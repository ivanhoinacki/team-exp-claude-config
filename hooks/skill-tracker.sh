#!/bin/bash
# PostToolUse hook: tracks which skills have been loaded in this session.
# Creates a state file at /tmp/claude-skills-{session_id} with one skill per line.
# Used by skill-enforcement-guard.sh to verify skill loading before operations.

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# Only track Skill tool calls
[ "$tool_name" != "Skill" ] && exit 0

skill_name=$(echo "$input" | jq -r '.tool_input.skill // empty')
[ -z "$skill_name" ] && exit 0

# Use PPID as session proxy (same approach as vault-rag-tracker.sh)
state_file="/tmp/claude-skills-${PPID}"
echo "$skill_name" >> "$state_file"

exit 0
