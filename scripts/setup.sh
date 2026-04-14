#!/bin/bash

# ============================================================================
# AI Dev Ecosystem Setup - Luxury Escapes
#
# Configures: rules, skills, agents, MCP servers, hooks, settings, ChromaDB vault-rag
# Works with: Claude Code + Cursor
# Run from repo root: bash scripts/setup.sh
#
# Flags:
#   --reconfigure    Re-enter personal info (name, email, token, paths)
#   --force          Skip confirmation prompt
# ============================================================================

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME}"
CONFIG_FILE="$CLAUDE_HOME/.claude/.team-config.json"
VERSION_FILE="$CLAUDE_HOME/.claude/.team-config-version"
BACKUP_DIR="$CLAUDE_HOME/.claude/.setup-backup-$(date +%Y%m%d-%H%M%S)"
REPO_VERSION=$(git -C "$REPO_ROOT" describe --tags --always 2>/dev/null || echo "dev")

# --- Parse flags ---
RECONFIGURE=false
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --reconfigure) RECONFIGURE=true ;;
    --force) FORCE=true ;;
  esac
done

# --- Output helpers ---
print_header() { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}\n"; }
print_ok() { echo -e "${GREEN}  ✓${NC} $1"; }
print_warn() { echo -e "${YELLOW}  !${NC} $1"; }
print_error() { echo -e "${RED}  ✗${NC} $1"; }
print_info() { echo -e "${BLUE}  i${NC} $1"; }

# --- Error handling (replaces set -e) ---
PHASES_COMPLETED=()

phase_fail() {
  local phase="$1"
  local msg="$2"
  print_error "Phase $phase failed: $msg"
  echo ""
  echo -e "${YELLOW}Completed phases: ${PHASES_COMPLETED[*]:-none}${NC}"
  echo -e "${YELLOW}Failed at: Phase $phase${NC}"
  if [ -d "$BACKUP_DIR" ]; then
    echo -e "${CYAN}Backup available at: $BACKUP_DIR${NC}"
    echo -e "${CYAN}Restore with: cp -r $BACKUP_DIR/.claude/* ~/.claude/${NC}"
  fi
  echo ""
  echo -e "${RED}Setup incomplete. Fix the issue above and re-run.${NC}"
  exit 1
}

phase_ok() {
  PHASES_COMPLETED+=("$1")
}

# --- Input validation helpers ---
validate_email() {
  local email="$1"
  if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    return 1
  fi
  return 0
}

validate_slack_id() {
  local sid="$1"
  if [[ ! "$sid" =~ ^U[A-Z0-9]{8,}$ ]]; then
    return 1
  fi
  return 0
}

validate_slack_dm_id() {
  local did="$1"
  # Optional: empty is OK, but if provided must start with D
  [ -z "$did" ] && return 0
  [[ "$did" =~ ^D[A-Z0-9]{8,}$ ]]
}

validate_not_empty() {
  local val="$1"
  if [ -z "$(echo "$val" | tr -d '[:space:]')" ]; then
    return 1
  fi
  return 0
}

validate_directory() {
  local dir="$1"
  # Expand ~ to $HOME
  dir="${dir/#\~/$HOME}"
  if [ -d "$dir" ]; then
    return 0
  fi
  # Directory doesn't exist: offer to create
  echo ""
  read -p "    Directory not found: $dir. Create it? (y/n) [y]: " CREATE_DIR
  CREATE_DIR="${CREATE_DIR:-y}"
  if [ "$CREATE_DIR" = "y" ] || [ "$CREATE_DIR" = "Y" ]; then
    if mkdir -p "$dir" 2>/dev/null; then
      echo -e "    ${GREEN}Created: $dir${NC}"
      return 0
    else
      echo -e "    ${RED}Failed to create: $dir (check permissions)${NC}"
      return 1
    fi
  fi
  return 1
}

# Prompt with validation and retry
prompt_validated() {
  local prompt_text="$1"
  local var_name="$2"
  local validator="$3"
  local error_msg="$4"
  local default_val="${5:-}"
  local is_secret="${6:-false}"
  local value=""

  while true; do
    if [ "$is_secret" = "true" ]; then
      read -sp "  $prompt_text" value
      echo ""
    elif [ -n "$default_val" ]; then
      read -p "  $prompt_text [$default_val]: " value
      value="${value:-$default_val}"
    else
      read -p "  $prompt_text" value
    fi

    # Trim whitespace
    value="$(echo "$value" | xargs)"

    if $validator "$value"; then
      printf -v "$var_name" '%s' "$value"
      return 0
    else
      print_error "$error_msg"
      echo ""
    fi
  done
}

# --- Detect install vs update ---
IS_UPDATE=false
if [ -f "$CONFIG_FILE" ] && [ "$RECONFIGURE" = "false" ] && [ "$SETUP_TEST_MODE" != "1" ]; then
  IS_UPDATE=true
  INSTALLED_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
  print_header "AI Dev Ecosystem Update"
  echo "Source: $REPO_ROOT"
  echo -e "Installed: ${YELLOW}${INSTALLED_VERSION}${NC} -> New: ${GREEN}${REPO_VERSION}${NC}"
  echo -e "Config: $CONFIG_FILE (preserved)"
  echo -e "Run with ${BOLD}--reconfigure${NC} to re-enter personal info"
  echo ""
