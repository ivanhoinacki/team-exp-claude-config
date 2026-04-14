# Local AI Layer

On-device AI infrastructure for the ecosystem. Provides semantic search over your Obsidian vault (Vault RAG) using ChromaDB for vector storage and Ollama for local embeddings.

## Components

```
local-ai/
  vault/              # Vault RAG pipeline
    vault_index.py    # Index vault markdown files into ChromaDB
    vault_query.sh    # CLI query interface for vault search
    vault_chroma.sh   # ChromaDB container management (start/stop/status)
    vault_watch.sh    # File watcher, re-indexes on vault changes
    vault_mcp_server.py  # MCP server exposing vault search to Claude
    README.md         # Detailed vault RAG documentation
```

## Architecture

```
Obsidian Vault (.md files)
       │
       ▼
  vault_index.py ──► ChromaDB (Docker)
       │                  │
       │            nomic-embed-text (Ollama)
       │                  │
       ▼                  ▼
  vault_watch.sh    vault_mcp_server.py
  (auto re-index)   (Claude queries via MCP)
```

## Prerequisites

- **Docker**, runs ChromaDB container
- **Ollama**, runs the embedding model locally (`nomic-embed-text`)
- **Python 3** with `chromadb`, `ollama` packages (installed in a venv)
- **fswatch** (macOS) or **inotifywait** (Linux), for file watching

## Setup

The setup scripts (Phase 11) handle installation automatically:
1. Check/install Ollama and pull `nomic-embed-text`
2. Start ChromaDB container
3. Create Python venv and install dependencies
4. Run initial vault indexing
5. Register `local-le-chromadb` MCP server in Claude config

## Usage

```bash
# Manual indexing
vault-index

# Start file watcher (auto re-indexes on changes)
vault-watch

# Query the vault from CLI
vault-query "how does experience booking work"

# ChromaDB management
vault-chroma start|stop|status
```

## MCP Integration

The `vault_mcp_server.py` exposes two tools to Claude:
- `query_vault`, semantic search with optional service/type filters
- `list_vault_sources`, list available document types and services

Registered as `local-le-chromadb` in `~/.claude.json`.
