#!/bin/bash
# Session start: process unprocessed previous sessions + verify tool connectivity
# Scans recent transcripts and summarizes any missing from Session-Memory.

# Resolve VAULT_ROOT: env var > saved config > fallback
if [ -n "${VAULT_ROOT:-}" ]; then
  VAULT="$VAULT_ROOT"
elif [ -f "$HOME/.claude/.team-config.json" ]; then
  VAULT=$(python3 -c "import json; print(json.load(open('$HOME/.claude/.team-config.json')).get('vault_root',''))" 2>/dev/null || true)
fi
VAULT="${VAULT:-$HOME/vault}"
PROJECT_DIR="$HOME/.claude/projects"
TODAY=$(date +%Y-%m-%d)
SESSION_FILE="$VAULT/Knowledge-Base/Session-Memory/$TODAY.md"

# --- Read hook input to get current session_id ---
CURRENT_SESSION=""
INPUT=$(timeout 1 cat 2>/dev/null || true)
if [[ -n "$INPUT" ]]; then
  CURRENT_SESSION=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || true)
fi

# --- Process previous sessions (background, non-blocking) ---
# Find transcripts modified in last 18h, > 2KB, not subagents
PROCESSED_FILE="$HOME/.claude/hooks/.processed-sessions"
UNPROCESSED=$(python3 - "$PROJECT_DIR" "$PROCESSED_FILE" "$CURRENT_SESSION" << 'PYEOF'
import sys, os, time

project_dir = sys.argv[1]
processed_file = sys.argv[2]
current_session = sys.argv[3]

# Get already-processed session IDs from tracking file
processed = set()
if os.path.exists(processed_file):
    with open(processed_file) as f:
        for line in f:
            sid = line.strip()
            if sid:
                processed.add(sid)

# Scan for recent transcripts
cutoff = time.time() - (18 * 3600)  # last 18 hours
candidates = []

for root, dirs, files in os.walk(project_dir):
    # Skip subagent transcripts
    if 'subagents' in root:
        continue
    for f in files:
        if not f.endswith('.jsonl'):
            continue
        path = os.path.join(root, f)
        stat = os.stat(path)
        # Skip too old, too small
        if stat.st_mtime < cutoff or stat.st_size < 2048:
            continue
        session_id = f.replace('.jsonl', '')
        # Skip current session
        if current_session and session_id.startswith(current_session[:8]):
            continue
        # Skip already processed
        if session_id[:8] in processed:
            continue
        candidates.append((stat.st_mtime, path, session_id))

# Sort by modification time (most recent first), take up to 2
candidates.sort(key=lambda x: -x[0])
for _, path, sid in candidates[:2]:
    print(f"{sid}|{path}")
PYEOF
) || true

if [[ -n "$UNPROCESSED" ]]; then
  echo "  Auto-saving previous session(s) to Session-Memory..." >&2
  # Process sequentially in a single background job (avoids parallel Ollama contention)
  BATCH_SCRIPT=$(mktemp /tmp/session-batch-XXXXXX.sh)
  chmod +x "$BATCH_SCRIPT"
  {
    echo '#!/bin/bash'
    while IFS='|' read -r sid path; do
      if [[ -n "$sid" && -n "$path" ]]; then
        echo "  → session ${sid:0:8} ($(( $(wc -c < "$path" 2>/dev/null | tr -d ' ') / 1024 ))KB)" >&2
        # Only call session-end-save.sh if it exists (optional hook, not installed by default)
        if [ -f "$HOME/.claude/hooks/session-end-save.sh" ]; then
          echo "\"$HOME/.claude/hooks/session-end-save.sh\" \"$path\" \"$sid\""
        fi
      fi
    done <<< "$UNPROCESSED"
    echo "rm -f \"$BATCH_SCRIPT\""
  } > "$BATCH_SCRIPT"
  nohup bash "$BATCH_SCRIPT" > /dev/null 2>&1 &
  disown 2>/dev/null || true
  echo "  Background processing started (log: /tmp/session-end-save.log)" >&2
fi

# --- Also process legacy breadcrumb if present ---
BREADCRUMB="/tmp/claude-session-breadcrumb.json"
if [[ -f "$BREADCRUMB" ]]; then
  rm -f "$BREADCRUMB"
fi

# --- Environment check ---
echo "Environment check:" >&2

# GitHub CLI
if gh auth status 2>/dev/null | grep -q "Logged in"; then
  echo "  GitHub CLI: OK" >&2
else
  echo "  WARN: GitHub CLI not authenticated. Run: gh auth login" >&2
fi

# CircleCI
if [ -f ~/.circleci/cli.yml ] && grep -q "token:" ~/.circleci/cli.yml; then
  echo "  CircleCI: OK" >&2
else
  echo "  WARN: CircleCI not configured. Run: circleci setup" >&2
fi

# AWS CLI
if [ -f ~/.aws/config ]; then
  echo "  AWS CLI: OK" >&2
else
  echo "  WARN: AWS CLI not configured" >&2
fi

exit 0
