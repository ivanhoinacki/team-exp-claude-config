---
name: investigation-case
description: Deep forensic investigation of bugs, incidents, or reported problems. Sweeps all sources (Jira, Slack, GitHub, Confluence, Codebase, Datadog/NR), cross-references data, reconstructs timeline, identifies root cause, and produces Investigation Case with Fix Plan. Use when the user says "investigation", "investigate", "investigation-case", "analyze this bug", "deep dive", "root cause", "what happened", "why did this fail", or when a bug/incident requires cross-system evidence gathering before fixing.
argument-hint: [ticket ID like BUG007-XXXX or EXP-XXXX, or problem description]
compatibility: Requires gh (GitHub CLI), git, newrelic CLI (legacy services), mcp-atlassian (Jira/Confluence), Slack MCP, Datadog MCP
context: fork
model: sonnet
allowed-tools: Bash(git *), Bash(gh *), Bash(newrelic *), Bash(wc *), Bash(ls *), Read, Write, Edit, Grep, Glob, Agent, mcp__claude_ai_Slack__slack_search_public_and_private, mcp__claude_ai_Slack__slack_read_channel, mcp__claude_ai_Slack__slack_read_thread, mcp__mcp-atlassian__jira_search, mcp__mcp-atlassian__jira_get_issue, mcp__mcp-atlassian__jira_get_issue_dates, mcp__mcp-atlassian__jira_get_issue_development_info, mcp__mcp-atlassian__confluence_search, mcp__mcp-atlassian__confluence_get_page
---

# Investigation Case -- Deep Forensic Investigation

## Purpose

Comprehensive investigation of bugs, incidents, or reported problems. Goes beyond triage (is it ours?) into deep forensic analysis: WHY it was built this way, WHAT business rules are involved, WHEN it broke, WHO touched it, and HOW to fix it using established company patterns.

## Language

The Investigation-Case.md document MUST be written in **English**. All narrative text, section titles, analysis, and explanations must be in English. Technical terms (code snippets, file paths, PR titles, error messages, variable names) remain as-is. Tables use English headers.

## Working Directories

1. **Obsidian workspace**: `__VAULT_ROOT__`
2. **Codebase**: `__CODEBASE_ROOT__`
3. **Investigation output**: `Development/BUG/{TICKET-ID}/` in the Obsidian workspace

## References

| File | Content |
|------|---------|
| [references/channel-map.md](references/channel-map.md) | Full Slack channel (4 tiers) and Confluence space (3 tiers) maps with IDs |
| [references/evidence-agents.md](references/evidence-agents.md) | Detailed prompts for the 7 parallel evidence collection agents |
| [references/report-template.md](references/report-template.md) | Investigation Case document template |
| [references/learnings.md](references/learnings.md) | Lessons from past investigations (review before starting) |

## Common Agent Mistakes

These mistakes have been observed across investigations and led to shallow reports, incorrect root causes, or wasted routing.

1. **Stopping too early**: Concluding investigation with fewer than 10 evidence items. Why: shallow investigations miss the root cause and produce fix plans that address symptoms. The 10-item minimum forces breadth before depth.
2. **Ignoring service chain**: Investigating only the reported service without resolving the full chain. Why: bugs in LE often span 3-5 services (e.g., www-le-customer -> svc-order -> svc-experiences -> svc-ee-offer). Investigating only one misses the actual failure point.
3. **Timestamp blindness**: Collecting evidence without cross-referencing timestamps. Why: the timeline is the primary tool for identifying "what changed when it broke." Without timestamps, correlation is impossible.
4. **Single-source bias**: Finding one strong lead in Slack and stopping the sweep. Why: Slack conversations often contain incomplete or incorrect assumptions. Cross-referencing with code, Datadog, and Confluence validates or invalidates the lead.
5. **Fixing instead of investigating**: Starting to write fix code during investigation. Why: investigation produces a report and fix plan, not code. Premature fixing without full context often introduces new bugs. Use /debug-mode for implementation.
6. **Missing the human context**: Not checking who was working on related code/tickets recently. Why: git blame, PR authors, and Slack thread participants often reveal critical context (e.g., "I changed this because of X constraint" in a PR body).

---

## Phase 0: Input & Scope Definition

### Parse input from $ARGUMENTS

Extract:

- **Ticket ID** (e.g., BUG007-4742, EXP-3500)
- **Problem description** (from user or will be fetched from Jira)
- **Specific customer/order IDs** (if mentioned)
- **Environment** (prod, staging, local)

