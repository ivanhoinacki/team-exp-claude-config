# Code Review: Known Gotchas

> Parent skill: [`code-review/SKILL.md`](../SKILL.md)
>
> Before finalizing findings, explicitly verify these recurring patterns against the diff.
> This file grows over time as new gotchas are discovered.
> Each pattern includes real examples from LE PRs where applicable.

## Input Parsing

- **`z.coerce.boolean()` on query params**: `Boolean("false")` = `true` in JS. Use `.transform(v => v === "true")` instead
- **`parseFloat`/`parseInt` on unvalidated input**: `parseFloat("-5")` = -5 (truthy, bypasses guards). Guard: `Number.isFinite(val) && val > 0`
- **Falsy check `!value` on numeric 0**: `!0` = `true`. Rejects equator coords (lat 0), zero scores, zero commissions. Real: PR #1732 `!qty.commissionValue` treated free tickets (`commissionValue: 0`) as having no commission, falling through to offer margin calc. PR #1707 `!attraction.latitude` rejected Quito attractions (lat ~0). Fix: use `=== null`, `=== undefined`, or `typeof !== 'number'`
- **Missing `additionalProperties: false` in JSON schema**: Without it, API silently accepts arbitrary extra fields. Real: PR #5372 (svc-order) allowed unexpected fields to pass validation

## Cross-Service Consistency

- **Source handles `true|false`, consumer only handles `true`**: If svc-experiences sends `active: true|false`, consumer must handle both, not just filter on `true`
- **Consumer APIs must validate enum values at boundary**: Use `mapEnumValues()` or explicit allowlist, not accept arbitrary strings from upstream
- **Range param with only one bound implemented**: If param is "range" (min, max), both bounds must be enforced or param renamed to avoid silent bugs
- **Currency param missing in cross-service calls**: BFFs/svc-order calling svc-experiences APIs MUST pass `currency`. Defaults to AUD without it. Real: multiple PRs missed this

## Query Layer

- **TypeORM `getCount()` with `offset()`/`limit()`**: `.getCount()` only strips `.take()`/`.skip()`, NOT `.offset()`/`.limit()`. Clone QB before applying pagination
- **GROUP BY with non-functional dependencies**: Columns that vary per row create duplicate groups. Use `MAX()`/`MIN()` aggregates
- **Active status filter inconsistency**: If list endpoint filters `active=true`, all related detail/offers endpoints MUST also filter. Real: PR #1706 returned offers for inactive attractions because query didn't join on `attraction.active = true`
- **PostGIS ST_MakePoint coordinate order**: `ST_MakePoint(longitude, latitude)` not `(lat, lng)`. Inverting causes attractions in wrong hemisphere. Real: documented in svc-experiences context.ts

## Codebase Pattern Reuse (D7 Consistency)

- **Hardcoded enum values when TypeScript enum exists**: If diff has `s.enum({ values: ['a', 'b', 'c'] })`, grep for existing enum. Use `Object.values(ExistingEnum)`. Real: PR #1754 hardcoded `['cultural', 'natural', ...]` when `AttractionType` existed in `@models/attraction/types.ts`
- **New util/helper when one exists**: Before creating a new function, use Grep tool with pattern `similar_name` in `src/`. The codebase likely has a util that does the same thing
- **Duplicated sort/filter logic**: Check if the same pattern exists in other queries/controllers in the same module before adding new sort/filter code
- **Redundant COALESCE**: `COALESCE($1, column)` when `$1` is guaranteed non-null by the calling code. Real: PR #1743 flagged for this

## Project Structure & Naming Conventions (D7 Consistency)

Check 2-3 adjacent files/folders to confirm the convention before flagging. LE services vary.

**File location by service pattern**:
- **svc-experiences**: `src/contexts/{domain}/context.ts` (business logic), `src/queries/{domain}/queries.ts` (DB), `src/controllers/{domain}/controller.ts + schema.ts` (API), `src/models/{entity}/model.ts + types.ts` (ORM)
- **svc-ee-offer**: `src/operations/` (business logic), `src/models/` (Sequelize), `src/routes/` (API)
- **svc-order**: `src/context/{vertical}/` (accommodation, experience, flight), `src/routes/`, `src/lib/`
- New files MUST go in the correct layer. Business logic in controllers = architecture violation

**File naming patterns**:
- svc-experiences: kebab-case dirs (`attraction-curation/`), camelCase files (`context.ts`, `queries.ts`)
- svc-order: camelCase dirs and files
- Check suffix: `.controller.ts`, `.schema.ts`, `.queries.ts`, `.types.ts`, `.unit.test.ts`
- Singular entity dirs (`attraction/`, `offer/`) not plural in svc-experiences

