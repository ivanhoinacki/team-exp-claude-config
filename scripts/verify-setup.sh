#!/bin/bash
# ============================================================================
# AI Dev Ecosystem - Setup Verification
# Validates that all components were installed correctly
# Run: bash scripts/verify-setup.sh
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}  PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}  FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}  WARN${NC} $1"; WARN=$((WARN + 1)); }
header() { echo -e "\n${BOLD}=== $1 ===${NC}\n"; }

# --- Prerequisites ---
header "1. Prerequisites"

command -v claude &>/dev/null && pass "claude CLI installed ($(claude --version 2>/dev/null | head -1))" || fail "claude CLI not found"
command -v node &>/dev/null && pass "node installed ($(node --version))" || fail "node not found"
command -v git &>/dev/null && pass "git installed" || fail "git not found"
command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1 && pass "GitHub CLI authenticated" || warn "GitHub CLI not authenticated (run: gh auth login)"
command -v python3 &>/dev/null && pass "python3 installed ($(python3 --version 2>&1))" || fail "python3 not found"
command -v uvx &>/dev/null && pass "uvx installed" || warn "uvx not found (run: curl -LsSf https://astral.sh/uv/install.sh | sh)"

# --- Rules ---
header "2. Rules (expect 8)"

RULES_DIR="$HOME/.claude/rules"
EXPECTED_RULES=("00-global-style.md" "01-code-quality-review.md" "02-skills-first.md" "03-escalation-protocol.md" "04-study-before-starting.md" "05-diagrams-standard.md" "06-worktree-detection.md" "08-behavioral-standards.md")

for rule in "${EXPECTED_RULES[@]}"; do
  [ -f "$RULES_DIR/$rule" ] && pass "$rule" || fail "$rule missing"
done

RULE_COUNT=$(ls "$RULES_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$RULE_COUNT" -ge 8 ] && pass "Total: $RULE_COUNT rules" || fail "Expected 8+ rules, found $RULE_COUNT"

# --- Skills ---
header "3. Skills (expect 16)"

SKILLS_DIR="$HOME/.claude/skills"
EXPECTED_SKILLS=("capture-knowledge" "codereview" "commit" "create-pr" "daily" "debug-mode" "deploy-checklist" "deslop" "diagrams" "feature-dev" "investigation-case" "learn" "test-scenarios" "thinking-partner" "validate-infra" "validate-migration")

for skill in "${EXPECTED_SKILLS[@]}"; do
  if [ -d "$SKILLS_DIR/$skill" ] && [ -f "$SKILLS_DIR/$skill/SKILL.md" ]; then
    pass "$skill"
  else
    fail "$skill missing or no SKILL.md"
  fi
done

