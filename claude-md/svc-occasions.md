# Service Dossier: svc-occasions

## Purpose
Occasions service. Handles Weddings (gift registries, guest management, contributions) and Corporate Events.

## Architecture
- Layers: api/ (router, controllers, contract/schema) → services/ → contexts/ → clients/
- Validation: Zod v4.1 (type-safe API contracts)
- ORM: Prisma v6.14 (with read replicas)
- DB: PostgreSQL (via Prisma)
- Queue: Bull jobs in jobs/
- Events: @luxuryescapes/lib-events v4 (event bus publishing/handling)
- Framework: Express 5 + @luxuryescapes/lib-router v3.1
- Cache: Redis (ioredis)
- APM: Datadog (dd-trace)
- Node: 24.5.0 | Scripts: yarn dev, yarn build, yarn test, yarn db:migrate

## Pre-flight (verify BEFORE implementing)
- [ ] Prisma schema updated? (yarn db:generate after changes)
- [ ] Read replica configured for read-only queries?
- [ ] Zod schema validates input in contract layer?
- [ ] Event publishing to lib-events when state changes?
- [ ] Node version 24.5.0 (different from other services)?

## Pitfalls
- Prisma 6: dd-trace patches tracingHelper to undefined, DD_TRACE_ENABLED=false in CI
- Prisma migrations: yarn db:migrate (not TypeORM or Sequelize)
- Prisma studio: yarn db:studio to visualize data
- Node 24.5.0: different version from most services (22.20.0)
- Express 5 + lib-router: query parser behavior may differ from Express 4 services
- Event-driven: state changes publish events, consumers may be affected

## Knowledge Base & Tools (check BEFORE coding)
**MANDATORY**: Call `query_vault` BEFORE reading code, attempting fixes, or starting any investigation.

- **Vault RAG (ALWAYS FIRST)**: `query_vault(query="<keywords>", service_filter="svc-occasions")` — pitfalls, review-learnings, business rules, runbooks indexed from the team vault
- **Ext. library docs**: Context7 MCP — `resolve-library-id("prisma")` then `query-docs` for up-to-date API docs
- **Slack**: `slack_search_public_and_private(query="<error or topic>")` — past team discussions, incident threads
- **Jira**: `jira_get_issue(issue_key="EXP-XXXX")` — ticket context, acceptance criteria, linked issues
- **Confluence**: `confluence_search(query="<topic>")` — internal docs, architecture, runbooks
- **Datadog**: `search_datadog_logs(query="service:svc-occasions <error>")` — prod logs, traces
- **GitHub**: `gh pr list --search "<query>" --repo user/repo` via Bash — past PRs, review discussions

## Business Rules
- Weddings: gift registries with guest management and contribution tracking
- Corporate Events: event planning and management
- Event bus: state changes publish events consumed by other services
- Read replicas: use for read-heavy queries, write to primary only

## Patterns
- New endpoint: api/controllers/ → services/ → Prisma queries
- Validation: Zod schemas in api/contract/ (auto-generates OpenAPI)
- DB changes: update prisma/schema.prisma → yarn db:generate → yarn db:migrate
- Background job: jobs/ directory, Bull queue
- External calls: clients/ directory for inter-service communication