**Variable/function naming**:
- camelCase for functions/variables, PascalCase for classes/interfaces/enums/types
- UPPER_SNAKE for constants and env vars
- Boolean prefix: `is`/`has`/`should` (`isActive`, not `active`; `hasOffers`, not `offers`)
- Strummer validators: `s.string()`, `s.integer({ parse: true })`, `s.enum({ values: [...] })`

**Export patterns**: Check adjacent files for default vs named exports, barrel `index.ts` usage

**Test patterns by service**:
- svc-experiences: `src/contexts/{domain}/__tests__/context.unit.test.ts`, `describe('functionName')`
- svc-order: `test/` at root, `describe('module')`, jest with `--forceExit`
- Test name matches source file. New code without tests = D6 finding

## Deprecated APIs & Patterns (D12 Dependencies)

Flag as nit if existing code uses the deprecated pattern (consistency). Flag as suggestion if new code.

- **`querystring` module**: Deprecated since Node 14. Use `URLSearchParams`. Real: flagged in svc-experiences PR
- **`url.parse()`**: Deprecated since Node 11. Use `new URL()`
- **`Buffer()` constructor**: Use `Buffer.from()`, `Buffer.alloc()`, `Buffer.allocUnsafe()`
- **`request` / `node-fetch` v2**: Prefer native `fetch` (Node 18+). If repo uses `axios`, stay with `axios`
- **Sequelize v5 patterns in v6**: `findOne` returns `null` not `undefined` in v6. `Model.init()` vs `define()` must match service version
- **TypeORM 0.2 vs 0.3**: `getConnection()` removed in 0.3. Use `dataSource.getRepository()`. svc-experiences is on 0.3

## Async & Concurrency (D4 Error Handling, D10 Concurrency)

- **Forgotten `await`**: Async call without `await`. Promise floats, errors unhandled, Node 15+ crashes. Check EVERY async call
- **`forEach` with `async` callback**: `items.forEach(async (item) => { await ... })` fires all in parallel uncontrolled, code after forEach runs immediately. Use `for...of` (sequential) or `Promise.all(items.map(...))` (parallel controlled)
- **Sequential awaits when parallel possible**: Three independent awaits in sequence = 3x latency. Use `Promise.all([a(), b(), c()])` when independent
- **Missing timeout on external calls**: `axios.get(url)` without `timeout` hangs forever. Real: Rezdy downstream calls timeout at 25s (supplier-side), but LE calls to Rezdy need their own timeout too. Always set `timeout` and `AbortSignal.timeout()`
- **TOCTOU race condition**: `if (remaining > 0) { remaining -= 1; save() }` allows concurrent overselling. Real: PR #5380 (svc-order) two admin refund requests both passing guard. Fix: atomic `UPDATE ... SET x = x - 1 WHERE x > 0`
- **Missing `process.exit()` in scripts/ECS tasks**: Script finishes but event loop stays alive due to DB pool. Real: PR #5390 (svc-order). Always `process.exit(0)` in `.then()`, `process.exit(1)` in `.catch()`
- **N+1 queries and thundering herd**: Sequential loop making one DB/API call per item. Real: PR #1707 each attraction = 1 INSERT + 1 SELECT + N match INSERTs. PR #1722 hundreds of concurrent `getAvailableDates` calls with no concurrency limit. Fix: batch upserts, `p-limit` for concurrency control

## Null Safety & Type Guards (D1 Correctness)

- **Methods on potentially null values**: `.toFixed()`, `.length` on external data. Real: PR #1743 `!images.length` on null images. PR #1713 `location.latitude.toFixed(7)` on null latitude (Rezdy online experiences have no coords)
- **`JSON.parse` without try-catch on external data**: One bad row breaks entire batch. Real: PR #1743 malformed images JSON in DB. PR #1707 LLM output truncated. Always wrap in try-catch, validate with `Array.isArray()`
- **`as` type assertion hiding runtime bugs**: `JSON.parse(raw) as Config` has zero runtime validation. Use Zod/Joi for external data
- **Optional chaining without handling undefined**: `order?.items?.[0]?.price` silently returns `undefined`. If downstream expects `number`, you get NaN. Always handle explicitly

## Database & ORM (D3 Performance, D10 Concurrency)

