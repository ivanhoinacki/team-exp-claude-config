---
description: Auto-detect worktrees and enforce worktree-based development
---

# Worktree Detection

On EVERY message with ticket (EXP-XXXX, BUG007-XXXX), BEFORE code: search worktrees in `__CODEBASE_ROOT__/*/` via `git worktree list | grep -i <ticket>`. Found = navigate + inform. Not found = search branches. NEVER create worktrees autonomously. Multiple matches = ask. Silent when no ticket.

## Feature Development

NEVER use `git checkout -b` on a main repo checkout. Feature work uses worktrees:

```
git worktree add ../REPO--FEATURE -b feat/FEATURE
```

Pattern: `REPO--short-name` (e.g., `www-le-customer--le-live-popup`, `svc-experiences--perf-attractions`).

Before starting any feature: ASK the user if he wants a worktree created. Hook enforces this (blocks `git checkout -b`).
