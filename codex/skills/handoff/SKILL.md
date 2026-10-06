---
name: handoff
description: Connect Codex to an existing Radar DB handoff session with Claude or Ivan. Use when Ivan says /handoff or $handoff, provides a handoff session id or slug, asks Codex to join a handoff, or asks Codex to coordinate with Claude through the handoff CLI.
---

# Handoff

Use this skill to join an existing agent handoff session through the Radar API-backed `handoff` CLI.

The skill does not create sessions. It connects Codex to a session identified by Ivan or by the current collaboration context.

## Contract

Before reading Luxury Escapes vault files, query `local-le-vault` when it is available:

```text
query: Agent Handoff Contract handoff Radar API CLI read gates
```

If `local-le-vault` is unavailable or failed to start in the current session, state that gap briefly and continue by reading the contract file directly.

Primary contract path:

```text
__VAULT_ROOT__/Spirit Tech Consulting/RadarDeveloper/@Handoff/Reference/contract-template.md
```

If that file is missing, use this fallback order:

```text
__VAULT_ROOT__/Spirit Tech Consulting/RadarDeveloper/@Handoff/Playbooks/README.md
__VAULT_ROOT__/Spirit Tech Consulting/RadarDeveloper/@Handoff/Features/Plano-Melhoria.md
```

Read the contract before acting in a session.

## Connect Workflow

When invoked with `/handoff <session-id-or-slug>`, `$handoff <session-id-or-slug>`, or equivalent:

1. Determine whether the Radar launcher already registered this Codex instance.

When the handoff invitation names a target id and codename, for example
`target ivanhoinacki-codex` and `CODEX`, the runtime is already connected by
the launcher. Keep that identity and do not run `codex-handoff-bridge join`;
doing so creates a second app-server target for the same Codex conversation.

Only a standalone Codex session without a launcher-provided target should join
or resume through the local bridge:

```bash
codex-handoff-bridge join <session-id-or-slug> --cwd "$PWD" --json
```

The Radar handoff launcher puts the CLI tools on `PATH`. Do not hardcode a
repository checkout path: releases and local checkouts can move.

This command:

- resolves the Radar session;
- auto-selects or reuses a `CODEX`, `CODEX-2`, ... codename for this local target;
- registers the target for bridge delivery;
- marks existing history as read for delivery purposes;
- posts a `Status` introduction in the handoff;
- returns the codename, target id, latest seq, and aliases such as `@codex` and `@codex-2`.

2. Read the session:

```bash
handoff list --limit 20
handoff read <session-id-or-slug> --since 0
```

3. Query `local-le-vault` if available, then read the contract file.
4. Announce briefly to Ivan that Codex is connected, including codename and latest seq.
5. Continue work using the handoff read gates below.

If the session does not exist, say so and ask Ivan or Claude for the correct id/slug. Do not create a replacement session unless Ivan explicitly asks.

If `codex-handoff-bridge join` is unavailable or fails because Radar is down, state the exact failure and fall back to manual `handoff read` only for the current turn. Do not silently create a new session.

## Codename And Routing

Use the codename returned by `codex-handoff-bridge join`.

Rules:

- Every handoff post from Codex starts with `[CODENAME]`.
- Codex responds to `--to codex`, `@codex`, `--to <target-id>`, `@<target-id>`, `--to <codename>`, and `@<codename>`.
- If Ivan posts a general room message with no directed recipient and no mentions, Codex may respond when the message asks agents to coordinate, divide work, review, validate, or continue.
- If Ivan mentions another codename only, do not take ownership unless reassigned.
- Messages from another Codex instance are actionable when their body starts with a different registered codename, for example `[CODEX-2] @codex ...`.
- Messages from this same Codex instance are self messages when their body starts with this codename, for example `[CODEX] ...`.

For multiple local Codex instances, Ivan may ask for a new identity:

```bash
codex-handoff-bridge join <session> --new --cwd "$PWD" --json
```

## Posting Rules

Use the same message taxonomy as the API:

```text
Decision
Blocker
Status
Evidence
Question
Needs-Ivan
Discussion
```

Always post with `--from codex`. Use `--to claude`, `--to ivan`, or omit `--to` when the message is for the session.

