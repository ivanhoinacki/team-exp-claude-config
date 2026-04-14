#!/bin/bash
# PreToolUse on Read/Grep: reminds to query_vault BEFORE reading LE files.
# Only fires for LE codebase and vault paths. Zero cost elsewhere.

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // empty')

# Extract path based on tool type
case "$tool" in
  Read)
    path=$(echo "$input" | jq -r '.tool_input.file_path // empty') ;;
  Grep)
    path=$(echo "$input" | jq -r '.tool_input.path // empty') ;;
  *)
    exit 0 ;;
esac

[ -z "$path" ] && exit 0

# Only fire for LE-related paths
is_le=false
case "$path" in
  */LuxuryEscapes/*|*/Luxury-Escapes/*|*/lux-group/*)
    is_le=true ;;
esac

if [ "$is_le" = true ]; then
  # Check if query_vault was already called this session (tracking file)
  TRACK="/tmp/claude-vault-queried-$$"
  # Use parent PID as session proxy
  TRACK="/tmp/claude-vault-queried-${PPID}"

  if [ -f "$TRACK" ]; then
    # Already queried this session, don't nag
    exit 0
  fi

  read -r -d '' ctx << 'REMINDER'
VAULT RAG REMINDER: You are reading LE codebase/vault files.
BEFORE investigating code, you MUST call query_vault(query, service_filter) first.
If you already called query_vault for this task, ignore this reminder.
If not, STOP and call query_vault NOW before continuing.
REMINDER
  jq -n --arg ctx "$ctx" '{ additionalContext: $ctx }'
fi

exit 0