else
  print_header "AI Dev Ecosystem Setup"
  echo "Source: $REPO_ROOT"
  if [ "$RECONFIGURE" = "true" ] && [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Reconfigure mode: will re-ask personal info${NC}"
  fi
  echo ""
fi

# ============================================================================
# Phase 0: Prerequisites
# ============================================================================
print_header "Phase 0: Prerequisites"
PREREQ_OK=true
if [ "$SETUP_TEST_MODE" != "1" ]; then
  for cmd in claude node git npx python3; do
    if command -v $cmd &>/dev/null; then
      print_ok "$cmd ($(command -v $cmd))"
    else
      print_error "$cmd not found. Install it before continuing."
      PREREQ_OK=false
    fi
  done
  if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null 2>&1; then
      print_ok "GitHub CLI: authenticated"
    else
      print_warn "GitHub CLI: not authenticated (run 'gh auth login')"
    fi
  else
    print_error "GitHub CLI (gh) not found. Install: https://cli.github.com"
    PREREQ_OK=false
  fi
  if command -v docker &>/dev/null; then
    if docker info &>/dev/null 2>&1; then
      print_ok "Docker: running"
    else
      print_warn "Docker: installed but not running"
    fi
  else
    print_warn "Docker: not found (needed for ChromaDB)"
  fi

  if [ "$PREREQ_OK" = "false" ]; then
    phase_fail "0" "Missing prerequisites. Install the tools above and re-run."
  fi
else
  print_ok "Test mode: prerequisites skipped"
fi
phase_ok "0-prereq"

# ============================================================================
# Phase 1: Personal Info
# ============================================================================
print_header "Phase 1: Personal Information"
if [ "$SETUP_TEST_MODE" != "1" ]; then
  if [ "$IS_UPDATE" = "true" ]; then
    # Update mode: load saved config (with safe Python parsing)
    if python3 -c "import json; json.load(open('$CONFIG_FILE'))" 2>/dev/null; then
      USER_FULL_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('name',''))")
      USER_EMAIL=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('email',''))")
      SLACK_USER_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('slack_id',''))")
      ATLASSIAN_TOKEN=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('atlassian_token',''))")
      CODEBASE_ROOT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('codebase_root',''))")
      VAULT_ROOT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('vault_root',''))")
      USE_CURSOR=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('use_cursor','n'))")
      INSTALL_LOCAL_AI=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('install_local_ai','n'))")
      SLACK_DM_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('slack_dm_id','__SLACK_DM_ID__'))")
      TEAM_VERTICALS=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('team_verticals','Experiences + White Label + Car Hire'))")
      print_ok "Loaded from saved config"
      print_info "$USER_FULL_NAME <$USER_EMAIL>"
      if [ "$SLACK_DM_ID" = "__SLACK_DM_ID__" ]; then
        print_info "Slack DM ID not configured — run setup.sh --reconfigure to set it"
      fi
    else
      print_error "Config file corrupted. Switching to interactive mode."
      IS_UPDATE=false
    fi
  fi

  if [ "$IS_UPDATE" = "false" ]; then
    # First install or reconfigure: interactive wizard with validation
    echo -e "  ${BOLD}Fill in your details (with validation):${NC}"
    echo ""

    # --- Full name ---
    prompt_validated "Full name: " USER_FULL_NAME validate_not_empty \
      "Name cannot be empty"

    # --- Email ---
    echo ""
    echo -e "  ${BLUE}Your Luxury Escapes email (e.g. your.name@luxuryescapes.com)${NC}"
    prompt_validated "LE email: " USER_EMAIL validate_email \
      "Invalid email format (expected: name@luxuryescapes.com)"

    # --- Slack User ID ---
    echo ""
    echo -e "  ${BLUE}How to find your Slack User ID:${NC}"
    echo -e "  1. Open Slack -> click your profile picture (bottom-left)"
    echo -e "  2. Click 'Profile' -> click the '...' (more) button"
    echo -e "  3. Click 'Copy member ID' (starts with U, e.g. U0ACKPKRM3N)"
    echo -e "  ${CYAN}Or: https://luxgroup-hq.slack.com -> Profile -> Copy member ID${NC}"
    prompt_validated "Slack User ID: " SLACK_USER_ID validate_slack_id \
      "Invalid format. Must start with U followed by 8+ chars (e.g. U0ACKPKRM3N)"

    # --- Atlassian API Token ---
    echo ""
    echo -e "  ${BLUE}Atlassian API Token (for Jira + Confluence MCP access):${NC}"
    echo -e "  1. Open: ${CYAN}https://id.atlassian.com/manage-profile/security/api-tokens${NC}"
    echo -e "  2. Click 'Create API token'"
    echo -e "  3. Label: 'claude-code' (or anything descriptive)"
    echo -e "  4. Copy the generated token"
    prompt_validated "Token: " ATLASSIAN_TOKEN validate_not_empty \
      "Token cannot be empty. Generate one at the URL above." "" "true"

    # --- Codebase root ---
    echo ""
    echo -e "  ${BLUE}Where are your LE repos cloned? (e.g. ~/Documents/LuxuryEscapes)${NC}"
    echo -e "  Should contain folders like: svc-experiences, www-le-customer, svc-order, etc."
    prompt_validated "Codebase root: " CODEBASE_ROOT validate_directory \
      "Directory not found. Create it or check the path. Expected: ~/Documents/LuxuryEscapes" "$HOME/Documents/LuxuryEscapes"

    # --- Vault root ---
    echo ""
    echo -e "  ${BLUE}Where is your Obsidian vault? (team knowledge base)${NC}"
    echo -e "  If you don't have one yet, create an empty folder and we'll set it up."
    prompt_validated "Obsidian vault root: " VAULT_ROOT validate_directory \
      "Directory not found. Create it first or check the path." "$HOME/Documents/vault"

    # --- Slack DM Channel ID (optional) ---
    echo ""
    echo -e "  ${BLUE}Slack DM Channel ID (so Claude can send you direct messages):${NC}"
    echo -e "  1. Open Slack -> click your own DM conversation"
    echo -e "  2. Click the channel name at the top"
    echo -e "  3. Scroll to the bottom of the popup, copy the Channel ID (starts with D)"
    echo -e "  ${CYAN}Leave empty to skip (you can add later in rules/00-global-style.md)${NC}"
    prompt_validated "Slack DM Channel ID: " SLACK_DM_ID validate_slack_dm_id \
      "Invalid format. Must start with D followed by 8+ chars, or leave empty." ""
    SLACK_DM_ID="${SLACK_DM_ID:-__SLACK_DM_ID__}"

    # --- Team verticals ---
    echo ""
    echo -e "  ${BLUE}Your team's verticals (used in agent/copilot context):${NC}"
    read -p "  Team verticals [Experiences + White Label + Car Hire]: " TEAM_VERTICALS
    TEAM_VERTICALS="${TEAM_VERTICALS:-Experiences + White Label + Car Hire}"

    # Cursor and Local AI preferences (saved for updates)
    echo ""
    read -p "  Use Cursor IDE? (y/n) [n]: " USE_CURSOR
    USE_CURSOR="${USE_CURSOR:-n}"

    read -p "  Install Local AI layer (ChromaDB + Ollama vault RAG)? (y/n) [n]: " INSTALL_LOCAL_AI
    INSTALL_LOCAL_AI="${INSTALL_LOCAL_AI:-n}"

    # Confirmation before proceeding
    echo ""
    echo -e "  ${BOLD}Review your settings:${NC}"
    echo "    Name:          $USER_FULL_NAME"
    echo "    Email:         $USER_EMAIL"
    echo "    Slack ID:      $SLACK_USER_ID"
    echo "    Token:         ${ATLASSIAN_TOKEN:0:8}..."
    echo "    Codebase:      $CODEBASE_ROOT"
    echo "    Vault:         $VAULT_ROOT"
    echo "    Slack DM:      ${SLACK_DM_ID}"
    echo "    Verticals:     $TEAM_VERTICALS"
    echo "    Cursor:        $USE_CURSOR"
    echo "    Local AI:      $INSTALL_LOCAL_AI"
    echo ""

    if [ "$FORCE" != "true" ]; then
      read -p "  Proceed? (y/n) [y]: " CONFIRM
      CONFIRM="${CONFIRM:-y}"
      if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo ""
        echo "Setup cancelled. Re-run to try again."
        exit 0
      fi
    fi

    print_ok "Info collected"
  fi
