---
name: feature-dev
description: "Full feature development workflow with codebase discovery, knowledge base search, implementation plan, and guided coding. Use when the user says \"feature\", \"new feature\", \"start development\", \"plan feature\", \"feature-dev\", \"implement\", \"build this feature\", or pastes a Jira ticket description for implementation. Do NOT use for bug fixes (use debug-mode or investigation) or for code review (use codereview)."
---


# Feature Development - Discovery, Plan & Implementation

## Codex Adaptation

Converted from `__HOME__/.agents/skills/feature-dev/SKILL.md`.
Claude-only frontmatter fields such as `model`, `allowed-tools`, `argument-hint`, and `compatibility` were removed because Codex discovers skills through `name` and `description`.
Original Claude model hint: `sonnet`. In Codex, use tier-approved model overrides for subagents because `spawn_agent` otherwise inherits the parent model.
Use Codex tools and MCPs available in the current session. If a named Claude MCP is unavailable, state the gap and use the closest safe local source.
Do not mutate Slack, Jira, Confluence, GitHub, Datadog, CI/CD, infrastructure, or production systems without explicit approval.
Use Codex subagents only when current system or user instructions explicitly allow delegation.

## Default Mode: Continue From Existing Plan

In Ivan's workflow, `feature-dev` usually runs **after** an investigation or study has already produced an implementation plan. The default behavior is therefore:

1. Read the provided implementation-plan path or infer it from the ticket/session.
2. Query `local-le-vault` for focused pitfalls and business rules using the mandatory Phase 0 client and service filters.
3. Verify only the plan assumptions that are risky, stale, contradicted, or explicitly questioned.
4. Reuse existing worktrees or create required worktrees.
5. Implement the plan with scoped code reads and focused validation.

Do not repeat full discovery by default. Full discovery belongs to `study` or `investigation`, or to `feature-dev` only when Ivan explicitly asks for it or when the existing plan is missing, stale, contradicted by evidence, or unsafe to implement.

At the start, state one of these modes explicitly:
- `feature-dev mode: continue from existing plan`, default when a plan path or ticket plan exists.
- `feature-dev mode: full discovery`, only when Ivan explicitly asks or no usable plan exists.

In continue mode, do not load discovery references, old PR bodies, Slack history, or broad git history unless a specific plan assumption needs verification.

## Token Economy Rules (MANDATORY)

- Prefix noisy shell commands with `rtk`, especially `git diff`, tests, build output, `gh`, and process inspection.
- Remote GitHub CLI commands require network access. When using `exec_command` for `rtk gh pr view`, `rtk gh pr list`, `rtk gh api`, `rtk gh search`, or other GitHub remote reads, request `sandbox_permissions="require_escalated"` on the first attempt with a narrow `prefix_rule`. Do not first run remote `gh` inside the sandbox just to observe `error connecting to api.github.com`.
- Prefer bounded reads: `rg`, `rg --files`, `sed -n`, `nl -ba`, and per-file diff hunks.
- Load skill references only on demand. Do not bulk-read templates or reference files.
- Prefer focused validation first. Escalate to build/full tests only when the risk or blast radius warrants it.
- Use agents only when the task is genuinely parallel, multi-repo, or ambiguous enough to justify duplicated context.
- Keep implementation output short: changed files, validation, residual risk, next step.
- If a command or read would touch broad history, archived sessions, lockfiles, snapshots, or generated files, narrow it first or explain why it is necessary.

## Parallel Agent Policy

Invoking `feature-dev` is not, by itself, a request for broad discovery fan-out. Use parallel read-only subagents only for multi-service, multi-repo, context-heavy, or contradicted-plan work where the extra context cost is justified. Implementation can use worker agents only after the parent agent has a clear plan, Ivan has approved that plan or the implementation request is already unambiguous, and disjoint file ownership is defined.

