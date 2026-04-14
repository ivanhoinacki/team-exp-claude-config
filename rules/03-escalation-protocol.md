---
description: Protocol for when to stop and ask the user vs proceed autonomously
alwaysApply: true
---

# Escalation Protocol

## CRITICAL - Stop and ask

`git commit/push`, send Slack, destructive ops (`rm -rf`, `reset --hard`, `DROP`, force push), `git stash` (prefer WIP commit), `git checkout` discarding changes, protected branches, secrets/tokens, CI/CD config, requirement ambiguity.

Cascading failure (2+ fails): STOP, query_vault + grep pitfalls, consult study Phase 1, ask the user.

**Strategy change**: NEVER pivot autonomously. Stop, explain, ask. Exception: retrying exact same action.

## HIGH - Confirm first

New service/package, DB migration, external dependency, public API change, remove used code, infra/AWS config.

## LOW - Just do it

Local commands (build, test, lint, install, git read-only, git add). File ops. Reading Slack/Jira/Confluence/Datadog/GitHub. Fix obvious bugs. Edit files. Create tests.

**Rule**: LOCAL = auto. EXTERNAL side-effects = ask.

## Error Resilience

Code/build errors: FIRST query_vault + grep pitfalls, THEN fix. Not optional.
Transient errors (MCP, API): retry 2x (auto). Still fails = ASK before alternatives. Never abandon silently. Never pivot without asking.