Use concise but readable bodies. Include concrete files, commands, test results, decisions, and blockers. Do not post secrets, tokens, credentials, or private payloads.

For non-trivial `Evidence`, `Status`, reviews, plans, investigation summaries, or validation reports, match the organized Radar style used by Claude:

- Do not send one dense paragraph.
- Start with `[CODENAME]` and one short opening sentence.
- Use blank lines, short section labels, and bullets.
- Put commands, file paths, PRs, endpoints, seq numbers, statuses, and flags in backticks when useful.
- Keep paragraphs to 1-2 short lines.
- Use one-line posts only for trivial confirmations or no-action status.

Template:

```markdown
[CODENAME] <short opening sentence>.

Contexto:
- <important point>
- <important point>

Validação:
- `<command>` => <result>

Riscos / próximos passos:
- <risk or next step>
```

Examples:

```bash
handoff post <session> --from codex --to claude --type Evidence "Radar API handoff tests passed: services/radar-api/tests 217 passed."
handoff post <session> --from codex --to claude --type Question "Can you validate the Claude skill reads contract-template.md before posting?"
handoff post <session> --from codex --to ivan --type Needs-Ivan "Need a decision: keep CLI polling only, or prioritize SSE before UI?"
```

## Read Gates

Run `handoff read <session> --since <last-seq>`:

- when connecting to a session;
- before decisions or tradeoffs;
- before edits that affect shared work;
- after long commands or test runs;
- before asking Ivan;
- before the final response;
- after resume, compaction, or context transition.

Track the highest `seq` seen in the current turn and use it as `--since` for later reads. On uncertainty, read from `--since 0`.

For live watching during coordinated work:

```bash
handoff read <session> --since <last-seq> --follow
```

## Coordination

- Treat the Radar API + CLI as the source of truth for handoff state.
- Do not rely on chat memory from another agent when the session has messages.
- If Claude reports work completed, read the session before validating or continuing.
- If Codex completes a phase, post a `Status` message with validation evidence and next owner.
- If Codex finds a blocker, post `Blocker`; if Ivan must decide, post `Needs-Ivan`.

## Single Executor Gate

Use this gate before any duplicate-prone side effect.

Side effects include:

- Jira creation or updates;
- Slack posts;
- GitHub comments, approvals, merges, or PR edits;
- Confluence edits;
- commit, push, deploy, migration;
- external resource creation/deletion;
- shared session/target deletion;
- shared file edits when multiple agents were awakened for the same task.

Rules:

- If Ivan addressed a specific codename/agent, that target owns the task.
- If the message is general and multiple agents may respond, do not execute side effects immediately.
- First read the handoff and check whether an owner already claimed the scope.
- If no owner exists, post a `Status` claim before executing:

```bash
handoff post <session> --from codex --type Status "[CODENAME] Claiming ownership for <scope>. Action: <exact side effect>. Other agents please stand down unless Ivan reassigns."
```

- Re-read after the claim. Proceed only if your claim is the first claim for that scope or Ivan assigns it to you.
- If another agent has an earlier claim, do not execute. Post that you are standing down or can validate.
- Read-only investigation and independent validation can run in parallel; external writes cannot.

## Permission Gate

Terminal/TUI agents must not wait silently on interactive permission prompts.

If a tool, MCP, or command asks for manual approval and the session cannot continue unattended:

- Do not wait indefinitely.
- Post `Blocker` with the exact tool or command, the attempted action, and the permission/allowlist/run-mode needed.
- Wait for Ivan to approve, adjust configuration, or reassign the work.

For Claude handoff panes, prefer:

```bash
handoff-claude-start
```

This uses handoff-specific Claude settings plus `--permission-mode dontAsk`, so missing approvals fail fast instead of stalling the pane.

## Close

Only close a session when Ivan explicitly asks or the plan says the session is complete:

```bash
handoff close <session>
```

## Ubuntu portability

Use project AGENTS.md for client facts, knowledge sources, worktrees and infrastructure.
The source machine paths are resolved by the installer. Optional MCPs and Radar require
separate target provisioning. Private histories are local placeholders. Do not assume
the source vault exists. Existing user authorization overrides redundant permission
prompts. When a required local skill/resource is missing, report it instead of claiming
that this package provisioned an external service.
