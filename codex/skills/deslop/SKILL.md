---
name: deslop
description: "Remove AI-generated code slop (verbose comments, unnecessary abstractions, dead code, inconsistent patterns) from the current branch. Use after implementation and before commit/PR, or when the user says \"deslop\", \"clean up AI code\", \"remove slop\", \"clean the code\", \"clean this up\", \"too much AI noise\". Do NOT use for general refactoring (that's manual work)."
---


# Remove AI Code Slop

## Codex Adaptation

Converted from `__HOME__/.agents/skills/deslop/SKILL.md`.
Claude-only frontmatter fields such as `model`, `allowed-tools`, `argument-hint`, and `compatibility` were removed because Codex discovers skills through `name` and `description`.
Original Claude model hint: `opus`. In Codex, do not override the model unless Ivan explicitly asks.
Use Codex tools and MCPs available in the current session. If a named Claude MCP is unavailable, state the gap and use the closest safe local source.
Do not mutate Slack, Jira, Confluence, GitHub, Datadog, CI/CD, infrastructure, or production systems without explicit approval.
Use Codex subagents only when current system or user instructions explicitly allow delegation.


## Phase 0: Vault RAG (MANDATORY)

Before ANY file reads, grep, or codebase exploration, call `query_vault` with relevant keywords and service_filter. This is non-negotiable. The vault contains pitfalls, business rules, review learnings, and patterns that prevent rework. Skip = rework.

## Token Economy Rules (MANDATORY)

- Prefix noisy shell commands with `rtk`, especially `git diff`, tests, build output, and process inspection.
- Remote GitHub CLI commands require network access. If deslop needs PR metadata, files, comments, or remote branch state via `rtk gh`, request `sandbox_permissions="require_escalated"` on the first attempt with a narrow `prefix_rule` such as `["rtk", "gh", "pr", "view"]`. Do not first run remote `gh` inside the sandbox just to observe `error connecting to api.github.com`.
- Do not run or paste a full branch diff by default.
- Scope deslop to files touched in the current task, files listed in the implementation plan, staged files, or explicit paths from Ivan.
- Use full branch diff only when Ivan explicitly asks for full branch deslop.
- Prefer `rtk git diff --name-only` and per-file hunks over reading complete files.
- Read complete files only when a hunk lacks enough context to decide safely.
- If `git diff --stat` shows more than 20 files or more than 800 changed lines, stop and narrow scope before reading hunks.
- Exclude unrelated merge/base churn. Do not deslop files introduced only by syncing from `origin/master`.

## Working Directories

1. **Vault root**: `__VAULT_ROOT__`
2. **Context root**: use `Personal Projects/` for company-neutral work or the matching company root for company work.
3. **Codebase**: derive from the repository named by the user or the current working directory.

Check the scoped diff for the current task and remove AI-generated slop introduced in those files. Do not clean the full branch unless Ivan explicitly asks for full-branch deslop.

## Common Agent Mistakes

1. **Over-removing**: Deleting code that looks "AI-ish" but was intentionally written. Always check if the pattern exists elsewhere in the file before removing.
2. **Touching unchanged code**: Cleaning up code that wasn't part of this branch's diff. Only touch lines that were added/modified in this branch.
3. **Removing useful comments**: Not all comments are slop. Domain-specific comments explaining WHY (not WHAT) are valuable. Only remove comments that state the obvious.
4. **Breaking functionality**: Removing a defensive check that actually prevents a runtime error. Before removing a try/catch or null check, verify the caller guarantees the value.
5. **Style inconsistency**: Making the cleaned code inconsistent with the rest of the file. The goal is to match existing style, not impose "better" style.

## Pre-Deslop Review (MANDATORY)

Before cleaning slop, review the full implementation against the original intent. This catches forgotten requirements, missing tests, and incomplete work BEFORE the code gets cleaned and committed.

### Steps

1. **Identify the task**: check branch name, recent commits, and any linked ticket (EXP-XXXX, BUG007-XXXX)
2. **Define scope first**: use explicit paths, implementation-plan paths, staged files, or task-touched files. If scope is unclear, use `rtk git diff origin/master...HEAD --name-only` and filter to files relevant to the current task.
3. **Scope guard**: run `rtk git diff origin/master...HEAD --stat`. If the stat shows broad branch churn (>20 files or >800 changed lines), do not read hunks yet. Report the stat summary and narrow to task files from the plan or ask Ivan for explicit paths.
4. **Read bounded diff only**: per-file hunks for scoped files. Do not run full `git diff` unless Ivan explicitly requested full branch deslop.
4. **Cross-reference**: if a ticket or feature doc exists, compare what was asked vs. what was implemented
5. **Produce checklist**:

```
Pre-deslop review:

Functionality:
  [x] Core requirement implemented
  [x] Edge cases handled (nulls, empty arrays, missing fields)
  [ ] Error handling covers external calls (timeouts, 4xx, 5xx)

Tests:
  [x] Unit tests for new functions
  [ ] Test for the unhappy path (error/empty/null)
  [ ] Existing tests still pass

Integration:
  [x] No breaking changes to public API/contract
  [ ] Feature flag registered in Pulumi config (if applicable)
  [ ] Migration has DOWN method (if applicable)

Observability:
  [ ] Logging on key decision points
  [ ] Metrics/histogram for new external calls (if applicable)
```

5. **Report gaps**: if anything is `[ ]`, flag it to the user BEFORE proceeding with deslop:

```
Found N gaps before deslop:
  1. Missing test for error path in fetchProvider()
  2. No logging when fallback triggers

Fix these first? (yes / skip / list only)
```

If user says "yes": fix the gaps, then proceed to deslop.
If user says "skip": proceed to deslop, mention gaps in output.

---

## Discovery Phase

```bash
# Get scoped changed files
rtk git diff origin/master...HEAD --name-only

# Read only scoped hunks
rtk git diff origin/master...HEAD -- path/to/file.ts
```

## What to Remove

### Slop Patterns (search with rg tool in changed files)

Use the rg tool (NOT bash grep) to scan for these patterns in `src/`:

**Unnecessary comments:**

- [ ] rg pattern `// This function` -> "This function does X" narration comments
- [ ] rg pattern `// TODO: ` -> TODO comments added by AI (not by user)
- [ ] rg pattern `// eslint-disable` -> Disabling lints instead of fixing

**Defensive bloat:**

- [ ] rg pattern `try \{` -> Unnecessary try/catch wrapping trusted internal calls
- [ ] rg pattern `if.*null|if.*undefined` -> Null checks on guaranteed non-null values
- [ ] rg pattern `as any` -> Type casts hiding real type issues

**Over-engineering:**

- [ ] New helper/util files with a single caller
- [ ] Abstractions wrapping a single operation
- [ ] Config objects for hardcoded values

**Debug leftovers:**

- [ ] rg pattern `console\.(log|debug|warn)` -> Console statements
- [ ] rg pattern `debugger` -> Debugger statements

### Context-Dependent (read the file to decide)

- Extra comments that a human wouldn't add or are inconsistent with the rest of the file
- Verbose error messages that expose internals
- Redundant type annotations where inference is sufficient
- Any style inconsistent with the surrounding file

## Process

1. Get candidate files: `rtk git diff origin/master...HEAD --name-only`
2. Select only files touched by the current task or listed in the implementation plan
3. If selection is still broad (>20 files or >800 changed lines), stop and ask for a narrower scope
4. Read per-file diff hunks first: `rtk git diff origin/master...HEAD -- path/to/file`
5. Read complete files only when the hunk lacks enough context to decide safely
6. For each AI addition, check if the same pattern exists in unchanged code nearby
7. Remove only clear slop, preserve intentional changes
8. Run verification checks

## Verification (MANDATORY before reporting)

```
- [ ] No functionality removed (only style/comments/bloat)
- [ ] Remaining code matches file's existing style
- [ ] No unchanged lines were modified
- [ ] Type check still passes when relevant: `rtk yarn test:types` (if available)
- [ ] Focused tests still pass when relevant. Avoid full test suites unless the change risk warrants it.
```

## Output

Report with 1-3 sentence summary:

```
Deslop complete:
  Files checked: N
  Changes made: N files modified
  Removed: [brief list of what was removed]
```

## Handoff to /commit (MANDATORY, last action)

After reporting, tell the user: "Deslop pronto. Quer que eu siga pro /commit?"

Do NOT run git commit directly from within deslop. The /commit skill should be invoked as the next step in the chain.

## Ubuntu portability

Use project AGENTS.md for client facts, knowledge sources, worktrees and infrastructure.
The source machine paths are resolved by the installer. Optional MCPs and Radar require
separate target provisioning. Private histories are local placeholders. Do not assume
the source vault exists. Existing user authorization overrides redundant permission
prompts. When a required local skill/resource is missing, report it instead of claiming
that this package provisioned an external service.
