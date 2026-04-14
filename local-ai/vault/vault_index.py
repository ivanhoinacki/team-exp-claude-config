#!/usr/bin/env python3
"""
vault-index: Index LE vault .md files into ChromaDB for shared RAG.

Chunks .md files by ## headers, embeds via Ollama nomic-embed-text,
stores in ChromaDB collection "le-vault".

Usage:
    vault-index --full          # Re-index everything
    vault-index --incremental   # Only files modified since last run
    vault-index --stats         # Show index statistics
    vault-index --test          # Run validation queries
"""

import argparse
import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path

# Add venv to path
CHROMA_VENV = Path.home() / ".local/share/le-vault-chroma/venv"
sys.path.insert(0, str(CHROMA_VENV / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages"))

import chromadb
import requests

# Configuration (override via env vars, fallback to LE defaults)
VAULT_ROOT = Path(os.environ.get("VAULT_ROOT", str(Path.home() / "Library/Mobile Documents/iCloud~md~obsidian/Documents/ObsidianDocs/Luxury-Escapes")))
CODEBASE_ROOT = Path(os.environ.get("CODEBASE_ROOT", str(Path.home() / "Documents/LuxuryEscapes")))
CHROMA_HOST = "localhost"
CHROMA_PORT = 8100
COLLECTION_NAME = "le-vault"
OLLAMA_PORT = os.environ.get("OLLAMA_PORT", "11434")
OLLAMA_URL = f"http://localhost:{OLLAMA_PORT}"
OLLAMA_EMBED_MODEL = "nomic-embed-text"
STATE_FILE = Path.home() / ".local/share/le-vault-chroma/index-state.json"

# Max chunk size in characters (~500 tokens)
MAX_CHUNK_CHARS = 2000

# Directories to index from vault (relative to VAULT_ROOT)
VAULT_DIRS = {
    "Knowledge-Base/Review-Learnings": "review-learning",
    "Knowledge-Base/Business-Rules": "business-rule",
    "Knowledge-Base/CI-Infrastructure": "ci-infra",
    "Knowledge-Base/Troubleshooting": "troubleshooting",
    "Knowledge-Base/Frontend": "frontend",
    "Knowledge-Base/Infrastructure": "infrastructure",
    "Knowledge-Base/Local-Development": "local-dev",
    "Runbooks": "runbook",
    "Development/Providers": "provider",
    "Development/BUG": "bug-triage",
    "Knowledge-Base/Session-Memory": "session-memory",
    "Knowledge-Base/Radar-RAG-Exports": "radar-export",
}

# Known service names for auto-tagging
SERVICE_NAMES = [
    "svc-experiences", "svc-search", "svc-order", "svc-auth",
    "svc-sailthru", "svc-ee-offer", "svc-occasions",
    "www-le-admin", "www-le-customer", "www-ee-admin",
    "infra-le-local-dev",
]


def log(msg: str) -> None:
    print(f"\033[0;34m[vault-index]\033[0m {msg}", file=sys.stderr)


def warn(msg: str) -> None:
    print(f"\033[1;33m[warn]\033[0m {msg}", file=sys.stderr)


def err(msg: str) -> None:
    print(f"\033[0;31m[error]\033[0m {msg}", file=sys.stderr)
    sys.exit(1)


def get_embedding(texts: list[str]) -> list[list[float]]:
    """Get embeddings from Ollama API. Batches for efficiency."""
    headers = {"Content-Type": "application/json"}

    response = requests.post(
        f"{OLLAMA_URL}/api/embed",
        headers=headers,
        json={"model": OLLAMA_EMBED_MODEL, "input": texts},
        timeout=60,
    )
    response.raise_for_status()
    return response.json()["embeddings"]


def detect_services(content: str) -> list[str]:
    """Detect which services are mentioned in content."""
    content_lower = content.lower()
    return [svc for svc in SERVICE_NAMES if svc in content_lower]


def extract_frontmatter(content: str) -> tuple[dict, str]:
    """Extract YAML frontmatter if present, return (metadata, body)."""
    if content.startswith("---"):
        parts = content.split("---", 2)
        if len(parts) >= 3:
            meta = {}
            for line in parts[1].strip().split("\n"):
                if ":" in line:
                    key, val = line.split(":", 1)
                    meta[key.strip()] = val.strip()
            return meta, parts[2].strip()
    return {}, content


def chunk_markdown(content: str, source_file: str) -> list[dict]:
    """Split markdown by ## headers. Small files stay as one chunk."""
    frontmatter, body = extract_frontmatter(content)

    # Small files: single chunk
    if len(body) <= MAX_CHUNK_CHARS:
        return [{
            "text": body,
            "section": "full",
            "frontmatter": frontmatter,
        }]

    chunks = []
    sections = re.split(r"(?=^## )", body, flags=re.MULTILINE)

    for section in sections:
        section = section.strip()
        if not section:
            continue

        # Extract section title
        title_match = re.match(r"^## (.+?)$", section, re.MULTILINE)
        title = title_match.group(1).strip() if title_match else "intro"

        # If section is still too large, split by ### or paragraphs
        if len(section) > MAX_CHUNK_CHARS:
            subsections = re.split(r"(?=^### )", section, flags=re.MULTILINE)
            for sub in subsections:
                sub = sub.strip()
                if not sub:
                    continue
                # Truncate if still too large
                if len(sub) > MAX_CHUNK_CHARS:
                    sub = sub[:MAX_CHUNK_CHARS] + "\n... [truncated]"
                sub_title_match = re.match(r"^### (.+?)$", sub, re.MULTILINE)
                sub_title = f"{title} > {sub_title_match.group(1).strip()}" if sub_title_match else title
                chunks.append({
                    "text": sub,
                    "section": sub_title,
                    "frontmatter": frontmatter,
                })
        else:
            chunks.append({
                "text": section,
                "section": title,
                "frontmatter": frontmatter,
            })

    return chunks if chunks else [{"text": body[:MAX_CHUNK_CHARS], "section": "full", "frontmatter": frontmatter}]


def collect_vault_files() -> list[dict]:
    """Collect all indexable .md files from vault directories."""
    files = []

    # Vault directories
    for rel_dir, doc_type in VAULT_DIRS.items():
        dir_path = VAULT_ROOT / rel_dir
        if not dir_path.exists():
            continue
        for md_file in dir_path.rglob("*.md"):
            if md_file.name.startswith("."):
                continue
            files.append({
                "path": md_file,
                "type": doc_type,
                "source": "vault",
            })

    # Root-level runbook files
    for md_file in (VAULT_ROOT / "Runbooks").rglob("*.md") if (VAULT_ROOT / "Runbooks").exists() else []:
        entry = {"path": md_file, "type": "runbook", "source": "vault"}
        if entry not in files:
            files.append(entry)

    # CLAUDE.md dossiers from repos
    for repo_dir in CODEBASE_ROOT.iterdir():
        claude_md = repo_dir / "CLAUDE.md"
        if claude_md.exists():
            files.append({
                "path": claude_md,
                "type": "service-dossier",
                "source": "codebase",
                "repo": repo_dir.name,
            })

    return files


def file_hash(path: Path) -> str:
    """MD5 hash of file content for change detection."""
    return hashlib.md5(path.read_bytes()).hexdigest()


def load_state() -> dict:
    """Load previous index state (file hashes)."""
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {}


def save_state(state: dict) -> None:
    """Save index state."""
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))


