---
name: study
description: "Deep forensic research before implementation. Sweeps vault, pitfalls, codebase patterns, GitHub PRs, Confluence, Slack, and Jira. Produces an Implementation-Plan.md with full context, risks, and step-by-step guide. Use when the user says \"study\", \"research this\", \"analyze before coding\", \"investigate this feature\", \"prepare implementation\", or at the start of any feature/bug workflow. This skill MUST run before feature-dev."
---



# Study: Deep Research Before Implementation

## Runtime adaptation

Converted from `__CODEX_ROOT__/skills/study/SKILL.md`.
Claude-only frontmatter fields such as `model`, `allowed-tools`, `argument-hint`, and `compatibility` were removed because Codex discovers skills through `name` and `description`.
Original Claude model hint: `sonnet`. In Codex, do not override the model unless Ivan explicitly asks.
Use Codex tools and MCPs available in the current session. If a named Claude MCP is unavailable, state the gap and use the closest safe local source.
Do not mutate Slack, Jira, Confluence, GitHub, Datadog, CI/CD, infrastructure, or production systems without explicit approval.
Use Codex subagents only when current system or user instructions explicitly allow delegation.

## Parallel Agent Policy

Invoking `study` is an explicit request to use parallel read-only subagents when the task spans multiple services, repositories, or external context sources. Run Phase 1 locally first so every subagent receives the same scope, ticket, domain, and suspected services.

Default fan-out slices:

- `researcher`: vault RAG, pitfalls, business rules, and session memory.
- `researcher`: codebase patterns across target services.
- `researcher`: GitHub PR history and git history prior art.
- `researcher`: Jira, Confluence, and Slack context.

The parent agent synthesizes the Implementation-Plan.md and validates contradictions between sources.

## Visible Deep Dive Lanes

For broad research, spec review, implementation planning, or any request that says "pesquise", "investigue", "deep dive", "spec completa", or spans multiple sources, make the parallel work visible like Claude-style agent runs.

Before launching work, announce the lanes in one compact block:

```text
Deep dive lanes:
- Deep dive: vault + business rules
- Deep dive: codebase + local setup
- Deep dive: GitHub prior art
- Deep dive: Jira/Confluence/Slack
- Deep dive: Datadog/read-only runtime (when relevant)
```

Use read-only subagents for independent lanes when available. If generic subagents are not available in the current Codex runtime, run the same lanes with parallel tool calls or bounded local reads and say `subagents unavailable, running local lanes`.

When each lane finishes, report one short status line:

```text
Deep dive "GitHub prior art" completed · 4 PRs checked · 1 relevant pattern
Deep dive "Confluence" blocked · Atlassian unavailable · vault fallback used
```

The parent agent must synthesize and reconcile all lanes. Lanes collect evidence only; they do not decide the final plan.


Forensic investigation of everything relevant to a task BEFORE any code is written. This skill produces the Implementation-Plan.md that /feature-dev executes. The quality of this research directly determines the quality of the implementation.

## Working Directories and Artifact Routing

1. **Vault root**: `__VAULT_ROOT__`
2. **Company-neutral root**: `Personal Projects/`
3. **Luxury Escapes root**: `Luxury-Escapes/`
4. **Codebase**: derive from the repository named by the user or the current working directory. Do not default to Luxury Escapes.

Route the plan before writing:

- No explicit company or corporate ticket: save inside the matching project under `Personal Projects/`; for investigation-led work, use the matching `Personal Projects/Investigations/{ID}/` folder.
- Explicit Luxury Escapes context or `EXP-*`/`BUG007-*` ticket: use the canonical feature or bug folder under `Luxury-Escapes/Development/`.
- Another explicit company: use that company's vault root and existing project convention.
- A user-provided destination always wins.

## Common Agent Mistakes

