# Skills

Automated workflows invoked via slash commands (e.g. `/commit`, `/create-pr`). Each skill is a directory containing a `SKILL.md` file with instructions, plus optional `references/` and `evals/` subdirectories.

## Available Skills (16)

| Skill | Command | Purpose |
|---|---|---|
| `commit/` | `/commit` | Format-enforced conventional commits, no trailers |
| `create-pr/` | `/create-pr` | PR with template, sequence diagrams, test evidence |
| `feature-dev/` | `/feature-dev` | Full feature lifecycle: discovery, plan, implement (6 phases) |
| `codereview/` | `/codereview` | 18-dimension code review, posts inline GitHub comments |
| `investigation-case/` | `/investigation-case` | Deep forensic bug investigation with parallel agents |
| `debug-mode/` | `/debug-mode` | Hypothesis-driven debugging with runtime log evidence |
| `deslop/` | `/deslop` | Remove AI-generated code noise before commit |
| `daily/` | `/daily` | Generate standup notes from git history and session memory |
| `learn/` | `/learn` | Capture a bug, pattern, or gotcha to persistent memory |
| `thinking-partner/` | `/thinking-partner` | Critical and collaborative analysis mode |
| `validate-infra/` | `/validate-infra` | Audit env vars, Pulumi config, schema consistency |
| `validate-migration/` | `/validate-migration` | Check migration safety: rollback, compat, performance |
| `deploy-checklist/` | `/deploy-checklist` | Risk-based deploy checklist with smoke test commands |
| `test-scenarios/` | `/test-scenarios` | Real test validation: environment, data, smoke tests |
| `diagrams/` | `/diagrams` | PlantUML/Mermaid diagram standard and style guide |
| `capture-knowledge/` | `/capture-knowledge` | Extract business rules from Slack into the vault |

## Skill structure

```
skills/
  commit/
    SKILL.md          # Main instructions (Claude reads this)
    evals/            # Test cases for skill quality
    references/       # Supporting docs, templates, learnings
  templates/
    SKILL-TEMPLATE.md # Template for creating new skills
```

## How skills work

Skills are loaded on demand when the user invokes a slash command or expresses matching intent (e.g. "commit this" triggers `/commit`). The `02-skills-first.md` rule ensures Claude always checks for a matching skill before executing raw commands.

## Workflow chain

Skills are designed to chain in sequence:

```
/feature-dev -> /deslop -> /test-scenarios -> /commit -> /create-pr -> /deploy-checklist
```

## Creating new skills

Use `templates/SKILL-TEMPLATE.md` as a starting point. Each skill needs:
1. `SKILL.md` — instructions, phases, verification checklist
2. `evals/` — at least one test scenario
3. Optional `references/` — supporting docs
