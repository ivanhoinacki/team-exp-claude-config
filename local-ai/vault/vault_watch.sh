#!/usr/bin/env bash
# vault-watch: Watch vault directories and trigger incremental re-index on changes.
# Debounces changes to avoid re-indexing on every keystroke in Obsidian.
#
# Uses kqueue_monitor (stable on macOS) and watches only the vault root.
# CLAUDE.md files in the codebase are checked by vault-index --incremental
# via MD5 comparison, so they get picked up on the next triggered run.
#
# Usage:
#   vault-watch          # Run in foreground (Ctrl+C to stop)
#   vault-watch &        # Run in background
#
# Auto-start: see com.le.vault-watch.plist in ~/Library/LaunchAgents/

set -uo pipefail

VAULT_ROOT="${VAULT_ROOT:-$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/ObsidianDocs/Luxury-Escapes}"
CHROMA_PORT=8100
CHROMA_VENV="$HOME/.local/share/le-vault-chroma/venv"
LOG_FILE="$HOME/.local/share/le-vault-chroma/sync.log"
DEBOUNCE_SECONDS=30
LOCK_FILE="/tmp/vault-index-running.lock"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

run_incremental_index() {
  # Prevent concurrent runs
  if [ -f "$LOCK_FILE" ]; then
    log "SKIP: index already running (lock exists)"
    return
  fi

  # Check ChromaDB is up
  if ! curl -sf "http://localhost:${CHROMA_PORT}/api/v2/heartbeat" > /dev/null 2>&1; then
    log "SKIP: ChromaDB not running (port ${CHROMA_PORT})"
    return
  fi

  touch "$LOCK_FILE"
  log "Running incremental index..."
  if "${CHROMA_VENV}/bin/python3" \
     "${VAULT_INDEX_CMD:-$HOME/.claude/local-ai/vault/vault_index.py}" --incremental >> "$LOG_FILE" 2>&1; then
    log "Incremental index done"
  else
    log "Incremental index FAILED (exit $?)"
  fi
  rm -f "$LOCK_FILE"
}

log "vault-watch started (debounce: ${DEBOUNCE_SECONDS}s)"
log "Watching: $VAULT_ROOT"

# Retry loop: if fswatch crashes, wait and restart
while true; do
  LAST_RUN=0

  # Watch vault root only (not codebase, which has 80+ repos causing segfaults).
  # CLAUDE.md files from repos are indexed via MD5 diff on each incremental run.
  # --event: only trigger on Create, Updated, Removed (not access/chmod)
  # --latency: coalesce events over N seconds (primary debounce)
  # --recursive: watch subdirectories
  # --exclude: skip non-indexable paths
  fswatch \
    --event Created \
    --event Updated \
    --event Removed \
    --latency "$DEBOUNCE_SECONDS" \
    --recursive \
    --exclude '/\.(obsidian|git|DS_Store)' \
    --exclude 'Session-Memory' \
    --exclude '\.tmp$' \
    --exclude '\.log$' \
    "$VAULT_ROOT" \
    2>>"$LOG_FILE" \
    | while read -r changed_path; do
      # Only process .md files
      [[ "$changed_path" == *.md ]] || continue
      NOW=$(date +%s)
      ELAPSED=$((NOW - LAST_RUN))

      # Secondary debounce: skip if last run was < 30s ago
      if [ "$ELAPSED" -lt "$DEBOUNCE_SECONDS" ]; then
        log "Debounced: $changed_path (${ELAPSED}s since last run)"
        continue
      fi

      log "Change detected: $changed_path"
      LAST_RUN="$NOW"
      run_incremental_index
    done

  # fswatch exited (crash or signal). Wait and retry.
  log "fswatch exited (code $?), restarting in 10s..."
  sleep 10
done
