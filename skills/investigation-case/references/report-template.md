# Investigation Case Report Template

> Parent skill: [../SKILL.md](../SKILL.md)

Template for the investigation output document at `Development/BUG/{TICKET-ID}/Investigation-Case.md`.

**Language**: The entire document MUST be written in English. Section titles, narrative text, analysis, and explanations in English. Technical terms (code snippets, file paths, PR titles, error messages, variable names) remain as-is.

---

```markdown
---
tags:
  - investigation
  - { ticket-id }
  - { service-name }
date: { YYYY-MM-DD }
ticket: { TICKET-ID }
status: investigating
ownership: { team-name }
severity: { P1/P2/P3 }
---

# Investigation Case: {TICKET-ID}

> {One-line problem description}

## Executive Summary

{2-3 sentences: what happened, who was affected, root cause, recommended fix}

## Evidence Collection

### Jira Evidence

{Structured findings from Agent 1}

### Slack Evidence

{Structured findings from Agent 2}

### GitHub Evidence

{Structured findings from Agent 3}

### Confluence Evidence

{Structured findings from Agent 4}

### Codebase Evidence (Backend)

{Structured findings from Agent 5}

### Codebase Evidence (Frontend)

{Structured findings from Agent 6}

### Production Evidence (Datadog/New Relic)

{Structured findings from Agent 7}

## Timeline Reconstruction

| Date/Time | Event | Source | Significance |
| --------- | ----- | ------ | ------------ |
| ...       | ...   | ...    | ...          |

## Business Context

### Why this feature was developed

{Extracted from PR bodies, Confluence, Slack}

### Business rules involved

{Rules governing this behavior}

### Original intent vs current behavior

{Gap analysis}

## Root Cause Analysis

### What went wrong

{Direct technical cause}

### Why it went wrong

{5 Whys analysis}

### Contributing factors

{Environmental, process, or design factors}

## Impact Assessment

- **Affected customers**: {count or estimate}
- **Affected orders**: {count or IDs}
- **Severity**: {P1/P2/P3}, {justification}
- **Blast radius**: {scope}
- **Trend**: {increasing/stable/decreasing}
- **Has workaround**: {yes/no}

## Ownership Classification

| Dimension | Value                    | Confidence | Evidence   |
| --------- | ------------------------ | ---------- | ---------- |
| Platform  | {Web/Mobile/Backend}     | {High/Med} | {evidence} |
| Domain    | {Experiences/Hotels/...} | {High/Med} | {evidence} |
| Service   | {svc-xxx}                | {High/Med} | {evidence} |
| Team      | {team name}              | {High/Med} | {evidence} |

## Similar Incidents

{Related bugs found, previous fixes, recurring patterns}

---

## Fix Plan

### Recommended Approach

{Strategy description with justification}

### Alternative Approaches Considered

{Other options and why they were not chosen}

### Implementation Steps

| Step | Action | File(s)  | Pattern Reference    |
| ---- | ------ | -------- | -------------------- |
| 1    | {what} | {files}  | {existing pattern}   |

### Test Plan

| Category         | Test        | Expected Result |
| ---------------- | ----------- | --------------- |
| **Reproduction** | {steps}     | {expected}      |
| **Regression**   | {tests}     | {expected}      |
| **Edge cases**   | {scenarios} | {expected}      |
| **Unit tests**   | {tests}     | {pass}          |

### Risks and Mitigations

| Risk   | Probability | Impact  | Mitigation   |
| ------ | ----------- | ------- | ------------ |
| {risk} | {L/M/H}     | {L/M/H} | {strategy}  |

### Rollback Strategy

{How to revert if the fix causes problems}

### Deploy Considerations

{Order, monitoring, feature flags}

## References

- **Jira**: [{TICKET-ID}](https://aussiecommerce.atlassian.net/browse/{TICKET-ID})
- **PRs**: {links to relevant PRs}
- **Confluence**: {links to relevant docs}
- **Slack threads**: {links or descriptions}
- **Datadog**: {relevant dashboards or queries}
- **Related bugs**: {links}
```

---

## Frontmatter Status Values

| Status | Meaning |
|---|---|
| `investigating` | Investigation in progress |
| `resolved` | Root cause found and fix applied |
| `escalated` | Escalated to another team or priority raised |
| `handed-off` | Not our team's issue, handed off with evidence |
