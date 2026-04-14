# Service Dossier: svc-ee-offer

## Purpose
White-Label Everyday (LED) offers service. Manages offer data, inventory, bookings, availability, and Salesforce integration for the Everyday vertical.

## Architecture
- Layers: api/v1/ (routes, controllers, handlers, schemas, validators) → operations/ → models/ → lib/
- Validation: AJV v8 + JSONSchema
- ORM: Sequelize 6 (define pattern, 38 models)
- DB: PostgreSQL (dual schema: Salesforce heroku-connect synced tables + public schema)
- Queue: Background jobs in jobs/ (sync-inventory, sync-salesforce, order processing, expire bookings)
- Auth: role-based access via constants/roles
- APM: Datadog (dd-trace)
- Node: 22.20.0 | Scripts: yarn dev, yarn build, yarn test, yarn lint, yarn db:migrate

## Pre-flight (verify BEFORE implementing)
- [ ] Which schema? Salesforce (heroku-connect) or public? (SF tables are read-only in the app)
- [ ] Sequelize model uses define pattern (not decorators like TypeORM)?
- [ ] Inventory sync job impacted by the change? (sync-inventory, sync-salesforce)
- [ ] AJV schema registered for the route?
- [ ] Booking expiration logic considered? (expire-reserved-bookings job)

## Pitfalls
- Salesforce tables are synced via heroku-connect: NEVER write directly to them from the app
- Sequelize 6 uses define pattern (different from TypeORM 0.3 in svc-experiences)
- Dual schema: queries may need to specify schema explicitly
- LED offers are pre-curated (curationStatus APPROVED): different from other providers that use NOT_CURATED
- Inventory sync has dedicated jobs: changes to availability/inventory may affect sync
- Order processing is asynchronous via Bull jobs

## Knowledge Base & Tools (check BEFORE coding)
**MANDATORY**: Call `query_vault` BEFORE reading code, attempting fixes, or starting any investigation.

- **Vault RAG (ALWAYS FIRST)**: `query_vault(query="<keywords>", service_filter="svc-ee-offer")`, pitfalls, review-learnings, business rules, runbooks indexed from the team vault
- **Ext. library docs**: Context7 MCP, `resolve-library-id("sequelize")` then `query-docs` for up-to-date API docs
- **Slack**: `slack_search_public_and_private(query="<error or topic>")`, past team discussions, incident threads
- **Jira**: `jira_get_issue(issue_key="EXP-XXXX")`, ticket context, acceptance criteria, linked issues
- **Confluence**: `confluence_search(query="<topic>")`, internal docs, architecture, runbooks
- **Datadog**: `search_datadog_logs(query="service:svc-ee-offer <error>")`, prod logs, traces
- **GitHub**: `gh pr list --search "<query>" --repo user/repo` via Bash, past PRs, review discussions

## Business Rules
- LED = Lux Everyday = svc-ee-offer = Salesforce Connect
- LED offers are pre-curated via Salesforce (APPROVED by default)
- Inventory comes from Salesforce via heroku-connect sync
- Bookings have states reserved → confirmed → expired
- Availability is managed via Salesforce, not directly in the app

## Patterns
- New endpoint: api/v1/ route → controller → handler → operation → model
- Validation: AJV schema + JSONSchema (not Strummer/Zod)
- Model: Sequelize define pattern with explicit schema reference
- Background job: jobs/ directory, Bull queue processing
