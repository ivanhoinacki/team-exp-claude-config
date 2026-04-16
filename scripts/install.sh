#!/bin/bash
set -e

# ============================================================================
# Quick Install - Clone repo and run full setup
# Detects platform: macOS -> setup.sh | Linux/WSL2 -> setup-wsl.sh
# Usage: curl -sSL https://raw.githubusercontent.com/ivanhoinacki/team-exp-claude-config/v1.1.0/scripts/install.sh | bash
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}AI Dev Ecosystem${NC}"
echo ""

# Detect platform
PLATFORM=""
if [[ "$OSTYPE" == "darwin"* ]]; then
  PLATFORM="macos"
elif grep -qi microsoft /proc/version 2>/dev/null; then
  PLATFORM="wsl"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  PLATFORM="linux"
else
  echo -e "${RED}Unsupported platform: $OSTYPE${NC}"
  echo "Run setup manually: bash scripts/setup.sh (macOS) or bash scripts/setup-wsl.sh (Linux/WSL2)"
  exit 1
fi

echo -e "${CYAN}Platform: ${BOLD}$PLATFORM${NC}"
echo ""

# Clone repo to standard location
REPO_DIR="$HOME/Documents/LuxuryEscapes/team-exp-claude-config"
mkdir -p "$(dirname "$REPO_DIR")"

if [ -d "$REPO_DIR/.git" ]; then
  echo "Updating existing config..."
  cd "$REPO_DIR" && git pull origin main 2>/dev/null
else
  echo "Cloning team config..."
  git clone git@github.com:ivanhoinacki/team-exp-claude-config.git "$REPO_DIR" 2>/dev/null || \
  git clone https://github.com/ivanhoinacki/team-exp-claude-config.git "$REPO_DIR"
fi

# Run platform-specific setup
cd "$REPO_DIR"
if [ "$PLATFORM" = "macos" ]; then
  bash scripts/setup.sh
else
  bash scripts/setup-wsl.sh
fi

echo -e "${GREEN}${BOLD}Done!${NC}"
