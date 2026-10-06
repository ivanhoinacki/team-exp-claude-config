# Code Review: 18 Dimensions — Detailed Reference

> Parent skill: [`code-review/SKILL.md`](../SKILL.md)

Each dimension has findings that map to a tier based on severity.

## Critical dimensions (Tier 1 — blocks merge)

### D1. Correctness

- Logic correct, feature flags respected, edge cases handled, null/undefined handling
- **Tier 1**: Logic bugs, wrong behavior, null pointer crashes, ignored feature flags
- **Tier 3**: Unhandled edge case that won't crash but produces unexpected results
- **LE examples**: Admin query filtering `active=true` hides entities admin needs to manage (PR #1775). `!qty.commissionValue` treats free tickets (value 0) as "no commission" (PR #1732). Report script joins junction table without checking source record status, inflating coverage metrics (PR #1760). Redux cache guard `if (state.foo[key]) return` blocks retry after error because error state is truthy (PR #32112)

### D2. Security

- No injection (SQL, XSS, command), no secrets in code, inputs validated at boundaries
- **Tier 1**: Injection vulnerabilities, exposed secrets, auth bypass
- **Tier 2**: Missing rate limit, overly broad permissions, missing input validation at boundaries
- **LE examples**: Auth role mismatch across batch endpoints: 3 of 5 routes had `EXPERIENCES_COORDINATOR`, 2 only had `ADMIN`, causing 403 for non-admin users (PR #1775). `uncachedVerifyUser` vs `cachedVerifyUser` on write endpoints (PR #5355). `Model.create(req.body)` mass assignment. Error middleware with 3 params instead of 4 silently ignored by Express (PR #5434)

### D3. Performance

- No N+1, bulk operations for DB, no blocked event loop, queries with index
- **Tier 1**: N+1 queries, missing indexes on hot paths, blocking event loop, memory leaks
- **Tier 2**: Inefficient but not critical (e.g., unnecessary iterations, suboptimal data structures)
- **LE examples**: Each attraction = 1 INSERT + 1 SELECT + N match INSERTs in loop (PR #1707). Hundreds of concurrent `getAvailableDates` calls with no concurrency limit (PR #1722). Read replica config doubled connection pool from 50 to 100 total connections (PR #1724). Missing index on new column used in WHERE/ORDER BY

### D4. Error Handling

- Errors not silenced, cleanup in error paths, explicit timeouts, retry with backoff
- **Tier 1**: Swallowed errors that hide failures, missing cleanup causing resource leaks, no timeout on external calls
- **Tier 2**: Missing retry/backoff on flaky external calls, error messages that don't help debugging
- **LE examples**: `JSON.parse` on external data without try-catch: one bad row breaks entire batch (PR #1743, #1707). Forgotten `await` on async call: promise floats, errors unhandled. `axios.get(url)` without `timeout` hangs forever. Missing `process.exit()` in ECS scripts keeps event loop alive (PR #5390). Sequelize queries inside `transaction()` without passing `{ transaction: t }` run outside the transaction (rollback has no effect)

## High dimensions (Tier 2 — should fix before merge)

### D5. SOLID / Clean Code

- SRP, DIP, no dead code, short focused functions, descriptive naming
- **Tier 2**: SRP violation (function doing too many things), dead code introduced by this PR, dependency inversion violated
- **Tier 3**: Naming could be clearer, function slightly long but readable

### D6. Testing

- Unit tests for new functions, mocks with real signatures, edge cases covered, no flaky tests
- **Tier 2**: Missing test for new behavior, mocks not matching real signatures, flaky test introduced
- **Tier 3**: Test exists but doesn't cover an important edge case

### D7. Codebase Consistency

- Follows existing repo patterns, reuses project utils, naming conventions
- **Tier 2**: Uses different approach than established pattern (e.g., raw SQL where repo uses query builder), doesn't reuse existing util
- **Tier 3**: Minor naming convention deviation

### D8. Architecture

- Layers respected (DDD/Clean), no circular coupling, clear boundaries
- **Tier 1**: Circular dependency introduced, data layer calling presentation layer
- **Tier 2**: Layer violation (e.g., controller with business logic), unclear module boundaries

## Medium dimensions (Tier 2/3 — fix if possible)

### D9. Operational Readiness

- Structured logs, business metrics, tracing propagated, health checks
- **Tier 2**: New endpoint or flow missing structured logging, critical business operation without metrics
- **Tier 3**: Log message could include more context, tracing not propagated to a new async call

### D10. Concurrency

- Race conditions, idempotency, locks when necessary, order of operations
- **Tier 1**: Race condition that causes data corruption or duplicate records
- **Tier 2**: Non-idempotent operation that should be idempotent, missing lock on shared resource
- **Tier 3**: Order of operations could cause stale read in rare cases

### D11. Documentation

- JSDoc on public APIs, README updated if contract changed, ADR for architectural decisions
- **Tier 2**: Public API signature changed without JSDoc update, new service without README entry
- **Tier 3**: Missing JSDoc on new public function, inline comment would clarify complex logic

### D12. Dependencies

- Pinned versions, no unnecessary deps, compatible licenses, no known vulnerabilities
- **Tier 1**: Dependency with known critical vulnerability
- **Tier 2**: Unpinned version (^major), unnecessary new dependency (existing dep covers it), incompatible license
- **Tier 3**: Could use lighter alternative

## LE-Specific dimensions (Tier 1/2 — derived from real incidents)

### D13. Cross-Service Contract Integrity

- Same field/value interpreted identically by producer and consumer? IDs stable across the chain? Enum values synced? SNS/SQS topic ARNs confirmed against real consumer?
- **Tier 1**: Field semantics differ between services (e.g., `leExclusive` accepts true/false in one service but only true in another). SNS topic mismatch causing silent event loss. transactionKey regenerated mid-flow breaking downstream lookup.
- **Tier 2**: Implicit contract assumption not documented (e.g., assumes Salesforce ticket is single-use but no guard).

### D14. Idempotency & State Recovery

- What happens if this operation runs twice? If a partial retry occurs? If an external job already acted on this state?
- **Tier 1**: Double refund possible (manual Stripe + system refund). Sync onUpdate wipes conditionally-populated field on re-run. Second bundle consumes already-used Salesforce ticket.
- **Tier 2**: Retry policy differs by payment type without documentation. Discount calculated but not persisted, causing divergence on re-read.

### D15. Financial Calculation Integrity

- In multi-item, multi-currency, or post-FX-conversion scenarios, is the value mathematically correct and financially fair for vendor, customer, and LE?
- **Tier 1**: Denominator excludes eligible items in proportional split. Two different `promoAmount` values in same calculation flow. FX rounding accumulates to reject valid orders. Holdback calculated on wrong base amount.
- **Tier 2**: `totalItemDiscounts()` returns 0 for new items causing incorrect promo distribution. Missing financial observability (holdback bugs are completely silent until Finance manually reviews).

### D16. Data Visibility & Context Coherence

- Is the data shown correct for THIS context (admin/public/report)? Are status filters applied consistently? Does "hidden" actually prevent access?
- **Tier 1**: Admin query filters `active=true`, hiding entities the admin needs to manage. Report joins junction table without checking source table state, inflating metrics.
- **Tier 2**: `status='ONLINE'` doesn't mean "available" (could be sold out). Hidden product still purchasable via direct link.

### D17. Runtime Configuration Coupling

- Does this change depend on a runtime configuration that is correct in ALL environments? Could a framework version or infra change silently alter behavior?
- **Tier 1**: Express 5 changed query parser default from `extended` to `simple`, breaking all providers with ticketModesMap. `qs` arrayLimit=20 silently converts arrays with 21+ items to objects.
- **Tier 2**: Missing explicit currency parameter causes silent default to AUD. DD_TRACE_ENABLED config wrong for service's ORM version. `lib-auth-middleware` major version change breaks all test JWTs.

### D18. External System Trust & Failure Attribution

- When this provider returns X, is our interpretation of X correct? When booking fails, is it our code or supplier configuration?
- **Tier 1**: Provider shows 18 available slots but booking fails (supplier-side config issue). Test transactions from external system trigger real failure alerts.
- **Tier 2**: Timeout attributed to our code but actually caused by downstream supplier. Failure triage path doesn't include "supplier-side" option.

## Internal Checklist (do NOT output, use internally)

Before presenting findings, verify you checked each dimension:

```
D1 Correctness:              [CLEAN / findings]
D2 Security:                 [CLEAN / findings]
D3 Performance:              [CLEAN / findings]
D4 Error Handling:           [CLEAN / findings]
D5 SOLID / Clean Code:       [CLEAN / findings]
D6 Testing:                  [CLEAN / findings]
D7 Consistency:              [CLEAN / findings]
D8 Architecture:             [CLEAN / findings]
D9 Ops Readiness:            [CLEAN / findings]
D10 Concurrency:             [CLEAN / findings]
D11 Documentation:           [CLEAN / findings]
D12 Dependencies:            [CLEAN / findings]
D13 Cross-Service Contract:  [CLEAN / findings]
D14 Idempotency:             [CLEAN / findings]
D15 Financial Integrity:     [CLEAN / findings]
D16 Data Visibility:         [CLEAN / findings]
D17 Runtime Config:          [CLEAN / findings]
D18 External Trust:          [CLEAN / findings]
```
