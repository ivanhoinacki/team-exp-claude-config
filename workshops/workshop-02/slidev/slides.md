---
theme: default
title: Claude Code Ecosystem - Workshop 02
info: |
  Workshop 02 - Claude Code Ecosystem
  Ivan Hoinacki | Engineering
author: Ivan Hoinacki
keywords: claude-code,workshop,ai
class: cover
highlighter: shiki
lineNumbers: false
drawings:
  persist: false
transition: slide-left
mdc: true
colorSchema: dark
fonts:
  sans: "Sora"
  mono: "JetBrains Mono"
download: true
exportFilename: workshop-02
hideInToc: false
---

<div class="cover-title">Productivity</div>
<div class="cover-title">with Claude Code</div>
<div class="cover-title">Workshop</div>

<div class="lead-subtitle">AI Dev Ecosystem | Principles, setup, and personalized workflows</div>

<div class="lead-divider"></div>

<div class="lead-tagline">Hands-on workshop for engineering teams</div>

<div class="lead-meta">Speaker: Ivan Hoinacki</div>

<div class="lead-footer">Engineering Team | April 17, 2026</div>

---

# Agenda

<div class="stagger-list">

- **Block 0**: Recap + Delta (10 min)
- **Block 1**: Setup (25 min)
- **Block 2**: Hooks (15 min)
- **Block 3**: MCP Servers (15 min)
- **Block 3.5**: Cursor Integration (10 min)
- **Break** (10 min)
- **Block 4**: CLAUDE.md (15 min)
- **Block 5**: Agents + New Skills (20 min)
- **Block 6**: Full Workflow (25 min)
- **Block 7**: Learning Cycle (10 min)
- **Block 8**: Q&A + Next Steps (10 min)

</div>

<div class="highlight stagger-last" style="margin-top: 0.8em;">

**Total: ~2h45**

</div>

---
layout: cover
class: cover
transition: slide-up
---

# Block 0

## Recap + What Changed

---

# W1 Recap (February)

<v-clicks>

4 layers introduced:

- **Workspace**: project structure, .claudeignore
- **Rules**: behavioral guardrails (auto-loaded)
- **Skills**: slash command workflows
- **Memory**: persistent knowledge (vault + ChromaDB)

Each dev left with an Obsidian vault and skills available.

</v-clicks>

<div v-click class="highlight">

**The problem**: everything was manual. Copy files, edit JSON, hope for the best.

</div>

---

# What changed in 2 months

<div v-click>

| Component    | W1 (Feb) | W2 (Apr)  | What's new                                                |
| ------------ | -------- | --------- | --------------------------------------------------------- |
| Rules        | 7        | **9**     | +behavioral-standards, +agent-model-defaults              |
| Skills       | 12       | **16**    | +investigation-case, +code-review 18-dim, +test-scenarios |
| Quality dims | 12       | **18**    | +6 (cross-service, financial, idempotency...)             |
| Hooks        | 0        | **25**    | Entirely new: automatic guard rails                       |
| Agents       | 0        | **4**     | Entirely new: specialized sub-processes                   |
| MCP Servers  | 0        | **7+1**   | Jira, Confluence, Datadog, Context7, Probe...             |
| Setup        | Manual   | **1 cmd** | `team-exp-claude-config`                                  |

</div>

---

# Today's goal

<div v-click class="highlight">

You leave with **everything installed and running**.

You use it for real during the workshop, not just theory.

</div>

<div v-click style="margin-top: 2em;">

> "If you weren't at W1, the pre-read covers the essentials. The setup installs everything automatically."

</div>

---
layout: cover
class: cover
transition: slide-up
---

# Block 1

## Setup (25 min)

---

# Why 1 command

<v-clicks>

- In W1, each dev configured manually. Slow, error-prone, divergent versions
- Now: one repo (`team-exp-claude-config`) with automated installer
- `setup.sh` has 12 phases: validates prerequisites, collects personal data, installs everything

</v-clicks>

<div v-click>

```bash
curl -sSL https://raw.githubusercontent.com/ivanhoinacki/\
team-exp-claude-config/v1.1.0/scripts/install.sh | bash
```

</div>

<div v-click>

Or manually:

```bash
git clone https://github.com/ivanhoinacki/team-exp-claude-config.git \
  ~/Documents/LuxuryEscapes/team-exp-claude-config
cd team-exp-claude-config
bash scripts/setup.sh        # macOS
bash scripts/setup-wsl.sh    # Linux / WSL2
```

