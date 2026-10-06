---
name: create-pr
description: 'Create a pull request with comprehensive technical format and monitor CI pipeline. Use when the user says "create pr", "open pr", "send the pr", "make the pr".'
---

# Create Pull Request

## Codex Adaptation

Converted from `__HOME__/.agents/skills/create-pr/SKILL.md`.
Claude-only frontmatter fields such as `model`, `allowed-tools`, `argument-hint`, and `compatibility` were removed because Codex discovers skills through `name` and `description`.
Original Claude model hint: `haiku`. In Codex, use tier-approved model overrides for subagents because `spawn_agent` otherwise inherits the parent model.
Use Codex tools and MCPs available in the current session. If a named Claude MCP is unavailable, state the gap and use the closest safe local source.
Do not mutate Slack, Jira, Confluence, GitHub, Datadog, CI/CD, infrastructure, or production systems without explicit approval.
Use Codex subagents only when current system or user instructions explicitly allow delegation.

## Parallel Agent Policy

Invoking `create-pr` is not a blanket request for parallel fan-out. Use parallel read-only subagents for PR readiness checks only when the change spans multiple repos, services, or validation surfaces. External GitHub mutations remain parent-agent actions and still require the normal approval gates.

Cost model: PR readiness subagents use cheap read-only roles. Spawn `reviewer`/`researcher` subagents with `model="gpt-5.4-mini"` and `reasoning_effort="low"` explicitly as best effort. Verify the runtime log before assuming the override was honored; if Codex inherits the parent model, reduce fan-out breadth. Keep PR body synthesis and final risk judgment in the parent. Do not escalate model/effort for routine PR creation.

Default fan-out slices:

- `reviewer`: local diff readiness, risky files, and missing tests.
- `researcher`: PR template, feature docs, Manual-E2E recipe, and source links.
- `researcher`: recent CI failures, known repo pitfalls, and validation commands.
- `researcher`: related PRs or paired frontend/backend branches.

Do not delegate `gh pr create`, pushes, comments, approvals, or CI reruns.

## Token Economy Rules (MANDATORY)

- Prefix noisy shell commands with `rtk`, especially `git diff`, `git log`, `gh`, tests, and build output.
- Keep reads selective. This skill runs late in the workflow, often after compaction.
- Generate PR body in a temp file and use `--body-file`; never paste the full body into conversation.
- Run focused validation first. Escalate only when the change risk warrants it.
- Use subagents only for multi-repo or multi-surface readiness checks.
- Start with branch/base sanity before running builds or generating PR text.
- Never use `gh pr checks --watch`. Use bounded polling and summarized JSON/JQ output.
- If the branch diff is unexpectedly large or merge/rebase would pull unrelated files, stop and ask Ivan before continuing.

## References

| File                                                   | Content                                                                           |
| ------------------------------------------------------ | --------------------------------------------------------------------------------- |
| [references/pr-template.md](references/pr-template.md) | PR body template, content generation guide, diagram pipeline                      |
| [references/ci-monitor.md](references/ci-monitor.md)   | CI monitoring workflow: polling, failure triage, local fix plan, escalation rules |
| [references/learnings.md](references/learnings.md)     | Lessons from past PR sessions (review before each PR)                             |

## Working Directories and Artifact Routing

1. **Vault root**: `__VAULT_ROOT__`
2. **Company-neutral artifacts**: use the matching project under `Personal Projects/`.
3. **Luxury Escapes artifacts**: use `Luxury-Escapes/Development/` only for explicit Luxury Escapes context or `EXP-*`/`BUG007-*` work.
4. **Other company artifacts**: use that company's existing project convention.
5. **Codebase**: derive from the repository named by the user or the current working directory.

## Worktree Detection (MANDATORY before ANY git command)

After compaction, the worktree path is lost. ALWAYS re-detect it before proceeding.

```bash
# Extract ticket from conversation context or arguments
TICKET="EXP-XXXX"  # from $ARGUMENTS or conversation

# Find the worktree for this ticket
WORKTREE=$(rtk find __CODEBASE_ROOT__ -maxdepth 1 -type d -name "*${TICKET,,}*" -o -name "*$(echo $TICKET | tr '[:upper:]' '[:lower:]' | tr '-' '')*" 2>/dev/null | sed -n '1p')

# Fallback: list all worktrees from all repos
rtk git -C __CODEBASE_ROOT__/svc-experiences worktree list 2>/dev/null | rg -i "$TICKET"
rtk git -C __CODEBASE_ROOT__/www-le-admin worktree list 2>/dev/null | rg -i "$TICKET"
rtk git -C __CODEBASE_ROOT__/svc-reporting worktree list 2>/dev/null | rg -i "$TICKET"
```

