---
name: learn
description: Capture a learning (bug, workaround, pattern, gotcha) and save to persistent memory. Use when the user says "learn", "save this", "remember this", "note this", "record this", "never forget this", or when a non-obvious bug fix, workaround, or integration pattern is discovered during development.
argument-hint: [what was learned]
allowed-tools: Read, Write, Edit, Glob, Grep, Task
---

# Capture Learning

Save a development learning (bug, workaround, pattern, config, pitfall, architecture decision, tool behavior) to persistent memory so it's available in future sessions.

## Working Directories

1. **Vault (source of truth)**: `__VAULT_ROOT__` — ALL detailed learnings go here
2. **Memory directory** (auto-memory): the path provided by the system prompt's auto memory section (derived from vault path: `$HOME/.claude/projects/-<vault-path-sanitized>/memory/`). Contains ONLY two files:
   - `MEMORY.md` — thin index with pointers to vault files
   - `pitfalls.md` — one-liner gotchas (exception: stays in memory for fast loading)
3. **Codebase**: `__CODEBASE_ROOT__`

**CRITICAL RULES**:
- NEVER create any file in the memory directory besides `MEMORY.md` and `pitfalls.md`. No `feedback_*.md`, `project_*.md`, `reference_*.md`, or any other `.md` files
- ALL detailed content goes to the **vault** and is referenced from `MEMORY.md`
- When writing to `MEMORY.md` or `pitfalls.md`, use the memory directory path from the auto memory system (shown in system prompt). Do NOT guess or use wildcards

---

## Phase 0: Detect Learnings

### If `$ARGUMENTS` is provided

Use it as the learning description. Skip to Phase 1.

### If invoked without arguments (after /debug-mode, /feature-dev, or conversation)

Scan the recent conversation context for learnable moments:

- Bug root causes that were confirmed with evidence
- Unexpected behaviors that took investigation to understand
- Config or env var discoveries (ports, commands, compatibility)
- Workarounds applied for known issues
- Patterns that worked well and should be reused
- Tool/CLI behaviors that surprised or blocked progress
- Architecture decisions with rationale worth preserving

Present candidates:

```
Learnings detected in this session:

  1. [BUG] svc-experiences TypeORM silently ignores WHERE on nullable columns
     Impact: HIGH | Service: svc-experiences

  2. [CONFIG] BigQuery ADC requires gcloud auth before local dev
     Impact: MEDIUM | Service: svc-experiences

  3. [PATTERN] Bulk upsert with ON CONFLICT needs explicit column list
     Impact: MEDIUM | Service: svc-experiences

Save all? Or pick by number (e.g., 1,3)?
```

If the user says "all", process each sequentially through Phases 1-5.

### Diff-based lesson extraction

When invoked after a coding session, analyze the git diff to find learnings automatically:

```bash
GIT_EDITOR=true git diff main --stat  # What changed
GIT_EDITOR=true git log --oneline main..HEAD  # What was committed
```

Look for:

- Files that were edited multiple times (sign of iteration/discovery)
- Test files that were added (new patterns worth noting)
- Config changes (env vars, Pulumi, schema changes)
- Workarounds (comments with "workaround", "hack", "TODO", "FIXME")

### Batch extraction (after multi-step sessions)

If invoked right after `/debug-mode` or `/feature-dev`, also check:

- Debug summary (Phase 8 output) for root cause and fix
- Feature implementation for patterns and pitfalls encountered
- Pre-review findings for quality insights

---

## Phase 1: Understand the Learning

For each learning, extract:

1. **What happened?** (bug, unexpected behavior, discovery, decision)
2. **Root cause or explanation** (why it happens)
3. **Fix, workaround, or recipe** (what to do about it)
4. **Where in the codebase?** (service, file, function if applicable)

If any of these are unclear from context, ask the user only for the missing piece.

---

## Phase 2: Classify

### Category

