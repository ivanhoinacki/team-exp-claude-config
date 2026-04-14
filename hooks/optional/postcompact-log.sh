#!/bin/bash
# PostCompact hook: logs confirmation after compaction completes.
# Also checks if precompact-backup.sh created a backup for this session.

input=$(cat)
summary=$(echo "$input" | jq -r '.summary // "no summary available"')
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG="/tmp/claude-events-${PPID}.jsonl"

# Truncate summary to first 200 chars for the log
short_summary=$(echo "$summary" | head -c 200)

jq -n \
  --arg ts "$ts" --arg summary "$short_summary" \
  '{timestamp: $ts, event: "PostCompact", summary: $summary}' \
  >> "$LOG" 2>/dev/null

# Check if a backup exists from precompact-backup.sh
backup_count=$(ls /tmp/claude-compact-backups/transcript-*.jsonl 2>/dev/null | wc -l | tr -d ' ')
if [ "$backup_count" -gt 0 ]; then
  latest=$(ls -t /tmp/claude-compact-backups/transcript-*.jsonl 2>/dev/null | head -1)
  echo "PostCompact: compaction complete. Backup available at $latest" >> "$LOG"
fi

exit 0
