---
name: feature-dev
model: sonnet
description: Full feature development workflow with codebase discovery, knowledge base search, implementation plan, and guided coding. Use when the user says "feature", "new feature", "start development", "plan feature", "feature-dev", "implement", "build this feature", or pastes a Jira ticket description for implementation. Do NOT use for code review (use /codereview).
argument-hint: [ticket id or feature description]
---

# Feature Development — Discovery, Plan & Implementation

## Phase 0: Vault RAG (MANDATORY, BEFORE ANYTHING ELSE)

Before any codebase exploration, consult the knowledge base the active client context declares (`~/.claude/contexts/<slug>.md`; none declared means skip). For Luxury Escapes that is `mcp__local-le-vault__query_vault(query, service_filter, client_filter="luxury-escapes")` (client_filter mandatory on client-scoped work, D13).

## Working Directories

Resolve context before discovery or writing:

1. **Vault root**: `__VAULT_ROOT__`
2. **Company-neutral / personal work**: use the artifact destination declared by the active project, or docs/ in a neutral repository.
3. **Luxury Escapes root**: `Luxury-Escapes/`.
4. **Codebase**: the repo you are in. Resolve with `git rev-parse --show-toplevel`.

Continue from the existing plan and preserve its folder. New artifacts use the destination declared by the active project; for a neutral repository, use its docs/ directory.
   Never assume a client-specific root; see rule 15 (`~/.claude/rules/15-client-context.md`).

## Common Agent Mistakes

These mistakes have been observed across feature development sessions and led to rework, rejected PRs, or production issues.

1. **Skipping discovery**: Jumping straight to coding without completing Phases 1-3. Why: discovery prevents rework. Past features that skipped it had 2-3 rework cycles when reviewers found existing utils or conflicting business rules.
2. (movida para a camada `contexts/luxury-escapes.md` em 28/08, item 4.3: era específica da LE)
3. **Ignoring existing patterns**: Writing code that doesn't match the patterns in adjacent files. Read 2-3 files in the same directory before writing new code. Why: inconsistent patterns confuse future maintainers and trigger review comments.
4. **Not consulting pitfalls.md**: The vault's pitfalls.md contains 66+ one-liner gotchas that prevent known bugs. Why: these pitfalls were each discovered the hard way. Checking takes 30 seconds, fixing the bug takes hours.
5. **Over-engineering**: Adding abstractions, configurability, or "future-proofing" that wasn't requested. Why: the user explicitly wants minimal, focused changes. Over-engineering was flagged in multiple past PR reviews as scope creep.
6. **Missing test updates**: Implementing a feature without updating or creating tests for the changed modules. Why: untested code is the #1 source of regressions and will be caught by `/code-review` anyway.
7. **Breaking the dependency chain**: Not verifying that skill chain (feature-dev -> deslop -> code-review -> commit -> create-pr) is followed. Why: each step feeds the next. Skipping deslop means code-review finds AI slop instead of real issues.
8. (movida para a camada `contexts/luxury-escapes.md` em 28/08, item 4.3: era específica da LE)

9. (movida para a camada `contexts/luxury-escapes.md` em 28/08, item 4.3: era específica da LE)

10. **Attempting to fix errors without checking KB first**: When a build/test/runtime error occurs during implementation, immediately trying to fix it without running `query_vault` + `grep pitfalls*.md`. Why: the KB has documented fixes for dozens of errors. A 2-second vault check prevents 10-minute retry loops. MANDATORY: on ANY error, check vault BEFORE attempting fix (see `08-behavioral-standards.md` rule 3).
11. (movida para a camada `contexts/luxury-escapes.md` em 28/08, item 4.3: era específica da LE)

12. **Silent error paths without observability**: Using `.catch(() => {})` or dropping Promise.allSettled rejections without logging. Why: 8 separate findings across 56 code reviews. User sees "no results" or "sold out" with zero visibility. Every catch needs at minimum `logger.warn` with context.

## References

Supporting files with detailed checklists and templates:

