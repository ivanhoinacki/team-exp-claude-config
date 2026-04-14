# Local Infrastructure (infra-le-local-dev)

Docker-based local environment at `~/Documents/LuxuryEscapes/infra-le-local-dev`.

## Services & Ports

| Service       | Container  | Host Port | Internal Port |
| ------------- | ---------- | --------- | ------------- |
| PostgreSQL 13 | postgres13 | 5432      | 5432          |
| PostgreSQL 14 | postgres14 | 5436      | 5432          |
| PostgreSQL 15 | postgres15 | 5437      | 5432          |
| PostgreSQL 16 | postgres16 | 5439      | 5432          |
| pgvector      | pg_vector  | 5438      | 5432          |
| Redis 4       | redis4     | 6379      | 6379          |
| Redis 5       | redis5     | 6380      | 6379          |
| Redis 6       | redis6     | 6381      | 6379          |
| Redis 7       | redis7     | 6382      | 6379          |
| Valkey 8      | valkey8    | 6383      | 6379          |
| Nginx proxy   | nginx_v2   | 8083      | 80            |
| LocalStack    | localstack | 4566      | 4566          |
| ElasticMQ     | elasticmq  | 9324      | 9324          |
| MinIO         | minio      | 9000/9001 | 9000/9001     |

## Nginx Proxy (routing)

The proxy at `localhost:8083` routes API requests to either local services or test environment.

**Default behavior:** routes to test environment ELB (`cdn.test.luxuryescapes.com`).

**To route to a local service:** set the port env var in `.env` and rebuild:

```bash
# .env
EXPERIENCES_PORT=3000
# then: docker compose up --build nginx_v2
```

**Injection mechanism:** `infra-api-luxgroup-com/docker_nginx_v2_local_services.sh` replaces the endpoint hostname with `host.docker.internal:<PORT>` and strips SSL config.

**Routing configs:** 92 service configs in `infra-api-luxgroup-com/proxy-v2/config/nginx/conf.d/`. Each maps URL patterns (e.g., `/api/experiences/*`) to a service variable.

## Pre-test Environment Check

All containers are already configured in docker-compose. They just need to be **started**, not set up.

Before running tests that need infra (integration tests, DB migrations, API calls):

1. Check which DB/Redis version the target service uses (read its config/env, don't assume postgres13)
2. Verify the required containers are running:
   ```bash
   docker ps --format '{{.Names}}' | grep -E 'postgres|redis|nginx'
   ```
3. If containers are down, start them:
   ```bash
   cd ~/Documents/LuxuryEscapes/infra-le-local-dev && docker compose up -d <specific-containers>
   ```

## New infrastructure dependency detected

If during KB search or codebase discovery the feature requires a service/image NOT already in docker-compose (e.g., a new message broker, a new DB engine, OpenSearch, a new external emulator), **stop and tell the user**:

- What service is needed and why (reference KB doc or code that requires it)
- Whether it already exists in docker-compose (check `~/Documents/LuxuryEscapes/infra-le-local-dev/docker-compose.yml`)
- If it doesn't exist, suggest adding it to docker-compose or an alternative approach

Never silently skip infra dependencies. If the feature needs it, flag it.

## When tests fail and infra might be the cause

Before investigating code, check:

1. `docker ps` — are required containers running?
2. `docker logs <container>` — any container errors?
3. Port connectivity — is the service reachable on the expected port?
4. Service env vars — does the service config point to the right port/host?

If infra is the problem, fix it before re-running tests. Don't chase code bugs caused by missing infra.

## Manual API Testing (Postman fallback)

When Claude can't directly test an API endpoint (auth tokens, browser cookies, complex flows):

- Suggest the user test via Postman through the proxy: `http://localhost:8083/api/...`
- Provide the exact curl command as reference
- If debugging a response, ask the user to share the Postman response body
