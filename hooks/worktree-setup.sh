#!/bin/bash
# WorktreeCreate hook: automatically sets up environment when a worktree is created.
# Runs after Claude Code creates a new worktree.
# Non-blocking: failures are logged but never prevent the worktree from being used.

input=$(cat)
worktree_path=$(echo "$input" | jq -r '.worktree_path // empty')
branch=$(echo "$input" | jq -r '.branch // "unknown"')

[ -z "$worktree_path" ] && exit 0
[ ! -d "$worktree_path" ] && exit 0

# Find the repo root (parent of the worktree, or where .git lives)
repo_root=$(git -C "$worktree_path" rev-parse --show-toplevel 2>/dev/null)
[ -z "$repo_root" ] && exit 0

LOG="/tmp/worktree-setup-${PPID}.log"
echo "[$(date -u +%H:%M:%SZ)] worktree-setup: path=$worktree_path branch=$branch" >> "$LOG"

# Copy .env.local from repo root if it exists and worktree doesn't have it yet
if [ -f "$repo_root/.env.local" ] && [ ! -f "$worktree_path/.env.local" ]; then
  cp "$repo_root/.env.local" "$worktree_path/.env.local" 2>/dev/null \
    && echo "[$(date -u +%H:%M:%SZ)] copied .env.local" >> "$LOG"
fi

# Copy .env from repo root as fallback
if [ -f "$repo_root/.env" ] && [ ! -f "$worktree_path/.env" ]; then
  cp "$repo_root/.env" "$worktree_path/.env" 2>/dev/null \
    && echo "[$(date -u +%H:%M:%SZ)] copied .env" >> "$LOG"
fi

# Run yarn install in background if this is a Node.js project
# Uses --frozen-lockfile to avoid unintended lockfile changes
if [ -f "$worktree_path/package.json" ]; then
  (
    cd "$worktree_path" && \
    yarn install --frozen-lockfile --silent >> "$LOG" 2>&1 && \
    echo "[$(date -u +%H:%M:%SZ)] yarn install complete" >> "$LOG" || \
    echo "[$(date -u +%H:%M:%SZ)] yarn install failed (check $LOG)" >> "$LOG"
  ) &
  disown
fi

exit 0
