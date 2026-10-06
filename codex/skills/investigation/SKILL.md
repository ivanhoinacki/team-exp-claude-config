---
name: investigation
description: "Deep investigation workflow for bugs, incidents, unclear behavior, technical decisions, production symptoms, feature questions, ownership questions, or any situation that needs evidence before action. Sweeps relevant sources (vault, Jira, Slack, GitHub, Confluence, codebase, Datadog/observability), cross-references findings, reconstructs timeline or decision context, identifies root cause or answer, and produces an Investigation report with an actionable plan. Use when the user says \"investigation\", \"investigate\", \"investiga\", \"analyze\", \"deep dive\", \"root cause\", \"what happened\", \"why did this fail\", \"look into this\", \"find out\", or when any question requires multi-source evidence and a plan before implementation."
---


# Investigation -- Evidence-First Analysis And Plan

## Codex Adaptation

Converted from `__HOME__/.agents/skills/investigation-case/SKILL.md` and renamed for Codex as the general-purpose `investigation` skill.
Claude-only frontmatter fields such as `model`, `allowed-tools`, `argument-hint`, and `compatibility` were removed because Codex discovers skills through `name` and `description`.
Original Claude model hint: `opus`. In Codex, use tier-approved model overrides for subagents because `spawn_agent` otherwise inherits the parent model.
Use Codex tools and MCPs available in the current session. If a named Claude MCP is unavailable, state the gap and use the closest safe local source.
Do not mutate Slack, Jira, Confluence, GitHub, Datadog, CI/CD, infrastructure, or production systems without explicit approval.
Use Codex subagents only when current system or user instructions explicitly allow delegation.

## Token Economy Rules (MANDATORY)

- Prefix noisy shell commands with `rtk`, especially `git diff`, `git log`, `gh`, tests, build output, and process inspection.
- Start with the smallest evidence set that can answer the question.
- Use bounded reads and snippets first. Read full pages, threads, or files only when they are likely to contain decisive context.
- Load reference files and agent prompts only when the selected investigation level needs them.
- Keep interim outputs compact: evidence, confidence, gaps, next action.
- Do not sweep archived Codex sessions, broad Slack history, or full git history unless the investigation level is `forensic` or Ivan explicitly asks.
- For `triage`, cap each evidence source to the smallest useful slice: one vault query, targeted code search, one PR/thread/log source when needed.
- Save long raw evidence to a file and summarize it; do not paste large logs, PR bodies, or transcript chunks into the conversation.

## Investigation Levels

Choose the smallest level that fits the request:

| Level | Use when | Evidence budget |
|---|---|---|
| `triage` | A focused question, likely single-service issue, ownership check, or quick "why" | `local-le-vault` + targeted code/log/PR evidence. No subagents by default. |
| `targeted` | Multiple plausible causes, stale plan, one or two external systems, or medium-risk decision | Vault + code + 1-2 strongest external sources. Optional read-only subagents only if they reduce wall time. |
| `forensic` | Incident, production impact, cross-service timeline, ownership dispute, or high-risk decision | Full multi-source sweep and fan-out are allowed. |

Default to `triage` unless the user asks for deep/forensic investigation or the evidence shows broader scope is needed.

## Parallel Agent Policy

Invoking `investigation` is not, by itself, a request to spend full fan-out context. Use fan-out for `forensic` investigations, or for `targeted` investigations when independent evidence streams clearly reduce wall time without duplicating context. The parent agent owns correlation, timeline or decision context, root cause or answer, final report, and action plan.

Cost model: evidence collectors use `cheap_readonly`. Spawn `researcher` subagents with `model="gpt-5.4-mini"` and `reasoning_effort="low"` explicitly as best effort. Verify the runtime log before assuming the override was honored; if Codex inherits the parent model, reduce fan-out breadth. The parent handles `expensive_synthesis` only for forensic conclusions, contradicted evidence, architecture decisions, production incidents, or financial/security risk.

Use the prompts in `references/evidence-agents.md` only for forensic or explicitly broad investigations. Dispatch only read-only collectors for Jira, Slack, GitHub, Confluence, codebase, Datadog/observability, and vault/prior learnings.