| File                                                                     | Content                                                                     |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| [references/discovery-checklist.md](references/discovery-checklist.md)   | Full discovery checklist with commands, search tiers, and completion matrix |
| [references/plan-template.md](references/plan-template.md)               | Implementation plan structure with all required sections                    |
| [references/local-infrastructure.md](references/local-infrastructure.md) | Docker ports, nginx proxy, pre-test checks, infra troubleshooting           |
| [references/learnings.md](references/learnings.md)                       | Lessons from past feature development (review before starting)              |
| `~/.claude/skills/codereview/references/known-gotchas.md`                 | Recurring bug patterns from past reviews. Check sections matching the domain BEFORE writing code |
| `~/.claude/skills/codereview/references/learnings.md`                     | Review learnings for the target repo/service (scan entries for the repo before implementation) |

## Autonomy Rules

Once the user approves the plan, proceed autonomously through all development steps WITHOUT asking permission for each action.

### DO autonomously (no permission needed)

- Read, write, edit any file in the project
- Create new files, directories, migrations, tests
- Run the repo's own test, lint and build scripts (read them from the manifest; never assume yarn)
- Run dev scripts (yarn dev, yarn db:migrate, yarn i18n:extract)
- Run git read commands (status, diff, log, branch) and staging (git add)
- Install dependencies (yarn add)
- Read any file from Knowledge Base or codebase
- Refactor, rename, delete dead code
- Create and run database migrations locally (dev/test environments)
- Fix lint errors, type errors, test failures
- Iterate on implementation until tests pass

### REQUIRES explicit permission (stop and ask)

- `git commit` — ALWAYS ask before committing
- `git push` to remote
- Opening a PR (`gh pr create`)
- Sending Slack messages (reading/searching is auto-approved)
- Running queries on production database
- DELETE operations on any database (even local, confirm first)
- Destructive git operations (force push, reset --hard, branch -D)
- Changes outside the scope of the current feature
- Adding new external dependencies that introduce significant complexity
- **ANY change of strategy or approach**: if something fails, an error occurs, or you think there's a better way, STOP and ask before pivoting. Never silently change direction. Explain what happened and present options

### ALWAYS do

- After completing each phase or significant step, suggest what comes next
- When facing a decision with trade-offs, present options with recommendation and **ASK which one to follow** before proceeding
- When stuck or hitting an unexpected blocker, **STOP, explain what happened, and ASK** how to proceed. Never silently try a different approach
- When an error occurs during implementation, **STOP and ASK** before changing strategy. Present what failed and what options exist
- When working on a multi-ticket feature, reference the merge order from the implementation guide
- After implementation is complete, suggest: `/code-review` -> `/create-pr`
- Before running tests that need infra (DB, Redis, APIs), verify containers are up

---

## Phase 1: Understand

Read the feature description from $ARGUMENTS or ask the user to describe:

- What: what needs to be built
- Why: business value, user impact
- Ticket: Jira link if available

If a Jira ticket is provided, fetch it:

```bash
# Via the tracker integration the active client declares, if any (see rule 15).
# None configured today: ask __USER_NAME__ to paste the ticket, do not invent its content.
```

## Phase 2: Knowledge Base & Context Search

Search the company knowledge base BEFORE any planning. Full checklist in [references/discovery-checklist.md](references/discovery-checklist.md).

**Required searches (in order):**

1. **Client knowledge base, FIRST (only if the active context declares one)** — Semantic search on indexed LE knowledge (Chroma collection `le-vault`). Call `query_vault` with feature/ticket keywords, domain terms, and `service_filter` when the target service is known (e.g. `svc-experiences`, `www-le-customer`). Use `list_vault_sources` if you need available `type_filter` / service names. Absorb review learnings, business-rule snippets, runbooks, and pitfalls from results before deeper file reads.
2. **Service chain & terminology** — for Luxury Escapes only, read `Runbooks/Experiences-Ecosystem.md` and `Runbooks/Luxury-Escapes-Ecosystem.md`. For other contexts, use the routed project's architecture sources. Identify ALL services in the data flow.
3. **Business Rules** — use the business-rule source declared by the active client context. For Luxury Escapes, check `Luxury-Escapes/Knowledge-Base/Business-Rules/`.
4. **Pitfalls** — use the pitfalls source declared by the active client context. Do not assume Luxury Escapes rules for another company.
5. **Local KB mirror** — for Luxury Escapes only, search `Luxury-Escapes/Knowledge-Base/Confluence/`. For other contexts, use the knowledge source declared by the active client context.
6. **Confluence via MCP** — minimum 3 queries across Tier 1 spaces (PE, TEC, ENGX), read full pages
7. **Slack** — minimum 2 keyword queries using ALL terminology aliases across team channels, read full threads
8. **GitHub PRs** — `gh pr list --repo lux-group/REPO --search "KEYWORD" --state merged --limit 5`, read PR bodies for rationale and trade-offs
9. **Git history** — `git log --oneline --all -15 -- path/to/changed/area`

