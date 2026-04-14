# Rules

Behavioral guardrails that Claude loads automatically at the start of every conversation. These define how Claude behaves, what it can do without asking, and what requires approval.

## Rule Index

| File | Purpose |
|---|---|
| `00-global-style.md` | Language, tone, formatting, commit style, technical posture |
| `01-code-quality-review.md` | 18-dimension code quality checklist (correctness, security, performance, etc.) |
| `02-skills-first.md` | Skill routing — ensures Claude uses skills instead of raw commands |
| `03-escalation-protocol.md` | What requires user approval vs. what Claude can do autonomously |
| `04-study-before-starting.md` | Mandatory discovery phase before any development task |
| `05-diagrams-standard.md` | PlantUML for Obsidian, Mermaid for GitHub PRs |
| `06-worktree-detection.md` | Auto-detect git worktrees when a Jira ticket is mentioned |
| `08-behavioral-standards.md` | Non-negotiable behaviors: investigate before answering, never defer work |

## How rules work

Rules are symlinked to `~/.claude/rules/` during setup. Claude Code reads all `.md` files in that directory at conversation start and follows them throughout the session.

## Rule priority

Rules are numbered for load order. Lower numbers = higher priority:
- `00-*` : foundational style and language
- `01-*` : code quality (blocks merge if violated)
- `02-03` : skill enforcement and safety
- `04-08` : workflow and behavioral standards

## Customization

Edit rules to match your team's standards:
- Adjust escalation thresholds in `03-escalation-protocol.md`
- Add your team's coding patterns to `01-code-quality-review.md`
- Modify language preferences in `00-global-style.md`
