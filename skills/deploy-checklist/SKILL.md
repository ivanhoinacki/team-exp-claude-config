---
name: deploy-checklist
model: haiku
description: Generate deployment checklist for a feature before merge. Use after PR is approved, before merge, or when the user says "deploy checklist", "checklist deploy", "pre-deploy", "ready to merge?", "checklist de deploy", "posso mergear?", "pronto pra deploy?", "can I merge?", "deploy readiness". Do NOT use for CI pipeline monitoring (use /create-pr for that).
argument-hint: "[EXP-XXXX ticket number]"
allowed-tools: Bash(git *), Bash(GIT_EDITOR=true git *), Read, Grep, Glob, Write, Edit, Task
---

## Phase 0: Vault RAG (MANDATORY, BEFORE any Read/Grep)

You MUST call `query_vault(query, service_filter)` BEFORE reading codebase files or external sources. This is enforced by hook. No exceptions.

---

# Deploy Checklist Generator

## Working Directories

1. **Obsidian workspace** (docs, plans, features): `__VAULT_ROOT__`
2. **Codebase** (all LE services): `__CODEBASE_ROOT__`

Generate a deployment checklist based on the actual changes in the current branch.

## References

- [`references/checklist-sections.md`](references/checklist-sections.md) - Section templates, inclusion rules, monitoring links
- [`references/risk-matrix.md`](references/risk-matrix.md) - Risk factor matrix and deploy strategies
- [`references/learnings.md`](references/learnings.md) - Lessons from past deployments (review before generating)

---

## Phase 1: Collect Context

```bash
# Branch and commit info
GIT_EDITOR=true git branch --show-current
GIT_EDITOR=true git log main..HEAD --oneline
GIT_EDITOR=true git diff main...HEAD --name-only
GIT_EDITOR=true git diff main...HEAD --stat
```

Identify the ticket number from `$ARGUMENTS` or from the branch name (e.g., `feat/EXP-3500-description` -> `EXP-3500`).

Read `references/learnings.md` for any relevant lessons from past deployments.

---

## Phase 2: Parallel Analysis (subagents)

Launch 2 subagents in parallel to analyze the branch changes:

### Agent 1: Infrastructure and Config Analysis

```
Analyze the git diff (main...HEAD) for infrastructure and configuration changes:

1. ENV VARS - Search for:
   - New `process.env.*` references in the diff
   - Changes to Pulumi YAML files (Pulumi.staging.yaml, Pulumi.prod.yaml)
   - Changes to environment-variables.ts, config files, schema files
   - For each new env var, trace the 4-layer chain:
     a) Pulumi YAML (value present in BOTH staging and prod?)
     b) environment-variables.ts (mapped?)
     c) config/index.ts (exported?)
     d) config/schema.ts (validated?)
   - Report any breaks in the chain

2. SECRETS - Check for:
   - New entries in secretNames[] array
   - New `secure:` entries in Pulumi YAMLs
   - Missing secrets (referenced in code but not in Pulumi config)

3. FEATURE FLAGS - Check for:
   - Env vars with ENABLED/FEATURE/FLAG in the name
   - Current values in staging vs prod YAMLs

4. DEPENDENCIES - Check for:
   - package.json changes (new deps, version bumps, removed deps)
   - Lock file changes

Return: env var chain report, secrets list, feature flags, dependency changes.
```

### Agent 2: Code and Migration Analysis