**Output:** list relevant docs found, context extracted, gaps to investigate.

## Phase 3: Codebase Discovery

Analyze the actual codebase to understand existing patterns. Full checklist in [references/discovery-checklist.md](references/discovery-checklist.md).

**Required analysis (per target service):**

1. **Project structure**: Bash `ls src/`
2. **Similar features**: Grep tool — pattern `DOMAIN_TERM`, path `src/`, glob `*.ts`
3. **Test patterns**: Glob tool — pattern `**/*.test.ts` in the feature area, then Read 1-2 files
4. **Validation patterns**: Grep tool — pattern `joi|zod|strummer|schema`, path `SERVICE/src/`, output `files_with_matches`, head_limit 5
5. **Error handling**: Grep tool — pattern `throw|AppError|HttpError|createError`, path `SERVICE/src/`, glob `*.ts`, output `files_with_matches`, head_limit 5
6. **Config patterns**: Glob tool — pattern `**/config*` and `**/schema.ts` in `SERVICE/src/`
7. **Existing enums/types**: Grep tool — pattern `export enum|export type|export interface`, path `SERVICE/src/models/`, glob `*.ts`, head_limit 10 (NEVER hardcode values that already exist as enums)
8. **Existing utils**: Bash `ls src/utils/ 2>/dev/null` (reuse before creating new)

**Service-specific architecture patterns**: derive from the repo (read 2-3 adjacent files).
Cross-repo maps that live in no single repo belong to the active client context (`~/.claude/contexts/<slug>.md`).


**Key convention checks (BEFORE writing code):**

- Read 2-3 files in the same directory to learn naming, export style, error patterns
- Check if the domain already has types/enums in `models/` or `types.ts` files. Use `Object.values(ExistingEnum)` in schemas, not hardcoded arrays
- Check if the domain has existing utils. Grep before creating new helper functions
- Check how the service handles env vars: Pulumi YAML -> environment-variables.ts -> config/\*.ts -> schema.ts (4-layer chain)

After completing Phases 2 and 3, present the **Discovery Checklist** table (see [references/discovery-checklist.md](references/discovery-checklist.md) section 3.3) and the **Pattern Summary**.

## Phase 3.5: Worktree Setup (parallel development)

After discovery identifies the target repo(s), set up isolated worktrees BEFORE presenting the implementation guide. This phase runs automatically, it does NOT depend on cwd being inside a git repo.

### Step 1: Identify target repos

From the discovery output (Phases 2-3), determine which repos will be modified. Common patterns:

Which repo a feature belongs to is client knowledge, not skill knowledge. Resolve from the active
client context; if it is not declared there, ask.


### Step 2: Check for active worktrees per repo

For EACH target repo, check if other worktrees already exist:

```bash
cd "$(git rev-parse --show-toplevel)"
git worktree list
```

### Step 3: Decide if worktree is needed

A worktree is **needed** if ANY of these is true:

- Other worktrees exist for this repo (parallel work detected)
- The repo's main directory is on a branch other than master/main
- The repo has uncommitted changes
- The user explicitly asked for isolation

A worktree is **NOT needed** if ALL of these are true:

- No other worktrees exist for this repo
- The repo is on master/main with no uncommitted changes
- This is the only active instance working on this repo

### Step 4: Create worktree (if needed)

> Formato de ticket vem do contexto ativo (`~/.claude/contexts/<slug>.md`); `<TICKET>` é placeholder. A skill nunca assume prefixo de empresa.

Extract the ticket number from $ARGUMENTS (e.g., `<TICKET>`).