</div>

---

# What the wizard does

<div class="table-fade-in">

<v-clicks>

| Phase | What                                                           | Time    |
| ----- | -------------------------------------------------------------- | ------- |
| 0     | Validate prerequisites (claude, node, gh, python3)             | 5s      |
| 1     | Collect personal data (name, email, Slack ID, Atlassian token) | 2 min   |
| 2     | Install 9 rules in `~/.claude/rules/`                          | 5s      |
| 3     | Install 16 skills in `~/.claude/skills/`                       | 5s      |
| 4     | Install 4 agents in `~/.claude/agents/`                        | 5s      |
| 5     | Install 25 hooks in `~/.claude/hooks/`                         | 5s      |
| 6     | Generate settings.json (hooks, permissions, env vars)          | 5s      |
| 7     | Configure 7 MCP servers in `~/.claude/claude.json`             | 10s     |
| 8-11  | Dossiers, Cursor sync, dotfiles, verification                  | 2-5 min |

</v-clicks>

</div>

---

# Hands-on: install now

<v-clicks>

**Step 1** - Validate prerequisites:

```bash
claude --version      # Claude Code installed
node --version        # Node 20+
gh auth status        # GitHub CLI authenticated
python3 --version     # Python 3.x
```

**Step 2** - Run the installer (15 min)

**Step 3** - Verify:

```bash
claude mcp list         # 7+ MCPs
ls ~/.claude/rules/     # 9 .md files
ls ~/.claude/skills/    # 16+ directories
ls ~/.claude/agents/    # 4 .md files
```

</v-clicks>

---
layout: cover
class: cover
transition: slide-up
---

# Block 2

## Hooks: Invisible Guard Rails

---

# What are hooks

<v-clicks>

Scripts that run automatically at specific moments in the Claude Code lifecycle.

You don't call them. They intercept actions and enforce rules.

> Analogy: like a seatbelt. You don't think about it, but it protects you.

**Without hooks**, Claude Code can:

- Commit code with lint errors
- Use `cat` instead of `Read` (wasting tokens)
- Skip the PR skill and run `gh pr create` directly
- Create branches on main checkout instead of worktree
- Spawn research agents on Opus (expensive) when Haiku suffices

</v-clicks>

---

# Hook lifecycle

<ZoomImage src="/hook-lifecycle.svg" alt="Claude Code hook lifecycle" caption="complete lifecycle: 5 phases, 9 hook events" width="34%" />

<div class="lifecycle-legend">

<span class="chip">9 hook events</span>
<span class="chip">25 scripts</span>
<span class="chip">read-only Vault sync</span>

</div>

---

# Key hooks reference

<div v-click>

| Hook                        | When              | What it does                                                          |
| --------------------------- | ----------------- | --------------------------------------------------------------------- |
| **skill-enforcement-guard** | Before Bash       | Blocks direct git commit, gh pr create, git checkout -b               |
| **tool-preference-guard**   | Before Bash       | Redirects cat/grep/find to Read/Grep/Glob                             |
| **db-tunnel-guard**         | Before Bash       | Blocks `le aws postgres`, forces `le-tunnel.sh`                       |
| **agent-model-guard**       | Before Agent      | Enforces correct model: Haiku for research, Sonnet for implementation |
| **pre-git-commit**          | Before git commit | Runs lint + types, blocks if fails                                    |
| **session-end-save**        | On session end    | Auto-saves Session-Memory via Ollama                                  |
| **vault-rag-reminder**      | Before Read/Grep  | Reminds to query vault before reading codebase                        |

</div>

---

# Demo: hooks in action

<v-clicks>

**Demo 1** - skill-enforcement-guard:

```
> "run git commit -m 'test'"
BLOCKED: Use /commit skill instead
```

**Demo 2** - tool-preference-guard:

```
> "run cat src/index.ts"
REDIRECTED: Using Read tool (saves ~1.8K tokens)
```

**Demo 3** - pre-git-commit:

```
> /commit
Running: yarn lint && yarn test:types...
PASS -> commit proceeds
```

</v-clicks>

---
layout: cover
class: cover
transition: slide-up
---

# Block 3

## MCP Servers: Connecting Systems

---

# What are MCPs

<v-click>

**Model Context Protocol**: open standard connecting LLMs to external systems.