**If worktree found**: Use that path for ALL subsequent git commands. NEVER use the main repo path.
**If NOT found**: STOP and ask the user. Do NOT fall back to the main repo.
**If on master**: STOP. You are in the wrong directory. Re-detect the worktree.

This prevents the critical bug where post-compaction /create-pr goes to the main repo on master, tries to push master, and loses track of the feature branch.

---

## Pre-checks

1. Verify not on the base branch (`master`/`main`) or `prod`. If so, you are likely in the WRONG directory (main repo instead of worktree). Re-run worktree detection above.
2. Check for uncommitted work, commit first if needed.
3. **Base sanity gate (mandatory, run before CI/build/PR body)**:
   ```bash
   rtk git fetch origin master
   BRANCH=$(rtk git branch --show-current)
   BASE=$(rtk git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's#^refs/remotes/origin/##')
   [ -z "$BASE" ] && BASE="master"
   rtk git status --short --branch
   rtk git log --oneline "$BASE..HEAD" -10
   rtk git diff "$BASE...HEAD" --stat
   rtk git diff "$BASE...HEAD" --name-only
   rtk gh pr list --head "$BRANCH" --state all --json number,state,mergedAt,url,title,baseRefName --jq '.[] | {number,state,mergedAt,url,title,baseRefName}'
   ```

   Stop before local CI or PR body generation when any of these are true:
   - the current branch already has a merged PR
   - the diff stat includes unrelated files or an unexpectedly large file count
   - `gh pr view` reports `mergeable: CONFLICTING`
   - updating from base would require `git merge origin/master`, `git merge origin/main`, or rebase

   In those cases, report the compact evidence and ask Ivan whether to create an incremental branch, cherry-pick the intended commits, or update the current branch.
4. **For Luxury Escapes tickets, verify Manual-E2E-Recipe exists (mandatory, blocks PR creation)**:
   ```bash
   VAULT="__VAULT_ROOT__/Luxury-Escapes"
   TICKET=$(rtk git branch --show-current | rg -o 'EXP-[0-9]+|BUG007-[0-9]+' -m 1)
   RECIPE=$(rtk find "$VAULT/Development/Features" -maxdepth 3 -name "Manual-E2E-Recipe.md" -path "*${TICKET}*" 2>/dev/null | sed -n '1p')
   [ -n "$RECIPE" ] && echo "E2E Recipe: $RECIPE" || echo "WARN: No Manual-E2E-Recipe.md found for $TICKET"
   ```
   If missing: create the recipe manually in the feature folder. Do NOT proceed without it.
   If the feature is docs-only or config-only (no testable behavior), skip with note "N/A: config-only change".
5. **Run scoped CI validation (mandatory, blocks PR creation)**:

   This is the ONLY place in the workflow where tests run. Not in /commit.

   ### Step 4a: Environment setup

   ```bash
   # Run from the service worktree with the tool workdir set to that path.
   source ~/.nvm/nvm.sh && nvm use && rtk yarn lint
   # NOT: nvm use in one command, then yarn lint in a separate command.
   ```

   ### Step 4b: Fast checks (foreground)

   IMPORTANT: Every shell command is a new shell. Always include `source ~/.nvm/nvm.sh && nvm use &&` in Node/Yarn commands.

   ```bash
   source ~/.nvm/nvm.sh && nvm use && rtk yarn lint
   ```

   ```bash
   source ~/.nvm/nvm.sh && nvm use && rtk yarn test:types   # skip if command not found
   ```

   ### Step 4c: Build (foreground, depends on types)

   ```bash
   source ~/.nvm/nvm.sh && nvm use && rtk yarn build
   ```

   ### Step 4d: Scoped tests (background, ONLY changed files)

   NEVER run the full test suite. Only test files related to the branch changes:

   ```bash
   # Option 1: changedSince (preferred)
   source ~/.nvm/nvm.sh && nvm use && rtk yarn test:unit --changedSince=origin/master

   # Option 2: findRelatedTests (fallback). First list changed files, then run a second command with explicit paths.
   rtk git diff --name-only origin/master...HEAD -- '*.ts' '*.tsx'
   source ~/.nvm/nvm.sh && nvm use && rtk yarn test:unit --findRelatedTests <explicit changed files>
   ```

   Run tests as a long-running Codex terminal session when they may exceed a couple of minutes. Poll the session id; do not use `sleep && tail` polling.

   ### Step 4e: On failure
   - Read the actual error output
   - Fix the issue locally when it is within the requested scope
   - Re-run only the failed check
   - Ask before committing or pushing any fix
   - **Never** create a PR with failing checks

   ### Step 4f: Report

   ```
   CI validation (svc-experiences):
   - nvm use: v22.22.2 ✓
   - yarn lint ✓
   - yarn test:types ✓ (or N/A)
   - yarn build ✓
   - yarn test:unit --changedSince ✓ (N suites, N tests)
   Ready to create PR.
   ```

   ### Exception: lightweight changes

   The following change types skip ALL local CI (lint, build, tests):
   - **SQL-only**: `.sql` files only (e.g., BQ queries in svc-reporting). No JS/TS runtime, no node_modules needed.
   - **Docs-only**: `.md`, vault files, assets.
   - **Config-only**: YAML, JSON config without code changes.

   Detection: check `rtk git diff --name-only origin/master...HEAD`. If ALL files match one of the above patterns, skip Steps 4a-4f entirely and proceed to PR creation.

   Report when skipping:

   ```
   CI validation: SKIPPED (SQL-only change, no JS/TS files in diff)
   ```