1. **Shallow vault search**: Running one query and moving on. The vault has 25K+ chunks. Run at least 3-5 queries with different angles (ticket keywords, domain terms, service name, error patterns, provider names).
2. **Skipping pitfalls**: The pitfall-sweep has cataloged 250+ gotchas from real PRs. Not checking them means repeating known mistakes.
3. **Assuming from memory**: "I think svc-experiences uses TypeORM" is not evidence. Read the actual package.json and a controller file. Every claim must be traceable.
4. **Missing cross-service impact**: A feature in svc-experiences often touches svc-order, svc-search, www-le-customer. Map ALL services in the data flow, not just the primary one.
5. **Ignoring prior art**: Before designing a new approach, search GitHub for merged PRs that solved similar problems. The codebase has patterns for everything.
6. **Planning without risks**: An implementation plan without a risks section is a wish list. Every external API call, migration, feature flag, and cross-service dependency is a risk.
7. **Treating inherited evidence as current evidence**: Session memory, existing investigation notes, or old plans are leads, not proof. Refresh Jira, Confluence, GitHub, Slack, and Datadog when they are relevant, or record the exact tool/blocker.
8. **Writing "refresh before PR" inside the plan**: If the skill can safely refresh read-only evidence now, do it before writing the plan. Only defer when the tool is unavailable, blocked, or access fails.

---

## Hard Evidence Gates

Before writing the final `Implementation-Plan.md`, complete these gates or record an explicit blocker with the attempted tool/query and fallback used. Do not silently satisfy a gate from session memory alone.

Remote GitHub evidence uses networked `gh` calls. In Codex, run `rtk gh pr view`, `rtk gh pr list`, `rtk gh api`, and `rtk gh search` with `sandbox_permissions="require_escalated"` on the first attempt and a narrow `prefix_rule`. Do not first run remote `gh` inside the sandbox just to observe `error connecting to api.github.com`.

| Gate | Required when | Minimum evidence |
|---|---|---|
| Jira current state | A ticket id is present | `jira_get_issue` result or explicit Atlassian blocker; include summary, status, priority, assignee, acceptance criteria or description facts. |
| Vault RAG | Any Luxury Escapes task | Minimum 5 `query_vault` angles, including direct ticket/domain, business rule, pitfall/review-learning, service-specific, and provider/error keywords where applicable. |
| Confluence direct check | Any implementation plan | `confluence_search` plus relevant page reads, or explicit Atlassian blocker plus vault-synced Confluence fallback. Do not leave this as "refresh later" if the tool is available. |
| GitHub prior art | Any code change plan | At least 3 search angles and 3 relevant PRs read with `gh pr view` or GitHub plugin. If results are inherited from another note, refresh them or mark as stale. |
| Slack context | Bug, incident, cross-team behavior, unclear ownership, or production symptom | Search relevant channels/threads. If nothing found, record negative evidence and query. |
| Datadog read-only | Bug, incident, production behavior, endpoint failure, provider failure, observability claim, or acceptance needing runtime proof | Query proxy/API and app-service logs when applicable, or record timeout/access blocker. Existing investigation evidence can seed the query but does not replace the refresh. |
| Local validation setup | Any implementation plan | Runtime version source, dependency command, DB/cache/queue needs, env file names, focused tests, broad checks, data setup, cleanup/reset. |
| Worktree gate | Ticket id present | Check existing worktrees under `__CODEBASE_ROOT__`; record selected worktree or blocker before implementation. |

If a gate fails due to permissions, network, MCP availability, or timeout, the plan must include a `Blocked / Not Refreshed Evidence` subsection with:

- source name
- exact query or command attempted
- failure mode
- fallback used
- risk created by using fallback

The final response must summarize gate counts, for example: `Jira: 1 refreshed`, `Confluence: 3 pages`, `Slack: 1 thread`, `GitHub: 4 PRs`, `Datadog: timeout, fallback to prior investigation`.

## Phase 1: Task Identification

### If ticket provided (EXP-XXXX, BUG007-XXXX)

1. Fetch from Jira: `mcp-atlassian jira_get_issue` with issue_key
2. Extract: title, description, acceptance criteria, linked tickets, components, labels
3. Check for subtasks: `mcp-atlassian jira_search` with `parent = TICKET`
4. Check for related tickets: linked issues, mentions in description
5. If Atlassian MCP is unavailable, try the configured Atlassian wrapper or approved read-only fallback. If that also fails, record the blocker in the plan. Do not rely only on old session memory for Jira facts.

### If description provided (no ticket)

