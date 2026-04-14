# Implementation Plan Template (Feature Development)

> Parent skill: [feature-dev/SKILL.md](../SKILL.md), Phase 4

Generate this plan using KB context + codebase patterns from discovery. Present to user for approval before implementation.

---

## Summary / Context

- What and why (1-2 sentences)
- Where it fits in the system

## Scope

- In scope / out of scope
- Acceptance criteria as checkboxes

## Step-by-step Plan

Ordered implementation steps. For each step:

- What to do
- Which file(s) to create/modify
- Which existing pattern to follow (reference the actual file)

## Implementation Order

Suggested: database/migration -> model/types -> service/context -> API/controller -> tests -> frontend (if applicable)

## Quality Standards (apply to every line of code written)

**Correctness:** logic correct, edge cases, feature flags, async/await handled
**Security:** no injection, no secrets exposed, inputs validated at boundaries
**Performance:** no N+1, bulk operations for DB writes, no event loop blocking
**Error handling:** errors not silenced, cleanup in error paths, explicit timeouts
**SOLID:** SRP, focused functions, no dead code, no unnecessary abstractions
**Testing:** unit tests for new functions, mocks with real signatures, edge cases covered
**Consistency:** follows existing codebase patterns (naming, structure, config, queries)

## What to Use

- Stack, libs, patterns (from codebase discovery, not invented)
- Reference actual files: "follow the pattern in src/contexts/booking/context.ts"

## Risks / Dependencies / Blockers

- Technical risks and mitigation
- External dependencies (other teams, APIs, providers)
- Questions to clarify with PM/stakeholder

## Test Plan (mandatory)

Every plan MUST include a concrete test plan. This is not optional.

| Category              | Tests                                             | Approach                                |
| --------------------- | ------------------------------------------------- | --------------------------------------- |
| **Unit tests**        | [list specific functions/modules to test]         | [mocking approach, assertions]          |
| **Integration tests** | [endpoints to test, or N/A with reason]           | [setup, DB seeding]                     |
| **Manual testing**    | [exact reproduction steps]                        | [which env, which customer, which flow] |
| **Regression**        | [what existing behavior must NOT break]           | [existing tests to run]                 |
| **Edge cases**        | [null/undefined, empty arrays, concurrent access] | [specific scenarios]                    |

For bug fixes, also include:

- **Before**: exact steps to reproduce the bug (date, customer ID, URL, params)
- **After**: same steps showing the fix works

## Diagrams

Include at minimum a Sequence Diagram of the main flow (PlantUML). See `~/.claude/rules/05-diagrams-standard.md` for style guide.

## References

- KB docs found
- Similar codebase files
- Jira ticket, Figma, API docs