### Fetch ticket if only ID provided

```bash
# Use Jira MCP tool:
mcp__mcp-atlassian__jira_get_issue(issue_key: '{TICKET-ID}')
```

### Check past learnings

Read `references/learnings.md` for any relevant entries from prior investigations.

### Create investigation directory

```bash
mkdir -p "__VAULT_ROOT__/Development/BUG/{TICKET-ID}"
```

### Announce scope

```
Investigation Case: {TICKET-ID}
Scope: {1-line problem statement}
Sources: Jira, Slack, GitHub, Confluence, Codebase, Datadog/New Relic
Strategy: Parallel evidence collection -> Cross-reference -> Root cause -> Fix plan
```

---

## Phase 0.5: Service Chain Resolution (MANDATORY before launching agents)

Before launching ANY evidence collection agents, resolve the full service chain involved.

### Step 0: LE Vault RAG (MCP `local-le-chromadb`) — FIRST

Run **`query_vault`** with the incident symptom, error text, ticket id, and suspected domain. Set **`service_filter`** for each service already identified from the ticket (e.g. `svc-experiences`). Use **`list_vault_sources`** if you need filters or coverage. Use hits to seed **hypotheses**, **terminology aliases**, and **known pitfalls** before parallel agents.

If the MCP is not available, skip and note the gap; do not replace this with Confluence-only search without attempting the vault when it returns.

### Step 1: Read Ecosystem Maps

Read these files from the vault (absolute path: `__VAULT_ROOT__`):

```bash
# Read all four in parallel using the Read tool:
Read("Runbooks/Experiences-Ecosystem.md")      # Experiences vertical: services, providers, data flows, async jobs
Read("Runbooks/Luxury-Escapes-Ecosystem.md")   # Full ecosystem: all verticals, shared services, integrations
Read("Development/Providers/Provider-Patterns.md")  # Provider integration patterns, multi-service recipes
Read("Development/BUG/Bug-Triaging.md")        # Ownership matrix, domain classification
```

### Step 2: Build Service Chain

From the ecosystem maps, identify ALL services in the data flow chain for this problem:

```
Example: "experience promo not applied in refund"
Chain: www-le-customer -> svc-promo -> svc-order -> svc-experiences -> svc-ee-offer -> Salesforce
```

Map each service to:
- **Repo name**: `lux-group/{repo}`
- **Owning team**: from ecosystem map or Bug-Triaging.md
- **Terminology aliases**: different names the same concept uses across services (e.g., LED = "Lux Everyday" = svc-ee-offer = "Salesforce Connect"; "bundle" = "complimentary" in codebase)

### Step 3: Build Terminology Expansion Table

Many concepts have multiple names across the codebase, Jira, Confluence, and Slack. Build a table BEFORE searching:

```markdown
| Canonical Term | Aliases (search with ALL of these) |
|---|---|
| {term1} | {alias1}, {alias2}, {alias3} |
| {term2} | {alias1}, {alias2} |
```

Common expansions:
- **LED** = "Lux Everyday", "svc-ee-offer", "Salesforce Connect", "LE Direct"
- **Experiences** = "things to do", "TTD", "tours", "activities", "svc-experiences"
- **Complimentary** = "bundle" (incorrect but used in Slack), "included experience", "complementary"
- **Promo** = "promotion", "discount", "coupon", "promo code", "voucher"

### Step 4: Identify Priority Search Channels

From the ecosystem map and service chain, determine:
- **Slack channels**: team channels, service channels, domain channels
- **Confluence spaces**: PE, TEC, ENGX, ENG, plus any team-specific spaces
- **GitHub repos**: all repos in the service chain, not just the primary one

Full channel/space map: [references/channel-map.md](references/channel-map.md)

**Summary of tier selection**:

| Tier | When to include |
|------|-----------------|
| Tier 1 (Team & Core) | ALWAYS |
| Tier 2 (Adjacent Teams) | When service chain crosses team boundaries |
| Tier 3 (Provider Integrations) | For provider-specific issues |
| Tier 4 (Cross-Functional) | For broad context, incidents, escalations |

---

## Phase 1: Parallel Evidence Collection

Launch 6-7 agents SIMULTANEOUSLY. Each agent is specialized in one data source. Use the Agent tool with `subagent_type: "general-purpose"` for each.

**CRITICAL**: All agents MUST run in a SINGLE message with multiple Agent tool calls. Do NOT run them sequentially.

**CRITICAL**: Pass the Service Chain, Terminology Expansion Table, and Priority Channels from Phase 0.5 to EVERY agent.

