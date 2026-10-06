---
name: playwright
description: "Playwright browser workflow. EXPLICIT OVERRIDE ONLY: activate only when Ivan explicitly chooses Playwright. Use exclusively the modified playwright-runner at __PLAYWRIGHT_RUNNER__. Default browser validation uses the chrome-devtools MCP family."
---


# Playwright Runner

## Policy

- Default browser validation uses the `chrome-devtools` MCP family.
- Activate this skill only when Ivan explicitly chooses Playwright for the task.
- Run every Playwright workflow through `__PLAYWRIGHT_RUNNER__`.
- Do not use a generic Playwright MCP, a standalone Playwright CLI wrapper, an ad hoc host install, or another runner.
- If the runner cannot execute the required workflow, stop and report the gap. Do not switch browser paths silently.

## Runner Contract

- Specs live in the runner's `tests/` directory.
- `BASE_URL` is required. The runner has no default target.
- `scripts/run.sh` is the only entry point for agent-driven runs.
- The Docker container reaches host services through `host.docker.internal`.
- `TEST_RUN_ID` identifies one run and its evidence.
- Evidence lands under `artifacts/<TEST_RUN_ID>/` by default.
- `RUN_COMMAND` may select one spec. Keep execution inside the runner.

## Workflow

1. Read the runner `README.md`, `playwright.config.ts`, and the closest existing spec.
2. Reuse an existing spec when it covers the workflow. Otherwise add a narrowly scoped spec under `tests/`.
3. Start the target application and derive its real URL from runtime configuration.
4. Run from the runner directory with a unique test run ID:

   ```bash
   RUNNER=__PLAYWRIGHT_RUNNER__
   cd "$RUNNER"
   BASE_URL=http://host.docker.internal:3000 \
   TEST_RUN_ID="<task>-$(date +%Y%m%d-%H%M%S)" \
   RUN_COMMAND="npm test -- tests/<spec>.spec.ts" \
   ./scripts/run.sh
   ```

5. Read the process exit code and the generated report, screenshots, traces, and `summary.json` when present.
6. Validate every required viewport and state. For parallel roles, use distinct spec names and `TEST_RUN_ID` values.
7. Report the exact artifact directory and any state that could not be exercised.

## Safety

- Never place credentials, session data, or personal answers in the repository.
- Keep private browser state in the external locations documented by the runner.
- Do not submit forms, purchases, applications, or other consequential actions without Ivan's explicit approval.
- Preserve unrelated specs and artifacts. Do not clean another agent's active run.
- Do not declare success from a spec diff. Use the runner result and artifacts as evidence.

## Ubuntu portability

Use the active project AGENTS.md for client facts, knowledge sources and infrastructure.
Paths below are resolved by the installer. Optional MCPs, Radar, Figma and the approved
Playwright runner require separate local provisioning. Do not fall back to a generic
Playwright MCP. Existing user authorization overrides repeated permission prompts;
continue authorized work. Prefer the host runtime tools and supported skill invocation.
