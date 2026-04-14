#!/bin/bash
# PreCompact hook: creates a snapshot of the transcript before compaction.
# Protects against context loss during auto-compaction on rate limits.
# Non-blocking: any failure just exits 0 (no obstruction).

input=$(cat)
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
trigger=$(echo "$input" | jq -r '.trigger // "auto"')

[ -z "$transcript" ] && exit 0
[ ! -f "$transcript" ] && exit 0

# Backup dir inside /tmp (cleaned on reboot, enough for session protection)
BACKUP_DIR="/tmp/claude-compact-backups"
mkdir -p "$BACKUP_DIR"

timestamp=$(date +%Y%m%d-%H%M%S)
backup_file="${BACKUP_DIR}/transcript-${trigger}-${timestamp}.jsonl"

cp "$transcript" "$backup_file" 2>/dev/null

# Keep only last 5 backups to avoid filling /tmp
ls -t "${BACKUP_DIR}"/transcript-*.jsonl 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null

exit 0