Full agent prompts: [references/evidence-agents.md](references/evidence-agents.md)

### Agent Summary

| Agent | Source | Key tool calls | Minimum queries |
|-------|--------|---------------|-----------------|
| 1. Jira Deep Dive | Jira | `jira_get_issue`, `jira_get_issue_dates`, `jira_get_issue_development_info`, `jira_search` | Ticket + related search |
| 2. Slack Archaeology | Slack | `slack_read_channel` (priority channels), `slack_search_public_and_private`, `slack_read_thread` | 8 keyword queries + channel reads |
| 3. GitHub Forensics | GitHub | `gh pr list --search`, `gh pr view --json`, `git log --grep`, `git blame`, `gh release list` | 3 keyword variations per repo |
| 4. Confluence Knowledge | Confluence | `confluence_search`, `confluence_get_page`, `confluence_get_page_children` | 10 queries across all spaces + 5 full page reads |
| 5. Backend Codebase | Codebase | `Grep`, `Read`, `Glob` (trace code path, config, tests) | All services in chain |
| 6. Frontend Codebase | Codebase | `Grep`, `Read`, `Glob` (components, data flow, feature flags) | www-le-customer + www-le-admin |
| 7. Production Intelligence | Datadog/NR | Datadog MCP tools (logs, metrics, traces, monitors). Fallback: `newrelic nrql query` | Error logs + trends + traces |

---

## Phase 2: Evidence Synthesis & Cross-Reference

After ALL agents return, synthesize their findings. This is the CRITICAL phase where raw data becomes intelligence.

### 2.1 Timeline Reconstruction

Build a chronological timeline from ALL sources:

```markdown
| Date/Time  | Event                                  | Source     | Significance               |
| ---------- | -------------------------------------- | ---------- | -------------------------- |
| YYYY-MM-DD | Feature originally developed (PR #XXX) | GitHub     | Original intent: {purpose} |
| YYYY-MM-DD | Business rule documented in Confluence | Confluence | Rule: {rule description}   |
| YYYY-MM-DD | Config change deployed                 | GitHub/DD  | {what changed}             |
| YYYY-MM-DD | First error appeared in DD/NR          | Datadog/NR | Correlates with deploy?    |
| YYYY-MM-DD | Bug reported by CX                     | Jira       | Customer impact started    |
| YYYY-MM-DD | Team discussion in Slack               | Slack      | {key decisions}            |
```

### 2.2 Business Context Extraction

From ALL sources, extract and consolidate:

- **WHY was this feature/flow built?** (PR bodies, Confluence, Slack)
- **WHAT business rules govern it?** (Confluence, code analysis, Slack decisions)
- **WHO was involved in building it?** (git blame, PR authors, Slack)
- **WHAT was the original intent vs current behavior?** (Confluence/PR bodies vs current code)

### 2.3 Root Cause Analysis

Cross-reference findings to identify the root cause:

1. **What changed?** (git history, deploys, config changes)
2. **When did it break?** (DD/NR timeline, first bug report)
3. **Does the timing correlate?** (deploy dates vs error start)
4. **Is it a regression or latent bug?** (was it ever working correctly?)
5. **Is it a code bug, config issue, data issue, or external dependency?**

Apply the 5 Whys technique:

```
1. Why is the customer seeing X? -> Because the API returns Y
2. Why does the API return Y? -> Because the service does Z
3. Why does the service do Z? -> Because the business rule says...
4. Why does the business rule say that? -> Because the original design...
5. Why was it designed that way? -> Because of constraint/decision...
```

### 2.4 Ownership Classification

Determine who owns this issue using the full classification matrix from `Development/BUG/Bug-Triaging.md` in the vault. That file contains: positive/negative indicators, platform dimension, domain dimension, decision matrix, svc-order context paths, and known non-Experiences domains.

Key quick checks:
- Mobile-only bug -> Mobile team (NOT us)
- `svc-order/src/context/accommodation/` -> Hotels
- `svc-order/src/context/experience/` -> Experiences (OURS)

Classify across 4 dimensions: Platform, Domain, Service, Team. Each with confidence level (High/Med) and evidence.

If NOT our team's issue, document the evidence and routing recommendation. Continue the investigation regardless (the document serves as handoff material).

### 2.5 Impact Assessment

```
- Affected customers: [count or estimate from DD/NR]
- Affected orders: [count or IDs if known]
- Severity: [P1/P2/P3 with justification]
- Blast radius: [single customer / segment / all users]
- Trend: [growing / stable / declining]
- Revenue impact: [if quantifiable]
- Has workaround: [yes/no, what is it]
```