- **Sequelize: missing `{ transaction: t }`**: Queries inside `sequelize.transaction()` without passing `t` run outside the transaction on separate connections. Rollback won't affect them. Insidious: works in unit tests (no concurrency)
- **Sequelize: options object mutation**: Sequelize mutates the options object. Reusing across requests causes cross-request pollution. Always spread: `{ ...defaultOptions }`
- **Sequelize model mutation risk**: `item.promo_code_discount_amount = 0` mutates the model instance. If `.save()` called downstream, change persists to DB. Real: PR #5383 (svc-order). Use local variables or spread instead
- **Missing index on new filtered/sorted columns**: New column in WHERE or ORDER BY without index. Invisible in staging, devastating in prod with millions of rows
- **Cache TTL mismatch**: Default TTL (1h) for "threshold reached" keys causes duplicate notifications on expiry. Real: PR #1702 (svc-experiences). Set TTL to match business window (30 days, not 1 hour)
- **Read replica connection pool doubling**: Enabling replication creates two pg.Pool instances inheriting same `max` setting. Real: PR #1724 (svc-experiences) doubled from 50 to 100 total connections. Halve per-pool sizes when enabling replicas

## Security (D2 Security)

- **Mass assignment via `Model.create(req.body)`**: Entire body passed to ORM creates records with unintended fields. Whitelist: `const { name, email } = req.body`
- **Sensitive data in error responses**: `res.json({ error: err.message, stack: err.stack })` leaks internals. Log internally, return generic to client
- **Missing body size limit**: `express.json()` without `{ limit: '100kb' }` allows DoS via large payloads blocking JSON.parse
- **Express 4.x async routes without error forwarding**: Async handlers that throw don't trigger error middleware. Use `express-async-errors` or try-catch + `next(err)`. svc-experiences uses `@luxuryescapes/router` which handles this

## Express-Specific (D4 Error Handling)

- **Error middleware with 3 params instead of 4**: `app.use((err, req, res) => {...})` silently ignored by Express. MUST have 4 params. Real: PR #5434 and #5428 (svc-order) both had this. Fix: `(err, req, res, _next)`
- **`uncachedVerifyUser` vs `cachedVerifyUser`**: Write endpoints MUST use `uncachedVerifyUser()` (checks token not revoked). Read endpoints can use cached. Real: PR #5355 (svc-order) mutation endpoint used cached

## Idempotency (D10 Concurrency)

- **Scripts without idempotency guards**: Migration scripts that overwrite on re-run. Real: PR #5390 (svc-order) would overwrite `maxCancellationDate` on already-correct rows. Fix: `WHERE column IS NULL`
- **Duplicate entries from `flatMap`/`map`**: Nested collections produce duplicate IDs. Real: PR #1721 (svc-experiences) duplicate productId in PATCH body. Deduplicate with `Set` before sending to external APIs

## Provider Sync (D1 Correctness)

- **`onUpdate: true` + conditional field population = data wipe**: When changing a sync override rule from `onUpdate: false` to `true`, trace the FULL data flow: (1) what does `parseToOffer` default the field to (often empty string), (2) is the field conditionally populated before sync (e.g., AI generation only when missing), (3) what happens when the condition skips. If the parser default is empty and the condition skips, `onUpdate: true` writes empty to DB, wiping the existing value. Real: PR #1740 (svc-experiences) Collinson `dealDescription` flip-flop
- **`onInsert: true` propagates parser defaults**: `parseToOffer` values go straight to DB on first insert. Verify defaults for `curationStatus` (must be `NOT_CURATED`), `status`, `unlisted`. Real: PR #1759 CustomLinc shipped with `APPROVED`, 35 offers went live without curation

## Frontend / i18n

- **ICU FormattedMessage with optional user data**: `{firstName}, we've sent you...` renders `, we've sent you...` when firstName is empty (simplified signup, guest users). Fix: compute greeting with conditional punctuation in `values` prop: `greeting: firstName ? \`${firstName}, \` : ''` and use `{greeting}we've sent you...`. Real: PR #32269 (www-le-customer) LE Live simplified signup. Applies to ANY i18n message where user data (name, title) might be absent. The punctuation (comma, colon, dash) must be part of the computed value, not the template
- **www-le-admin SSO requires port 3000**: `start:dev` hardcodes Express BFF on port 3002, rspack dev server on port 3000. SSO callback is only registered for `localhost:3000`. Never change these ports. Architecture: rspack 3000 (client) -> Express 3002 (BFF)
- **www-le-admin `public/` directory is gitignored**: Worktrees and fresh clones don't have it. Express BFF fails to serve pages without it. Fix: `cp -r ../www-le-admin/public/ ./public/` before starting dev server in a worktree

## Express Query Parser (extended)

