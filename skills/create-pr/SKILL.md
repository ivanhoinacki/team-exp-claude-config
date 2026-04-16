---
name: create-pr
model: haiku
description: Create a pull request with comprehensive technical format and monitor CI pipeline. Use when the user says "create pr", "open pr", "send the pr", "make the pr".
argument-hint: [ticket number, e.g. EXP-1234]
compatibility: Requires gh (GitHub CLI), git, circleci CLI (for CI monitoring)
allowed-tools: Bash(git *), Bash(gh *), Bash(jq *), Read, Write, Edit, Grep, Glob, Agent
---

# Create Pull Request

## References

| File | Content |
|------|---------|
| [references/pr-template.md](references/pr-template.md) | PR body template, content generation guide, diagram pipeline |
| [references/ci-monitor.md](references/ci-monitor.md) | Background CI agent: polling, auto-fix logic, escalation rules |
| [references/learnings.md](references/learnings.md) | Lessons from past PR sessions (review before each PR) |

## Working Directories

1. **Obsidian workspace** (docs, plans, features): `__VAULT_ROOT__`
2. **Codebase** (all LE services): `__CODEBASE_ROOT__`

## Pre-checks

1. Verify not on `main` or `prod`. If so, create a feature branch first.
2. Check for uncommitted work, commit first if needed.
3. **Verify Manual-E2E-Recipe exists (mandatory, blocks PR creation)**:
   ```bash
   VAULT="__VAULT_ROOT__"
   TICKET=$(git branch --show-current | grep -oE 'EXP-[0-9]+|BUG007-[0-9]+' | head -1)
   RECIPE=$(find "$VAULT/Development/Features" -maxdepth 3 -name "Manual-E2E-Recipe.md" -path "*${TICKET}*" 2>/dev/null | head -1)
   [ -n "$RECIPE" ] && echo "E2E Recipe: $RECIPE" || echo "WARN: No Manual-E2E-Recipe.md found for $TICKET"
   ```
   If missing: run `/test-scenarios` first (Phase 5 creates the recipe). Do NOT proceed without it.
   If the feature is docs-only or config-only (no testable behavior), skip with note "N/A: config-only change".
4. **Run CI checks locally (mandatory, blocks PR creation)**:
   If `/code-review` already ran CI checks in this session AND all passed, skip this step (checks already validated).
   Otherwise, run the shared CI check script:
   ```bash
   ~/.claude/scripts/ci-local-check.sh .
   ```
   This auto-detects `package.json` scripts and runs lint, types, build, and tests in order.

   If ANY check fails: fix the issue, commit the fix, then retry. Do NOT proceed to PR creation with failing checks.
4. Read the full diff: `GIT_EDITOR=true git diff main...HEAD`
5. Read all changed files completely (not just the diff) to understand context.
6. Prepend `GIT_EDITOR=true` to all git commands.

## Verification (MANDATORY before creating PR)

- [ ] **Manual-E2E-Recipe.md exists** in feature folder (or N/A for config-only)
- [ ] Local CI passed: lint, types, build, tests (in that order)
- [ ] Branch is up to date with base: `git log --oneline base..HEAD`
- [ ] No unintended files staged: `git diff --name-only base...HEAD`
- [ ] PR title follows `[TICKET] Description` format (no conventional commit prefix)
- [ ] PR description has Summary, Test Plan sections
- [ ] Diagram included if data flow or architecture changed
- [ ] No secrets, .env files, or credentials in the diff
- [ ] Commit messages follow repo convention

## PR Title Format

```
[TICKET-CODE] Short description
```

Examples:
- `[EXP-3563] Add instant confirmation badge and social proof pill`
- `[EXP-3559] Bugbash UI Refinements`

Rules:
- Ticket in square brackets FIRST, then description
- No conventional commit prefixes (feat, fix, chore) in the PR title
- No parentheses around ticket. Always `[EXP-XXXX]`, never `(EXP-XXXX)`
- No emojis in titles
- svc-search CI enforces regex: `^\[([A-Z]+-\d+|FIX|CHORE|REVERT|DOCS|FEAT|DEPS)\]\s[A-Za-z].+`
- Max 75 characters