Each MCP server exposes "tools" that Claude can call.

</v-click>

<div v-click class="columns" style="margin-top: 1.5em;">

<div class="card">

**Without MCP:**
You copy/paste from Jira, Confluence, Datadog into Claude

</div>

<div class="card">

**With MCP:**
You say "investigate EXP-3570" and Claude searches everything automatically

</div>

</div>

---

# The 7+1 MCP servers

<div v-click>

| MCP Server            | What it accesses      | Use cases                                        |
| --------------------- | --------------------- | ------------------------------------------------ |
| **mcp-atlassian**     | Jira + Confluence     | Search tickets, read ADRs, find docs             |
| **datadog-mcp**       | Logs, traces, metrics | Investigate prod errors, check latency           |
| **context7**          | 1000+ library docs    | "How to use zod v3.22?", "Knex transactions API" |
| **probe**             | Semantic code search  | Find implementations, patterns, usages           |
| **playwright**        | Browser automation    | E2E tests, screenshots                           |
| **chrome-devtools**   | Chrome DevTools       | Frontend debug, network, console                 |
| **imugi**             | Image generation      | Diagrams, mockups                                |
| **local-le-chromadb** | Vault RAG             | "What do we know about refund calculation?"      |

</div>

---

# Hands-on: connect and test

<v-clicks>

**Step 1** - Connect OAuth (3 min):

```bash
claude          # open Claude Code
/mcp            # connect Datadog (OAuth) and Slack (OAuth)
```

**Step 2** - Test (7 min), pick at least 2:

1. **Atlassian**: "Search ticket [YOUR-RECENT-TICKET] in Jira"
2. **Context7**: "Search Express middleware docs in Context7"
3. **vault-rag**: "What do we know about checkout promo validation?"

</v-clicks>

---
layout: cover
class: cover
transition: slide-up
---

# Block 3.5

## Cursor Integration

---

# What syncs automatically

<div v-click>

```
~/.claude/                          ~/.cursor/
  rules/                              rules/
    00-global-style.md        -->       00-global-style.mdc
    ...all 9 rules            -->       ...converted to .mdc

  claude.json                         mcp.json
    mcpServers: { ... }       -->       mcpServers: { ... }
```

</div>

<div v-click>

| Feature           | Claude Code | Cursor     | Shared?          |
| ----------------- | ----------- | ---------- | ---------------- |
| Rules (9)         | Yes         | Yes (.mdc) | Auto-synced      |
| MCP Servers (7-8) | Yes         | Yes        | Auto-synced      |
| CLAUDE.md         | Yes         | Yes        | Same file        |
| Skills (16)       | Yes         | No         | Can be shared    |
| Hooks (25)        | Yes         | No         | Claude Code only |
| Agents (4)        | Yes         | No         | Can be shared    |

</div>

---
layout: cover
class: cover
transition: slide-up
---

# Break (10 min)

---
layout: cover
class: cover
transition: slide-up
---

# Block 4

## CLAUDE.md: Service Dossier

---

# What is CLAUDE.md

<v-click>

File at repo root that Claude Code (and Cursor) reads automatically.
Contains: what the service does, stack, commands, structure, patterns, gotchas.

</v-click>

<div v-click style="margin-top: 1em;">

**Impact on tokens:**

| Scenario                 | Without CLAUDE.md             | With CLAUDE.md                         |
| ------------------------ | ----------------------------- | -------------------------------------- |
| "How do I run tests?"    | 5-8 tool calls, ~3K tokens    | Knows: `yarn test:unit` (0 extra)      |
| "Where is refund logic?" | Grep entire repo (~8K tokens) | Knows: `src/services/refund.ts` (~500) |
| "Which error pattern?"   | Reads 2-3 files (~4K tokens)  | Knows: `{ error, code }` (0 extra)     |

</div>

<div v-click class="highlight">

Each avoided tool call = ~500-2000 tokens saved.

</div>

---

# Hands-on: generate your CLAUDE.md (5 min)

<div class="claude-md-steps">

<v-clicks>

<div class="step">

**1. Generate** - open Claude Code in your repo and run:

<div class="compact-code">

```bash
claude
> /init
```

</div>

Claude scans the repo, proposes stack, commands, structure, patterns.

</div>

<div class="step">

**2. Refine** - add the parts Claude can't infer:

