# team-exp-claude-config

Reusable Claude Code instructions for a company machine. This temporary branch updates
the configuration without creating a tag or release.

## Download and install the temporary branch

```bash
git clone --branch transfer/company-config-20261005 --single-branch https://github.com/ivanhoinacki/team-exp-claude-config.git
cd team-exp-claude-config
python3 scripts/install-config.py
python3 scripts/install-config.py --verify
```

The recommended portable install includes **16 rules, 8 active skills and 4 agents**.
It backs up changed files, archives superseded package rules, preserves personal
learnings and leaves settings, MCPs, credentials and dependencies unchanged.

Paths can be supplied with `--codebase-root`, `--vault-root` and `--user-name`.
Existing `.team-config.json` values are reused when available. See
[company machine instructions](docs/COMPANY-MACHINE.md) for examples and rollback.

## Current workflows

`commit`, `create-pr`, `deslop`, `feature-dev`, `codereview`, `thinking-partner`,
`investigation`, and optional project-configured `handoff`.

The older 16 workflows remain in the repository for compatibility, making 18 skill
directories in total. `investigation-case` delegates to the current investigation
workflow. The portable installer installs the 8 current workflows only.

## Full historical setup

`bash scripts/setup.sh` (macOS) and `bash scripts/setup-wsl.sh` (Linux/WSL) retain
the original team-specific hooks, service dossiers and integrations. Use them only
for that environment. `--config-only` selects the portable installation instead.
The full setup does not add generic Playwright MCP; Chrome DevTools is the browser default.
Existing MCP entries are preserved rather than removed.

## Update and validate

```bash
bash scripts/update.sh --config-only
python3 -m unittest discover -s tests -v
bash scripts/test-setup.sh
```

The update follows the checked-out branch. ZIP downloads can rerun install-config.py
without Git. No private settings, tokens, memory, client contexts or local knowledge
histories were exported into this branch. Hooks and MCPs are not installed by the portable mode.

## Workshops

The existing [workshops](workshops/) and their main-branch publication remain unchanged.
