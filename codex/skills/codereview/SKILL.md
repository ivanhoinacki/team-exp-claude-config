---
name: codereview
description: 'Codex Skill - Review code quality with all 18 dimensions. Analyzes diff, gathers deep context, checks Known Gotchas, presents findings grouped by severity. If a PR exists, posts inline comments on GitHub only after Ivan explicitly approves. Use when the user invokes /codex:review or says "code review", "review this PR", "review PR", "review", "check quality", or before opening a PR. This is the default review skill.'
---

# Code Review - Full Spectrum

## Invocation Target

If the user invoked this as `/codereview ...`, `/review ...`, selected this skill from the picker, or included a PR URL/ticket/repo in the same message, treat the full user message as the review target input.

Do not ask what to review when the user message contains any of:
- `https://github.com/lux-group/{repo}/pull/{number}`
- `EXP-XXXX`, `BUG007-XXXX`, or `ENGX-XXXX`
- a repo/worktree name under `__HOME__/Documents/_Repositories/LuxuryEscapes`

Only ask for a target when no PR URL, ticket ID, repo, worktree, branch, or file target is present in the user message and `$ARGUMENTS` is empty.

## Codex Adaptation

Converted from `__HOME__/.agents/skills/codereview/SKILL.md`.
Claude-only frontmatter fields such as `model`, `allowed-tools`, `argument-hint`, and `compatibility` were removed because Codex discovers skills through `name` and `description`.
Original Claude model hint: `sonnet`. In Codex, use tier-approved model overrides for subagents because `spawn_agent` otherwise inherits the parent model.
Use Codex tools and MCPs available in the current session. If a named Claude MCP is unavailable, state the gap and use the closest safe local source.
Do not mutate Slack, Jira, Confluence, GitHub, Datadog, CI/CD, infrastructure, or production systems without explicit approval.
Use Codex subagents only when current system or user instructions explicitly allow delegation.

## Parallel Agent Policy

Invoking `codereview` or `/codex:review` is not a blanket request for broad fan-out. Use parallel read-only subagents only when the review is medium or high risk, cross-service, or context-heavy. Keep the parent agent responsible for final findings and GitHub approval gates.

Cost model: use `cheap_readonly` roles for evidence and independent review slices. Spawn `reviewer`/`researcher` subagents with `model="gpt-5.4-mini"` and `reasoning_effort="low"` explicitly as best effort. Verify the runtime log before assuming the override was honored; if Codex inherits the parent model, reduce fan-out breadth. The parent agent performs final severity, deduplication, and synthesis. Do not escalate subagent model/effort unless the review involves security, financial impact, migration risk, production incident evidence, or contradicted findings.

Default fan-out budget:

| Risk | Default delegation |
| --- | --- |
| LOW | No subagents. Parent collects vault + diff + focused history locally. |
| MEDIUM | At most 2 read-only subagents unless the diff is cross-service or the PR history is unusually complex. |
| HIGH | Up to 4 read-only subagents when each one owns a distinct evidence stream. |

Do not copy Claude-style broad fan-out by default. A medium PR should not launch 8 independent agents unless the duplicated context has a clear payoff. If token/runtime logs show subagents inheriting the parent model or using large contexts, stop spawning more agents and continue with bounded local reads.

Default fan-out slices:

- `diff-and-tests` (`reviewer`): changed diff, callers/callees, contract risks, and tests.
- `vault-context` (`researcher`): vault RAG, prior review learnings, business rules, and known gotchas.
- `history-prior-art` (`researcher`): GitHub PR history, git history, and cross-repo/service-chain prior art.
- `decisions-context` (`researcher`): Slack/Confluence decision context for medium/high risk changes.

Do not delegate posting comments, approving PRs, requesting changes, writing files, committing, or pushing. Subagents are for evidence collection and independent review only.

## Visible Deep Dive Lanes

For medium/high-risk reviews, cross-service PRs, production-impacting changes, broad specs, or when Ivan asks to compare with Claude-style behavior, make context gathering visible.

Before launching deep context work, announce the lanes in one compact block. Choose only relevant lanes:

```text
Deep dive lanes:
- Deep dive: diff + changed code
- Deep dive: tests + coverage
- Deep dive: vault + known gotchas
- Deep dive: GitHub prior art
- Deep dive: Slack/Confluence decisions
- Deep dive: runtime/CI evidence
```

Use read-only subagents for independent lanes when available. If generic subagents are not available in the current Codex runtime, run the same lanes with parallel tool calls or bounded local reads and say `subagents unavailable, running local lanes`.

When each lane finishes, report a short completion line:

```text
Deep dive "GitHub prior art" completed · 5 PRs checked · 2 relevant patterns
Deep dive "tests + coverage" completed · 3 test files · 1 missing edge case
```