else
  USER_FULL_NAME="${USER_FULL_NAME:-Test User}"
  USER_EMAIL="${USER_EMAIL:-test@luxuryescapes.com}"
  SLACK_USER_ID="${SLACK_USER_ID:-U0TEST123}"
  ATLASSIAN_TOKEN="${ATLASSIAN_TOKEN:-test-token-123}"
  CODEBASE_ROOT="${CODEBASE_ROOT:-$CLAUDE_HOME/Documents/LuxuryEscapes}"
  VAULT_ROOT="${VAULT_ROOT:-$CLAUDE_HOME/vault}"
  USE_CURSOR="${USE_CURSOR:-n}"
  INSTALL_LOCAL_AI="${INSTALL_LOCAL_AI:-n}"
  SLACK_DM_ID="${SLACK_DM_ID:-__SLACK_DM_ID__}"
  TEAM_VERTICALS="${TEAM_VERTICALS:-Experiences + White Label + Car Hire}"
fi

# Save config (safe JSON via Python, avoids heredoc injection)
mkdir -p "$(dirname "$CONFIG_FILE")"
python3 -c "
import json, sys
config = {
    'name': sys.argv[1],
    'email': sys.argv[2],
    'slack_id': sys.argv[3],
    'atlassian_token': sys.argv[4],
    'codebase_root': sys.argv[5],
    'vault_root': sys.argv[6],
    'use_cursor': sys.argv[7],
    'install_local_ai': sys.argv[8],
    'installed_at': sys.argv[9],
    'slack_dm_id': sys.argv[11],
    'team_verticals': sys.argv[12]
}
with open(sys.argv[10], 'w') as f:
    json.dump(config, f, indent=2)
" "$USER_FULL_NAME" "$USER_EMAIL" "$SLACK_USER_ID" "$ATLASSIAN_TOKEN" \
  "$CODEBASE_ROOT" "$VAULT_ROOT" "$USE_CURSOR" "$INSTALL_LOCAL_AI" \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$CONFIG_FILE" "$SLACK_DM_ID" "$TEAM_VERTICALS" \
  || phase_fail "1" "Failed to save config"
print_ok "Config saved to $CONFIG_FILE"
phase_ok "1-info"

# ============================================================================
# Backup existing installation (for rollback)
# ============================================================================
print_header "Backup: Existing Setup"
if [ "$SETUP_TEST_MODE" != "1" ]; then
  HAS_EXISTING=0
  [ -d "$CLAUDE_HOME/.claude/rules" ] && HAS_EXISTING=1
  [ -d "$CLAUDE_HOME/.claude/skills" ] && HAS_EXISTING=1
  [ -f "$CLAUDE_HOME/.claude/settings.json" ] && HAS_EXISTING=1
  [ -f "$CLAUDE_HOME/.claude.json" ] && HAS_EXISTING=1

  if [ "$HAS_EXISTING" = "1" ]; then
    mkdir -p "$BACKUP_DIR"
    [ -d "$CLAUDE_HOME/.claude/rules" ] && cp -r "$CLAUDE_HOME/.claude/rules" "$BACKUP_DIR/" 2>/dev/null && print_ok "Rules backed up"
    [ -d "$CLAUDE_HOME/.claude/skills" ] && cp -r "$CLAUDE_HOME/.claude/skills" "$BACKUP_DIR/" 2>/dev/null && print_ok "Skills backed up"
    [ -d "$CLAUDE_HOME/.claude/agents" ] && cp -r "$CLAUDE_HOME/.claude/agents" "$BACKUP_DIR/" 2>/dev/null && print_ok "Agents backed up"
    [ -d "$CLAUDE_HOME/.claude/hooks" ] && cp -r "$CLAUDE_HOME/.claude/hooks" "$BACKUP_DIR/" 2>/dev/null && print_ok "Hooks backed up"
    [ -f "$CLAUDE_HOME/.claude/settings.json" ] && cp "$CLAUDE_HOME/.claude/settings.json" "$BACKUP_DIR/" 2>/dev/null && print_ok "settings.json backed up"
    [ -f "$CLAUDE_HOME/.claude.json" ] && cp "$CLAUDE_HOME/.claude.json" "$BACKUP_DIR/" 2>/dev/null && print_ok "claude.json backed up"
    print_info "Backup: $BACKUP_DIR"
  else
    print_info "No existing setup, skipping backup"
  fi
