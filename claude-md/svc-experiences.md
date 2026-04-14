# Service Dossier: svc-experiences

## Architecture
- Layers: controllers/{domain}/controller.ts + schema.ts → contexts/{domain}/context.ts → queries/{domain}/queries.ts
- Handlers: handlers/{domain}/handler.ts (response formatting)
- Validation: Strummer (s.string(), s.enum(), s.integer({ parse: true }))
- ORM: TypeORM 0.3 (entities in models/, migrations in src/migration/)
- DB: PostgreSQL 16 + PostGIS
- Entry: Express 5 via @luxuryescapes/router
- Query parser: app.set('query parser', extended) with arrayLimit: 100
- Config chain: Pulumi YAML → environment-variables.ts → config/*.ts → schema.ts
- Datadog: svc-experiences-main (API), svc-experiences-queues (workers), svc-experiences-events (consumers)
- Node: 22.20.0 | Scripts: yarn dev, yarn build, yarn test:unit, yarn db:migrate

## Pre-flight (verify BEFORE implementing)
- [ ] Currency param passed in inter-service calls? (default AUD without it)
- [ ] curationStatus = NOT_CURATED for new providers? (APPROVED = live immediately without curation)
- [ ] Active status filter consistent between list and detail endpoints?
- [ ] Admin queries do NOT filter by active status? (admin = manage inactive entities)
- [ ] DISTINCT ON in queries of junction tables (offer_attractions)?
- [ ] RETURNING clause in raw UPDATE/DELETE? (without it, result is always [])
- [ ] Enum exists in codebase? (grep Object.values before hardcoding)
- [ ] Auth roles (canBeAccessedBy) same in ALL routes of feature group?

## Pitfalls (condensed, full detail: pitfalls-experiences.md)
- showUnlisted=true for complementary experiences (default false)
- curationStatusIn default ['APPROVED'], only returns approved items
- Currency param missing = default AUD. convertCurrency does amount→AUD→target with _.ceil()
- TypeORM getCount() does not strip .offset()/.limit(), clone QB
- GROUP BY: columns that vary per row create duplicate groups, use MAX/MIN
- Express 5 qs arrayLimit=20: arrays >20 become objects silently
- offers_locations JSONB key is 'description', NOT 'city'
- Sync onUpdate: true + conditional population = data wipe (always populate parsedOffer)
- ECS migration: batch per entity, not bulk INSERT...SELECT (timeout)
- Image ID from provider ≠ Cloudinary public ID, use urls[0].url
- Pipeline curated field: use _curated boolean flag + CASE WHEN curated THEN keep
- LLM output: always Array.isArray() guard, normalize nested coordinates
- Datadog service:svc-experiences returns nothing, use suffix -main/-queues/-events

## Knowledge Base & Tools (check BEFORE coding)
**MANDATORY**: Call `query_vault` BEFORE reading code, attempting fixes, or starting any investigation.

- **Vault RAG (ALWAYS FIRST)**: `query_vault(query="<keywords>", service_filter="svc-experiences")` — pitfalls, review-learnings, business rules, runbooks indexed from the team vault
- **Ext. library docs**: Context7 MCP — `resolve-library-id("typeorm")` then `query-docs` for up-to-date API docs
- **Slack**: `slack_search_public_and_private(query="<error or topic>")` — past team discussions, incident threads
- **Jira**: `jira_get_issue(issue_key="EXP-XXXX")` — ticket context, acceptance criteria, linked issues
- **Confluence**: `confluence_search(query="<topic>")` — internal docs, architecture, runbooks
- **Datadog**: `search_datadog_logs(query="service:svc-experiences-main <error>")` — prod logs, traces (use `-main`, `-queues`, or `-events` suffix)
- **GitHub**: `gh pr list --search "<query>" --repo user/repo` via Bash — past PRs, review discussions

## Business Rules
- Offers are the center of gravity, not attractions (commercial + curators focus on offers)
- "Provider" not "vendor" (provider = data source, vendor = business operator)
- Provider sync: onInsert propagates parser defaults, verify curationStatus/status/unlisted
- Offer status ONLINE ≠ available (availability comes from provider in real-time)
- External images: SharePoint > Getty > offer hero. Never Wikipedia without checking license
- Staging CDN (test-images) does not have same images as prod (images)

## Patterns
- New endpoint: controller.ts (route + handler) → schema.ts (Strummer) → context.ts (logic) → queries.ts (DB) → tests
- New migration: batched approach for ECS (one entity at a time, not bulk)
- Junction dedup: DISTINCT ON (entity_id) for offer_attractions
- Pipeline + curation: field_curated BOOLEAN DEFAULT false, CASE WHEN curated THEN keep
- Nearest coordinate: LATERAL JOIN (SELECT ... ORDER BY ST_Distance LIMIT 1)
- Provider images: img.urls[0].url with startsWith('http') guard
- Country normalization: resolveCountryName() with COUNTRY_CODE_TO_NAME map

## Setup (non-obvious)
- Dual DB migrations: run on BOTH dev + spec databases before tests
- Staging scripts: Node 22.20.0 + le aws login + le-tunnel.sh + URL-encode IAM token + DATABASE_USE_SSL=true
- Dev config: copy src/config/development.ts from main repo (gitignored, not in worktrees)
- CORS middleware: verify PATCH/DELETE in Access-Control-Allow-Methods when adding new HTTP methods
