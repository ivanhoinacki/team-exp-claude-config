# Service Dossier: infra-le-local-dev

## Purpose
Local development infrastructure orchestrator. Docker Compose services (Postgres, Redis, OpenSearch, LocalStack, Nginx proxy) that simulate the production environment locally for ~80 microservices.

## Architecture
- Docker Compose: main (postgres, redis, valkey, nginx), opensearch, localstack
- Nginx proxy: http://localhost:8083 routes to local services via env var port mapping
- DB versions: PostgreSQL 12, 13, 14, 15, 16 (multi-version support)
- Cache: Redis 4-7 + Valkey 8
- Search: OpenSearch (requires AWS profile le-test-v1-search)
- Queues: LocalStack (SES, SQS, SNS, S3 emulation)
- Process manager: pm2
- Node: 24.14.0 | Scripts: yarn start, yarn db-clone, yarn git-clone, yarn git-pull

## Key Files
- docker-compose.yml: main services (postgres, redis, valkey, nginx_v2)
- docker-compose.opensearch.yml: OpenSearch + dashboards + AWS credential refresh
- docker-compose.localstack.yml: SES, SQS, SNS, S3 local emulation
- .env: all service port mappings (copy from .env.example, uncomment needed ports)
- _libexec/: helper scripts (clone repos, pull latest, manage dbs, pm2)
- docker/: Dockerfiles per service version

## Pre-flight (verify BEFORE changing)
- [ ] .env copied from .env.example? (never commit .env)
- [ ] Conflicting ports with other local services? (check lsof -i :PORT)
- [ ] Mac/Windows: LOCALHOST=host.docker.internal uncommented?
- [ ] OpenSearch: AWS profile le-test-v1-search configured?
- [ ] GITHUB_TOKEN set in .env for git-clone of private repos?

## Knowledge Base & Tools (check BEFORE coding)
**MANDATORY**: Call `query_vault` BEFORE reading code, attempting fixes, or starting any investigation.

- **Vault RAG (ALWAYS FIRST)**: `query_vault(query="<keywords>", service_filter="infra-le-local-dev")` — pitfalls, review-learnings, business rules, runbooks indexed from the team vault
- **Slack**: `slack_search_public_and_private(query="<error or topic>")` — past team discussions, incident threads
- **Confluence**: `confluence_search(query="docker local dev setup")` — internal docs, runbooks
- **GitHub**: `gh pr list --search "<query>" --repo user/repo` via Bash — past PRs, review discussions

## Pitfalls
- Mac/Windows users: LOCALHOST must be host.docker.internal (not localhost)
- WSL2: LOCALHOST=$(hostname -I | xargs) when running compose
- OpenSearch snapshot restore requires AWS SSO credential refresh sidecar
- Ports are localhost-only (127.0.0.1) for security
- db-clone pulls databases from staging via AWS: requires VPN + le aws login
- Nginx v2 builds from repo infra-api-luxgroup-com: must be cloned

## Common Operations
- Start all: docker-compose up -d
- Start specific DB: docker-compose up -d postgres16
- Clone all repos: yarn git-clone
- Pull latest: yarn git-pull
- Clone test DBs from staging: yarn db-clone
- Monitor processes: yarn status / yarn logs
- Stop all: docker-compose down