The parent agent must reconcile all lane outputs before drafting findings. Do not let lane output become a finding until the parent verifies file/line, introduced-by-diff status, impact, and fix direction.

### Parent synthesis gate

Before showing findings to Ivan, explicitly reconcile all agent outputs:

- Mark each proposed finding as `CONFIRMED`, `FALSE POSITIVE`, `DUPLICATE`, `PRE-EXISTING`, or `OUT OF SCOPE`.
- Drop every `FALSE POSITIVE`, `DUPLICATE`, `PRE-EXISTING`, and `OUT OF SCOPE` item from the final findings.
- For each `CONFIRMED` finding, verify the exact file/line, introduced-by-diff status, impact, and fix direction in parent context.
- Surface a short "Cross-check notes" section only when it explains why likely findings were intentionally dropped.

Never trust subagent findings directly. Subagents are evidence sources, not reviewers of record.

## Token Economy Rules (MANDATORY)

- Prefix noisy shell commands with `rtk`, especially `git diff`, `gh pr diff`, `git log`, tests, and build output.
- Remote GitHub CLI commands require network access. When using `exec_command` for `rtk gh pr view`, `rtk gh pr list`, `rtk gh pr diff`, `rtk gh api`, or `rtk gh search`, request `sandbox_permissions="require_escalated"` on the first attempt with a narrow `prefix_rule` such as `["rtk", "gh", "pr", "view"]`. Do not first run remote `gh` inside the sandbox just to get `error connecting to api.github.com`.
- Start with diff triage before deciding context depth.
- Use diff hunks, changed functions, callers/callees, and focused tests before full file reads.
- Do not read generated files, lockfiles, snapshots, assets, or bulk fixtures fully unless they are the review subject.
- Load reference files only when the current risk tier needs them.
- Use subagents only when independent analysis is worth the duplicated context.
- If branch mode diff is broad (>20 files or >800 changed lines), triage the stat first and ask whether to review the whole branch or only task-scoped paths.
- In PR mode, do not use `gh pr diff --stat` or `gh pr diff -- <path>`; current GitHub CLI rejects those forms. Use `gh pr view --json files` for file stats and local `git diff` in the matching worktree for per-file hunks.
- Keep findings evidence-rich but compact: file/line, impact, fix direction. Avoid narrating the whole investigation.

## Phase 0: Vault RAG (MANDATORY, BEFORE ANYTHING ELSE)

Before ANY file reads, grep, or codebase exploration, call `query_vault` with relevant keywords, `client_filter` set to the active client slug, and `service_filter` when known. The client filter is mandatory on client-scoped work: it excludes rows tagged for other clients while preserving neutral or legacy rows. Omit it only for an explicitly company-neutral query. This is non-negotiable and must be the FIRST action after reading the task. The vault contains pitfalls, business rules, review learnings, and patterns that prevent rework. Skip = rework.

## Working Directories and Review Routing

1. **Vault root**: `__VAULT_ROOT__`
2. **Company-neutral reviews**: `Personal Projects/Code Reviews/{REPO}/`.
3. **Luxury Escapes reviews**: `Luxury-Escapes/Development/Reviews/` only for explicit Luxury Escapes context or `EXP-*`/`BUG007-*` work.
4. **Other company reviews**: use that company's existing review folder.
5. **Codebase**: derive from the repository named by the user or the current working directory.

## References

| File                                                                 | Content                                                   |
| -------------------------------------------------------------------- | --------------------------------------------------------- |
| [`references/dimension-details.md`](references/dimension-details.md) | Full 18-dimension definitions with tier/severity for each |
| `~/.agents/skills/codereview/references/known-gotchas.md`            | Shared recurring bug patterns to check against every diff |
| `~/.agents/skills/codereview/references/learnings.md`                | Shared lessons from past reviews (grows over time)        |

## Shared PR Review Learning Loop (MANDATORY)

Use only these shared files for PR review learning capture and reuse:

- `~/.agents/skills/codereview/references/learnings.md`
- `~/.agents/skills/codereview/references/known-gotchas.md`

Do not read from or write to local `~/.codex/skills/codereview/references/learnings.md` or `~/.codex/skills/codereview/references/known-gotchas.md` copies as a source of truth.

CAPTURE: every PR review comment made, every PR review comment answered, and every completed review must leave a reusable learning trail. When applying any PR review comment fix or reply, fix the code first, then append the reusable lesson to `~/.agents/skills/codereview/references/learnings.md` before the final response. The learning may be a repo convention, hidden rule, business constraint, reviewer preference, validation gap, false-positive avoidance note, or process guardrail. If it changes future review checks and is high-impact or recurring, update the matching section in `~/.agents/skills/codereview/references/known-gotchas.md`.

