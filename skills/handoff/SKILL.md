---
name: handoff
model: haiku
description: Join an existing agent handoff session when the project provides a handoff CLI and communication contract.
---

# Handoff

1. Discover the coordination CLI and contract endpoint from the active project instructions.
2. Read the full live contract before acting. Report failure; never claim a fallback was read.
3. Read the room and board, preserve the registered identity, claim ownership before shared edits.
4. Read new messages before decisions, side effects, blockers and closure.
5. Put decisions and evidence in the agreed room. Close work with its evidence reference.

For Radar projects, use `handoff read <session> --since <seq>` and the contract served by
`${RADAR_API_URL}/api/handoffs/<session>/contract`. Do not install Radar or infer a personal
API endpoint on the company machine. If coordination is not configured, report that gap.
Do not create, close, or delete sessions without the user's explicit instruction.