else
  print_ok "Test mode: backup skipped"
fi
phase_ok "backup"

# ============================================================================
# Phase 2: Rules
# ============================================================================
print_header "Phase 2: Rules"
mkdir -p "$CLAUDE_HOME/.claude/rules"
cp "$REPO_ROOT/rules/"*.md "$CLAUDE_HOME/.claude/rules/" || phase_fail "2" "Failed to copy rules"
RULE_COUNT=$(ls "$CLAUDE_HOME/.claude/rules/"*.md 2>/dev/null | wc -l | tr -d ' ')
print_ok "$RULE_COUNT rules installed"
phase_ok "2-rules"

# ============================================================================
# Phase 3: Skills (preserves personal learnings)
# ============================================================================
print_header "Phase 3: Skills"
SKILL_COUNT=0
for skill_dir in "$REPO_ROOT/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  target="$CLAUDE_HOME/.claude/skills/$skill_name"

  # Backup personal learnings before overwrite
  LEARNINGS_BAK=""
  if [ -f "$target/references/learnings.md" ]; then
    LEARNINGS_BAK="/tmp/learnings-${skill_name}.md"
    cp "$target/references/learnings.md" "$LEARNINGS_BAK" 2>/dev/null || true
  fi

  # Copy skill files individually to avoid glob issues
  mkdir -p "$target"
  if [ -d "${skill_dir}references" ]; then
    mkdir -p "$target/references"
  fi
  if [ -d "${skill_dir}scripts" ]; then
    mkdir -p "$target/scripts"
  fi

  for f in "$skill_dir"*; do
    [ -e "$f" ] || continue
    bname=$(basename "$f")
    if [ -d "$f" ]; then
      cp -r "$f" "$target/" 2>/dev/null || true
    else
      cp "$f" "$target/$bname" 2>/dev/null || true
    fi
  done

  # Restore personal learnings
  if [ -n "$LEARNINGS_BAK" ] && [ -f "$LEARNINGS_BAK" ]; then
    mkdir -p "$target/references"
    cp "$LEARNINGS_BAK" "$target/references/learnings.md"
    rm -f "$LEARNINGS_BAK"
  fi

  SKILL_COUNT=$((SKILL_COUNT + 1))
done
print_ok "$SKILL_COUNT skills installed (learnings preserved)"
phase_ok "3-skills"

