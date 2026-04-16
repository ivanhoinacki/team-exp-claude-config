#!/usr/bin/env bash
# session-end-save.sh — Summarize a Claude Code transcript into Session-Memory
# Called by session-start-check.sh with the PREVIOUS session's breadcrumb.
# Runs in background (nohup) so it doesn't block the new session.
#
# Usage: session-end-save.sh <transcript_path> <session_id>

set -euo pipefail

TRANSCRIPT="${1:-}"
SESSION_ID="${2:-}"

# Resolve VAULT_ROOT: env var > saved config > fallback
if [ -n "${VAULT_ROOT:-}" ]; then
  VAULT="$VAULT_ROOT"
elif [ -f "$HOME/.claude/.team-config.json" ]; then
  VAULT=$(python3 -c "import json; print(json.load(open('$HOME/.claude/.team-config.json')).get('vault_root',''))" 2>/dev/null || true)
fi
VAULT="${VAULT:-$HOME/vault}"

LOG="/tmp/session-end-save.log"
MODEL="qwen2.5-coder:14b"
OLLAMA_URL="http://localhost:11434"

exec >> "$LOG" 2>&1
echo "---"

echo "[$(date +%H:%M:%S)] Session-end save started"
echo "[$(date +%H:%M:%S)] Transcript: $TRANSCRIPT"
echo "[$(date +%H:%M:%S)] Session: ${SESSION_ID:0:8}"

# Dedup check: skip if already processed
PROCESSED_FILE="$HOME/.claude/hooks/.processed-sessions"
if [[ -f "$PROCESSED_FILE" ]] && grep -qF "${SESSION_ID:0:8}" "$PROCESSED_FILE" 2>/dev/null; then
  echo "[$(date +%H:%M:%S)] Already processed, skipping"
  exit 0
fi

# Validate transcript
if [[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]]; then
  echo "[$(date +%H:%M:%S)] ERROR: Transcript not found: $TRANSCRIPT"
  exit 1
fi

TSIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d ' ')
echo "[$(date +%H:%M:%S)] Transcript size: ${TSIZE}B"

if [[ "$TSIZE" -lt 2048 ]]; then
  echo "[$(date +%H:%M:%S)] Too small (< 2KB), skipping"
  exit 0
fi

# Extract conversation context from JSONL
CONTEXT=$(python3 - "$TRANSCRIPT" << 'PYEOF'
import json, sys

transcript = sys.argv[1]
messages = []

with open(transcript) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue

        # Claude Code JSONL format: type="user"|"assistant", content in msg["message"]
        msg_type = msg.get("type", "")
        if msg_type not in ("user", "assistant"):
            continue

        message = msg.get("message", {})
        if not isinstance(message, dict):
            continue

        content = message.get("content", "")

        # Assistant content is a list of parts, user content is a string
        if isinstance(content, list):
            text_parts = []
            for part in content:
                if isinstance(part, dict) and part.get("type") == "text":
                    text_parts.append(part.get("text", ""))
            content = " ".join(text_parts)
        elif not isinstance(content, str):
            continue

        content = content.strip()
        if not content:
            continue

        # Skip system reminders and tool noise
        if "<system-reminder>" in content[:50]:
            continue
        if content.startswith("Base directory for this skill"):
            continue

        # Truncate long messages
        if len(content) > 600:
            content = content[:600] + "... [truncated]"

        label = "USER" if msg_type == "user" else "ASSISTANT"
        messages.append(f"{label}: {content}")

# Keep last 50 messages
for m in messages[-50:]:
    print(m)
PYEOF
) || true

MSG_COUNT=0
if [[ -n "$CONTEXT" ]]; then
  MSG_COUNT=$(echo "$CONTEXT" | grep -c "^USER:\|^ASSISTANT:" 2>/dev/null)
  MSG_COUNT=${MSG_COUNT:-0}
fi
echo "[$(date +%H:%M:%S)] Extracted $MSG_COUNT messages"

if [[ "$MSG_COUNT" -lt 3 ]]; then
  echo "[$(date +%H:%M:%S)] Too few messages ($MSG_COUNT), skipping"
  exit 0
fi

# Check Ollama
if ! curl -sf "$OLLAMA_URL/api/tags" > /dev/null 2>&1; then
  echo "[$(date +%H:%M:%S)] ERROR: Ollama not reachable"
  exit 1
fi

# Get transcript date from the file modification time
FILE_DATE=$(stat -f "%Sm" -t "%Y-%m-%d" "$TRANSCRIPT" 2>/dev/null || date +%Y-%m-%d)

# Build prompt
PROMPT="You are a session summarizer for a senior engineer at Luxury Escapes (Experiences vertical).
Summarize this Claude Code conversation into a Session-Memory entry.

Rules:
- Output ONLY markdown, no preamble or explanation
- Use PT-BR for descriptions, technical terms in English inline
- Be concise: max 3-5 bullets per section
- Skip sections that have no content (if no decisions, omit Decisoes)
- Include file paths, PR numbers, ticket numbers when mentioned
- Capture the WHY behind decisions, not just what was done
- Use proper PT-BR accents (nao -> nao is WRONG, use nao with tilde)

Format:

## Session (brief 3-5 word topic)

### O que foi feito
- bullet points

### Decisoes
- decisions taken (omit if none)

### Pendente
- what is left pending (omit if none)

### Arquivos modificados
- file paths changed (omit if none)

Conversation:
$CONTEXT"