1. Parse the intent: what needs to change, why, where
2. Identify affected services from keywords
3. Identify the domain (attractions, bookings, providers, search, checkout, admin, etc.)

### If topic/question provided

1. Frame as a research question
2. Identify the scope: single service, cross-service, infrastructure
3. Determine what the deliverable should look like

**Output**: Clear problem statement with scope, services, and domain.

---

## Phase 2: Vault Deep Dive (MANDATORY, never skip)

This is the most important phase. The vault contains 25K+ indexed chunks from Review-Learnings, Business-Rules, Pitfalls, Runbooks, Meeting-Notes, and Knowledge-Base.

### 2.1 Semantic search (minimum 5 queries)

Call `local-le-vault query_vault` with different angles:

| Query | Purpose |
|---|---|
| Ticket keywords + service name | Direct matches |
| Domain terms (e.g., "attractions ranking") | Business context |
| Technical terms (e.g., "materialized view refresh") | Architecture patterns |
| Error/pitfall terms (e.g., "NULL PARTITION BY") | Known gotchas |
| Provider name (e.g., "CustomLinc booking") | Integration specifics |
| Session memory or prior plan keywords | Continuity, but only as a lead to refresh external evidence |

Use `service_filter` when the service is known. Use `list_vault_sources` to discover available filters.

### 2.2 Pitfalls scan

Read the pitfalls cataloged for the target service(s):

```bash
# Search PostgreSQL pitfalls via radar API
TOKEN=$(cat ~/.config/radar-dashboard/token)
curl -s "http://localhost:8900/api/search?q=DOMAIN_TERM&scope=knowledge&limit=20" \
  -H "X-Radar-Token: $TOKEN" | python3 -m json.tool
```

Also grep vault Troubleshooting files:
```bash
find "$VAULT/Knowledge-Base/Troubleshooting" -name "*.md" | xargs grep -li "KEYWORD" 2>/dev/null
```

### 2.3 Business Rules check

Read relevant business rules from `Knowledge-Base/Business-Rules/`:

| Domain | File |
|---|---|
| Booking, checkout | `Checkout.md`, `Providers.md` |
| Refunds | `Refunds.md`, `Orders.md` |
| Promotions | `Promos.md` |
| Search, ranking | `Search.md` |
| White label | `WhiteLabel.md` |
| Operations | `Operations.md` |

For each rule found: does it constrain the implementation? Does it invalidate an assumption?

### 2.4 Review Learnings

Check if prior work on this ticket or related features left documented learnings:

```bash
find "$VAULT/Knowledge-Base/Review-Learnings" -name "*TICKET*" -o -name "*DOMAIN*" 2>/dev/null
find "$ROUTED_COMPANY_ROOT/Development/Features" -path "*TICKET*" -name "*.md" 2>/dev/null
```

### 2.5 Meeting Notes context

Search recent meeting notes for discussions about this feature:

```bash
rg -l -i "KEYWORD\|TICKET" "$VAULT/Knowledge-Base/Meeting-Notes/" 2>/dev/null | head -5
```

**Output**: Structured summary of everything found, organized by source. Flag contradictions between sources.

---

## Phase 3: Codebase Forensics

Analyze the actual code. No assumptions.

### 3.1 Service architecture

For each affected service:

```bash
# Project structure
ls __CODEBASE_ROOT__/SERVICE/src/

# Package.json for deps and scripts
cat __CODEBASE_ROOT__/SERVICE/package.json | head -30

# ORM, validation, framework
grep -r "typeorm\|sequelize\|prisma\|strummer\|zod\|joi" __CODEBASE_ROOT__/SERVICE/package.json
```

### 3.2 Existing patterns in the target area

```bash
# Find files in the domain area
find __CODEBASE_ROOT__/SERVICE/src -path "*DOMAIN*" -name "*.ts" | head -20

# Read a controller/route in the same domain to learn the pattern
# Read a test file in the same domain to learn test conventions
# Read types/models to understand the data shape
```

### 3.3 GitHub History Forensics (prior art + business patterns)

This is where you understand HOW the team has evolved this area over time. PR bodies contain business rationale, trade-off discussions, and reviewer feedback that never makes it to the code.

