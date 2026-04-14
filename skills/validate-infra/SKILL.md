---
name: validate-infra
description: Validate infrastructure configuration consistency (env vars, Pulumi, config, schema). Use when adding env vars, changing Pulumi config, before deploy, or when the user says "validate infra", "check config", "valida infra", "env vars ok?", "check pulumi".
model: haiku
argument-hint: "[service name, e.g. svc-experiences]"
compatibility: Requires git, le CLI (for Pulumi config access)
allowed-tools: Bash(git *), Bash(GIT_EDITOR=true git *), Read, Grep, Glob, Edit, Task
---

## Phase 0: Vault RAG (MANDATORY, BEFORE any Read/Grep)

You MUST call `query_vault(query, service_filter)` BEFORE reading codebase files or external sources. This is enforced by hook. No exceptions.

---

# Validate Infrastructure, Config Consistency Check

## Working Directories

1. **Obsidian workspace** (docs, plans, features): `__VAULT_ROOT__`
2. **Codebase** (all LE services): `__CODEBASE_ROOT__`

Validate that environment variables, Pulumi config, application config, and schema validation are consistent across all layers.

---

## Common Agent Mistakes

1. **Single-environment check**: Checking only staging Pulumi config and missing that prod is different. ALWAYS check BOTH `Pulumi.staging.yaml` and `Pulumi.prod.yaml`.
2. **Ignoring secretNames vs envVars**: Putting a secret value in `envVars[]` instead of `secretNames[]`. Any key containing SECRET/KEY/TOKEN/PASSWORD/PRIVATE/CREDENTIAL must be in `secretNames[]`.
3. **Missing schema.ts**: Verifying env vars exist in Pulumi and environment-variables.ts but forgetting to check if schema.ts validates them. A missing schema entry means silent undefined at runtime.
4. **Config layer skip**: Checking Layer 1 (Pulumi) and Layer 2 (env-vars) but not Layer 3 (config/*.ts). The config layer is where env vars get organized and typed.
5. **False positive on non-prod fallbacks**: Reporting `?? ''` fallbacks in test/spec/dev configs as issues. These are intentional and required for strummer validation.
6. **Not generating fix commands**: Finding issues but not generating copy-paste ready fix commands. Every issue must have an actionable fix.

---

## The 4-Layer Chain (all must be in sync)

```
Layer 1: Pulumi YAMLs          -> Defines env var values per environment
Layer 2: environment-variables.ts -> Maps process.env.* to named variables
Layer 3: config/*.ts            -> Organizes vars into config sections
Layer 4: schema.ts              -> Validates config shape at startup
```

If ANY layer is missing an env var, the service fails:

- Missing from Pulumi YAML -> pipeline fails with `Missing required configuration variable`
- Missing from environment-variables.ts -> runtime undefined
- Missing from config -> code can't access the value
- Missing from schema.ts -> startup validation fails silently or crashes

---

## Phase 0: Detect Service

### If `$ARGUMENTS` is provided

Use it as the service name (e.g., `svc-experiences`).

### If no argument

Auto-detect from context:

1. **Current directory**: if inside `__CODEBASE_ROOT__/<service>/`, use that service
2. **Branch name**: extract service from branch (e.g., `feat/EXP-3500-experiences-booking` -> likely `svc-experiences`)
3. **Changed files**: check which service directories have changes

```bash
GIT_EDITOR=true git diff main --name-only | grep -oE "^[^/]+" | sort -u
```

If multiple services are detected, validate ALL of them (see Phase 2 multi-service).

### Service file path map

| Service         | Pulumi dir               | env-vars file                                                  | config dir    | schema file            |
| --------------- | ------------------------ | -------------------------------------------------------------- | ------------- | ---------------------- |
| svc-experiences | `infra/svc-experiences/` | `src/config/environment-variables.ts`                          | `src/config/` | `src/config/schema.ts` |
| svc-order       | `infra/svc-order/`       | `src/config/environment-variables.ts` or `src/config/index.ts` | `src/config/` | `src/config/schema.ts` |
| svc-ee-offer    | `infra/svc-ee-offer/`    | varies                                                         | `src/config/` | varies                 |
| svc-search      | `infra/svc-search/`      | `src/config/environment-variables.ts`                          | `src/config/` | `src/config/schema.ts` |
| svc-auth        | `infra/svc-auth/`        | varies                                                         | `src/config/` | varies                 |

If the service is not in this map, discover paths by searching:

Use native tools to discover paths:
- **Config files**: Glob tool, patterns `**/environment-variables*`, `**/schema.ts`, `**/config.ts` in service root (automatically excludes node_modules)
- **Pulumi files**: Glob tool, pattern `**/Pulumi.*.yaml` in service root

---

## Phase 1: Detect Changes (diff-aware)

### New and changed env vars (priority)

```bash
# New process.env references in application code
GIT_EDITOR=true git diff main -U0 | grep -E "process\.env\." | grep "^+"

# Changed Pulumi YAML keys
GIT_EDITOR=true git diff main -- "infra/*/Pulumi.*.yaml" | grep -E "^\+" | grep -v "^+++"

# Changed env-vars/config/schema
GIT_EDITOR=true git diff main --name-only | grep -E "(Pulumi|environment-variables|config/|schema\.ts)"
```

### Full scan (light, for regressions)

Even if no infra files changed in the diff, do a quick consistency check of existing vars to catch pre-existing issues.

If no changes detected at all: report "No infrastructure changes detected." and exit.

---

## Phase 2: Analyze Layers (parallel subagents)

### Single service

Launch 2 subagents in parallel:

#### Agent 1: Pulumi and Secrets Analysis

```
For service [name] in __CODEBASE_ROOT__/[service]:

1. Read infra/[svc-name]/Pulumi.staging.yaml and Pulumi.prod.yaml
2. Extract ALL keys from envVars: section (both staging and prod)
3. Extract ALL keys from secretNames: section
4. Check for secure: entries, these are set via `le pulumi config set --secret`
5. For each key in secretNames, verify a corresponding secure: entry exists
6. Note: only staging and prod stacks exist (no dev)

Return: envVars per environment, secretNames, secure entries present/missing.
```

#### Agent 2: Application Code Analysis

```
For service [name] in __CODEBASE_ROOT__/[service]:

1. Read environment-variables.ts (or equivalent)
   - Extract all process.env.* references
   - Note any with fallback defaults (?? 'value')

2. Read config files (src/config/production.ts, staging.ts, development.ts, test.ts, spec.ts, index.ts)
   - Extract all env var mappings
   - Note non-prod fallbacks

3. Read schema.ts (or equivalent strummer/joi/zod)
   - Extract all validated fields
   - Note validation types (string, boolean, number, etc.)

4. Search application code for NEW process.env.* references not in environment-variables.ts
   (direct env access that bypasses the config layer)

Return: env vars per layer, validation types, direct env access violations, fallback defaults.
```

### Multi-service

If multiple services are affected, launch agent pairs for each service in parallel (up to 3 services). Report results per service.

---

## Phase 3: Cross-Reference

Build a consistency matrix for each env var:

```
ENV VAR              | Pulumi stg | Pulumi prod | env-vars.ts | config | schema | Type
---------------------|------------|-------------|-------------|--------|--------|------
DATABASE_URL         | ok         | ok          | ok          | ok     | ok     | string
NEW_FEATURE_ENABLED  | ok         | MISSING     | ok          | ok     | ok     | string
API_TIMEOUT          | ok         | ok          | ok          | MISSING| ok     | number
SECRET_KEY           | secret:ok  | secret:MISS | secretNames | ok     | ok     | string
```

### Consistency rules

For each env var, check:

1. **Present in ALL 4 layers**, if missing from any, it's a failure
2. **Pulumi values match expectations**:
   - Staging and prod both have the key (or it's intentionally staging-only)
   - Values are appropriate (prod shouldn't have localhost, staging shouldn't have prod URLs)
3. **Secrets are in the right place**:
   - Keys with SECRET/KEY/TOKEN/PASSWORD/PRIVATE/CREDENTIAL in name -> must be in `secretNames[]`, not `envVars[]`
   - Each secret in `secretNames[]` must have a `secure:` entry in the YAML (proof it was set)
4. **Feature flags are safe**:
   - Keys with ENABLED/FEATURE/FLAG/TOGGLE -> prod should be `"false"` or `"0"`
   - Staging should be `"true"` or `"1"` for testing
5. **No direct env access**:
   - Application code should use config layer, not `process.env.*` directly
   - Exception: environment-variables.ts itself
6. **Non-prod fallbacks**:
   - Test/spec/dev configs should have `?? ''` fallbacks for strings without env var backing

---

## Phase 4: Secrets Verification

For every secret identified:

### Check secure entries

```yaml
# In Pulumi.staging.yaml, a properly set secret looks like:
config:
  svc-experiences:SECRET_KEY:
    secure: v1:abc123... # This means le pulumi config set --secret was run
```

If `secure:` entry is missing for a declared secret:

```
SECRET INCOMPLETE: SECRET_KEY
  - Listed in secretNames[] but no secure: entry in Pulumi.[env].yaml
  - This means `le pulumi config set --secret` was NOT run for this environment
  - The deploy will fail
```

### Check for plaintext secrets

If a key that looks like a secret is in `envVars[]` with a plaintext value instead of `secretNames[]`:

```
SECURITY WARNING: API_KEY is in envVars with plaintext value "sk-..."
  Should be in secretNames[] with value set via:
  le pulumi config set --secret API_KEY --stack staging
  le pulumi config set --secret API_KEY --stack prod
```

---

## Phase 5: Generate Fix Commands

For every issue found, generate the exact command or code change needed:

### Missing from Pulumi YAML

```bash
# Add to infra/<svc>/Pulumi.<env>.yaml under envVars:
#   svc-name:NEW_VAR: "value"

# Or for secrets:
cd __CODEBASE_ROOT__/<service>/infra/<svc-name>
le pulumi config set --secret SECRET_KEY --stack staging
le pulumi config set --secret SECRET_KEY --stack prod
```

### Missing from environment-variables.ts

```typescript
// Add to environment-variables.ts:
export const NEW_VAR = process.env.NEW_VAR;
```

### Missing from config

```typescript
// Add to src/config/<env>.ts:
newVar: environmentVariables.NEW_VAR ?? '',
```

### Missing from schema.ts

```typescript
// Add to schema validation:
newVar: s.string(),  // or s.boolean(), s.number()
```

### Private keys (special case)

```bash
# Keys containing "-----" need printf workaround:
printf '%s' 'value' | le pulumi config set --secret PRIVATE_KEY --stack staging
printf '%s' 'value' | le pulumi config set --secret PRIVATE_KEY --stack prod
```

---

## Phase 6: Output

### All Consistent

```
Infrastructure validation PASSED.

  Service: [name]
  Env vars checked: X (Y new in this branch)
  Layers validated: Pulumi staging, Pulumi prod, env-vars.ts, config, schema.ts
  Secrets: N configured, all secure: entries present
  Feature flags: N found, all safe (prod disabled)
  Direct env access: none detected

  Ready to proceed: /code-review -> /commit -> /create-pr (invoke each via Skill tool)
```

### Inconsistencies Found

```
Infrastructure validation FAILED.

  Service: [name]
  Issues: N

CRITICAL (blocks deploy):
  LAYER          | ENV VAR         | ISSUE                    | FIX
  ---------------|-----------------|--------------------------|----
  Pulumi.prod    | NEW_VAR         | Missing from envVars     | Add: svc-name:NEW_VAR: "value"
  schema.ts      | OLD_VAR         | Missing validation       | Add: oldVar: s.string()

WARNINGS (should fix):
  LAYER          | ENV VAR         | ISSUE                    | FIX
  ---------------|-----------------|--------------------------|----
  envVars[]      | API_KEY         | Plaintext secret         | Move to secretNames[], run le pulumi config set --secret
  Pulumi.prod    | FEATURE_FLAG    | Enabled in prod          | Set to "false" for initial rollout

FIX COMMANDS (copy-paste ready):
  # 1. Add missing Pulumi config
  cd __CODEBASE_ROOT__/<service>/infra/<svc-name>
  le pulumi config set --secret API_KEY --stack prod

  # 2. Add to schema.ts
  [Edit instruction with exact code]

Re-run /validate-infra after fixing.
```

### Multi-service output

If multiple services were validated:

```
Infrastructure validation, 2 services

  svc-experiences: PASSED (12 vars, 3 secrets, all consistent)
  svc-order:       FAILED (8 vars, 1 missing from Pulumi.prod)

[Details for failed service...]
```

---

## Rules

- Only `staging` and `prod` stacks exist for most services (no `dev`)
- Secrets use `le pulumi` (not `pulumi` directly) for AWS role assumption
- Private keys with `-----` need the `printf` workaround
- `secure:` entries in YAML are generated by Pulumi and MUST be committed
- Non-prod configs (test, spec, dev) need `?? ''` fallbacks for strummer validation
- Never output actual secret values in the report
- Feature flags should always be disabled in prod for initial rollout
- Direct `process.env.*` access in application code (outside environment-variables.ts) is a violation
