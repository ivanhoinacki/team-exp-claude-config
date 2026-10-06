---
name: investigation
description: Deep multi-source investigation producing findings and a plan. Use when the user says "investigate", "investiga", "deep dive on this bug", "find out why", or a problem needs evidence from more than one source before any fix. Do NOT use for code review (use /codereview) or feature planning (use /feature-dev).
model: opus
---

# Investigation

Evidence-led investigation across four sources. Rewritten from scratch on 2026-08-28
(plan item 4.1, decision D3): short, client-neutral, no tiered channel or space lists.
Client specifics live in the active context layer (`~/.claude/contexts/<slug>.md`).

## Rules (from rule 13, non-negotiable)

1. Reproduce and capture raw evidence BEFORE any edit.
2. State the hypothesis AND the single test that would refute it. Run that test.
3. Two failed hypotheses = stop, write findings to a file, report, ask.
4. Success requires proof: paste the real output, not "it should work now".

## The four sources (in this order)

1. **Knowledge base / vault RAG** - `mcp__local-le-vault__query_vault(query, service_filter, client_filter)`.
   It serves ALL companies (decision D1); `client_filter` = the active client slug is
   mandatory on client-scoped work (D13: excludes other clients' rows, keeps neutral
   ones). Also `type_filter: [pitfall, review-learning]` for known traps.
2. **Pitfalls and learnings on disk** -
   `~/.claude/skills/codereview/references/known-gotchas.md` (sections matching the
   domain) and `learnings.md` (entries for the target repo; entries are indexed by
   client, do not apply one client's rule to another).
3. **Git history** - `git log -S`/`-G` on the suspect area, blame on the exact lines,
   and the PR that introduced them (`gh pr list --search`). The reason a line exists
   usually lives in the commit or PR body.
4. **GitHub** - related PRs and issues in the service chain via `gh`. Always read the
   PR body, not just the title.

No fixed chat channels, wiki spaces, or trackers here: if the active context declares
such sources, consult them; none declared, skip without asking.

## Output

Findings go to a FILE (rule 11), destination from the active context layer (none
declared: ask once). The chat gets the path plus at most 3 bullets: cause, evidence,
proposed next step. If the investigation ends in "fix it", hand to the normal chain
(fix -> /deslop -> commit) - do not silently start implementing mid-investigation.
