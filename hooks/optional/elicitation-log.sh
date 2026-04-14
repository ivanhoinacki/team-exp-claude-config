#!/bin/bash
# Elicitation + ElicitationResult hook: logs MCP server input requests.
# Useful for debugging MCP integrations that require user/system input.

input=$(cat)
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG="/tmp/claude-events-${PPID}.jsonl"

request_id=$(echo "$input" | jq -r '.request_id // empty')
prompt=$(echo "$input" | jq -r '.prompt // empty')
result=$(echo "$input" | jq -r '.result // empty')

if [ -n "$prompt" ]; then
  # Elicitation event
  jq -n \
    --arg ts "$ts" --arg id "$request_id" --arg prompt "$prompt" \
    '{timestamp: $ts, event: "Elicitation", request_id: $id, prompt: $prompt}' \
    >> "$LOG" 2>/dev/null
elif [ -n "$result" ]; then
  # ElicitationResult event
  jq -n \
    --arg ts "$ts" --arg id "$request_id" --arg result "$result" \
    '{timestamp: $ts, event: "ElicitationResult", request_id: $id, result: $result}' \
    >> "$LOG" 2>/dev/null
fi

exit 0
