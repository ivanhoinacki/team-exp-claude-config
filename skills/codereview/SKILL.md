---
name: codereview
description: Review code quality with all 18 dimensions. Analyzes diff, gathers deep context, checks Known Gotchas, presents findings grouped by severity. If a PR exists, posts inline comments on GitHub. Use when the user says "code review", "review this PR", "review PR", "review", "pre-review", "check quality", or before opening a PR.
argument-hint:
  [PR URL, PR number, ticket ID (EXP-XXXX), or repo name. If omitted, reviews current branch diff against main]
compatibility: Requires git, gh (GitHub CLI), mcp-atlassian (Jira/Confluence), Slack MCP
model: sonnet
allowed-tools: Bash(git *), Bash(gh *), Read, Grep, Glob, Agent, mcp__claude_ai_Slack__slack_search_public_and_private, mcp__claude_ai_Slack__slack_read_channel, mcp__claude_ai_Slack__slack_read_thread, mcp__mcp-atlassian__confluence_search, mcp__mcp-atlassian__confluence_get_page
---

# Code Review, Full Spectrum

## Working Directories

1. **Obsidian workspace** (docs, plans, features): `__VAULT_ROOT__`
2. **Codebase** (all LE services): `__CODEBASE_ROOT__`

## References

| File | Content |
|------|---------|
| [`references/dimension-details.md`](references/dimension-details.md) | Full 18-dimension definitions with tier/severity for each |
| [`references/known-gotchas.md`](references/known-gotchas.md) | Recurring bug patterns to check against every diff |
| [`references/learnings.md`](references/learnings.md) | Lessons from past reviews (grows over time) |

## Mode Detection

**PR mode** (argument is a PR URL, number, or ticket with open PR): Review a pull request with inline GitHub comments.
**Branch mode** (no argument, no open PR, or merged/closed PR): Self-review current branch diff against main. Includes local CI checks.

## Quick Reference Flow

```
Step 0:    Detect PR and review mode
Step 0.5:  CI checks (BRANCH MODE ONLY)
Step 1:    Get the diff (detect PR vs branch)
Step 1.5:  Diff triage (classify files, assess risk) → PRESENT triage summary
Step 2:    Context gathering (intent + full code read + deep search)
  2.1  Understand intent (PR body / git log / vault feature doc)
  2.2  Read code (full files + callers + tests)
  2.3  Deep context (vault RAG + git history + PR history + Slack + Confluence)
  2.4  Previous review round (PR mode: inline comments + review verdicts)
  GATE: Context self-check → PRESENT checklist (all items must be [x])
Step 3:    Analyze ALL 18 dimensions + read known-gotchas.md + feature flag + dep analysis + D6 test checklist
  → PRESENT "Known gotchas checked" section (mandatory, even if all N/A)
  → PRESENT "D6 test checklist" results (if test files in diff)
Step 4:    Draft comments (human tone, no labels, max 2 sentences, actionable)
  → PRESENT Verification checklist with [x] marks (mandatory, not prose)
Step 5:    Present findings for approval (STOP and WAIT)
Step 6:    Post comments (PR mode only)
Step 7:    Approve or request changes (PR mode only)
Step 8:    Summary + workflow compliance
Step 9:    Save learnings
Step 10:   Export for other instance
```

## Common Agent Mistakes

These mistakes have been observed in past reviews and led to false positives, noise, or missed real bugs. Check each one explicitly.

1. **Style policing**: Reporting indentation, formatting, or naming preferences as issues. Only flag style when it causes a bug or violates an explicit project pattern. Why: style noise drowns out real findings and erodes reviewer trust. The user has explicitly rejected style-only comments.
2. **Reviewing generated code**: Analyzing auto-generated files (contract types, OpenAPI specs, migration snapshots). Check if the file is in a generated/ directory or has a "do not edit" header. Why: findings on generated code are not actionable since the source generator owns the output.
3. **Missing cross-file impact**: Finding an issue in file A but not checking if the same pattern exists in files B, C, D. Always grep for the pattern across the full changeset. Why: a bug in one mapper often means the same bug was copy-pasted to siblings.
4. **False positive on existing patterns**: Flagging code that follows the established repo pattern as a "bug". Before reporting, check 2-3 nearby files for the same pattern. Why: flagging intentional patterns wastes the author's time and signals the reviewer doesn't understand the codebase.
5. **Ignoring test coverage**: Reviewing implementation without checking if new paths have test coverage. Why: untested code is the #1 source of regressions. Finding the missing test is often more valuable than any code comment.
6. **Severity inflation**: Marking medium issues as CRITICAL. Reserve CRITICAL/BUG for actual correctness or security issues that would cause production incidents. Why: severity inflation causes the author to ignore all comments equally.
7. **Skipping codebase pattern check**: Not grepping for existing enums, utils, or helpers before flagging hardcoded values or new abstractions. Why: suggesting "extract this to a constant" when the constant already exists in another file is embarrassing and unhelpful.

---

## Step 0: Detect PR and review mode

**Detect PR number, state, and repo** from the user's input or current branch:
```bash
PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || echo "")
PR_STATE=$(gh pr view --json state -q .state 2>/dev/null || echo "")
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
REPO_NAME=$(basename "$(pwd)")
```

**CRITICAL**: Only use the PR if `PR_STATE == "OPEN"`. If merged or closed, treat as no PR (local branch diff).

Inform the user which mode will be used:
- **PR mode**: reviewing the open PR diff
- **Branch mode**: reviewing local branch changes vs main

---

## Step 0.5: Run CI checks locally (BRANCH MODE ONLY)

Skip this step in PR mode (CI already runs on the PR).

Before reviewing code quality, ensure the code compiles and passes tests.

