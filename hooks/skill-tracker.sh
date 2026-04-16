#!/bin/bash
# PostToolUse hook: tracks which skills have been loaded in this session.
# Creates a state file at /tmp/claude-skills-{session_id} with one skill per line.
# Used by skill-enforcement-guard.sh and statusline to show active skill.

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# Only track Skill tool calls
[ "$tool_name" != "Skill" ] && exit 0

skill_name=$(echo "$input" | jq -r '.tool_input.skill // empty')
[ -z "$skill_name" ] && exit 0

# Use session_id for cross-process visibility (statusline reads this)
session_id=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$session_id" ]; then
  state_file="/tmp/claude-skills-${session_id}"
else
  # Fallback to PPID
  state_file="/tmp/claude-skills-${PPID}"
fi

echo "$skill_name" >> "$state_file"

exit 0
