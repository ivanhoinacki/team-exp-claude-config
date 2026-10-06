---
name: commit
description: "Commit current work with a clean, conventional message. Use when the user says \"commit\", \"save this\", \"git commit\", \"make the commit\". Do NOT use for push (that requires separate approval)."
---


# Commit Current Work

## Codex Adaptation

Converted from `__HOME__/.agents/skills/commit/SKILL.md`.
Claude-only frontmatter fields such as `model`, `allowed-tools`, `argument-hint`, and `compatibility` were removed because Codex discovers skills through `name` and `description`.
Original Claude model hint: `haiku`. In Codex, do not override the model unless Ivan explicitly asks.
Use Codex tools and MCPs available in the current session. If a named Claude MCP is unavailable, state the gap and use the closest safe local source.
Do not mutate Slack, Jira, Confluence, GitHub, Datadog, CI/CD, infrastructure, or production systems without explicit approval.
Use Codex subagents only when current system or user instructions explicitly allow delegation.


## Working Directories

1. **Vault root**: `__VAULT_ROOT__`
2. **Context root**: use `Personal Projects/` for company-neutral work or the matching company root for company work.
3. **Codebase**: derive from the repository named by the user or the current working directory.

## Token Economy Rules (MANDATORY)

- Prefix noisy shell commands with `rtk`, especially `git diff`, `git log`, and secret scans.
- Use diff stats and staged-file checks, not full diffs, unless investigating a specific file.
- Secret scanning should use staged/scoped diff and bounded output.
- Do not run tests here. Commit remains a lightweight checkpoint; validation belongs to `deslop`, `codereview`, or `create-pr`.
- If unstaged diff is broad (>20 files or >800 changed lines), stop and narrow the commit scope before staging.
- Never use full `git diff | rg` secret scans. Scan staged diff only, or explicit scoped paths.

## Worktree Detection (MANDATORY FIRST ACTION, before ANY git command)

The cwd may be the Obsidian directory (not a git repo) or already inside a worktree. Verify before proceeding.

**Step 1**: Extract ticket from conversation context (EXP-XXXX from compact summary, file paths, or branch names).

**Step 2**: Find the worktree on disk:
```bash
TICKET="exp3644"  # lowercase, no dash
rtk find __CODEBASE_ROOT__ -maxdepth 1 -type d -name "*${TICKET}*" 2>/dev/null
```

**Step 3**: Verify it's a git repo with changes:
```bash
rtk git branch --show-current
rtk git status --short
```

**Step 4**: Use that path as the command working directory for ALL subsequent git commands. In Codex, set the tool `workdir` to the worktree path instead of prepending `cd WORKTREE_PATH &&`.

**If no worktree found**: STOP and ask the user.
**If on master**: STOP. You are in the wrong directory.
**NEVER run git commands without first confirming the tool `workdir` is the worktree.**

---

## Deslop Gate (MANDATORY - check BEFORE anything else)

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

**All commands below use the worktree path from Step 2 above as the tool `workdir`.** Do not chain commands with `&&` or pipes for routine commit checks.

```bash
rtk git branch --show-current  # Must NOT be main/master
rtk git diff --stat
rtk git diff --cached --check
rtk git diff --cached -- ':!yarn.lock' ':!package-lock.json'
```

For secret scanning, keep it scoped and run a separate bounded search only if the staged diff contains suspicious additions.

---

## Process

1. **Check current branch**: `git branch --show-current`
   - If on `main` or `master`: **NEVER commit directly**. Analyze the diff to suggest a smart branch name:
     1. Run `rtk git diff --stat` to see changed files
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

2. Review changed files: `rtk git diff --stat`. If it is broad (>20 files or >800 changed lines), stop and stage only explicit paths from the current task.
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
- **Cursor CLI trailer injection**: after every commit, run `rtk git log -1 --format="%B"` to check for trailers, then strip them with a bounded edit if needed.
- Only commit when instructed
- Prepend `GIT_EDITOR=true` to all git commands
- After commit, ask if user wants to push (only if not on main)

## Common Agent Mistakes

1. **Running git in Obsidian directory**: After compact, cwd is often Obsidian (not a git repo). You MUST find the worktree first and set the command `workdir` to it. Running bare `git branch` or `git diff` from Obsidian will fail with "not a git repository".
2. **Committing unrelated changes**: Always review `rtk git diff --stat` before committing
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

## Ubuntu portability

Use project AGENTS.md for client facts, knowledge sources, worktrees and infrastructure.
The source machine paths are resolved by the installer. Optional MCPs and Radar require
separate target provisioning. Private histories are local placeholders. Do not assume
the source vault exists. Existing user authorization overrides redundant permission
prompts. When a required local skill/resource is missing, report it instead of claiming
that this package provisioned an external service.