### 2.6 Similar Bug Pattern Check

From the Jira search results, identify:

- Has this exact bug been reported before?
- Are there similar bugs that were already fixed? (What was the fix?)
- Is this part of a recurring pattern?

---

## Phase 3: Fix Plan Curation

Based on ALL evidence, create a concrete fix plan that uses established company patterns.

### 3.1 Approach Selection

Present 2-3 possible approaches with trade-offs:

```markdown
### Option A: {name}

- Description: {what}
- Pros: {benefits}
- Cons: {risks}
- Effort: {S/M/L}
- Pattern precedent: {link to similar PR or pattern}

### Option B: {name}

...

### Recommendation: Option {X}

Rationale: {why this is the best approach}
```

### 3.2 Implementation Steps

```markdown
| Step | Action       | File(s)      | Pattern Reference                 |
| ---- | ------------ | ------------ | --------------------------------- |
| 1    | {what to do} | {file paths} | {similar existing code to follow} |
| 2    | ...          | ...          | ...                               |
```

Each step MUST reference an existing pattern in the codebase. Never invent new patterns.

### 3.3 Test Plan

```markdown
| Category         | Test                                  | Expected Result        |
| ---------------- | ------------------------------------- | ---------------------- |
| **Reproduction** | {exact steps from bug report}         | {bug no longer occurs} |
| **Regression**   | {related flows that must still work}  | {unchanged behavior}   |
| **Edge cases**   | {boundary conditions the fix touches} | {correct handling}     |
| **Unit tests**   | {new/modified tests}                  | {all pass}             |
```

### 3.4 Risks & Mitigations

```markdown
| Risk     | Likelihood   | Impact       | Mitigation            |
| -------- | ------------ | ------------ | --------------------- |
| {risk 1} | Low/Med/High | Low/Med/High | {mitigation strategy} |
```

### 3.5 Rollback Strategy

- Feature flag: `DISABLE_{FEATURE_NAME}=true`
- If env var is true, revert to old behavior
- Rollback: set env var + service restart (no deploy needed)

### 3.6 Deploy Considerations

- Deploy order (if multi-service)
- Environment testing sequence (staging -> production)
- Monitoring to watch after deploy (Datadog dashboard, Slack alerts)

---

## Verification (MANDATORY before presenting report)

- [ ] Evidence count: minimum 10 items with sources and timestamps
- [ ] Timeline: events ordered chronologically, no gaps > 24h without explanation
- [ ] Service chain: all services in the chain identified and checked
- [ ] Root cause: specific (file, line, commit, config) not vague ("something in the service")
- [ ] Fix plan: actionable steps with owner/service/file for each item
- [ ] Cross-reference: at least 2 independent sources corroborate the root cause
- [ ] Ownership: clear team/person identified for the fix
- [ ] Reproduction: steps to reproduce documented (or explicit "not reproducible" with reason)

---

## Phase 4: Document Generation (MANDATORY structure)

Create the investigation document at:
`Development/BUG/{TICKET-ID}/Investigation-Case.md`

The document MUST follow this exact structure, written in English. Every section is required:

```markdown
---
tags: [investigation, {ticket-id}, {service-name}]
date: YYYY-MM-DD
ticket: {TICKET-ID}
status: investigating
ownership: {team-name}
severity: {P1/P2/P3}
---

# Investigation Case: {TICKET-ID}

> {One-line problem description}

## Executive Summary
{2-3 sentences: what happened, who was affected, root cause, recommended fix}

## Evidence Collection
### Jira Evidence
### Slack Evidence
### GitHub Evidence
### Confluence Evidence
### Codebase Evidence (Backend)
### Codebase Evidence (Frontend)
### Production Evidence (Datadog/New Relic)

## Timeline Reconstruction
| Date/Time | Event | Source | Significance |

## Business Context
### Why this feature was developed
### Business rules involved
### Original intent vs current behavior

## Root Cause Analysis
### What went wrong
### Why it went wrong (5 Whys)
### Contributing factors

## Impact Assessment
- Affected customers | Affected orders | Severity | Blast radius | Trend | Workaround

## Ownership Classification
| Dimension | Value | Confidence | Evidence |

## Similar Incidents

---

## Fix Plan
### Recommended Approach
### Alternative Approaches Considered
### Implementation Steps
| Step | Action | File(s) | Pattern Reference |

### Test Plan
| Category | Test | Expected Result |

### Risks and Mitigations
| Risk | Probability | Impact | Mitigation |

### Rollback Strategy
### Deploy Considerations

## References
```