6. Confirm the base branch detected above (LE repos usually use `master`, not `main`):
   ```bash
   BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's#^refs/remotes/origin/##')
   [ -z "$BASE" ] && BASE="master"
   ```
   Use `$BASE` for all subsequent diff/log commands.
7. Read the diff stat only: `rtk git diff $BASE...HEAD --stat`
8. Read changed files SELECTIVELY (only files you need for PR body, not all). Prefer `rtk git diff $BASE...HEAD -- path/to/file` over reading entire files.
9. Prepend `GIT_EDITOR=true` to all git commands.
10. **Context budget**: This skill runs at end of session when context is low. Minimize reads. Use diff hunks, not full files.

## Verification (MANDATORY before creating PR)

- [ ] Local CI passed: lint, types, build, tests (in that order)
- [ ] Branch is up to date with base: `git log --oneline base..HEAD`
- [ ] No unintended files staged: `rtk git diff --name-only base...HEAD`
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

````markdown
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

[MANDATORY for business logic changes: at least 1 Mermaid diagram.
SKIP this section entirely for config-only or script-only changes.
NEVER use ASCII art boxes. GitHub renders Mermaid natively inside ```mermaid code blocks.
See diagram guidelines in references/pr-template.md]

---

## What have you done to test it?

| Category           | Result            | Details              |
| ------------------ | ----------------- | -------------------- |
| **Unit tests**     | X suites, Y tests | [what's new/changed] |
| **Integration**    | [status]          | [what was validated] |
| **Manual/Staging** | [status]          | [what was verified]  |

---

## Evidences (optional)

[Screenshots, GIFs, CSV results, coverage tables, logs]

---

## Summary (product perspective)

[1 paragraph plain language: what this means for the user/business. No jargon. Written for a PM.]

---

## Related

| Link                | Description |
| ------------------- | ----------- |
| Jira: [TICKET](url) | Ticket      |
| [Related PR](url)   | Context     |
````

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
- Generate Mermaid diagrams (sequence, flowchart, or graph) for business logic changes. NEVER ASCII art. GitHub renders ```mermaid blocks natively.
- Write the product summary LAST, after understanding all technical changes
- If a section doesn't apply, write "N/A" or skip it. Do NOT omit required sections without reason

## Execution

**CRITICAL: Write PR body to a temp file, then create PR using `--body-file`. This keeps the PR body OUT of the context window and survives compaction.**

1. Generate Mermaid diagrams (see [references/pr-template.md](references/pr-template.md), Diagram Guidelines section)
2. Re-run the base sanity gate if any commit, amend, merge, or rebase happened after pre-checks.
3. **Detect related PRs** (see Related PRs & Merge Order section below) before push/PR creation.
4. Push branch: `git push -u origin $(git branch --show-current)`
5. **Write PR body to temp file using the Write tool**: Write to `/tmp/pr-body-TICKET.md`. This is mandatory. Never generate the body inline in conversation.
6. **Create PR from file and delete temp file immediately**:
   ```bash
   gh pr create --draft --title "[TICKET] Description" --body-file /tmp/pr-body-TICKET.md && rm -f /tmp/pr-body-TICKET.md
   ```
   The `rm` is critical. If the temp file survives, compact will restore it (200+ lines) and cause thrashing.
7. **Present PR link(s) clearly** (MANDATORY, this is the primary output):
   ```
   PR created:
   - svc-reporting: https://github.com/lux-group/svc-reporting/pull/NNNN
   - www-le-admin: https://github.com/lux-group/www-le-admin/pull/NNNN
   ```
   Links must be visible, not buried in bash output. This is what the user needs.
8. **Self-review + bot monitor** (MANDATORY, bounded):
   a. Do not post `@claude merge review` automatically. Trigger bot review only when Ivan explicitly asks or when the repo convention for this task requires it.
   b. Read existing bot comments and risk/check summaries with bounded output:
   ```bash
   rtk gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments --jq '.[].body'
   rtk gh api repos/OWNER/REPO/issues/PR_NUMBER/comments --jq '.[] | select(.user.type == "Bot") | .body'
   ```
   c. For EACH actionable bot comment: analyze the feedback, fix if within scope, and ask before committing or pushing. Reply only after Ivan approves external GitHub comments:
   ```bash
   gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments --method POST -f body="Fixed: [explanation]" -F in_reply_to=COMMENT_ID
   ```
   d. If bot flags risk score > 2: review the RISKY OR NOT section and add mitigations if needed (edit PR body via `gh pr edit --body-file`)
9. **Run CI Pipeline Monitor workflow** (see [references/ci-monitor.md](references/ci-monitor.md)). Use bounded polling, not `--watch`. Use a subagent only when current instructions explicitly allow delegation; otherwise monitor locally with Codex terminal sessions.

**Anti-pattern**: generating the full PR body inline in conversation. The body can be 200+ lines and consumes critical context. Always use Write tool -> temp file -> `--body-file`.

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

| Dependency type                       | Merge first                | Merge second                 |
| ------------------------------------- | -------------------------- | ---------------------------- |
| DB migration that other PRs depend on | Migration PR               | Consumer PRs                 |
| Shared lib/type changes               | Lib PR                     | Service PRs that import it   |
| API contract (provider -> consumer)   | Provider PR (new endpoint) | Consumer PR (calls endpoint) |
| Independent (no dependency)           | Any order                  | Any order                    |

### PR Body Integration

If related PRs exist, add a **Merge Order** section at the end of the PR body (before Related table):

```markdown
---

## Merge Order

This PR is part of a multi-PR feature. Merge in this order:

| Order | PR                                   | Repo            | Reason                    |
| ----- | ------------------------------------ | --------------- | ------------------------- |
| 1     | #1758 - DB migration for attractions | svc-experiences | Schema must exist first   |
| 2     | **#1760 - This PR**                  | svc-experiences | Depends on migration      |
| 3     | #42 - Admin UI for attractions       | www-ee-admin    | Depends on API from #1760 |

**Status:** PR #1758 merged. This PR is next.
```

If NO related PRs are found, skip the Merge Order section entirely.

### Rules

- Always search by ticket AND parent ticket (if subtask)
- Include PRs from ALL repos, not just the current one
- Update the Merge Order status when posting (which are already merged, which are pending)
- If merge order creates a blocker (e.g., PR #1 not yet approved), warn in the PR body

## PR Review Notification (ONLY when user asks)

Do NOT automatically draft or send Slack notifications. Only notify when the user explicitly asks ("manda no slack", "notify the team", "avisa o time").

When asked, identify which team owns the repo and draft a message for the correct channel.

### Service-to-Channel Mapping

| Repo / Service                                  | Owning Team       | Slack Channel to Notify   |
| ----------------------------------------------- | ----------------- | ------------------------- |
| svc-order, lib-refunds                          | Customer Payments | `#team-customer-payments` |
| svc-payment, svc-vcc                            | Customer Payments | `#team-customer-payments` |
| svc-cart                                        | CRO               | `#team-cro`               |
| svc-search, svc-geo                             | Search            | `#team-search`            |
| svc-auth, svc-verification, svc-discovery       | EngX              | `#team-engx`              |
| svc-accommodation, svc-reservation, svc-bedbank | Hotels            | `#team-hotels`            |
| svc-tour, svc-connection-ttc                    | Tours             | `#team-tours`             |
| svc-cruise                                      | Cruises           | `#team-cruises`           |
| www-le-admin, svc-offer, svc-support            | OpEx              | `#team-op-ex`             |
| svc-membership, svc-lux-loyalty                 | LuxPlus           | `#team-luxplus`           |
| svc-flights, svc-flights-\*                     | Flights           | `#team-flights`           |
| svc-trip                                        | Trip Planner      | `#team-trip-planner`      |
| svc-reporting                                   | Data Platforms    | `#team-data`              |
| www-le-customer                                 | CRO (shared)      | `#team-cro`               |
| svc-promo, svc-content, svc-sailthru            | Marketing         | `#team-marketing`         |
| svc-agent, www-le-agent                         | Wholesale         | `#team-agent-hub`         |
| svc-business, www-le-business                   | LE Business       | `#team-business`          |

### Our vertical (no external notification needed)

| Repo / Service                                                                          | Team                        |
| --------------------------------------------------------------------------------------- | --------------------------- |
| svc-experiences, svc-ee-offer, svc-car-hire, svc-addons, svc-tag, svc-occasions, svc-fx | Experiences + WL + Car Hire |
| www-ee-admin, www-ee-customer, www-ee-vendor                                            | Experiences + WL + Car Hire |
| svc-traveller, svc-notification-proxy                                                   | Experiences + WL + Car Hire |

### Notification flow (only when user requests)

1. Check the repo name against the table above
2. If it's an **external team's repo**: draft a Slack message for the owning team's channel. Present for user approval before sending
3. If it's **our vertical's repo**: say "nosso vertical, sem notificacao necessaria"
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

After PR creation, monitor CircleCI checks for up to 20 minutes. Investigate failures, apply local fixes only when they are within the requested scope, and ask before any commit or push. Non-fixable or pre-existing failures are escalated to the user.

Full agent prompt and rules: [references/ci-monitor.md](references/ci-monitor.md)

## Luxury Escapes Feature Folder Status Update (MANDATORY after PR creation)

After a Luxury Escapes PR is created, update the feature folder status in the vault to REVIEW. Search BOTH top-level folders AND subfolders (subtasks inside parent features). Skip this section for other contexts and update their routed project artifact only when such a convention exists.

```bash
FEATURES_DIR="__VAULT_ROOT__/Luxury-Escapes/Development/Features"
TICKET="EXP-XXXX"  # extracted from branch name or arguments

# 1. Search top-level (e.g., EXP-3544 - TODO)
OLD=$(rtk find "$FEATURES_DIR" -maxdepth 1 -type d -name "${TICKET}*" | sed -n '1p')
if [ -n "$OLD" ]; then
  NEW_NAME=$(echo "$OLD" | sed 's/- [A-Z_]*$/- REVIEW/' | sed "s/${TICKET}\$/${TICKET} - REVIEW/")
  [ "$OLD" != "$NEW_NAME" ] && mv "$OLD" "$NEW_NAME"
fi

# 2. Search subfolders (e.g., EXP-3536 - REVIEW/EXP-3537 - WIP)
SUB=$(rtk find "$FEATURES_DIR" -mindepth 2 -maxdepth 2 -type d -name "${TICKET}*" | sed -n '1p')
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
  cd __HOME__/Documents/_Repositories/LuxuryEscapes/{main-repo}
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
9. **Generating PR body inline**: Writing the full PR body in conversation instead of to a temp file. The body consumes 200+ lines of context. Always use Write tool to `/tmp/pr-body-TICKET.md` then `gh pr create --body-file`.
10. **Not deleting temp files after PR creation**: If `/tmp/pr-body-*.md` files survive, compact restores them (200+ lines each) and causes autocompact thrashing. Always `rm -f /tmp/pr-body-*.md` after PR creation.
11. **Using ASCII art instead of Mermaid**: NEVER generate ASCII box diagrams. GitHub renders Mermaid natively. Use ```mermaid code blocks with sequence, flowchart, or graph syntax. ASCII art is unreadable on mobile and not interactive.

## Rules

- Every claim in the PR must be traceable to actual code in the diff
- Never write generic descriptions, be specific (file names, function names, line numbers)
- If env vars were added, show the full config chain (schema -> config -> env-variables -> Pulumi)
- If queries were added, include the actual SQL
- Code snippets should be the real code, not pseudo-code
- Diagrams should reflect the actual architecture, not a generic pattern
- Review [references/learnings.md](references/learnings.md) before starting a new PR

## Ubuntu portability

Use project AGENTS.md for client facts, knowledge sources, worktrees and infrastructure.
The source machine paths are resolved by the installer. Optional MCPs and Radar require
separate target provisioning. Private histories are local placeholders. Do not assume
the source vault exists. Existing user authorization overrides redundant permission
prompts. When a required local skill/resource is missing, report it instead of claiming
that this package provisioned an external service.
