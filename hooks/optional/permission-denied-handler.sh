#!/bin/bash
# PermissionDenied hook: fires when a tool call is denied by the permission system.
# Injects context via additionalContext to help Claude understand how to proceed
# instead of retrying the same blocked action.

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // "unknown"')
reason=$(echo "$input" | jq -r '.reason // ""')
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

LOG="/tmp/claude-events-${PPID}.jsonl"
jq -n --arg ts "$ts" --arg event "PermissionDenied" --arg tool "$tool" --arg reason "$reason" \
  '{timestamp: $ts, event: $event, tool: $tool, reason: $reason}' >> "$LOG" 2>/dev/null

ctx=""

case "$tool" in
  Bash*)
    # If skill enforcement blocked it, guide Claude to load the skill first
    if echo "$reason" | grep -q "SKILL ENFORCEMENT"; then
      skill=$(echo "$reason" | grep -oE 'Skill\([^)]+\)' | head -1)
      ctx="PERMISSION DENIED [Bash]: Skill enforcement blocked this command.
Action: load the required skill first with ${skill:-Skill(commit)}, then retry the original command.
Do NOT attempt git commit or gh pr create directly without the skill."
    elif echo "$reason" | grep -q "ESCALATION"; then
      ctx="PERMISSION DENIED [Bash]: This action requires explicit user approval per escalation protocol.
Action: STOP and ask the user before proceeding. Do not attempt the command again."
    else
      ctx="PERMISSION DENIED [Bash]: Command blocked. Reason: ${reason}
Action: ask the user how to proceed or use an alternative approach."
    fi
    ;;
  *)
    ctx="PERMISSION DENIED [${tool}]: Tool call was blocked.
Reason: ${reason}
Action: check if an alternative tool or approach is available, or ask the user."
    ;;
esac

[ -n "$ctx" ] && jq -n --arg ctx "$ctx" '{ additionalContext: $ctx }'

exit 0