def index_files(files: list[dict], collection, incremental: bool = False) -> dict:
    """Index files into ChromaDB. Returns stats."""
    state = load_state() if incremental else {}
    new_state = {}

    stats = {"files": 0, "chunks": 0, "skipped": 0, "errors": 0, "by_type": {}}

    # Batch processing
    batch_ids = []
    batch_texts = []
    batch_metadatas = []
    BATCH_SIZE = 20  # embed 20 texts at once

    for file_info in files:
        path = file_info["path"]
        if not path.exists():
            continue

        current_hash = file_hash(path)
        path_key = str(path)

        # Skip if unchanged (incremental mode)
        if incremental and state.get(path_key) == current_hash:
            stats["skipped"] += 1
            new_state[path_key] = current_hash
            continue

        try:
            content = path.read_text(encoding="utf-8")
        except Exception as e:
            warn(f"Could not read {path}: {e}")
            stats["errors"] += 1
            continue

        if not content.strip():
            continue

        doc_type = file_info["type"]
        services = detect_services(content)
        if file_info.get("repo"):
            # Extract service name from repo dir (e.g., svc-search--exp3563 -> svc-search)
            repo_base = re.sub(r"--.*$", "", file_info["repo"])
            if repo_base not in services:
                services.append(repo_base)

        chunks = chunk_markdown(content, str(path))

        for idx, chunk in enumerate(chunks):
            chunk_id = hashlib.md5(f"{path_key}:{idx}:{chunk['section']}".encode()).hexdigest()
            metadata = {
                "source_file": path_key,
                "source_name": path.name,
                "type": doc_type,
                "section": chunk["section"],
                "services": ",".join(services) if services else "",
                "source_origin": file_info.get("source", "vault"),
            }

            batch_ids.append(chunk_id)
            batch_texts.append(chunk["text"])
            batch_metadatas.append(metadata)

            # Flush batch
            if len(batch_ids) >= BATCH_SIZE:
                _flush_batch(collection, batch_ids, batch_texts, batch_metadatas)
                stats["chunks"] += len(batch_ids)
                batch_ids, batch_texts, batch_metadatas = [], [], []

        stats["files"] += 1
        stats["by_type"][doc_type] = stats["by_type"].get(doc_type, 0) + 1
        new_state[path_key] = current_hash

    # Flush remaining
    if batch_ids:
        _flush_batch(collection, batch_ids, batch_texts, batch_metadatas)
        stats["chunks"] += len(batch_ids)

    # Save state for incremental
    if incremental:
        new_state.update({k: v for k, v in state.items() if k not in new_state})
    save_state(new_state)

    return stats


