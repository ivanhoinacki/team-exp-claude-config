# Service Dossiers (CLAUDE.md)

Pre-built `CLAUDE.md` files for Luxury Escapes repositories. Each dossier gives Claude instant context about a service: stack, commands, architecture, patterns, and known gotchas.

## Available Dossiers (9)

| File | Service | Stack |
|---|---|---|
| `svc-experiences.md` | Experience booking API | TypeScript, TypeORM, PostGIS, Express |
| `svc-ee-offer.md` | LED/Salesforce offer sync | TypeScript, Sequelize, Salesforce Connect |
| `svc-order.md` | Order lifecycle and payments | TypeScript, Sequelize, BullMQ |
| `svc-occasions.md` | Gift cards and occasions | TypeScript, Prisma, Express 5 |
| `svc-search.md` | Search and discovery | TypeScript, Elasticsearch |
| `svc-sailthru.md` | Email marketing integration | TypeScript, Sailthru API |
| `www-le-customer.md` | Customer-facing frontend | React 19, Redux, styled-components |
| `www-le-admin.md` | Admin/vendor portal | React, internal APIs |
| `infra-le-local-dev.md` | Local Docker infrastructure | Docker Compose, PostgreSQL, Redis, Nginx |

## How dossiers work

During setup, each dossier is copied to the root of its matching repository as `CLAUDE.md`. Claude Code reads this file automatically when working inside that repo, providing:

- Available commands (`yarn dev`, `yarn test`, `yarn migration:run`)
- Architecture overview (layers, patterns, directory structure)
- Database and config details
- Known pitfalls and gotchas
- Testing patterns and conventions

## Installation

The setup script handles this automatically (Phase 5.6). It searches your codebase root for matching repo directories and copies the dossier.

## Creating a new dossier

1. Copy an existing dossier as a template
2. Fill in: service name, stack, commands, architecture, patterns, gotchas
3. Add to `claude-md/` in this repo
4. Run `bash scripts/update.sh` to deploy it