Cost model: use cheap read-only roles for context gathering and balanced code roles for scoped implementation. Spawn `researcher` subagents with `model="gpt-5.4-mini"` and `reasoning_effort="low"` as best effort. Spawn `implementer` subagents with `model="gpt-5.4"` and `reasoning_effort="medium"` as best effort. Verify the runtime log before assuming overrides were honored; if Codex inherits the parent model, reduce fan-out breadth. Keep `gpt-5.5` for parent synthesis, plan mode, contradicted plans, or high-risk decisions.

Optional discovery fan-out slices when full or targeted rediscovery is warranted:

- `researcher`: vault RAG, business rules, pitfalls, and prior feature notes.
- `researcher`: codebase discovery for target service A.
- `researcher`: codebase discovery for target service B or paired frontend/backend repo.
- `researcher`: GitHub PR history, Jira, Slack, and Confluence context.

For implementation fan-out, assign explicit ownership by repo/module and tell workers they are not alone in the codebase and must not revert others' work. Do not spawn write-capable workers while requirements, architecture, or ownership are still ambiguous.


## Phase 0: Vault RAG (MANDATORY, BEFORE ANYTHING ELSE)

Before ANY file reads, grep, ls, or codebase exploration, call `query_vault` with relevant keywords, `client_filter` set to the active client slug, and `service_filter` when known. The client filter is mandatory on client-scoped work: it excludes rows tagged for other clients while preserving neutral or legacy rows. Omit it only for an explicitly company-neutral query. This is non-negotiable and must be the FIRST action after reading the task. The vault contains pitfalls, business rules, review learnings, and patterns that prevent rework. Skip = rework.

For Luxury Escapes code changes, also reuse the shared PR review learning loop before implementation:

- Scan matching sections in `~/.agents/skills/codereview/references/known-gotchas.md` for the change domain.
- Search `~/.agents/skills/codereview/references/learnings.md` for the target repo or service.
- Surface any matched pattern as an implementation risk before editing code.

## Working Directories and Artifact Routing

Resolve context before discovery or writing:

1. **Vault root**: `__VAULT_ROOT__`
2. **Company-neutral root**: `Personal Projects/`
3. **Luxury Escapes root**: `Luxury-Escapes/`
4. **Codebase**: derive from the repository named by the user or the current working directory. Do not default to Luxury Escapes.

Continue from the existing plan and preserve its folder. If a new artifact is required without a plan, route company-neutral work under the matching project in `Personal Projects/`, Luxury Escapes tickets under the canonical `Luxury-Escapes/Development/` folder, and other company work under that company's root. A user-provided destination always wins.

## Common Agent Mistakes

These mistakes have been observed across feature development sessions and led to rework, rejected PRs, or production issues.

1. **Ignoring the plan state**: Running broad discovery when a current implementation plan already exists, or coding from a stale/suspect plan without targeted verification. Why: both waste time. Default to plan continuation, and verify only risky or contradicted assumptions.
2. **Creating new utils when one exists**: Writing a new helper function without checking if the repo already has one. Why: Diego's review on EXP-3472 flagged this. Duplicate utils diverge over time and create maintenance burden.
3. **Ignoring existing patterns**: Writing code that doesn't match the patterns in adjacent files. Read 2-3 files in the same directory before writing new code. Why: inconsistent patterns confuse future maintainers and trigger review comments.
4. **Not consulting pitfalls.md**: The vault's pitfalls.md contains 66+ one-liner gotchas that prevent known bugs. Why: these pitfalls were each discovered the hard way. Checking takes 30 seconds, fixing the bug takes hours.
5. **Over-engineering**: Adding abstractions, configurability, or "future-proofing" that wasn't requested. Why: the user explicitly wants minimal, focused changes. Over-engineering was flagged in multiple past PR reviews as scope creep.
6. **Missing test updates**: Implementing a feature without updating or creating tests for the changed modules. Why: untested code is the #1 source of regressions and will be caught by `/code-review` anyway.
7. **Breaking the dependency chain**: Not verifying that skill chain (feature-dev -> deslop -> code-review -> commit -> create-pr) is followed. Why: each step feeds the next. Skipping deslop means code-review finds AI slop instead of real issues.
8. **Wrong admin portal (www-ee-admin vs www-le-admin)**: Building a feature in the wrong admin project. www-le-admin = LE main admin (internal ops, content curation, attractions, experience management). www-ee-admin = White Label vendor/partner features. Why: EXP-3538 was built entirely in www-ee-admin, had to be redone. During discovery, always verify which portal matches the feature type.
9. **www-le-admin worktree missing public/ directory**: After creating a worktree for www-le-admin, the `public/` directory is missing (gitignored). Express BFF fails to serve pages. Fix: `cp -r ../www-le-admin/public/ ./public/` after worktree creation. Why: EXP-3538 lost time debugging empty responses.
10. **Attempting to fix errors without checking KB first**: When a build/test/runtime error occurs during implementation, immediately trying to fix it without running `query_vault` with the mandatory Phase 0 client and service filters + `grep pitfalls*.md`. Why: the KB has documented fixes for dozens of errors. A 2-second vault check prevents 10-minute retry loops. MANDATORY: on ANY error, check vault BEFORE attempting fix (see `08-behavioral-standards.md` rule 3).
11. **Feature flag missing from infra env-var allowlist**: Adding a flag to `production.ts` but forgetting `infra/svc-experiences/src/environment-variables.ts` + `Pulumi.*.yaml`. Why: Pulumi won't inject to pods, making the flag indeployable and `pulumi config set` a dead rollback mechanism. Found 3x in EXP-3559 PRs #1914/#1915/#1916. Checklist: schema.ts + all config/*.ts + environment-variables.ts + Pulumi YAML.
12. **Silent error paths without observability**: Using `.catch(() => {})` or dropping Promise.allSettled rejections without logging. Why: 8 separate findings across 56 code reviews. User sees "no results" or "sold out" with zero visibility. Every catch needs at minimum `logger.warn` with context.

## References

Supporting files with detailed checklists and templates:

| File                                                                     | Content                                                                     |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| [references/discovery-checklist.md](references/discovery-checklist.md)   | Full discovery checklist with commands, search tiers, and completion matrix |
| [references/plan-template.md](references/plan-template.md)               | Implementation plan structure with all required sections                    |
| [references/local-infrastructure.md](references/local-infrastructure.md) | Docker ports, nginx proxy, pre-test checks, infra troubleshooting           |
| [references/learnings.md](references/learnings.md)                       | Lessons from past feature development (review before starting)              |

## Autonomy Rules

Once the user approves the plan, proceed autonomously through all development steps WITHOUT asking permission for each action.

### DO autonomously (no permission needed)

- Read, write, edit any file in the project
- Create new files, directories, migrations, tests
- Run focused tests/checks first (`rtk yarn test ...`, `rtk yarn lint`, `rtk yarn build` when warranted)
- Run dev scripts (yarn dev, yarn db:migrate, yarn i18n:extract)
- Run git read commands (status, diff, log, branch) and staging (git add)
- Install dependencies (yarn add)
- Read any file from Knowledge Base or codebase
- Refactor, rename, delete dead code
- Create and run database migrations locally (dev/test environments)
- Fix lint errors, type errors, test failures
- Iterate on implementation until tests pass

### REQUIRES explicit permission (stop and ask)

- `git commit` - ALWAYS ask before committing
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

## Phase 1: Understand The Plan

If an implementation plan exists or was provided:

- Read the plan path first, using bounded reads around relevant sections.
- Extract: scope, target repos, files, acceptance criteria, validation commands, risks, and unresolved questions.
- If the plan has suspected false positives or stale assumptions, run targeted verification for those assumptions only.
- Do not run the full discovery checklist unless the plan is absent or materially unreliable.

If no implementation plan exists, stop and route to `study` or `investigation` unless Ivan explicitly asks `feature-dev` to do full discovery.

## Phase 1b: Understand Missing Plan Inputs

Read the feature description from $ARGUMENTS or ask the user to describe:

- What: what needs to be built
- Why: business value, user impact
- Ticket: Jira link if available

If a Jira ticket is provided, fetch it:

```bash
# Via MCP: mcp-atlassian jira_get_issue with issue_key
```

## Phase 2: Knowledge Base & Context Search (Only When Plan Is Missing Or Suspect)

Search the company knowledge base before planning only when the existing plan is missing, stale, contradicted, or explicitly challenged. Full checklist lives in [references/discovery-checklist.md](references/discovery-checklist.md), but load it only when needed.

**Required searches (in order):**

1. **LE Vault RAG (MCP `local-le-vault`) - FIRST** - Semantic search on indexed LE knowledge in the DB-backed vault. Call `query_vault` with feature/ticket keywords, domain terms, `client_filter` set to the active client slug, and `service_filter` when the target service is known (e.g. `svc-experiences`, `www-le-customer`). The client filter is mandatory for client-scoped work and keeps neutral or legacy rows while excluding other clients. Use `list_vault_sources` if you need available `type_filter` / service names. Absorb review learnings, business-rule snippets, runbooks, and pitfalls from results before deeper file reads.
2. **Service chain & terminology** - for Luxury Escapes only, read `Runbooks/Experiences-Ecosystem.md` and `Runbooks/Luxury-Escapes-Ecosystem.md`. For other contexts, use the routed project's architecture sources. Identify ALL services in the data flow.
3. **Business Rules** - check `Knowledge-Base/Business-Rules/` for the domain. Match task to files: booking/checkout -> `Checkout.md` + `Providers.md`, refunds -> `Refunds.md` + `Orders.md`, promos -> `Promos.md`, search -> `Search.md`, white label -> `WhiteLabel.md`, ops -> `Operations.md`. Read the full file. For each rule found, evaluate: does this affect what I'm building? Am I about to violate a known constraint?
4. **pitfalls.md** - read and check relevant domain sections. 66+ gotchas that prevent known bugs
5. **Local KB mirror** - for Luxury Escapes only, search the Confluence mirror under `Luxury-Escapes/Knowledge-Base/Confluence/`. For other contexts, use the knowledge source defined by the routed project.
6. **Confluence via MCP** - targeted queries only when the plan depends on external docs or business decisions
7. **Slack** - targeted queries only when the plan depends on human decisions not captured in the vault/plan
8. **GitHub PRs** - targeted prior-art search for changed areas, using `rtk gh` or bounded `gh` output
9. **Git history** - `rtk git log --oneline --all -15 -- path/to/changed/area`

**Output:** list relevant docs found, context extracted, gaps to investigate.

## Phase 3: Codebase Discovery

Analyze the actual codebase only for target files/modules from the plan. Full checklist in [references/discovery-checklist.md](references/discovery-checklist.md) is for missing or suspect plans.

**Required analysis (per target service):**

1. **Project structure**: Bash `ls __CODEBASE_ROOT__/SERVICE/src/`
2. **Similar features**: rg tool - pattern `DOMAIN_TERM`, path `__CODEBASE_ROOT__/SERVICE/src/`, glob `*.ts`
3. **Test patterns**: Glob tool - pattern `**/*.test.ts` in the feature area, then Read 1-2 files
4. **Validation patterns**: rg tool - pattern `joi|zod|strummer|schema`, path `SERVICE/src/`, output `files_with_matches`, head_limit 5
5. **Error handling**: rg tool - pattern `throw|AppError|HttpError|createError`, path `SERVICE/src/`, glob `*.ts`, output `files_with_matches`, head_limit 5
6. **Config patterns**: Glob tool - pattern `**/config*` and `**/schema.ts` in `SERVICE/src/`
7. **Existing enums/types**: rg tool - pattern `export enum|export type|export interface`, path `SERVICE/src/models/`, glob `*.ts`, head_limit 10 (NEVER hardcode values that already exist as enums)
8. **Existing utils**: Bash `ls __CODEBASE_ROOT__/SERVICE/src/utils/ 2>/dev/null` (reuse before creating new)

**Service-specific architecture patterns:**

| Service                   | Layers                                                                                                        | Validation                                                        | ORM                               | DB             |
| ------------------------- | ------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- | --------------------------------- | -------------- |
| **svc-experiences**       | controllers/{domain}/controller.ts + schema.ts -> contexts/{domain}/context.ts -> queries/{domain}/queries.ts | Strummer (`s.string()`, `s.enum()`, `s.integer({ parse: true })`) | TypeORM 0.3 (entities in models/) | PG16 + PostGIS |
| **svc-ee-offer**          | routes/ -> operations/ -> models/                                                                             | Strummer                                                          | Sequelize 6 (define pattern)      | PG14 + PostGIS |
| **svc-order**             | routes/ -> context/{vertical}/ -> lib/                                                                        | JSON Schema                                                       | Sequelize 6                       | PG             |
| **svc-car-hire**          | routes/ -> services/ -> prisma                                                                                | Zod                                                               | Prisma                            | PG             |
| **svc-occasions**         | routes/ -> contexts/ -> clients/                                                                              | Zod                                                               | Prisma                            | PG             |
| **www-ee-admin/customer** | pages/ -> components/ -> hooks/ -> api/                                                                       | React 19, Redux                                                   | N/A (BFF)                         | N/A            |

**Key convention checks (BEFORE writing code):**

- Read 2-3 files in the same directory to learn naming, export style, error patterns
- Check if the domain already has types/enums in `models/` or `types.ts` files. Use `Object.values(ExistingEnum)` in schemas, not hardcoded arrays
- Check if the domain has existing utils. rg before creating new helper functions
- Check how the service handles env vars: Pulumi YAML -> environment-variables.ts -> config/\*.ts -> schema.ts (4-layer chain)

After completing targeted plan verification, present only the assumptions verified, gaps found, and pattern summary. Present the full **Discovery Checklist** only when full discovery was actually run.

## Phase 3.5: Worktree Setup (parallel development)

After discovery identifies the target repo(s), set up isolated worktrees BEFORE presenting the implementation guide. This phase runs automatically, it does NOT depend on cwd being inside a git repo.

### Step 1: Identify target repos

From the discovery output (Phases 2-3), determine which repos will be modified. Common patterns:

| Feature type               | Likely repos                                            |
| -------------------------- | ------------------------------------------------------- |
| Backend experience feature | `svc-experiences`                                       |
| Admin portal feature       | `www-ee-admin` (+ `svc-experiences` if API changes)     |
| Customer-facing feature    | `www-le-customer` (+ backend service)                   |
| White label feature        | `www-ee-customer` or `www-ee-vendor` (+ `svc-ee-offer`) |
| Cross-service              | multiple repos, one worktree per repo                   |

### Step 2: Check for active worktrees per repo

For EACH target repo, check if other worktrees already exist:

```bash
cd __HOME__/Documents/_Repositories/LuxuryEscapes/{REPO}
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

Extract the ticket number from $ARGUMENTS (e.g., `EXP-3538`).

```bash
cd __HOME__/Documents/_Repositories/LuxuryEscapes/{REPO}

TICKET="EXP-XXXX"
TICKET_LOWER=$(echo "$TICKET" | tr '[:upper:]' '[:lower:]' | tr '-' '')
REPO_NAME=$(basename $(pwd))
WORKTREE_DIR="../${REPO_NAME}--${TICKET_LOWER}"
SHORT_DESC="short-feature-name"  # from ticket title, kebab-case

# Check if worktree already exists for this ticket
if rtk git worktree list | rg -qi "$TICKET_LOWER"; then
  echo "Worktree already exists, reusing it"
  cd "$(rtk git worktree list | rg -i "$TICKET_LOWER" | awk '{print $1}')"
else
  rtk git fetch origin master
  rtk git worktree add "${WORKTREE_DIR}" -b "feat/${TICKET}-${SHORT_DESC}" origin/master
  cd "${WORKTREE_DIR}"
  source ~/.nvm/nvm.sh && nvm use && rtk yarn install --frozen-lockfile
fi
```

Repeat for each target repo that needs a worktree.

### Step 5: Switch session to worktree

After creating the worktree, ALL subsequent phases (implementation guide, implementation, tests) run inside the worktree directory. Use absolute paths when referencing the worktree.

Report to user:

```
Worktree setup:
  svc-experiences--exp3538 -> feat/EXP-3538-attractions-dashboard (based on master)
  www-ee-admin--exp3538    -> feat/EXP-3538-attractions-dashboard (based on master)
  Deps installed. Continuing inside worktrees.
```

### Naming convention

| Component | Format                     | Example                         |
| --------- | -------------------------- | ------------------------------- |
| Directory | `{repo}--{ticket}`         | `svc-experiences--exp3544`      |
| Branch    | `feat/EXP-XXXX-short-desc` | `feat/EXP-3544-umbrella-offers` |

### Post-setup: service-specific fixups

After worktree creation and `yarn install`, apply service-specific fixes:

| Service             | Required fixup                                                                   |
| ------------------- | -------------------------------------------------------------------------------- |
| **Any service**     | `cp ../REPO/CLAUDE.md ./CLAUDE.md` (Service Dossier, auto-loaded by Claude Code) |
| **Any service**     | `nvm use` (Node version from `.nvmrc`, prevents pre-commit hook failures)        |
| **www-le-admin**    | `cp -r ../www-le-admin/public/ ./public/` (gitignored, Express BFF needs it)     |
| **svc-experiences** | Copy `src/config/development.ts` from main repo (gitignored)                     |

### Skip worktree when

- Current working directory is already a worktree for this ticket
- No other worktrees/branches active in the target repo (single instance, clean master)
- The user says "no" when informed

## Phase 4: Implementation Guide (MANDATORY structure)

Generate the implementation guide using KB context + codebase patterns. Present to user for approval.

### Single-ticket vs Multi-ticket features

| Scenario                                                                | Guide structure                                                                       |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Single ticket** (e.g., EXP-3537)                                      | One implementation guide for the whole ticket                                         |
| **Parent + subtasks** (e.g., EXP-3536 with children EXP-3538/3539/3540) | One guide per subtask, each self-contained with its own scope, steps, and merge order |
| **Multi-service feature** (e.g., backend + admin + customer)            | One guide per service/PR, with cross-references and merge order                       |

For multi-ticket features, generate guides in dependency order (the first guide to implement should be the one with no dependencies on other guides).

### Implementation Guide Template

The guide MUST follow this exact structure (every section required):

```markdown
# Implementation Guide: EXP-XXXX - [Short Title]

## Summary / Context

- What and why (1-2 sentences)
- Where it fits in the system
- Parent ticket (if subtask): EXP-XXXX

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
| 1     | EXP-3538 | svc-experiences | TBD | None (DB migration)             |
| 2     | EXP-3539 | svc-experiences | TBD | Depends on #1 (uses new schema) |
| 3     | EXP-3540 | www-ee-admin    | TBD | Depends on #2 (calls new API)   |

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

### Standard files per Luxury Escapes feature folder (4 files)

Every feature folder MUST end up with these 4 files by the time the PR is created:

```
Development/Features/EXP-XXXX - [STATUS]/
  Implementation-Guide.md       # Created in Phase 4 (plan)
  Test-Simulation-Plan.md       # Created in Phase 4 (test plan section, expanded during testing)
  Code-Review.md                # Created by /code-review (review findings + verdict)
  Manual-E2E-Recipe.md          # Created during implementation (how to reproduce locally)
```

The Manual-E2E-Recipe is the reviewer's entry point: environment setup, test steps, expected results, evidence. Without it, the PR is not ready.

### File naming for guides

For Luxury Escapes tickets, save each implementation guide in the feature folder:

```
Development/Features/EXP-XXXX - [STATUS]/Implementation-Guide.md          # single ticket
Development/Features/EXP-XXXX - [STATUS]/Implementation-Guide-EXP-YYYY.md # per subtask
```