#### Step A: Find related merged PRs (minimum 3 search angles)

```bash
# By domain keyword
gh pr list --repo lux-group/SERVICE --search "KEYWORD" --state merged --limit 10

# By file path (who changed the files you'll touch)
gh pr list --repo lux-group/SERVICE --search "PATH/TO/DOMAIN" --state merged --limit 10

# By ticket reference
gh pr list --repo lux-group/SERVICE --search "EXP-XXXX" --state merged --limit 5

# By author (team members who own this area)
gh pr list --repo lux-group/SERVICE --search "DOMAIN" --state merged --author HANDLE --limit 5
```

Do not copy PRs from an existing investigation without refresh. If GitHub plugin search fails, use `gh pr list` and `gh pr view` as the fallback. Record failed plugin queries when they affect coverage.

#### Step B: Analyze PR bodies (read at least 3-5 merged PRs)

For each relevant PR, extract:

```bash
# Get PR body + review comments
gh pr view PR_NUMBER --repo lux-group/SERVICE --json title,body,reviews,comments,mergedAt,additions,deletions
```

Look for:
- **Business context**: why was this built? What problem did it solve?
- **Trade-offs documented**: "we chose X over Y because..."
- **Reviewer feedback**: what did reviewers flag? What patterns did they enforce?
- **Rollout strategy**: feature flags, staged deploy, migration approach
- **Known limitations**: "this doesn't handle Z yet" or "follow-up needed for..."

#### Step C: Commit history analysis (understand evolution)

```bash
# Recent commits in the domain area (last 3 months)
cd __CODEBASE_ROOT__/SERVICE
git log --oneline --since="3 months ago" -- src/PATH/TO/DOMAIN/ | head -30

# Commits with full messages (look for business context in commit bodies)
git log --format="%h %s%n%b%n---" --since="3 months ago" -- src/PATH/TO/DOMAIN/ | head -100

# Who contributes to this area (ownership signal)
git shortlog -sn --since="6 months ago" -- src/PATH/TO/DOMAIN/

# Files changed together (coupling analysis)
git log --oneline --since="3 months ago" -- src/PATH/TO/DOMAIN/ | head -20 | awk '{print $1}' | while read sha; do
  git diff-tree --no-commit-id --name-only -r "$sha" 2>/dev/null
done | sort | uniq -c | sort -rn | head -20
```

The coupling analysis reveals which files always change together. If you're touching file A, you probably need to touch files B and C too.

#### Step D: Synthesize patterns

From the PR + commit analysis, document:

1. **Business evolution**: how has this domain changed? What direction is it going?
2. **Recurring patterns**: what approach does the team consistently use? (e.g., feature flag first, migration separate, tests required)
3. **Reviewer expectations**: what do reviewers in this area always check? (e.g., "must have rollback plan", "needs staging evidence")
4. **Ownership**: who owns this area? Who should review the PR?
5. **Coupling map**: which files/modules always change together?

**Output**: A "Prior Art Summary" section in the Implementation-Plan.md that includes:
- Top 3-5 most relevant merged PRs with links and key takeaways
- Business pattern evolution timeline
- Reviewer expectations for this area
- File coupling map

### 3.4 Cross-service data flow

If the feature spans services:

1. Identify the contract: how does service A call service B?
2. Check API schemas/types at the boundary
3. Check if there are shared types or contracts
4. Map the full request flow: client -> BFF -> service A -> service B -> DB

### 3.5 Infrastructure check

```bash
# Feature flags (Pulumi config)
grep -r "FEATURE_NAME\|DOMAIN" __CODEBASE_ROOT__/SERVICE/pulumi/ 2>/dev/null

# Environment variables
grep -r "FEATURE\|DOMAIN" __CODEBASE_ROOT__/SERVICE/src/**/config* 2>/dev/null

# Database migrations (recent, related)
ls __CODEBASE_ROOT__/SERVICE/src/migrations/ 2>/dev/null | tail -10
```

**Output**: Pattern summary with concrete file paths and code snippets.

---

## Phase 4: External Sources (parallel where possible)

These are read-only evidence gates. For a full `study`, do not skip them because the existing investigation already mentions them. Existing notes identify good queries, but the study pass must either refresh the source or document why refresh failed.

