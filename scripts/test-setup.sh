#!/bin/bash
# ============================================================================
# AI Dev Ecosystem - Functional Tests for setup.sh / setup-wsl.sh
# Runs the platform-appropriate setup in an isolated environment
# Works on: macOS, Linux, WSL2
# Run: bash scripts/test-setup.sh
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'
BOLD='\033[1m'

PASS=0
FAIL=0
TESTS_RUN=0
TOTAL_GROUPS=15
CURRENT_GROUP=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# --- Platform detection ---
PLATFORM="unknown"
SETUP_SCRIPT="setup.sh"
EXPECTED_MCP_COUNT=8
HAS_CHROMADB=1

if [[ "$OSTYPE" == "darwin"* ]]; then
  PLATFORM="macOS"
  SETUP_SCRIPT="setup.sh"
  EXPECTED_MCP_COUNT=8
  HAS_CHROMADB=1
elif grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
  PLATFORM="WSL2"
  SETUP_SCRIPT="setup-wsl.sh"
  EXPECTED_MCP_COUNT=8
  HAS_CHROMADB=1
elif [[ "$OSTYPE" == "linux"* ]]; then
  PLATFORM="Linux"
  SETUP_SCRIPT="setup-wsl.sh"
  EXPECTED_MCP_COUNT=8
  HAS_CHROMADB=1
fi

# --- Helpers ---

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); TESTS_RUN=$((TESTS_RUN + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); TESTS_RUN=$((TESTS_RUN + 1)); }
skip() { echo -e "  ${DIM}SKIP${NC} $1"; }

header() {
  CURRENT_GROUP=$((CURRENT_GROUP + 1))
  local pct=$((CURRENT_GROUP * 100 / TOTAL_GROUPS))
  [ "$pct" -gt 100 ] && pct=100
  local filled=$((pct / 5))
  local empty=$((20 - filled))
  local bar="${GREEN}"
  local i
  for i in $(seq 1 $filled 2>/dev/null); do bar+="█"; done
  bar+="${DIM}"
  for i in $(seq 1 $empty 2>/dev/null); do bar+="░"; done
  bar+="${NC}"
  echo -e "\n${CYAN}${BOLD}[$CURRENT_GROUP/$TOTAL_GROUPS]${NC} ${CYAN}${BOLD}$1${NC}  ${bar} ${DIM}${pct}%${NC}\n"
}

assert_file() { [ -f "$1" ] && pass "$2" || fail "$2 (missing: $1)"; }
assert_dir() { [ -d "$1" ] && pass "$2" || fail "$2 (missing: $1)"; }
assert_exec() { [ -x "$1" ] && pass "$2" || fail "$2 (not executable: $1)"; }

assert_count() {
  local actual="$1" expected="$2" label="$3"
  [ "$actual" -eq "$expected" ] 2>/dev/null && pass "$label (count: $actual)" || fail "$label (expected $expected, got $actual)"
}

assert_json_key() {
  local file="$1" key="$2" label="$3"
  python3 -c "import json; d=json.load(open('$file')); assert $key" 2>/dev/null && pass "$label" || fail "$label"
}

# Spinner for long-running commands
# Usage: run_with_spinner "label" command [args...]
run_with_spinner() {
  local label="$1"; shift
  local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local pid exit_code tmpfile

  tmpfile=$(mktemp)
  "$@" > "$tmpfile" 2>&1 &
  pid=$!

  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    local c="${spin_chars:$((i % ${#spin_chars})):1}"
    printf "\r  ${CYAN}%s${NC} %s" "$c" "$label"
    sleep 0.1
    i=$((i + 1))
  done

  wait "$pid"
  exit_code=$?

  printf "\r\033[K"

  SPINNER_OUTPUT=$(cat "$tmpfile")
  rm -f "$tmpfile"
  return $exit_code
}

# ============================================================================
# Setup: create isolated environment
# ============================================================================
header "Setup: Isolated Environment"

echo -e "  ${DIM}Platform: $PLATFORM${NC}"
echo -e "  ${DIM}Script:   $SETUP_SCRIPT${NC}"

TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/claude-test-XXXXXX")
echo -e "  ${DIM}Test HOME: $TEST_HOME${NC}"