For parent tickets with subtasks, also create an index:

```markdown
# EXP-XXXX - Feature Name

## Implementation Guides

| Order | Ticket   | Guide                             | Status      |
| ----- | -------- | --------------------------------- | ----------- |
| 1     | EXP-3538 | [[Implementation-Guide-EXP-3538]] | In Progress |
| 2     | EXP-3539 | [[Implementation-Guide-EXP-3539]] | Not Started |
| 3     | EXP-3540 | [[Implementation-Guide-EXP-3540]] | Not Started |
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
   rtk yarn test --changedSince=main
   ```
5. Fix any failures before moving to next step
6. **Layout/browser validation** (when implementing frontend/visual/browser changes) - if the feature touches CSS, styled-components, JSX layout, LuxKit/MUI components, responsive behavior, routes, forms, tables, auth, or browser-visible workflows, use `chrome-devtools-validation` and the `chrome-devtools` MCP family by default BEFORE presenting to user. If Ivan explicitly chooses Playwright, use only `__PLAYWRIGHT_RUNNER__`: specs in `tests/`, required `BASE_URL`, entry `scripts/run.sh`, and evidence in `artifacts/<TEST_RUN_ID>/`. Do not use a generic Playwright MCP or standalone CLI wrapper. When the validation needs multiple browser states at once, such as LE admin + customer, follow the selected browser path's isolated-context pattern. If chrome-devtools returns `Transport closed`, `tool call failed`, or `connection closed`, follow the recovery sequence in `chrome-devtools-validation` (`browser-mcp-doctor --browser chrome-devtools --profile codex-primary --cleanup`, retry once, `--still-closed`, hand off to Claude, then ask Ivan for reload/reconnect if both panes fail).

   **Step D: Design comparison (imugi MCP, only if Figma link exists)**

   ```
   imugi_figma_export → export Figma frame as PNG
   imugi_compare → design vs localhost screenshot (SSIM + heatmap)
   Score < 95%? → imugi_iterate (auto-correct loop until score > 95% or max 3 iterations)
   ```

   **Skip layout validation when**: backend-only changes, logic-only changes inside components (no JSX/style), test-only files, or dev server cannot start.

7. **Deslop before presenting** - before showing code to the user or committing, self-review every file touched and remove:
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

- [ ] Tests exist and pass for all new code paths: `rtk yarn test --changedSince=main` or a focused equivalent
- [ ] Happy path + edge case + error path tested
- [ ] Mocks match real signatures (not `jest.fn()` without type)
- [ ] No hardcoded dates in tests (use `jest.useFakeTimers()`)

### Frontend layout (when changes touch CSS/HTML/styled-components/JSX layout)

- [ ] Browser evidence collected with `chrome-devtools-validation` by default, or with `__PLAYWRIGHT_RUNNER__` only when Ivan explicitly chose Playwright: page state, console/network evidence, screenshots, responsive checks, and/or E2E flow
- [ ] No overflow, broken layout, or unreadable text at any validated viewport
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

1. Run focused validation first. Run full test suites only when the implementation risk warrants it.
2. Suggest next steps:

   ```
   Implementation complete. Running context compaction before next step.
   Next: /deslop
   ```

   **IMPORTANT**: ALWAYS run `context compaction` after implementation completes, BEFORE suggesting /deslop. The implementation phase consumes most of the context. Without compacting, /deslop and /commit will fail with "Context limit reached".

3. If running inside a worktree, remind the user:

   ```
   This dev was done in worktree: svc-experiences--exp3544
   After the PR is merged, clean up with:
     git worktree remove ../svc-experiences--exp3544
   ```

## Ubuntu portability

Use project AGENTS.md for client facts, knowledge sources, worktrees and infrastructure.
The source machine paths are resolved by the installer. Optional MCPs and Radar require
separate target provisioning. Private histories are local placeholders. Do not assume
the source vault exists. Existing user authorization overrides redundant permission
prompts. When a required local skill/resource is missing, report it instead of claiming
that this package provisioned an external service.
