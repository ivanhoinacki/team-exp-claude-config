#!/bin/bash
# PostToolUseFailure hook: logs structured tool failures to /tmp.
# Useful for debugging recurring failures without --debug mode.
# Non-blocking: never denies, only logs.

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // "unknown"')
error=$(echo "$input" | jq -r '.error // .tool_response // "no error detail"')
cwd=$(echo "$input" | jq -r '.cwd // ""')
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

LOG="/tmp/claude-tool-failures-${PPID}.jsonl"

# Write structured log entry
jq -n \
  --arg ts "$timestamp" \
  --arg tool "$tool" \
  --arg error "$error" \
  --arg cwd "$cwd" \
  '{timestamp: $ts, tool: $tool, error: $error, cwd: $cwd}' \
  >> "$LOG" 2>/dev/null

exit 0