## PR Body (MANDATORY structure, never skip sections)

The PR body MUST follow this exact structure. Every section is required unless marked optional. Do NOT use a simplified format, do NOT skip sections, do NOT produce a generic summary. This is the template, use it as-is:

```markdown
# Feature Name (TICKET-CODE)

> [One-line summary: what this PR does and the mechanism]

### RISKY OR NOT

**[No risk (score: 2) / Low risk (score: 2) / Medium risk (score: 3) / High risk (score: 4)]**: [1-line summary]

- **Migrations**: [none / yes: describe impact]
- **Env vars**: [none / yes: list new vars and environments]
- **API contract changes**: [none / yes: endpoints added/modified/removed]
- **Runtime impact on deploy**: [zero: explain why / yes: describe]
- **Destructive queries**: [none / only in manual scripts / yes: in runtime code]
- [Add any relevant mitigation: "additive-only changes", "pure functions with N tests", "manual script with --dry-run", "feature-flagged", etc.]

### Changes at a glance

- **[Area 1]**: [specific change with technical detail]
- **[Area 2]**: [what changed and why]
- **[Tests]**: [number of new/updated tests, what they cover]

---

## Why is this change happening?

**Problem: [One sentence stating the core problem.]**

[2-3 paragraphs: what exists today, why it's insufficient, what was investigated]

### Approach

[Brief description of the solution strategy]

---

## What changed?

### 1. [Area name, e.g. Config + Schema]

[Explain what was added/modified. Include REAL code snippets from the diff.]

### 2. [Area name, e.g. Database / Queries]

[Explain new queries with ACTUAL SQL from the code. Not pseudo-SQL.]

### 3. [Area name, e.g. Business Logic]

[Explain the flow. Include TypeScript snippets for key logic.]

### 4. [Area name, e.g. API / Controller] (if applicable)

[New endpoints, modified responses, schema changes]

### 5. [Area name, e.g. Infra / Pulumi] (if applicable)

[Table of env vars with values per environment]

---

## Architecture

[MANDATORY for business logic changes: at least 1 Mermaid sequence diagram.
SKIP this section entirely for config-only or script-only changes.
See diagram guidelines in references/pr-template.md]

---

## What have you done to test it?

| Category | Result | Details |
|----------|--------|---------|
| **Unit tests** | X suites, Y tests | [what's new/changed] |
| **Integration** | [status] | [what was validated] |
| **Manual/Staging** | [status] | [what was verified] |

---

## Evidences (optional)

[Screenshots, GIFs, CSV results, coverage tables, logs]

---

## Summary (product perspective)

[1 paragraph plain language: what this means for the user/business. No jargon. Written for a PM.]

---

## Related

| Link | Description |
|------|-------------|
| Jira: [TICKET](url) | Ticket |
| [Related PR](url) | Context |
```

### RISKY OR NOT generation rules (bot-scored, NEVER manually change labels)

The "Claude Risk Score: N" label is set by a bot that parses the PR body + diff. NEVER manually add/remove this label. To influence the score, write a detailed RISKY OR NOT section.

**What the bot weighs**: diff size, destructive SQL keywords (DELETE/UPDATE/DROP), migration presence, env var changes, API surface changes, and the explicit risk section content. A detailed mitigation section counterbalances a large diff.

**How to target score 2**:
1. Start with explicit assessment: `**No risk (score: 2)**:` or `**Low risk (score: 2)**:`
2. Use bullet points for EACH mitigation (not a single sentence)
3. Be specific: "no migrations" beats "low risk"
4. Call out what looks scary but isn't: e.g., "DELETE queries only exist in the manual cleanup script, not in runtime code"
5. Mention test coverage: "pure functions with 54 unit tests"
6. If script/manual-only changes: "never runs automatically, requires explicit invocation"

