---
name: create-pr
model: haiku
description: Create a pull request with comprehensive technical format and monitor CI pipeline. Use when the user says "create pr", "open pr", "send the pr", "make the pr".
argument-hint: [ticket id, format depends on the client]
compatibility: Requires gh (GitHub CLI) and git. CI monitoring uses whatever CI the repo declares in .github/, .circleci/ or .gitlab-ci.yml
allowed-tools: Bash(git *), Bash(gh *), Bash(jq *), Read, Write, Edit, Grep, Glob, Agent
---

# Create Pull Request

## References (load on-demand, not upfront)

| File                                                                       | When to load                                         |
| -------------------------------------------------------------------------- | ---------------------------------------------------- |
| [references/pr-template.md](references/pr-template.md)                     | When writing PR body (template + diagram guidelines) |
| [references/ci-monitor.md](references/ci-monitor.md)                       | When launching CI monitor agent                      |
| [references/learnings.md](references/learnings.md)                         | Only if context < 60% (skip when tight)              |
| `~/.claude/contexts/luxury-escapes.d/notification-channels.md` (camada LE) | Only when user asks to notify a team, LE context only                 |

## Working Directories

1. **Vault root**: `__VAULT_ROOT__`
2. **Company-neutral artifacts**: use the artifact destination declared by the active project, or docs/ in a neutral repository.
3. **Luxury Escapes artifacts**: use `Luxury-Escapes/Development/` only for explicit Luxury Escapes context or `EXP-*`/`BUG007-*` work.
4. **Other company artifacts**: use that company's existing project convention.
5. **Codebase**: the repo you are in. Resolve with `git rev-parse --show-toplevel`.
   Never assume a client-specific root. __USER_NAME__ works for more than one company; see rule 15
   (`~/.claude/rules/15-client-context.md`) for how to derive client facts from the repo.

## Post-compact behavior

After compaction, do NOT reproduce feature analysis, architecture, or problem statements in conversation. The PR body captures that. Go straight to: detect worktree -> pre-checks -> read diff -> write PR body to temp file -> create PR.

## Worktree Detection (MANDATORY before ANY git command)

After compaction, the worktree path is lost. ALWAYS re-detect it before proceeding.

> Formato de ticket vem do contexto ativo (`~/.claude/contexts/<slug>.md`); `<TICKET>` é placeholder. A skill nunca assume prefixo de empresa.

```bash
# Extract ticket from conversation context or arguments
TICKET="<TICKET>"  # from $ARGUMENTS or conversation

# Find the worktree for this ticket
BRANCH=$(git branch -a --list "*${TICKET}*" | head -1 | sed "s|remotes/origin/||;s/^[ *]*//")

# Fallback: list all worktrees from all repos
```

**If worktree found**: Use that path for ALL subsequent git commands. NEVER use the main repo path.
**If NOT found**: STOP and ask the user. Do NOT fall back to the main repo.
**If on master**: STOP. You are in the wrong directory. Re-detect the worktree.

This prevents the critical bug where post-compaction /create-pr goes to the main repo on master, tries to push master, and loses track of the feature branch.

---

## Pre-checks

1. Verify not on the base branch (`master`/`main`) or `prod`. If so, you are likely in the WRONG directory (main repo instead of worktree). Re-run worktree detection above.
2. Check for uncommitted work, commit first if needed.
3. **Run lint + types locally (mandatory, blocks PR creation)**:

   Every Bash() call is a new shell. Always chain `cd WORKTREE && nvm use && <command>`.
   Skip entirely for SQL-only, docs-only, or config-only changes.

   ```bash
   # rodar o script equivalente do manifesto do repo (package.json scripts, Makefile, justfile)
   lint 2>&1 | tail -20
   # rodar o script equivalente do manifesto do repo (package.json scripts, Makefile, justfile)
   test:types 2>&1 | tail -20
   ```

   On failure: fix, commit, re-run failed check only. Build and tests are validated by CI after PR creation.

4. Detect base branch: `BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's#^refs/remotes/origin/##'); [ -z "$BASE" ] && BASE="master"`
5. Read diff stat only: `GIT_EDITOR=true git diff $BASE...HEAD --stat`
6. Read changed files SELECTIVELY via diff hunks, not full files. **Context budget**: this skill runs late in session.

## Verification (MANDATORY before creating PR)

- [ ] Local CI passed: lint, types (build + tests validated by CI)
- [ ] Branch is up to date with base: `git log --oneline base..HEAD`
- [ ] No unintended files staged: `git diff --name-only base...HEAD`
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

- `[<TICKET>] Add instant confirmation badge and social proof pill`
- `[<TICKET>] Bugbash UI Refinements`

