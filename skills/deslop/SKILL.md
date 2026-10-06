---
name: deslop
model: opus
description: Remove AI-generated code slop (verbose comments, unnecessary abstractions, dead code, inconsistent patterns) from the current branch. Use after implementation and before commit/PR, or when the user says "deslop", "clean up AI code", "remove slop", "clean the code", "clean this up", "too much AI noise". Do NOT use for general refactoring (that's manual work).
allowed-tools: Bash(git *), Read, Grep, Glob, Edit
---

# Remove AI Code Slop

## Phase 0: Vault RAG (MANDATORY)

Before ANY file reads, grep, or codebase exploration, call `query_vault` with relevant keywords and service_filter. This is non-negotiable. The vault contains pitfalls, business rules, review learnings, and patterns that prevent rework. Skip = rework.

## Working Directories

1. **Vault root**: `__VAULT_ROOT__`
2. **Context root**: use the artifact destination declared by the active project, or docs/ in a neutral repository.
3. **Codebase**: the repo you are in. Resolve with `git rev-parse --show-toplevel`.
   Never assume a client-specific root. __USER_NAME__ works for more than one company; see rule 15
   (`~/.claude/rules/15-client-context.md`) for how to derive client facts from the repo.

Check the diff against main and remove all AI-generated slop introduced in this branch.

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
2. **Read the diff**: `GIT_EDITOR=true git diff origin/master --stat` + `GIT_EDITOR=true git diff origin/master`
3. **Cross-reference**: if a ticket or feature doc exists, compare what was asked vs. what was implemented
4. **Produce checklist**:

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
# Get list of changed files
GIT_EDITOR=true git diff origin/master --name-only

# Get detailed diff to see AI additions
GIT_EDITOR=true git diff origin/master
```

## What to Remove

### Slop Patterns (search with Grep tool in changed files)

Use the Grep tool (NOT bash grep) to scan for these patterns in `src/`:

**Unnecessary comments:**

- [ ] Grep pattern `// This function` -> "This function does X" narration comments
- [ ] Grep pattern `// TODO: ` -> TODO comments added by AI (not by user)
- [ ] Grep pattern `// eslint-disable` -> Disabling lints instead of fixing

**Defensive bloat:**

- [ ] Grep pattern `try \{` -> Unnecessary try/catch wrapping trusted internal calls
- [ ] Grep pattern `if.*null|if.*undefined` -> Null checks on guaranteed non-null values
- [ ] Grep pattern `as any` -> Type casts hiding real type issues

**Over-engineering:**

- [ ] New helper/util files with a single caller
- [ ] Abstractions wrapping a single operation
- [ ] Config objects for hardcoded values

**Debug leftovers:**

- [ ] Grep pattern `console\.(log|debug|warn)` -> Console statements
- [ ] Grep pattern `debugger` -> Debugger statements

### Context-Dependent (read the file to decide)

- Extra comments that a human wouldn't add or are inconsistent with the rest of the file
- Verbose error messages that expose internals
- Redundant type annotations where inference is sufficient
- Any style inconsistent with the surrounding file

## Process

1. Get the diff: `GIT_EDITOR=true git diff origin/master --name-only`
2. Read each changed file completely (not just the diff)
3. For each AI addition, check if the same pattern exists in unchanged code nearby
4. Remove only clear slop, preserve intentional changes
5. Run verification checks

## Verification (MANDATORY before reporting)

```
- [ ] No functionality removed (only style/comments/bloat)
- [ ] Remaining code matches file's existing style
- [ ] No unchanged lines were modified
- [ ] Type check still passes: `yarn test:types` (if available)
- [ ] Tests still pass: `yarn test` (if available)
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