**When to score higher**:
- Score 3: new migrations, new env vars in staging/prod, API contract changes
- Score 4: breaking changes, data migration on large tables, multi-service deploy dependency

### Content generation rules

- Every claim must be traceable to actual code in the diff
- Group changes logically by area, not by file
- Include REAL code snippets (actual SQL, TypeScript, config from the diff, not pseudo-code)
- Generate Mermaid sequence diagrams for business logic changes (see [references/pr-template.md](references/pr-template.md) for diagram guidelines)
- Write the product summary LAST, after understanding all technical changes
- If a section doesn't apply, write "N/A" or skip it. Do NOT omit required sections without reason

## Execution

**CRITICAL: Execute `gh pr create` IMMEDIATELY after generating the body. Do NOT do anything else between body generation and PR creation. Compaction can happen at any time and will lose the generated body, wasting all the work. The sequence below is atomic: steps 2-5 must happen in rapid succession without interruption.**

1. Generate Mermaid diagrams (see [references/pr-template.md](references/pr-template.md), Diagram Guidelines section)
2. Push branch: `git push -u origin $(git branch --show-current)`
3. **Detect related PRs** (see Related PRs & Merge Order section below)
4. Build PR body with Mermaid code blocks (GitHub renders natively) AND create PR **as draft** in THE SAME Bash call: `gh pr create --draft --title "..." --body "$(cat <<'EOF' ... EOF)"`. Never split body generation and PR creation into separate steps.
5. Return the PR link in markdown so user can click it
6. **Launch CI Pipeline Monitor** (background agent, see [references/ci-monitor.md](references/ci-monitor.md))

**Anti-pattern**: generating the full PR body in one message, then creating the PR in the next message. If compaction happens between them, the body is lost and must be regenerated.

**IMPORTANT**: PRs are ALWAYS created as draft. The user promotes to "ready for review" manually after validation.

## Related PRs & Merge Order (MANDATORY check before PR creation)

Before creating the PR, check for related open PRs that form a merge chain. Related PRs share the same ticket, epic, or service dependency.

### Detection

```bash
TICKET="EXP-XXXX"  # extracted from branch name or arguments

# 1. Same ticket: other PRs for this ticket across all repos
gh search prs "$TICKET" --owner lux-group --state open --json repository,number,title,url,headRefName --limit 10

# 2. Same epic/parent: if this ticket is a subtask, search the parent ticket too
# Extract parent from Jira if available (e.g., EXP-3536 is parent of EXP-3538/3539/3540)
gh search prs "$PARENT_TICKET" --owner lux-group --state open --json repository,number,title,url,headRefName --limit 10

# 3. Same service chain: check if other PRs touch the same service with related branches
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [[ -z "$REPO" ]]; then
  REPO=$(git remote get-url origin 2>/dev/null \
    | sed -E 's#git@github\.com:##; s#https?://github\.com/##; s#\.git$##')
fi
gh pr list --repo "$REPO" --state open --json number,title,url,headRefName --limit 10
```

### Merge Order Definition

When related PRs are found, determine the correct merge order based on dependency direction:

| Dependency type | Merge first | Merge second |
|---|---|---|
| DB migration that other PRs depend on | Migration PR | Consumer PRs |
| Shared lib/type changes | Lib PR | Service PRs that import it |
| API contract (provider -> consumer) | Provider PR (new endpoint) | Consumer PR (calls endpoint) |
| Independent (no dependency) | Any order | Any order |

### PR Body Integration

If related PRs exist, add a **Merge Order** section at the end of the PR body (before Related table):

```markdown
---

## Merge Order

This PR is part of a multi-PR feature. Merge in this order:

| Order | PR | Repo | Reason |
|-------|-----|------|--------|
| 1 | #1758 - DB migration for attractions | svc-experiences | Schema must exist first |
| 2 | **#1760 - This PR** | svc-experiences | Depends on migration |
| 3 | #42 - Admin UI for attractions | www-ee-admin | Depends on API from #1760 |

**Status:** PR #1758 merged. This PR is next.
```