# ============================================================================
# Phase 4: Agents
# ============================================================================
print_header "Phase 4: Agents"
mkdir -p "$CLAUDE_HOME/.claude/agents"
cp "$REPO_ROOT/agents/"*.md "$CLAUDE_HOME/.claude/agents/" || phase_fail "4" "Failed to copy agents"
AGENT_COUNT=$(ls "$CLAUDE_HOME/.claude/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
print_ok "$AGENT_COUNT agents installed"
phase_ok "4-agents"

# ============================================================================
# Phase 4.5: Replace path placeholders (safe Python, no heredoc)
# ============================================================================
print_header "Phase 4.5: Placeholders"
python3 -c "
import os, glob, sys
dirs = [sys.argv[1] + '/.claude/rules', sys.argv[1] + '/.claude/skills', sys.argv[1] + '/.claude/agents']
replacements = {
    '__CODEBASE_ROOT__': sys.argv[2],
    '__VAULT_ROOT__': sys.argv[3],
    '__HOME__': sys.argv[1],
    '__SLACK_USER_ID__': sys.argv[4],
    '__USER_FULL_NAME__': sys.argv[5],
    '__USER_NAME__': sys.argv[5],
    '__USER_EMAIL__': sys.argv[6],
    '__SLACK_DM_ID__': sys.argv[7],
    '__TEAM_VERTICALS__': sys.argv[8]
}
count = 0
for d in dirs:
    for f in glob.glob(os.path.join(d, '**', '*.md'), recursive=True):
        try:
            txt = open(f).read()
            changed = False
            for placeholder, value in replacements.items():
                if placeholder in txt and value:
                    txt = txt.replace(placeholder, value)
                    changed = True
            if changed:
                open(f, 'w').write(txt)
                count += 1
        except Exception:
            pass
print(f'{count} files updated')
" "$CLAUDE_HOME" "$CODEBASE_ROOT" "$VAULT_ROOT" "$SLACK_USER_ID" "$USER_FULL_NAME" "$USER_EMAIL" "$SLACK_DM_ID" "$TEAM_VERTICALS" \
  || phase_fail "4.5" "Failed to resolve placeholders"
print_ok "Path placeholders resolved"
phase_ok "4.5-placeholders"

# ============================================================================
# Phase 4.6: Service Dossiers (CLAUDE.md per repo)
# ============================================================================
print_header "Phase 4.6: Service Dossiers"
DOSSIER_DIR="$REPO_ROOT/claude-md"
DEPLOYED=0
TOTAL_DOSSIERS=0
if [ -d "$DOSSIER_DIR" ] && [ -d "$CODEBASE_ROOT" ]; then
  for dossier in "$DOSSIER_DIR"/*.md; do
    [ -f "$dossier" ] || continue
    TOTAL_DOSSIERS=$((TOTAL_DOSSIERS + 1))
    repo_name=$(basename "$dossier" .md)
    target_repo="$CODEBASE_ROOT/$repo_name"
    if [ -d "$target_repo" ]; then
      cp "$dossier" "$target_repo/CLAUDE.md" && DEPLOYED=$((DEPLOYED + 1))
    fi
  done
  print_ok "$DEPLOYED/$TOTAL_DOSSIERS dossiers deployed"
  if [ "$DEPLOYED" -lt "$TOTAL_DOSSIERS" ]; then
    print_info "Missing repos: clone them to $CODEBASE_ROOT and re-run"
  fi
else
  print_warn "Skipped: dossier dir or codebase root not found"
fi
phase_ok "4.6-dossiers"

# ============================================================================
# Phase 5: Hooks + Status Line
# ============================================================================
print_header "Phase 5: Hooks + Status Line"
mkdir -p "$CLAUDE_HOME/.claude/hooks"
HOOK_COUNT=0
for hook in pre-git-commit.sh session-start-check.sh skill-enforcement-guard.sh skill-tracker.sh tool-preference-guard.sh; do
  if [ -f "$REPO_ROOT/hooks/core/$hook" ]; then
    cp "$REPO_ROOT/hooks/core/$hook" "$CLAUDE_HOME/.claude/hooks/" && HOOK_COUNT=$((HOOK_COUNT + 1))
  else
    print_warn "Hook not found in repo: hooks/core/$hook"
  fi
done
if [ -f "$REPO_ROOT/hooks/core/statusline-command.sh" ]; then
  cp "$REPO_ROOT/hooks/core/statusline-command.sh" "$CLAUDE_HOME/.claude/statusline-command.sh"
fi
chmod +x "$CLAUDE_HOME/.claude/hooks/"*.sh 2>/dev/null || true
chmod +x "$CLAUDE_HOME/.claude/statusline-command.sh" 2>/dev/null || true
print_ok "$HOOK_COUNT hooks + status line installed"
phase_ok "5-hooks"

# ============================================================================
# Phase 6: Settings (preserves existing)
# ============================================================================
print_header "Phase 6: Settings"
if [ ! -f "$CLAUDE_HOME/.claude/settings.json" ]; then
  cat > "$CLAUDE_HOME/.claude/settings.json" << 'SETTINGS_EOF'
{
  "env": {
    "CLAUDE_CODE_SHELL": "/bin/zsh",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "permissions": {
    "allow": ["Bash","Read","Edit","Write","Glob","Grep","NotebookEdit","WebSearch","WebFetch","Agent","Skill","ToolSearch"],
    "defaultMode": "default"
  },
  "hooks": {
    "PreToolUse": [
      {"matcher":"Bash","hooks":[{"type":"command","command":"$HOME/.claude/hooks/skill-enforcement-guard.sh","timeout":5,"statusMessage":"Checking skill enforcement..."},{"type":"command","command":"$HOME/.claude/hooks/tool-preference-guard.sh","timeout":3}]},
      {"matcher":"Bash(git commit)","hooks":[{"type":"command","command":"$HOME/.claude/hooks/pre-git-commit.sh","timeout":120,"statusMessage":"Running pre-commit checks (lint + types)..."}]}
    ],
    "PostToolUse": [{"matcher":"Skill","hooks":[{"type":"command","command":"$HOME/.claude/hooks/skill-tracker.sh","timeout":3}]}],
    "SessionStart": [{"matcher":"startup|resume","hooks":[{"type":"command","command":"~/.claude/hooks/session-start-check.sh","timeout":10}]}],
    "Notification": [{"matcher":"","hooks":[{"type":"command","command":"printf '\\a' > /dev/tty"}]}]
  },
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  },
  "language": "English",
  "effortLevel": "medium",
  "voiceEnabled": true,
  "mcpServers": {}
}
SETTINGS_EOF
  print_ok "settings.json created"
else
  print_ok "settings.json preserved (already exists)"
fi
phase_ok "6-settings"

# ============================================================================
# Phase 7: MCP Servers (merges, doesn't overwrite)
# ============================================================================
print_header "Phase 7: MCP Servers"
CLAUDE_JSON="$CLAUDE_HOME/.claude.json"

# Detect uvx path dynamically (may be Homebrew, cargo, or ~/.local/bin)
UVX_CMD=""
if command -v uvx &>/dev/null; then
  UVX_CMD="$(command -v uvx)"
elif [ "$SETUP_TEST_MODE" = "1" ]; then
  UVX_CMD="uvx"
else
  print_warn "uvx not found, will install uv in Phase 9"
  UVX_CMD="uvx"
fi

python3 -c "
import json, os, sys
path = sys.argv[1]
email = sys.argv[2]
token = sys.argv[3]
claude_home = sys.argv[4]
uvx_cmd = sys.argv[6]

data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except json.JSONDecodeError:
        print('  WARN: Existing .claude.json was corrupted, creating fresh', file=sys.stderr)
        data = {}

if 'mcpServers' not in data:
    data['mcpServers'] = {}

# Add-only: never overwrite user's existing MCP configs
our_mcps = {
    'mcp-atlassian': {
        'type': 'stdio', 'command': uvx_cmd, 'args': ['mcp-atlassian'],
        'env': {
            'CONFLUENCE_URL': 'https://aussiecommerce.atlassian.net/wiki',
            'CONFLUENCE_USERNAME': email, 'CONFLUENCE_API_TOKEN': token,
            'JIRA_URL': 'https://aussiecommerce.atlassian.net',
            'JIRA_USERNAME': email, 'JIRA_API_TOKEN': token
        }
    },
    'datadog-mcp': {'type': 'http', 'url': 'https://mcp.ap2.datadoghq.com/api/unstable/mcp-server/mcp?toolsets=core,apm'},
    'context7': {'type': 'stdio', 'command': 'npx', 'args': ['-y', '@upstash/context7-mcp@latest']},
    'probe': {'type': 'stdio', 'command': 'npx', 'args': ['-y', '@probelabs/probe@latest', 'mcp']},
    'playwright': {'type': 'stdio', 'command': 'npx', 'args': ['@playwright/mcp@latest', '--viewport-size', '1440x900']},
    'chrome-devtools': {'type': 'stdio', 'command': 'npx', 'args': ['chrome-devtools-mcp@latest']},
    'imugi': {'type': 'stdio', 'command': 'npx', 'args': ['-y', 'imugi-ai@latest', 'mcp']}
}

# local-le-chromadb: only if Local AI is enabled
install_local_ai = sys.argv[5]
if install_local_ai.lower() == 'y':
    our_mcps['local-le-chromadb'] = {
        'type': 'stdio',
        'command': claude_home + '/.local/share/le-vault-chroma/venv/bin/python3',
        'args': [claude_home + '/.claude/local-ai/vault/vault_mcp_server.py'],
        'env': {'CHROMA_HOST': 'localhost', 'CHROMA_PORT': '8100'}
    }

added = 0
for name, config in our_mcps.items():
    if name not in data['mcpServers']:
        data['mcpServers'][name] = config
        added += 1

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
total = len(data['mcpServers'])
existing = total - added
if existing > len(our_mcps):
    print(f'{added} MCPs added, {existing} existing preserved ({total} total)')
else:
    print(f'{total} MCP servers configured ({added} added)')
" "$CLAUDE_JSON" "$USER_EMAIL" "$ATLASSIAN_TOKEN" "$CLAUDE_HOME" "$INSTALL_LOCAL_AI" "$UVX_CMD" \
  || phase_fail "7" "Failed to configure MCP servers"
print_ok "MCP servers configured"
phase_ok "7-mcp"

# ============================================================================
# Phase 8: Vault RAG Scripts + Python venv
# ============================================================================
print_header "Phase 8: Vault RAG"
CHROMA_DIR="$CLAUDE_HOME/.local/share/le-vault-chroma"
VAULT_SCRIPTS_DIR="$CLAUDE_HOME/.claude/local-ai/vault"

# 8a: Copy vault scripts to ~/.claude/local-ai/vault/
mkdir -p "$VAULT_SCRIPTS_DIR"
VAULT_SCRIPT_COUNT=0
for script in vault_chroma.sh vault_index.py vault_watch.sh vault_query.sh vault_mcp_server.py; do
  if [ -f "$REPO_ROOT/local-ai/vault/$script" ]; then
    cp "$REPO_ROOT/local-ai/vault/$script" "$VAULT_SCRIPTS_DIR/" && VAULT_SCRIPT_COUNT=$((VAULT_SCRIPT_COUNT + 1))
  else
    print_warn "Vault script not found: local-ai/vault/$script"
  fi
done
chmod +x "$VAULT_SCRIPTS_DIR/"*.sh "$VAULT_SCRIPTS_DIR/"*.py 2>/dev/null || true
print_ok "$VAULT_SCRIPT_COUNT vault scripts installed to ~/.claude/local-ai/vault/"

# 8b: Create CLI symlinks in ~/bin/
mkdir -p "$CLAUDE_HOME/bin"
for cmd in vault-chroma:vault_chroma.sh vault-index:vault_index.py vault-watch:vault_watch.sh vault-query:vault_query.sh; do
  alias_name="${cmd%%:*}"
  script_name="${cmd##*:}"
  if [ -f "$VAULT_SCRIPTS_DIR/$script_name" ]; then
    ln -sf "$VAULT_SCRIPTS_DIR/$script_name" "$CLAUDE_HOME/bin/$alias_name"
  fi
done
print_ok "CLI symlinks created (vault-chroma, vault-index, vault-watch, vault-query)"

# 8c: Copy utility scripts
mkdir -p "$CLAUDE_HOME/.claude/scripts"
for util in ci-local-check.sh; do
  if [ -f "$REPO_ROOT/scripts/$util" ]; then
    cp "$REPO_ROOT/scripts/$util" "$CLAUDE_HOME/.claude/scripts/"
    chmod +x "$CLAUDE_HOME/.claude/scripts/$util"
  fi
done
print_ok "Utility scripts installed (ci-local-check.sh)"

# 8d: Python venv for ChromaDB + MCP SDK
if [ -d "$CHROMA_DIR/venv" ]; then
  print_ok "Python venv already exists"
else
  echo "  Creating Python venv for vault-rag..."
  mkdir -p "$CHROMA_DIR"
  if [ "$SETUP_TEST_MODE" = "1" ]; then
    python3 -m venv "$CHROMA_DIR/venv" || phase_fail "8" "Failed to create venv"
    print_ok "Venv created (test mode: pip install skipped)"
  else
    python3 -m venv "$CHROMA_DIR/venv" || phase_fail "8" "Failed to create venv"
    "$CHROMA_DIR/venv/bin/pip" install -q chromadb requests mcp 2>/dev/null || print_warn "pip install had issues (may work anyway)"
    print_ok "Venv created + dependencies installed"
  fi
fi
phase_ok "8-rag"

# ============================================================================
# Phase 9: Python Tools (uvx)
# ============================================================================
print_header "Phase 9: Python Tools"
if [ "$SETUP_TEST_MODE" = "1" ]; then
  print_ok "uvx check skipped (test mode)"
elif command -v uvx &>/dev/null; then
  print_ok "uvx installed ($(uvx --version 2>/dev/null || echo 'version unknown'))"
else
  if curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null; then
    # Source the env so uvx is available immediately in this session
    [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env" 2>/dev/null || true
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env" 2>/dev/null || true
    if command -v uvx &>/dev/null; then
      print_ok "uv/uvx installed"
      # Update mcp-atlassian command path if it was set to the 'uvx' placeholder
      UVX_REAL="$(command -v uvx)"
      python3 -c "
import json, sys
path = sys.argv[1]
uvx_real = sys.argv[2]
with open(path) as f: data = json.load(f)
mcp = data.get('mcpServers', {}).get('mcp-atlassian', {})
if mcp.get('command') == 'uvx':
    mcp['command'] = uvx_real
    with open(path, 'w') as f: json.dump(data, f, indent=2)
    print(f'Updated mcp-atlassian path to {uvx_real}')
else:
    print('mcp-atlassian path already set, skipped')
" "$CLAUDE_JSON" "$UVX_REAL"
      print_ok "uvx path verified"
    else
      print_warn "uv installed but uvx not in PATH. Run: source ~/.local/bin/env"
    fi
  else
    print_warn "Failed to install uv. MCP Atlassian may not work. Install manually: https://astral.sh/uv"
  fi
fi
phase_ok "9-python"

# ============================================================================
# Phase 10: Cursor IDE Sync (uses saved preference)
# ============================================================================
print_header "Phase 10: Cursor"
if [ "$USE_CURSOR" = "y" ] || [ "$USE_CURSOR" = "Y" ]; then

  # 10a: Backup existing Cursor config
  CURSOR_BACKUP="$BACKUP_DIR/cursor"
  if [ -d "$CLAUDE_HOME/.cursor/rules" ] || [ -f "$CLAUDE_HOME/.cursor/mcp.json" ]; then
    mkdir -p "$CURSOR_BACKUP"
    [ -d "$CLAUDE_HOME/.cursor/rules" ] && cp -r "$CLAUDE_HOME/.cursor/rules" "$CURSOR_BACKUP/" 2>/dev/null
    [ -f "$CLAUDE_HOME/.cursor/mcp.json" ] && cp "$CLAUDE_HOME/.cursor/mcp.json" "$CURSOR_BACKUP/" 2>/dev/null
    [ -d "$CLAUDE_HOME/.cursor/agents" ] && cp -r "$CLAUDE_HOME/.cursor/agents" "$CURSOR_BACKUP/" 2>/dev/null
    print_ok "Cursor config backed up to $CURSOR_BACKUP"
  fi

  # 10b: Sync rules (.md -> .mdc, preserving user's extra rules)
  mkdir -p "$CLAUDE_HOME/.cursor/rules"
  CURSOR_RULE_COUNT=0
  for f in "$CLAUDE_HOME/.claude/rules/"*.md; do
    cp "$f" "$CLAUDE_HOME/.cursor/rules/$(basename "$f" .md).mdc" 2>/dev/null && CURSOR_RULE_COUNT=$((CURSOR_RULE_COUNT + 1))
  done
  EXTRA_RULES=$(ls "$CLAUDE_HOME/.cursor/rules/"*.mdc 2>/dev/null | wc -l | tr -d ' ')
  EXTRA_COUNT=$((EXTRA_RULES - CURSOR_RULE_COUNT))
  if [ "$EXTRA_COUNT" -gt 0 ]; then
    print_ok "$CURSOR_RULE_COUNT rules synced ($EXTRA_COUNT extra rules preserved)"
  else
    print_ok "$CURSOR_RULE_COUNT rules synced"
  fi

  # 10c: Sync agents
  if [ -d "$CLAUDE_HOME/.claude/agents" ]; then
    mkdir -p "$CLAUDE_HOME/.cursor/agents"
    cp "$CLAUDE_HOME/.claude/agents/"*.md "$CLAUDE_HOME/.cursor/agents/" 2>/dev/null
    print_ok "Agents synced to Cursor"
  fi

  # 10d: Merge MCP servers (preserve user's existing MCPs, add ours)
  python3 -c "
import json, os, sys
claude_json = sys.argv[1]
cursor_mcp = sys.argv[2]

# Load our MCPs from .claude.json
claude_data = json.load(open(claude_json)) if os.path.exists(claude_json) else {}
our_mcps = claude_data.get('mcpServers', {})

# Load existing Cursor MCPs (preserve user's own servers)
cursor_data = {}
if os.path.exists(cursor_mcp):
    try:
        cursor_data = json.load(open(cursor_mcp))
    except json.JSONDecodeError:
        cursor_data = {}

existing_mcps = cursor_data.get('mcpServers', {})

# Add-only: never overwrite existing MCPs (user's or Claude's)
added = 0
for name, config in our_mcps.items():
    if name not in existing_mcps:
        existing_mcps[name] = config
        added += 1

with open(cursor_mcp, 'w') as f:
    json.dump({'mcpServers': existing_mcps}, f, indent=2)

total = len(existing_mcps)
if total > added:
    print(f'{added} MCPs added, {total - added} existing preserved ({total} total)')
else:
    print(f'{total} MCPs synced')
" "$CLAUDE_JSON" "$CLAUDE_HOME/.cursor/mcp.json"
  print_ok "Cursor MCP servers merged"

else
  print_info "Cursor: skipped (saved preference)"
fi
phase_ok "10-cursor"

# ============================================================================
# Phase 11: Local AI Layer - Ollama + ChromaDB + fswatch (uses saved preference)
# ============================================================================
print_header "Phase 11: Local AI Layer"
if [ "$INSTALL_LOCAL_AI" = "y" ] || [ "$INSTALL_LOCAL_AI" = "Y" ]; then

  # 11a: Check Ollama (required for embeddings)
  if command -v ollama &>/dev/null; then
    print_ok "Ollama installed"
    # Pull embedding model if not present
    if ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
      print_ok "nomic-embed-text model present"
    else
      echo "  Pulling nomic-embed-text model (274MB, one-time)..."
      if [ "$SETUP_TEST_MODE" != "1" ]; then
        ollama pull nomic-embed-text 2>/dev/null && print_ok "nomic-embed-text pulled" || print_warn "Failed to pull model. Run manually: ollama pull nomic-embed-text"
      else
        print_ok "Model pull skipped (test mode)"
      fi
    fi
  else
    print_warn "Ollama not found. Install: brew install ollama && brew services start ollama"
    print_info "Then run: ollama pull nomic-embed-text"
  fi

  # 11b: Check fswatch (required for vault-watch)
  if command -v fswatch &>/dev/null; then
    print_ok "fswatch installed"
  else
    print_warn "fswatch not found. Install: brew install fswatch"
    print_info "Required for automatic vault re-indexing on file changes"
  fi

  # 11c: ChromaDB container
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q chromadb; then
    print_ok "ChromaDB container running (port 8100)"
  elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q chromadb; then
    print_info "ChromaDB container exists but not running. Start with: docker start chromadb"
  else
    if [ "$SETUP_TEST_MODE" != "1" ]; then
      echo "  Starting ChromaDB container..."
      docker run -d --name chromadb -p 8100:8000 --restart unless-stopped chromadb/chroma:latest 2>/dev/null \
        && print_ok "ChromaDB container started (port 8100)" \
        || print_warn "Failed to start ChromaDB. Run manually: docker run -d --name chromadb -p 8100:8000 chromadb/chroma"
    else
      print_ok "ChromaDB start skipped (test mode)"
    fi
  fi

  # 11d: Initial vault index (if ChromaDB + Ollama are running)
  if curl -sf "http://localhost:8100/api/v2/heartbeat" > /dev/null 2>&1; then
    if command -v ollama &>/dev/null && ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
      echo "  Running initial vault index..."
      if [ "$SETUP_TEST_MODE" != "1" ]; then
        VAULT_ROOT="$VAULT_ROOT" CODEBASE_ROOT="$CODEBASE_ROOT" \
          "$CHROMA_DIR/venv/bin/python3" "$VAULT_SCRIPTS_DIR/vault_index.py" --full 2>/dev/null \
          && print_ok "Initial vault index complete" \
          || print_warn "Initial index failed. Run manually: vault-index --full"
      else
        print_ok "Initial index skipped (test mode)"
      fi
    else
      print_info "Skipped initial index (Ollama not ready). Run later: vault-index --full"
    fi
  else
    print_info "Skipped initial index (ChromaDB not ready). Run later: vault-index --full"
  fi

else
  print_info "Local AI: skipped (saved preference)"
  if [ "$IS_UPDATE" = "false" ]; then
    print_info "Install later: re-run setup.sh --reconfigure and enable Local AI"
  fi
fi
phase_ok "11-local-ai"

# ============================================================================
# Save version + Cleanup old backups (keep last 3)
# ============================================================================
echo "$REPO_VERSION" > "$VERSION_FILE"

# Cleanup old backups (keep most recent 3)
ls -dt "$CLAUDE_HOME/.claude/.setup-backup-"* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null || true

# ============================================================================
# Summary
# ============================================================================
if [ "$IS_UPDATE" = "true" ]; then
  print_header "Update Complete! ($INSTALLED_VERSION -> $REPO_VERSION)"
else
  print_header "Setup Complete! ($REPO_VERSION)"
fi

echo -e "${GREEN}${BOLD}Installed:${NC}"
MCP_COUNT=$(python3 -c "import json; print(len(json.load(open('$CLAUDE_HOME/.claude.json')).get('mcpServers',{})))" 2>/dev/null || echo "?")
echo "  $(ls "$CLAUDE_HOME/.claude/rules/"*.md 2>/dev/null | wc -l | tr -d ' ') rules | $(ls -d "$CLAUDE_HOME/.claude/skills/"*/ 2>/dev/null | wc -l | tr -d ' ') skills | $(ls "$CLAUDE_HOME/.claude/agents/"*.md 2>/dev/null | wc -l | tr -d ' ') agents | $MCP_COUNT MCP servers"
if [ -d "$CLAUDE_HOME/.claude/local-ai/vault" ]; then
  echo "  Vault RAG: scripts installed | $([ -d "$CHROMA_DIR/venv" ] && echo 'venv ready' || echo 'venv missing')"