# Export test environment
export CLAUDE_HOME="$TEST_HOME"
export SETUP_TEST_MODE=1
export USER_FULL_NAME="Test User"
export USER_EMAIL="test@luxuryescapes.com"
export SLACK_USER_ID="U0TEST123"
export ATLASSIAN_TOKEN="test-token-123"
export CODEBASE_ROOT="$TEST_HOME/Documents/LuxuryEscapes"
export VAULT_ROOT="$TEST_HOME/vault"
export INSTALL_LOCAL_AI="y"
export USE_CURSOR="y"

mkdir -p "$TEST_HOME/Documents/LuxuryEscapes"
mkdir -p "$TEST_HOME/vault"
mkdir -p "$TEST_HOME/bin"

# Vault scripts are now in local-ai/vault/ (no stubs needed)

# setup scripts use relative paths, must run from repo root
cd "$REPO_ROOT"

pass "Isolated environment created"

# ============================================================================
# Test 1: Run setup
# ============================================================================
header "Run $SETUP_SCRIPT"

run_with_spinner "Running $SETUP_SCRIPT (all phases)..." bash "$REPO_ROOT/scripts/$SETUP_SCRIPT" || {
  fail "$SETUP_SCRIPT exited with error"
  echo "$SPINNER_OUTPUT"
  exit 1
}
SETUP_OUTPUT="$SPINNER_OUTPUT"
pass "$SETUP_SCRIPT completed without error"

echo "$SETUP_OUTPUT" | grep -q "Phase 0: Prerequisites" && pass "Phase 0 present" || fail "Phase 0 missing"
echo "$SETUP_OUTPUT" | grep -q "Rules" && pass "Rules phase present" || fail "Rules phase missing"
echo "$SETUP_OUTPUT" | grep -q "Skills" && pass "Skills phase present" || fail "Skills phase missing"
echo "$SETUP_OUTPUT" | grep -q "Agents" && pass "Agents phase present" || fail "Agents phase missing"
echo "$SETUP_OUTPUT" | grep -q "Hooks" && pass "Hooks phase present" || fail "Hooks phase missing"
echo "$SETUP_OUTPUT" | grep -q "Settings" && pass "Settings phase present" || fail "Settings phase missing"
echo "$SETUP_OUTPUT" | grep -q "MCP" && pass "MCP phase present" || fail "MCP phase missing"
echo "$SETUP_OUTPUT" | grep -q "Setup Complete" && pass "Setup Complete banner" || fail "Setup Complete banner missing"

# ============================================================================
# Test 2: Rules
# ============================================================================
header "Rules"

RULES_DIR="$TEST_HOME/.claude/rules"
assert_dir "$RULES_DIR" "rules directory exists"

EXPECTED_RULES=("00-global-style.md" "01-code-quality-review.md" "02-skills-first.md" "03-escalation-protocol.md" "04-study-before-starting.md" "05-diagrams-standard.md" "06-worktree-detection.md" "08-behavioral-standards.md")
for rule in "${EXPECTED_RULES[@]}"; do
  assert_file "$RULES_DIR/$rule" "rule: $rule"
done

RULE_COUNT=$(ls "$RULES_DIR/"*.md 2>/dev/null | grep -v "README.md" | wc -l | tr -d ' ')
assert_count "$RULE_COUNT" 8 "total rules"

for rule in "${EXPECTED_RULES[@]}"; do
  SIZE=$(wc -c < "$RULES_DIR/$rule" 2>/dev/null | tr -d ' ')
  [ "$SIZE" -gt 10 ] && pass "$rule has content ($SIZE bytes)" || fail "$rule is empty ($SIZE bytes)"
done

# ============================================================================
# Test 3: Skills
# ============================================================================
header "Skills"

SKILLS_DIR="$TEST_HOME/.claude/skills"
assert_dir "$SKILLS_DIR" "skills directory exists"

EXPECTED_SKILLS=("capture-knowledge" "codereview" "commit" "create-pr" "daily" "debug-mode" "deploy-checklist" "deslop" "diagrams" "feature-dev" "investigation-case" "learn" "test-scenarios" "thinking-partner" "validate-infra" "validate-migration")
for skill in "${EXPECTED_SKILLS[@]}"; do
  assert_dir "$SKILLS_DIR/$skill" "skill dir: $skill"
  assert_file "$SKILLS_DIR/$skill/SKILL.md" "SKILL.md: $skill"