REUSE: before writing or modifying code in any Luxury Escapes repo, scan the matching `~/.agents/skills/codereview/references/known-gotchas.md` sections for the change domain and quickly search `~/.agents/skills/codereview/references/learnings.md` for the target repo or service. Surface matched patterns as risks before implementation.

REVIEW: when reviewing code, read both shared files first and cross-reference every section of `~/.agents/skills/codereview/references/known-gotchas.md` against the diff.

## Review Learning Pre-Flight

Before reviewing a PR, applying another developer's review comments, or reading a saved review artifact, check prior review learnings first:

1. Read `~/.agents/skills/codereview/references/learnings.md` for service/domain-specific lessons that may apply to the current diff.
2. Search durable memory for the ticket, repo, PR number, reviewer name, and terms from the feedback, for example `AGENTS.md`, `CLAUDE.md`, `migration`, `DML`, `contract`, or `review feedback`.
3. If a review comment exposes a repo guideline, hidden convention, or missed business rule, save that as a new learning after the correction is made.
4. On the next review, treat those saved learnings as input before forming findings, especially before disagreeing with another developer's review.

Recent example: for `svc-experiences` PR #2196, Leo correctly pointed out that repo guidance disallows DML inside TypeORM migrations. Future reviews touching migrations must read repo `AGENTS.md`/`CLAUDE.md` before accepting or defending migration-based data changes.

## Mode Detection

**PR mode** (argument is a PR URL, number, or ticket with open PR): Review a pull request with inline GitHub comments.
**Branch mode** (no argument, no open PR, or merged/closed PR): Self-review current branch diff against origin/master. Includes local CI checks.

## Quick Reference Flow

```
Step 0:    Detect PR and review mode
Step 0.5:  CI checks (BRANCH MODE ONLY)
Step 1:    Get the diff (detect PR vs branch)
Step 1.5:  Diff triage (classify files, assess risk) → PRESENT triage summary
Step 2:    Context gathering (intent + bounded code read + risk-tier search)
  2.1  Understand intent (PR body / git log / vault feature doc)
  2.2  Read code (diff hunks + changed functions + callers + tests)
  2.3  Deep context (vault RAG + git history + PR history + Slack + Confluence)
  2.4  Previous review round (PR mode: inline comments + review verdicts)
  GATE: Context self-check → PRESENT checklist (all items must be [x])
Step 3:    Analyze ALL 18 dimensions + read known-gotchas.md + feature flag + dep analysis + D6 test checklist
  → Reconcile agent outputs and drop false positives before drafting comments
  → PRESENT "Known gotchas checked" section (mandatory, even if all N/A)
  → PRESENT "D6 test checklist" results (if test files in diff)
Step 4:    Draft comments (human tone, no labels, max 2 sentences, actionable)
  → PRESENT Verification checklist with [x] marks (mandatory, not prose)
Step 5:    Present findings, save review to vault, then wait for GitHub action
Step 6:    Post approved comments only (PR mode only)
Step 7:    Approve or request changes only when Ivan explicitly asks
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
~/.codex/scripts/ci-local-check.sh .
```

This auto-detects `package.json` scripts and runs lint, types, build, and tests in order.

If ANY check fails: **STOP the review**. Report the failures as CRITICAL findings and fix them first. Do not proceed to the 18 dimensions with failing CI.

---

## Step 1: Get the diff

### Pre-flight (mandatory before analysis)

Do not fetch before the target is known. In PR mode, start from GitHub PR metadata. Fetch only after selecting a local worktree and only when local branch comparison is needed.

### Scope detection

Parse `$ARGUMENTS` and detect the review target:

1. **PR URL** (e.g. `https://github.com/lux-group/svc-sailthru/pull/3020`): extract repo + PR number. Use bounded `rtk gh pr diff <number>` for the diff, NEVER `git log` on the full branch.
2. **PR number** (e.g. `3020`): use current repo. Use bounded `rtk gh pr diff <number>` only after file triage.
3. **Ticket ID** (e.g. `EXP-3572`): search worktrees across `__CODEBASE_ROOT__/` for a matching worktree, `cd` into it. Then check for open PR, otherwise use local branch diff
4. **Repo or worktree name** (e.g. `svc-sailthru--exp3572` or `svc-sailthru`): `cd` into `__CODEBASE_ROOT__/<name>`. Then check for open PR, otherwise use local branch diff
5. **No argument**: use current directory. Check for open PR: `gh pr view --json number,url 2>/dev/null`