Run the shared CI check script:
```bash
~/.claude/scripts/ci-local-check.sh .
```
This auto-detects `package.json` scripts and runs lint, types, build, and tests in order.

If ANY check fails: **STOP the review**. Report the failures as CRITICAL findings and fix them first. Do not proceed to the 18 dimensions with failing CI.

---

## Step 1: Get the diff

Parse `$ARGUMENTS` and detect the review target:

1. **PR URL** (e.g. `https://github.com/lux-group/svc-sailthru/pull/3020`): extract repo + PR number
2. **PR number** (e.g. `3020`): use current repo
3. **Ticket ID** (e.g. `EXP-3572`): search worktrees across `~/Documents/LuxuryEscapes/` for a matching worktree, `cd` into it. Then check for open PR, otherwise use local branch diff
4. **Repo or worktree name** (e.g. `svc-sailthru--exp3572` or `svc-sailthru`): `cd` into `~/Documents/LuxuryEscapes/<name>`. Then check for open PR, otherwise use local branch diff
5. **No argument**: use current directory. Check for open PR: `gh pr view --json number,url 2>/dev/null`

For cases 3-5, if no PR is found OR the PR is not OPEN, use local branch diff (`git diff main...HEAD`).

**CRITICAL: Check PR state before using it.** A merged/closed PR is NOT the review target. The local branch may have new commits on top.

```bash
# Check PR state (MUST be OPEN to use as review target)
PR_STATE=$(gh pr view --json state -q .state 2>/dev/null || echo "")
```

- `PR_STATE == "OPEN"` → use the PR diff
- `PR_STATE == "MERGED"` or `"CLOSED"` or empty → **ignore the PR**, use local branch diff
- If the PR is merged but the branch has new local commits: those commits are what needs review, not the old PR

Once the target directory and PR status are resolved, get the diff:

If an OPEN PR exists:
   ```bash
   gh pr view <NUMBER> --repo <REPO> --json title,body,headRefName,baseRefName,author
   gh pr diff <NUMBER> --repo <REPO>
   gh pr diff <NUMBER> --repo <REPO> --name-only
   ```
If no OPEN PR (merged, closed, or none):
   ```bash
   GIT_EDITOR=true git diff main...HEAD --name-only
   GIT_EDITOR=true git diff main...HEAD
   ```

### PR edge cases

| Situation | Behavior |
|-----------|----------|
| **Draft PR** | Review normally but note "PR is draft" in summary. Do NOT approve/request-changes (Step 7) on drafts |
| **Force-pushed PR** | Re-fetch diff after force-push. Previous review comments may reference stale lines. Note in Step 2.4 |
| **PR with no code diff** (metadata-only) | Skip review. Report: "No code changes to review" |
| **PR touching git submodules** | Skip submodule changes. Note in summary: "Submodule changes not reviewed" |
| **PR across forks** | Use full repo path in all gh commands. Verify base branch is correct |

Store whether a PR was found (used in Steps 6-7 for posting comments).

## Step 1.5: Diff Triage (MANDATORY, classify before deep-diving)

**NEVER skip this step.** Before reading every file in detail, classify the changed files to focus review energy on what matters. Present the triage summary to show it was done.

### File classification

```bash
# Get changed files
FILES=$(gh pr diff <NUMBER> --repo <REPO> --name-only 2>/dev/null || git diff main...HEAD --name-only)
```

Classify each file into one of these categories:

| Category | Examples | Action |
|----------|---------|--------|
| **Skip** | `yarn.lock`, `package-lock.json`, `*.snap`, `generated/`, `__generated__/`, files with "do not edit" header | Do not review. Mention in summary: "X files skipped (lock/generated)" |
| **Scan** | Type definitions (`.d.ts`), config files (`.json`, `.yml`), pure rename/move | Quick scan for correctness, no deep analysis |
| **Review** | Source code, tests, migrations, API routes, handlers, services, models | Full 18-dimension analysis |

### Priority order for Review files

1. **Handlers / Routes / Controllers** (entry points, highest bug surface)
2. **Services / Business logic** (where correctness and financial integrity live)
3. **Database layer** (queries, migrations, models)
4. **Tests** (verify coverage matches implementation changes)
5. **Shared utils / types** (cross-file impact)

### Diff size awareness

| Diff size | Behavior |
|-----------|----------|
| Small (<100 lines of actual code) | Full depth on everything |
| Medium (100-500 lines) | Full depth on Review files, scan-only for Scan files |
| Large (>500 lines) | Flag "this PR is large, consider splitting". Still review fully, but note in the verdict that size increases risk |

### Risk classification (modulates context depth in Step 2.3)

Based on the diff triage, classify the overall change risk:

| Risk | Criteria | Context depth |
|------|----------|---------------|
| **LOW** | Rename, typo fix, config-only, docs-only, test-only | Step 2.3: git history only. Skip Slack/Confluence. Vault RAG optional |
| **MEDIUM** | Logic change, new function, refactor, UI change | Step 2.3: full (vault RAG + git + PR history + Slack + Confluence) |
| **HIGH** | New endpoint, cross-service, financial logic, auth change, DB migration | Step 2.3: full + extra diligence (search ALL repos in service chain, read related Confluence ADRs) |

**You MUST present the triage before proceeding.** Use this format:

```
Diff triage:
- Review (X files): handler.ts, service.ts, migration.ts, ...
- Scan (X files): types.d.ts, config.json, ...
- Skip (X files): yarn.lock, generated/...
- Diff size: small/medium/large (~N lines of code)
- Risk: LOW/MEDIUM/HIGH
```

Proceed to Step 2 with the prioritized file list and risk level.

## Step 2: Understand the context (mandatory, never skip)