```
Analyze the git diff (main...HEAD) for code and database changes:

1. MIGRATIONS - Search for:
   - New files in src/migration/ or db/migrations/
   - Read each migration: what tables/columns are affected
   - Is the migration backward-compatible? (old code works with new schema)
   - Is there a rollback/revert migration?
   - Does it modify existing columns (ALTER) or just ADD?

2. API CHANGES - Search for:
   - New or modified route files
   - New endpoints (method + path)
   - Changed request/response shapes
   - For each endpoint, generate a curl command for staging

3. CRON/JOBS - Search for:
   - New Bull queue definitions or job processors
   - New cron schedules
   - Changed job configurations

4. EXTERNAL INTEGRATIONS - Search for:
   - New provider/client calls (HTTP, SDK)
   - New S3 bucket references
   - New Slack channel references
   - New SNS/SQS topic references

5. IMPLEMENTATION GUIDE - Read the feature's Implementation Guide:
   Find: Development/Features/EXP-XXXX*/Implementation-Guide*.md
   Check for deploy-specific steps mentioned in the guide that should be in the checklist.
   Also check the Merge Order section for multi-PR deploy sequencing.

Return: migration details, API endpoints with curl commands, jobs, integrations, plan deploy steps.
```

---

## Phase 3: Risk Assessment

Assess risk using the full matrix in [`references/risk-matrix.md`](references/risk-matrix.md).

Evaluate each factor (services affected, DB migrations, env vars, breaking API changes, rollback complexity, traffic impact) and determine the overall risk level. Apply the corresponding deploy strategy.

---

## Phase 4: Generate Checklist

Based on detected changes, generate ONLY the relevant sections. Skip sections with no items.

See [`references/checklist-sections.md`](references/checklist-sections.md) for section templates, inclusion rules, and monitoring links.

### Sections (include only when applicable)

| Section | Include when |
|---|---|
| Environment Configuration | New env vars or secrets detected |
| Database | Migration files detected |
| Dependencies | package.json changed |
| Communication | HIGH/CRITICAL risk |
| Deploy Order | Multiple services affected |
| Smoke tests | Generate curl commands from detected endpoints |

### Output format (MANDATORY structure)

````markdown
# Deploy Checklist - EXP-XXXX

**Branch:** feature/EXP-XXXX-description
**Service(s):** svc-name
**PR:** [link]
**Risk:** [LOW/MEDIUM/HIGH/CRITICAL]
**Strategy:** [deploy strategy from risk assessment]

---

## Pre-merge

### Environment Configuration (if new env vars/secrets)
- [ ] Env var `VAR_NAME`: staging=`value` | prod=`value`
- [ ] Env var chain validated (Pulumi -> env-vars -> config -> schema)
- [ ] Secret set: `le pulumi config set --secret SECRET_NAME --stack staging/prod`
- [ ] Feature flag: staging=`"true"` | prod=`"false"`

### Database (if migrations)
- [ ] Migration tested locally (dev + spec)
- [ ] Migration is backward-compatible
- [ ] Rollback tested: `yarn migration:revert`
- [ ] Large table impact assessed: [table, row count]

### Dependencies (if package.json changed)
- [ ] No new CVEs: `yarn audit`
- [ ] Lock file committed

### Communication (if HIGH/CRITICAL risk)
- [ ] Team notified in #exp-team
- [ ] Stakeholders informed

### Deploy Order (if multi-service)
| Step | Service | Action | Depends on |

---

## Post-merge: Staging
- [ ] CI pipeline green
- [ ] Check staging logs for errors
- [ ] Test feature manually in staging
- [ ] Smoke tests:
  ```bash
  curl -s https://staging-api.luxuryescapes.com/api/... | jq '.status'
  ```
- [ ] Verify migration ran (if applicable)

---

## Post-merge: Production
- [ ] Enable feature flag (if applicable)
- [ ] Monitor 30 min: error rate, latency p99, exceptions
- [ ] Smoke tests (prod):
  ```bash
  curl -s https://api.luxuryescapes.com/api/... | jq '.status'
  ```
- [ ] Verify feature in production
- [ ] Notify team: "EXP-XXXX deployed to prod"

---

## Rollback Plan

**Estimated rollback time:** [X min]

