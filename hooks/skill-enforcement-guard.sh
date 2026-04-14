#!/bin/bash
# PreToolUse hook: blocks git commit and gh pr create if the required skill
# was not loaded first. Checks the state file written by skill-tracker.sh.
#
# Rules:
#   git commit  -> requires /commit skill
#   gh pr create -> requires /create-pr skill
#
# Exit 0 with JSON deny = block. Exit 0 without output = allow.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ -z "$command" ] && exit 0

# Use PPID as session proxy (same approach as vault-rag-tracker.sh)
state_file="/tmp/claude-skills-${PPID}"

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

# Check: git commit without /commit skill
if cmd_matches '\bgit\s+commit\b'; then
  if [ ! -f "$state_file" ] || ! grep -q "^commit$" "$state_file" 2>/dev/null; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "SKILL ENFORCEMENT: You must load the /commit skill (via Skill tool) before running git commit. The skill contains format rules, verification checklists, and quality gates. Run Skill(commit) first, then retry."
      }
    }'
    exit 0
  fi
fi

# Check: gh pr create without /create-pr skill
if cmd_matches '\bgh\s+pr\s+create\b'; then
  if [ ! -f "$state_file" ] || ! grep -q "^create-pr$" "$state_file" 2>/dev/null; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "SKILL ENFORCEMENT: You must load the /create-pr skill (via Skill tool) before running gh pr create. The skill includes mandatory sequence diagrams, pre-checks, and PR template. Run Skill(create-pr) first, then retry."
      }
    }'
    exit 0
  fi
fi

# Check: git push - allow in worktrees, block on main checkouts
if cmd_matches '\bgit\s+push\b'; then
  # Detect if command targets a worktree (path contains "--" pattern like repo--feature)
  is_worktree=false
  if echo "$command" | grep -qE 'cd\s+[^\s]*--[^\s]*'; then
    is_worktree=true
  fi
  if [ "$is_worktree" = false ]; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "ESCALATION: git push on main checkout requires explicit user approval. Ask the user before pushing. (Hint: pushes from worktree directories like repo--feature are allowed automatically.)"
      }
    }'
    exit 0
  fi
fi

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

# Check: git checkout -b on main repos (should use worktree)
if cmd_matches '\bgit\s+checkout\s+-b\b'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "ESCALATION: git checkout -b detected. Feature development should use git worktrees, not branches on the main checkout. Ask the user: (1) should I create a worktree with `git worktree add ../REPO--FEATURE -b BRANCH`? (2) or is this intentional on the main checkout?"
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