Every sub-step below is mandatory. Execute them all in order before forming any opinion about the code. Do not skip to analysis early, even if the change looks simple. Why: premature analysis without context leads to false positives (flagging intentional patterns) and false negatives (missing business rule violations). Past reviews that skipped context had 3-4x more rejected comments.

### 2.1 Understand the intent

- If PR exists: read the PR body thoroughly. This is the PRIMARY source of context.
- Read the git log: `git log main..HEAD --oneline` (if local branch available; for remote-only PRs use the PR commits list)
- **Search vault for feature doc**: `query_vault(query="<TICKET_ID> implementation plan", type_filter=["session-memory"])` and search `Development/Features/` for a folder matching the ticket. If a feature plan or implementation plan exists, read it. This reveals design decisions the PR body may omit.

### 2.2 Read the code

1. **Read every changed file completely** (not just the diff lines) to understand surrounding code, business rules, existing patterns, and why things are the way they are
2. **Check related files** - if a function is modified, read its callers and callees
3. **Check tests** - read existing tests for the changed code to understand expected behavior

### 2.3 Deep context gathering (MANDATORY, never skip)

Investigate the history behind the implementation. This is NOT optional, even for "simple" changes. **Skipping sub-steps here is the #1 cause of false positives and missed business rule violations in past reviews.**

**Pre-search**: If the diff touches multiple services or a cross-cutting concern, quickly identify the service chain and terminology aliases before searching. The same concept often has different names across services (e.g., "complimentary" vs "bundle", "LED" vs "svc-ee-offer"). Use ALL aliases in searches below.

**Risk-based depth** (from Step 1.5 triage):
- **LOW risk**: sub-steps 1 and 2 mandatory. Sub-steps 3-5 optional.
- **MEDIUM risk**: ALL sub-steps mandatory.
- **HIGH risk**: ALL sub-steps mandatory + extra diligence (search ALL repos in service chain, read related Confluence ADRs).

1. **LE Vault RAG (MCP `local-le-chromadb`), FIRST**, Run `query_vault` with PR title/body keywords, ticket id, domain terms, and **`service_filter`** matching the repo (e.g. `svc-experiences`). Use `list_vault_sources` if filters are unclear. Pull review learnings, business-rule reminders, and pitfalls relevant to the change **before** GitHub/Slack/Confluence. If MCP is unavailable, note it and continue.

2. **Git history** - check why the code around the change exists. Run for EACH key changed file (not just one):
   ```bash
   git log --oneline -10 -- <file_path>
   ```
   If local clone doesn't have the branch, use `gh api` to get commit history:
   ```bash
   gh api repos/<REPO>/commits?path=<file_path>&sha=<branch>&per_page=5 --jq '.[].commit.message'
   ```

3. **GitHub PR history** - find previous PRs that touched the same area and **always read their body**:
   ```bash
   gh pr list --repo <REPO> --search "<keyword>" --state merged --limit 5
   gh pr view <NUMBER> --repo <REPO> --json body,title
   ```
   **Minimum**: 2 keyword variations per repo. Search ALL repos in the service chain if cross-service.

4. **Slack conversations** - search for the ticket number, feature name, or domain term using ALL terminology aliases. Use channel tiers from `investigation-case/SKILL.md` Phase 0.5:
   - Tier 1 (always): `#team-experiences-pt-br`, `#svc-experiences`, `#007-exp`
   - Tier 2 (when crossing teams): `#team-customer-payments`, `#team-bundles`, relevant service channels
   **Minimum**: 2 keyword queries using aliases. Read full threads for relevant results.

5. **Confluence docs** - search for ADRs, RFCs, or business rules across multiple spaces. Use tiered space list from `investigation-case/SKILL.md` Phase 0.5:
   - Tier 1 (always): PE, TEC, ENGX
   - Tier 2 (when feature crosses teams): OE, HOT, WHI, LOYAL, TOUR
   **Minimum**: 2 queries across Tier 1 spaces. Read full pages for relevant results.

6. **Zero-result rule** - if any search returns 0 results, try a different alias or wording before concluding "nothing found".

### 2.4 Previous review round awareness (PR MODE ONLY)

Before analyzing, check if the PR already has review comments from previous rounds or other reviewers. **Both commands below are mandatory.** Inline comments reveal specific code concerns; review-level comments reveal the overall verdict and whether changes were requested.

```bash
# Get existing INLINE review comments (on specific lines)
gh api repos/<REPO>/pulls/<NUMBER>/comments --jq '.[] | {id, user: .user.login, path, line, body: .body[:120], created_at}'

# Get REVIEW-LEVEL comments (approve/request-changes verdicts)
gh api repos/<REPO>/pulls/<NUMBER>/reviews --jq '.[] | {id, user: .user.login, state, body: .body[:120]}'
```

**Rules:**
- **Do not re-flag resolved items.** If a previous comment pointed out an issue and the code was updated since, skip it
- **Do not duplicate.** If another reviewer already flagged the same issue, do not post a new inline comment. At most, reply in their thread agreeing
- **Acknowledge addressed feedback.** If previous round requested changes and they were addressed, note it in the summary: "Previous review comments addressed: X/Y"
- **Build on prior context.** If a previous reviewer asked a question that's still unanswered, flag it as context in your review

Only after completing ALL sub-steps (2.1, 2.2, 2.3, 2.4) should you proceed to analysis. If a pattern was an intentional decision (documented in a PR body, Slack thread, or Confluence page), do NOT comment on it.

### Context self-check (MANDATORY gate before Step 3)

Before proceeding to analysis, internally verify and present this checklist. If any REQUIRED item is not done, go back and do it. Do NOT proceed with incomplete context.

```
Context gathering:
  [x] 2.1 PR body / git log read
  [x] 2.1 Vault feature doc search (ticket ID)
  [x] 2.2 All changed files read completely
  [x] 2.2 Callers/callees checked
  [x] 2.2 Existing tests read
  [x] 2.3.1 Vault RAG (query_vault with service_filter)
  [x] 2.3.2 Git history per key file
  [x] 2.3.3 GitHub PR history (2+ keyword searches)    ← MEDIUM/HIGH risk only
  [x] 2.3.4 Slack search (2+ queries with aliases)     ← MEDIUM/HIGH risk only
  [x] 2.3.5 Confluence search (2+ queries, Tier 1)     ← MEDIUM/HIGH risk only
  [x] 2.4 Previous review comments + reviews fetched   ← PR mode only
  Risk level: LOW/MEDIUM/HIGH (from Step 1.5)
```

**If risk is MEDIUM or HIGH and sub-steps 3-5 of 2.3 show [ ], STOP and execute them.** "Vault RAG was enough" is NOT a valid reason to skip Slack/Confluence/PR history. Each source surfaces different context (vault = patterns/pitfalls, Slack = decisions/discussions, Confluence = ADRs/business rules, PR history = why code exists).

## Step 3: Analyze with ALL 18 dimensions (mandatory checklist)

You MUST evaluate every changed function/module against ALL 18 dimensions. No dimension may be skipped. After analysis, internally mark each dimension as CLEAN or list findings. Report ALL actionable findings, organized by severity tier.

### Dimension Summary

| # | Dimension | Tier | Key checks |
|---|-----------|------|------------|
| D1 | Correctness | Critical | Logic bugs, null handling, feature flags, edge cases |
| D2 | Security | Critical | Injection, secrets, auth, input validation |
| D3 | Performance | Critical | N+1, indexes, event loop, memory |
| D4 | Error Handling | Critical | Swallowed errors, cleanup, timeouts, retry |
| D5 | SOLID / Clean Code | High | SRP, DIP, dead code, naming |
| D6 | Testing | High | Coverage, mock signatures, edge cases |
| D7 | Codebase Consistency | High | Repo patterns, existing utils, naming, ENUM REUSE |
| D8 | Architecture | High | Layer violations, circular deps, boundaries |
| D9 | Operational Readiness | Medium | Logs, metrics, tracing, health checks |
| D10 | Concurrency | Medium | Race conditions, idempotency, locks |
| D11 | Documentation | Medium | JSDoc, README, ADR |
| D12 | Dependencies | Medium | Pinned versions, licenses, vulnerabilities |
| D13 | Cross-Service Contract | Critical | Same field interpreted by producer and consumer, IDs stable in chain, enum values synced, SNS/SQS ARNs confirmed |
| D14 | Idempotency & State Recovery | High | Retry/re-run safety, double refund possible, sync wipes manual data, ticket consumed 2x |
| D15 | Financial Calculation Integrity | Critical | FX rounding accumulation, denominator includes all items, same promoAmount everywhere, vendor holdback correct |
| D16 | Data Visibility & Context | High | Admin queries don't over-filter, public endpoints don't leak inactive, reports join source for current state |
| D17 | Runtime Configuration Coupling | Medium | Query parser configured explicitly, currency default declared, DD_TRACE correct for ORM, feature flag rollback via env var |
| D18 | External System Trust | Medium | Provider returns semantically wrong data, test transactions triggering alerts, failure attribution (our code vs supplier config) |

> Full tier/severity details for each dimension: [`references/dimension-details.md`](references/dimension-details.md)

### Known Gotchas (MANDATORY, read the file)

**You MUST read [`references/known-gotchas.md`](references/known-gotchas.md) during every review.** Do not rely on memory of past reviews. The file is updated after each review (Step 9) and may contain new entries since the last time you read it. Scan each section header against the diff:
- Does the diff touch input parsing? Check "Input Parsing Traps"
- Does the diff touch cross-service data? Check "Cross-Service Consistency"
- Does the diff touch queries/DB? Check "Query Layer Pitfalls"
- Does the diff touch financial calculations? Check "Financial Calculation"
- Does the diff touch feature flags? Check "Feature Flags"
- Does the diff touch dependencies? Check "Dependency Changes"

If a gotcha pattern matches the diff, verify the code handles it correctly. If it doesn't, add a finding.

**You MUST present a "Known gotchas" section in the output** (between context gathering and findings) showing which sections matched and the result. Format:

```
Known gotchas checked:
- Input Parsing Traps: matched (new qs.stringify with array params) → verified, finding #3
- Cross-Service Consistency: matched (new filter params to BFF) → verified, finding #1
- Feature Flags: matched (Optimizely flag) → verified, both paths work
- Query Layer Pitfalls: not applicable
- Financial Calculation: not applicable
- Dependency Changes: not applicable
```

This section is mandatory even if all results are "not applicable". It proves the file was read and cross-referenced.

### Dependency Change Analysis (when package.json or similar changes)

If the diff includes changes to `package.json`, `yarn.lock`, or dependency config:

1. **Identify what changed**: compare old vs new `package.json` deps. Focus on direct dependencies, not transitive
2. **Major version bumps**: flag as Suggestion. Major versions often have breaking changes. Check the changelog/migration guide
3. **New dependencies**: check if the package is actively maintained (last publish date, open issues). Check for known vulnerabilities via `npm audit` or `yarn audit`
4. **Removed dependencies**: verify no remaining imports reference the removed package
5. **Security advisories**: for any changed dep, check if the target version has known CVEs. `gh api /advisories?ecosystem=npm&package=<name>` or npm advisory database

If deps changed but no code changed: the PR is a dependency-only update. Still check for breaking changes in changelogs, but skip most other dimensions.

### When reviewing test files (D6 concrete checklist, MANDATORY when test files in diff)

**If the diff triage (Step 1.5) classified ANY `.test.ts`, `.spec.ts`, or `__tests__/` file as Review or Scan, you MUST apply this checklist.** "I checked the tests" without referencing these items is not sufficient. For each test file in the diff, check:

1. **Mock fidelity**: Do mocks reflect the real contract? `jest.fn().mockReturnValue({...})` with a shape that doesn't match the real function signature hides bugs. Compare mock shape with actual function return type
2. **Assertion specificity**: `expect(result).toBeDefined()` passes for wrong values. Use `toEqual`, `toMatchObject`, or `toStrictEqual` with concrete expected values
3. **Edge case coverage**: Does test data cover the domain edge cases? Empty arrays, null fields, zero values (0 is falsy), multi-currency, multi-item orders
4. **Both flag states**: If code is behind a feature flag, tests should cover both ON and OFF paths
5. **Context mocking pattern**: LE pattern is header-based auth mock (`x-test-user-id`, `x-test-roles`) after lib-auth-middleware v3. Flag `_currentValue` or other React internals. Query vault for the repo's test patterns if unsure
6. **Test isolation**: Tests that depend on execution order or shared mutable state are flaky. Each test should set up its own state

**You MUST present a "D6 test checklist" section in the output** (after the Known gotchas section) when test files are in the diff. Format:

```
D6 test checklist (N test files in diff):
- ExperienceSearchCategoryFilters.test.ts:
  1. Mock fidelity: OK (no external mocks, pure function test)
  2. Assertion specificity: OK (uses toEqual with concrete arrays)
  3. Edge case coverage: FINDING → empty categories array not tested
  4. Both flag states: N/A (no feature flag in tested code)
  5. Context mocking pattern: N/A (no auth/context)
  6. Test isolation: OK (each test has own input)
```

If all items are OK/N/A, still present the section. It proves the checklist was applied, not just "I looked at the tests".

### Feature Flag Completeness (when diff touches feature flags)

If the diff introduces or modifies feature flag checks (e.g., `isFeatureEnabled`, `getFeatureFlag`, `featureToggle`, `config.features`):

1. **Both paths work**: verify the code handles both flag ON and flag OFF correctly. A common bug is the OFF path returning undefined or throwing
2. **No orphan code**: if the flag wraps a new feature, check that the old code path still works when the flag is OFF. The PR should not break the existing behavior
3. **Flag cleanup path**: if this is a temporary flag (rollout), check if there's a plan or ticket to remove it. Permanent flags without cleanup accumulate tech debt
4. **Default value**: verify what happens if the flag service is unreachable. The default should be the safe/old behavior, not the new feature
5. **Test coverage for both paths**: tests should cover both flag ON and flag OFF scenarios

### Frontend Layout Validation (when diff touches CSS/HTML/styled-components)

**Trigger**: If the diff triage (Step 1.5) classified ANY file as Review or Scan that matches these patterns: `*.css`, `*.scss`, `*.styled.ts`, `styled(`, `css\``, `.tsx` with JSX layout changes, LuxKit component modifications, MUI `sx` prop changes, or responsive breakpoint changes.

**This is a visual correctness check (D1 + D7), not a style preference check.** Only flag issues where the visual output is wrong, broken, or inconsistent with existing patterns.

When triggered, use the frontend layout MCP tools:

1. **Playwright MCP** (screenshots at multiple viewports):
   ```
   browser_navigate → localhost URL of the changed page/component
   browser_take_screenshot at 3 viewports:
     - mobile: browser_resize(375, 812) → screenshot
     - tablet: browser_resize(768, 1024) → screenshot
     - desktop: browser_resize(1440, 900) → screenshot
   ```

2. **chrome-devtools MCP** (CSS inspection on elements the diff modified):
   ```
   For each changed component/element:
     - get_computed_styles(node_id) → verify spacing, font, color
     - get_element_box_model(node_id) → verify margin/padding/border
     - get_matched_styles(node_id) → verify no conflicting rules
     - get_media_queries() → verify breakpoints are correct
   ```

3. **imugi MCP** (design comparison, only if Figma link exists in PR body or ticket):
   ```
   imugi_figma_export → export design frame
   imugi_compare → design vs screenshot (SSIM score + heatmap)
   Score < 95%? → flag as finding with heatmap evidence
   ```

**Present layout validation section in output:**

```
Layout validation (N frontend files in diff):
- Viewports tested: 375px, 768px, 1440px
- Figma comparison: score 97% (PASS) / not applicable (no Figma link)
- Responsive: OK / FINDING → breakpoint at 768px causes overflow
- Spacing: OK / FINDING → padding-left 16px, design shows 24px
- Typography: OK / FINDING → font-size 14px, adjacent components use 16px
```

**Skip layout validation when:**
- Diff is backend-only (no .tsx, .css, .scss, styled-components)
- Diff only changes logic inside components (no JSX/style changes)
- Dev server cannot be started (note: "Layout validation skipped, dev server not available")
- Changes are test-only files

### Do NOT report these (skip entirely)

- Pure formatting/whitespace preferences (linters handle this)
- Things that a linter, typechecker, or compiler would catch
- Pre-existing issues not introduced by this diff
- Existing patterns you'd do differently but work correctly (respect the codebase)
- Generic advice without specific context ("consider adding more tests")
- Issues on lines not in the diff

## Step 4: Draft comments

For each finding, draft an inline comment.

### Comment rules

1. **One to two sentences maximum** - be concise. If a comment exceeds 2 sentences, split it: first sentence = the problem, second = the suggested fix. Discard everything else. The inline comment is a pointer, not an essay
2. **Sound like a human colleague** - not a bot, linter, or automated tool
3. **ZERO prefixes or labels** - NEVER use `[suggestion]`, `[nit]`, `D1:`, severity labels, or dimension codes. The tier classification is internal only, never visible in the comment
4. **No em dash** - use comma, period, or parentheses instead
5. **English only**
6. **Actionable** - say what's wrong and hint at the fix
7. **Empathetic** - phrase as questions, observations, or "worth checking"
8. **Context-aware** - reference the business rule, scenario, or codebase pattern that makes it relevant

### Good examples

- `This will throw if 'offer' is undefined since the filter runs before the null check on line 42.`
- `Two concurrent requests could both pass this check and create duplicate bookings here.`
- `There's an AttractionType enum in @models/attraction/types.ts that already has these values, worth using Object.values(AttractionType) here instead of hardcoding.`
- `There's a 'formatCurrency' util in src/lib/currency.ts that already handles this, might be worth reusing.`
- `Worth adding a test for the empty array case here, that's the most common scenario for new customers.`
- `'data' is pretty vague here, something like 'availabilitySlots' would make the intent clearer.`

### Bad examples (NEVER do this)

- `[suggestion] D6: Missing test for the case where experiences is an empty array.`
- `MEDIUM | CLEAN_CODE | src/service.ts:45 | This function could be split.`
- `Suggestion: You might want to add a try-catch block around this call for safety.`
- `The fetch size grows as page * 32 up to 320. Worth validating payload size and latency with the search service and RUM after rollout, especially on slower networks.` (3 sentences, exceeds limit. Better: `Fetch size grows to page * 32 (max 320), worth validating payload latency with RUM after rollout.`)

## Verification (MANDATORY, present to user before findings)

**You MUST present this checklist to the user with `[x]` marks** as part of the Step 5 output, between the context gate and the findings. This is not optional. Do NOT summarize it as prose ("18 dimensions considered"). Present the actual checklist with marks. If any item is `[ ]`, go back and fix it before presenting findings.

```
Verification:
[x] All 18 dimensions checked (even if N/A for some)
[x] No generated files reviewed
[x] Each finding has: dimension, severity, file:line, description, suggestion
[x] No style-only findings (unless causes bug)
[x] Cross-file grep done for each pattern found (D7)
[x] Test coverage verified for new code paths
[x] Existing repo patterns checked before flagging
[x] CI checks passed (lint, types, build, tests)
[x] Known gotchas file read and checked against diff
[x] Verdict includes rationale
[x] Rollback safety assessed
[x] Previous review comments checked (PR mode)
[x] Each comment is max 2 sentences
```

**A prose summary is NOT acceptable.** The checklist format exists so the user can scan it in 2 seconds and spot any `[ ]`.

---

## Step 5: Present findings for approval (mandatory gate)

Always present all findings to the user before posting anything on GitHub. Never post comments without showing them first and getting explicit approval. Why: once posted, GitHub comments are visible to the PR author and team. Incorrect or noisy comments damage credibility, and the user has been burned by auto-posted comments that were false positives. This gate ensures every comment earns its place.

Present ALL findings grouped by severity. **NEVER filter, cap, or omit findings.** Every finding must be shown regardless of tier. The user decides what to post, not the tool.

```
## Blocking (X findings)
1. `src/file.ts` (line 42) - Correctness
   > This will throw if `offer` is undefined since the filter runs before the null check on line 42.

## Suggestions (X findings)
2. `src/handler.ts` (line 15) - Consistency
   > There's a `formatCurrency` util in src/lib/currency.ts that already handles this, might be worth reusing.

## Nits (X findings)
3. `src/mapper.ts` (line 22) - Clean Code
   > `data` is pretty vague here, something like `availabilitySlots` would make the intent clearer.

## Dimensions checked: 18/18
## CI: lint OK, types OK, build OK, tests OK (X suites, Y tests)

Verdict: APPROVED / APPROVED WITH SUGGESTIONS / CHANGES NEEDED
Rationale: [1-2 sentences explaining the verdict]
Rollback safety: SAFE / CAUTION / UNSAFE
  SAFE = pure code change, no state mutations, revert is clean
  CAUTION = has DB migration, event publishing, or external API calls with side-effects. Revert needs [specific steps]
  UNSAFE = irreversible state change (destructive migration, external system mutation). Revert requires [manual intervention]
---
The `> quoted text` above is EXACTLY what will be posted on GitHub as inline comments.
Review each one. Then choose:
  (a) approve all - post all comments
  (b) approve by tier - e.g. "blocking and suggestions"
  (c) one by one - review each individually
  (d) skip all - post nothing
  (numbers) e.g. "1, 3, 5" - post only those
  (edit N) - change a comment before posting
  (s) save - save full review to vault (always available, combinable with other options e.g. "a s")
```

**STOP HERE and WAIT for user response.** Do NOT proceed to Step 6 until the user explicitly chooses an action. If the user doesn't respond, ask: "Which comments should I post?"

### Save review to vault (option "s")

When the user includes `s` in their response (standalone or combined, e.g. "a s", "1,3,5 s", "d s"):

**Directory**: `__VAULT_ROOT__/Development/Reviews/`

**File naming**: `<PR_NUMBER>--<REPO>--<BRANCH_SLUG>--round-<N>.md`

```bash
# Detect round number (check for existing files with same PR+repo+branch prefix)
REVIEWS_DIR="__VAULT_ROOT__/Development/Reviews"
PREFIX="<PR_NUMBER>--<REPO>--<BRANCH_SLUG>"
EXISTING=$(ls "$REVIEWS_DIR"/${PREFIX}--round-*.md 2>/dev/null | wc -l | tr -d ' ')
ROUND=$((EXISTING + 1))
```

**Branch slug**: lowercase, slashes and underscores replaced with dashes, truncated to 40 chars. E.g. `feat/EXP-3572-attractions-dashboard` becomes `feat-exp-3572-attractions-dashboard`.

