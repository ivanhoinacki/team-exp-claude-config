#!/usr/bin/env bash
# Hook: PreToolUse/Bash - blocks "le aws postgres" and tells the agent to use le-tunnel.sh
# The rule in 08-behavioral-standards.md says NEVER use "le aws postgres" directly.

set -euo pipefail

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

[[ "$TOOL_NAME" == "Bash" ]] || exit 0

# Extract the command from JSON input
CMD=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "")

if echo "$CMD" | grep -qE 'le aws postgres'; then
  cat <<'EOF'
BLOCKED: "le aws postgres" is not allowed. Use le-tunnel.sh instead:

  ~/bin/le-tunnel.sh -s <service> -d <database> [-p 5555] [-m ro|rw]

Examples:
  ~/bin/le-tunnel.sh -s svc-experiences -d svc_experiences -m ro
  ~/bin/le-tunnel.sh -s svc-order -d svc_order -m ro -p 5556

Then query via: psql -h 127.0.0.1 -p 5555 -U postgres -d <database>
Or: PGPASSWORD=... psql "postgresql://user@127.0.0.1:5555/db"

Wait ~20s after starting the tunnel before querying.
EOF
  exit 2
fi

exit 0