fi
echo ""
echo -e "${BLUE}${BOLD}Preserved:${NC}"
echo "  Personal config ($CONFIG_FILE)"
echo "  Personal learnings (references/learnings.md per skill)"
echo "  settings.json (hooks, permissions, status line)"
echo ""
if [ "$IS_UPDATE" = "false" ]; then
  echo -e "${YELLOW}${BOLD}Next steps:${NC}"
  echo "  1. Restart Claude Code (or Cursor)"
  echo "  2. /mcp to connect Datadog + Slack (OAuth)"
  echo "  3. circleci setup"
  echo "  4. Paste the verification prompt below into Claude Code or Cursor"
fi
echo ""
echo -e "${CYAN}Update:       bash scripts/update.sh${NC}"
echo -e "${CYAN}Reconfigure:  bash scripts/setup.sh --reconfigure${NC}"
echo -e "${CYAN}Rollback:     cp -r $BACKUP_DIR/.claude/* ~/.claude/${NC}"
echo ""
echo -e "${GREEN}${BOLD}Version $REPO_VERSION installed. Phases: ${PHASES_COMPLETED[*]}${NC}"

# ============================================================================
# Verification prompt (paste into Claude Code or Cursor after setup)
# ============================================================================
if [ "$SETUP_TEST_MODE" != "1" ]; then
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}${BOLD}  Verification: paste this into your AI coding tool to check setup${NC}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  cat << 'VERIFY_PROMPT'
Run a full setup verification. Check each item and report a table with status (PASS/FAIL/WARN) and details:

1. **Rules**: list files in ~/.claude/rules/, confirm 8 .md files exist and none contain __PLACEHOLDER__ strings
2. **Skills**: list dirs in ~/.claude/skills/, confirm each has a SKILL.md, count total
3. **Agents**: list files in ~/.claude/agents/, confirm 4 .md files, none contain __PLACEHOLDER__ strings
4. **Hooks**: list files in ~/.claude/hooks/, confirm 5 .sh files are executable, confirm ~/.claude/statusline-command.sh exists
5. **Settings**: read ~/.claude/settings.json, confirm valid JSON with keys: hooks, statusLine, permissions, env
6. **MCP Servers**: read ~/.claude.json, confirm mcpServers has at minimum: mcp-atlassian, datadog-mcp, context7, probe, playwright, chrome-devtools, imugi (7 base). If local-le-chromadb exists (Local AI enabled), check the python and script paths exist on disk. Report total count
7. **Placeholders**: grep recursively in ~/.claude/rules/, ~/.claude/skills/, ~/.claude/agents/ for any remaining __PLACEHOLDER__ patterns (double underscore prefix+suffix). Report any found
8. **Vault RAG** (if ~/.claude/local-ai/vault/ exists): confirm vault scripts present (vault_mcp_server.py, vault_index.py, vault_chroma.sh, vault_watch.sh), confirm Python venv at ~/.local/share/le-vault-chroma/venv/bin/python3, check if ChromaDB is running (curl localhost:8100/api/v2/heartbeat), check if Ollama is running and has nomic-embed-text model
9. **CLI symlinks** (if ~/bin/ has vault-* files): check vault-chroma, vault-index, vault-watch, vault-query exist and point to valid targets
10. **Utility scripts**: check ~/.claude/scripts/ci-local-check.sh exists

Output a summary table, then list any FAIL items with fix instructions. End with "Setup verified: X/10 checks passed."
VERIFY_PROMPT
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi
