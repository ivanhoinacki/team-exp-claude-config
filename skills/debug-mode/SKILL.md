---
name: debug-mode
description: Hypothesis-driven debugging workflow that requires runtime evidence before making fixes. Spins up a local log server so browser code can POST structured logs to a file the AI reads directly. Use when the user says "debug", "debug mode", "help me debug", "find this bug", "why isn't this working", "what's wrong with", "it's broken", or when investigating a bug that needs runtime log evidence rather than guessing from static code analysis. Do NOT use for static code review (use /code-review) or for incident investigation across multiple sources (use /investigation-case).
argument-hint: [bug description]
compatibility: Requires node, lsof, curl, git, gh (GitHub CLI)
allowed-tools: Bash(node *), Bash(kill *), Bash(lsof *), Bash(nohup *), Bash(curl *), Bash(git *), Bash(gh *), Read, Grep, Glob, Edit, mcp__claude_ai_Slack__slack_search_public_and_private, mcp__mcp-atlassian__confluence_search, mcp__mcp-atlassian__confluence_get_page
---

# Debug Mode

## Working Directories

Always consider these directories as primary sources when investigating bugs:

1. **Obsidian workspace** (docs, plans, features): `__VAULT_ROOT__`
2. **Codebase** (all LE services): `__CODEBASE_ROOT__`

You are now in **Debug Mode**. Follow a strict hypothesis-driven workflow. Do NOT guess fixes from static analysis alone.

## Common Agent Mistakes

1. **Guessing from static analysis**: Making code changes based on reading code alone without gathering runtime evidence (logs, traces, metrics). The whole point of debug-mode is evidence-based debugging.
2. **Fixing symptoms, not causes**: Patching the error handler or adding a null check without understanding WHY the value is null. Always trace back to the root cause.
3. **Not reproducing first**: Attempting to fix a bug without confirming it exists in the expected environment. Check: does the bug happen in staging? prod? local?
4. **Ignoring the service chain**: The bug may originate in an upstream service. Check the Experiences Ecosystem doc for the data flow chain before diving into one service.
5. **Skipping hypothesis documentation**: Making changes without writing down the hypothesis first. Each fix attempt should be: hypothesis -> evidence -> change -> verify.
6. **Not checking recent deploys**: A bug may have been introduced by a recent deployment. Always check `git log --oneline -10` and recent CircleCI deploys before deep diving.
7. **Not checking KB before attempting fix**: When encountering an error, immediately trying to fix it without running `query_vault` + `grep pitfalls*.md` first. The KB has documented fixes for dozens of known errors. A 2-second vault check prevents a 10-minute retry loop. ALWAYS check vault BEFORE your first fix attempt.

## References

- [Evidence Collection Patterns](references/evidence-collection.md) - Datadog/NR queries, browser console, codebase evidence
- [Debug Mode Learnings](references/learnings.md) - Lessons from past debugging sessions

## Rules

- NEVER fix code without log evidence.
- Every log must map to a hypothesis.
- 3-8 log statements per round.
- Never log secrets.
- Never ask the user to copy-paste console output -- read `.claude/debug.log` directly.

## Log Server

Browser code can't write files. A tiny HTTP server bridges this:

```
Browser JS  -->  fetch() POST  -->  127.0.0.1:7777  -->  .claude/debug.log  -->  AI reads file
Server JS   -->  fs.appendFileSync  --------------------->  .claude/debug.log  -->  AI reads file
```

## Workflow

### Step 0: Start Log Server

```bash
lsof -i :7777 && kill $(lsof -t -i :7777)  # kill if running
rm -f .claude/debug.log
nohup node ~/.claude/skills/debug-mode/scripts/debug-server.js > /tmp/debug-server.log 2>&1 &
sleep 1 && curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:7777 -H 'Content-Type: application/json' -d '{"test":"alive"}'
```

### Step 1: Understand the Bug

Ask: expected vs actual behavior, reproduction steps, when it started.

### Step 1.5: Production Data Investigation (Datadog / New Relic)

BEFORE generating hypotheses, query production observability data. Real data narrows the search space.

**Primary: Datadog MCP** (use by default for all services migrated to DD)

Concrete tool calls (see [evidence-collection.md](references/evidence-collection.md) for full patterns):

1. **Error logs** (last 1h, expand if needed):
   `mcp__datadog-mcp__search_datadog_logs` with query `service:<svc-name> status:error`
2. **Error rate trend** (last 7 days):
   `mcp__datadog-mcp__get_datadog_metric` with query `sum:trace.express.request.errors{service:<svc>}.as_count()`
3. **APM traces for affected endpoint**:
   `mcp__datadog-mcp__search_datadog_spans` with query `service:<svc-name> resource_name:<endpoint> status:error`
4. **Active monitors/incidents**:
   `mcp__datadog-mcp__search_datadog_monitors` with query `<svc-name>`

**Fallback: New Relic CLI** (only for services NOT yet migrated to Datadog)

```bash
newrelic nrql query --accountId 2826932 --query "SELECT count(*) FROM TransactionError WHERE appName LIKE '%svc-experiences%' SINCE 24 hours ago FACET error.message LIMIT 20"
```

**How to decide**: Check if the service has Datadog APM configured (most services are migrating). If Datadog returns data, use it. If not, fall back to NR CLI.

Present observability findings before hypotheses.

### Step 1.6: Service Chain & Terminology (before searching)

Before searching Slack, Confluence, or GitHub, identify the service chain and terminology:

1. **Read ecosystem maps** from the vault: `Runbooks/Experiences-Ecosystem.md` and `Runbooks/Luxury-Escapes-Ecosystem.md`
2. **Build service chain**: list ALL services involved in the data flow for this bug (e.g., `www-le-customer -> svc-promo -> svc-order -> svc-experiences`)
3. **Build terminology expansion**: the same concept has multiple names across services. Build a table of aliases BEFORE searching:

```
Example: "promo" = "promotion", "discount", "coupon", "promo code", "voucher"
Example: "LED" = "Lux Everyday", "svc-ee-offer", "Salesforce Connect"
Example: "complimentary" = "bundle" (used in Slack), "included experience"
```

Use ALL aliases in every Slack, Confluence, and GitHub search below.

### Step 1.7: Investigation Checklist

Present what was investigated before proceeding. A row is only "checked" if the minimum search depth was met.

```markdown
## Investigation Checklist

| Source                                              | Checked   | Findings                                       |
| --------------------------------------------------- | --------- | ---------------------------------------------- |
| Bug report (Jira/Slack)                             | [x] / [ ] | [summary]                                      |
| Datadog/NR: error rate                              | [x] / [ ] | [query + result]                               |
| Datadog/NR: traces/transactions                     | [x] / [ ] | [query + result]                               |
| Datadog/NR: monitors/incidents                      | [x] / [ ] | [active incidents or "none"]                   |
| Codebase: error path analysis                       | [x] / [ ] | [files examined]                               |
| Memory: known pitfalls                              | [x] / [ ] | [relevant entries or "none"]                   |
| Git history: recent changes                         | [x] / [ ] | [relevant commits or "none"]                   |
| Git blame: why the code was written this way        | [x] / [ ] | [key decisions or "standard pattern"]          |
| GitHub PR bodies: merged PRs that touched this area | [x] / [ ] | [PR links + key rationale from body or "none"] |
| Slack: team discussions about this flow             | [x] / [ ] | [decisions, edge cases found or "none"]        |
| Confluence: business rules, ADRs for this domain    | [x] / [ ] | [docs found or "none"]                         |
| Related bugs/PRs                                    | [x] / [ ] | [links or "none found"]                        |
```

### Search Depth Requirements

A checklist row is only "checked" when the minimum depth is met:

- **Slack**: minimum 3 keyword queries using ALL terminology aliases + read the primary service channel history. Use channel tiers from `investigation-case/SKILL.md` Phase 0.5 (Tier 1 always, Tier 2 when service chain crosses teams)
- **Confluence**: minimum 3 queries across Tier 1 spaces (PE, TEC, ENGX) + at least 1 full page read for every relevant result. See `investigation-case/SKILL.md` Phase 0.5 for full space tiers
- **GitHub PRs**: search with at least 2 keyword variations per repo in the service chain. Always read the PR body (not just the title)
- **Zero-result rule**: if a search returns 0 results, try a different alias or wording before marking as "none"