**Example filenames**:
- `1800--svc-experiences--feat-exp-3572-attractions-dashboard--round-1.md`
- `1800--svc-experiences--feat-exp-3572-attractions-dashboard--round-2.md`
- `0--svc-experiences--feat-exp-3580-search-v2--round-1.md` (branch mode, no PR = use 0)

**File content**:

```markdown
---
pr: <PR_URL or "branch-mode">
repo: <REPO_NAME>
branch: <BRANCH_NAME>
round: <N>
verdict: <APPROVED / APPROVED WITH SUGGESTIONS / CHANGES NEEDED>
rollback: <SAFE / CAUTION / UNSAFE>
date: YYYY-MM-DD
dimensions_checked: 18/18
findings_total: <N>
findings_blocking: <N>
findings_suggestions: <N>
findings_nits: <N>
---

# Code Review Round <N> - <REPO> PR #<NUMBER>

## Verdict

<verdict> - <rationale>
Rollback safety: <assessment>

## Blocking (<N>)

### 1. <short description>
- **File**: `path/to/file.ts` (line XX)
- **Dimension**: D1/D2/etc
- **Comment**: <exact comment text>

## Suggestions (<N>)

### 2. <short description>
- **File**: `path/to/file.ts` (line XX)
- **Dimension**: D5/D6/etc
- **Comment**: <exact comment text>

## Nits (<N>)

### 3. <short description>
- **File**: `path/to/file.ts` (line XX)
- **Dimension**: D7/D11/etc
- **Comment**: <exact comment text>

## Context gathered
- <key context from Step 2 that explains WHY these findings matter>

## Dimensions clean
D2, D3, D8, D10, D12 (list all clean dimensions)
```

Create the directory if it doesn't exist. After saving, confirm: "Review saved: `<filename>`"

## Step 6: Post comments (if PR exists)

If a PR was detected in Step 1, post approved comments. Two types of comments:

### New findings = INLINE comments (on the code line)

New findings from this review are posted as inline comments on the specific line of code:

```bash
gh api repos/<REPO>/pulls/<NUMBER>/comments \
  -f body="<COMMENT>" \
  -f commit_id="$(gh pr view <NUMBER> --repo <REPO> --json headRefOid -q .headRefOid)" \
  -f path="<FILE_PATH>" \
  -F line=<LINE_NUMBER> \
  -f side="RIGHT"
```

**Only on lines in the diff.** Findings about lines not in the diff are skipped entirely.

### Replies to existing comments = IN-THREAD replies

When responding to existing review comments (from other reviewers or previous review rounds), reply IN THE THREAD of that comment, not as a new inline comment:

```bash
# Reply to an existing review comment
gh api repos/<REPO>/pulls/<NUMBER>/comments/<COMMENT_ID>/replies \
  -f body="<REPLY>"
```

To find existing comment IDs:
```bash
gh api repos/<REPO>/pulls/<NUMBER>/comments --jq '.[] | {id, body: .body[:80], path, line}'
```

**Rule**: New finding = inline on the code. Response to existing comment = reply in that comment's thread. Never create a new inline comment to respond to an existing one.

If no PR exists, skip this step entirely (findings were already presented in Step 5).

## Step 7: Approve or request changes (if PR exists)

If a PR was detected:

- **Zero findings, or only Nits**: approve
- **Only Suggestions (no Blocking)**: approve
- **Any Blocking findings**: request changes

**Always present review action to user before posting:**

```
**Review action:** Approve (or Request changes)
**Comment:** <exact comment body>
Post? (y/n/edit)
```

- **Approval**: comment body MUST be exactly `LGTM!`
- **Request changes**: short and casual, reference inline comments

```bash
gh pr review <NUMBER> --repo <REPO> --approve --body "LGTM!"
gh pr review <NUMBER> --repo <REPO> --request-changes --body "<COMMENT>"
```

If no PR exists, skip Steps 6 and 7.

## Step 8: Summary + Workflow Compliance

```
Review complete (18/18 dimensions checked):
- Blocking: X findings
- Suggestions: X findings
- Nits: X findings
- Total: X findings presented (all reported, none filtered)
- CI: lint OK, types OK, build OK, tests OK

Dimensions with findings: D1, D6, D9
Dimensions clean: D2, D3, D4, D5, D7, D8, D10, D11, D12

Verdict: APPROVED / APPROVED WITH SUGGESTIONS / CHANGES NEEDED
Rollback safety: SAFE / CAUTION / UNSAFE
```

### Branch mode verdict criteria

- **APPROVED**: zero Blocking findings. Ready to commit
- **APPROVED WITH SUGGESTIONS**: only Suggestions and/or Nits. Can commit, but consider fixing suggestions first
- **CHANGES NEEDED**: has Blocking findings (list them). Fix before committing

### Workflow Compliance - Skills Usage Table

After every review, present the workflow progress:

```
| Skill | Status | Notes |
|---|---|---|
| `/feature-dev` | DONE / SKIPPED / N/A | |
| `/deslop` | DONE / PENDING / N/A | |
| `/code-review` | DONE | this review |
| `/test-scenarios` | PENDING | smoke tests + staging validation |
| `/commit` | PENDING | after tests pass |
| `/create-pr` | PENDING | after commit |
| `/deploy-checklist` | PENDING / N/A | N/A if no infra changes |
| `/validate-infra` | DONE / N/A | if env vars changed |
| `/validate-migration` | DONE / N/A | if migration created |
| `/learn` | PENDING / N/A | if new pattern/pitfall found |

**Pending actions**: [list skills that should still be run before merge]
```

**IMPORTANT**: Each pending skill MUST be invoked via the Skill tool. Never run `git commit` or `gh pr create` directly.

## Step 9: Save learnings (automatic, never skip)

After EVERY review that has findings (any tier), evaluate if new patterns or gotchas were discovered. This step is built into the skill so it works regardless of which tool runs it (Claude Code, Cursor, etc.).

