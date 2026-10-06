---
name: commit
model: haiku
description: Commit current work with a clean, conventional message. Use when the user says "commit", "save this", "git commit", "make the commit". Do NOT use for push (that requires separate approval).
allowed-tools: Bash(git *), Bash(find *), Bash(cd *), Bash(ls *)
effort: low
---

# Commit Current Work

## Working Directories

1. **Vault root**: `__VAULT_ROOT__`
2. **Context root**: use the artifact destination declared by the active project, or docs/ in a neutral repository.
3. **Codebase**: the repo you are in. Resolve with `git rev-parse --show-toplevel`.
   Never assume a client-specific root. __USER_NAME__ works for more than one company; see rule 15
   (`~/.claude/rules/15-client-context.md`) for how to derive client facts from the repo.

## Worktree Detection (MANDATORY FIRST ACTION, before ANY git command)

The cwd may be the Obsidian directory (not a git repo) or already inside a worktree. Verify before proceeding.

**Step 1**: Extract ticket from conversation context (EXP-XXXX from compact summary, file paths, or branch names).

**Step 2**: Find the worktree on disk:
```bash
TICKET="exp3644"  # lowercase, no dash
git branch -a --list "*${TICKET}*"   # busca no repo atual, nao em raiz de cliente
```

**Step 3**: Verify it's a git repo with changes:
```bash
git branch --show-current && git status --short
```

**Step 4**: Use that path for ALL subsequent git commands. Prepend `cd WORKTREE_PATH &&` to every bash call.

**If no worktree found**: STOP and ask the user.
**If on master**: STOP. You are in the wrong directory.
**NEVER run git commands without first confirming you are in the worktree.**

---

## Deslop Gate (MANDATORY — check BEFORE anything else)

If the current branch has code changes (not docs/config only), verify /deslop was run:

1. Check conversation history for a prior /deslop invocation in this session
2. If NOT found: **STOP**. Tell the user:
   ```
   /deslop not run yet. Run /deslop first? (yes / skip for docs-only)
   ```
3. Only proceed if user confirms skip (docs/config only) or /deslop was already run

---

## Pre-commit Check (lightweight, no tests)

Quick sanity checks only. Full CI validation (lint, types, build, tests) happens in /create-pr.

**All commands below use the worktree path from Step 2 above.** Never run bare `git` without `cd WORKTREE_PATH &&`.

```bash
cd WORKTREE_PATH && git branch --show-current  # Must NOT be main/master
cd WORKTREE_PATH && GIT_EDITOR=true git diff --stat
cd WORKTREE_PATH && GIT_EDITOR=true git diff | grep -iE "(api.key|secret|token|password|private.key)" | head -5
```

---

## Process

1. **Check current branch**: `git branch --show-current`
   - If on `main` or `master`: **NEVER commit directly**. Analyze the diff to suggest a smart branch name:
     1. Run `GIT_EDITOR=true git diff --stat` to see changed files
     2. Infer **type** from changes:
        - New files with business logic -> `feat`
        - Modified existing logic fixing a defect -> `fix`
        - Only test files -> `test`
        - Only config/CI/deps -> `chore`
        - Only `.md` files -> `docs`
        - Restructuring without behavior change -> `refactor`
        - Performance-related changes -> `perf`
     3. Infer **scope** from file paths (e.g., `svc-experiences`, `www-le-customer`)
     4. Present suggestion and wait for user response

2. Review changed files: `GIT_EDITOR=true git diff --stat`
3. Check each file is related to the current work (don't commit unrelated changes)
4. Stage relevant files by name (avoid `git add .`)
5. Write commit message

## Commit Format

```
<type>(<scope>): <short description>

- Bullet point 1
- Bullet point 2
```

### Types

| Type     | When                                                    |
| -------- | ------------------------------------------------------- |
| feat     | New feature                                             |
| fix      | Bug fix                                                 |
| refactor | Code change that neither fixes a bug nor adds a feature |
| chore    | Build, CI, config, deps                                 |
| docs     | Documentation only                                      |
| test     | Adding or fixing tests                                  |
| perf     | Performance improvement                                 |

### Scope

The service or module affected (e.g., `svc-experiences`, `checkout`, `auth`, `infra`).

### Rules

- Title under 80 characters
- No Co-authored-by, Signed-off-by, Made-with, Made-with: Cursor, or any trailers unless user asks
- **Cursor CLI trailer injection**: after every commit, run `git log -1 --format="%B"` to check for trailers, then strip them with: `git log -1 --format="%B" | grep -v "^Made-with:" | grep -v "^Co-Authored-By:" > /tmp/clean-msg.txt && GIT_EDITOR="cp /tmp/clean-msg.txt" git commit --amend --allow-empty`
- Only commit when instructed
- Prepend `GIT_EDITOR=true` to all git commands
- After commit, ask if user wants to push (only if not on main)

## Common Agent Mistakes

1. **Running git in Obsidian directory**: After compact, cwd is ALWAYS Obsidian (not a git repo). You MUST find and cd to the worktree FIRST. Running bare `git branch` or `git diff` without `cd WORKTREE &&` will fail with "not a git repository".
2. **Committing unrelated changes**: Always review `git diff --stat` before committing
3. **Adding trailers**: Never add trailers unless user explicitly asks
4. **Committing secrets**: Always scan for sensitive content
5. **Vague commit messages**: Describe WHAT changed and WHY
6. **Using git add -A**: Always stage specific files by name

## Verification (MANDATORY before committing)

```
- [ ] Deslop gate passed (or skipped for docs-only)
- [ ] Branch is NOT main/master
- [ ] All staged files are related to current work
- [ ] No secrets in staged files
- [ ] Commit message follows format: <type>(<scope>): <description>
- [ ] No trailers added
```
