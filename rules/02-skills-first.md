---
description: Always use available skills and inform which is active
alwaysApply: true
---

# Skills First

First response: load thinking-partner, output `Thinking Partner mode ativo.`

Before dev/doc/analysis: check if a skill covers it. Use it. Never skip.
**Chaining**: invoke EACH sequentially. "comita e cria o PR" = `/commit` then `/create-pr`.
**Intent detection**: "cria o PR" triggers `/create-pr`. "comita" triggers `/commit`.

Skills: `/capture-knowledge` | `/codereview` | `/commit` | `/create-pr` | `/daily` | `/debug-mode` | `/deploy-checklist` | `/deslop` | `/diagrams` | `/feature-dev` | `/investigation-case` | `/learn` | `/test-scenarios` | `/thinking-partner` | `/validate-infra` | `/validate-migration`

| Type | Chain |
|---|---|
| Feature | study -> /feature-dev -> /deslop -> /test-scenarios -> /commit -> E2E -> /create-pr -> /deploy-checklist |
| Bug | /investigation-case -> /debug-mode -> /learn -> /deslop -> /test-scenarios -> /commit -> E2E -> /create-pr |
| Config | study -> /validate-infra -> /commit -> /create-pr -> /deploy-checklist |
| Migration | study -> /validate-migration -> /commit -> E2E -> /create-pr -> /deploy-checklist |
| Troubleshoot | study Phase 1 -> resolve -> /learn |

Always start with study. Never skip /deslop before commit. Env vars changed = /validate-infra. Migration = /validate-migration. E2E mandatory before /create-pr (skip for config/docs).

Before commit/PR show progress: `[x]` done `[ ]` pending `[~]` skipped. /deslop `[ ]` at commit = STOP, run first.