### 4.1 Confluence

Search company documentation:

```
mcp-atlassian confluence_search with query "KEYWORD", limit 5
```

Priority spaces: PE (Product Engineering), TEC (Technical), ENGX (Engineering Excellence), PROD/Product Quality, and the domain/team spaces surfaced by Jira or vault.

Read full pages for relevant results (not just titles). If Confluence search is unavailable, record the blocker and search vault-synced Confluence content as a fallback. Do not produce a final Implementation-Plan.md without either Confluence evidence or explicit negative evidence.

If Atlassian MCP is not exposed directly but a local wrapper exists, use the wrapper for read-only Confluence search/page reads before falling back to vault-synced Confluence.

Confluence must answer:

- What is the documented business/process expectation?
- What are the provider, operational, or product-quality notes?
- Are there runbooks, troubleshooting pages, or launch docs that constrain the implementation?
- Does Confluence contradict Jira, Slack, GitHub, or code evidence?

### 4.2 Slack

Search team discussions with the Slack plugin `slack@openai-curated` (`mcp__codex_apps__slack`). Do not use the legacy local `mcp__slack__` server.

```
Slack plugin search tool, preferably `_slack_search_public` or `_slack_search_public_and_private`, with query "KEYWORD"
```

Channels to prioritize: team channels (experiences, engineering), ticket-specific threads.

Read full threads when found. Discussions often contain context that never made it to documentation.

### 4.3 Datadog read-only evidence

For bugs, incidents, customer-impacting behavior, endpoint failures, provider failures, or any plan that references production logs, run Datadog read-only queries before writing the plan.

Minimum for web/API bugs:

- proxy/API gateway logs for the exact endpoint, request shape, timestamp/window, status code, trace id when possible
- app-service logs for the suspected service, provider/error codes, request terms, and same window
- if Datadog times out or access fails, record the exact query, time window, failure, and fallback evidence

Do not state "Datadog confirmed" unless this study pass queried Datadog or the sentence clearly says it is inherited from `investigation-case`/prior evidence and may need refresh.

### 4.4 GitHub Issues/Discussions

```bash
gh search issues "KEYWORD" --repo lux-group/SERVICE --limit 5
```

**Output**: External context summary. Flag any decisions or constraints found.

---

## Phase 4.5: Local Validation & Data Setup Plan

Before writing the implementation steps, define how the change will be tested with real-enough data.

### Environment selection

Choose the lowest-risk environment that can prove the behavior:

| Environment | Use when | Requirements |
|---|---|---|
| Local only | Logic is isolated, tests can mock provider/data, no production data dependency | Dependencies installed, local env file, unit/integration scripts identified |
| Local with local DB/cache | Behavior depends on Prisma/Sequelize/Postgres/Redis/BullMQ state | DB seed or fixture path, migrations status, queue worker needs, reset/cleanup steps |
| Staging | Need deployed service interaction, external provider sandbox, feature flags, or real frontend/backend integration | Staging URL, env flags, test account/order/search inputs, safe data scope |
| Production read-only | Bug only reproduces with prod data/provider behavior/logs and no mutation is needed | Explicit read-only commands/tools, RO DB tunnel if needed, Datadog/Jira/GitHub evidence, no writes |

### Local setup details

For each service in scope, document:

- Node/runtime version and exact evidence source, for example `.nvmrc`, `package.json engines`, Dockerfile, or CI config.
- Dependency command.
- Required env vars/config files and safe placeholders.
- Database/cache/queue dependencies, for example Postgres, Redis, BullMQ, Prisma migrations, Sequelize migrations.
- Whether tests use mocks, local fixtures, local DB, staging, or production read-only evidence.
- Exact focused test commands and broader validation commands.
- Data setup: seed records, fixture files, provider stubs, DB query, or Jira/Datadog reproduction inputs.
- Cleanup/reset steps for local DB/cache/queues.

### Production read-only rules

Use production only for read-only validation. Prefer Datadog, Jira, GitHub, vault, and RO database tunnels. For LE database access, use the tunnel helper in RO mode when required:

```bash
~/bin/le-tunnel.sh -s <svc> -d <db> -m ro
```

Never include production writes, data patches, migrations, or provider mutations in the implementation plan unless Ivan explicitly approves that separate operational action.

---

## Phase 5: Risk Analysis

For every finding, evaluate risk:

### Technical risks

| Risk | Impact | Mitigation |
|---|---|---|
| Migration locks large table | HIGH | Use CONCURRENTLY, add during low traffic |
| Cross-service contract change | HIGH | Feature flag, staged rollout |
| New external API dependency | MEDIUM | Timeout, retry, circuit breaker |
| Cache invalidation needed | MEDIUM | Identify all cache layers |

### Business risks

- Does this change affect pricing, refunds, or bookings?
- Does this touch a provider integration (Rezdy, Klook, CustomLinc)?
- Does this require coordination with another team?
- Is there a compliance or legal constraint?

### Knowledge gaps

- What do we NOT know that we need to know before coding?
- Who should we ask? (team member, product, provider)
- What needs manual verification (staging, prod data)?

---

## Phase 6: Produce Implementation-Plan.md

Create the plan in the routed project, feature, or investigation folder. For Luxury Escapes tickets, the canonical form is:

```
Development/Features/TICKET-slug-STATUS/Implementation-Plan.md
```

If no ticket or company exists, use a descriptive project folder under `Personal Projects/`.

### Template

```markdown
---
ticket: EXP-XXXX
title: Feature Title
status: draft
services: [svc-experiences, www-le-customer]
created: YYYY-MM-DD
---

# Implementation Plan: Feature Title

## Context

[Problem statement. Why this matters. Business value.]

## Research Summary

### Evidence Gate Status

| Gate | Status | Evidence |
|---|---|---|
| Jira current state | done/blocked/not applicable | [ticket result, query, or blocker] |
| Vault RAG | done/blocked | [N queries, best findings, negative findings] |
| Confluence direct check | done/blocked | [pages read or blocker + fallback] |
| GitHub prior art | done/blocked | [search angles, PRs read, or blocker] |
| Slack context | done/blocked/not applicable | [threads/results or negative evidence] |
| Datadog read-only | done/blocked/not applicable | [queries, time window, results, timeout, or blocker] |
| Local validation setup | done/blocked | [runtime source, DB/cache/queue, scripts] |
| Worktree gate | done/blocked/not applicable | [selected worktree or missing worktree] |

### Vault Findings
[Key insights from vault RAG, pitfalls, business rules. Reference specific docs.]

### Confluence Findings
[Relevant Confluence pages read, decisions found, constraints, and contradictions. If unavailable, record exact blocker and vault-synced fallback used.]

### Codebase Patterns
[Existing patterns to follow. File paths. Architecture conventions.]

### Prior Art (GitHub History)

**Key merged PRs:**
| PR | Title | Takeaway |
|---|---|---|
| #NNN | [title] | [business rationale, trade-off, reviewer feedback] |

**Business evolution**: [how this domain has changed over last 3 months]
**Reviewer expectations**: [what reviewers consistently enforce in this area]
**Ownership**: [who owns this area, who should review]
**File coupling**: [files that always change together]

### External Context
[Confluence docs, Slack threads, Jira context. Links.]

### Blocked / Not Refreshed Evidence

| Source | Attempted query/tool | Failure mode | Fallback used | Risk |
|---|---|---|---|---|
| [source] | [query/tool] | [timeout/access/unavailable/no results] | [memory/vault/code/etc.] | [what could be stale or missing] |

## Local Validation & Data Setup

### Environment Strategy

| Layer | Environment | Why | Data Source | Safety |
|---|---|---|---|---|
| Unit tests | local | [why enough/not enough] | mocks/fixtures | safe |
| Integration tests | local DB/staging/prod read-only | [why needed] | [seed/staging/prod RO] | [constraints] |
| Runtime validation | local/staging/prod read-only | [what it proves] | [URL/log/query] | [read-only or test account] |

### Service Setup

| Service | Runtime | Dependencies | Setup command | Test command |
|---|---|---|---|---|
| svc-name | Node/version | DB/cache/queue/provider | command | command |

### Data Requirements

- Local data: [seed/fixtures/migrations needed]
- Staging data: [test account/order/search/provider sandbox needed]
- Production read-only: [Datadog/Jira/RO DB query/log window needed]
- Cleanup/reset: [local DB/cache/queue cleanup]

## Technical Approach

### Data Flow
[How data moves through the system. Which services, which endpoints, which tables.]

### Changes Required

| Service | File/Area | Change | Complexity |
|---|---|---|---|
| svc-experiences | src/controllers/DOMAIN/ | New endpoint | Medium |
| svc-experiences | src/migrations/ | New migration | Low |
| www-le-customer | src/pages/DOMAIN/ | New component | Medium |

### Step-by-Step Implementation

1. **[Service] Migration/Schema** (if needed)
   - What: create table/column/index
   - File: src/migrations/TIMESTAMP-name.ts
   - Pattern: follow [existing migration path]
   - Rollback: [DOWN method description]

2. **[Service] Backend logic**
   - What: new endpoint/function
   - File: src/controllers/DOMAIN/controller.ts
   - Pattern: follow [existing controller in same domain]
   - Validation: [schema rules]
   - Tests: [what to test, which patterns to follow]

3. **[Service] Frontend** (if applicable)
   - What: new page/component
   - File: src/pages/DOMAIN/
   - Pattern: follow [existing component in same area]
   - Tests: [component tests, hook tests]

### Feature Flag Strategy (if applicable)

- Flag name: `FEATURE_NAME`
- Default: off
- Pulumi config: [where to register]
- Rollout: [staging first, then prod AU, then global]

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| [specific risk] | HIGH/MEDIUM/LOW | [specific mitigation] |

## Open Questions

- [Question that needs human input before implementation]
- [Decision that affects the approach]

## Dependencies

- [ ] [External dependency, e.g., provider API access]
- [ ] [Team dependency, e.g., svc-order contract change]
- [ ] [Infrastructure dependency, e.g., Pulumi config update]

## Acceptance Criteria Mapping

| AC from Jira | Implementation | Test |
|---|---|---|
| [criteria 1] | [which step covers it] | [how to verify] |
| [criteria 2] | [which step covers it] | [how to verify] |
```