See [references/report-template.md](references/report-template.md) for detailed field descriptions and frontmatter status values.

---

## Phase 5: Present & Recommend Next Steps

After writing the document, present a summary to the user:

```
Investigation Case complete: Development/BUG/{TICKET-ID}/Investigation-Case.md

Summary:
- Root cause: {1-2 sentences}
- Ownership: {team} ({confidence})
- Severity: {P1/P2/P3}
- Recommended fix: {1-2 sentences}

Suggested next steps:
1. /debug-mode {TICKET-ID} -- Implement and test the fix with evidence
2. /learn -- Capture the root cause as persistent learning
3. Review the fix plan and adjust if needed
```

If the bug is NOT our team's:

```
Full investigation case: Development/BUG/{TICKET-ID}/Investigation-Case.md

Conclusion: This problem belongs to team {team}.
Evidence: {key evidence}
Recommendation: Route to team {team} with the investigation document as context.

The document can serve as handoff material.
```

---

## Rules

### Core Rules
- NEVER use Chrome MCP for Jira/Confluence. Use mcp-atlassian tools
- ALL evidence collection agents MUST run in parallel (single message, multiple Agent calls)
- If an agent fails, retry 2x then continue with partial results. Never block the investigation
- Every claim in the root cause analysis must be backed by evidence from at least one source
- The fix plan must reference existing codebase patterns, not invented approaches
- Cross-reference is mandatory: no single-source conclusions
- The document is the deliverable. It must be self-contained and actionable
- After investigation, suggest `/debug-mode` for implementation or `/learn` for knowledge capture
- Document status in frontmatter: `investigating` -> `resolved` / `escalated` / `handed-off`
- **ASK before changing approach**: if the investigation direction needs to change (e.g., evidence points to a completely different root cause than initially suspected, or the problem is in a different service than expected), STOP and present findings to the user before pivoting. Never silently change the investigation direction

### Team Context
- Known team members (Experiences): __USER_NAME__ and team members (update this file manually after setup with your team's contacts)
- Team channel: `#team-experiences-pt-br` (C036ALHDG79)
- Engineering Manager: check your team org chart
- Key stakeholders: check your team org chart for current product and engineering contacts

### Search Quality Rules

These rules exist because shallow investigations produce incorrect root causes. Each rule was added after a real investigation missed critical evidence.

1. **Phase 0.5 first**: Always complete Service Chain Resolution before launching agents. Why: ecosystem maps reveal which services are in the data flow. Skipping this means agents search the wrong repos and channels.
2. **Terminology expansion**: Every search (Slack, Confluence, GitHub) must use all known aliases for the concept. Why: the same feature is called "LED" in Slack, "svc-ee-offer" in code, "Salesforce Connect" in Confluence, and "Lux Everyday" in Jira. Single-term search misses 60%+ of results.
3. **Minimum search depth**: Slack (8 queries + channel reads), Confluence (10 queries + 5 full pages), GitHub (3 keywords per repo). Why: investigations that stopped at 3-4 queries consistently missed the root cause, finding it was in a Confluence page or Slack thread that needed a different search term.
4. **Full reads, not snippets**: Search snippets are not evidence. Full page reads, full thread reads, full PR body reads are required. Why: the critical detail is usually in paragraph 3 of a Confluence page or message 7 of a Slack thread, not the search snippet.
5. **Zero results trigger variations**: If a search returns 0 results, try a different wording, alias, or space. Why: 0 results almost always means wrong search terms, not "nothing exists."
6. **Cross-source validation**: If Slack mentions a Confluence page, fetch it. If a PR references a Jira ticket, fetch it. Follow every cross-reference. Why: cross-references connect the timeline and reveal the full picture.
7. **Search all repos in chain**: Not just the one where the bug was reported. Why: bugs in LE often originate 2-3 services upstream from where the symptom appears.
8. **Both keyword search and channel reading for Slack**: Why: keyword search misses conversations that use unexpected terminology. Channel history catches context that keywords miss.
9. **Follow links in Confluence**: After reading a page, check child pages and follow links. Why: the most valuable content is often one link away from the search result.
10. **10-item quality gate**: If fewer than 10 evidence items, search was too shallow. Go back before synthesizing. Why: investigations with < 10 items had a 70%+ chance of misidentifying root cause in past cases.