- **Express 5 `qs` arrayLimit default is 20**: Even with `app.set('query parser', 'extended')`, the underlying `qs` module has `arrayLimit: 20`. Arrays with >20 items silently become objects with numeric keys (`{0: 'a', 1: 'b', ...}`). Real: svc-tag, Chiamaka flagged in #engineering (2026-03-18). Fix: `app.set('query parser', (str) => qs.parse(str, { arrayLimit: 100 }))`. Check EVERY service using `app.set('query parser', 'extended')` for this limit

## Financial Calculation (D15 Financial Integrity)

Query vault with `financial calculation promo discount holdback` for full investigation cases.

- **Proportional split denominator**: MUST include ALL eligible items across ALL types. Each vertical "thinking" it has 100% of the promo = double-counting. Real: svc-order calcPromoPercentage same-type filtering bug
- **promoAmount consistency**: If two functions compute promoAmount independently, values WILL diverge. One source of truth, passed through. Real: calcAccountingAmount vs refundMetadata disagreement
- **Promo reduces vendor holdback**: `cash_amount - promoAmount` before calculating `accounting_amount` means vendor pays for LE's discount. Rule: promo = LE cost, NEVER vendor. Real: calcAccountingAmount L21
- **NULL promo_code_discount_amount**: NULL distributes promo proportionally wrong (treated as 0 by some callers, skipped by others). Guard: explicit `?? 0` with comment
- **FX rounding accumulation**: Converting each item individually vs converting the total produces different results. Multi-item orders with different currencies: verify rounding happens ONCE on the total, not per-item
- **item_discounts sent as empty array**: Intermittently `[]` when should have values, causing `promo_code_discount_amount = 0`. Real: Hardik Purohit edge case, svc-order

## Feature Flags (D1 Correctness, D17 Runtime Config)

Query vault with `feature flag env var Pulumi config` for infra patterns.

- **Both paths tested**: Flag ON and flag OFF must both work. Common bug: OFF path returns undefined or throws because nobody tested it
- **Default value on flag service unreachable**: Must be the safe/old behavior, not the new feature. If flag service is down and default is "enabled", untested feature goes live to 100%
- **Flag via Pulumi config, not code**: LE pattern: `le pulumi config set KEY "VALUE" --stack ENV`. NOT `le pulumi up`. Real: EXP-3472 CustomLinc
- **Feature starts ENABLED=false**: Pre-push checklist requires every new feature flag to start disabled in all environments
- **4-layer consistency**: Flag env var must exist in: (1) Pulumi YAML, (2) environment-variables.ts, (3) config file, (4) schema.ts. Missing any layer = deploy failure or silent default
- **Cleanup plan**: Temporary flags without removal ticket accumulate. Check if there's a follow-up ticket to remove the flag after rollout

## Dependency Changes (D12 Dependencies)

Query vault with `lib-auth-middleware breaking change library migration upgrade` for LE-specific library patterns.

- **lib-auth-middleware v3 breaks all test JWTs**: JWKS replaces static public key. Hardcoded RS256 tokens stop working. Fix: global `jest.mock` with header-based auth (`x-test-user-id`, `x-test-roles`). Real: svc-ee-offer migration
- **@luxuryescapes/router v3**: Supports zod but strummer still works. Recommended but not mandatory for DD migration
- **lib-logger v3 coupled to router v3**: Required for Datadog. Changing one often requires changing both
- **Contract version bump forgotten**: When `src/contract/server.ts` changes, MUST bump version in `src/contract/package.json`. Downstream consumers break silently. Real: svc-accommodation pattern
- **dotenv-safe rejects new env vars**: Adding optional env vars to `.env.example` crashes ALL tests in CI (CI doesn't have the var). Use `?? ''` fallback in non-prod config instead
- **Sequelize v5 vs v6**: `findOne` returns `null` not `undefined` in v6. `Model.init()` vs `define()` must match version
- **TypeORM 0.2 vs 0.3**: `getConnection()` removed in 0.3. `dataSource.query('UPDATE')` returns `[]` for affected rows (use RETURNING clause). Real: EXP-3540

## Cross-Service Review Checklist

When the PR touches multiple services or crosses team boundaries:

1. **Contract parity**: Consumer handles same values/types as source (boolean `true|false`, not just `true`)
2. **Schema coercion**: Same parsing approach (strummer `s.boolean({ parse: true })` vs Zod `z.coerce.boolean()`)
3. **Enum alignment**: Consumer validates against same enum values as source
4. **Related PRs**: Read diffs from related PRs in other repos (check Slack thread, PR body for links)
5. **Currency propagation**: Every cross-service call passes `currency` param explicitly
6. **Service owner notification**: If PR is in another team's repo, notify their Slack channel (see create-pr skill mapping)