SKILL_COUNT=0
for d in "$SKILLS_DIR"/*/; do
  [ -f "$d/SKILL.md" ] && SKILL_COUNT=$((SKILL_COUNT + 1))
done
[ "$SKILL_COUNT" -ge 16 ] && pass "Total: $SKILL_COUNT skills with SKILL.md" || fail "Expected 16+ skills, found $SKILL_COUNT"

# --- Agents ---
header "4. Agents (expect 4)"

AGENTS_DIR="$HOME/.claude/agents"
EXPECTED_AGENTS=("copilot.md" "researcher.md" "implementer.md" "reviewer.md")

for agent in "${EXPECTED_AGENTS[@]}"; do
  [ -f "$AGENTS_DIR/$agent" ] && pass "$agent" || fail "$agent missing"
done

# --- Hooks ---
header "5. Hooks (expect 22 scripts + statusline)"

HOOKS_DIR="$HOME/.claude/hooks"
EXPECTED_HOOKS=("pre-git-commit.sh" "session-start-check.sh" "skill-enforcement-guard.sh" "skill-tracker.sh" "tool-preference-guard.sh" "agent-lifecycle-log.sh" "config-change-log.sh" "cwd-context.sh" "elicitation-log.sh" "file-changed-log.sh" "frontend-layout-guard.sh" "instructions-audit.sh" "permission-denied-handler.sh" "post-tool-failure-log.sh" "postcompact-log.sh" "precompact-backup.sh" "stop-failure-handler.sh" "user-prompt-context.sh" "vault-rag-reminder.sh" "vault-rag-tracker.sh" "worktree-remove.sh" "worktree-setup.sh")

for hook in "${EXPECTED_HOOKS[@]}"; do
  if [ -f "$HOOKS_DIR/$hook" ] && [ -x "$HOOKS_DIR/$hook" ]; then
    pass "$hook (executable)"
  elif [ -f "$HOOKS_DIR/$hook" ]; then
    warn "$hook exists but not executable"
  else
    fail "$hook missing"
  fi
done

[ -f "$HOME/.claude/statusline-command.sh" ] && pass "statusline-command.sh" || fail "statusline-command.sh missing"

# --- Settings ---
header "6. Settings"

SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  pass "settings.json exists"

  python3 -c "import json; d=json.load(open('$SETTINGS')); assert 'hooks' in d" 2>/dev/null && pass "hooks configured" || fail "hooks missing from settings.json"
  python3 -c "import json; d=json.load(open('$SETTINGS')); assert 'statusLine' in d" 2>/dev/null && pass "statusLine configured" || fail "statusLine missing from settings.json"
  python3 -c "import json; d=json.load(open('$SETTINGS')); assert 'PreToolUse' in d['hooks']" 2>/dev/null && pass "PreToolUse hooks present" || fail "PreToolUse hooks missing"
  python3 -c "import json; d=json.load(open('$SETTINGS')); assert 'PostToolUse' in d['hooks']" 2>/dev/null && pass "PostToolUse hooks present" || warn "PostToolUse hooks missing (skill tracker)"
  python3 -c "import json; d=json.load(open('$SETTINGS')); assert 'SessionStart' in d['hooks']" 2>/dev/null && pass "SessionStart hooks present" || fail "SessionStart hooks missing"
  python3 -c "import json; d=json.load(open('$SETTINGS')); assert 'Notification' in d['hooks']" 2>/dev/null && pass "Notification hooks present" || warn "Notification hooks missing"

  # Count PreToolUse hooks
  PRE_ENTRIES=$(python3 -c "import json; d=json.load(open('$SETTINGS')); print(len(d['hooks']['PreToolUse']))" 2>/dev/null)
  [ "$PRE_ENTRIES" -ge 2 ] 2>/dev/null && pass "PreToolUse has $PRE_ENTRIES entries (all-Bash + git-commit)" || warn "PreToolUse has $PRE_ENTRIES entries, expected 2"
else
  fail "settings.json not found"
fi

# --- MCP Servers ---
header "7. MCP Servers (expect 7 base + optional local-le-chromadb)"

MCP_FILE="$HOME/.claude.json"
if [ -f "$MCP_FILE" ]; then
  pass ".claude.json exists"

  # 7 base MCPs always installed
  BASE_MCPS=("mcp-atlassian" "datadog-mcp" "context7" "probe" "playwright" "chrome-devtools" "imugi")
  for mcp in "${BASE_MCPS[@]}"; do
    python3 -c "import json; d=json.load(open('$MCP_FILE')); assert '$mcp' in d.get('mcpServers',{})" 2>/dev/null && pass "$mcp configured" || fail "$mcp missing"
  done

  # local-le-chromadb is optional (only if Local AI enabled)
  python3 -c "import json; d=json.load(open('$MCP_FILE')); assert 'local-le-chromadb' in d.get('mcpServers',{})" 2>/dev/null \
    && pass "local-le-chromadb configured (Local AI enabled)" \
    || warn "local-le-chromadb not configured (Local AI disabled, expected if you skipped it)"

  MCP_COUNT=$(python3 -c "import json; d=json.load(open('$MCP_FILE')); print(len(d.get('mcpServers',{})))" 2>/dev/null)
  [ "$MCP_COUNT" -ge 7 ] && pass "Total: $MCP_COUNT MCP servers" || fail "Expected 7+ MCP servers, found $MCP_COUNT"
else
  fail ".claude.json not found"
fi

# --- ChromaDB / Vault RAG ---
header "8. ChromaDB Vault RAG"

CHROMA_DIR="$HOME/.local/share/le-vault-chroma"
[ -d "$CHROMA_DIR/venv" ] && pass "Python venv exists" || fail "Python venv missing at $CHROMA_DIR/venv"
[ -f "$CHROMA_DIR/venv/bin/python3" ] && pass "venv python3 exists" || fail "venv python3 missing"
"$CHROMA_DIR/venv/bin/python3" -c "import chromadb" 2>/dev/null && pass "chromadb package installed" || fail "chromadb package missing (run: $CHROMA_DIR/venv/bin/pip install chromadb)"
"$CHROMA_DIR/venv/bin/python3" -c "import ollama" 2>/dev/null && pass "ollama Python package installed" || warn "ollama Python package not in venv (ok if vault-index uses HTTP API directly)"
[ -f "$HOME/.claude/local-ai/vault/vault_mcp_server.py" ] && pass "vault_mcp_server.py installed" || fail "vault_mcp_server.py missing (~/.claude/local-ai/vault/)"
[ -f "$HOME/.claude/local-ai/vault/vault_index.py" ] && pass "vault_index.py installed" || fail "vault_index.py missing (~/.claude/local-ai/vault/)"
[ -L "$HOME/bin/vault-chroma" ] && pass "vault-chroma CLI symlink" || warn "vault-chroma symlink missing (~/bin/vault-chroma)"
[ -L "$HOME/bin/vault-index" ] && pass "vault-index CLI symlink" || warn "vault-index symlink missing (~/bin/vault-index)"

# Check Docker container
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q chromadb; then
  pass "ChromaDB Docker container running"
else
  warn "ChromaDB Docker container not running (run: docker run -d --name chromadb -p 8100:8000 chromadb/chroma)"
fi

# Check Ollama model
if command -v ollama &>/dev/null; then
  ollama list 2>/dev/null | grep -q "nomic-embed-text" && pass "Ollama nomic-embed-text model available" || warn "Ollama model nomic-embed-text not pulled (run: ollama pull nomic-embed-text)"
else
  warn "Ollama not installed (needed for embeddings)"
fi

# Check fswatch
if command -v fswatch &>/dev/null; then
  pass "fswatch installed"
else
  warn "fswatch not installed (brew install fswatch)"
fi

# --- Summary ---
header "Results"

TOTAL=$((PASS + FAIL + WARN))
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo -e "  Total: $TOTAL checks"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All critical checks passed!${NC}"
  if [ "$WARN" -gt 0 ]; then
    echo -e "${YELLOW}$WARN warnings to review (non-blocking).${NC}"
  fi
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL critical checks failed. Run setup.sh to fix.${NC}"
  exit 1
fi