| Category           | Description                                      | Target (ALWAYS in vault, never in .claude/memory/)            |
| ------------------ | ------------------------------------------------ | ------------------------------------------------------------- |
| **Bug/Pitfall**    | Something that broke or behaved unexpectedly     | One-liner → `pitfalls.md` (only exception). Detail → `vault/KB/Troubleshooting/` |
| **Pattern/Recipe** | A reusable code pattern or multi-step recipe     | `vault/KB/Review-Learnings/EXP-XXXX.md` (per feature)        |
| **Config**         | Port, DB, env var, command, service detail       | `MEMORY.md` (Quick Configs) or `vault/KB/Local-Development/`  |
| **Workflow**       | Team process, deploy step, convention            | `vault/KB/Infrastructure/` or `vault/KB/CI-Infrastructure/`   |
| **Workaround**     | Temporary fix for a known issue                  | One-liner → `pitfalls.md` (only exception). Detail → `vault/KB/Troubleshooting/` |
| **Architecture**   | Design decision with rationale and trade-offs    | `vault/Knowledge-Base/Infrastructure/`                        |
| **Tool/CLI**       | CLI tool behavior, command syntax, gotchas       | One-liner → `pitfalls.md` (only exception). Detail → `vault/KB/Troubleshooting/` |
| **External API**   | Third-party API behavior, quirks, error patterns | `vault/Development/Providers/Provider-Patterns.md`            |
| **Feedback**       | Correction or guidance from user                 | `vault/KB/Review-Learnings/` (NOT .claude/memory/)            |
| **Project status** | Ongoing work, decisions, timelines               | `vault/Development/Features/EXP-XXXX/` or `vault/KB/Infrastructure/` |
| **Reference**      | Pointer to external resource                     | `MEMORY.md` (Vault Index or Key Confluence Pages section)     |

### Impact

| Impact       | When                                                 | Marker                       |
| ------------ | ---------------------------------------------------- | ---------------------------- |
| **CRITICAL** | Production bug, data corruption risk, security issue | Prioritize at top of section |
| **HIGH**     | Dev blocker, hours of debugging, common mistake      | Add near top                 |
| **MEDIUM**   | Time-saver, non-obvious behavior                     | Add in logical order         |
| **LOW**      | Nice-to-know, edge case, minor convenience           | Add at end                   |

### Service tags

Tag with affected service(s): `svc-experiences`, `svc-order`, `svc-ee-offer`, `www-le-customer`, `infra`, `cli`, `general`.

---

## Phase 3: Verify and Cross-Reference

### 3.1 Codebase verification (for code-related learnings)

Before saving a Bug/Pitfall, Pattern/Recipe, or External API learning, verify it against the actual code:

- For bugs: confirm the problematic code still exists at the referenced location
- For patterns: confirm the pattern matches the current codebase conventions
- For configs: confirm the values (ports, env vars, commands) are current

Use Grep/Glob to quickly verify. If the code has changed since the learning was discovered, note the current state.

If verification fails:

```
Verification warning: The referenced code at [file:line] has changed.
Current state: [what it looks like now]

Save anyway? (yes / update details / skip)
```

### 3.2 Duplicate check

Search existing memory files for similar content:

1. Read `MEMORY.md` - check routing table and Quick Configs
2. Read `pitfalls.md` - check if similar one-liner exists
3. Grep vault `Knowledge-Base/` for key terms (service name, function name, error message)

If a similar entry exists:

```
Related existing entry found:
  File: pitfalls.md
  Entry: "TypeORM getCount() with offset/limit"

Options:
  a) Update existing entry (add new detail)
  b) Save as separate entry (different aspect)
  c) Replace existing (outdated)
  d) Skip (already covered)
```

### 3.3 Cross-reference

Find related learnings that should be linked:

- Same service
- Same domain (TypeORM, Pulumi, BigQuery, etc.)
- Same pattern category

If found, add a brief cross-reference: `(see also: [related entry title])`

---

## Phase 4: Write

### MEMORY.md budget check

Before writing to MEMORY.md:

```bash
wc -l MEMORY.md
```

- **Under 170 lines**: safe to add directly
- **170-190 lines**: add, but flag that a migration is needed soon
- **190+ lines**: do NOT add to MEMORY.md. Route to vault instead (see routing table in MEMORY.md)

### Formatting by category

**For pitfalls (memory/pitfalls.md) — one-liner only:**

```
X. **[Short title]**: [What happens]. Fix: [solution]
```

**For detailed learnings (vault files):**

```
## [Learning Title]

[When it happens. Root cause. Fix or workaround. Code snippet if relevant.]
Services: [affected services]
```

**For configs (MEMORY.md Quick Configs):**

```
- **[service]**: [key detail] (port, DB, command)
```

**For provider patterns (vault/Development/Providers/):**

