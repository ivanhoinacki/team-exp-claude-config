# Agents

Specialized sub-agents for Claude Code. Each agent has a defined role, model preference, and permission scope.

## Available Agents

| Agent | Model | Mode | Purpose |
|---|---|---|---|
| `copilot.md` | Opus | Read/Write | Daily partner — context-aware, triggers skills, updates session memory |
| `researcher.md` | Sonnet | Read-only | Discovery and investigation — searches codebase, docs, Slack, Jira |
| `implementer.md` | Opus | Read/Write | Code implementation — follows approved plans, writes code and tests |
| `reviewer.md` | Opus | Read-only | Code review — 18-dimension analysis, posts inline PR comments |

## How agents work

Claude Code can delegate tasks to agents via the `Agent` tool. Each agent file defines:
- **Role and constraints** (what the agent can and cannot do)
- **Tools available** (which MCPs and file operations are allowed)
- **Model preference** (Opus for complex tasks, Sonnet for read-heavy discovery)

## Usage

Agents are invoked automatically by skills or manually:
```
claude --agent researcher "find all uses of getExperienceById in svc-experiences"
claude --agent copilot
```

## Customization

Fork and edit agent files to match your team's workflow. Common changes:
- Adjust tool permissions per agent
- Add domain-specific context (team channels, service ownership)
- Change model preferences based on cost/quality trade-offs