---

## Phase 7: Present and Validate

Present the plan to the user with a summary:

```
Study complete for EXP-XXXX.

Research:
  Jira: refreshed/blocked/not applicable
  Vault: N queries, N relevant findings (pitfalls: X, business rules: Y, review learnings: Z)
  Confluence: N pages read or blocked with fallback
  GitHub: N search angles, N PRs read
  Slack: N threads/results or negative evidence
  Datadog: N queries or blocked/timeout with fallback
  Codebase: N files analyzed, pattern identified: [pattern name]

Plan saved: {ROUTED_PLAN_PATH}/Implementation-Plan.md

Risks: N identified (X high, Y medium)
Open questions: N (need input before coding)
Blocked evidence: N sources

Ready for /feature-dev after questions resolved.
```

If there are open questions or blocked hard gates that affect implementation correctness, STOP and wait for answers. Do NOT proceed to /feature-dev with unresolved questions.

---

## Rules

- Every claim must be backed by evidence (file path, vault result, PR link, Slack thread)
- Never assume a pattern exists, verify it in the codebase
- Never skip vault search. 5 queries minimum, different angles
- Cross-reference contradictory information between sources
- Flag knowledge gaps explicitly, don't paper over them
- The plan must be self-contained. Someone reading it cold should understand what to do
- If research reveals the task is more complex than expected, say so. Don't simplify to fit
- If research reveals the task is unnecessary (already done, wrong approach), say so
- Parallel agents for independent research (Confluence + Slack + GitHub) when possible
- Total research time: invest 10-20 minutes here to save hours during implementation

## Ubuntu portability

Use the active project AGENTS.md for client facts, knowledge sources and infrastructure.
Paths below are resolved by the installer. Optional MCPs, Radar, Figma and the approved
Playwright runner require separate local provisioning. Do not fall back to a generic
Playwright MCP. Existing user authorization overrides repeated permission prompts;
continue authorized work. Prefer the host runtime tools and supported skill invocation.
