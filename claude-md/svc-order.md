# Service Dossier: svc-order

## Architecture
- Layers: src/api/v1/ (controllers, handlers, routes, presenters) → src/context/{vertical}/ → src/queries/ → src/models/
- Lib: src/lib/ (228 utility modules, including promoCodeUtils, refund logic, accounting)
- Validation: jsonschema
- ORM: Sequelize 6 + sequelize-typescript
- DB: PostgreSQL (pg 8.7)
- Queue: Bull for background jobs (src/jobs/)
- Constants: src/constants/ (37 domains)
- Owner: team-customer-payments (since Feb 2026). Channel: #team-customer-payments. Custodian: Andy Welch
- Node: 22.20.0 | Scripts: yarn dev, yarn build, yarn test:jest, yarn db:migrate

## Pre-flight (verify BEFORE implementing)
- [ ] transactionKey filtered in filterItemDiscounts? (without filter = double-counting)
- [ ] Promo split denominator includes ALL items across ALL types?
- [ ] costPriceData populated for the vertical? (experience refundMetadata needs it)
- [ ] calcAccountingAmount uses promoAmount explicit (not calcPromoPercentage deprecated)?
- [ ] .env copied from .env.example? (Jest fails without it)
- [ ] DB name uses underscore? (svc_order, not svc-order)

## Pitfalls (condensed, full detail: pitfalls-orders.md)
- calcPromoPercentage NULL fallback: NULL promo_code_discount_amount distributes promo proportionally wrong
- calcPromoPercentage same-type filtering: each vertical "thinks" it has 100% of promo. Multi-type orders break
- Proportional split: denominator MUST include ALL eligible items across ALL types
- experience/refundMetadata.js missing costPriceData: cost_price = 0, holdback invisible in admin
- calcAccountingAmount L21: promoAmount reduces cash_amount, affects vendor holdback. Promo = LE cost, NEVER vendor
- calcAccountingAmount has TWO different promoAmounts: parameter vs calculated. Divergence = accounting_amount wrong
- Zero observability for holdback/accounting: no alerts, only Finance discovers manually
- filterItemDiscounts without transactionKey = ALL discounts returned for EACH item (double-counting)
- ID stability: transactionKey must be stable throughout the chain (svc-promo → frontend → svc-order → DB)
- totalItemDiscounts() always returns 0 for new orders (null input)

## Knowledge Base & Tools (check BEFORE coding)
**MANDATORY**: Call `query_vault` BEFORE reading code, attempting fixes, or starting any investigation.

- **Vault RAG (ALWAYS FIRST)**: `query_vault(query="<keywords>", service_filter="svc-order")` — pitfalls, review-learnings, business rules, runbooks indexed from the team vault
- **Ext. library docs**: Context7 MCP — `resolve-library-id("sequelize")` then `query-docs` for up-to-date API docs
- **Slack**: `slack_search_public_and_private(query="<error or topic>")` — past team discussions, incident threads
- **Jira**: `jira_get_issue(issue_key="EXP-XXXX")` — ticket context, acceptance criteria, linked issues
- **Confluence**: `confluence_search(query="<topic>")` — internal docs, architecture, runbooks
- **Datadog**: `search_datadog_logs(query="service:svc-order <error>")` — prod logs, traces
- **GitHub**: `gh pr list --search "<query>" --repo user/repo` via Bash — past PRs, review discussions

## Business Rules
- Promo is LE cost, NEVER vendor cost (holdback calculation)
- MyEscapes "Add experience" creates NEW order (not appendItems)
- Each vertical has its own refund flow (accommodation ≠ experience ≠ bedbank)
- svc-order shared code: always check existing GitHub PRs before implementing fix (PR #5417 merged+reverted 2x)
- F5 on checkout clears promo from Redux, but is not the valid bug trigger (transactionKey mismatch is)

## Patterns
- Entry point: npx nodemon src/server.js (not node src/server.js, nodemon configures ts-node)
- Experience items: per-item promo_code_discount_amount bypasses proportional calc
- Refund metadata: vertical-specific (accommodation/refundMetadata vs experience/refundMetadata)
- NODE_TLS_REJECT_UNAUTHORIZED=0 for local calling staging APIs (never in prod)

## Setup (non-obvious)
- Entry: npx nodemon src/server.js (NOT node src/server.js)
- .env required: cp .env.example .env before running tests
- NODE_TLS_REJECT_UNAUTHORIZED=0 when calling staging HTTPS APIs locally
- DB name: svc_order (underscore, not hyphen) in RDS
- Car-hire searchId lives in Redis (TTL 20min), local tests need local svc-order running
