#!/bin/bash
# PreToolUse hook: detects when Bash is used for operations that have
# better native tool alternatives (Grep, Read, Glob).
# Does NOT block, only injects a reminder via additionalContext.
#
# Patterns detected:
#   grep -rn / grep -n / grep --include  -> should use Grep tool
#   cat /path (standalone)               -> should use Read tool
#   find ... -name                        -> should use Glob tool
#   head -N / tail -N on files            -> should use Read with offset/limit

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ -z "$command" ] && exit 0

# Strip quoted strings and echo/printf content to avoid false positives on tests
clean_cmd=$(echo "$command" | sed "s/'[^']*'//g" | sed 's/"[^"]*"//g' | sed 's/echo .*//' | sed 's/printf .*//')

warnings=""

# Detect grep usage (standalone grep, not after pipe from git/docker/yarn)
if echo "$clean_cmd" | grep -qE '^\s*(grep\s+-[rnliE]|grep\s+--include)'; then
  warnings="${warnings}- Use Grep tool instead of bash grep (faster, better output, respects permissions)\n"
fi

# Detect cat for reading files (standalone cat with absolute path)
if echo "$clean_cmd" | grep -qE '^\s*cat\s+/'; then
  warnings="${warnings}- Use Read tool instead of cat (handles truncation, line numbers, images, PDFs)\n"
fi

# Detect find for file searching
if echo "$clean_cmd" | grep -qE '^\s*find\s+.*-name'; then
  warnings="${warnings}- Use Glob tool instead of find (faster pattern matching, sorted by mtime)\n"
fi

# Detect standalone head/tail on files (not in pipes)
if echo "$clean_cmd" | grep -qE '^\s*(head|tail)\s+-[0-9]+\s+/'; then
  warnings="${warnings}- Use Read tool with offset/limit instead of head/tail\n"
fi

# If warnings found, inject as context (do NOT block)
if [ -n "$warnings" ]; then
  context=$(printf "TOOL PREFERENCE: Native tools are more efficient than Bash equivalents:\n%b\nPrefer native tools (Grep, Read, Glob) in future calls." "$warnings")
  jq -n --arg ctx "$context" '{ additionalContext: $ctx }'
  exit 0
fi

exit 0
