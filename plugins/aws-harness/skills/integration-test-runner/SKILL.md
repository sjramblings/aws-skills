---
name: integration-test-runner
description: >-
  Runs integration tests against a deployed per-PR stack. Use when the user
  says "integration test", "run tests against stack", "integration suite", or
  invoked by the pr-stack workflow after a successful deploy. Resolves CFN
  outputs into env vars, runs `npm test` / `pytest` filtered to tests tagged
  `integration`, and emits a compact pass/fail/skip summary instead of raw
  test runner output. Heavier sibling of post-deploy-verify.
context: fork
skills:
  - cfn-stack-events
  - cloudwatch-query
allowed-tools:
  - Bash(aws cloudformation describe-stacks:*)
  - Bash(npm:*)
  - Bash(npx:*)
  - Bash(pytest:*)
  - Bash(python3:*)
  - Bash(jq:*)
  - Bash(bash:*)
---

# integration-test-runner — run integration tests against a live stack

`post-deploy-verify` does declarative smoke tests. This skill runs the real
integration suite (the kind with assertions, fixtures, and setup/teardown)
against the same per-PR stack. Both should run on every PR — smoke first
(fast, declarative), then integration (heavier, asserts behavior).

## When to use

- After `deploy-pr-stack` succeeds.
- After `post-deploy-verify` passes.
- When the user says "run integration tests", "integration suite", "verify the PR stack works end-to-end".
- Locally, when iterating against a sandbox stack you've manually deployed.

## How it picks tests

It does NOT run all tests — only tests tagged `integration`:

- **TypeScript/Vitest:** `describe('@integration ...')` or filename `*.integration.test.ts`
- **Python/pytest:** `@pytest.mark.integration` decorator
- **Jest:** `describe('@integration ...')` with `--testNamePattern @integration`

Unit tests are skipped — they should already be green via the pre-commit
red-test block.

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/integration-test-runner/scripts/run.sh \
  --stack <stack-name> [--region REGION] [--runner auto|vitest|jest|pytest] \
  [--bail] [--timeout-minutes 15]
```

Arguments:
- `--stack` — CFN stack name to resolve outputs from. Required.
- `--region` — AWS region. Default `AWS_REGION`.
- `--runner` — test runner. Default `auto` (detects from `package.json` / `pyproject.toml`).
- `--bail` — stop on first failure.
- `--timeout-minutes` — overall timeout. Default 15.

## What the script does

1. `aws cloudformation describe-stacks --stack-name <stack>` and pull the OutputValue map.
2. Export each output as `STACK_<KEY>=<value>` env var (e.g. `STACK_API_ENDPOINT=https://...`).
3. Detect the runner from `package.json` (vitest/jest) or `pyproject.toml` / `pytest.ini` (pytest).
4. Run the test command with the integration filter:
   - vitest: `npx vitest run --reporter=json --testNamePattern @integration`
   - jest: `npx jest --json --testNamePattern @integration`
   - pytest: `python3 -m pytest -m integration --json-report --json-report-file=.harness-cache/pytest.json`
5. Parse the JSON report; emit compact summary:
   ```
   RUNNER  TOTAL  PASS  FAIL  SKIP  ELAPSED
   vitest  42     38    2     2     2m18s
   ```
6. List failed tests under the summary with their first error line.
7. Exit non-zero if any test failed.

## Output format

```
RUNNER  TOTAL  PASS  FAIL  SKIP  ELAPSED
pytest  18     17    1     0     38s

FAILED:
  tests/integration/test_ingest.py::test_round_trip
    AssertionError: expected 202 got 500
```

The skill never dumps the full test runner output. If a single test's stack
trace is needed, the agent should follow up with `cloudwatch-query
function=<handler> level=ERROR last=10m`.

## Do not

- Do not run integration tests against prod from local. Only via the deploy workflow targeting `pr` env stacks.
- Do not run in parallel with `post-deploy-verify` against the same stack — they may interfere with each other's fixtures.
- Do not leave fixture data in the stack after the run. Tests must clean up after themselves; if they can't, mark the test as `@destructive` and let the per-PR teardown handle it.
- Do not paste raw test runner output into context. The compact summary is the agent-legible view.

## Relationship to other skills

- **`deploy-pr-stack`** (M3) — runs this immediately after a successful deploy + post-deploy-verify.
- **`post-deploy-verify`** (M5) — lighter sibling. Run that first; if smoke fails there's no point running integration.
- **`cloudwatch-query`** (M1) — pivot here when an integration test fails to inspect handler errors.
- **`postmortem-capture`** (M6) — auto-invoked if integration suite fails on PR.

## Learning-loop note

A failed integration test that surfaces a regression should add a regression-guard test in the same PR, not be deferred. Per golden principle P-12 (red test policy).
