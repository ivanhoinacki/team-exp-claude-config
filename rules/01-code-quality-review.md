---
description: Priority code quality rule. Apply DURING development, not just before PR.
alwaysApply: true
---

# Code Quality Review

18 dimensions per function/module:
**Critical** (blocks merge): Correctness, Security, Performance, Error Handling, Cross-Service Contract, Financial Integrity
**High** (fix before merge): SOLID, Testing, Codebase Consistency, Architecture/DDD, Idempotency, Data Visibility, Runtime Config, External System Trust
**Medium**: Observability, Concurrency, Documentation, Dependencies

Before push: correctness? security? perf? contracts? financial? tests? patterns? env vars?
Before PR: run `/deslop`. Gotchas in `pitfalls*.md`.
