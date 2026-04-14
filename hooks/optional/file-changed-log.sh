#!/bin/bash
# FileChanged hook: logs changes to monitored files.
# Useful for tracking when critical config files (rules, settings) are modified.

input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // empty')
change_type=$(echo "$input" | jq -r '.change_type // "modified"')
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

[ -z "$file_path" ] && exit 0

LOG="/tmp/claude-events-${PPID}.jsonl"

jq -n \
  --arg ts "$ts" --arg path "$file_path" --arg type "$change_type" \
  '{timestamp: $ts, event: "FileChanged", file_path: $path, change_type: $type}' \
  >> "$LOG" 2>/dev/null

# Flag changes to critical ecosystem files
case "$file_path" in
  *settings.json|*CLAUDE.md|*.cursor/rules/*|*/.claude/hooks/*)
    jq -n \
      --arg ctx "FILE CHANGED [critical]: ${file_path} was ${change_type}. If this was unintentional, review the change before proceeding." \
      '{ additionalContext: $ctx }'
    ;;
esac

exit 0
