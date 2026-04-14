# Hooks

Claude Code lifecycle hooks that run automatically at specific events (pre-commit, session start, tool use, etc.). Split into **core** (installed by default) and **optional** (opt-in).

## Core Hooks (5 + status line)

Installed automatically by `setup.sh` / `setup-wsl.sh`.

| Hook | Event | Purpose |
|---|---|---|
| `pre-git-commit.sh` | PreToolUse (git commit) | Blocks commits without skill, strips trailers |
| `skill-enforcement-guard.sh` | PreToolUse | Ensures skills are used instead of raw commands |
| `tool-preference-guard.sh` | PreToolUse | Enforces preferred tools (e.g. rg over grep) |
| `skill-tracker.sh` | PostToolUse | Tracks which skills were invoked per session |
| `session-start-check.sh` | PostToolUse (first) | Processes previous session logs at startup |
| `statusline-command.sh` | Notification | Custom status line: `user :: dir :: branch :: rate% :: ctx%` |

## Optional Hooks (17)

Installed only when explicitly enabled. Copy from `optional/` to your hooks config.

| Hook | Event | Purpose |
|---|---|---|
| `vault-rag-reminder.sh` | PostToolUse | Reminds to check vault before answering |
| `vault-rag-tracker.sh` | PostToolUse | Tracks vault RAG usage per session |
| `worktree-setup.sh` | PostToolUse | Auto-setup worktree for new feature branches |
| `worktree-remove.sh` | PostToolUse | Cleanup worktree after branch merge |
| `frontend-layout-guard.sh` | PreToolUse | Validates frontend changes follow layout patterns |
| `user-prompt-context.sh` | PreToolUse | Injects context from user prompt analysis |
| `agent-lifecycle-log.sh` | PostToolUse | Logs agent invocations for debugging |
| `config-change-log.sh` | PostToolUse | Tracks config file modifications |
| `cwd-context.sh` | PreToolUse | Adds working directory context |
| `elicitation-log.sh` | PostToolUse | Logs clarification questions |
| `file-changed-log.sh` | PostToolUse | Tracks all file modifications |
| `instructions-audit.sh` | PostToolUse | Audits rule compliance |
| `permission-denied-handler.sh` | PostToolUse | Handles permission failures gracefully |
| `post-tool-failure-log.sh` | PostToolUse | Logs tool failures for debugging |
| `postcompact-log.sh` | PostToolUse | Logs context compaction events |
| `precompact-backup.sh` | PreToolUse | Backs up context before compaction |
| `stop-failure-handler.sh` | PostToolUse | Handles forced stop events |

## How hooks work

Hooks are shell scripts registered in `~/.claude/settings.json` under the `hooks` key. Claude Code executes them at the matching lifecycle event. Each hook receives context via environment variables and stdin.

## Enabling optional hooks

Edit `~/.claude/settings.json` and add the hook to the appropriate event array, or copy the script to `~/.claude/hooks/` and reference it.
