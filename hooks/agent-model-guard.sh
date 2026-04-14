#!/bin/bash
# PreToolUse hook: blocks Agent calls without a model specified.
# Skills define their own model via frontmatter. This hook catches
# any Agent call that slips through without model: haiku/sonnet/opus.
#
# Matcher: Agent

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

[ "$tool_name" != "Agent" ] && exit 0

model=$(echo "$input" | jq -r '.tool_input.model // empty')

# If model is already specified, allow
[ -n "$model" ] && exit 0

# No model = block
subagent_type=$(echo "$input" | jq -r '.tool_input.subagent_type // empty')

jq -n --arg type "${subagent_type:-unspecified}" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("COST GUARD: Agent (" + $type + ") has no model specified. Add model: \"haiku\" (default), \"sonnet\" (implementation), or \"opus\" (investigation/deslop). Check rule 07-agent-model-defaults.md for the mapping.")
  }
}'
exit 0
