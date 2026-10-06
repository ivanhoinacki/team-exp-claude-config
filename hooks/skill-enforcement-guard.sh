#!/bin/bash
# PreToolUse hook: flags destructive commands. Skills are guides, not approval gates.
#
# Exit 0 with JSON deny = block. Exit 0 without output = allow.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ -z "$command" ] && exit 0

# Use session_id for cross-process visibility, fallback to PPID
session_id=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$session_id" ]; then
  state_file="/tmp/claude-skills-${session_id}"
else
  state_file="/tmp/claude-skills-${PPID}"
fi

# Strip content inside quotes and after echo/printf/cat to avoid false positives
# on test commands like: echo '{"command":"git commit"}' | ./script.sh
clean_cmd=$(echo "$command" | sed "s/'[^']*'//g" | sed 's/"[^"]*"//g' | sed 's/echo .*//' | sed 's/printf .*//')

# Decompose compound command into sub-commands for individual evaluation.
# Handles: &&, ||, ;, | (in that order to avoid double-splitting ||)
# Each sub-command is trimmed and checked independently.
subcmds=$(printf '%s' "$clean_cmd" \
  | sed 's/||/\n/g' \
  | sed 's/&&/\n/g' \
  | sed 's/;/\n/g' \
  | sed 's/|/\n/g')

# cmd_matches PATTERN - returns 0 if ANY sub-command matches the ERE pattern.
# Uses here-string to avoid subshell so break/return work correctly.
cmd_matches() {
  local pattern="$1"
  local found=1
  while IFS= read -r sub; do
    sub=$(echo "$sub" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    [ -z "$sub" ] && continue
    if echo "$sub" | grep -qE "$pattern"; then
      found=0
      break
    fi
  done <<< "$subcmds"
  return $found
}

# Commit/push approval is governed by the user and operational rule.

# Check: destructive commands
if cmd_matches '\bgit\s+reset\s+--hard\b|\brm\s+-rf\b|\bgit\s+clean\s+-f'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "ESCALATION: Destructive command detected. Ask the user before proceeding. Consider safer alternatives."
    }
  }'
  exit 0
fi

# Check: git stash (warn)
if cmd_matches '\bgit\s+stash\b'; then
  jq -n --arg ctx "WARNING: git stash can lose uncommitted work if followed by checkout. Consider committing WIP to a branch instead. Ask the user before stashing." \
    '{ additionalContext: $ctx }'
  exit 0
fi

exit 0
