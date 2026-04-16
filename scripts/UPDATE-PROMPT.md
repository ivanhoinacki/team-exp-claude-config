# Self-Update Prompt

Paste this prompt into Claude Code to update your team-exp-claude-config installation.

> **Automated alternative**: `bash scripts/update.sh` runs git pull + full setup while preserving your personal config.

---

```
Update my team-exp-claude-config setup following these exact steps:

1. Pull latest from repo:
   cd ~/Documents/LuxuryEscapes/team-exp-claude-config && git pull

2. Copy ALL .sh files from hooks/ to ~/.claude/hooks/:
   cp hooks/*.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/*.sh
   This includes 2 new hooks: db-tunnel-guard.sh (blocks direct le aws postgres, forces le-tunnel.sh) and session-end-save.sh (saves Session-Memory via local Ollama).

3. Copy utility scripts:
   mkdir -p ~/.claude/scripts
   cp scripts/plantuml_encode.py ~/.claude/scripts/ && chmod +x ~/.claude/scripts/plantuml_encode.py

4. Remove statusline-command.sh (deprecated, Claude Code built-in replaces it):
   rm -f ~/.claude/statusline-command.sh

5. Patch ~/.claude/settings.json (Read first, then Edit):
   a. In the PreToolUse array, matcher "Bash": append to the end of the hooks array:
      {"type":"command","command":"$HOME/.claude/hooks/db-tunnel-guard.sh","timeout":3,"statusMessage":"Checking DB access method..."}
   b. Remove the entire "statusLine" block (key + value) if it exists
   c. Do NOT change any other configuration

6. Copy updated rules/:
   Read ~/.claude/.team-config.json to get substitution values.
   For each .md in rules/: read the file from the repo, replace __VAULT_ROOT__, __CODEBASE_ROOT__, __USER_NAME__, __TEAM_VERTICALS__, __SLACK_DM_ID__ with values from .team-config.json, and write to ~/.claude/rules/

7. Copy updated skills/:
   Same process: for each SKILL.md in skills/*/: read, replace template variables, write to ~/.claude/skills/*/SKILL.md

8. Verify:
   - ~/.claude/hooks/db-tunnel-guard.sh exists and is executable
   - ~/.claude/hooks/session-end-save.sh exists and is executable
   - ~/.claude/scripts/plantuml_encode.py exists and is executable
   - ~/.claude/statusline-command.sh does NOT exist
   - settings.json is valid JSON and does NOT have a "statusLine" block
   - No __PLACEHOLDER__ remaining in rules/ or skills/

Report the result of each step.
```
