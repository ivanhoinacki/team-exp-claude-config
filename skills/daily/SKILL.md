---
name: daily
model: haiku
description: Generate daily standup notes from git history, session memory, and Jira. Use when the user says "daily", "generate daily", "create daily", "standup", "stand-up", "what did I do today", "daily notes".
argument-hint: [YYYY-MM-DD or "hoje"]
allowed-tools: Bash(git *), Read, Write, Glob
effort: low
---

# Daily Standup Generator

## Working Directories

1. **Obsidian workspace** (docs, plans, dailies): `__VAULT_ROOT__`
2. **Codebase** (all LE services): `__CODEBASE_ROOT__`

## Collect context automatically

- Recent commits: !`git log --oneline --since="yesterday" --author="__USER_NAME__" 2>/dev/null | head -10 || echo "no commits found"`
- Current branch: !`git branch --show-current 2>/dev/null || echo "N/A"`

## Ask the user

1. Which Jira tasks did you work on? (numbers and descriptions)
2. Any important meetings? With whom and about what?
3. Did you encounter any blockers? How did you resolve them?
4. Anything else relevant?

## Generate two files

Use $ARGUMENTS as date if provided, otherwise use today.

### Output directory

Files go inside a month subfolder under `Dailies/`:

```
Dailies/{Mon}/YYYY-MM-DD.md
Dailies/{Mon}/YYYY-MM-DD-en.md
```

Where `{Mon}` is the abbreviated English month name (Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec).

Example: `Dailies/Mar/2026-03-12.md` and `Dailies/Mar/2026-03-12-en.md`

Create the month folder if it doesn't exist yet.

### PT-BR: `YYYY-MM-DD.md`

```markdown
# Daily – DD/MM/YYYY

## Storytelling

Good evening everyone, good morning team.

[Fluid narrative connecting activities. Professional but natural tone.
Tasks in declarative format: "task 3303, which is about adding schedule support".
Each topic in a separate paragraph for readability.
Continuous text, not bullet points.
Ends with blockers and tasks status: "No blockers and no tasks assigned at the moment" or equivalent.]
```

### EN: `YYYY-MM-DD-en.md`

```markdown
# Daily – MM/DD/YYYY

## Storytelling

Good evening everyone, good morning team.

[Simple English for B1 level. Short sentences, easy vocabulary.
Tasks with pronunciation: "task 3303 (thirty-three oh three)".
Same structure as PT-BR: one paragraph per topic, separated by blank lines.
Ends with blockers/tasks status: "No blockers and no tasks assigned at the moment." or equivalent.]
```

## Timeline Rules

- **Coverage**: From yesterday's daily (19:30 BRT) to today's daily (19:30 BRT)
- **Work hours**: 14h-22h BRT (official), but often starts in the morning to get ahead
- **Narrative blocks (in order):**
  1. **Yesterday post-daily (19:30-22:00)**: "Yesterday after the daily..."
  2. **Today morning (before 14h)**: "Started the shift early in the morning..."
  3. **Today afternoon (14h+)**: "In the afternoon..."
- Always analyze real timestamps (commits, Slack messages) to place activities in the correct block
- If no activity in a block, simply omit it

## Common Agent Mistakes

1. **Writing outside month folder**: Files MUST go to `Dailies/{Mon}/`, not `Dailies/` root. Always build the path with the abbreviated month name
2. **Including non-dev activities**: Mentioning Claude usage, automations, doc updates, Slack message sends, memory saves, or prompt engineering. Only include development work, meetings, and technical decisions
3. **Using bullet points**: The daily must be narrative text, not lists. Each topic as a separate paragraph
4. **Missing pronunciation in EN**: Every number in the EN version needs pronunciation in parentheses. EXP-3463 (thirty-four sixty-three), PR #1636 (sixteen thirty-six)
5. **Wrong timeline placement**: Putting afternoon activities in the "yesterday post-daily" block. Always check timestamps from commits/messages to place correctly
6. **Including implementation details**: Mentioning function names, test counts, or line numbers. The audience is PM/tech lead, not PR reviewer
7. **Passive voice instead of active**: WRONG: "the migrations were merged". RIGHT: "I merged the PRs". Always use first person active voice describing what the user DID, not what happened passively
8. **Rigid timeline block separation**: Do NOT force every activity into a separate "yesterday / morning / afternoon" block with explicit labels. If activities flow naturally together, combine them. Use natural transitions like "After that I moved on to..." / "Right after I needed to..." instead of mechanical "In the afternoon..." markers
9. **Including minor/irrelevant activities**: Only mention work the TEAM cares about. A small one-off fix in another team's service (e.g., svc-order hotfix) can be omitted if it was not a significant effort or not relevant to the team's context. When in doubt, omit
10. **Over-explaining merges**: WRONG: "the three migrations were merged". RIGHT: "I generated the testing evidence in staging for the migrations" (describes the WORK, not the git event). Focus on what effort was done, not git operations

## References

- **Cluely prompt** (for standalone use): `Prompts/Daily-Standup.md` in the vault. Same rules, designed for Cluely overlay during daily meeting

## General Rules

- **Always start with greeting**: "Good evening everyone, good morning team."
- Write as continuous narrative, not bullet points
- Connect tasks, meetings, and problem-solving naturally
- Use declarative form for task numbers

## Verification (MANDATORY before saving files)

- [ ] Files saved to `Dailies/{Mon}/` subfolder (not root)
- [ ] Both versions generated (PT-BR + EN)
- [ ] Greeting present in both versions
- [ ] Blockers/tasks status at the end of both versions
- [ ] EN version has pronunciation for ALL numbers
- [ ] No bullet points or lists, narrative only
- [ ] No non-dev activities (automations, docs, Claude, Slack)
- [ ] Timeline blocks in correct order (yesterday post-daily, today morning, today afternoon)