```
X. **[Provider] - [behavior]**: [what happens, when]. Handle: [how to deal with it]
```

### Write rules

- Keep entries concise (1-3 lines for MEMORY.md, more detail allowed in topic files)
- Use English for all entries
- Never store secrets, tokens or credentials
- Include the service tag in the entry text
- CRITICAL/HIGH impact entries get bold markers or go to top of section
- **NEVER create files in the memory directory** except updating `MEMORY.md` or `pitfalls.md`
- **ALL detailed content goes to the vault** and is referenced from `MEMORY.md` (Vault Index table)
- After writing to vault, ALWAYS update `MEMORY.md` Vault Index if the file is new

---

## Phase 5: Confirm

Show what was saved:

```
Learning saved:
  Category: [bug/pattern/config/workflow/workaround/architecture/tool/external-api]
  Impact: [CRITICAL/HIGH/MEDIUM/LOW]
  Service: [service tag(s)]
  Entry: "[short title]"
  File: [file:section]
  Related: [cross-referenced entries, if any]

This will be available in all future sessions.
```

If multiple learnings were saved (batch):

```
Learnings saved: N entries

  1. [BUG/HIGH] "TypeORM nullable WHERE" -> pitfalls.md (one-liner)
  2. [CONFIG/MEDIUM] "BigQuery ADC setup" -> MEMORY.md:Quick Configs
  3. [PATTERN/MEDIUM] "Bulk upsert recipe" -> vault/KB/Review-Learnings/EXP-XXXX.md

All available in future sessions.
```

---

## Phase 6: Skill Feedback Loop (NEW)

When a learning is directly related to a skill's execution (e.g., a mistake made during `/code-review`, a gap found during `/debug-mode`, a pattern discovered during `/feature-dev`), also append it to that skill's `references/learnings.md`.

### How to route

1. Check if the learning was discovered during or after a specific skill execution
2. Map to the skill:

| Context | Skill | Learnings file |
|---|---|---|
| Code review gap | code-review | `~/.claude/skills/code-review/references/learnings.md` |
| Feature dev pitfall | feature-dev | `~/.claude/skills/feature-dev/references/learnings.md` |
| Debug session insight | debug-mode | `~/.claude/skills/debug-mode/references/learnings.md` |
| Investigation gap | investigation-case | `~/.claude/skills/investigation-case/references/learnings.md` |
| Deploy issue | deploy-checklist | `~/.claude/skills/deploy-checklist/references/learnings.md` |
| PR creation issue | create-pr | `~/.claude/skills/create-pr/references/learnings.md` |
| Infra config gap | validate-infra | `~/.claude/skills/validate-infra/references/learnings.md` |
| Migration issue | validate-migration | `~/.claude/skills/validate-migration/references/learnings.md` |

3. If the skill has a `references/learnings.md`, append the entry:

```markdown
### [DATE] [SHORT TITLE]
- **Context**: [what was being done when discovered]
- **Gap**: [what the skill missed or got wrong]
- **Fix**: [how to avoid this in the future]
- **Promoted to Common Mistakes**: [yes/no]
```

4. If the same gap appears 3+ times in a skill's learnings, promote it to that skill's "Common Agent Mistakes" section.

### Feedback loop flow

```
Discover gap during skill execution
    |
    v
/learn saves to vault (primary) + pitfalls.md (one-liner)
    |
    v
Also appends to skill's references/learnings.md
    |
    v
After 3+ occurrences of same pattern:
    |
    v
Promote to skill's "Common Agent Mistakes" section
```

---

## Rules

- Keep entries concise (1-3 lines for MEMORY.md, more detail allowed in topic files)
- Use English for all entries (consistent with the rest of the memory)
- Never duplicate - update existing entries when possible
- Never store secrets, tokens or credentials in memory
- If the learning contradicts an existing memory entry, flag it and ask the user which is correct
- Always verify code-related learnings against the actual codebase before saving
- MEMORY.md must stay under 200 lines. Proactively migrate to topic files
- Tag every learning with the affected service(s) for future retrieval
- Impact classification helps prioritize: CRITICAL entries should be easily found
- **Max 3 lessons per session**: 1 primary lesson + up to 2 "also worth noting". Depth over breadth. If you detect more than 3, pick the 3 most impactful and mention the rest briefly in the confirmation output
- **Skill feedback**: Always check if a learning maps to a skill and append to its learnings.md