For cases 3-5, if no PR is found OR the PR is not OPEN, use local branch diff (`git diff origin/master...HEAD`). Always use `origin/master` as the base, not local `master`.

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
rtk gh pr view <NUMBER> --repo <REPO> --json number,state,title,body,headRefName,baseRefName,author,isDraft,url,headRefOid,files
```

Use `.files[]` from `gh pr view` for changed paths and additions/deletions. If a matching local worktree exists, inspect hunks with `rtk git diff origin/<base>...HEAD -- <file>`. If no local checkout exists, use one bounded `rtk gh pr diff <NUMBER> --repo <REPO> --patch` after triage, only when the changed-file count is small enough to review safely.

If no OPEN PR (merged, closed, or none):

```bash
git fetch origin master --quiet 2>/dev/null || git fetch origin main --quiet 2>/dev/null || true
rtk git diff origin/master...HEAD --name-only
rtk git diff origin/master...HEAD --stat
rtk git diff origin/master...HEAD -- path/to/review-file.ts
```

### PR edge cases

| Situation                                | Behavior                                                                                             |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Draft PR**                             | Review normally but note "PR is draft" in summary. Do NOT approve/request-changes (Step 7) on drafts |
| **Force-pushed PR**                      | Re-fetch diff after force-push. Previous review comments may reference stale lines. Note in Step 2.4 |
| **PR with no code diff** (metadata-only) | Skip review. Report: "No code changes to review"                                                     |
| **PR touching git submodules**           | Skip submodule changes. Note in summary: "Submodule changes not reviewed"                            |
| **PR across forks**                      | Use full repo path in all gh commands. Verify base branch is correct                                 |

Store whether a PR was found (used in Steps 6-7 for posting comments).

## Step 1.5: Diff Triage (MANDATORY, classify before deep-diving)

**NEVER skip this step.** Before reading every file in detail, classify the changed files to focus review energy on what matters. Present the triage summary to show it was done.

### File classification

```bash
# Get changed files
FILES=$(rtk gh pr view <NUMBER> --repo <REPO> --json files --jq '.files[].path' 2>/dev/null || rtk git diff origin/master...HEAD --name-only)
```

Classify each file into one of these categories:

| Category   | Examples                                                                                                    | Action                                                                |
| ---------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| **Skip**   | `yarn.lock`, `package-lock.json`, `*.snap`, `generated/`, `__generated__/`, files with "do not edit" header | Do not review. Mention in summary: "X files skipped (lock/generated)" |
| **Scan**   | Type definitions (`.d.ts`), config files (`.json`, `.yml`), pure rename/move                                | Quick scan for correctness, no deep analysis                          |
| **Review** | Source code, tests, migrations, API routes, handlers, services, models                                      | Full 18-dimension analysis                                            |

### Priority order for Review files

1. **Handlers / Routes / Controllers** (entry points, highest bug surface)
2. **Services / Business logic** (where correctness and financial integrity live)
3. **Database layer** (queries, migrations, models)
4. **Tests** (verify coverage matches implementation changes)
5. **Shared utils / types** (cross-file impact)

### Diff size awareness

| Diff size                         | Behavior                                                                                                          |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Small (<100 lines of actual code) | Full depth on everything                                                                                          |
| Medium (100-500 lines)            | Full depth on Review files, scan-only for Scan files                                                              |
| Large (>500 lines)                | Flag "this PR is large, consider splitting". Still review fully, but note in the verdict that size increases risk |

### Risk classification (modulates context depth in Step 2.3)

Based on the diff triage, classify the overall change risk:

| Risk       | Criteria                                                                | Context depth                                                                                      |
| ---------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| **LOW**    | Rename, typo fix, config-only, docs-only, test-only                     | Step 2.3: Vault RAG + focused git history. Skip Slack/Confluence/PR history unless aliases or risk signals suggest broader context |
| **MEDIUM** | Logic change, new function, refactor, UI change                         | Step 2.3: vault + git + targeted PR history. Add Slack/Confluence when decisions or business rules are not already captured |
| **HIGH**   | New endpoint, cross-service, financial logic, auth change, DB migration | Step 2.3: full risk-tier evidence + extra diligence across relevant service-chain repos |

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

Complete the applicable sub-steps for the risk level from Step 1.5. Dependency gates must run in order, but independent evidence searches should run in parallel when possible. Do not skip to analysis early, even if the change looks simple. Why: premature analysis without context leads to false positives (flagging intentional patterns) and false negatives (missing business rule violations). Past reviews that skipped context had 3-4x more rejected comments.

### 2.1 Understand the intent

- If PR exists: read the PR body thoroughly. This is the PRIMARY source of context.
- Read the git log: `git log main..HEAD --oneline` (if local branch available; for remote-only PRs use the PR commits list)
- **Search vault for feature doc**: `query_vault(query="<TICKET_ID> implementation plan", type_filter=["session-memory"], service_filter="<service-if-known>", client_filter="<active-client-slug>")` and search `Development/Features/` for a folder matching the ticket. If a feature plan or implementation plan exists, read it. This reveals design decisions the PR body may omit.

### 2.2 Read the code

1. **Read bounded code context first**: diff hunks, changed functions, directly affected callers/callees, and tests.
2. **Read complete files only when needed**: when the hunk lacks enough context, the file is small and central, or the surrounding module determines correctness.
3. **Skip full reads for low-value files**: generated files, lockfiles, snapshots, assets, and large fixtures unless they are the review subject.
4. **Check related files** - if a function is modified, read its callers and callees.
5. **Check tests** - read existing tests for the changed code to understand expected behavior.

### 2.3 Deep context gathering (MANDATORY, never skip)

Investigate the history behind the implementation. This is NOT optional, even for "simple" changes. **Skipping sub-steps here is the #1 cause of false positives and missed business rule violations in past reviews.**

**Pre-search**: If the diff touches multiple services or a cross-cutting concern, quickly identify the service chain and terminology aliases before searching. The same concept often has different names across services (e.g., "complimentary" vs "bundle", "LED" vs "svc-ee-offer"). Use ALL aliases in searches below.

**Risk-based depth** (from Step 1.5 triage):

- **LOW risk**: sub-steps 1 and 2 mandatory. Sub-steps 3-5 optional.
- **MEDIUM risk**: Vault, code, git history, and targeted PR history mandatory. Slack/Confluence are mandatory only when decisions, business rules, or historical intent are not already captured.
- **HIGH risk**: Vault, code, git history, previous review comments, and the specific high-risk surface are mandatory. Add Slack/Confluence/service-chain evidence only when the change depends on product decisions, business rules, historical intent, ownership, cross-service contracts, or externally observable behavior.

**Parallel execution rule**: Run Pre-search and LE Vault RAG first. After aliases, service chain, risk level, and vault gotchas are known, launch independent read-only checks in parallel. Use subagents for medium/high-risk, cross-service, or context-heavy reviews; for low-risk reviews, parallel local tool calls are enough unless subagents would materially improve coverage.
Use cheap read-only roles for these checks. Keep expensive synthesis in the parent only.

- Git history for key changed files.
- GitHub PR history across the repo or service chain.
- Slack searches and thread reads.
- Confluence searches and page reads.

Do not wait for one external source before starting another unless its result changes the query scope. The parent agent must synthesize conflicts and cite which evidence source supports each finding.

Stop external context expansion once there is enough evidence for an actionable technical finding and the remaining sources are unlikely to change the conclusion. Example: a small PR whose only issue is a TypeORM migration lock risk does not need Slack or Confluence unless the lock strategy appears to be a documented product or platform decision.

1. **LE Vault RAG (MCP `local-le-vault`) - FIRST** - Run `query_vault` with PR title/body keywords, ticket id, domain terms, **`client_filter`** set to the active client slug, and **`service_filter`** matching the repo when known (e.g. `svc-experiences`). The client filter is mandatory for client-scoped work and preserves neutral or legacy rows while excluding other clients. Use `list_vault_sources` if filters are unclear. Pull review learnings, business-rule reminders, and pitfalls relevant to the change **before** GitHub/Slack/Confluence. If MCP is unavailable, note it and continue.

2. **Git history** - check why the code around the change exists. Run for EACH key changed file (not just one):

   ```bash
   git log --oneline -10 -- <file_path>
   ```

   If local clone doesn't have the branch, use `gh api` to get commit history:

   ```bash
   rtk gh api 'repos/<REPO>/commits?path=<file_path>&sha=<branch>&per_page=5' --jq '.[].commit.message'
   ```

3. **GitHub PR history** - find previous PRs that touched the same area and **always read their body**:

   ```bash
   rtk gh pr list --repo <REPO> --search "<keyword>" --state merged --limit 5 --json number,title,url
   rtk gh pr view <NUMBER> --repo <REPO> --json body,title
   ```

   **Minimum**: 2 keyword variations per repo. Search ALL repos in the service chain if cross-service.

4. **Slack conversations** - search for the ticket number, feature name, or domain term using ALL terminology aliases. Use channel tiers from `investigation/SKILL.md` Phase 0.5:
   - Tier 1 (always): `#team-experiences-pt-br`, `#svc-experiences`, `#007-exp`
   - Tier 2 (when crossing teams): `#team-customer-payments`, `#team-bundles`, relevant service channels
     **Minimum**: 2 keyword queries using aliases. Read full threads for relevant results.