### What to save

For each finding that meets ANY of these criteria:
- A new pattern not yet in `references/learnings.md` or `references/known-gotchas.md`
- A false positive you almost posted (save WHY it was wrong to prevent recurrence)
- A cross-service interaction that wasn't obvious from the diff alone
- A codebase convention you discovered during Step 2 context gathering

### How to save

1. **Append to `references/learnings.md`** using this format:
   ```
   ### YYYY-MM-DD Short description
   - **Context**: PR/ticket, service, what happened
   - **Gap**: What the review initially missed or almost got wrong
   - **Fix**: What to check next time to catch this earlier
   - **Promoted to Common Mistakes**: yes/no (yes if high-impact and recurring)
   ```

2. **If the learning is a one-liner gotcha**, also append to pitfalls.md:
   - Vault: `Knowledge-Base/Reference/Routing-Tables.md` has the path
   - Memory dir pitfalls: check if the project has `pitfalls.md` in its memory directory

3. **If promoted to Common Mistakes**, update `references/known-gotchas.md` with the new pattern

### When to skip

Only skip if the review was fully clean (APPROVED, zero findings across all tiers) AND no new patterns were discovered during context gathering. Even "LGTM" reviews can discover learnings in Step 2.

## Step 10: Export for other instance (always ask)

At the end of every review, ask the user:

```
Save the review for the other instance?
  (a) Apply fixes - save actionable findings for the other instance to apply the corrections
  (b) Publish - save for the other instance to post comments on the PR (review of someone else's PR)
  (c) Both
  (n) Not needed

Which findings? (default: all Blocking + Suggestions)
  (all) - include everything (Blocking + Suggestions + Nits)
  (numbers) e.g. "1, 3, 5" - only specific findings
```

### If (a) or (c): Save actionable findings

Write to `vault/Development/Reviews/YYYY-MM-DD--PR-NUMBER--REPO.md`:

```markdown
---
pr: <PR_URL>
repo: <REPO_NAME>
branch: <BRANCH_NAME>
verdict: <APPROVED / CHANGES NEEDED>
action: apply-fixes
date: YYYY-MM-DD
---

# Code Review Findings - PR #NUMBER

## Fixes to apply

For each finding (Blocking and Suggestions only):

### 1. [Short description]
- **File**: `path/to/file.ts` (line XX)
- **Dimension**: D1/D2/etc
- **Problem**: What's wrong (1-2 lines)
- **Fix**: Exactly what to change (be specific enough for the other instance to implement without guessing)

## Context gathered
- [Key context from Step 2 that the other instance needs to understand WHY these fixes matter]
```

### If (b) or (c): Save for publishing

Write to `vault/Development/Reviews/YYYY-MM-DD--PR-NUMBER--REPO.md`:

```markdown
---
pr: <PR_URL>
repo: <REPO_NAME>
branch: <BRANCH_NAME>
verdict: <APPROVED / CHANGES NEEDED>
action: publish-comments
date: YYYY-MM-DD
---

# Code Review Comments - PR #NUMBER

## Comments to post

For each finding, the EXACT text to post as inline comment:

### 1. File: `path/to/file.ts` | Line: XX
> Exact comment text ready to post (already follows comment rules from Step 4)

### 2. File: `path/to/other.ts` | Line: YY
> Exact comment text ready to post

## Review action
- Type: approve / request-changes
- Body: `LGTM!` or `<short casual comment>`
```

### Vault path

- **Directory**: `__VAULT_ROOT__/Development/Reviews/`
- Create the directory if it doesn't exist
- File naming: `YYYY-MM-DD--PR-NUMBER--repo-name.md`

The other instance (Claude Code or Cursor) can then read this file and execute the action (apply fixes or post comments) without re-running the full review.

---

## Replying to PR Comments

### Format rules

1. **One sentence, two max.** State what was done and the commit SHA
2. **No em dash**. Use comma, period, or parentheses
3. **Sound human** - like a quick reply to a colleague
4. **No narration** - don't explain the "why" unless the reviewer asked
5. **English only**

### Good examples

- `Fixed in 4abc69a, now checks promoItemInfo.length > 0.`
- `Good catch. Applied in e29f1b2.`
- `Updated, switched to the existing formatCurrency util.`

---

## Rules

- Understand business rules before flagging something as a bug. Why: what looks like a bug is often an intentional business rule. Flagging it shows ignorance of the domain.
- If unsure whether something is a bug, investigate more (read callers, tests, docs) before commenting. Why: uncertain comments erode trust faster than saying nothing.
- Respect existing codebase patterns. If a pattern is intentional (documented in PR body, Slack, Confluence), do not flag it. Why: suggesting "a better way" when the team deliberately chose this way is disrespectful of their context.
- Quality over noise: every comment must be actionable and specific. Why: a review with 20 comments but only 2 actionable ones trains authors to ignore reviews.
- Nits must reference a concrete improvement, not generic advice. Why: "consider adding tests" with no specifics is not helpful.
- If the diff is clean across all dimensions, say so. Don't force findings. Why: an honest "LGTM" is more valuable than manufactured nitpicks.
- Full workflow is mandatory: never skip Step 2. A "looks good" without investigation is a failed review. Why: shallow reviews that miss context have led to production bugs that proper investigation would have caught.
- Inline only: findings about lines not in the diff are skipped entirely. Why: commenting on pre-existing code is out of scope and creates resentment.
- Report ALL findings across ALL tiers. Never cap, filter, or omit findings. Why: the reviewer decides what to post, not the tool. Suppressing findings means bugs slip through.
- Balance nit volume: if Nits exceed 5 items, present all but recommend which ones are highest-impact to post. A review with 15 nits and 0 bugs is noise. Show all, suggest posting top 5.
