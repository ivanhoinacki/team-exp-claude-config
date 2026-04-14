#!/bin/bash

# ============================================================================
# AI Dev Ecosystem Setup - Luxury Escapes (WSL2 / Linux)
#
# Configures: rules, skills, agents, MCP servers, hooks, settings, ChromaDB vault-rag
# Works with: Claude Code + Cursor
# WSL2-specific: GNU sed, Linux paths, no Homebrew, python3/python fallback
#
# Flags:
#   --reconfigure    Re-enter personal info (name, email, token, paths)
#   --force          Skip confirmation prompt
# Run: bash scripts/setup-wsl.sh
# ============================================================================

set -uo pipefail
# Note: no 'set -e' to allow graceful handling of optional steps (Ollama, Docker, etc.)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Allow overriding HOME for testing (SETUP_TEST_MODE=1 skips prerequisites and interactive prompts)
SETUP_TEST_MODE="${SETUP_TEST_MODE:-0}"
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
print_ok() { echo -e "${GREEN}  OK${NC} $1"; }
print_warn() { echo -e "${YELLOW}  WARN${NC} $1"; }
print_error() { echo -e "${RED}  ERROR${NC} $1"; }
print_info() { echo -e "${BLUE}  INFO${NC} $1"; }

# --- Error handling ---
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

# Python: try python3 first, fallback to python
PYTHON_CMD=""
if command -v python3 &>/dev/null; then
  PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
  PYTHON_CMD="python"
fi