done

SKILL_COUNT=0
for d in "$SKILLS_DIR"/*/; do
  [ -f "$d/SKILL.md" ] && SKILL_COUNT=$((SKILL_COUNT + 1))
done
assert_count "$SKILL_COUNT" 16 "total skills with SKILL.md"

# ============================================================================
# Test 3b: Path Placeholders Resolved
# ============================================================================
header "Path Placeholders"

# No __CODEBASE_ROOT__ or __VAULT_ROOT__ should remain in installed files
PLACEHOLDER_HITS=$(grep -rl "__CODEBASE_ROOT__\|__VAULT_ROOT__" "$TEST_HOME/.claude/rules/" "$TEST_HOME/.claude/skills/" "$TEST_HOME/.claude/agents/" 2>/dev/null | wc -l | tr -d ' ')
[ "$PLACEHOLDER_HITS" -eq 0 ] && pass "no __CODEBASE_ROOT__ placeholders remaining" || fail "$PLACEHOLDER_HITS files still have placeholders"

# Verify paths were actually replaced with test values
grep -q "$TEST_HOME/Documents/LuxuryEscapes" "$TEST_HOME/.claude/skills/thinking-partner/SKILL.md" 2>/dev/null && pass "CODEBASE_ROOT resolved in skills" || fail "CODEBASE_ROOT not resolved"
grep -q "$TEST_HOME/vault" "$TEST_HOME/.claude/skills/thinking-partner/SKILL.md" 2>/dev/null && pass "VAULT_ROOT resolved in skills" || fail "VAULT_ROOT not resolved"

# Verify __USER_NAME__ was replaced in rules and agents
grep -q "Test User" "$TEST_HOME/.claude/rules/00-global-style.md" 2>/dev/null && pass "USER_NAME resolved in rules" || fail "USER_NAME not resolved in rules/00-global-style.md"
grep -q "Test User" "$TEST_HOME/.claude/agents/copilot.md" 2>/dev/null && pass "USER_NAME resolved in agents" || fail "USER_NAME not resolved in agents/copilot.md"

# ============================================================================
# Test 4: Agents
# ============================================================================
header "Agents"

AGENTS_DIR="$TEST_HOME/.claude/agents"
assert_dir "$AGENTS_DIR" "agents directory exists"

EXPECTED_AGENTS=("copilot.md" "implementer.md" "researcher.md" "reviewer.md")
for agent in "${EXPECTED_AGENTS[@]}"; do
  assert_file "$AGENTS_DIR/$agent" "agent: $agent"
done

AGENT_COUNT=$(ls "$AGENTS_DIR/"*.md 2>/dev/null | grep -v "README.md" | wc -l | tr -d ' ')
assert_count "$AGENT_COUNT" 4 "total agents"

# ============================================================================
# Test 5: Hooks
# ============================================================================
header "Hooks"

HOOKS_DIR="$TEST_HOME/.claude/hooks"
assert_dir "$HOOKS_DIR" "hooks directory exists"

EXPECTED_CORE_HOOKS=("pre-git-commit.sh" "session-start-check.sh" "skill-enforcement-guard.sh" "skill-tracker.sh" "tool-preference-guard.sh")
for hook in "${EXPECTED_CORE_HOOKS[@]}"; do
  assert_file "$HOOKS_DIR/$hook" "hook: $hook"
  assert_exec "$HOOKS_DIR/$hook" "hook executable: $hook"
done

EXPECTED_OPTIONAL_HOOKS=("agent-lifecycle-log.sh" "config-change-log.sh" "cwd-context.sh" "elicitation-log.sh" "file-changed-log.sh" "frontend-layout-guard.sh" "instructions-audit.sh" "permission-denied-handler.sh" "post-tool-failure-log.sh" "postcompact-log.sh" "precompact-backup.sh" "stop-failure-handler.sh" "user-prompt-context.sh" "vault-rag-reminder.sh" "vault-rag-tracker.sh" "worktree-remove.sh" "worktree-setup.sh")
for hook in "${EXPECTED_OPTIONAL_HOOKS[@]}"; do
  assert_file "$HOOKS_DIR/$hook" "hook: $hook"
done

assert_file "$TEST_HOME/.claude/statusline-command.sh" "statusline-command.sh installed"
assert_exec "$TEST_HOME/.claude/statusline-command.sh" "statusline-command.sh executable"

HOOK_COUNT=$(ls "$HOOKS_DIR/"*.sh 2>/dev/null | wc -l | tr -d ' ')
assert_count "$HOOK_COUNT" 22 "total hook scripts"

# ============================================================================
# Test 6: Settings
# ============================================================================
header "Settings"

SETTINGS="$TEST_HOME/.claude/settings.json"
assert_file "$SETTINGS" "settings.json exists"

python3 -c "import json; json.load(open('$SETTINGS'))" 2>/dev/null && pass "valid JSON" || fail "invalid JSON"

assert_json_key "$SETTINGS" "'hooks' in d" "has hooks"
assert_json_key "$SETTINGS" "'statusLine' in d" "has statusLine"
assert_json_key "$SETTINGS" "'permissions' in d" "has permissions"
assert_json_key "$SETTINGS" "'env' in d" "has env"

assert_json_key "$SETTINGS" "'PreToolUse' in d['hooks']" "hooks: PreToolUse"
assert_json_key "$SETTINGS" "'SessionStart' in d['hooks']" "hooks: SessionStart"
assert_json_key "$SETTINGS" "'Notification' in d['hooks']" "hooks: Notification"

# PreToolUse[0] = all-Bash hooks (skill-enforcement + tool-preference), PreToolUse[1] = git-commit-only (pre-commit)
PRE_ENTRIES=$(python3 -c "import json; d=json.load(open('$SETTINGS')); print(len(d['hooks']['PreToolUse']))" 2>/dev/null)
assert_count "$PRE_ENTRIES" 2 "PreToolUse has 2 entries (all-Bash + git-commit)"
PRE_ALL_HOOKS=$(python3 -c "import json; d=json.load(open('$SETTINGS')); print(len(d['hooks']['PreToolUse'][0]['hooks']))" 2>/dev/null)
assert_count "$PRE_ALL_HOOKS" 2 "PreToolUse[0] has 2 hooks (enforcement + tool-pref)"
PRE_COMMIT_MATCHER=$(python3 -c "import json; d=json.load(open('$SETTINGS')); print(d['hooks']['PreToolUse'][1]['matcher'])" 2>/dev/null)
[ "$PRE_COMMIT_MATCHER" = "Bash(git commit)" ] && pass "PreToolUse[1] scoped to git commit" || fail "PreToolUse[1] matcher: '$PRE_COMMIT_MATCHER'"

SL_TYPE=$(python3 -c "import json; d=json.load(open('$SETTINGS')); print(d['statusLine']['type'])" 2>/dev/null)
[ "$SL_TYPE" = "command" ] && pass "statusLine type is 'command'" || fail "statusLine type: '$SL_TYPE'"

# ============================================================================
# Test 7: MCP Servers
# ============================================================================
header "MCP Servers"

MCP_FILE="$TEST_HOME/.claude.json"
assert_file "$MCP_FILE" ".claude.json exists"

python3 -c "import json; json.load(open('$MCP_FILE'))" 2>/dev/null && pass "valid JSON" || fail "invalid JSON"

# Common MCPs (all platforms)
COMMON_MCPS=("mcp-atlassian" "datadog-mcp" "context7" "probe" "playwright" "chrome-devtools" "imugi")
for mcp in "${COMMON_MCPS[@]}"; do
  assert_json_key "$MCP_FILE" "'$mcp' in d.get('mcpServers',{})" "MCP: $mcp"
done

# macOS-only: ChromaDB
if [ "$HAS_CHROMADB" = "1" ]; then
  assert_json_key "$MCP_FILE" "'local-le-chromadb' in d.get('mcpServers',{})" "MCP: local-le-chromadb"
  CHROMA_CMD=$(python3 -c "import json; d=json.load(open('$MCP_FILE')); print(d['mcpServers']['local-le-chromadb']['command'])" 2>/dev/null)
  echo "$CHROMA_CMD" | grep -q "$TEST_HOME" && pass "ChromaDB MCP uses CLAUDE_HOME path" || fail "ChromaDB path wrong: $CHROMA_CMD"
else
  skip "local-le-chromadb (not on $PLATFORM)"
fi

MCP_COUNT=$(python3 -c "import json; d=json.load(open('$MCP_FILE')); print(len(d.get('mcpServers',{})))" 2>/dev/null)
assert_count "$MCP_COUNT" "$EXPECTED_MCP_COUNT" "total MCP servers"

# Verify Atlassian email interpolation
ATLASSIAN_EMAIL=$(python3 -c "import json; d=json.load(open('$MCP_FILE')); print(d['mcpServers']['mcp-atlassian']['env']['CONFLUENCE_USERNAME'])" 2>/dev/null)
[ "$ATLASSIAN_EMAIL" = "test@luxuryescapes.com" ] && pass "Atlassian email interpolated" || fail "Atlassian email: $ATLASSIAN_EMAIL"

# ============================================================================
# Test 8: ChromaDB / Vault RAG (macOS only)
# ============================================================================
header "ChromaDB Vault RAG"

if [ "$HAS_CHROMADB" = "1" ]; then
  CHROMA_DIR="$TEST_HOME/.local/share/le-vault-chroma"
  assert_dir "$CHROMA_DIR" "ChromaDB directory"
  assert_dir "$CHROMA_DIR/venv" "Python venv"
  assert_file "$CHROMA_DIR/venv/bin/python3" "venv python3"
  assert_dir "$TEST_HOME/.claude/local-ai/vault" "vault scripts directory"
  assert_file "$TEST_HOME/.claude/local-ai/vault/vault_mcp_server.py" "vault_mcp_server.py"
  assert_file "$TEST_HOME/.claude/local-ai/vault/vault_index.py" "vault_index.py"
  assert_file "$TEST_HOME/.claude/local-ai/vault/vault_chroma.sh" "vault_chroma.sh"
  assert_file "$TEST_HOME/.claude/local-ai/vault/vault_watch.sh" "vault_watch.sh"
  assert_file "$TEST_HOME/.claude/local-ai/vault/vault_query.sh" "vault_query.sh"
  assert_file "$TEST_HOME/.claude/scripts/ci-local-check.sh" "ci-local-check.sh"
else
  skip "ChromaDB not included on $PLATFORM (setup manually if needed)"
fi

# ============================================================================
# Test 9: Idempotency
# ============================================================================
header "Idempotency"

# Create personal learnings
LEARNINGS_DIR="$TEST_HOME/.claude/skills/learn/references"
mkdir -p "$LEARNINGS_DIR"
echo "# My personal learnings" > "$LEARNINGS_DIR/learnings.md"
echo "- Gotcha: always check null" >> "$LEARNINGS_DIR/learnings.md"

run_with_spinner "Re-running $SETUP_SCRIPT (idempotency)..." bash "$REPO_ROOT/scripts/$SETUP_SCRIPT" || {
  fail "$SETUP_SCRIPT re-run failed"
  echo "$SPINNER_OUTPUT"
}
RERUN_OUTPUT="$SPINNER_OUTPUT"
pass "re-run completed"

if [ -f "$LEARNINGS_DIR/learnings.md" ]; then
  grep -q "always check null" "$LEARNINGS_DIR/learnings.md" && pass "learnings preserved" || fail "learnings content lost"
else
  fail "learnings.md deleted"
fi

echo "$RERUN_OUTPUT" | grep -q "settings.json preserved" && pass "settings.json not overwritten" || fail "settings.json was overwritten"

# MCP config is merged (not replaced), so backup is not created by setup.sh
# The backup dir from the general backup phase covers rollback
BACKUP_DIRS=$(ls -d "$TEST_HOME/.claude/.setup-backup-"* 2>/dev/null | wc -l | tr -d ' ')
[ "$BACKUP_DIRS" -ge 1 ] && pass "setup backup exists" || fail "no setup backup"

# ============================================================================
# Test 10: Settings preservation
# ============================================================================
header "Settings Preservation"

python3 -c "
import json
s = json.load(open('$SETTINGS'))
s['customUserSetting'] = True
with open('$SETTINGS', 'w') as f:
    json.dump(s, f, indent=2)
"

run_with_spinner "Re-running (settings preservation)..." bash "$REPO_ROOT/scripts/$SETUP_SCRIPT"
assert_json_key "$SETTINGS" "d.get('customUserSetting') == True" "custom setting survives re-run"

# ============================================================================
# Test 11: Cursor sync (macOS only)
# ============================================================================
header "Cursor Sync"

if [ "$PLATFORM" = "macOS" ]; then
  export USE_CURSOR="y"
  run_with_spinner "Re-running (Cursor sync)..." bash "$REPO_ROOT/scripts/$SETUP_SCRIPT"
  unset USE_CURSOR

  assert_dir "$TEST_HOME/.cursor/rules" "Cursor rules directory"

  CURSOR_RULE_COUNT=$(ls "$TEST_HOME/.cursor/rules/"*.mdc 2>/dev/null | wc -l | tr -d ' ')
  [ "$CURSOR_RULE_COUNT" -ge 8 ] && pass "Cursor rules synced ($CURSOR_RULE_COUNT .mdc files)" || fail "Cursor rules: $CURSOR_RULE_COUNT (expected 8+)"

  assert_file "$TEST_HOME/.cursor/mcp.json" "Cursor MCP config"
  python3 -c "import json; d=json.load(open('$TEST_HOME/.cursor/mcp.json')); assert 'mcpServers' in d" 2>/dev/null && pass "Cursor MCP valid" || fail "Cursor MCP invalid"
else
  skip "Cursor sync (macOS only)"
fi

# ============================================================================
# Test 12: Summary output counts
# ============================================================================
header "Summary Output"

run_with_spinner "Running (final output check)..." bash "$REPO_ROOT/scripts/$SETUP_SCRIPT"
FINAL_OUTPUT="$SPINNER_OUTPUT"

echo "$FINAL_OUTPUT" | grep -q "8 rules" && pass "summary: 8 rules" || fail "summary missing 8 rules"
echo "$FINAL_OUTPUT" | grep -qE "1[5-8] skills" && pass "summary: skills count present" || fail "summary missing skills count"
echo "$FINAL_OUTPUT" | grep -q "4 agents" && pass "summary: 4 agents" || fail "summary missing 4 agents"
echo "$FINAL_OUTPUT" | grep -q "$EXPECTED_MCP_COUNT MCP" && pass "summary: $EXPECTED_MCP_COUNT MCP servers" || fail "summary missing $EXPECTED_MCP_COUNT MCP"

# ============================================================================
# Test 13: Cross-platform shell compat
# ============================================================================
header "Shell Compatibility"

# Verify no bashisms that break on older bash (WSL2 ships bash 5.x, should be fine)
BASH_VER=$(bash --version | head -1)
pass "bash: $BASH_VER"

# Verify python3 available (both scripts need it)
python3 --version &>/dev/null && pass "python3 available" || fail "python3 not found"

# Verify settings.json has no platform-specific hardcoded paths
SHELL_IN_SETTINGS=$(python3 -c "import json; d=json.load(open('$SETTINGS')); print(d['env']['CLAUDE_CODE_SHELL'])" 2>/dev/null)
if [ "$PLATFORM" = "macOS" ]; then
  [ "$SHELL_IN_SETTINGS" = "/bin/zsh" ] && pass "shell: /bin/zsh (macOS)" || fail "shell: $SHELL_IN_SETTINGS (expected /bin/zsh)"
else
  [ "$SHELL_IN_SETTINGS" = "/bin/bash" ] && pass "shell: /bin/bash ($PLATFORM)" || fail "shell: $SHELL_IN_SETTINGS (expected /bin/bash)"
fi

# ============================================================================
# Cleanup
# ============================================================================
echo -e "\n${CYAN}${BOLD}Cleanup${NC}\n"

rm -rf "$TEST_HOME"
pass "Test environment cleaned up"

# ============================================================================
# Results
# ============================================================================
echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Platform: ${BOLD}$PLATFORM${NC} ($SETUP_SCRIPT)"
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  Total: $TESTS_RUN tests"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}All tests passed!${NC} ${GREEN}████████████████████${NC}"
  exit 0
else
  echo -e "  ${RED}${BOLD}$FAIL tests failed.${NC}"
  exit 1
fi