| Severity | Action | Time |
|----------|--------|------|
| Minor | Disable feature flag + deploy | ~5 min |
| Code bug | `git revert` -> new PR -> fast merge | ~15 min |
| Migration | Revert migration (if backward-compat) | ~10 min |
| Critical | All above + notify #exp-ops | ASAP |
````

---

## Phase 5: Save

### File naming

Save the checklist following the naming convention (no EXP prefix inside feature folders):

```bash
FEATURES_DIR="__VAULT_ROOT__/Development/Features"
FEATURE_FOLDER=$(find "$FEATURES_DIR" -maxdepth 1 -type d -name "EXP-XXXX*" | head -1)
```

Save to: `$FEATURE_FOLDER/Checklist-Deploy.md`

If the feature folder doesn't exist, create `$FEATURES_DIR/EXP-XXXX - DONE/Checklist-Deploy.md`.

---

## Phase 6: Wrap-up

### Update folder status to DONE

```bash
FEATURES_DIR="__VAULT_ROOT__/Development/Features"
OLD=$(find "$FEATURES_DIR" -maxdepth 1 -type d -name "EXP-XXXX*" | head -1)
NEW_NAME=$(echo "$OLD" | sed 's/- [A-Z]*$/- DONE/' | sed 's/EXP-\([0-9]*\)$/EXP-\1 - DONE/')
[ -n "$OLD" ] && [ "$OLD" != "$NEW_NAME" ] && mv "$OLD" "$NEW_NAME"
```

### Report

```
Deploy checklist generated:

  Risk: [LEVEL]
  Strategy: [deploy strategy]
  Service(s): [list]
  Sections: [which sections were included]

  Env vars: [N new, chain validated: PASS/FAIL]
  Migrations: [N, backward-compat: yes/no]
  New endpoints: [N, smoke tests generated]
  Feature flags: [list with staging/prod values]

  Saved to: Development/Features/EXP-XXXX - DONE/Checklist-Deploy.md
  Folder status: -> DONE

  Review the checklist and start executing pre-merge items.
```

### Infra chain validation warning

If Agent 1 found breaks in the env var 4-layer chain, add a prominent warning:

```
ENV VAR CHAIN BROKEN - Do not merge until fixed:
  - VAR_NAME: missing from Pulumi.prod.yaml
  - SECRET_NAME: missing from secretNames[]

Run /validate-infra for full report.
```

---

## Common Agent Mistakes

1. **Missing env var propagation**: Checking env vars in code but not verifying they exist in Pulumi config for ALL environments (dev, staging, prod). Always check `infra/*/Pulumi.*.yaml`.
2. **Ignoring migration rollback**: Listing a migration without specifying rollback steps. Every migration in the checklist must have a rollback procedure.
3. **Feature flag blindness**: Not checking if the feature has a flag that should be enabled/disabled per environment during deployment.
4. **Deploy order assumption**: Assuming services can be deployed in any order. Check for API contract dependencies between services.
5. **Stale staging assumption**: Not warning that staging may have other branches deployed. Always note the current staging state.

---

## Verification (MANDATORY before presenting checklist)

- [ ] All changed services identified from diff
- [ ] Env vars checked in ALL environments (dev, staging, prod Pulumi configs)
- [ ] Migration rollback steps documented for each migration
- [ ] Deploy order specified if multi-service
- [ ] Risk level assessed using risk matrix
- [ ] Feature flags identified and deployment state specified per environment
- [ ] Monitoring links included (Datadog dashboards, alerts)
- [ ] Rollback procedure documented (exact commands)

---

## Rules

- Every checklist item must trace back to actual code changes in the diff
- Never generate generic checklists. Only include sections relevant to detected changes
- Smoke test curl commands must use real endpoint paths from the diff
- Multi-service deploys MUST specify order with dependencies
- Risk assessment drives the deploy strategy and communication requirements
- Env var chain validation is mandatory. A broken chain blocks the checklist
- Prepend `GIT_EDITOR=true` to all git commands that might open an editor
- No emojis in the checklist