If NO related PRs are found, skip the Merge Order section entirely.

### Rules

- Always search by ticket AND parent ticket (if subtask)
- Include PRs from ALL repos, not just the current one
- Update the Merge Order status when posting (which are already merged, which are pending)
- If merge order creates a blocker (e.g., PR #1 not yet approved), warn in the PR body

## PR Review Notification (MANDATORY after PR creation)

After the PR is created, identify which team owns the repo and notify the correct Slack channel asking for review. If the repo is owned by our vertical, no notification needed (we review internally).

### Service-to-Channel Mapping

| Repo / Service | Owning Team | Slack Channel to Notify |
|---|---|---|
| svc-order, lib-refunds | Customer Payments | `#team-customer-payments` |
| svc-payment, svc-vcc | Customer Payments | `#team-customer-payments` |
| svc-cart | CRO | `#team-cro` |
| svc-search, svc-geo | Search | `#team-search` |
| svc-auth, svc-verification, svc-discovery | EngX | `#team-engx` |
| svc-accommodation, svc-reservation, svc-bedbank | Hotels | `#team-hotels` |
| svc-tour, svc-connection-ttc | Tours | `#team-tours` |
| svc-cruise | Cruises | `#team-cruises` |
| www-le-admin, svc-offer, svc-support | OpEx | `#team-op-ex` |
| svc-membership, svc-lux-loyalty | LuxPlus | `#team-luxplus` |
| svc-flights, svc-flights-* | Flights | `#team-flights` |
| svc-trip | Trip Planner | `#team-trip-planner` |
| svc-reporting | Data Platforms | `#team-data` |
| www-le-customer | CRO (shared) | `#team-cro` |
| svc-promo, svc-content, svc-sailthru | Marketing | `#team-marketing` |
| svc-agent, www-le-agent | Wholesale | `#team-agent-hub` |
| svc-business, www-le-business | LE Business | `#team-business` |

### Our vertical (no external notification needed)

| Repo / Service | Team |
|---|---|
| svc-experiences, svc-ee-offer, svc-car-hire, svc-addons, svc-tag, svc-occasions, svc-fx | Experiences + WL + Car Hire |
| www-ee-admin, www-ee-customer, www-ee-vendor | Experiences + WL + Car Hire |
| svc-traveller, svc-notification-proxy | Experiences + WL + Car Hire |

### Notification flow

1. After PR is created, check the repo name against the table above
2. If it's an **external team's repo**: draft a Slack message to the owning team's channel with the PR link, asking for review. Present for user approval before sending
3. If it's **our vertical's repo**: skip notification (we handle internally)
4. If the repo is not in the table: ask the user which channel to notify

### Message format (external team PRs)

```
Hey team, I've opened a PR on {repo} that touches {brief area description}.
PR: {link}
Would appreciate a review when you get a chance. :cool-doge:
```

Keep it short, casual, and contextual. Follow the Slack tone rules from `00-global-style.md`.

---

## CI Pipeline Monitor

After PR creation, a background agent monitors CircleCI checks, polls every 90s (max 20 min), and auto-fixes lint/type/test/build failures (max 2 attempts per check). Non-fixable or pre-existing failures are escalated to the user.

Full agent prompt and rules: [references/ci-monitor.md](references/ci-monitor.md)

## Feature Folder Status Update (MANDATORY after PR creation)

After the PR is created, update the feature folder status in the vault to REVIEW. Search BOTH top-level folders AND subfolders (subtasks inside parent features).

```bash
FEATURES_DIR="__VAULT_ROOT__/Development/Features"
TICKET="EXP-XXXX"  # extracted from branch name or arguments

# 1. Search top-level (e.g., EXP-3544 - TODO)
OLD=$(find "$FEATURES_DIR" -maxdepth 1 -type d -name "${TICKET}*" | head -1)
if [ -n "$OLD" ]; then
  NEW_NAME=$(echo "$OLD" | sed 's/- [A-Z_]*$/- REVIEW/' | sed "s/${TICKET}\$/${TICKET} - REVIEW/")
  [ "$OLD" != "$NEW_NAME" ] && mv "$OLD" "$NEW_NAME"
fi

# 2. Search subfolders (e.g., EXP-3536 - REVIEW/EXP-3537 - WIP)
SUB=$(find "$FEATURES_DIR" -mindepth 2 -maxdepth 2 -type d -name "${TICKET}*" | head -1)
if [ -n "$SUB" ]; then
  NEW_SUB=$(echo "$SUB" | sed 's/- [A-Z_]*$/- REVIEW/' | sed "s/${TICKET}\$/${TICKET} - REVIEW/")
  [ "$SUB" != "$NEW_SUB" ] && mv "$SUB" "$NEW_SUB"
fi
```

This handles both:
- **Top-level features**: `EXP-3544 - TODO` -> `EXP-3544 - REVIEW`
- **Subtasks inside parent**: `EXP-3536 - REVIEW/EXP-3537 - WIP` -> `EXP-3536 - REVIEW/EXP-3537 - REVIEW`

If the folder doesn't exist at either level, skip silently.

Status lifecycle: `PLANNING` / `TODO` -> `WIP` / `IN_PROGRESS` -> `REVIEW` -> `DONE`

## Worktree Cleanup Reminder

After the PR is created and CI passes, remind the user about worktree cleanup if the current session is running inside a worktree (detected by path pattern `{repo}--{ticket}/`):

```
Worktree cleanup (after PR is merged):
  cd __CODEBASE_ROOT__/{main-repo}
  git worktree remove ../{repo}--{ticket}
```

Do NOT auto-remove the worktree. The user decides when to clean up (usually after merge). Just include the reminder with the exact command.

## Common Agent Mistakes

1. **Skipping local CI**: Creating PR without running lint, types, and tests locally first. Why: the CI monitor catches failures but local checks are faster and cheaper. A PR that fails CI on first push looks sloppy to reviewers.
2. **PR too large**: Not suggesting to split when diff is > 500 lines across many files. Why: large PRs get worse reviews (reviewers skim instead of reading) and slower approvals. Studies show review quality drops sharply after ~400 lines.
3. **Missing Jira link**: Not including the ticket reference in PR title or body. Why: unlinked PRs don't appear in Jira's development panel, breaking traceability for PMs and audits.
4. **Diagram without context**: Generating a diagram that shows the full system when only a small part changed. Why: diagrams should focus on what changed, not the whole architecture. A 20-service diagram for a 1-endpoint change is noise.
5. **Force pushing after review**: If the PR already has review comments, creating new commits instead of amending preserves review context. Why: force push orphans inline comments, making it impossible for reviewers to verify their feedback was addressed.
6. **Not checking base branch**: Assuming main/master without verifying. Why: some repos use develop or release branches. PRing to the wrong base creates merge conflicts or deploys changes prematurely.
7. **Manually changing risk labels**: NEVER add/remove "Claude Risk Score: N" labels via `gh api`. The bot owns these labels and must re-evaluate by itself. To influence the score, update the RISKY OR NOT section in the PR body with explicit mitigations.
8. **Vague RISKY OR NOT section**: Writing a single-line risk assessment like "Low risk: no breaking changes" when the diff is large. The bot needs explicit bullet-point mitigations to counterbalance diff size and destructive SQL keywords. A 690-line diff with DELETE queries scored risk 3 until mitigations were expanded.

## Rules

- Every claim in the PR must be traceable to actual code in the diff
- Never write generic descriptions, be specific (file names, function names, line numbers)
- If env vars were added, show the full config chain (schema -> config -> env-variables -> Pulumi)
- If queries were added, include the actual SQL
- Code snippets should be the real code, not pseudo-code
- Diagrams should reflect the actual architecture, not a generic pattern
- Review [references/learnings.md](references/learnings.md) before starting a new PR