5. **Confluence docs** - search for ADRs, RFCs, or business rules across multiple spaces. Use tiered space list from `investigation/SKILL.md` Phase 0.5:
   - Tier 1 (always): PE, TEC, ENGX
   - Tier 2 (when feature crosses teams): OE, HOT, WHI, LOYAL, TOUR
     **Minimum**: 2 queries across Tier 1 spaces. Read full pages for relevant results.

6. **Zero-result rule** - if any search returns 0 results, try a different alias or wording before concluding "nothing found".

### 2.4 Previous review round awareness (PR MODE ONLY)

Before analyzing, check if the PR already has review comments from previous rounds or other reviewers. **Both commands below are mandatory.** Inline comments reveal specific code concerns; review-level comments reveal the overall verdict and whether changes were requested.

```bash
# Get existing INLINE review comments (on specific lines)
rtk gh api repos/<REPO>/pulls/<NUMBER>/comments --jq '.[] | {id, user: .user.login, path, line, body: .body[:120], created_at}'

# Get REVIEW-LEVEL comments (approve/request-changes verdicts)
rtk gh api repos/<REPO>/pulls/<NUMBER>/reviews --jq '.[] | {id, user: .user.login, state, body: .body[:120]}'
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
  [x] 2.2 Bounded code context read, with full files only where needed
  [x] 2.2 Callers/callees checked
  [x] 2.2 Existing tests read
  [x] 2.3.1 Vault RAG (query_vault with client_filter + service_filter when known)
  [x] 2.3.2 Git history per key file
  [x] 2.3.3 GitHub PR history (2+ keyword searches)    ← MEDIUM/HIGH risk only
  [x] 2.3.4 Slack search or explicit skip reason       ← MEDIUM/HIGH risk only when decision context can affect findings
  [x] 2.3.5 Confluence search or explicit skip reason  ← MEDIUM/HIGH risk only when decision context can affect findings
  [x] 2.4 Previous review comments + reviews fetched   ← PR mode only
  Risk level: LOW/MEDIUM/HIGH (from Step 1.5)
```

