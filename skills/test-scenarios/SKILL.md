---
name: test-scenarios
description: |
  Validate feature with real test scenarios before commit. Verifies environment (Docker, VPN, DB), seeds test data, runs unit + integration tests, and executes manual smoke tests against local or staging.
  Use after /code-review and before /commit. Use when the user says "test", "testar", "test scenarios", "smoke test", "integration test", "valida no staging", "roda os testes", "testa isso", "verifica se funciona", "run tests", or when the workflow reaches the test gate. Do NOT use for just running `yarn test` (that's a direct command).
model: haiku
argument-hint: [feature description or ticket number]
compatibility: Requires docker, git, gh (GitHub CLI), yarn, node, psql (PostgreSQL client)
allowed-tools: Bash(git *), Bash(gh *), Bash(docker *), Bash(curl *), Bash(yarn *), Bash(npx *), Bash(node *), Bash(psql *), Read, Write, Edit, Grep, Glob, Agent
---

## Phase 0: Vault RAG (MANDATORY, BEFORE any Read/Grep)

You MUST call `query_vault(query, service_filter)` BEFORE reading codebase files or external sources. This is enforced by hook. No exceptions.

---

# Test Scenarios -- Real Validation Before Commit

Validate that the feature works with real data, not just unit test mocks. Covers environment setup, test data seeding, automated tests, and manual smoke tests.

## When to Use

After `/code-review` approves, before `/commit`. This is a quality gate.

```
/feature-dev -> /deslop -> /code-review -> /test-scenarios -> /commit -> /create-pr
```

## Common Agent Mistakes

1. **Running tests without checking infra**: Tests fail because Docker containers are down, not because code is wrong. Always verify environment first
2. **Testing only happy path**: Missing edge cases, error paths, empty arrays, null values. Every scenario needs positive + negative + edge
3. **Assuming staging data matches expectations**: Staging data changes daily. Always verify test data exists before running smoke tests
4. **Not asking user for VPN/tunnel**: DB access and staging APIs require VPN. Always ask if VPN is connected before any remote operation
5. **Skipping test data setup**: Running integration tests against empty tables. Seed or verify data exists first
6. **Running against empty local DB for provider features**: When testing features that depend on real provider data (SSC/CMC sync, images, pickup points), the local DB is empty. ALWAYS ask user for VPN + `le aws login`, then set up staging DB tunnel via `le-tunnel.sh` and configure `.env` to point to the tunnel BEFORE starting the service. Without this, images won't load (Cloudinary IDs not in local DB) and synced data won't exist

---

## Phase 1: Environment Verification

### 1.1 Local Infrastructure

```bash
# Check Docker containers
docker ps --format '{{.Names}}' | grep -E 'postgres|redis|nginx'

# Check which DB the service uses (from MEMORY.md Quick Configs)
# svc-experiences: PG16 :5439
# svc-ee-offer: PG14 :5436
# svc-order: PG (needs .env)
# svc-car-hire: Prisma
```

If containers are down:
```bash
cd ~/Documents/LuxuryEscapes/infra-le-local-dev && docker compose up -d postgres16 redis7 nginx_v2
```

### 1.2 Service Running

```bash
# Check if the service is running locally
curl -s http://localhost:PORT/health 2>/dev/null | head -1 || echo "Service not running"
```

Service ports (from MEMORY.md):
- svc-experiences: 8893
- svc-traveller: 8099
- svc-auth: 8888
- svc-order: check .env

If not running, start:
```bash
cd ~/Documents/LuxuryEscapes/SERVICE && yarn dev
```

### 1.3 Remote Access (if testing against staging)

**STOP and ask the user:**
```
Testing against staging requires:
1. VPN connected (FortiClient)?
2. AWS session active? (le aws login -e staging -t experiences)

Please confirm before I proceed.
```

NEVER attempt staging DB or API calls without user confirming VPN is connected.

If DB tunnel needed:
```bash
le-tunnel.sh -s SERVICE -d DB_NAME -m ro
# or
le aws postgres --tunnel-only -s SERVICE --connection-mode ro -d DB_NAME
```

---

## Phase 2: Automated Tests

### 2.1 Unit Tests

```bash
# Run only tests affected by changes
yarn test --changedSince=main

# If specific test file
yarn test -- --testPathPattern="contexts/DOMAIN"
```

All tests MUST pass. If any fail, investigate and fix before proceeding.

### 2.2 Type Check + Lint

```bash
yarn test:types 2>/dev/null || yarn tsc --noEmit
yarn lint
```

### 2.3 Integration Tests (if applicable)

Check if the service has integration tests using Glob tool:
- Pattern `**/*.integration.test.*` in `src/`
- Pattern `**/*.e2e.test.*` in `src/`

If they exist, verify DB is running and run:
```bash
APP_ENV=spec yarn test:integration 2>/dev/null || echo "No integration test script"
```

For svc-experiences dual DB:
```bash
APP_ENV=development yarn migration:run
APP_ENV=spec yarn migration:run
```

---

## Phase 3: Test Scenario Design

Based on the feature changes, design concrete test scenarios:

### 3.1 Identify What Changed

```bash
GIT_EDITOR=true git diff main --name-only
```

### 3.2 Build Scenario Matrix

For each changed endpoint/function, create:

```markdown
## Test Scenarios

| # | Scenario | Type | Input | Expected | How to Test |
|---|----------|------|-------|----------|-------------|
| 1 | Happy path | Positive | [valid input] | [expected output] | curl / unit test |
| 2 | Empty input | Edge | [] or null | [graceful handling] | curl / unit test |
| 3 | Invalid params | Negative | [wrong type/value] | 400 with message | curl |
| 4 | Unauthorized | Security | No auth token | 401 | curl |
| 5 | Not found | Edge | Non-existent ID | 404 or empty array | curl |
| 6 | Large dataset | Performance | 1000+ items | Response < 2s | curl with timing |
| 7 | Concurrent | Concurrency | 2 simultaneous | No duplicates | parallel curl |
```

### 3.3 Generate Curl Commands

For each endpoint in the diff, generate ready-to-run curl commands:

**Local:**
```bash
curl -s http://localhost:PORT/api/ENDPOINT?params | jq .
```

**Staging (via proxy):**
```bash
curl -s http://localhost:8083/api/ENDPOINT?params | jq .
```

**Staging (direct, requires VPN):**
```bash
curl -s https://cdn.test.luxuryescapes.com/api/ENDPOINT?params | jq .
```

### 3.4 Test Data Requirements

Identify what data is needed in the DB for scenarios to work:

```markdown
## Test Data

| Data | Where | How to Get/Create |
|---|---|---|
| Active offer | offers table | Query: SELECT id FROM offers WHERE status = 'ONLINE' LIMIT 1 |
| Experience booking | svc-order | Use Test-Simulation.md spoofing or admin |
| Specific provider offer | offers | Query by provider_key |
| Customer with orders | svc-order | Test-Simulation.md customer IDs |
```

Check `Knowledge-Base/Local-Development/Test-Simulation.md` for staging test data (offers, customers, orders).

---

## Phase 4: Execute Smoke Tests

### 4.1 Local Smoke Tests

Run each curl command from Phase 3.3 against local service. Verify:
- Response status code matches expected
- Response body structure is correct
- New fields/filters work as designed
- Edge cases return graceful errors

### 4.2 Staging Smoke Tests (if applicable)

Only run against staging if:
- Feature touches cross-service flow (svc-experiences -> svc-order)
- Feature depends on data not available locally (provider sync data)
- User explicitly asks for staging validation

**Before staging tests, confirm with user:**
```
Ready to test against staging. This requires VPN. Proceed?
```

### 4.3 DB Verification (if migration or data change)

```sql
-- Verify migration ran
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'TABLE' ORDER BY ordinal_position;

-- Verify data integrity
SELECT count(*) FROM TABLE WHERE new_column IS NOT NULL;

-- Verify indexes exist
SELECT indexname FROM pg_indexes WHERE tablename = 'TABLE';
```

---

## Phase 5: Generate Manual-E2E-Recipe (MANDATORY)

After all tests pass, persist the test recipe as a reusable file in the feature folder. This file is the source of truth for how to reproduce and validate the feature manually. It MUST exist before `/create-pr`.

### 5.1 Locate or create the feature folder

```bash
VAULT="__VAULT_ROOT__"
TICKET="EXP-XXXX"  # from arguments or branch name

# Search for existing feature folder
FOLDER=$(find "$VAULT/Development/Features" -maxdepth 2 -type d -name "*${TICKET}*" | head -1)
if [ -z "$FOLDER" ]; then
  echo "WARN: No feature folder found for $TICKET. Ask user where to save."
fi
```

### 5.2 Write Manual-E2E-Recipe.md

Save the file at `$FOLDER/Manual-E2E-Recipe.md` with this exact structure:

```markdown
# Manual E2E Recipe: EXP-XXXX - [Feature Name]

## Environment Setup

### Local (minimum)
- [ ] Docker running: `docker ps` (postgres, redis, nginx)
- [ ] Node version: `nvm use` (check .nvmrc)
- [ ] Service running: `yarn dev` on port XXXX
- [ ] [If queues needed]: `yarn dev-queues` (separate process)

### Staging Connection (if needed)
- [ ] VPN connected (FortiClient)
- [ ] AWS session: `le aws login -e staging -t experiences`
- [ ] DB tunnel: `le-tunnel.sh -s SERVICE -d DB_NAME -p PORT -m ro`
- [ ] [Any other staging dependencies]

### Env Vars (if feature added new ones)
| Var | Value (local) | Value (staging) |
|-----|--------------|-----------------|
| FEATURE_FLAG | true | false |

## Test Steps

### Happy Path
1. [Step-by-step instructions to reproduce the feature]
2. [Include curl commands, URLs, or UI navigation]
3. [Expected result with specific values]

### Edge Cases
1. [Edge case 1: empty input, null values, etc.]
2. [Edge case 2: unauthorized, wrong params, etc.]

### Regression Check
1. [Existing flow that must NOT break]
2. [How to verify it still works]

## Verification Queries (if DB changes)

```sql
-- Verify data after feature runs
SELECT ... FROM ... WHERE ...;
```

## Evidence

[Links to screenshots, GIFs, or video recordings from test execution]
[These get copied to the PR body "Evidences" section]
```

### 5.3 Rules for the recipe

- Include REAL commands (curl with actual ports, endpoints, params), not pseudo-code
- Include the staging connection recipe if the feature needs staging for testing
- If the feature added env vars, document ALL of them with local and staging values
- Evidence section is filled during test execution, not after
- This file replaces any ad-hoc test notes scattered in Slack or conversation

## Phase 6: Report

Present results:

```
Test Scenarios Report:
  Environment: local (Docker) / staging (VPN)
  Service: SERVICE on port PORT

  Automated:
  - Unit tests: X/X passed
  - Type check: clean
  - Lint: clean
  - Integration: X/X passed (or N/A)

  Smoke Tests:
  | # | Scenario | Status | Notes |
  |---|----------|--------|-------|
  | 1 | Happy path | PASS | 200, correct body |
  | 2 | Empty input | PASS | 200, empty array |
  | 3 | Invalid params | PASS | 400, validation error |
  | 4 | Unauthorized | SKIP | Local doesn't check auth |
  | 5 | Not found | PASS | 200, empty result |

  Test Data:
  - Used offer ID: XXXX (local DB)
  - Seeded: [what was seeded, if any]

  Verdict: ALL PASS / X FAILURES (list)

  Next: /commit -> /create-pr
```

If any smoke test fails, investigate and fix before proceeding to commit.

---

## Verification (MANDATORY before declaring tests complete)

- [ ] Docker containers verified running
- [ ] Unit tests pass: `yarn test --changedSince=main`
- [ ] Type check passes
- [ ] Lint passes
- [ ] Test scenario matrix created (positive + negative + edge)
- [ ] Curl commands generated and executed for each changed endpoint
- [ ] Response status codes match expected
- [ ] Response body structure validated
- [ ] Edge cases handled gracefully (empty input, invalid params, not found)
- [ ] If staging: VPN confirmed, user approved
- [ ] If migration: DB schema verified, data integrity checked
- [ ] **Manual-E2E-Recipe.md created** in feature folder (Phase 5)
- [ ] Test report presented to user

## Rules

- NEVER skip environment verification (Phase 1)
- ALWAYS ask user before staging/remote operations (VPN, DB tunnel)
- Test data from staging is READ-ONLY. Never INSERT/UPDATE/DELETE on staging without explicit permission
- If a test fails, investigate root cause. Don't just re-run and hope it passes
- psql path: `/opt/homebrew/opt/libpq/bin/psql`
- Staging test data reference: `Knowledge-Base/Local-Development/Test-Simulation.md`
