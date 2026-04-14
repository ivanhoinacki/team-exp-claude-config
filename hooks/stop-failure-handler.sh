#!/bin/bash
# StopFailure hook: fires when a turn ends due to an API error (rate limit, timeout).
# Logs the failure and injects recovery context for the next turn.

input=$(cat)
error=$(echo "$input" | jq -r '.error // "unknown error"')
turn_count=$(echo "$input" | jq -r '.turn_count // 0')
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

LOG="/tmp/claude-events-${PPID}.jsonl"

jq -n \
  --arg ts "$ts" --arg error "$error" --arg turns "$turn_count" \
  '{timestamp: $ts, event: "StopFailure", error: $error, turn_count: $turns}' \
  >> "$LOG" 2>/dev/null

# Detect rate limit specifically
if echo "$error" | grep -qiE 'rate.limit|overloaded|429|too many'; then
  jq -n --arg ctx "STOP FAILURE [rate limit]: Turn ended due to API rate limit after ${turn_count} turns.
Recovery: wait 60 seconds before resuming. The session context is preserved.
If compaction was triggered, check /tmp/claude-compact-backups/ for transcript backup." \
    '{ additionalContext: $ctx }'
else
  jq -n --arg ctx "STOP FAILURE [${error}]: Turn ended unexpectedly after ${turn_count} turns.
Recovery: the session context is preserved. Resume by describing what you were working on." \
    '{ additionalContext: $ctx }'
fi

exit 0