# --- Helper: call Ollama and return response ---
# Log lines go to stderr (-> log file via exec), response goes to stdout (-> captured by caller)
call_ollama() {
  local label="$1"
  local prompt_text="$2"
  local max_tokens="${3:-1024}"

  echo "[$(date +%H:%M:%S)] Calling Ollama ($MODEL) for $label..." >&2

  local prompt_file
  prompt_file=$(mktemp /tmp/session-prompt-XXXXXX.txt)
  echo "$prompt_text" > "$prompt_file"

  local payload
  payload=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    prompt = f.read()
print(json.dumps({
    'model': sys.argv[2],
    'prompt': prompt,
    'stream': False,
    'options': {'temperature': 0.3, 'num_predict': int(sys.argv[3])}
}))
" "$prompt_file" "$MODEL" "$max_tokens" 2>/dev/null) || true

  rm -f "$prompt_file"

  if [[ -z "$payload" ]]; then
    echo "[$(date +%H:%M:%S)] ERROR: Failed to build payload for $label" >&2
    return 1
  fi

  local response
  response=$(curl -sf "$OLLAMA_URL/api/generate" \
    --max-time 180 \
    -d "$payload" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('response',''))" 2>/dev/null) || true

  if [[ -z "$response" ]]; then
    echo "[$(date +%H:%M:%S)] ERROR: Empty response for $label" >&2
    return 1
  fi

  echo "[$(date +%H:%M:%S)] Got $label response ($(echo "$response" | wc -c | tr -d ' ')B)" >&2
  # Only the actual response goes to stdout (captured by caller)
  echo "$response"
}

# ============================================================
# STEP 1: Session-Memory summary
# ============================================================

RESPONSE=$(call_ollama "session-memory" "$PROMPT" 1024)

if [[ -z "$RESPONSE" ]]; then
  echo "[$(date +%H:%M:%S)] Session-Memory generation failed, aborting"
  exit 1
fi

# Write to Session-Memory
SESSION_DIR="$VAULT/Knowledge-Base/Session-Memory"
SESSION_FILE="$SESSION_DIR/$FILE_DATE.md"

mkdir -p "$SESSION_DIR"

if [[ ! -f "$SESSION_FILE" ]]; then
  cat > "$SESSION_FILE" << HEADER
---
date: $FILE_DATE
type: session-memory
---

# Session Memory - $FILE_DATE

HEADER
fi

{
  echo ""
  echo "$RESPONSE"
  echo ""
  echo "_Auto-saved at $(date +%H:%M) | session ${SESSION_ID:0:8}_"
  echo ""
  echo "---"
} >> "$SESSION_FILE"

echo "[$(date +%H:%M:%S)] Session-Memory saved to $SESSION_FILE"

# Mark session as processed (dedup tracking)
PROCESSED_FILE="$HOME/.claude/hooks/.processed-sessions"
echo "${SESSION_ID:0:8}" >> "$PROCESSED_FILE"

# ============================================================
# STEP 2: Review-Learnings extraction
# ============================================================

LEARNINGS_DIR="$VAULT/Knowledge-Base/Review-Learnings"
mkdir -p "$LEARNINGS_DIR"

LEARNINGS_PROMPT="You are a senior engineering knowledge extractor for Luxury Escapes (Experiences vertical).
Analyze this conversation and extract ONLY concrete, reusable technical learnings.

A learning is:
- A bug root cause that was discovered and confirmed
- A workaround or fix for a specific technical problem
- A non-obvious configuration or setup step
- A pattern that worked well and should be reused
- A gotcha/pitfall that wasted time and should be avoided

A learning is NOT:
- A summary of what was discussed (that's Session-Memory)
- A decision about product direction
- General programming knowledge
- Something that only applies to this one session

Rules:
- Output ONLY if there are genuine learnings. If the session was just discussion/planning with no technical discoveries, output exactly: NO_LEARNINGS
- Use English for the output (code terms, file paths, service names)
- Each learning must have: What happened, Root cause/explanation, Fix/solution
- Include service names, file paths, error messages when available
- Be specific and actionable, not vague

Format (if learnings exist):

# Session Learnings - $FILE_DATE

## 1. [Short title] (HIGH/MEDIUM/LOW)

**What happened:** [description]

**Root cause:** [why it happened]

**Fix:** [how to fix or avoid]

Services: [affected services]

## 2. ...

Conversation:
$CONTEXT"

LEARNINGS_RESPONSE=$(call_ollama "review-learnings" "$LEARNINGS_PROMPT" 1536)

if [[ -n "$LEARNINGS_RESPONSE" ]]; then
  # Check if the model found actual learnings
  if echo "$LEARNINGS_RESPONSE" | grep -q "NO_LEARNINGS"; then
    echo "[$(date +%H:%M:%S)] No learnings found in this session (expected for non-technical sessions)"
  else
    # Save to Review-Learnings with session date and short ID
    LEARNINGS_FILE="$LEARNINGS_DIR/Session-${FILE_DATE}-${SESSION_ID:0:8}.md"

    # Don't overwrite if file already exists (edge case: re-processing)
    if [[ ! -f "$LEARNINGS_FILE" ]]; then
      {
        echo "---"
        echo "date: $FILE_DATE"
        echo "type: review-learning"
        echo "source: auto-extracted"
        echo "session: ${SESSION_ID:0:8}"
        echo "---"
        echo ""
        echo "$LEARNINGS_RESPONSE"
        echo ""
        echo "_Auto-extracted at $(date +%H:%M) from session ${SESSION_ID:0:8}_"
      } > "$LEARNINGS_FILE"
      echo "[$(date +%H:%M:%S)] Review-Learnings saved to $LEARNINGS_FILE"
    else
      echo "[$(date +%H:%M:%S)] Review-Learnings file already exists, skipping"
    fi
  fi
else
  echo "[$(date +%H:%M:%S)] Review-Learnings extraction failed (non-blocking)"
fi

echo "[$(date +%H:%M:%S)] Done."
