#!/bin/bash
set -e

# ============================================================================
# AI Dev Ecosystem Update
#
# Pulls latest changes and re-runs setup without the wizard.
# Personal config, learnings, and settings.json are preserved.
#
# Usage:
#   bash scripts/update.sh              # update to latest
#   bash scripts/update.sh --reconfigure  # update + re-enter personal info
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${HOME}/.claude/.team-config.json"
VERSION_FILE="${HOME}/.claude/.team-config-version"

# Check first install
if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}No existing installation found.${NC}"
  echo -e "Run ${CYAN}bash scripts/setup.sh${NC} for first-time setup."
  exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
echo -e "${CYAN}${BOLD}AI Dev Ecosystem Update${NC}"
echo -e "Current version: ${YELLOW}${CURRENT_VERSION}${NC}"
echo ""

# Pull latest
echo -e "${CYAN}Pulling latest...${NC}"
cd "$REPO_ROOT"
BEFORE=$(git rev-parse HEAD)
git pull --ff-only origin main 2>&1 || {
  echo -e "${RED}Pull failed. Resolve conflicts manually, then re-run.${NC}"
  exit 1
}
AFTER=$(git rev-parse HEAD)
NEW_VERSION=$(git describe --tags --always 2>/dev/null || echo "dev")

if [ "$BEFORE" = "$AFTER" ]; then
  echo -e "${GREEN}Already up to date ($NEW_VERSION).${NC}"
  echo ""
  echo -e "Re-run setup anyway? This refreshes all files. (y/N)"
  read -r RERUN
  if [ "$RERUN" != "y" ] && [ "$RERUN" != "Y" ]; then
    exit 0
  fi
else
  echo -e "${GREEN}Updated to ${NEW_VERSION}${NC}"
  echo ""
  echo "Changes:"
  git log --oneline "$BEFORE..$AFTER" | head -20
  echo ""
fi

# Forward flags
EXTRA_FLAGS=""
for arg in "$@"; do
  case "$arg" in
    --reconfigure) EXTRA_FLAGS="--reconfigure" ;;
  esac
done

# Detect platform and run the correct setup script
if [[ "$OSTYPE" == "darwin"* ]]; then
  bash "$REPO_ROOT/scripts/setup.sh" $EXTRA_FLAGS
else
  bash "$REPO_ROOT/scripts/setup-wsl.sh" $EXTRA_FLAGS
fi
