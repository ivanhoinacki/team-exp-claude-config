# Deployment Risk Matrix

Parent: [`deploy-checklist/SKILL.md`](../SKILL.md)

Reference for assessing deployment risk level.

| Risk Factor | Low | Medium | High |
|---|---|---|---|
| Services affected | 1 | 2-3 | 4+ |
| DB migrations | None | Additive only | Alter/drop |
| Env vars changed | None | Non-secret | Secrets/critical |
| Breaking API changes | None | Internal only | Public API |
| Rollback complexity | Revert commit | Manual steps | Data migration |
| Traffic impact | Background only | Low-traffic endpoints | High-traffic/checkout |

## Risk Level Determination

- **Low**: All factors Low -> standard deploy
- **Medium**: Any factor Medium -> deploy during low-traffic, monitor 30min
- **High**: Any factor High -> deploy with team awareness, rollback plan ready, monitor 1h
- **Critical**: Multiple factors High -> requires team lead approval, staged rollout

## Deploy Strategies by Risk

| Risk Level | Strategy |
|---|---|
| **LOW** | Merge and deploy. Monitor for 15 min |
| **MEDIUM** | Deploy to staging first. Verify. Then deploy to prod with flag off. Enable gradually |
| **HIGH** | Deploy during low-traffic window. Team member on standby. Verify each step before proceeding |
| **CRITICAL** | Schedule deploy with team. War-room style. Step-by-step execution with checkpoints |

## Risk Assessment Output Format

```
Risk assessment: [LEVEL]
  Factors:
  - [reason 1]
  - [reason 2]
  - [reason 3]

  Recommended: [deploy strategy]
```