Do not delegate production mutations, ticket updates, Slack writes, GitHub writes, or fixes. Subagents collect evidence only.

Parallel execution model:

| Phase | Parallelism |
| --- | --- |
| 0 | Fetch ticket, read past learnings, and create the investigation directory in parallel after parsing the input. |
| 0.5 | Run Step 0 (Vault RAG) and Step 1 (4 ecosystem reads) in parallel when both are available. Build the service chain only after both return. |
| 1 | For forensic investigations, launch 7 cheap `researcher` evidence collectors **SIMULTANEOUSLY** in one fan-out round using `model="gpt-5.4-mini"` and `reasoning_effort="low"`. For triage/targeted work, collect only the bounded evidence needed. |
| 2 | For forensic investigations, launch 5 `researcher` synthesis agents in parallel for 2.1, 2.2, 2.4, 2.5, and 2.6. For triage/targeted investigations, synthesize locally from the bounded evidence set. |
| 3-4 | Run sequentially. Phase 3 depends on Phase 2. Phase 4 depends on Phase 3. |

The parent agent owns correlation, final conclusion, final report, and action plan. Subagents or parallel lanes collect and shape evidence only; they do not make final ownership or root-cause decisions independently.

## Visible Deep Dive Lanes

For `targeted` and `forensic` investigations, make evidence collection visible like Claude-style agent runs. This is required when Ivan asks to investigate, search broadly, compare behavior, analyze a spec, or validate a production symptom.

Before launching evidence collection, announce the lanes in one compact block. Choose only relevant lanes:

```text
Deep dive lanes:
- Deep dive: Jira + ticket attachments
- Deep dive: vault + prior learnings
- Deep dive: codebase + git history
- Deep dive: GitHub resolved precedents
- Deep dive: Slack + Confluence decisions
- Deep dive: Datadog proxy/app logs
- Deep dive: local artifacts/screenshots
```

Use read-only subagents for independent lanes when available. If generic subagents are not available in the current Codex runtime, run the same lanes with parallel tool calls or bounded local reads and say `subagents unavailable, running local lanes`.

When each lane finishes, report a short completion line:

```text
Deep dive "Datadog proxy/app logs" completed · 2 queries · exact 500 reproduced
Deep dive "GitHub resolved precedents" completed · 3 PRs checked · BUG007-4938 relevant
```

If a lane is blocked, report it with the attempted tool/query and fallback:

```text
Deep dive "Confluence decisions" blocked · Atlassian auth failed · vault-synced fallback used
```

The final investigation must include a short `Deep Dive Coverage` table with lane status, evidence count, and blocker/fallback where relevant.


## Vault RAG Guardrail

Before ANY codebase file reads, grep, or implementation exploration, call `query_vault` with relevant keywords, `client_filter` set to the active client slug, and `service_filter` when known. The client filter is mandatory on client-scoped work: it excludes rows tagged for other clients while preserving neutral or legacy rows. Omit it only for an explicitly company-neutral query. The vault contains pitfalls, business rules, review learnings, and patterns that prevent rework. Skip = rework.

## Purpose

Comprehensive investigation of any ambiguous or evidence-sensitive question. Use it for bugs, incidents, reported problems, production symptoms, ownership questions, feature behavior, regressions, architecture questions, or team decisions that need multi-source evidence. The output is not just an answer: it is a self-contained Investigation report with findings, evidence, root cause or conclusion, and an actionable plan.

## Language

The Investigation.md document MUST be written in **English**. All narrative text, section titles, analysis, and explanations must be in English. Technical terms (code snippets, file paths, PR titles, error messages, variable names) remain as-is. Tables use English headers.

## Working Directories and Output Routing

1. **Vault root**: `__VAULT_ROOT__`
2. **Company-neutral root**: `Personal Projects/`
3. **Luxury Escapes root**: `Luxury-Escapes/`
4. **Codebase**: derive from the repository named by the user or the current working directory. Do not default to Luxury Escapes.

Route the output before creating files:

- No explicit company, corporate ticket, or company-owned system: `Personal Projects/Investigations/{INVESTIGATION-ID}/`.
- Explicit Luxury Escapes context or `EXP-*`/`BUG007-*` ticket: use the canonical folder under `Luxury-Escapes/Development/`; use `Luxury-Escapes/Development/Investigations/{INVESTIGATION-ID}/` only when no feature or bug folder exists.
- Another explicit company: use that company's vault root and its existing investigation convention.
- A user-provided destination always wins.

Use a short date-prefixed slug when no ticket exists.

## References

| File                                                           | Content                                                                   |
| -------------------------------------------------------------- | ------------------------------------------------------------------------- |
| [references/channel-map.md](references/channel-map.md)         | Full Slack channel (4 tiers) and Confluence space (3 tiers) maps with IDs |
| [references/evidence-agents.md](references/evidence-agents.md) | Detailed prompts for the 7 parallel evidence collection agents            |
| [references/report-template.md](references/report-template.md) | Investigation document template                                           |
| [references/learnings.md](references/learnings.md)             | Lessons from past investigations (review before starting)                 |

## Common Agent Mistakes

These mistakes have been observed across investigations and led to shallow reports, incorrect root causes, or wasted routing.

1. **Stopping too early**: Concluding investigation with fewer than 10 evidence items. Why: shallow investigations miss the root cause and produce fix plans that address symptoms. The 10-item minimum forces breadth before depth.
2. **Ignoring service chain**: Investigating only the reported service without resolving the full chain. Why: bugs in LE often span 3-5 services (e.g., www-le-customer -> svc-order -> svc-experiences -> svc-ee-offer). Investigating only one misses the actual failure point.
3. **Timestamp blindness**: Collecting evidence without cross-referencing timestamps. Why: the timeline is the primary tool for identifying "what changed when it broke." Without timestamps, correlation is impossible.
4. **Single-source bias**: Finding one strong lead in Slack and stopping the sweep. Why: Slack conversations often contain incomplete or incorrect assumptions. Cross-referencing with code, Datadog, and Confluence validates or invalidates the lead.
5. **Fixing instead of investigating**: Starting to write fix code during investigation. Why: investigation produces a report and action plan, not code. Premature fixing without full context often introduces new bugs. Use /debug-mode for implementation when the next step is a fix.
6. **Missing the human context**: Not checking who was working on related code/tickets recently. Why: git blame, PR authors, and Slack thread participants often reveal critical context (e.g., "I changed this because of X constraint" in a PR body).

---

## Phase 0: Input & Scope Definition

Phase 0 has three independent evidence-prep tasks after input parsing:

1. Fetch the Jira ticket when only an ID is provided.
2. Read `references/learnings.md` for relevant prior learnings.
3. Check local ticket folder artifacts and Jira attachments/screenshots.
4. Create the investigation output directory.

Run them in parallel when useful, ideally in one bounded dispatch batch. For triage, keep this to the ticket/vault/context needed to answer the immediate question.

### Parse input from $ARGUMENTS

Extract:

- **Investigation ID** (ticket ID if available, e.g., BUG007-4742 or EXP-3500; otherwise create `YYYY-MM-DD-short-slug`)
- **Problem description** (from user or will be fetched from Jira)
- **Specific customer/order IDs** (if mentioned)
- **Environment** (prod, staging, local)

### Fetch ticket if only ID provided

```bash
# Use Jira MCP tool:
mcp-atlassian jira_get_issue(issue_key: '{TICKET-ID}')
```

### Check past learnings

Read `references/learnings.md` for any relevant entries from prior investigations.

### Check local artifacts and attachments

If the user provides an existing investigation folder, or if a matching ticket folder already exists in the routed company root, list the files before writing the report. Inspect screenshots/images, logs, CSVs, HAR files, exports, and prior notes. For images, use image inspection and record what the UI, console, network panel, request params, and visible error state show.

Also check Jira attachments when the Atlassian MCP exposes them. If Jira attachments are unavailable, explicitly record that gap and rely on local folder artifacts.

### Browser/UI reproduction

If the investigation needs live browser reproduction, UI/UX validation, login, screenshots, console logs, network requests, E2E steps, or admin/customer journey evidence, use `chrome-devtools-validation`. When the investigation needs multiple browser states at once, such as admin + customer or authenticated + logged-out comparison, follow that skill's parallel isolated MCP pattern. Do not use any other browser automation path unless Ivan explicitly overrides it for the current task.

### Create investigation directory

Resolve `INVESTIGATION_DIR` from the routing rules above, verify the exact parent, then create only that directory:

```bash
mkdir -p "$INVESTIGATION_DIR"
```

### Announce scope

```
Investigation: {INVESTIGATION-ID}
Scope: {1-line problem statement}
Sources: Jira, Slack, GitHub, Confluence, Codebase, Datadog/New Relic
Strategy: Parallel evidence collection -> Cross-reference -> Conclusion -> Action plan
```

---

## Phase 0.5: Service Chain Resolution (MANDATORY before launching agents)

Before launching ANY evidence collection agents, resolve the full service chain involved.

Run Step 0 and Step 1 in parallel when useful. For triage, Step 0 plus the most relevant ecosystem read is enough unless evidence shows the service chain is broader:

- Step 0: LE Vault RAG.
- Step 1: Read all four ecosystem maps.

Then run Steps 2-4 sequentially because they depend on the returned vault hits and ecosystem context.

### Step 0: LE Vault RAG (MCP `local-le-vault`)

Run **`query_vault`** with the incident symptom, error text, ticket id, suspected domain, and **`client_filter`** set to the active client slug. The client filter is mandatory for client-scoped work; omit it only for an explicitly company-neutral query. Set **`service_filter`** for each service already identified from the ticket (e.g. `svc-experiences`). Use **`list_vault_sources`** if you need filters or coverage. Use hits to seed **hypotheses**, **terminology aliases**, and **known pitfalls** before parallel agents.

Domain routing examples:

- Car Hire, CarTrawler, vehicle availability, or car booking: `service_filter="svc-car-hire"`.
- Experiences attractions/tours/offers: `service_filter="svc-experiences"`.
- Orders, payments, promo/refund/order state: `service_filter="svc-order"`.
- White Label, LED, Lux Everyday, Salesforce Connect: `service_filter="svc-ee-offer"`.

If the MCP is not available, skip and note the gap; do not replace this with Confluence-only search without attempting the vault when it returns.

### Step 1: Read Ecosystem Maps

For Luxury Escapes investigations only, read these files from `Luxury-Escapes/` in the vault:

```bash
# For targeted/forensic work, read the relevant ecosystem docs in parallel using bounded reads:
Read file: "Runbooks/Experiences-Ecosystem.md")      # Experiences vertical: services, providers, data flows, async jobs
Read file: "Runbooks/Luxury-Escapes-Ecosystem.md")   # Full ecosystem: all verticals, shared services, integrations
Read file: "Development/Providers/Provider-Patterns.md")  # Provider integration patterns, multi-service recipes
Read file: "Development/BUG/Bug-Triaging.md")        # Ownership matrix, domain classification
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
| -------------- | ---------------------------------- |
| {term1}        | {alias1}, {alias2}, {alias3}       |
| {term2}        | {alias1}, {alias2}                 |
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

| Tier                           | When to include                            |
| ------------------------------ | ------------------------------------------ |
| Tier 1 (Team & Core)           | ALWAYS                                     |
| Tier 2 (Adjacent Teams)        | When service chain crosses team boundaries |
| Tier 3 (Provider Integrations) | For provider-specific issues               |
| Tier 4 (Cross-Functional)      | For broad context, incidents, escalations  |

---

## Phase 1: Parallel Evidence Collection

For forensic investigations, launch 7 `researcher` agents **SIMULTANEOUSLY** for independent read-only evidence collection. Each agent is specialized in one data source. If Codex subagents are available, use `spawn_agent` with `agent_type="researcher"`, `model="gpt-5.4-mini"`, and `reasoning_effort="low"` for each evidence stream in a single fan-out round. Otherwise collect the evidence locally in priority order and state that fan-out was unavailable.

For triage and targeted investigations, do not launch the full agent set. Use local bounded evidence collection or a small number of read-only agents for clearly independent streams.

**CRITICAL for forensic investigations**: Dispatch independent evidence collectors in one parallel delegation round. Do not wait for Agent 1 before launching Agent 2. If delegation is not available in the current runtime, collect the same evidence locally without claiming that agents ran.

**CRITICAL**: Pass the Service Chain, Terminology Expansion Table, and Priority Channels from Phase 0.5 to EVERY agent.

Full agent prompts: [references/evidence-agents.md](references/evidence-agents.md)

### Agent Summary

| Agent                      | Source     | Key tool calls                                                                                   | Minimum queries                                  |
| -------------------------- | ---------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| 1. Jira Deep Dive          | Jira       | `jira_get_issue`, `jira_get_issue_dates`, `jira_get_issue_development_info`, `jira_search`       | Ticket + related search                          |
| 2. Slack Archaeology       | Slack plugin `slack@openai-curated` | `_slack_read_channel` (priority channels), `_slack_search_public` or `_slack_search_public_and_private`, `_slack_read_thread` | 8 keyword queries + channel reads                |
| 3. GitHub Forensics        | GitHub     | `gh pr list --search`, `gh pr view --json`, `git log --grep`, `git blame`, `gh release list`     | 3 keyword variations per repo                    |
| 4. Confluence Knowledge    | Confluence | `confluence_search`, `confluence_get_page`, `confluence_get_page_children`                       | 10 queries across all spaces + 5 full page reads |
| 5. Backend Codebase        | Codebase   | `rg`, `Read`, `Glob` (trace code path, config, tests)                                          | All services in chain                            |
| 6. Frontend Codebase       | Codebase   | `rg`, `Read`, `Glob` (components, data flow, feature flags)                                    | www-le-customer + www-le-admin                   |
| 7. Production Intelligence | Datadog/NR | Datadog MCP tools (logs, metrics, traces, monitors). Fallback: `newrelic nrql query`             | Error logs + trends + traces                     |

### Datadog Gate

For BUG, incident, customer-impact, production-behavior, endpoint, provider, checkout, booking, search, availability, payment, or performance investigations, Production Intelligence is mandatory.

Before Phase 2 synthesis, record one of:

- Datadog evidence found: logs, traces, metrics, monitors, incidents, dashboards, or service catalog links.
- Datadog negative evidence: exact query/window/service checked and why the absence matters.
- Datadog unavailable: concrete MCP/auth/network/tooling failure and the fallback used.

For web/API bugs, query both layers when possible:

- Edge/proxy/API gateway logs by exact endpoint, date/time params, request id, status code, and customer-visible URL terms.
- Application logs by service name, provider/error code, trace id/span id, request id, and error message.

If a proxy query finds failures but app logs are noisy, use representative timestamps, request ids, trace ids, or exact params to narrow the app query. Do not treat a broad app-log count as root cause without tying it back to the reproduction.

Do not conclude root cause for production-facing bugs without this Datadog gate unless Ivan explicitly approves skipping observability evidence.

---

## Phase 1.5: Similar Bug Resolution Filter (BUG007 only)

When the investigation ID or ticket key starts with `BUG007-`, run this filter before Phase 2 synthesis. This step improves accuracy by turning previously resolved bugs into prioritized hypotheses, not final conclusions.

### Search similar BUG007 tickets

Use Jira/Atlassian read-only tools to search the BUG007 service desk project for similar symptoms, services, endpoints, providers, customer impact, error strings, and ticket labels. Include the BUG007 board/queue context when available:

```text
https://aussiecommerce.atlassian.net/jira/servicedesk/projects/BUG007/queues/custom/136
```

Search with:

- ticket summary terms
- error messages and HTTP status
- endpoint, route, provider, service, and product terms
- customer-visible symptom
- terminology aliases from Phase 0.5

Start with 5-10 candidates. Expand only when none are close enough.

### Trace prior fixes in GitHub

For each relevant candidate:

- Read ticket status, resolution, key comments, linked PRs, linked commits, and resolution date.
- Search GitHub by ticket ID, branch names, PR title/body, and commit messages across all repos in the service chain.
- Read the resolving PR body and changed-file list. Read focused hunks only when the file or pattern overlaps the current case.
- Identify the fix pattern: config change, data patch, validation fix, async/race fix, provider-specific handling, frontend guard, retry/idempotency, or routing/handoff.

If Jira development info is blocked or empty, GitHub search is still mandatory. Search by:

- similar BUG ticket ids and nearby tickets
- provider names and provider error codes
- customer-visible error text and API error text
- endpoint/path names and service names
- terms from Datadog logs

Record the exact GitHub queries used, matching PRs, and why each PR is relevant or ruled out. A valid Deep Find must include at least one of: matching PRs, explicit negative evidence, or a permission/network blocker with fallback search attempted.

### Similar Bug Filter table

Add this table to the investigation notes and final report:

```markdown
| Candidate Ticket | Similarity Reason | Prior Root Cause | Prior Fix / PR | Same As Current? | Evidence Needed To Confirm | Confidence |
|---|---|---|---|---|---|---|
| BUG007-XXXX | {symptom/service/provider overlap} | {root cause} | {PR/link} | yes/no/partial | {runtime/code evidence still needed} | High/Med/Low |
```

Rules:

- Similar tickets generate hypotheses, not conclusions.
- A current root cause can be `High confidence` from this filter only when current runtime/code evidence matches the prior pattern.
- If similar tickets disagree, mark the hypothesis as `partial` and keep competing causes alive.
- If no similar tickets are found, record the negative evidence and continue.
- Do not mutate Jira, GitHub, or the BUG007 board.

---

## Phase 2: Evidence Synthesis & Cross-Reference

After ALL agents return, synthesize their findings. This is the CRITICAL phase where raw data becomes intelligence.

Phase 2 parallelism for forensic investigations:

- Launch 5 `researcher` synthesis agents in parallel when the evidence set is large enough to justify it:
  - S1: 2.1 Timeline Reconstruction.
  - S2: 2.2 Business Context Extraction.
  - S3: 2.4 Ownership Classification.
  - S4: 2.5 Impact Assessment.
  - S5: 2.6 Similar Pattern Check.
- The parent/orchestrator runs 2.3 Root Cause Or Conclusion Analysis only after 2.1 and 2.2 complete.
- The parent agent must reconcile all Phase 2 outputs into one final conclusion before Phase 3.

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

### 2.3 Root Cause Or Conclusion Analysis

Cross-reference findings to identify the root cause, explanation, ownership decision, or best-supported answer:

1. **What changed?** (git history, deploys, config changes)
2. **When did it break?** (DD/NR timeline, first bug report)
3. **Does the timing correlate?** (deploy dates vs error start)
4. **Is it a regression or latent bug?** (was it ever working correctly?)
5. **Is it a code bug, config issue, data issue, external dependency, expected behavior, or decision gap?**
6. **For BUG007 tickets, does current runtime or code evidence match prior resolved BUG007 patterns?** (use Phase 1.5 as hypothesis input)

Apply the 5 Whys technique:

```
1. Why is the customer seeing X? -> Because the API returns Y
2. Why does the API return Y? -> Because the service does Z
3. Why does the service do Z? -> Because the business rule says...
4. Why does the business rule say that? -> Because the original design...
5. Why was it designed that way? -> Because of constraint/decision...
```

### 2.4 Ownership Classification

When the investigation involves a bug, incident, or routing question, determine who owns it using the full classification matrix from `Development/BUG/Bug-Triaging.md` in the vault. That file contains: positive/negative indicators, platform dimension, domain dimension, decision matrix, svc-order context paths, and known non-Experiences domains. For non-bug investigations, classify the accountable service, team, or decision owner when possible.

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

### 2.6 Similar Pattern Check

From Jira, GitHub, vault, Slack, and docs search results, identify:

- Has this exact issue, behavior, or decision been reported before?
- Are there similar cases that were already fixed or decided? (What was the fix or decision?)
- Is this part of a recurring pattern?
- For BUG007 tickets, include the Phase 1.5 Similar Bug Filter table and explicitly state which prior fixes are applicable, partially applicable, or ruled out.

---

## Phase 3: Action Plan Curation

Based on ALL evidence, create a concrete action plan that uses established company patterns. For bugs, this is usually a fix plan. For research, routing, architecture, or ownership investigations, it may be a decision plan, handoff plan, validation plan, or implementation plan.

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
- [ ] Root cause or conclusion: specific, evidence-backed, and not vague ("something in the service")
- [ ] Action plan: actionable steps with owner/service/file or decision owner for each item
- [ ] Cross-reference: at least 2 independent sources corroborate the root cause, conclusion, or routing recommendation
- [ ] Ownership: clear team/person identified for the fix
- [ ] Reproduction: steps to reproduce documented (or explicit "not reproducible" with reason)
- [ ] Attachments/screenshots: local folder and Jira attachments checked, or explicit negative evidence recorded
- [ ] Datadog gate: production evidence, negative evidence, or unavailable/fallback is recorded before root-cause synthesis
- [ ] BUG007 similarity: similar tickets and resolving GitHub PRs checked, or negative evidence recorded. Similarity used only as hypothesis unless current evidence confirms it.
- [ ] GitHub Deep Find: exact queries, relevant PRs, ruled-out PRs, and prior fix patterns recorded for all service-chain repos

---

## Phase 4: Document Generation (MANDATORY structure)

Create the investigation document at:
`{INVESTIGATION_DIR}/Investigation.md`

The document MUST follow this exact structure, written in English. Every section is required:

```markdown
---
tags: [investigation, { ticket-id }, { service-name }]
date: YYYY-MM-DD
ticket: { TICKET-ID or N/A }
status: investigating
ownership: { team-name }
severity: { P1/P2/P3 }
---

