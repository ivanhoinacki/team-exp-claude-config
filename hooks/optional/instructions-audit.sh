#!/bin/bash
# InstructionsLoaded hook: audits which CLAUDE.md files and rules are loaded per session.
# Useful for debugging rule loading order and detecting when rules are missing.

input=$(cat)
path=$(echo "$input" | jq -r '.instructions_path // empty')
type=$(echo "$input" | jq -r '.instructions_type // "unknown"')
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

[ -z "$path" ] && exit 0

LOG="/tmp/claude-events-${PPID}.jsonl"
AUDIT="/tmp/claude-instructions-${PPID}.log"

jq -n \
  --arg ts "$ts" --arg path "$path" --arg type "$type" \
  '{timestamp: $ts, event: "InstructionsLoaded", path: $path, type: $type}' \
  >> "$LOG" 2>/dev/null

# Human-readable audit trail
echo "${ts} [${type}] ${path}" >> "$AUDIT" 2>/dev/null

exit 0
