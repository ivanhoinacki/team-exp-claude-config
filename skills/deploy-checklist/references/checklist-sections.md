# Checklist Sections Reference

Parent: [`deploy-checklist/SKILL.md`](../SKILL.md)

Detailed definitions of each checklist section: what it contains, when to include it, and template examples.

---

## Section Inclusion Rules

Only include sections where items exist:

- **Environment Configuration**: only if new env vars or secrets detected
- **Database**: only if migration files detected
- **Dependencies**: only if package.json changed
- **Communication**: only if HIGH/CRITICAL risk
- **Deploy Order**: only if multiple services are affected
- **Smoke tests**: generate actual curl commands from the endpoints found in Agent 2

---

## Section Templates

### Environment Configuration

Include when: new `process.env.*` references, Pulumi YAML changes, or secret additions detected.

```markdown
### Environment Configuration

- [ ] Env var `VAR_NAME`: staging=`value` | prod=`value`
- [ ] Env var chain validated (Pulumi -> env-vars -> config -> schema): PASSED/FAILED
- [ ] Secret `SECRET_NAME` set: `le pulumi config set --secret SECRET_NAME --stack staging`
- [ ] Secret `SECRET_NAME` set: `le pulumi config set --secret SECRET_NAME --stack prod`
- [ ] Feature flag `FLAG_NAME`: staging=`"true"` | prod=`"false"`
```

### Database

Include when: migration files detected in `src/migration/` or `db/migrations/`.

```markdown
### Database

- [ ] Migration tested locally (dev + spec databases)
- [ ] Migration is backward-compatible (old code works with new schema)
- [ ] Rollback migration tested: `yarn migration:revert`
- [ ] Large table impact assessed: [table name, row count estimate]
```

### Dependencies

Include when: `package.json` or lock file changed.

```markdown
### Dependencies

- [ ] No new CVEs: `yarn audit`
- [ ] Lock file committed
```

### Communication

Include when: risk level is HIGH or CRITICAL.

```markdown
### Communication

- [ ] Team notified of deploy timing in #exp-team (if HIGH/CRITICAL risk)
- [ ] Stakeholders informed (if user-facing change)
```

### Deploy Order

Include when: multiple services are affected. Specify the sequence and dependencies.

```markdown
## Deploy Order

| Step | Service         | Action                             | Depends on |
| ---- | --------------- | ---------------------------------- | ---------- |
| 1    | svc-experiences | Deploy (migration runs on startup) | -          |
| 2    | svc-order       | Deploy (consumes new field)        | Step 1     |
| 3    | www-le-customer | Deploy (renders new field)         | Step 2     |
```

### Post-merge: Staging

Always include. Generate actual curl commands from endpoints found in analysis.

```markdown
## Post-merge: Staging

- [ ] CI pipeline green
- [ ] Check staging logs for new errors: [CloudWatch logs]
- [ ] Test feature manually in staging
- [ ] Smoke tests:
  ```bash
  # [Description of what this tests]
  curl -s https://staging-api.luxuryescapes.com/api/v1/endpoint | jq '.status'
  ```
- [ ] Verify Bull Arena jobs (if new jobs): [Bull Arena link]
- [ ] Verify migration ran: check table/column exists in staging DB
```

### Post-merge: Production

Always include. Feature flag enablement, monitoring, and smoke tests.

```markdown
## Post-merge: Production

- [ ] Enable feature flag: set `FLAG_NAME` to `"true"` in Pulumi.prod.yaml + deploy
- [ ] Monitor for 30 min:
  - [ ] Error rate stable: [New Relic dashboard]
  - [ ] Latency p99 stable
  - [ ] No new exceptions in Sentry
- [ ] Smoke tests (prod):
  ```bash
  curl -s https://api.luxuryescapes.com/api/v1/endpoint | jq '.status'
  ```
- [ ] Verify feature in production
- [ ] Notify team: "EXP-XXXX deployed to prod" in #exp-team
```

### Rollback Plan

Always include. Populate with specifics from the analysis.

```markdown
## Rollback Plan

**Estimated rollback time:** [X minutes]

| Severity        | Action                                                              | Time    |
| --------------- | ------------------------------------------------------------------- | ------- |
| Minor issue     | Disable feature flag in Pulumi.prod.yaml + deploy                   | ~5 min  |
| Code bug        | `git revert <merge-commit>` -> new PR -> fast merge                 | ~15 min |
| Migration issue | Run revert migration (only if forward migration is backward-compat) | ~10 min |
| Critical        | All above + notify #exp-ops immediately                             | ASAP    |

### Rollback commands

```bash
# Feature flag disable
cd infra/svc-name && le pulumi config set FLAG_NAME "false" --stack prod

# Code revert
git revert <merge-commit-hash>
git push origin main

# Migration revert (from service directory)
yarn migration:revert
```
```

---

## Monitoring Links

Map services to their monitoring dashboards:

| Service         | New Relic                      | Logs              |
| --------------- | ------------------------------ | ----------------- |
| svc-experiences | `https://one.newrelic.com/...` | ECS CloudWatch    |
| svc-order       | `https://one.newrelic.com/...` | ECS CloudWatch    |
| svc-ee-offer    | `https://one.newrelic.com/...` | ECS CloudWatch    |
| www-le-customer | `https://one.newrelic.com/...` | Vercel/CloudWatch |

Use generic `[New Relic dashboard]` and `[CloudWatch logs]` placeholders if specific URLs are not known.