# Investigation: {INVESTIGATION-ID}

> {One-line problem description}

## Executive Summary

{2-3 sentences: what was investigated, what evidence says, root cause or conclusion, recommended plan}

## Evidence Collection

### Jira Evidence

### Slack Evidence

### GitHub Evidence

### Confluence Evidence

### Codebase Evidence (Backend)

### Codebase Evidence (Frontend)

### Production Evidence (Datadog/New Relic)

### Screenshot / Attachment Evidence

## Timeline Reconstruction

| Date/Time | Event | Source | Significance |

## Business Context

### Why this feature was developed

### Business rules involved

### Original intent vs current behavior

## Root Cause Or Conclusion

### What the evidence shows

### Why it happened or why this conclusion is likely

### Contributing factors

## Impact Assessment

- Affected customers | Affected orders | Severity | Blast radius | Trend | Workaround

## Ownership Classification

| Dimension | Value | Confidence | Evidence |

## Similar Incidents

### BUG007 Similar Bug Filter

| Candidate Ticket | Similarity Reason | Prior Root Cause | Prior Fix / PR | Same As Current? | Evidence Needed To Confirm | Confidence |
|---|---|---|---|---|---|---|

### GitHub Deep Find

| Query | Matching PRs | Relevance | Ruled Out |
|---|---|---|---|

