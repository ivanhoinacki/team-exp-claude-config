#!/bin/bash
# Pre-commit hook: runs lint + types before allowing git commit
# Triggered by PreToolUse on Bash commands matching "git commit"
# Input: JSON via stdin with tool_input.command and cwd
# Output: exit 0 = allow, JSON with permissionDecision=deny = block

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Safety: only intercept actual git commit commands
if ! echo "$command" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -z "$cwd" ] && exit 0
cd "$cwd" || exit 0

# Skip if not a Node.js project
[ ! -f "package.json" ] && exit 0

# Detect package manager: yarn > pnpm > npm
PKG_MGR="npm"
if [ -f "yarn.lock" ] && command -v yarn &>/dev/null; then
  PKG_MGR="yarn"
elif [ -f "pnpm-lock.yaml" ] && command -v pnpm &>/dev/null; then
  PKG_MGR="pnpm"
fi

errors=""

# Check if lint script exists
if jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
  lint_out=$($PKG_MGR lint 2>&1)
  if [ $? -ne 0 ]; then
    # Trim to last 30 lines to avoid flooding
    errors="${errors}LINT FAILED:\n$(echo "$lint_out" | tail -30)\n\n"
  fi
fi

# Check if types script exists
if jq -e '.scripts["test:types"]' package.json >/dev/null 2>&1; then
  types_out=$($PKG_MGR test:types 2>&1)
  if [ $? -ne 0 ]; then
    errors="${errors}TYPE CHECK FAILED:\n$(echo "$types_out" | tail -30)\n\n"
  fi
elif jq -e '.scripts.typecheck' package.json >/dev/null 2>&1; then
  types_out=$($PKG_MGR typecheck 2>&1)
  if [ $? -ne 0 ]; then
    errors="${errors}TYPE CHECK FAILED:\n$(echo "$types_out" | tail -30)\n\n"
  fi
fi

# If errors found, block the commit
if [ -n "$errors" ]; then
  reason=$(printf "Pre-commit checks failed. Fix before committing:\n\n%b" "$errors")
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi

# All checks passed
exit 0