```bash
cd "$(git rev-parse --show-toplevel)"

TICKET="<TICKET>"
TICKET_LOWER=$(echo "$TICKET" | tr '[:upper:]' '[:lower:]' | tr '-' '')
REPO_NAME=$(basename $(pwd))
WORKTREE_DIR="../${REPO_NAME}--${TICKET_LOWER}"
SHORT_DESC="short-feature-name"  # from ticket title, kebab-case

# Check if worktree already exists for this ticket
if git worktree list | grep -qi "$TICKET_LOWER"; then
  echo "Worktree already exists, reusing it"
  cd "$(git worktree list | grep -i "$TICKET_LOWER" | awk '{print $1}')"
else
  git fetch origin master
  git worktree add "${WORKTREE_DIR}" -b "feat/${TICKET}-${SHORT_DESC}" origin/master
  cd "${WORKTREE_DIR}"
  nvm use 2>/dev/null; yarn install --frozen-lockfile
fi
```

Repeat for each target repo that needs a worktree.

### Step 5: Switch session to worktree

After creating the worktree, ALL subsequent phases (implementation guide, implementation, tests) run inside the worktree directory. Use absolute paths when referencing the worktree.

Report to user:

```
Worktree setup:
  svc-experiences--<ticket> -> feat/<TICKET>-attractions-dashboard (based on master)
  www-ee-admin--<ticket>    -> feat/<TICKET>-attractions-dashboard (based on master)
  Deps installed. Continuing inside worktrees.
```

### Naming convention

| Component | Format                     | Example                         |
| --------- | -------------------------- | ------------------------------- |
| Directory | `{repo}--{ticket}`         | `svc-experiences--<ticket>`      |
| Branch    | `feat/<TICKET>-short-desc` | `feat/<TICKET>-umbrella-offers` |

### Post-setup: service-specific fixups

After worktree creation and `yarn install`, apply service-specific fixes:

| Service             | Required fixup                                                                   |
| ------------------- | -------------------------------------------------------------------------------- |
| **Any repo** | copy gitignored local files the repo needs; per-client specifics live in the client context |

### Skip worktree when

- Current working directory is already a worktree for this ticket
- No other worktrees/branches active in the target repo (single instance, clean master)
- The user says "no" when informed

## Phase 4: Implementation Guide (MANDATORY structure)

Generate the implementation guide using KB context + codebase patterns. Present to user for approval.

### Single-ticket vs Multi-ticket features

| Scenario                                                                | Guide structure                                                                       |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Single ticket** (e.g., <TICKET>)                                      | One implementation guide for the whole ticket                                         |
| **Parent + subtasks** (e.g., <TICKET> with children <TICKET>/3539/3540) | One guide per subtask, each self-contained with its own scope, steps, and merge order |
| **Multi-service feature** (e.g., backend + admin + customer)            | One guide per service/PR, with cross-references and merge order                       |

For multi-ticket features, generate guides in dependency order (the first guide to implement should be the one with no dependencies on other guides).

### Implementation Guide Template

The guide MUST follow this exact structure (every section required):

```markdown
# Implementation Guide: <TICKET> - [Short Title]

## Summary / Context

- What and why (1-2 sentences)
- Where it fits in the system
- Parent ticket (if subtask): <TICKET>

## Scope

- In scope / out of scope
- [ ] Acceptance criteria as checkboxes

## Step-by-step Plan

| Step | Action       | File(s)                  | Pattern Reference         |
| ---- | ------------ | ------------------------ | ------------------------- |
| 1    | [what to do] | [files to create/modify] | [existing file to follow] |

## Implementation Order

migration -> model/types -> service/context -> API/controller -> tests -> frontend

## Quality Standards

- **Correctness**: logic correct, edge cases, feature flags, async/await
- **Security**: no injection, no secrets, inputs validated at boundaries
- **Performance**: no N+1, bulk DB writes, no event loop blocking
- **Error handling**: errors not silenced, cleanup paths, timeouts
- **SOLID**: SRP, focused functions, no dead code, no over-engineering
- **Testing**: unit tests for new functions, mocks with real signatures
- **Consistency**: follows existing codebase patterns

## What to Use

- Stack, libs, patterns (from discovery, not invented)
- Reference actual files: "follow pattern in src/contexts/booking/context.ts"

## Risks / Dependencies / Blockers

- Technical risks + mitigation
- External dependencies (other teams, APIs)
- Questions for PM/stakeholder

## Merge Order

Define the merge sequence for this PR relative to other PRs in the same feature.

| Order | Ticket   | Repo            | PR  | Dependency                      |
| ----- | -------- | --------------- | --- | ------------------------------- |
| 1     | <TICKET> | svc-experiences | TBD | None (DB migration)             |
| 2     | <TICKET> | svc-experiences | TBD | Depends on #1 (uses new schema) |
| 3     | <TICKET> | www-ee-admin    | TBD | Depends on #2 (calls new API)   |

**This guide's position:** #N of M

Rules:

- DB migrations merge first (schema must exist before consumers)
- Shared lib/type changes merge before services that import them
- API providers merge before API consumers
- Independent PRs can merge in any order (mark as "parallel")
- Update this table as PRs are created (replace TBD with actual PR numbers)

## Test Plan

| Category    | Tests                     | Approach              |
| ----------- | ------------------------- | --------------------- |
| Unit        | [functions to test]       | [mocking, assertions] |
| Integration | [endpoints or N/A]        | [setup, DB seeding]   |
| Manual      | [repro steps]             | [env, customer, flow] |
| Regression  | [must NOT break]          | [existing tests]      |
| Edge cases  | [null, empty, concurrent] | [scenarios]           |

## Diagrams

[Sequence diagram of main flow in PlantUML]

## References

- KB docs, codebase files, Jira, Figma
```

