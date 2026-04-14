#!/bin/bash
# WorktreeRemove hook: fires when a worktree is removed.
# Cleans up any session-specific state and logs the removal.

input=$(cat)
worktree_path=$(echo "$input" | jq -r '.worktree_path // empty')
branch=$(echo "$input" | jq -r '.branch // "unknown"')
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

[ -z "$worktree_path" ] && exit 0

LOG="/tmp/claude-events-${PPID}.jsonl"

jq -n \
  --arg ts "$ts" --arg path "$worktree_path" --arg branch "$branch" \
  '{timestamp: $ts, event: "WorktreeRemove", worktree_path: $path, branch: $branch}' \
  >> "$LOG" 2>/dev/null

# Clean up any .env files that were copied by worktree-setup.sh
# Only if the worktree directory no longer exists (already removed)
if [ ! -d "$worktree_path" ]; then
  echo "${ts} WorktreeRemove: ${branch} at ${worktree_path} (already removed)" >> "$LOG"
fi

exit 0