---

## Action Plan

### Recommended Approach

### Alternative Approaches Considered

### Implementation or Follow-up Steps

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
Investigation complete: {INVESTIGATION_DIR}/Investigation.md

Summary:
- Conclusion: {1-2 sentences}
- Ownership: {team} ({confidence})
- Severity: {P1/P2/P3}
- Recommended plan: {1-2 sentences}

Suggested next steps:
1. /debug-mode {INVESTIGATION-ID} -- Implement and test the fix with evidence, if code changes are needed
2. Review the action plan and adjust if needed
```

If the bug is NOT our team's:

```
Full investigation: {INVESTIGATION_DIR}/Investigation.md

Conclusion: This problem belongs to team {team}.
Evidence: {key evidence}
Recommendation: Route to team {team} with the investigation document as context.

The document can serve as handoff material.
```

---

## Rules

### Core Rules

- NEVER use Chrome MCP for Jira/Confluence. Use mcp-atlassian tools
- Evidence collectors run in parallel by default only for forensic investigations. Otherwise, collect bounded evidence locally and state when fan-out was intentionally skipped for token economy.
- If an agent fails, retry 2x then continue with partial results. Never block the investigation
- Every claim in the root cause or conclusion analysis must be backed by evidence from at least one source
- The action plan must reference existing codebase patterns or documented operational workflows, not invented approaches
- Cross-reference is mandatory: no single-source conclusions
- The document is the deliverable. It must be self-contained and actionable
- After investigation, suggest `/debug-mode` only when implementation or runtime debugging is the next step
- Document status in frontmatter: `investigating` -> `resolved` / `escalated` / `handed-off`
- **ASK before changing approach**: if the investigation direction needs to change (e.g., evidence points to a completely different root cause than initially suspected, or the problem is in a different service than expected), STOP and present findings to Ivan before pivoting. Never silently change the investigation direction

### Team Context

- Known team members (Experiences): Ivan Hoinacki, Renan Murta (Product), Diego Gadens, Luiz Carraro, Cleber Ricardi, Matheus Zilio, Jean Biezus, Leo Ferreira, Luiz Henrique Clazzer
- Team channel: `#team-experiences-pt-br` (C036ALHDG79)
- Engineering Manager: Matt Swanson
- Key stakeholders: Aaron Toomey (product), Gregory Fine (product), Joshua Cullen (engineering)