def _flush_batch(collection, ids, texts, metadatas):
    """Embed a batch and upsert to ChromaDB."""
    try:
        embeddings = get_embedding(texts)
        collection.upsert(
            ids=ids,
            documents=texts,
            embeddings=embeddings,
            metadatas=metadatas,
        )
    except Exception as e:
        warn(f"Batch upsert failed: {e}")
        # Try one by one as fallback
        for i in range(len(ids)):
            try:
                emb = get_embedding([texts[i]])
                collection.upsert(
                    ids=[ids[i]],
                    documents=[texts[i]],
                    embeddings=emb,
                    metadatas=[metadatas[i]],
                )
            except Exception as e2:
                warn(f"  Single upsert failed for {metadatas[i]['source_name']}: {e2}")


def cmd_full(args):
    """Full re-index of all vault files."""
    log("Starting full index...")
    client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)

    # Delete existing collection if it exists
    try:
        client.delete_collection(COLLECTION_NAME)
        log("Deleted existing collection")
    except Exception:
        pass

    collection = client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"description": "Luxury Escapes vault knowledge base for RAG"},
    )

    files = collect_vault_files()
    log(f"Found {len(files)} files to index")

    stats = index_files(files, collection, incremental=False)

    log(f"Done! {stats['files']} files, {stats['chunks']} chunks indexed")
    if stats["errors"]:
        warn(f"{stats['errors']} files had errors")
    log(f"By type: {json.dumps(stats['by_type'], indent=2)}")


def cmd_incremental(args):
    """Incremental index (only changed files)."""
    log("Starting incremental index...")
    client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
    collection = client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"description": "Luxury Escapes vault knowledge base for RAG"},
    )

    files = collect_vault_files()
    stats = index_files(files, collection, incremental=True)

    log(f"Done! {stats['files']} files updated, {stats['chunks']} chunks, {stats['skipped']} unchanged")


def cmd_stats(args):
    """Show index statistics."""
    client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
    try:
        collection = client.get_collection(COLLECTION_NAME)
    except Exception:
        err(f"Collection '{COLLECTION_NAME}' not found. Run: vault-index --full")

    count = collection.count()
    print(f"\nCollection: {COLLECTION_NAME}")
    print(f"Total chunks: {count}")

    if count == 0:
        return

    # Sample to get type distribution
    sample = collection.get(limit=min(count, 500), include=["metadatas"])
    types = {}
    services = {}
    sources = set()
    for meta in sample["metadatas"]:
        t = meta.get("type", "unknown")
        types[t] = types.get(t, 0) + 1
        for svc in meta.get("services", "").split(","):
            if svc:
                services[svc] = services.get(svc, 0) + 1
        sources.add(meta.get("source_name", "unknown"))

    print(f"Unique source files: {len(sources)}")
    print(f"\nBy type:")
    for t, c in sorted(types.items(), key=lambda x: -x[1]):
        print(f"  {t}: {c}")
    print(f"\nTop services mentioned:")
    for s, c in sorted(services.items(), key=lambda x: -x[1])[:10]:
        print(f"  {s}: {c}")


