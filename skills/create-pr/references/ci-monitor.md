# CI Pipeline Monitor (Background Agent)

> Parent skill: [create-pr/SKILL.md](../SKILL.md)

After the PR is created, ALWAYS launch a background agent to monitor the CI pipeline. This agent watches CircleCI checks, waits for completion, and auto-fixes failures.

## Launch command

```
Agent(
  description: "Monitor CI pipeline for PR",
  run_in_background: true,
  prompt: <see below>
)
```

## Agent prompt

```
Monitor the CI pipeline for PR #{PR_NUMBER} in repo {REPO}.

## Phase 1: Wait for checks to complete

Poll every 90 seconds until all checks finish (max 20 minutes):

gh pr checks {PR_NUMBER} --repo {REPO}

Status interpretation:
- All checks "pass" -> Phase 3 (success)
- Any check "fail" -> Phase 2 (investigate)
- Checks still "pending" -> wait 90s and poll again
- After 20 minutes with pending checks -> report timeout to user

## Phase 2: Investigate and fix failures

For each failed check:

1. Get the failed check details:
   gh pr checks {PR_NUMBER} --repo {REPO} --json name,state,description,detailsUrl

2. Identify the failure type from the check name:
   - "test-unit" or "test" -> unit test failure
   - "test-integration" -> integration test failure
   - "lint" -> lint error
   - "test-types" or "typecheck" -> type error
   - "build" -> build failure
   - Other -> report to user without auto-fixing

3. Get the failure logs:
   gh run view --repo {REPO} --log-failed 2>/dev/null | tail -100

   If gh run view doesn't work, try:
   gh pr checks {PR_NUMBER} --repo {REPO} --json detailsUrl -q '.[].detailsUrl'
   (and report the URL to the user)

4. For fixable failures (test-unit, test-integration, lint, test-types, build):

   a. Read the error output to understand what failed
   b. Find the failing file(s) in the codebase
   c. Fix the issue locally
   d. Run the same check locally to verify:
      - test-unit: yarn test:unit (or yarn test)
      - test-integration: yarn test:integration
      - lint: yarn lint
      - test-types: yarn test:types
      - build: yarn build
   e. If local check passes after fix:
      - Stage the fix: git add <files>
      - Commit with message: fix(<scope>): fix <check-name> failure\n\n- <what was wrong and how it was fixed>
      - Push: git push
      - Return to Phase 1 (poll again for new check run)
   f. If local check still fails after 2 attempts:
      - Report to user with error details and what was tried

5. For non-fixable failures (unknown check names, infra issues, flaky external deps):
   - Report to user with the check name, error output, and details URL

## Phase 3: Report result

### All checks passed
Notify the user:
"CI pipeline passed for PR #{PR_NUMBER}. All checks green."

### Checks failed and were fixed
Notify the user:
"CI pipeline for PR #{PR_NUMBER}: {N} check(s) failed, {M} auto-fixed.
Fixed: {list of checks and commit SHAs}
Still failing: {list if any, with error details}"

### Checks failed and could not be fixed
Notify the user:
"CI pipeline for PR #{PR_NUMBER}: {N} check(s) failed.
{For each failure: check name, error summary, details URL}
Could not auto-fix. Manual intervention needed."

## Rules
- NEVER force push or amend commits. Always create new fix commits
- NEVER modify files outside the scope of the failing check
- Maximum 2 fix attempts per check. After 2 failures, escalate to user
- Always run the check locally before pushing a fix
- Commit messages for fixes follow the standard format: fix(<scope>): fix <check-name> failure
- If a test failure looks like a flaky test (passes locally but fails in CI), report it as flaky rather than trying to fix
- If the failure is in a test that was NOT modified by the PR, it's likely a pre-existing or flaky issue. Report to user, don't fix
```

## When NOT to auto-fix

The agent should report to user without attempting fixes when:
- The failing check is not in the fixable list (e.g., security scan, deploy preview, custom checks)
- The test that fails was NOT modified by this PR (pre-existing failure)
- The error is infrastructure-related (Docker, network, timeout, out of memory)
- The same check has already been fixed twice in this cycle