- **Gotchas**: non-obvious bugs, edge cases, prod-only behavior
- **Business rules**: cross-service agreements, SLA, financial invariants
- **History**: why a weird pattern exists

</div>

<div class="step">

**3. Keep it alive** - ask Claude mid-session:

<div class="compact-code">

```
> update CLAUDE.md: price field is in cents, not dollars
```

</div>

</div>

</v-clicks>

</div>

<div v-click class="highlight" style="margin-top: 0.6em;">

Claude generates the skeleton. You add tacit knowledge. Claude keeps it updated.

</div>

---
layout: cover
class: cover
transition: slide-up
---

# Block 5

## Agents + New Skills

---

# 4 specialized agents

<div v-click>

| Agent           | Model  | Permissions   | When used                                              |
| --------------- | ------ | ------------- | ------------------------------------------------------ |
| **Copilot**     | Haiku  | Read + Write  | Default mode: questions, decisions, briefings          |
| **Researcher**  | Haiku  | **Read-only** | Before implementing: search patterns, traces. Cheapest |
| **Implementer** | Sonnet | Read + Write  | Receives spec and implements                           |
| **Reviewer**    | Haiku  | **Read-only** | Post-implementation: 18 dimensions                     |

</div>

<div v-click class="highlight">

Researcher and Reviewer use Haiku (cheapest, sufficient for reading).
Implementer uses Sonnet (mid-tier, detailed spec from vault).
Opus only via specific skills (deslop, investigation-case).

</div>

---

# Two model selection mechanisms

<v-clicks>

**1. Agent Model Guard** (subagents):

| subagent_type                                           | Model      |
| ------------------------------------------------------- | ---------- |
| Explore, researcher, reviewer, general-purpose, copilot | **Haiku**  |
| implementer, Plan                                       | **Sonnet** |

**2. Skill Frontmatter** (main session):

| Model          | Skills                                                         |
| -------------- | -------------------------------------------------------------- |
| **Haiku** (11) | commit, create-pr, daily, deploy-checklist, diagrams, learn... |
| **Sonnet** (3) | codereview, debug-mode, feature-dev                            |
| **Opus** (2)   | deslop, investigation-case                                     |

</v-clicks>

---

# /investigation-case: 7 agents in parallel

<ZoomImage src="/investigation-case.svg" alt="Investigation case: 7 parallel agents" caption="7 researchers sweep all sources · ChromaDB vault · 5 Whys synthesis" width="30%" />

<div class="lifecycle-legend">

<span class="chip">7 parallel agents</span>
<span class="chip">ChromaDB vault</span>
<span class="chip">read-only research</span>

</div>

---

# /investigation-case: the numbers

<div class="columns" style="margin-bottom: 1.5em;">

<div v-click class="card">
<div class="metric">15-30 min</div>
<div class="metric-label">with /investigation-case</div>
</div>

<div v-click class="card">
<div class="metric">2-4 hours</div>
<div class="metric-label">manual investigation</div>
</div>

</div>

<v-clicks>

- 7 researchers (Haiku, read-only) sweep all sources simultaneously
- Output saved to vault and indexed by ChromaDB
- Next time someone touches the same code, `query_vault` returns the findings

</v-clicks>

<div v-click>

<ZoomImage src="/sim-investigation-case.png" alt="Investigation case simulation" caption="real session: 7 agents in parallel, all Haiku" width="22%" />

</div>

---

# /code-review: 18 dimensions

<v-clicks>

**6 Critical** (blocks merge): Correctness, Security, Performance, Error Handling, Cross-Service Contract, Financial Integrity

**8 High** (fix before merge): SOLID, Testing, Consistency, Architecture, Idempotency, Data Visibility, Runtime Config, External Trust

**4 Medium**: Observability, Concurrency, Documentation, Dependencies

</v-clicks>

<div v-click style="margin-top: 1.5em;">

> "Doesn't depend on who reviewed. Always the same 18 dimensions."

</div>

---
layout: cover
class: cover
transition: slide-up
---

# Block 6

## Full Workflow: Hands-on (25 min)

---

# Feature dev: from Jira to PR

<ZoomImage src="/feature-dev.svg" alt="Feature dev workflow: Jira to PR" caption="4 phases · multi-agent orchestration · Haiku + Sonnet mix" width="30%" />

<div class="lifecycle-legend">

<span class="chip">4 phases</span>
<span class="chip">5 parallel researchers</span>
<span class="chip">Haiku + Sonnet</span>

