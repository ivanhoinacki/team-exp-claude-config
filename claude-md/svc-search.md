# Service Dossier: svc-search

## Architecture
- Layers: src/apps/ (service definitions) → src/controllers/ → src/services/ → src/repo/ → src/models/
- Validation: Zod 4.3 (schemas in src/schema/)
- ORM: Sequelize 6 + OpenSearch 3.5 (dual data store)
- DB: PostgreSQL + OpenSearch + Redis (ioredis)
- Queue: Bull for background jobs (src/bull/)
- CLI: src/cli.ts for data loading/syncing tasks
- Framework: Express 5 + @luxuryescapes/router 3.3 (auto OpenAPI generation)
- Scheduled tasks: Pulumi.{env}.yaml under scheduledTasks, factories.createScheduledTask()
- Owner: Search team
- Node: 24.10.0 | Scripts: yarn dev, yarn build, yarn test

## Pre-flight (verify BEFORE implementing)
- [ ] Price filters converted to AUD? (priceGte/priceLte arrive in local currency, DB is AUD)
- [ ] PR title format correct? ([TICKET-123] Description or [FEAT] Description)
- [ ] Sync pattern with all resilience? (throw on 0 results, per-item try/catch, remove failed from seenIds)
- [ ] eslint --fix run? (prettier/eslint stricter than svc-experiences)
- [ ] CircleCI: approval gates from other teams checked before merge?

## Pitfalls (condensed, full detail: pitfalls-search.md)
- prettier/eslint stricter: no-explicit-any, use catch (error) + instanceof Error
- PR title: regex enforced by GitHub Action, [TICKET-123] or [FEAT] required
- Sync resilience: match ALL patterns from updateOffers (throw, try/catch, seenIds cleanup)
- Price filters: priceGte/priceLte arrive in local currency, eo.price is AUD. Must priceRangeInAUD()
- Production approval gate: merge to master triggers build, prod deploy needs manual approval
- Pending deploys: merging YOUR PR can push OTHER team's code to prod. ALWAYS check CircleCI first
- Datadog task naming: svc-search-{app}-{task-name} (different from -main/-queues convention)
- Manual task: le aws exec svc-search --env {env} -- yarn run cli {app} {task}
- Disabled tasks: disabled: true + cronSchedule: "cron(0 0 1 1 ? 2099)" in Pulumi

## Knowledge Base & Tools (check BEFORE coding)
**MANDATORY**: Call `query_vault` BEFORE reading code, attempting fixes, or starting any investigation.

- **Vault RAG (ALWAYS FIRST)**: `query_vault(query="<keywords>", service_filter="svc-search")`, pitfalls, review-learnings, business rules, runbooks indexed from the team vault
- **Ext. library docs**: Context7 MCP, `resolve-library-id("sequelize")` then `query-docs` for up-to-date API docs
- **Slack**: `slack_search_public_and_private(query="<error or topic>")`, past team discussions, incident threads
- **Jira**: `jira_get_issue(issue_key="EXP-XXXX")`, ticket context, acceptance criteria, linked issues
- **Confluence**: `confluence_search(query="<topic>")`, internal docs, architecture, runbooks
- **Datadog**: `search_datadog_logs(query="service:svc-search-main <error>")`, prod logs, traces (use `svc-search-{app}-{task}` for tasks)
- **GitHub**: `gh pr list --search "<query>" --repo user/repo` via Bash, past PRs, review discussions

## Business Rules
- Search team owns deploy approval. Coordinate before merging
- Price in DB is always AUD, convert at query time
- OpenSearch indexes need migration (yarn opensearch:migrate)
- Scheduled tasks configured in Pulumi, not in code

## Patterns
- New sync task: replicate updateOffers with ALL resilience (throw, try/catch, seenIds)
- Price filtering: priceRangeInAUD() before any price query
- CLI tasks: src/cli.ts with app + task pattern
- On-demand tasks: disabled: true + far-future cron in Pulumi

## Setup (non-obvious)
- Node 24.10.0 (different from svc-experiences 22.20.0)
- Test heap: 3.8GB (--max-old-space-size=3800 in jest config)
- OpenSearch required locally for integration tests