### Search Quality Rules

These rules exist because shallow investigations produce incorrect root causes. Each rule was added after a real investigation missed critical evidence.

1. **Phase 0.5 first**: Always complete Service Chain Resolution before launching agents. Why: ecosystem maps reveal which services are in the data flow. Skipping this means agents search the wrong repos and channels.
2. **Terminology expansion**: Every search (Slack, Confluence, GitHub) must use all known aliases for the concept. Why: the same feature is called "LED" in Slack, "svc-ee-offer" in code, "Salesforce Connect" in Confluence, and "Lux Everyday" in Jira. Single-term search misses 60%+ of results.
3. **Minimum search depth for forensic only**: Slack (8 queries + channel reads), Confluence (10 queries + 5 full pages), GitHub (3 keywords per repo). For triage/targeted work, expand only when the current evidence does not answer the question.
4. **Bounded reads first**: Search snippets are leads, not final evidence. Read the full page/thread/PR body only when the snippet is relevant or the source is likely decisive.
5. **Zero results trigger variations**: If a search returns 0 results, try a different wording, alias, or space. Why: 0 results almost always means wrong search terms, not "nothing exists."
6. **Cross-source validation**: If Slack mentions a Confluence page, fetch it. If a PR references a Jira ticket, fetch it. Follow every cross-reference. Why: cross-references connect the timeline and reveal the full picture.
7. **Search all repos in chain**: Not just the one where the bug was reported. Why: bugs in LE often originate 2-3 services upstream from where the symptom appears.
8. **Both keyword search and channel reading for Slack**: Why: keyword search misses conversations that use unexpected terminology. Channel history catches context that keywords miss.
9. **Follow links in Confluence**: After reading a page, check child pages and follow links. Why: the most valuable content is often one link away from the search result.
10. **10-item quality gate**: If fewer than 10 evidence items, search was too shallow. Go back before synthesizing. Why: investigations with < 10 items had a 70%+ chance of misidentifying root cause in past cases.
11. **BUG007 similarity filter**: For BUG007 tickets, search similar resolved tickets and their GitHub fixes before final root-cause synthesis. Why: recurring bug classes often have known fix patterns, but textual similarity alone is not proof. Treat matches as hypotheses until current runtime or code evidence confirms them.

## Ubuntu portability

Use project AGENTS.md for client facts, knowledge sources, worktrees and infrastructure.
The source machine paths are resolved by the installer. Optional MCPs and Radar require
separate target provisioning. Private histories are local placeholders. Do not assume
the source vault exists. Existing user authorization overrides redundant permission
prompts. When a required local skill/resource is missing, report it instead of claiming
that this package provisioned an external service.
