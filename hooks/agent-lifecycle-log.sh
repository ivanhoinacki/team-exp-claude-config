#!/bin/bash
# Unified lifecycle log for agent and task events.
# Handles: SubagentStart, SubagentStop, TaskCreated, TaskCompleted, TeammateIdle
# All events are written to a shared JSONL log for the session.
# Non-blocking: always exits 0.

input=$(cat)
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG="/tmp/claude-events-${PPID}.jsonl"

# Detect event type from input fields
# SubagentStart/Stop have subagent_id; TaskCreated/Completed have task_id
subagent_id=$(echo "$input" | jq -r '.subagent_id // empty')
task_id=$(echo "$input" | jq -r '.task_id // empty')
teammate_id=$(echo "$input" | jq -r '.teammate_id // empty')

if [ -n "$subagent_id" ]; then
  subagent_type=$(echo "$input" | jq -r '.subagent_type // "unknown"')
  exit_code=$(echo "$input" | jq -r '.exit_code // "null"')
  event="SubagentStart"
  [ "$exit_code" != "null" ] && event="SubagentStop"
  jq -n \
    --arg ts "$ts" --arg event "$event" \
    --arg id "$subagent_id" --arg type "$subagent_type" --arg code "$exit_code" \
    '{timestamp: $ts, event: $event, subagent_id: $id, subagent_type: $type, exit_code: $code}' \
    >> "$LOG" 2>/dev/null

elif [ -n "$task_id" ]; then
  desc=$(echo "$input" | jq -r '.task_description // ""')
  result=$(echo "$input" | jq -r '.result // "null"')
  event="TaskCreated"
  [ "$result" != "null" ] && event="TaskCompleted"
  jq -n \
    --arg ts "$ts" --arg event "$event" \
    --arg id "$task_id" --arg desc "$desc" --arg result "$result" \
    '{timestamp: $ts, event: $event, task_id: $id, description: $desc, result: $result}' \
    >> "$LOG" 2>/dev/null

elif [ -n "$teammate_id" ]; then
  jq -n \
    --arg ts "$ts" --arg id "$teammate_id" \
    '{timestamp: $ts, event: "TeammateIdle", teammate_id: $id}' \
    >> "$LOG" 2>/dev/null
fi

exit 0
