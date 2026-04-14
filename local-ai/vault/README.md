# Vault RAG (ChromaDB + Ollama)

Semantic search over the team's Obsidian vault, exposed as an MCP server for Claude Code and Cursor.

## Architecture

```
[Obsidian vault] --fswatch--> vault_watch.sh --triggers--> vault_index.py --incremental-->
  [ChromaDB :8100] <--query-- vault_mcp_server.py (MCP) <--tool_call-- Claude Code / Cursor
```

## Scripts

| Script | Purpose |
|---|---|
| `vault_chroma.sh` | Manage ChromaDB Docker container (start/stop/status/ui) |
| `vault_index.py` | Index .md files into ChromaDB (full/incremental), chunks by `##` headers |
| `vault_watch.sh` | fswatch monitor, triggers incremental index on vault file changes (30s debounce) |
| `vault_query.sh` | CLI wrapper for querying ChromaDB directly from terminal |
| `vault_mcp_server.py` | MCP server exposing `query_vault` and `list_vault_sources` tools |

## Dependencies

- **Docker**: ChromaDB container (`chromadb/chroma:latest`) on port 8100
- **Ollama**: `nomic-embed-text` model for embeddings (768-dim)
- **Python 3**: with chromadb, requests, mcp SDK in a venv at `~/.local/share/le-vault-chroma/venv`
- **fswatch**: macOS file system watcher (`brew install fswatch`)

## Setup

The `setup.sh` wizard handles installation. Manual steps:

```bash
# 1. Start ChromaDB
vault-chroma start

# 2. Full index (first time)
vault-index --full

# 3. Start file watcher (or add to LaunchAgents)
vault-watch &

# 4. Verify MCP connection
claude mcp list  # should show local-le-chromadb
```

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `VAULT_ROOT` | `~/Library/Mobile Documents/.../Luxury-Escapes` | Path to Obsidian vault |
| `CODEBASE_ROOT` | `~/Documents/LuxuryEscapes` | Path to LE repos |
| `CHROMA_HOST` | `localhost` | ChromaDB host |
| `CHROMA_PORT` | `8100` | ChromaDB port |
| `OLLAMA_PORT` | `11434` | Ollama API port |

## MCP config

```json
"local-le-chromadb": {
  "type": "stdio",
  "command": "$HOME/.local/share/le-vault-chroma/venv/bin/python",
  "args": ["$HOME/.claude/local-ai/vault/vault_mcp_server.py"],
  "env": { "CHROMA_HOST": "localhost", "CHROMA_PORT": "8100" }
}
```
