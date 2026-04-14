---
name: skill-name
description: What this skill does. Use when the user says "trigger phrase 1", "trigger phrase 2", or when [condition].
argument-hint: "[optional-arg] - description of optional argument"
allowed-tools: ["Read", "Edit", "Write", "Glob", "Grep", "Bash", "Agent"]
---

# Skill Title

Brief description of purpose and when to use.

## Common Agent Mistakes

These mistakes have been observed in past executions. Check each one EXPLICITLY before and during execution.

1. **Mistake name**: What the agent does wrong vs what it should do. Why this matters.
2. **Mistake name**: Description. How to avoid it.

## Discovery Phase

Scan the context thoroughly before acting. Every situation is different.

### Checklist

```
# Category 1
- [ ] Item: `command to run or check`
- [ ] Item: Grep tool — pattern `"pattern"` in `src/`

# Category 2
- [ ] Item: `command or check`
```

## Execution Steps

### Step 1: Name

**Prerequisite**: What must be in place.

Summary of what to do. For complex steps, delegate to [references/detail-doc.md](references/detail-doc.md).

### Step 2: Name

**Prerequisite**: Step 1 complete.

Instructions.

## Verification (MANDATORY)

Run through every item. Do NOT skip.

```
- [ ] Check: `command` -> Expected: result
- [ ] Check: `command` -> Expected: result
- [ ] Cross-reference: X matches Y
```

## Edge Cases

### Scenario 1: Description
How to handle this non-standard situation.

### Scenario 2: Description
How to handle this.

## Learnings

See [references/learnings.md](references/learnings.md) for lessons from past executions.
When a new lesson is discovered, append it there AND consider promoting frequent issues to Common Agent Mistakes.