See [references/plan-template.md](references/plan-template.md) for additional content generation guidelines.

### Standard files per feature folder (4 files)

Every feature folder MUST end up with these 4 files by the time the PR is created:

```
Development/Features/<TICKET> - [STATUS]/
  Implementation-Guide.md       # Created in Phase 4 (plan)
  Test-Simulation-Plan.md       # Created in Phase 4 (test plan section, expanded during testing)
  Code-Review.md                # Created by /code-review (review findings + verdict)
```

### File naming for guides

Save each implementation guide in the feature folder:

```
Development/Features/<TICKET> - [STATUS]/Implementation-Guide.md          # single ticket
Development/Features/<TICKET> - [STATUS]/Implementation-Guide-EXP-YYYY.md # per subtask
```

For parent tickets with subtasks, also create an index:

```markdown
# <TICKET> - Feature Name

## Implementation Guides

| Order | Ticket   | Guide                             | Status      |
| ----- | -------- | --------------------------------- | ----------- |
| 1     | <TICKET> | [[Implementation-Guide-<TICKET>]] | In Progress |
| 2     | <TICKET> | [[Implementation-Guide-<TICKET>]] | Not Started |
| 3     | <TICKET> | [[Implementation-Guide-<TICKET>]] | Not Started |
```

## Local Infrastructure

Docker ports, nginx proxy routing, pre-test checks, and troubleshooting: [references/local-infrastructure.md](references/local-infrastructure.md). Read it before running integration tests or debugging infra-related failures.

## Phase 5: Implementation (after user approves implementation guide)

Execute the guide autonomously. Follow the step-by-step order. For each step:

1. Write the code following discovered patterns
2. Apply quality standards inline (don't wait for review)
3. Write tests alongside implementation (not after)
4. Run tests after each meaningful change:
   ```bash
   yarn test --changedSince=main
   ```
5. Fix any failures before moving to next step
6. **Layout validation** (when implementing frontend/visual changes) — if the feature touches CSS, styled-components, JSX layout, LuxKit/MUI components, or responsive behavior, validate visually BEFORE presenting to user:

   **Step A: Screenshot verification (Chrome DevTools MCP by default, D8)**

   ```
   navigate_page → localhost URL of the changed page
   take_screenshot at 3 viewports:
     - mobile: resize_page(375, 812) → take_screenshot
     - tablet: resize_page(768, 1024) → take_screenshot
     - desktop: resize_page(1440, 900) → take_screenshot
   ```

   If __USER_NAME__ explicitly chooses Playwright, use only the approved runner declared by the project instructions: specs in `tests/`, required `BASE_URL`, entry `scripts/run.sh`, and evidence in `artifacts/<TEST_RUN_ID>/`. Do not use a generic Playwright MCP or standalone CLI wrapper.

   Visually verify: no overflow, no broken layout, spacing consistent, text readable at all sizes.

   **Step B: CSS inspection (chrome-devtools MCP)**

   ```
   For key elements changed (selector S), via evaluate_script:
     - getComputedStyle(document.querySelector(S)) → verify spacing, font, color
     - document.querySelector(S).getBoundingClientRect() → verify box model
     - matchMedia("(max-width: <bp>px)").matches → verify responsive breakpoints
   ```

   **Step C: Design comparison (imugi MCP, only if Figma link exists)**

   ```
   imugi_figma_export → export Figma frame as PNG
   imugi_compare → design vs localhost screenshot (SSIM + heatmap)
   Score < 95%? → imugi_iterate (auto-correct loop until score > 95% or max 3 iterations)
   ```

   **Skip layout validation when**: backend-only changes, logic-only changes inside components (no JSX/style), test-only files, or dev server cannot start.

7. **Deslop before presenting** — before showing code to the user or committing, self-review every file touched and remove:
   - Comments a human wouldn't write or that are inconsistent with the rest of the file
   - Unnecessary defensive try/catch blocks (especially on trusted/validated codepaths)
   - Casts to `any` to work around type issues, fix the types instead
   - Over-engineering: abstractions for one-time operations, unnecessary helpers
   - Verbose error messages that expose internals
   - Redundant type annotations where inference is sufficient
   - Console.log or debug leftovers
   - Any style inconsistent with the surrounding file
8. Commit logically grouped changes (don't accumulate a giant diff)

The code the user sees must already be clean. Deslop is not a separate step, it's part of writing code.

Commit format (no trailers):

```
Short title (< 80 chars)

- Bullet 1
- Bullet 2
```

## Verification (MANDATORY before moving to /deslop, check against implementation guide)

### Pattern compliance

- [ ] File location matches service architecture (context in contexts/, queries in queries/, not mixed)
- [ ] File naming matches adjacent files (kebab-case dirs, camelCase files, correct suffixes)
- [ ] Export pattern matches adjacent files (default vs named, barrel index.ts)
- [ ] No new utils/helpers created when existing ones could be reused (grep first)
- [ ] No hardcoded enum values when TypeScript enum already exists (use `Object.values()`)

### Code quality

- [ ] No `any` types, no `as` assertions on external data (use Zod/Strummer validation)
- [ ] No hardcoded values that should be config/env vars
- [ ] Null guards on all external data (provider APIs, DB results, JSON.parse)
- [ ] `await` on every async call (no floating promises)
- [ ] Timeout set on external HTTP calls
- [ ] No `forEach` with async callback (use `for...of` or `Promise.all`)

### Testing

- [ ] Tests exist and pass for all new code paths: `yarn test --changedSince=main`
- [ ] Happy path + edge case + error path tested
- [ ] Mocks match real signatures (not `jest.fn()` without type)
- [ ] No hardcoded dates in tests (use `jest.useFakeTimers()`)

### Frontend layout (when changes touch CSS/HTML/styled-components/JSX layout)

- [ ] Chrome DevTools screenshots taken at 3 viewports (375px, 768px, 1440px)
- [ ] No overflow, broken layout, or unreadable text at any viewport
- [ ] chrome-devtools: computed styles, box model verified on key elements
- [ ] Figma comparison done (if Figma link exists): imugi score > 95%
- [ ] Responsive breakpoints work correctly (no layout jumps)
- [ ] Existing design system components used (LuxKit, MUI) instead of custom CSS

### Business rules

- [ ] pitfalls.md checked for relevant domain
- [ ] Business Rules KB checked: list which files were read and any rules that apply
- [ ] No known business rule violated (if a rule conflicts with the plan, flag to user)
- [ ] Implementation matches approved implementation guide (no scope creep)
- [ ] Merge order from implementation guide is correct and updated with PR numbers
- [ ] Feature flag used if needed for gradual rollout
- [ ] If env vars added: 4-layer chain verified (Pulumi -> env-vars -> config -> schema)

## Phase 6: Wrap-up

After implementation is complete:

1. Run full test suite, fix any failures
2. Suggest next steps:

   ```
   Implementation complete. Running /compact before next step.
   Next: /deslop
   ```

   **IMPORTANT**: ALWAYS run `/compact` after implementation completes, BEFORE suggesting /deslop. The implementation phase consumes most of the context. Without compacting, /deslop and /commit will fail with "Context limit reached".

3. If running inside a worktree, remind the user:

   ```
   This dev was done in worktree: svc-experiences--<ticket>
   After the PR is merged, clean up with:
     git worktree remove ../svc-experiences--<ticket>
   ```