# --- Input validation helpers ---
validate_email() {
  local email="$1"
  [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

validate_slack_id() {
  local sid="$1"
  [[ "$sid" =~ ^U[A-Z0-9]{8,}$ ]]
}

validate_slack_dm_id() {
  local did="$1"
  # Optional: empty is OK, but if provided must start with D
  [ -z "$did" ] && return 0
  [[ "$did" =~ ^D[A-Z0-9]{8,}$ ]]
}

validate_not_empty() {
  local val="$1"
  [ -n "$(echo "$val" | tr -d '[:space:]')" ]
}

validate_directory() {
  local dir="$1"
  dir="${dir/#\~/$HOME}"
  if [ -d "$dir" ]; then
    return 0
  fi
  echo ""
  read -p "    Directory not found: $dir. Create it? (y/n) [y]: " CREATE_DIR
  CREATE_DIR="${CREATE_DIR:-y}"
  if [ "$CREATE_DIR" = "y" ] || [ "$CREATE_DIR" = "Y" ]; then
    if mkdir -p "$dir" 2>/dev/null; then
      echo -e "    ${GREEN}Created: $dir${NC}"
      return 0
    else
      echo -e "    ${RED}Failed to create: $dir${NC}"
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
  print_header "AI Dev Ecosystem Update (WSL2 / Linux)"
  echo "Source: $REPO_ROOT"
  echo -e "Installed: ${YELLOW}${INSTALLED_VERSION}${NC} -> New: ${GREEN}${REPO_VERSION}${NC}"
  echo -e "Config: $CONFIG_FILE (preserved)"
  echo -e "Run with ${BOLD}--reconfigure${NC} to re-enter personal info"
  echo ""
else
  print_header "AI Dev Ecosystem Setup (WSL2 / Linux)"
  echo "Source: $REPO_ROOT"
  if [ "$RECONFIGURE" = "true" ] && [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Reconfigure mode: will re-ask personal info${NC}"
  fi
  echo ""
fi

# --- Phase 0: Prerequisites ---
print_header "Phase 0: Prerequisites"
if [ "$SETUP_TEST_MODE" != "1" ]; then
  PREREQ_OK=true
  for cmd in claude node git npx; do
    if command -v $cmd &>/dev/null; then
      print_ok "$cmd ($(command -v $cmd))"
    else
      print_error "$cmd not found. Install it before continuing."
      PREREQ_OK=false
    fi
  done

  if [ -n "$PYTHON_CMD" ]; then
    print_ok "$PYTHON_CMD ($(command -v $PYTHON_CMD))"
  else
    print_error "python not found (need python3 or python)"
    PREREQ_OK=false
  fi

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

  if [ "$PREREQ_OK" = "false" ]; then
    phase_fail "0" "Missing prerequisites. Install the tools above and re-run."
  fi

  if command -v docker &>/dev/null; then
    if docker info &>/dev/null 2>&1; then
      print_ok "Docker: running"
    else
      print_warn "Docker: installed but not running (needed for ChromaDB in Local AI layer)"
      print_info "Start Docker before enabling Local AI, or skip it for now"
    fi
  else
    print_warn "Docker: not found (needed for ChromaDB if you enable Local AI layer)"
    print_info "Install: https://docs.docker.com/engine/install/ or via your distro package manager"
  fi
else
  PYTHON_CMD="${PYTHON_CMD:-python3}"
  print_ok "Test mode: prerequisites skipped"
fi
phase_ok "0-prereq"

# --- Phase 1: Backup ---
print_header "Phase 1: Backup Existing Setup"
if [ "$SETUP_TEST_MODE" != "1" ]; then
  HAS_EXISTING=0
  [ -d "$CLAUDE_HOME/.claude/rules" ] && HAS_EXISTING=1
  [ -d "$CLAUDE_HOME/.claude/skills" ] && HAS_EXISTING=1
  [ -f "$CLAUDE_HOME/.claude/settings.json" ] && HAS_EXISTING=1
  [ -f "$CLAUDE_HOME/.claude.json" ] && HAS_EXISTING=1

  if [ "$HAS_EXISTING" = "1" ]; then
    mkdir -p "$BACKUP_DIR"
    [ -d "$CLAUDE_HOME/.claude/rules" ] && cp -r "$CLAUDE_HOME/.claude/rules" "$BACKUP_DIR/rules" 2>/dev/null && print_ok "Rules backed up"
    [ -d "$CLAUDE_HOME/.claude/skills" ] && cp -r "$CLAUDE_HOME/.claude/skills" "$BACKUP_DIR/skills" 2>/dev/null && print_ok "Skills backed up"
    [ -d "$CLAUDE_HOME/.claude/agents" ] && cp -r "$CLAUDE_HOME/.claude/agents" "$BACKUP_DIR/agents" 2>/dev/null && print_ok "Agents backed up"
    [ -d "$CLAUDE_HOME/.claude/hooks" ] && cp -r "$CLAUDE_HOME/.claude/hooks" "$BACKUP_DIR/hooks" 2>/dev/null && print_ok "Hooks backed up"
    [ -f "$CLAUDE_HOME/.claude/settings.json" ] && cp "$CLAUDE_HOME/.claude/settings.json" "$BACKUP_DIR/settings.json" 2>/dev/null && print_ok "settings.json backed up"
    [ -f "$CLAUDE_HOME/.claude.json" ] && cp "$CLAUDE_HOME/.claude.json" "$BACKUP_DIR/claude.json" 2>/dev/null && print_ok "claude.json backed up"
    print_info "Backup: $BACKUP_DIR"
  else
    print_info "No existing setup, skipping backup"
  fi
else
  print_ok "Test mode: backup skipped"
fi
phase_ok "1-backup"

# --- Phase 2: Personal Info ---
print_header "Phase 2: Personal Information"

# Load saved config if update mode
if [ "$IS_UPDATE" = "true" ]; then
  if $PYTHON_CMD -c "import json; json.load(open('$CONFIG_FILE'))" 2>/dev/null; then
    USER_FULL_NAME=$($PYTHON_CMD -c "import json; print(json.load(open('$CONFIG_FILE')).get('name',''))")
    USER_EMAIL=$($PYTHON_CMD -c "import json; print(json.load(open('$CONFIG_FILE')).get('email',''))")
    SLACK_USER_ID=$($PYTHON_CMD -c "import json; print(json.load(open('$CONFIG_FILE')).get('slack_id',''))")
    ATLASSIAN_TOKEN=$($PYTHON_CMD -c "import json; print(json.load(open('$CONFIG_FILE')).get('atlassian_token',''))")
    CODEBASE_ROOT=$($PYTHON_CMD -c "import json; print(json.load(open('$CONFIG_FILE')).get('codebase_root',''))")
    VAULT_ROOT=$($PYTHON_CMD -c "import json; print(json.load(open('$CONFIG_FILE')).get('vault_root',''))")
    SLACK_DM_ID=$($PYTHON_CMD -c "import json; print(json.load(open('$CONFIG_FILE')).get('slack_dm_id','__SLACK_DM_ID__'))")
    TEAM_VERTICALS=$($PYTHON_CMD -c "import json; print(json.load(open('$CONFIG_FILE')).get('team_verticals','Experiences + White Label + Car Hire'))")
    INSTALL_LOCAL_AI=$($PYTHON_CMD -c "import json; print(json.load(open('$CONFIG_FILE')).get('install_local_ai','n'))")
    USE_CURSOR=$($PYTHON_CMD -c "import json; print(json.load(open('$CONFIG_FILE')).get('use_cursor','n'))")
    print_ok "Loaded from saved config"
    print_info "$USER_FULL_NAME <$USER_EMAIL>"
    if [ "$SLACK_DM_ID" = "__SLACK_DM_ID__" ]; then
      print_info "Slack DM ID not configured — run setup-wsl.sh --reconfigure to set it"
    fi
  else
    print_error "Config file corrupted. Switching to interactive mode."
    IS_UPDATE=false
  fi
fi

if [ "$SETUP_TEST_MODE" != "1" ] && [ "$IS_UPDATE" = "false" ]; then
  echo -e "  ${BOLD}Fill in your details (with validation):${NC}"
  echo -e "  ${YELLOW}NOTE: Use Linux paths in WSL2 (forward slashes)${NC}"
  echo -e "  Example: /mnt/c/Users/youruser/Documents/... NOT C:\\Users\\youruser\\..."
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
  echo -e "  1. Open Slack -> click your profile picture"
  echo -e "  2. Click 'Profile' -> click '...' (more)"
  echo -e "  3. Click 'Copy member ID' (starts with U, e.g. U0ACKPKRM3N)"
  prompt_validated "Slack User ID: " SLACK_USER_ID validate_slack_id \
    "Invalid format. Must start with U followed by 8+ chars (e.g. U0ACKPKRM3N)"

  # --- Atlassian API Token ---
  echo ""
  echo -e "  ${BLUE}Atlassian API Token (for Jira + Confluence MCP access):${NC}"
  echo -e "  1. Open: ${CYAN}https://id.atlassian.com/manage-profile/security/api-tokens${NC}"
  echo -e "  2. Click 'Create API token', label: 'claude-code'"
  echo -e "  3. Copy the generated token"
  prompt_validated "Token: " ATLASSIAN_TOKEN validate_not_empty \
    "Token cannot be empty. Generate one at the URL above." "" "true"

  # --- Codebase root ---
  echo ""
  echo -e "  ${BLUE}Where are your LE repos cloned?${NC}"
  echo -e "  This is the folder that CONTAINS all your LE repositories."
  echo -e "  Example: if svc-experiences is at ~/Documents/LuxuryEscapes/svc-experiences,"
  echo -e "  then your codebase root is ${CYAN}~/Documents/LuxuryEscapes${NC}"
  echo -e "  Claude will use this path to navigate repos, run commands, and read code."
  prompt_validated "Codebase root: " CODEBASE_ROOT validate_directory \
    "Directory not found." "$HOME/Documents/LuxuryEscapes"

  # --- Vault root (Obsidian) ---
  echo ""
  echo -e "  ${BLUE}Where is your Obsidian vault?${NC}"
  echo -e "  The vault is a local folder of Markdown files that Claude uses as a knowledge base."
  echo -e "  It stores: investigation learnings, business rules, session memory, runbooks."
  echo -e "  If you don't have a vault yet, we'll create one and set up the folder structure."
  echo ""

  # Check if Obsidian is installed (Linux only - WSL doesn't typically have desktop apps)
  OBSIDIAN_INSTALLED=false
  if command -v obsidian &>/dev/null; then
    OBSIDIAN_INSTALLED=true
  fi

  if [ "$OBSIDIAN_INSTALLED" = "false" ]; then
    echo -e "  ${YELLOW}Obsidian not found on this system.${NC}"
    echo -e "  Obsidian is the desktop app that opens the vault as a visual knowledge base."
    echo -e "  Without it the vault still works (Claude reads it directly), but"
    echo -e "  you won't have the UI to browse and edit notes."
    echo -e "  Install it on your main OS and point it to this vault location."
    echo ""
  fi

  prompt_validated "Obsidian vault root: " VAULT_ROOT validate_directory \
    "Directory not found." "$HOME/Documents/vault"

  # Create initial vault structure if the folder is new/empty
  if [ -d "$VAULT_ROOT" ] && [ -z "$(ls -A "$VAULT_ROOT" 2>/dev/null)" ]; then
    mkdir -p "$VAULT_ROOT/Knowledge-Base/Session-Memory"
    mkdir -p "$VAULT_ROOT/Knowledge-Base/Business-Rules"
    mkdir -p "$VAULT_ROOT/Knowledge-Base/Review-Learnings"
    mkdir -p "$VAULT_ROOT/Development"
    mkdir -p "$VAULT_ROOT/Runbooks"
    mkdir -p "$VAULT_ROOT/Prompts"
    print_ok "Initial vault structure created"
    print_info "Open Obsidian on your main OS -> 'Open folder as vault' -> select: $VAULT_ROOT"
  fi

  # --- Slack DM Channel ID (optional) ---
  echo ""
  echo -e "  ${BLUE}Slack DM Channel ID (so Claude can send you direct messages):${NC}"
  echo "  Open Slack -> your own DM -> click channel name -> copy Channel ID (starts with D)"
  echo "  Leave empty to skip (add later in rules/00-global-style.md)"
  prompt_validated "Slack DM Channel ID: " SLACK_DM_ID validate_slack_dm_id \
    "Invalid format. Must start with D followed by 8+ chars, or leave empty." ""
  SLACK_DM_ID="${SLACK_DM_ID:-__SLACK_DM_ID__}"

  # --- Team verticals ---
  echo ""
  echo -e "  ${BLUE}Your team's verticals (used in agent/copilot context):${NC}"
  read -p "  Team verticals [Experiences + White Label + Car Hire]: " TEAM_VERTICALS
  TEAM_VERTICALS="${TEAM_VERTICALS:-Experiences + White Label + Car Hire}"

  # --- Cursor IDE ---
  echo ""
  read -p "  Use Cursor IDE? (y/n) [n]: " USE_CURSOR
  USE_CURSOR="${USE_CURSOR:-n}"

  # --- Local AI ---
  echo ""
  read -p "  Install Local AI layer (ChromaDB + Ollama vault RAG)? (y/n) [n]: " INSTALL_LOCAL_AI
  INSTALL_LOCAL_AI="${INSTALL_LOCAL_AI:-n}"

  # --- Confirmation ---
  echo ""
  echo -e "  ${BOLD}Review your settings:${NC}"
  echo "    Name:          $USER_FULL_NAME"
  echo "    Email:         $USER_EMAIL"
  echo "    Slack ID:      $SLACK_USER_ID"
  echo "    Token:         ${ATLASSIAN_TOKEN:0:8}..."
  echo "    Codebase:      $CODEBASE_ROOT"
  echo "    Vault:         $VAULT_ROOT"
  echo "    Slack DM:      $SLACK_DM_ID"
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
elif [ "$SETUP_TEST_MODE" = "1" ]; then
  USER_FULL_NAME="${USER_FULL_NAME:-Test User}"
  USER_EMAIL="${USER_EMAIL:-test@luxuryescapes.com}"
  SLACK_USER_ID="${SLACK_USER_ID:-U0TEST123}"
  ATLASSIAN_TOKEN="${ATLASSIAN_TOKEN:-test-token-123}"
  CODEBASE_ROOT="${CODEBASE_ROOT:-$CLAUDE_HOME/Documents/LuxuryEscapes}"
  VAULT_ROOT="${VAULT_ROOT:-$CLAUDE_HOME/vault}"
  SLACK_DM_ID="${SLACK_DM_ID:-__SLACK_DM_ID__}"
  TEAM_VERTICALS="${TEAM_VERTICALS:-Experiences + White Label + Car Hire}"
  USE_CURSOR="${USE_CURSOR:-n}"
  INSTALL_LOCAL_AI="${INSTALL_LOCAL_AI:-n}"
fi
# else: IS_UPDATE=true, values already loaded from config

# Save config (for re-runs without re-entering info)
mkdir -p "$(dirname "$CONFIG_FILE")"
$PYTHON_CMD -c "
import json, sys
config = {
    'name': sys.argv[1], 'email': sys.argv[2], 'slack_id': sys.argv[3],
    'atlassian_token': sys.argv[4], 'codebase_root': sys.argv[5],
    'vault_root': sys.argv[6], 'slack_dm_id': sys.argv[7],
    'team_verticals': sys.argv[8], 'use_cursor': sys.argv[9],
    'install_local_ai': sys.argv[10], 'installed_at': sys.argv[11]
}
with open(sys.argv[12], 'w') as f: json.dump(config, f, indent=2)
" "$USER_FULL_NAME" "$USER_EMAIL" "$SLACK_USER_ID" "$ATLASSIAN_TOKEN" \
  "$CODEBASE_ROOT" "$VAULT_ROOT" "$SLACK_DM_ID" "$TEAM_VERTICALS" \
  "$USE_CURSOR" "$INSTALL_LOCAL_AI" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$CONFIG_FILE" \
  || phase_fail "2" "Failed to save config"
print_ok "Config saved to $CONFIG_FILE"
phase_ok "2-info"

# --- Phase 3: Rules ---
print_header "Phase 3: Rules"
mkdir -p "$CLAUDE_HOME/.claude/rules"

RULE_COUNT=0
for rule_file in "$REPO_ROOT/rules/"*.md; do
  [ -f "$rule_file" ] || continue
  rule_name=$(basename "$rule_file")
  cp "$rule_file" "$CLAUDE_HOME/.claude/rules/$rule_name"
  RULE_COUNT=$((RULE_COUNT + 1))
done
print_ok "$RULE_COUNT rules installed"
phase_ok "3-rules"

# --- Phase 4: Skills ---
print_header "Phase 4: Skills"
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

  # Copy skill files
  mkdir -p "$target"
  if [ -d "${skill_dir}references" ]; then
    mkdir -p "$target/references"
  fi
  if [ -d "${skill_dir}scripts" ]; then
    mkdir -p "$target/scripts"
  fi

  # Copy files individually to avoid glob issues
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
print_ok "$SKILL_COUNT skills installed"
phase_ok "4-skills"

# --- Phase 5: Agents ---
print_header "Phase 5: Agents"
mkdir -p "$CLAUDE_HOME/.claude/agents"

AGENT_COUNT=0
for agent_file in "$REPO_ROOT/agents/"*.md; do
  [ -f "$agent_file" ] || continue
  cp "$agent_file" "$CLAUDE_HOME/.claude/agents/"
  AGENT_COUNT=$((AGENT_COUNT + 1))
done
print_ok "$AGENT_COUNT agents installed"
phase_ok "5-agents"

# --- Phase 5.5: Replace path placeholders (uses Python sys.argv to avoid shell injection) ---
print_header "Phase 5.5: Placeholder Replacement"
$PYTHON_CMD -c "
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
  || phase_fail "5.5" "Failed to resolve placeholders"
print_ok "Path placeholders resolved"
phase_ok "5.5-placeholders"

# --- Phase 5.6: Service Dossiers (CLAUDE.md per repo) ---
print_header "Phase 5.6: Service Dossiers"
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
phase_ok "5.6-dossiers"

# --- Phase 6: Hooks + Status Line ---
print_header "Phase 6: Hooks + Status Line"
mkdir -p "$CLAUDE_HOME/.claude/hooks"
HOOK_COUNT=0

# All hooks (22)
for hook in "$REPO_ROOT/hooks/"*.sh; do
  [ -f "$hook" ] || continue
  hook_name=$(basename "$hook")
  if [ "$hook_name" = "statusline-command.sh" ]; then
    cp "$hook" "$CLAUDE_HOME/.claude/statusline-command.sh"
  else
    cp "$hook" "$CLAUDE_HOME/.claude/hooks/" && HOOK_COUNT=$((HOOK_COUNT + 1))
  fi
done
chmod +x "$CLAUDE_HOME/.claude/hooks/"*.sh 2>/dev/null || true
chmod +x "$CLAUDE_HOME/.claude/statusline-command.sh" 2>/dev/null || true
print_ok "$HOOK_COUNT hooks + status line installed"
phase_ok "6-hooks"

# --- Phase 7: Settings ---
print_header "Phase 7: Settings"
# NOTE: settings.json uses $HOME (not $CLAUDE_HOME) because Claude Code reads this
# at runtime where $HOME is the real user home. CLAUDE_HOME is only for test isolation.
if [ ! -f "$CLAUDE_HOME/.claude/settings.json" ]; then
  cat > "$CLAUDE_HOME/.claude/settings.json" << 'EOF'
{
  "env": {
    "CLAUDE_CODE_SHELL": "/bin/bash",
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
EOF
  print_ok "settings.json created"
else
  print_ok "settings.json preserved (exists)"
fi
phase_ok "7-settings"

# --- Phase 8: MCP Servers ---
print_header "Phase 8: MCP Servers"

# Find uvx
UVX_CMD=""
if command -v uvx &>/dev/null; then
  UVX_CMD="$(command -v uvx)"
elif [ "$SETUP_TEST_MODE" = "1" ]; then
  UVX_CMD="uvx"
else
  print_warn "uvx not found, will install uv in Phase 9"
  UVX_CMD="uvx"
fi

CLAUDE_JSON="$CLAUDE_HOME/.claude.json"

$PYTHON_CMD -c "
import json, os, sys
path = sys.argv[1]
uvx_cmd = sys.argv[2]
email = sys.argv[3]
token = sys.argv[4]
install_local_ai = sys.argv[5]
claude_home = sys.argv[6]

data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except json.JSONDecodeError:
        print('  WARN: Existing .claude.json was corrupted, creating fresh', flush=True)
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
    'playwright': {'command': 'npx', 'args': ['@playwright/mcp@latest', '--viewport-size', '1440x900']},
    'chrome-devtools': {'command': 'npx', 'args': ['chrome-devtools-mcp@latest']},
    'imugi': {'command': 'npx', 'args': ['-y', 'imugi-ai@latest', 'mcp']}
}

# local-le-chromadb: only if Local AI is enabled
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
if total > added:
    print(f'{added} MCPs added, {total - added} existing preserved ({total} total)')
else:
    print(f'{total} MCP servers configured ({added} added)')
" "$CLAUDE_JSON" "$UVX_CMD" "$USER_EMAIL" "$ATLASSIAN_TOKEN" "$INSTALL_LOCAL_AI" "$CLAUDE_HOME"
if [ $? -ne 0 ]; then
  phase_fail "8" "Failed to configure MCP servers"
fi
phase_ok "8-mcp"

# --- Phase 8.5: Vault RAG Scripts + Utilities ---
print_header "Phase 8.5: Vault RAG Scripts"
VAULT_SCRIPTS_DIR="$CLAUDE_HOME/.claude/local-ai/vault"
CHROMA_DIR="$CLAUDE_HOME/.local/share/le-vault-chroma"
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

# CLI symlinks
mkdir -p "$CLAUDE_HOME/bin"
for cmd in vault-chroma:vault_chroma.sh vault-index:vault_index.py vault-watch:vault_watch.sh vault-query:vault_query.sh; do
  alias_name="${cmd%%:*}"
  script_name="${cmd##*:}"
  [ -f "$VAULT_SCRIPTS_DIR/$script_name" ] && ln -sf "$VAULT_SCRIPTS_DIR/$script_name" "$CLAUDE_HOME/bin/$alias_name"
done

# Utility scripts
mkdir -p "$CLAUDE_HOME/.claude/scripts"
for util in ci-local-check.sh; do
  if [ -f "$REPO_ROOT/scripts/$util" ]; then
    cp "$REPO_ROOT/scripts/$util" "$CLAUDE_HOME/.claude/scripts/"
    chmod +x "$CLAUDE_HOME/.claude/scripts/$util"
  fi
done
print_ok "$VAULT_SCRIPT_COUNT vault scripts + utilities installed"

# Python venv for ChromaDB
if [ ! -d "$CHROMA_DIR/venv" ]; then
  mkdir -p "$CHROMA_DIR"
  if [ "$SETUP_TEST_MODE" = "1" ]; then
    $PYTHON_CMD -m venv "$CHROMA_DIR/venv" || print_warn "Failed to create venv"
    print_ok "Venv created (test mode: pip install skipped)"
  else
    $PYTHON_CMD -m venv "$CHROMA_DIR/venv" || print_warn "Failed to create venv"
    "$CHROMA_DIR/venv/bin/pip" install -q chromadb requests mcp 2>/dev/null || print_warn "pip install had issues"
    print_ok "Venv created + dependencies installed"
  fi
else
  print_ok "Python venv already exists"
fi
phase_ok "8.5-rag"

# --- Phase 9: Python Tools ---
print_header "Phase 9: Python Tools"
if [ "$SETUP_TEST_MODE" = "1" ]; then
  print_ok "uvx check skipped (test mode)"
elif command -v uvx &>/dev/null; then
  print_ok "uvx already installed"
else
  echo "  Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null
  # Source the env so uvx is available
  [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env" 2>/dev/null || true
  [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env" 2>/dev/null || true
  if command -v uvx &>/dev/null; then
    print_ok "uv installed"
    # Update mcp-atlassian command path only if it was set to the placeholder 'uvx'
    UVX_REAL="$(command -v uvx)"
    $PYTHON_CMD -c "
import json, sys
path = sys.argv[1]
uvx_real = sys.argv[2]
with open(path) as f: data = json.load(f)
mcp = data.get('mcpServers', {}).get('mcp-atlassian', {})
if mcp.get('command') == 'uvx':
    mcp['command'] = uvx_real
    with open(path, 'w') as f: json.dump(data, f, indent=2)
    print(f'Updated mcp-atlassian uvx path to {uvx_real}')
else:
    print('mcp-atlassian path already set, skipped')
" "$CLAUDE_JSON" "$UVX_REAL"
    print_ok "uvx path checked"
  else
    print_warn "uv installed but uvx not in PATH. Run: source ~/.local/bin/env"
  fi
fi
phase_ok "9-python"

# --- Phase 10: Cursor IDE Sync ---
print_header "Phase 10: Cursor"
if [ "$USE_CURSOR" = "y" ] || [ "$USE_CURSOR" = "Y" ]; then

  # 10a: Backup existing Cursor config
  CURSOR_BACKUP="${BACKUP_DIR:-$CLAUDE_HOME/.claude/.setup-backup-$(date +%Y%m%d-%H%M%S)}/cursor"
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

  # 10d: Add MCP servers (add-only, never overwrite existing)
  $PYTHON_CMD -c "
import json, os, sys
claude_json = sys.argv[1]
cursor_mcp = sys.argv[2]

# Load our MCPs from .claude.json
claude_data = json.load(open(claude_json)) if os.path.exists(claude_json) else {}
our_mcps = claude_data.get('mcpServers', {})

# Load existing Cursor MCPs
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
  print_ok "Cursor MCP servers synced"

else
  print_info "Cursor: skipped (saved preference)"
fi
phase_ok "10-cursor"

# --- Phase 11: Local AI Layer ---
print_header "Phase 11: Local AI Layer"
if [ "$INSTALL_LOCAL_AI" = "y" ] || [ "$INSTALL_LOCAL_AI" = "Y" ]; then

  # Ollama
  if command -v ollama &>/dev/null; then
    print_ok "Ollama installed"
    if ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
      print_ok "nomic-embed-text model present"
    else
      if [ "$SETUP_TEST_MODE" != "1" ]; then
        echo "  Pulling nomic-embed-text model (274MB)..."
        ollama pull nomic-embed-text 2>/dev/null && print_ok "nomic-embed-text pulled" || print_warn "Failed. Run: ollama pull nomic-embed-text"
      fi
    fi
  else
    print_warn "Ollama not found. Install: curl -fsSL https://ollama.com/install.sh | sh"
    print_info "Then run: ollama pull nomic-embed-text"
  fi

  # inotifywait (Linux equivalent of fswatch)
  if command -v inotifywait &>/dev/null; then
    print_ok "inotifywait installed"
  elif command -v fswatch &>/dev/null; then
    print_ok "fswatch installed"
  else
    print_warn "inotifywait not found. Install: sudo apt install inotify-tools"
    print_info "Required for automatic vault re-indexing on file changes"
  fi

  # Docker + ChromaDB
  if command -v docker &>/dev/null; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q chromadb; then
      print_ok "ChromaDB container running (port 8100)"
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q chromadb; then
      print_info "ChromaDB exists but not running. Start: docker start chromadb"
    elif [ "$SETUP_TEST_MODE" != "1" ]; then
      echo "  Starting ChromaDB container..."
      docker run -d --name chromadb -p 8100:8000 --restart unless-stopped chromadb/chroma:latest 2>/dev/null \
        && print_ok "ChromaDB started (port 8100)" \
        || print_warn "Failed. Run: docker run -d --name chromadb -p 8100:8000 chromadb/chroma"
    fi
  else
    print_warn "Docker not found. Required for ChromaDB."
  fi

  # Initial index
  if [ "$SETUP_TEST_MODE" != "1" ] && curl -sf "http://localhost:8100/api/v2/heartbeat" > /dev/null 2>&1; then
    if command -v ollama &>/dev/null && ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
      echo "  Running initial vault index..."
      VAULT_ROOT="$VAULT_ROOT" CODEBASE_ROOT="$CODEBASE_ROOT" \
        "$CHROMA_DIR/venv/bin/$PYTHON_CMD" "$VAULT_SCRIPTS_DIR/vault_index.py" --full 2>/dev/null \
        && print_ok "Initial vault index complete" \
        || print_warn "Index failed. Run: vault-index --full"
    else
      print_info "Skipped index (Ollama not ready). Run later: vault-index --full"
    fi
  else
    print_info "Skipped index (ChromaDB not ready). Run later: vault-index --full"
  fi

else
  print_info "Local AI: skipped (saved preference)"
  if [ "$IS_UPDATE" = "false" ]; then
    print_info "Install later: re-run setup-wsl.sh --reconfigure and enable Local AI"
  fi
fi
phase_ok "11-local-ai"

# --- Phase 12: Optional Tools (macOS only) ---
# Note: WSL/Linux doesn't have Homebrew or app installation in the same way
if [ "$(uname)" = "Darwin" ]; then
  print_header "Phase 12: Optional Tools"
  if [ "$SETUP_TEST_MODE" = "1" ]; then
    print_ok "Optional tools skipped (test mode)"
  else
    echo -e "  ${BLUE}Recommended tools for the best dev experience.${NC}"
    echo -e "  ${BLUE}All optional — skip any with Enter.${NC}"
    echo ""

    if ! command -v brew &>/dev/null; then
      print_warn "Homebrew not found — skipping all optional tools"
      print_info "Install Homebrew first: https://brew.sh, then re-run setup.sh --reconfigure"
    else
      # Warp terminal
      if ls /Applications/Warp.app &>/dev/null 2>&1; then
        print_ok "Warp: already installed"
      else
        echo -e "  ${CYAN}Warp${NC} — modern terminal with AI, autocomplete, and team sharing"
        read -p "  Install Warp? (y/n) [y]: " INST_WARP
        if [ "${INST_WARP:-y}" = "y" ] || [ "${INST_WARP:-y}" = "Y" ]; then
          brew install --cask warp 2>/dev/null && print_ok "Warp installed" \
            || print_warn "Warp install failed. Download: https://warp.dev"
        fi
      fi

      # oh-my-zsh
      if [ -d "$HOME/.oh-my-zsh" ]; then
        print_ok "oh-my-zsh: already installed"
      else
        echo -e "  ${CYAN}oh-my-zsh${NC} — zsh framework with themes, plugins, and git status"
        read -p "  Install oh-my-zsh? (y/n) [y]: " INST_OMZ
        if [ "${INST_OMZ:-y}" = "y" ] || [ "${INST_OMZ:-y}" = "Y" ]; then
          RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" 2>/dev/null \
            && print_ok "oh-my-zsh installed (restart terminal to apply)" \
            || print_warn "oh-my-zsh install failed. See: https://ohmyz.sh"
        fi
      fi

      # OrbStack
      if ls /Applications/OrbStack.app &>/dev/null 2>&1; then
        print_ok "OrbStack: already installed"
      else
        echo -e "  ${CYAN}OrbStack${NC} — lightweight Docker Desktop replacement (faster, uses less RAM)"
        read -p "  Install OrbStack? (y/n) [n]: " INST_ORB
        if [ "${INST_ORB:-n}" = "y" ] || [ "${INST_ORB:-n}" = "Y" ]; then
          brew install --cask orbstack 2>/dev/null && print_ok "OrbStack installed" \
            || print_warn "OrbStack install failed. Download: https://orbstack.dev"
        fi
      fi

      # Shottr
      if ls /Applications/Shottr.app &>/dev/null 2>&1; then
        print_ok "Shottr: already installed"
      else
        echo -e "  ${CYAN}Shottr${NC} — screenshot tool with annotations, OCR, and clipboard history"
        read -p "  Install Shottr? (y/n) [n]: " INST_SHOTTR
        if [ "${INST_SHOTTR:-n}" = "y" ] || [ "${INST_SHOTTR:-n}" = "Y" ]; then
          brew install --cask shottr 2>/dev/null && print_ok "Shottr installed" \
            || print_warn "Shottr install failed. Download: https://shottr.cc"
        fi
      fi

      # TablePlus
      if ls /Applications/TablePlus.app &>/dev/null 2>&1; then
        print_ok "TablePlus: already installed"
      else
        echo -e "  ${CYAN}TablePlus${NC} — database GUI for PostgreSQL, MySQL, SQLite"
        read -p "  Install TablePlus? (y/n) [n]: " INST_TABLEPLUS
        if [ "${INST_TABLEPLUS:-n}" = "y" ] || [ "${INST_TABLEPLUS:-n}" = "Y" ]; then
          brew install --cask tableplus 2>/dev/null && print_ok "TablePlus installed" \
            || print_warn "TablePlus install failed. Download: https://tableplus.com"
        fi
      fi
    fi
  fi
  phase_ok "12-optional-tools"
else
  # Linux / WSL2 optional tools
  print_header "Phase 12: Optional Tools (Linux/WSL2)"
  if [ "$SETUP_TEST_MODE" = "1" ]; then
    print_ok "Optional tools skipped (test mode)"
  else
    echo -e "  ${BLUE}Recommended tools for the best dev experience.${NC}"
    echo -e "  ${BLUE}All optional — skip any with Enter.${NC}"
    echo ""

    # zsh (required for oh-my-zsh and the .zshrc template)
    if command -v zsh &>/dev/null; then
      print_ok "zsh: $(zsh --version 2>/dev/null | head -1)"
    else
      echo -e "  ${CYAN}zsh${NC} — shell required for oh-my-zsh and the .zshrc template"
      read -p "  Install zsh? (y/n) [y]: " INST_ZSH
      if [ "${INST_ZSH:-y}" = "y" ] || [ "${INST_ZSH:-y}" = "Y" ]; then
        sudo apt-get install -y zsh 2>/dev/null \
          && print_ok "zsh installed" \
          || print_warn "zsh install failed. Try: sudo apt-get install zsh"
      fi
    fi

    # oh-my-zsh
    if [ -d "$HOME/.oh-my-zsh" ]; then
      print_ok "oh-my-zsh: already installed"
    else
      echo -e "  ${CYAN}oh-my-zsh${NC} — zsh framework with themes, plugins, and git status"
      read -p "  Install oh-my-zsh? (y/n) [y]: " INST_OMZ
      if [ "${INST_OMZ:-y}" = "y" ] || [ "${INST_OMZ:-y}" = "Y" ]; then
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" 2>/dev/null \
          && print_ok "oh-my-zsh installed (restart terminal to apply)" \
          || print_warn "oh-my-zsh install failed. See: https://ohmyz.sh"
      fi
    fi

    # WSL2 clipboard tool (for pbpaste/pbcopy shims in .zshrc)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      if command -v xclip &>/dev/null || command -v xsel &>/dev/null || command -v wl-copy &>/dev/null; then
        print_ok "Clipboard tool: already installed ($(command -v xclip || command -v xsel || command -v wl-copy))"
      else
        echo -e "  ${CYAN}xclip${NC} — clipboard bridge for WSL2 (enables jsonf, b64e, jwtd helpers)"
        read -p "  Install xclip? (y/n) [y]: " INST_XCLIP
        if [ "${INST_XCLIP:-y}" = "y" ] || [ "${INST_XCLIP:-y}" = "Y" ]; then
          sudo apt-get install -y xclip 2>/dev/null \
            && print_ok "xclip installed" \
            || print_warn "xclip install failed. Try: sudo apt-get install xclip"
        fi
      fi
    fi

    # Modern CLI tools via apt
    echo ""
    echo -e "  ${BLUE}Modern CLI tools:${NC}"
    declare -A CLI_TOOLS=( ["bat"]="bat" ["fd-find"]="fdfind" ["ripgrep"]="rg" ["jq"]="jq" ["fzf"]="fzf" )
    for pkg in "${!CLI_TOOLS[@]}"; do
      cmd="${CLI_TOOLS[$pkg]}"
      if command -v "$cmd" &>/dev/null; then
        print_ok "$pkg: already installed"
      else
        sudo apt-get install -y "$pkg" 2>/dev/null \
          && print_ok "$pkg installed" \
          || print_warn "$pkg not installed. Try: sudo apt-get install $pkg"
      fi
    done
  fi
  phase_ok "12-optional-tools"
fi

# --- Version save + Cleanup old backups (keep last 3) ---
echo "$REPO_VERSION" > "$VERSION_FILE"
ls -dt "$CLAUDE_HOME/.claude/.setup-backup-"* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null || true

# --- Summary ---
if [ "$IS_UPDATE" = "true" ]; then
  print_header "Update Complete! ($INSTALLED_VERSION -> $REPO_VERSION)"
else
  print_header "Setup Complete! ($REPO_VERSION)"
fi

echo -e "${GREEN}${BOLD}Installed:${NC}"
MCP_COUNT=$($PYTHON_CMD -c "import json; print(len(json.load(open('$CLAUDE_JSON')).get('mcpServers',{})))" 2>/dev/null || echo "?")
echo "  $(ls "$CLAUDE_HOME/.claude/rules/"*.md 2>/dev/null | grep -v README.md | wc -l | tr -d ' ') rules | $(ls -d "$CLAUDE_HOME/.claude/skills/"*/ 2>/dev/null | wc -l | tr -d ' ') skills | $(ls "$CLAUDE_HOME/.claude/agents/"*.md 2>/dev/null | grep -v README.md | wc -l | tr -d ' ') agents | $MCP_COUNT MCP servers"
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
echo -e "${CYAN}Update:       bash scripts/setup-wsl.sh${NC}"
echo -e "${CYAN}Reconfigure:  bash scripts/setup-wsl.sh --reconfigure${NC}"
echo -e "${CYAN}Rollback:     cp -r $BACKUP_DIR/.claude/* ~/.claude/${NC}"
echo ""
echo -e "${GREEN}${BOLD}Version $REPO_VERSION installed. Phases: ${PHASES_COMPLETED[*]}${NC}"

# Vault RAG status (if Local AI enabled)
if [ "$INSTALL_LOCAL_AI" = "y" ] || [ "$INSTALL_LOCAL_AI" = "Y" ]; then
  if curl -sf "http://localhost:8100/api/v2/heartbeat" > /dev/null 2>&1; then
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  Vault RAG — running${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ChromaDB dashboard:  ${CYAN}http://localhost:8100${NC}"
    echo ""
    echo -e "  Use in ${BOLD}Claude Code${NC}:"
    echo -e "    ${CYAN}query_vault(\"your question here\")${NC}"
    echo ""
    echo -e "  Use in ${BOLD}Cursor${NC}:"
    echo -e "    Reference ${CYAN}@local-le-chromadb${NC} in your prompt"
    echo ""
    echo -e "  CLI:"
    echo -e "    ${CYAN}vault-query \"boolean validation zod\"${NC}"
    echo -e "    ${CYAN}vault-index --full${NC}   (re-index everything)"
    echo -e "    ${CYAN}vault-watch${NC}           (auto-index on file changes)"
  fi
fi

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
4. **Hooks**: list files in ~/.claude/hooks/, confirm 22 .sh files are executable, confirm ~/.claude/statusline-command.sh exists
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
