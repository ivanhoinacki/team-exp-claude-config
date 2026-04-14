#!/bin/bash
# ConfigChange hook: logs when settings.json is modified during a session.
# Useful for detecting accidental config changes or tracking deliberate updates.

input=$(cat)
changed_keys=$(echo "$input" | jq -r '.changed_keys // [] | join(", ")')
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

LOG="/tmp/claude-events-${PPID}.jsonl"

jq -n \
  --arg ts "$ts" --arg keys "$changed_keys" \
  '{timestamp: $ts, event: "ConfigChange", changed_keys: $keys}' \
  >> "$LOG" 2>/dev/null

# If hooks section changed, flag it prominently
if echo "$changed_keys" | grep -qi "hook"; then
  echo "${ts} WARNING: hooks config changed. Keys: ${changed_keys}" >> "$LOG"
fi

exit 0