**If risk is MEDIUM or HIGH and sub-steps 3-5 of 2.3 show [ ], decide based on the risk model.** PR history is mandatory when prior art can affect the finding. Slack/Confluence are mandatory only when the change depends on product decisions, business rules, historical intent, or cross-service contracts. They can be skipped with a stated reason for narrow implementation-only changes where vault, PR body, code evidence, and previous review comments are sufficient.

## Step 3: Analyze with ALL 18 dimensions (mandatory checklist)

You MUST evaluate every changed function/module against ALL 18 dimensions. No dimension may be skipped. After analysis, internally mark each dimension as CLEAN or list findings. Report ALL actionable findings, organized by severity tier.

**Parallel dimension analysis rule**: After Step 2 context gathering is complete and the bounded code context is read, analyze the 18 dimensions. Use read-only subagents for medium/high-risk, cross-service, or context-heavy reviews; for low-risk reviews, parallel local analysis slices are enough unless subagents would materially improve coverage.
Use `reviewer` agents for dimension slices and keep their prompts narrow. The parent decides final findings.

Default parallel slices (fit within `max_threads = 6`):

- `critical-correctness` (`reviewer`): D1 Correctness, D4 Error Handling, D14 Idempotency & State Recovery.
- `security-performance` (`reviewer`): D2 Security, D3 Performance, D12 Dependencies.
- `tests-consistency` (`reviewer`): D6 Testing, D7 Codebase Consistency, D5 SOLID / Clean Code.
- `architecture-contracts` (`reviewer`): D8 Architecture, D13 Cross-Service Contract, D16 Data Visibility & Context.
- `operations-runtime` (`reviewer`): D9 Operational Readiness, D10 Concurrency, D17 Runtime Configuration Coupling.
- `business-external` (`reviewer`): D11 Documentation, D15 Financial Calculation Integrity, D18 External System Trust.

Each slice must return CLEAN or concrete findings for every assigned dimension. The parent agent owns final deduplication, severity, confidence, and whether a finding is actionable. Do not delegate GitHub comments, approvals, file edits, commits, pushes, or external mutations during dimension analysis.

### Dimension Summary