### Step 1.9: Ownership Determination

BEFORE generating hypotheses, determine if this bug belongs to the Experiences team. Read the full classification matrix from `Development/BUG/Bug-Triaging.md` in the vault for platform dimension, domain dimension, decision matrix, and svc-order context paths.

Key quick checks:
- Mobile-only bug -> Mobile team (NOT us), stop investigation
- `svc-order/src/context/accommodation/` -> Hotels team
- `svc-order/src/context/experience/` -> Experiences (OURS)

If the bug is NOT ours, present evidence and suggest routing. Then STOP investigation.

### Step 2: Generate 3-5 Hypotheses

Each must be specific, testable, falsifiable. Cover different root causes. Reference observability data when available.

### Step 3: Instrument Code

Add 3-8 targeted logs wrapped in `// #region debug-mode` / `// #endregion`.

**Browser-side:**

```typescript
// #region debug-mode
void fetch("http://127.0.0.1:7777", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    location: "File.tsx:42",
    message: "description",
    data: { vars },
    timestamp: Date.now(),
    runId: "initial",
    hypothesisId: "A",
  }),
}).catch(() => {});
// #endregion
```

**Server-side (Node):**

```typescript
// #region debug-mode
require("fs").appendFileSync(
  ".claude/debug.log",
  JSON.stringify({
    location: "file.ts:42",
    message: "description",
    data: { vars },
    timestamp: Date.now(),
    runId: "initial",
    hypothesisId: "A",
  }) + "\n",
);
// #endregion
```

Tell user to reproduce. Wait.

### Step 4: Analyze Logs

Read `.claude/debug.log`. Evaluate each hypothesis: CONFIRMED / REJECTED / INCONCLUSIVE.
If all rejected/inconclusive, **STOP and ASK the user** before generating new hypotheses. Present:
- Which hypotheses were tested and why each was rejected/inconclusive
- What the evidence suggests so far
- What new directions you're considering

Never silently pivot to a new round of hypotheses. The user must approve the new direction.

### Step 5: Fix

Only fix with CONFIRMED hypothesis + log proof. Change runId to `"post-fix"`.

### Step 5.5: Test Plan

After fixing, produce a concrete test plan BEFORE asking for verification:

```markdown
## Test Plan

| Category         | Test                                  | Expected Result        |
| ---------------- | ------------------------------------- | ---------------------- |
| **Reproduction** | [exact steps from bug report]         | [bug no longer occurs] |
| **Regression**   | [related flows that must still work]  | [unchanged behavior]   |
| **Edge cases**   | [boundary conditions the fix touches] | [correct handling]     |
| **Unit tests**   | [new/modified tests]                  | [all pass]             |
```

### Step 6: Verify

Delete log, ask user to reproduce again, compare before/after.

## Verification (MANDATORY before presenting fix)

- [ ] Root cause identified with evidence (not just a guess)
- [ ] At least 2 pieces of runtime evidence support the hypothesis (logs, traces, metrics, screenshots)
- [ ] Fix addresses root cause, not just symptom
- [ ] Reproduction steps documented
- [ ] Tests added/updated to cover the bug scenario
- [ ] No regression: existing tests still pass
- [ ] Service chain checked: fix doesn't break upstream/downstream
- [ ] /learn suggested if novel root cause discovered

### Step 7: Clean Up

Remove all `#region debug-mode` blocks. Delete `.claude/debug.log`. Kill server: `kill $(lsof -t -i :7777)`.

Summary: Bug -> Root Cause -> Fix -> Evidence.

After debug is complete, suggest next steps (invoke each via Skill tool, never raw commands):

```
Debug complete. Suggested next steps:
1. /learn, capture root cause as persistent learning
2. /deslop, clean any debug artifacts
3. /code-review, quality check (18 dimensions, branch mode)
4. /commit, commit with proper format
5. /create-pr, open PR with full template
```
