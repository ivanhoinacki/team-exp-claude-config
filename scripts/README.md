# Scripts

Setup, maintenance, and verification scripts for the AI Dev Ecosystem.

## Scripts

| Script | Purpose | Platform |
|---|---|---|
| `install.sh` | One-line curl installer, detects platform and runs the correct setup | All |
| `setup.sh` | Full interactive installer for macOS (12 phases) | macOS |
| `setup-wsl.sh` | Full interactive installer for Linux/WSL2 (12 phases) | Linux/WSL2 |
| `update.sh` | Update an existing installation from the latest repo | All |
| `verify-setup.sh` | Quick health check of the installed ecosystem | All |
| `test-setup.sh` | Automated test suite (dry-run both installers in test mode) | All |
| `ci-local-check.sh` | Run CI checks locally before pushing (`lint + types + build + test`) | All |

## Installation flow

```
install.sh
  ├── macOS    → setup.sh
  └── Linux    → setup-wsl.sh
```

## Setup phases (both scripts)

| Phase | What it does |
|---|---|
| 0 | Prerequisites check (Node, Git, Python, GitHub CLI, Docker) |
| 1 | Backup existing configs |
| 2 | Collect user info (name, email, Slack ID, paths) |
| 3 | Install rules (8 files) |
| 4 | Install skills (16 directories) |
| 5 | Install agents (4 files) + placeholder replacement + service dossiers |
| 6 | Install hooks + status line |
| 7 | Configure settings.json |
| 8 | Configure MCP servers (8, add-only merge) |
| 8.5 | Install Vault RAG scripts and CLI symlinks |
| 9 | Install Python tools (uvx for mcp-atlassian) |
| 10 | Cursor IDE sync (optional, backup + merge) |
| 11 | Local AI layer (Ollama + ChromaDB + fswatch/inotifywait) |
| 12 | Optional tools (oh-my-zsh, CLI tools, platform-specific apps) |

## Flags

| Flag | Script | Effect |
|---|---|---|
| `--reconfigure` | setup.sh, setup-wsl.sh | Re-run user prompts even on update |
| `--force` | setup-wsl.sh | Skip confirmation prompt |

## Testing

```bash
bash scripts/test-setup.sh
```

Runs both macOS and Linux installers in `SETUP_TEST_MODE=1` (no interactive prompts, temporary directories).
