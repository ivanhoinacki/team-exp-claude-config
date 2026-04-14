# team-exp-claude-config

AI Dev ecosystem for engineering teams. One-command setup that installs rules, skills, agents, hooks, MCP servers, and service dossiers. Works with Claude Code and Cursor.

## Install

```bash
# macOS
curl -sSL https://raw.githubusercontent.com/ivanhoinacki/team-exp-claude-config/main/scripts/install.sh | bash

# Linux / WSL2
curl -sSL https://raw.githubusercontent.com/ivanhoinacki/team-exp-claude-config/main/scripts/install.sh | bash
```

> The installer detects your platform and runs the correct setup script.

## What you get

| Component | Count | Purpose |
|---|---|---|
| **Rules** | 8 | Behavioral guardrails (auto-loaded every conversation) |
| **Skills** | 16 | Automated workflows: `/commit`, `/create-pr`, `/feature-dev`, `/investigation-case`, etc. |
| **Agents** | 4 | Specialized sub-agents: Copilot, Researcher, Implementer, Reviewer |
| **Hooks** | 5 core + 17 optional | Lifecycle automation: pre-commit checks, skill enforcement, tool preferences |
| **Service Dossiers** | 9 | CLAUDE.md per repo (stack, commands, patterns, gotchas) |
| **MCP Servers** | 8 | Atlassian, Datadog, ChromaDB/vault-rag, Context7, Probe, Playwright, Chrome DevTools, Imugi |
| **Status Line** | 1 | `user :: dir :: branch :: rate% :: ctx%` |

## Quick start (manual clone)

```bash
cd ~/Documents/LuxuryEscapes
git clone git@github.com:ivanhoinacki/team-exp-claude-config.git
cd team-exp-claude-config

bash scripts/setup.sh        # macOS
bash scripts/setup-wsl.sh    # Linux / WSL2
```

## Post-setup

```bash
claude                     # open Claude Code
/mcp                       # connect Datadog (needs VPN) + Slack (OAuth)
```

### Verify

```bash
claude mcp list            # 8 MCPs
ls ~/.claude/rules/        # 8 files
ls ~/.claude/skills/       # 16+ directories
ls ~/.claude/agents/       # 4 files
```

## Structure

```
team-exp-claude-config/
  rules/                   # 8 behavioral rules (auto-loaded)
    00-global-style.md
    01-code-quality-review.md
    02-skills-first.md
    03-escalation-protocol.md
    04-study-before-starting.md
    05-diagrams-standard.md
    06-worktree-detection.md
    08-behavioral-standards.md
  skills/                  # 16 slash command workflows
    commit/                #   /commit - format enforced
    create-pr/             #   /create-pr - template + diagrams
    feature-dev/           #   /feature-dev - 6 phases
    codereview/            #   /codereview - 18 dimensions
    investigation-case/    #   /investigation-case - 7 parallel agents
    debug-mode/            #   /debug-mode - hypothesis-driven
    deslop/                #   /deslop - clean AI-generated code
    daily/                 #   /daily - standup notes
    learn/                 #   /learn - capture knowledge
    thinking-partner/      #   /thinking-partner - critical analysis
    validate-infra/        #   /validate-infra - env var audit
    validate-migration/    #   /validate-migration - rollback check
    deploy-checklist/      #   /deploy-checklist - risk-based
    test-scenarios/        #   /test-scenarios - real validation
    diagrams/              #   /diagrams - PlantUML standard
    capture-knowledge/     #   /capture-knowledge - Slack to vault
  agents/                  # 4 specialized sub-agents
    copilot.md             #   Opus, daily partner
    researcher.md          #   Sonnet, read-only discovery
    implementer.md         #   Opus, code implementation
    reviewer.md            #   Opus, read-only review
  hooks/
    core/                  # 5 essential hooks (installed by default)
      pre-git-commit.sh
      skill-enforcement-guard.sh
      tool-preference-guard.sh
      skill-tracker.sh
      session-start-check.sh
      statusline-command.sh
    optional/              # 17 advanced hooks (opt-in)
      vault-rag-reminder.sh
      vault-rag-tracker.sh
      worktree-setup.sh
      worktree-remove.sh
      frontend-layout-guard.sh
      user-prompt-context.sh
      agent-lifecycle-log.sh
      ...
  claude-md/               # 9 service dossiers (CLAUDE.md templates)
    svc-experiences.md
    svc-order.md
    www-le-admin.md
    ...
  scripts/                 # Setup and maintenance
    install.sh             #   One-line curl installer (auto-detects platform)
    setup.sh               #   macOS installer
    setup-wsl.sh           #   Linux/WSL2 installer
    update.sh              #   Update existing installation
    verify-setup.sh        #   Verify installation
    test-setup.sh          #   Test suite
    ci-local-check.sh      #   Run CI checks locally
```

## Cursor IDE integration

The setup syncs rules and MCP servers to Cursor automatically (Phase 10, opt-in):

| Feature | Claude Code | Cursor | Shared? |
|---|---|---|---|
| Rules (8) | `~/.claude/rules/*.md` | `~/.cursor/rules/*.mdc` | Yes, auto-synced |
| MCP Servers (8) | `~/.claude/claude.json` | `~/.cursor/mcp.json` | Yes, auto-synced |
| Skills (16) | `~/.claude/skills/` | Not supported | Claude Code only |
| Hooks | `settings.json` | Not supported | Claude Code only |
| Agents (4) | `~/.claude/agents/` | Not supported | Claude Code only |
| CLAUDE.md | Repo root | Repo root | Yes, same file |

## Customization

Fork this repo and adapt for your team:

1. Edit rules for your domain and coding standards
2. Create skills for your recurring workflows
3. Write CLAUDE.md dossiers for your repos
4. Add pitfalls as you discover bugs and gotchas

## Pre-requisites

- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- Node.js 20+ (via nvm)
- Git + GitHub CLI (`gh auth login`)
- Atlassian API token
- Python 3 (for vault-rag)
