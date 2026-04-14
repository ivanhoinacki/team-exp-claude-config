#!/usr/bin/env bash
# CI Local Check - runs the same checks that CI will run, in order.
# Used by: /create-pr, /code-review
#
# Usage: ci-local-check.sh [--help] [project-dir]
#   project-dir: path to the project root (default: current directory)
#
# Reads package.json to auto-detect available scripts and runs them in order:
#   1. Lint (yarn lint)
#   2. Type check (yarn test:types)
#   3. Build (yarn build)
#   4. Unit tests (yarn test:unit or yarn test)
#
# Exit codes:
#   0 = all checks passed
#   1 = one or more checks failed (details printed to stderr)

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  sed -n '2,/^$/p' "$0" | sed 's/^# *//'
  exit 0
fi

PROJECT_DIR="${1:-.}"
PKG_JSON="$PROJECT_DIR/package.json"

if [[ ! -f "$PKG_JSON" ]]; then
  echo "ERROR: No package.json found at $PKG_JSON" >&2
  exit 1
fi

# Auto-switch Node version if .nvmrc exists (prevents "engine incompatible" errors)
if [[ -f "$PROJECT_DIR/.nvmrc" ]]; then
  REQUIRED_NODE=$(cat "$PROJECT_DIR/.nvmrc" | tr -d '[:space:]')
  CURRENT_NODE=$(node -v 2>/dev/null | sed 's/^v//')
  if [[ "$CURRENT_NODE" != "$REQUIRED_NODE" ]]; then
    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
      # shellcheck disable=SC1091
      source "$HOME/.nvm/nvm.sh" 2>/dev/null
      nvm use "$REQUIRED_NODE" 2>/dev/null || nvm install "$REQUIRED_NODE" 2>/dev/null
      echo "==> Switched Node: v${CURRENT_NODE} -> v${REQUIRED_NODE}"
    else
      echo "WARNING: .nvmrc requires Node $REQUIRED_NODE but current is $CURRENT_NODE and nvm not found" >&2
    fi
  fi
fi

SCRIPTS=$(node -e "const p=require('$PKG_JSON'); console.log(JSON.stringify(p.scripts||{}))")

has_script() {
  echo "$SCRIPTS" | node -e "const s=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.exit(s['$1'] ? 0 : 1)"
}

FAILED=()
PASSED=()
SKIPPED=()

run_check() {
  local name="$1"
  local script="$2"

  if has_script "$script"; then
    echo "==> Running $name (yarn $script)..."
    if (cd "$PROJECT_DIR" && yarn "$script" 2>&1); then
      PASSED+=("$name")
      echo "==> $name PASSED"
    else
      FAILED+=("$name")
      echo "==> $name FAILED" >&2
    fi
  else
    SKIPPED+=("$name")
  fi
}

# Run in CI order
run_check "Lint" "lint"
run_check "Type check" "test:types"
run_check "Build" "build"

# Unit tests: prefer test:unit, fallback to test
if has_script "test:unit"; then
  run_check "Unit tests" "test:unit"
elif has_script "test"; then
  run_check "Unit tests" "test"
else
  SKIPPED+=("Unit tests")
fi

# Summary
echo ""
echo "=== CI Local Check Summary ==="
[[ ${#PASSED[@]} -gt 0 ]] && echo "PASSED:  ${PASSED[*]}"
[[ ${#SKIPPED[@]} -gt 0 ]] && echo "SKIPPED: ${SKIPPED[*]}"
[[ ${#FAILED[@]} -gt 0 ]] && echo "FAILED:  ${FAILED[*]}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo ""
  echo "EXIT: ${#FAILED[@]} check(s) failed. Fix before proceeding." >&2
  exit 1
fi

echo ""
echo "All checks passed."
exit 0
