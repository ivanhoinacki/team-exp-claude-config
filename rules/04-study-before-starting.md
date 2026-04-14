---
description: Discovery phase before any development activity
alwaysApply: true
---

# Study Before Starting

## Phase 0: Environment (code tasks)

Check Docker running, `nvm use`, node_modules present.

## Phase 0.5: Vault RAG (MANDATORY, BEFORE any Read/Grep)

You MUST call `query_vault(query, service_filter)` BEFORE reading codebase files or external sources for any LE-related task. This is enforced by hook. No exceptions.

## Phase 1: Domain Routing

DB/access -> pitfalls-infra, Test-Simulation | AWS/IAM -> cli/USAGE, pitfalls-infra | CI -> CI-Checks-Reference | Provider -> Business-Rules/Providers, Provider-Patterns | Bug -> Bug-Triaging, Ecosystem, Business-Rules, Datadog | Multi-service -> Experiences-Ecosystem, Business-Rules/Orders | Promo/refund -> Business-Rules/Refunds, Promos, pitfalls-orders

Exhaust domain sources BEFORE trial-and-error.

## Phase 1.5: Business Rules (MANDATORY before code)

Read relevant `Knowledge-Base/Business-Rules/`. Does this rule affect implementation?

## Phase 2-3: Context + Prior Art

Memory/Vault -> CLI docs -> Codebase -> Git history -> GitHub PRs -> Confluence -> Slack.

## Ad-hoc Questions

ANY LE question: query_vault first, then pitfalls, Review-Learnings, Business-Rules.

ctx% > 60% -> suggest `/compact`.

CI: `yarn lint && yarn test:types && yarn build && yarn test:unit`