| #   | Dimension                       | Tier     | Key checks                                                                                                                       |
| --- | ------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------- |
| D1  | Correctness                     | Critical | Logic bugs, null handling, feature flags, edge cases                                                                             |
| D2  | Security                        | Critical | Injection, secrets, auth, input validation                                                                                       |
| D3  | Performance                     | Critical | N+1, indexes, event loop, memory                                                                                                 |
| D4  | Error Handling                  | Critical | Swallowed errors, cleanup, timeouts, retry                                                                                       |
| D5  | SOLID / Clean Code              | High     | SRP, DIP, dead code, naming                                                                                                      |
| D6  | Testing                         | High     | Coverage, mock signatures, edge cases                                                                                            |
| D7  | Codebase Consistency            | High     | Repo patterns, existing utils, naming, ENUM REUSE                                                                                |
| D8  | Architecture                    | High     | Layer violations, circular deps, boundaries                                                                                      |
| D9  | Operational Readiness           | Medium   | Logs, metrics, tracing, health checks                                                                                            |
| D10 | Concurrency                     | Medium   | Race conditions, idempotency, locks                                                                                              |
| D11 | Documentation                   | Medium   | JSDoc, README, ADR                                                                                                               |
| D12 | Dependencies                    | Medium   | Pinned versions, licenses, vulnerabilities                                                                                       |
| D13 | Cross-Service Contract          | Critical | Same field interpreted by producer and consumer, IDs stable in chain, enum values synced, SNS/SQS ARNs confirmed                 |
| D14 | Idempotency & State Recovery    | High     | Retry/re-run safety, double refund possible, sync wipes manual data, ticket consumed 2x                                          |
| D15 | Financial Calculation Integrity | Critical | FX rounding accumulation, denominator includes all items, same promoAmount everywhere, vendor holdback correct                   |
| D16 | Data Visibility & Context       | High     | Admin queries don't over-filter, public endpoints don't leak inactive, reports join source for current state                     |
| D17 | Runtime Configuration Coupling  | Medium   | Query parser configured explicitly, currency default declared, DD_TRACE correct for ORM, feature flag rollback via env var       |
| D18 | External System Trust           | Medium   | Provider returns semantically wrong data, test transactions triggering alerts, failure attribution (our code vs supplier config) |

> Full tier/severity details for each dimension: [`references/dimension-details.md`](references/dimension-details.md)

### Known Gotchas (MANDATORY, read the file)

**You MUST read `~/.agents/skills/codereview/references/known-gotchas.md` during every review.** Do not rely on memory of past reviews. The file is updated after each review (Step 9) and may contain new entries since the last time you read it. Scan each section header against the diff:

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
5. **Security advisories**: for any changed dep, check if the target version has known CVEs. `gh api '/advisories?ecosystem=npm&package=<name>'` or npm advisory database

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

**Trigger**: If the diff triage (Step 1.5) classified ANY file as Review or Scan that matches these patterns: `*.css`, `*.scss`, `*.styled.ts`, `styled(`, `css\``, `.tsx`with JSX layout changes, LuxKit component modifications, MUI`sx` prop changes, or responsive breakpoint changes.

**This is a visual correctness check (D1 + D7), not a style preference check.** Only flag issues where the visual output is wrong, broken, or inconsistent with existing patterns.

When triggered, use `chrome-devtools-validation` and the `chrome-devtools` MCP family by default for live inspection, console/network evidence, DOM state, screenshots, responsive checks, and E2E-style validation. If Ivan explicitly chooses Playwright, use only `__PLAYWRIGHT_RUNNER__`: specs in `tests/`, required `BASE_URL`, entry `scripts/run.sh`, and evidence in `artifacts/<TEST_RUN_ID>/`. Do not use a generic Playwright MCP or standalone CLI wrapper. When review validation needs multiple browser states at once, such as admin + customer or authenticated + logged-out comparison, follow the selected browser path's isolated-context pattern. If chrome-devtools returns `Transport closed`, `tool call failed`, or `connection closed`, follow the recovery sequence in `chrome-devtools-validation` (`browser-mcp-doctor --browser chrome-devtools --profile codex-primary --cleanup`, retry once, `--still-closed`, hand off to Claude, then ask Ivan for reload/reconnect if both panes fail).

**Optional design comparison** (only if Figma link exists in PR body or ticket):
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

### Focused Test Attempts

For PR mode, local tests are useful but not mandatory. Run at most one focused command for the changed test or module when dependencies are already installed and the command is cheap. If it fails before the test runner because of local toolchain setup, record the failure and stop retrying alternate wrappers unless there is a known local fix from the vault or session memory. Do not spend review time debugging unrelated toolchain issues.

Known local example: `libsimdutf.33.dylib` missing before Jest starts is a machine setup issue, not a PR finding. Mention it under CI/test status and continue the review from code evidence.

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

**You MUST present this checklist to the user with `[x]` marks** as part of the Step 5 output, between the context gate and the findings. This is not optional. Do NOT summarize it as prose ("18 dimensões consideradas"). Present the actual checklist with marks. If any item is `[ ]`, go back and fix it before presenting findings.

```
Verification:
[x] All 18 dimensions checked (even if N/A for some)
[x] No generated files reviewed
[x] Each finding has: dimension, severity, file:line, description, suggestion
[x] No style-only findings (unless causes bug)
[x] Cross-file grep done for each pattern found (D7)
[x] Test coverage verified for new code paths
[x] Existing repo patterns checked before flagging
[x] CI/test status recorded (PR mode may rely on remote CI; local focused test may be skipped or blocked)
[x] Known gotchas file read and checked against diff
[x] Agent/context findings reconciled; false positives and duplicates dropped
[x] Verdict includes rationale
[x] Rollback safety assessed
[x] Previous review comments checked (PR mode)
[x] Each comment is max 2 sentences
```