Rules:

- Ticket in square brackets FIRST, then description
- No conventional commit prefixes (feat, fix, chore) in the PR title
- No parentheses around ticket. Always `[<TICKET>]`, never `(<TICKET>)`
- No emojis in titles
- svc-search CI enforces regex: `^\[([A-Z]+-\d+|FIX|CHORE|REVERT|DOCS|FEAT|DEPS)\]\s[A-Za-z].+`
- Max 75 characters

## PR Body (MANDATORY structure)

**Repository template wins.** If the repo has `.github/pull_request_template.md`, follow it section by section instead of the generic template below (rule 15: derive from the repo). The generic template is the fallback for repos without one.

Use the full template from [references/pr-template.md](references/pr-template.md). Sections: RISKY OR NOT, Changes at a glance, Why, What changed (grouped by area with real code), Architecture (Mermaid diagrams), Tests, Summary (product perspective), Related.

### RISKY OR NOT (bot-scored, NEVER manually change labels)

Bot parses PR body + diff. Weighs: diff size, destructive SQL, migrations, env vars, API changes. To target score 2: bullet-point mitigations (not single sentence), be specific ("no migrations" > "low risk"), call out scary-but-safe items. Score 3+: migrations, new env vars, API contract changes. Score 4: breaking changes, large data migration, multi-service deploy.

### Content rules

Real code only (no pseudo-code). Group by area, not file. Mermaid diagrams for business logic (never ASCII). Product summary last.

## Execution

**CRITICAL: Write PR body to a temp file, then create PR using `--body-file`. This keeps the PR body OUT of the context window and survives compaction.**

1. Generate Mermaid diagrams (see [references/pr-template.md](references/pr-template.md), Diagram Guidelines section)
2. Push branch: `git push -u origin $(git branch --show-current)`
3. **Detect related PRs** (see Related PRs & Merge Order section below)
4. **Write PR body to temp file using the Write tool**: Write to `/tmp/pr-body-TICKET.md`. This is mandatory. Never generate the body inline in conversation.
5. **Create PR from file and delete temp file immediately**:
   ```bash
   gh pr create --draft --title "[TICKET] Description" --body-file /tmp/pr-body-TICKET.md && rm -f /tmp/pr-body-TICKET.md
   ```
   The `rm` is critical. If the temp file survives, compact will restore it (200+ lines) and cause thrashing.
6. **Present PR link(s) clearly** (MANDATORY, this is the primary output):
   ```
   PR created:
   - svc-reporting: https://github.com/lux-group/svc-reporting/pull/NNNN
   - www-le-admin: https://github.com/lux-group/www-le-admin/pull/NNNN
   ```
   Links must be visible, not buried in bash output. This is what the user needs.
7. **Self-review + bot monitor** (MANDATORY, automatic, no user prompt needed):
   a. Post the merge review trigger comment (exact text, triggers the Claude bot):
   ```bash
   gh pr comment PR_NUMBER --repo REPO --body "@claude merge review"
   ```
   b. Wait ~30s for bot checks to post (risk score, lint, etc.):
   ```bash
   gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments --jq '.[].body' | head -50
   gh api repos/OWNER/REPO/issues/PR_NUMBER/comments --jq '.[] | select(.user.type == "Bot") | .body' | head -50
   ```
   c. For EACH bot comment: analyze the feedback, fix if actionable (push fix commit), and reply explaining the resolution:
   ```bash
   gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments --method POST -f body="Fixed: [explanation]" -F in_reply_to=COMMENT_ID
   ```
   c2. **Learning capture (MANDATORY for each applied fix)**: evaluate if the comment exposes a reusable pattern (repo convention, hidden rule, business constraint, validation gap). If yes: append to `~/.claude/skills/codereview/references/learnings.md` and save a copilot memory feedback entry. If it changes how future reviews should check code, also update `~/.claude/skills/codereview/references/known-gotchas.md`. Skipping this means repeating the same mistake in the next PR.
   d. If bot flags risk score > 2: review the RISKY OR NOT section and add mitigations if needed (edit PR body via `gh pr edit --body-file`)
8. **Launch CI Pipeline Monitor** (background agent, see [references/ci-monitor.md](references/ci-monitor.md))

**Anti-pattern**: generating the full PR body inline in conversation. The body can be 200+ lines and consumes critical context. Always use Write tool -> temp file -> `--body-file`.

**IMPORTANT**: PRs are ALWAYS created as draft. The user promotes to "ready for review" manually after validation.

## Related PRs & Merge Order

Before creating PR, search for related open PRs:

```bash
TICKET="<TICKET>"
gh search prs "$TICKET" --owner lux-group --state open --json repository,number,title,url --limit 10
gh pr list --repo "$(git remote get-url origin | sed -E 's#.*github\.com[:/]##; s#\.git$##')" --state open --json number,title,url --limit 10
```

If found, add a Merge Order table to the PR body (migration first, then consumers, then UI). If none found, skip.

## PR Review Notification (ONLY when user asks)

Only notify when user explicitly asks. Channel mapping is client-specific: for Luxury Escapes it lives in `~/.claude/contexts/luxury-escapes.d/notification-channels.md`; other contexts only notify where their own context layer declares channels. Our vertical repos (svc-experiences, svc-ee-offer, svc-car-hire, svc-addons, svc-tag, svc-occasions, www-ee-\*): no external notification needed.

---

## CI Pipeline Monitor

After PR creation, a background agent monitors CircleCI checks, polls every 90s (max 20 min), and auto-fixes lint/type/test/build failures (max 2 attempts per check). Non-fixable or pre-existing failures are escalated to the user.

Full agent prompt and rules: [references/ci-monitor.md](references/ci-monitor.md)

## Feature Folder Status Update (context-gated; mandatory ONLY when active context is luxury-escapes)

Gate first, write second. Resolve the active client context from the repo you are in:

```bash
source "$HOME/.claude/hooks/lib/active-context.sh"
CTX=$(active_context "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
```

- `CTX = luxury-escapes`: run the update below.
- Any other value, or empty (neutral): **write nothing, anywhere**. Fail closed. Never
  write one client's status into another client's tree (rule 11). Other contexts get a
  status artifact only when their own context layer declares such a convention.

After a Luxury Escapes PR is created, update the feature folder status in the vault to REVIEW. Search BOTH top-level folders AND subfolders (subtasks inside parent features).

```bash
FEATURES_DIR="__VAULT_ROOT__/Luxury-Escapes/Development/Features"
TICKET="<TICKET>"  # extracted from branch name or arguments; format comes from the active context

# 1. Search top-level (e.g., <TICKET> - TODO)
OLD=$(find "$FEATURES_DIR" -maxdepth 1 -type d -name "${TICKET}*" | head -1)
if [ -n "$OLD" ]; then
  NEW_NAME=$(echo "$OLD" | sed 's/- [A-Z_]*$/- REVIEW/' | sed "s/${TICKET}\$/${TICKET} - REVIEW/")
  [ "$OLD" != "$NEW_NAME" ] && mv "$OLD" "$NEW_NAME"
fi

# 2. Search subfolders (e.g., <TICKET> - REVIEW/<TICKET> - WIP)
SUB=$(find "$FEATURES_DIR" -mindepth 2 -maxdepth 2 -type d -name "${TICKET}*" | head -1)
if [ -n "$SUB" ]; then
  NEW_SUB=$(echo "$SUB" | sed 's/- [A-Z_]*$/- REVIEW/' | sed "s/${TICKET}\$/${TICKET} - REVIEW/")
  [ "$SUB" != "$NEW_SUB" ] && mv "$SUB" "$NEW_SUB"
fi
```

This handles both:

- **Top-level features**: `<TICKET> - TODO` -> `<TICKET> - REVIEW`
- **Subtasks inside parent**: `<TICKET> - REVIEW/<TICKET> - WIP` -> `<TICKET> - REVIEW/<TICKET> - REVIEW`

If the folder doesn't exist at either level, skip silently.

Status lifecycle: `PLANNING` / `TODO` -> `WIP` / `IN_PROGRESS` -> `REVIEW` -> `DONE`

## Worktree Cleanup Reminder

After PR created, include cleanup command (do NOT auto-remove):

```
Worktree cleanup (after merge): cd "$(git rev-parse --show-toplevel)" && git worktree remove ../{repo}--{ticket}
```

## Common Mistakes

1. **PR body inline**: Write to `/tmp/pr-body-TICKET.md`, use `--body-file`, delete after. Inline = 200+ lines wasted.
2. **Risk labels manual**: Bot owns labels. Influence via RISKY OR NOT body section only.
3. **Vague risk section**: Bullet-point mitigations, not single sentence.
4. **Skip lint/types**: lint and types must pass locally before PR.
5. **Diff > 500 lines**: Suggest splitting.
6. **Force push after review**: New commits preserve review context.
7. **ASCII diagrams**: Mermaid only.

## Rules

- Real code in every claim. No pseudo-code. Env var chain: schema -> config -> environment-variables.ts -> Pulumi.
- Review [references/learnings.md](references/learnings.md) if context budget allows (skip at >60% usage)
