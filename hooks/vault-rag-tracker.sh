#!/bin/bash
# PostToolUse on mcp__local-le-chromadb__query_vault:
# Marks that vault was queried this session so the reminder hook stops firing.

TRACK="/tmp/claude-vault-queried-${PPID}"
touch "$TRACK"
exit 0
