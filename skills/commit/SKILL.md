---
name: commit
model: haiku
description: Commit current work with a clean, conventional message. Use when the user says "commit", "save this", "git commit", "make the commit". Do NOT use for push (that requires separate approval).
allowed-tools: Bash(git *)
effort: low
---

# Commit Current Work

## Working Directories

1. **Obsidian workspace** (docs, plans, features): `__VAULT_ROOT__`
2. **Codebase** (all LE services): `__CODEBASE_ROOT__`

## Process

1. **Check current branch**: `git branch --show-current`
   - If on `main` or `master`: **NEVER commit directly**. Analyze the diff to suggest a smart branch name:
     1. Run `GIT_EDITOR=true git diff --stat` to see changed files
     2. Infer **type** from changes:
        - New files with business logic → `feat`
        - Modified existing logic fixing a defect → `fix`
        - Only test files → `test`
        - Only config/CI/deps → `chore`
        - Only `.md` files → `docs`
        - Restructuring without behavior change → `refactor`
        - Performance-related changes → `perf`
     3. Infer **scope** from file paths:
        - `svc-experiences/...` → `svc-experiences`
        - `www-le-customer/...` → `www-le-customer`
        - `src/checkout/...` → `checkout`
        - Multiple services → use the primary one or the shared module name
     4. Infer **description** from the nature of changes (function names, file names, test names)
     5. Present to user with context:

        ```
        You are on main. Based on the diff:
        - Type: feat (new files with business logic)
        - Scope: svc-experiences (all changed files)
        - Suggestion: feat/svc-experiences-add-complementary-filter

        Use this branch or prefer a different name?
        ```

     6. Wait for the user's response before creating the branch with `git checkout -b <name>`

   - If no branch exists (detached HEAD): analyze the diff and suggest a branch name before committing

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

- Title under 80 characters. Why: longer titles get truncated in `git log --oneline` and GitHub PR lists, losing context.
- No Co-authored-by, Signed-off-by, Made-with, Made-with: Cursor, or any trailers unless user asks. Why: both Claude Code and Cursor CLI auto-add trailers (`Co-Authored-By`, `Made-with: Cursor`) by default, which pollutes git history and conflicts with the team's commit conventions. This rule overrides those system defaults.
- **Cursor CLI trailer injection**: Cursor CLI intercepts every `git commit` and appends `Made-with: Cursor` automatically. There is no way to prevent this from inside the Cursor session. **Post-commit cleanup**: after every commit, run `git log -1 --format="%B"` to check for trailers, then strip them with: `git log -1 --format="%B" | grep -v "^Made-with:" | grep -v "^Co-Authored-By:" > /tmp/clean-msg.txt && GIT_EDITOR="cp /tmp/clean-msg.txt" git commit --amend --allow-empty`. If the amend also re-injects the trailer, warn the user to run the amend from a terminal outside Cursor.
- Only commit when instructed. Why: premature commits create noise in the branch history and the user may still be iterating on the changes.
- If `git diff` fails, use working memory of what changed.
- Prepend `GIT_EDITOR=true` to all git commands. Why: prevents git from opening an interactive editor which blocks the CLI session indefinitely.
- After commit, ask if user wants to push (only if not on main). Why: pushing is an external action with side-effects (triggers CI, notifies reviewers) and requires explicit user intent.

## Common Agent Mistakes

1. **Committing unrelated changes**: Not checking if ALL staged files are related to the current work. Always review `git diff --stat` before committing. Why: mixed commits make `git bisect` and `git revert` unreliable.
2. **Adding trailers**: Both Claude Code and Cursor CLI try to add trailers (`Co-Authored-By`, `Made-with: Cursor`). This rule overrides that. Never add trailers unless user explicitly asks. Why: the team's convention is clean commit messages; trailers add noise and were flagged in past PR reviews.
3. **Committing secrets**: Not checking for `.env`, credentials, tokens, or API keys in the staged files. Always scan for sensitive content. Why: secrets in git history require credential rotation and are a security incident.
4. **Vague commit messages**: Writing "update code" or "fix bug" instead of describing WHAT changed and WHY. Why: vague messages make git blame useless for future investigators.
5. **Using git add -A**: Staging everything including untracked files. Always stage specific files by name. Why: `git add -A` can accidentally include `.env`, `node_modules` artifacts, or unrelated work-in-progress files.

## Verification (MANDATORY before committing)

```
- [ ] Branch is NOT main/master: `git branch --show-current`
- [ ] Node version matches .nvmrc: `node -v` vs `cat .nvmrc` (pre-commit hooks fail on mismatch, run `nvm use` first)
- [ ] All staged files are related to current work: `GIT_EDITOR=true git diff --cached --name-only`
- [ ] No secrets in staged files: `GIT_EDITOR=true git diff --cached | grep -iE "(api.key|secret|token|password|private.key)" | head -5`
- [ ] Commit message follows format: <type>(<scope>): <description>
- [ ] No trailers added (Co-Authored-By, Signed-off-by, Made-with: Cursor)
```