def cmd_test(args):
    """Run validation queries to test retrieval quality."""
    client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
    try:
        collection = client.get_collection(COLLECTION_NAME)
    except Exception:
        err(f"Collection '{COLLECTION_NAME}' not found. Run: vault-index --full")

    test_queries = [
        {
            "query": "boolean validation zod coerce query parameter string false",
            "expected_in": "EXP-3488",
            "match_field": "source_name",
            "description": "Zod boolean pitfall from search filters review",
        },
        {
            "query": "price filter AUD currency conversion priceGte priceLte search",
            "expected_in": "svc-search",
            "match_field": "services",
            "description": "Price filter AUD conversion (svc-search context)",
        },
        {
            "query": "refund promo calculation financial fx rate payment",
            "expected_in": "Payment",
            "match_field": "source_name",
            "description": "Financial/payment processing rules",
        },
        {
            "query": "provider sync images klook resilience retry",
            "expected_in": "klook",
            "match_field": "source_name",
            "description": "Provider sync patterns (Klook)",
        },
        {
            "query": "experience search offer listing confirmation booking",
            "expected_in": "svc-experiences",
            "match_field": "services",
            "description": "Experience search/listing features",
        },
    ]

    headers = {"Content-Type": "application/json"}

    print("\n=== Validation Queries ===\n")
    passed = 0
    for test in test_queries:
        emb_response = requests.post(
            f"{OLLAMA_URL}/api/embed",
            headers=headers,
            json={"model": OLLAMA_EMBED_MODEL, "input": test["query"]},
            timeout=30,
        )
        emb_response.raise_for_status()
        query_embedding = emb_response.json()["embeddings"][0]

        results = collection.query(
            query_embeddings=[query_embedding],
            n_results=5,
            include=["metadatas", "distances"],
        )

        field = test["match_field"]
        values = [m.get(field, "") for m in results["metadatas"][0]]
        sources = [m.get("source_name", "?") for m in results["metadatas"][0]]
        distances = results["distances"][0]
        found = any(test["expected_in"].lower() in v.lower() for v in values)

        status = "\033[0;32mPASS\033[0m" if found else "\033[0;31mFAIL\033[0m"
        if found:
            passed += 1

        print(f"[{status}] {test['description']}")
        print(f"  Query: {test['query'][:70]}...")
        print(f"  Expected '{test['expected_in']}' in {field}")
        print(f"  Top 5 sources: {sources}")
        print(f"  Top 5 {field}: {values[:5]}")
        print(f"  Distances: {[f'{d:.3f}' for d in distances]}")
        print()

    print(f"Result: {passed}/{len(test_queries)} passed")


def main():
    parser = argparse.ArgumentParser(description="Index LE vault into ChromaDB for RAG")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--full", action="store_true", help="Full re-index")
    group.add_argument("--incremental", action="store_true", help="Index only changed files")
    group.add_argument("--stats", action="store_true", help="Show index statistics")
    group.add_argument("--test", action="store_true", help="Run validation queries")
    args = parser.parse_args()

    # Check ChromaDB
    try:
        client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
        client.heartbeat()
    except Exception:
        err("ChromaDB not running. Start with: vault-chroma start")

    # Check Ollama (needed for embedding, not for stats)
    if not args.stats:
        try:
            r = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
            r.raise_for_status()
        except Exception:
            err("Ollama not running. Start with: brew services start ollama")

    if args.full:
        cmd_full(args)
    elif args.incremental:
        cmd_incremental(args)
    elif args.stats:
        cmd_stats(args)
    elif args.test:
        cmd_test(args)


if __name__ == "__main__":
    main()