**A prose summary is NOT acceptable.** The checklist format exists so Ivan can scan it in 2 seconds and spot any `[ ]`.

---

## Step 5: Present findings, save review, then wait (mandatory gate)

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
  (post all) post all comments
  (blocking) post only Blocking comments
  (suggestions) post Blocking and Suggestions comments
  (nits) include Nits too
  (c) one by one - review each individually
  (d) post nothing and take no GitHub review action
  (numbers) e.g. "1, 3, 5" - post only those
  (edit N) - change a comment before posting
  (approve) submit GitHub approval with no inline comments
  (request changes) submit GitHub request changes using the Blocking summary
```

Before stopping, save the review to vault using the mandatory save block below. Saving is not optional and is not a user choice.

If there are zero findings, save the review, report `No GitHub actions performed`, and do not ask for `s`. Wait only if Ivan explicitly wants a GitHub approval.

**STOP HERE and WAIT for user response after saving.** Do NOT proceed to Step 6 until Ivan explicitly chooses a GitHub action. If the user doesn't respond, ask only: "Which GitHub action should I take, if any?"

### Save review to vault (mandatory)

Always save the review locally before asking for optional GitHub actions.

**Directory**: resolve `REVIEWS_DIR` using the review routing rules above.

**File naming**: `<PR_NUMBER>--<REPO>--<BRANCH_SLUG>--round-<N>.md`

```bash
# Detect round number (check for existing files with same PR+repo+branch prefix)
REVIEWS_DIR="<resolved review directory>"
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

Run only if Ivan explicitly chooses `approve` or `request changes` after Step 5.

Do not infer a GitHub review action from the verdict. The verdict is local review guidance; the GitHub review action is an external side effect and requires Ivan's explicit latest instruction.

Recommended mapping when Ivan asks what to do:

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
| `/commit` | PENDING | after review pass |
| `/create-pr` | PENDING | after commit |

**Pending actions**: [list skills that should still be run before merge]
```

**IMPORTANT**: Each pending skill MUST be invoked via the Skill tool. Never run `git commit` or `gh pr create` directly.

## Step 9: Save learnings (automatic, never skip)

After EVERY review that has findings (any tier), and after EVERY pass that applies or replies to PR review comments, save the reusable learning. This step is built into the skill so it works regardless of which tool runs it (Claude Code, Cursor, etc.).

This is not optional after reviewer feedback. If a reviewer comment caused a code change, a reply, a clarified convention, or a "we should have checked X first" moment, save the reusable lesson before the final response to Ivan. Do not leave the learning only in an inline GitHub comment or Radar message.

### What to save

For each finding that meets ANY of these criteria:

- A new pattern not yet in `~/.agents/skills/codereview/references/learnings.md` or `~/.agents/skills/codereview/references/known-gotchas.md`
- A false positive you almost posted (save WHY it was wrong to prevent recurrence)
- A cross-service interaction that wasn't obvious from the diff alone
- A codebase convention you discovered during Step 2 context gathering
- A reviewer comment that exposed a missing guardrail, unclear product/config boundary, or better local pattern

### How to save

1. **Append to `~/.agents/skills/codereview/references/learnings.md`** using this format:

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

3. **If promoted to Common Mistakes**, update `~/.agents/skills/codereview/references/known-gotchas.md` with the new pattern

### When to skip

Only skip if the review/comment pass was fully clean (APPROVED, zero findings across all tiers, no actionable reviewer comments) AND no new patterns were discovered during context gathering. Even "LGTM" reviews can discover learnings in Step 2.

## Step 10: Export for other instance (always ask)

At the end of every review, ask Ivan:

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

- **Directory**: the context-aware `REVIEWS_DIR` resolved before the review
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
- Risk-tiered workflow is mandatory: never skip Step 2, but keep context depth proportional to risk. A "looks good" without evidence is a failed review; a low-risk review that loads every external source is waste.
- Inline only: findings about lines not in the diff are skipped entirely. Why: commenting on pre-existing code is out of scope and creates resentment.
- Report ALL findings across ALL tiers. Never cap, filter, or omit findings. Why: the reviewer (Ivan) decides what to post, not the tool. Suppressing findings means bugs slip through.
- Balance nit volume: if Nits exceed 5 items, present all but recommend which ones are highest-impact to post. A review with 15 nits and 0 bugs is noise. Show all, suggest posting top 5.

## Ubuntu portability

Use project AGENTS.md for client facts, knowledge sources, worktrees and infrastructure.
The source machine paths are resolved by the installer. Optional MCPs and Radar require
separate target provisioning. Private histories are local placeholders. Do not assume
the source vault exists. Existing user authorization overrides redundant permission
prompts. When a required local skill/resource is missing, report it instead of claiming
that this package provisioned an external service.
