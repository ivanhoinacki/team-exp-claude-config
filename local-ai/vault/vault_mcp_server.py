#!/usr/bin/env python3
"""
vault-mcp-server: MCP server exposing ChromaDB vault RAG for Claude Code and Cursor.

Canonical source: ~/.claude/local-ai/vault/vault_mcp_server.py (installed by team-exp-claude-config)
(This file; keep MCP config pointing at this path as the default.)

Uses the official MCP Python SDK (stdio transport) so protocol version and framing
match current clients (Cursor, Claude Code).

Tools:
  - query_vault: Semantic search in the LE knowledge base
  - list_vault_sources: Discover indexed types and services

Requires: ChromaDB on CHROMA_HOST:CHROMA_PORT (default localhost:8100), Ollama for embeddings.

Embedding provider: Ollama (port 11434) with nomic-embed-text.

Config (~/.cursor/mcp.json or ~/.claude/mcp.json), example:
  "local-le-chromadb": {
    "type": "stdio",
    "command": "$HOME/.local/share/le-vault-chroma/venv/bin/python",
    "args": ["$HOME/.claude/local-ai/vault/vault_mcp_server.py"],
    "env": { "CHROMA_HOST": "localhost", "CHROMA_PORT": "8100" }
  }
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys
from typing import Any

import requests

try:
    from flashrank import Ranker, RerankRequest
    FLASHRANK_AVAILABLE = True
except ImportError:
    FLASHRANK_AVAILABLE = False

# Configuration
CHROMA_HOST = os.environ.get("CHROMA_HOST", "localhost")
CHROMA_PORT = int(os.environ.get("CHROMA_PORT", "8100"))
COLLECTION_NAME = "le-vault"

# Embedding provider: Ollama
EMBED_PROVIDER = os.environ.get("EMBED_PROVIDER", "auto")
OLLAMA_PORT = os.environ.get("OLLAMA_PORT", "11434")
OLLAMA_URL = f"http://localhost:{OLLAMA_PORT}"
OLLAMA_EMBED_MODEL = "nomic-embed-text"

# Chroma client deps live in this venv (same as chromadb)
CHROMA_VENV = os.path.expanduser("~/.local/share/le-vault-chroma/venv")
sys.path.insert(
    0,
    os.path.join(
        CHROMA_VENV,
        "lib",
        f"python{sys.version_info.major}.{sys.version_info.minor}",
        "site-packages",
    ),
)

import chromadb  # noqa: E402

import mcp.server.stdio  # noqa: E402
import mcp.types as types  # noqa: E402
from mcp.server.lowlevel import NotificationOptions, Server  # noqa: E402
from mcp.server.models import InitializationOptions  # noqa: E402

_LOG_PATH = os.path.expanduser("~/.local/share/le-vault-chroma/mcp-server.log")


def _setup_logging() -> None:
    os.makedirs(os.path.dirname(_LOG_PATH), exist_ok=True)
    logging.basicConfig(
        filename=_LOG_PATH,
        level=logging.DEBUG,
        format="%(asctime)s %(levelname)s %(message)s",
    )


def _detect_embed_provider() -> str:
    """Check if Ollama is available for embeddings."""
    if EMBED_PROVIDER != "auto":
        return EMBED_PROVIDER
    # Try Ollama first (preferred, always-on via brew services)
    try:
        resp = requests.get(f"{OLLAMA_URL}/api/tags", timeout=3)
        if resp.status_code == 200:
            return "ollama"
    except Exception:
        pass
    return "none"


def _log_ollama_request(caller: str, endpoint: str, model: str, duration_ms: float):
    """Append to shared Ollama request log for caller tracing."""
    try:
        import datetime
        ts = datetime.datetime.now().strftime("%H:%M:%S")
        dur = f"{duration_ms:.0f}ms" if duration_ms < 1000 else f"{duration_ms/1000:.1f}s"
        with open("/tmp/ollama-requests.log", "a") as f:
            f.write(f"{ts} [{caller}] POST {endpoint} model={model} ({dur})\n")
    except Exception:
        pass


def get_embedding(text: str) -> list[float]:
    """Get embedding from Ollama."""
    provider = _detect_embed_provider()

    if provider == "ollama":
        import time as _t
        _start = _t.monotonic()
        resp = requests.post(
            f"{OLLAMA_URL}/api/embed",
            json={"model": OLLAMA_EMBED_MODEL, "input": text},
            timeout=30,
        )
        _elapsed = (_t.monotonic() - _start) * 1000
        resp.raise_for_status()
        _log_ollama_request("vault-rag", "/api/embed", OLLAMA_EMBED_MODEL, _elapsed)
        return resp.json()["embeddings"][0]

    raise ConnectionError(
        "Ollama not running. Start with: brew services start ollama"
    )


def get_collection():
    """Get ChromaDB collection."""
    client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
    return client.get_collection(COLLECTION_NAME)


def handle_query_vault(params: dict[str, Any]) -> str:
    """Semantic search in the vault knowledge base."""
    query = params.get("query", "")
    n_results = min(int(params.get("n_results", 5)), 10)
    type_filter = params.get("type_filter") or []
    service_filter = params.get("service_filter") or ""

    logging.info(f"query_vault: query={query!r}, n={n_results}, svc={service_filter!r}")

    if not query:
        return "Error: query parameter is required"

    try:
        collection = get_collection()
        embedding = get_embedding(query)

        where = None
        conditions: list[dict[str, Any]] = []
        if type_filter:
            conditions.append({"type": {"$in": type_filter}})
        if service_filter:
            conditions.append({"services": {"$contains": service_filter}})

        if len(conditions) == 1:
            where = conditions[0]
        elif len(conditions) > 1:
            where = {"$and": conditions}

        kwargs: dict[str, Any] = {
            "query_embeddings": [embedding],
            "n_results": n_results,
            "include": ["documents", "metadatas", "distances"],
        }
        if where:
            kwargs["where"] = where

        # Retrieve more candidates for reranking
        retrieve_n = n_results * 4 if FLASHRANK_AVAILABLE else n_results
        kwargs["n_results"] = min(retrieve_n, 20)

        results = collection.query(**kwargs)

        docs = results["documents"][0]
        metas = results["metadatas"][0]
        dists = results["distances"][0]

        # Rerank with FlashRank if available (retrieve broad, rerank precise)
        if FLASHRANK_AVAILABLE and len(docs) > n_results:
            try:
                ranker = Ranker(model_name="ms-marco-MiniLM-L-12-v2", cache_dir="/tmp/flashrank")
                passages = [{"id": str(i), "text": d[:800], "meta": {"idx": i}} for i, d in enumerate(docs)]
                rerank_req = RerankRequest(query=query, passages=passages)
                ranked = ranker.rerank(rerank_req)
                # Take top n_results by rerank score
                top_indices = [int(r["id"]) for r in ranked[:n_results]]
                docs = [docs[i] for i in top_indices]
                metas = [metas[i] for i in top_indices]
                dists = [dists[i] for i in top_indices]
            except Exception as e:
                logging.warning(f"FlashRank reranking failed, using raw results: {e}")
                docs = docs[:n_results]
                metas = metas[:n_results]
                dists = dists[:n_results]

        output_parts: list[str] = []
        for doc, meta, dist in zip(docs, metas, dists):
            if dist > 0.85:
                continue
            source = meta.get("source_name", "unknown")
            section = meta.get("section", "")
            doc_type = meta.get("type", "")
            services = meta.get("services", "")
            text = doc[:600].strip() if doc else ""

            output_parts.append(
                f"## [{doc_type}] {source}"
                + (f" > {section}" if section and section != "full" else "")
                + f" (distance: {dist:.3f})"
                + (f"\nServices: {services}" if services else "")
                + f"\n\n{text}\n"
            )

        if not output_parts:
            logging.info(f"query_vault: 0 chunks passed threshold. Raw results: {len(docs)} docs, distances={[f'{d:.3f}' for d in dists]}")
            return f"No relevant results found for: {query}"

        response = f"Found {len(output_parts)} relevant chunks:\n\n" + "\n---\n".join(output_parts)
        logging.info(f"query_vault: returning {len(output_parts)} chunks, response length={len(response)} chars")
        return response

    except Exception as e:
        return f"Error querying vault: {e}"


def handle_list_vault_sources(_params: dict[str, Any]) -> str:
    """List indexed types and services for discovery."""
    try:
        collection = get_collection()
        count = collection.count()
        sample = collection.get(limit=min(count, 1000), include=["metadatas"])

        types_count: dict[str, int] = {}
        services: dict[str, int] = {}
        for meta in sample["metadatas"]:
            t = meta.get("type", "unknown")
            types_count[t] = types_count.get(t, 0) + 1
            for svc in meta.get("services", "").split(","):
                if svc:
                    services[svc] = services.get(svc, 0) + 1

        output = f"Collection: {COLLECTION_NAME}\n"
        output += f"Total chunks: {count}\n\n"
        output += "Types (use in type_filter):\n"
        for t, c in sorted(types_count.items(), key=lambda x: -x[1]):
            output += f"  - {t}: {c} chunks\n"
        output += "\nServices (use in service_filter):\n"
        for s, c in sorted(services.items(), key=lambda x: -x[1])[:15]:
            output += f"  - {s}: {c} chunks\n"

        return output
    except Exception as e:
        return f"Error listing sources: {e}"


TOOLS: list[types.Tool] = [
    types.Tool(
        name="query_vault",
        description=(
            "Semantic search in the Luxury Escapes team knowledge base. "
            "Returns relevant chunks from review learnings, business rules, "
            "service dossiers, pitfalls, troubleshooting guides, runbooks, and "
            "radar-export (DB digests exported to Knowledge-Base/Radar-RAG-Exports). "
            "Use before code review or when investigating domain-specific behavior."
        ),
        inputSchema={
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": (
                        "Natural language search query "
                        "(e.g. 'boolean validation zod query params')"
                    ),
                },
                "n_results": {
                    "type": "integer",
                    "description": "Number of results to return (default 5, max 10)",
                    "default": 5,
                },
                "type_filter": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": (
                        "Filter by document type. Options: review-learning, business-rule, "
                        "service-dossier, runbook, ci-infra, troubleshooting, frontend, "
                        "infrastructure, local-dev, provider, bug-triage, session-memory, "
                        "radar-export"
                    ),
                },
                "service_filter": {
                    "type": "string",
                    "description": (
                        "Filter by service name (e.g. 'svc-search', 'svc-experiences', "
                        "'svc-order', 'www-le-customer')"
                    ),
                },
            },
            "required": ["query"],
        },
    ),
    types.Tool(
        name="list_vault_sources",
        description=(
            "List available document types and services in the LE knowledge base. "
            "Use to discover what filters are available for query_vault."
        ),
        inputSchema={"type": "object", "properties": {}},
    ),
]

server = Server("local-le-chromadb", version="1.0.0")


@server.list_tools()
async def list_tools() -> list[types.Tool]:
    return TOOLS


@server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> types.CallToolResult:
    if name == "query_vault":
        text = await asyncio.to_thread(handle_query_vault, arguments)
    elif name == "list_vault_sources":
        text = await asyncio.to_thread(handle_list_vault_sources, arguments)
    else:
        return types.CallToolResult(
            content=[types.TextContent(type="text", text=f"Unknown tool: {name}")],
            isError=True,
        )
    return types.CallToolResult(
        content=[types.TextContent(type="text", text=text)],
        isError=False,
    )


async def run() -> None:
    logging.info("vault-mcp-server (MCP SDK stdio) starting")
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="local-le-chromadb",
                server_version="1.0.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )


def main() -> None:
    _setup_logging()
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