</div>

---

# Your turn: full workflow

<div v-click>

Pick a micro-task from your backlog:

```
[ ] Describe the task
[ ] Watch the study (Rule 04) + approve plan
[ ] Implementation
[ ] /deslop (clean AI code)
[ ] /commit (hook runs lint + types)
[ ] /create-pr (optional)
```

</div>

<div v-click>

**What /deslop removes:**

```
BEFORE (AI generated):
  // This function validates the user input and returns a boolean
  const isValid = validateInput(input); // validate the input
  if (isValid === true) { return true; } // return true if valid
  return false; // return false if not valid

AFTER (/deslop cleaned):
  return validateInput(input);
```

</div>

---
layout: cover
class: cover
transition: slide-up
---

# Block 7

## The Learning Cycle

---

# Knowledge compounds

<ZoomImage src="/learning-cycle.svg" alt="Learning cycle: bug → investigate → fix → vault grows" caption="each bug feeds the vault, next time it gets caught earlier" width="32%" />

<div class="lifecycle-legend">

<span class="chip">4-step loop</span>
<span class="chip">ChromaDB grows</span>
<span class="chip">team flywheel</span>

</div>

---

# When something doesn't work

<div v-click>

| Symptom                             | Action                              |
| ----------------------------------- | ----------------------------------- |
| Claude repeats the same mistake     | Refine a **Rule**                   |
| Claude skips workflow steps         | Adjust a **Skill**                  |
| Claude lacks service context        | Update **CLAUDE.md**                |
| Claude doesn't know a gotcha        | Use **/learn** to capture           |
| Claude doesn't know a business rule | Add to **Business-Rules/** in vault |

</div>

<div v-click class="highlight">

The framework is generic. The content is your team's.
The more you feed it, the smarter it gets.

</div>

---
layout: cover
class: cover
transition: slide-up
---

# Block 8

## Next Steps

---

# Roadmap

<div v-click>

| When     | Focus                 | What to do                                          |
| -------- | --------------------- | --------------------------------------------------- |
| Day 1    | Explore               | Run `/powerup` (interactive lessons, 3-10 min each) |
| Week 1   | Standardize format    | Use `/commit` and `/create-pr` on everything        |
| Week 2   | Standardize workflow  | Use `/feature-dev` and `/deslop`                    |
| Week 3   | Standardize debugging | Use `/investigation-case` and `/debug-mode`         |
| Week 4+  | Accumulate knowledge  | `/learn` + pitfalls grow. Run `/insights`           |
| Month 2+ | Flywheel              | Knowledge compounds across the team                 |

</div>

---

# Quick wins (do today)

<v-clicks>

| Action                                | Time   | Impact                                    |
| ------------------------------------- | ------ | ----------------------------------------- |
| Run `/powerup`                        | 10 min | Discover features you didn't know existed |
| Create `CLAUDE.md` for your main repo | 15 min | -5K to -15K tokens/session                |
| Create `.claudeignore` in repo        | 5 min  | -500 to -2K tokens/tool call              |
| Run `/cost` at end of next session    | 1 min  | Baseline to measure improvement           |
| Try `/commit` on next commit          | 2 min  | Standardized format + lint enforced       |

</v-clicks>

---

# Token economics

<div v-click>

| Technique             | Savings                                  |
| --------------------- | ---------------------------------------- |
| **CLAUDE.md**         | ~5-15K tokens/session (avoids discovery) |
| **Agents (Haiku)**    | ~85% in discovery phases                 |
| **ChromaDB**          | ~2-5K tokens per search                  |
| **.claudeignore**     | ~500-2K per tool call                    |
| **Optimized rules**   | -50% fixed overhead                      |
| **Agent Model Guard** | ~85% on research agents                  |

</div>

<div class="columns" style="margin-top: 1.5em;">

<div v-click class="card">
<div class="metric">-49%</div>
<div class="metric-label">tokens on feature dev</div>
</div>

<div v-click class="card">
<div class="metric">-50%</div>
<div class="metric-label">tokens on bug investigation</div>
</div>

</div>

---
layout: cover
class: cover
transition: fade
---

# Questions?

<div class="lead-subtitle">

**Repo**: github.com/ivanhoinacki/team-exp-claude-config

**Support**: DM @ivan on Slack

</div>

<div class="lead-meta" style="margin-top: 2em;">

Workshop 02 | April 2026

</div>
