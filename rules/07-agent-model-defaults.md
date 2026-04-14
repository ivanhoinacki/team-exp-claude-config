---
description: Default model for every Agent tool call
alwaysApply: true
---

# Agent Model Defaults

EVERY Agent tool call MUST include the `model` parameter. No exceptions.

## Subagent type mapping

| subagent_type | model |
|---|---|
| Explore, researcher, reviewer, general-purpose, claude-code-guide, copilot, (empty) | **haiku** |
| implementer, Plan | **sonnet** |
| any (when user explicitly requests opus) | **opus** |

Default = haiku. Missing model = bug. Hook `agent-model-guard.sh` enforces this as safety net but should never trigger.

## Skill model mapping

Skills define their model via frontmatter `model:` field. This changes the session model when the skill is invoked.

| Model | Skills |
|---|---|
| **haiku** (14) | automations, capture-knowledge, commit, create-pr, daily, datadog-pup-cli, deploy-checklist, diagrams, learn, migrate-newrelic-resources-to-datadog, migrate-newrelic-to-datadog, test-scenarios, thinking-partner, validate-infra, validate-migration |
| **sonnet** (3) | codereview, debug-mode, feature-dev |
| **opus** (2) | deslop, investigation-case |
