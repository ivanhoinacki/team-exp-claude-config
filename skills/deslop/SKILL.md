---
name: deslop
description: Remove AI-generated code slop (verbose comments, unnecessary abstractions, dead code, inconsistent patterns) from the current branch. Use after implementation and before commit/PR, or when the user says "deslop", "clean up AI code", "remove slop", "clean the code", "clean this up", "too much AI noise". Do NOT use for general refactoring (that's manual work).
allowed-tools: Bash(git *), Read, Grep, Glob, Edit
---

# Remove AI Code Slop

## Working Directories

1. **Obsidian workspace** (docs, plans, features): `__VAULT_ROOT__`
2. **Codebase** (all LE services): `__CODEBASE_ROOT__`

Check the diff against main and remove all AI-generated slop introduced in this branch.

## Common Agent Mistakes

1. **Over-removing**: Deleting code that looks "AI-ish" but was intentionally written. Always check if the pattern exists elsewhere in the file before removing.
2. **Touching unchanged code**: Cleaning up code that wasn't part of this branch's diff. Only touch lines that were added/modified in this branch.
3. **Removing useful comments**: Not all comments are slop. Domain-specific comments explaining WHY (not WHAT) are valuable. Only remove comments that state the obvious.
4. **Breaking functionality**: Removing a defensive check that actually prevents a runtime error. Before removing a try/catch or null check, verify the caller guarantees the value.
5. **Style inconsistency**: Making the cleaned code inconsistent with the rest of the file. The goal is to match existing style, not impose "better" style.

## Discovery Phase

```bash
# Get list of changed files
GIT_EDITOR=true git diff main --name-only

# Get detailed diff to see AI additions
GIT_EDITOR=true git diff main
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

1. Get the diff: `GIT_EDITOR=true git diff main --name-only`
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

  Next: /code-review (branch mode)
```
