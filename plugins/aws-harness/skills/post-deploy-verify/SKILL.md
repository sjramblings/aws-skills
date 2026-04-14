---
name: post-deploy-verify
description: >-
  Runs declarative smoke tests against a freshly-deployed CloudFormation stack.
  Use when the user says "smoke test", "canary", "post-deploy verify", "verify
  the stack", "is the stack working", or after any successful `cdk deploy` /
  `deploy-pr-stack`. Reads `docs/smoke-tests/&lt;service&gt;.yaml`, resolves CFN
  outputs into request URLs, runs each test, and emits a compact pass/fail
  matrix instead of raw curl output. Closes the loop on the per-PR ephemeral
  stack pattern: every deploy self-verifies.
context: fork
skills:
  - cfn-stack-events
  - cloudwatch-query
allowed-tools:
  - Bash(aws cloudformation describe-stacks:*)
  - Bash(curl:*)
  - Bash(jq:*)
  - Bash(yq:*)
  - Bash(bash:*)
  - Read
---

# post-deploy-verify — declarative smoke tests

Every per-PR stack should self-verify within minutes of deploying. Without this, the harness can only tell you the deploy *finished*, not whether it *works*. This skill closes that gap.

The format is YAML, declarative, and grep-friendly. It's deliberately lower-power than a real test framework — it's a smoke test, not an integration test (that's `integration-test-runner`).

## Smoke-test file format

`docs/smoke-tests/<service>.yaml`:

```yaml
service: my-service
stack_name: pr-${PR_NUMBER}-my-service   # or hard-coded for uat/prod
outputs:
  api_url: ApiEndpoint                   # CFN output name -> short alias
  bucket: ContentBucketName

defaults:
  timeout_seconds: 10
  retries: 3
  retry_delay_seconds: 5

tests:
  - name: health
    request:
      method: GET
      url: "{api_url}/health"
    expect:
      status: 200
      body_contains: "ok"

  - name: ingest_simple
    request:
      method: POST
      url: "{api_url}/ingest"
      headers:
        content-type: application/json
        x-api-key: "${SMOKE_API_KEY}"
      body: |
        {"uri":"smoke://test/1","content":"hello"}
    expect:
      status: 202
      body_contains_path: "$.id"

  - name: ingest_invalid_uri
    request:
      method: POST
      url: "{api_url}/ingest"
      headers:
        content-type: application/json
        x-api-key: "${SMOKE_API_KEY}"
      body: |
        {"uri":"BAD","content":"x"}
    expect:
      status: 400
```

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/post-deploy-verify/scripts/verify.sh \
  --spec docs/smoke-tests/my-service.yaml \
  --pr 42 \
  [--region REGION] \
  [--bail]
```

Arguments:
- `--spec` — path to the smoke-test YAML. Required.
- `--pr` — PR number (substituted into `${PR_NUMBER}` in the YAML). Required for per-PR stacks; omit for uat/prod.
- `--region` — AWS region. Default `AWS_REGION`.
- `--bail` — stop on first failure. Default: run all.

Environment variables referenced in the YAML (e.g. `${SMOKE_API_KEY}`) must be set in the shell or the workflow.

## Output

Compact TSV:

```
NAME                STATUS  CODE  ELAPSED  DETAIL
health              PASS    200   42ms     -
ingest_simple       PASS    202   118ms    id=01HX...
ingest_invalid_uri  PASS    400   88ms     expected 400
```

On failure, exit non-zero. Failed rows expand DETAIL with the mismatch (e.g. `expected 200 got 502 body=Bad Gateway`).

## What `expect` supports

- `status` — exact HTTP status code
- `status_in` — list of acceptable codes
- `body_contains` — literal substring match
- `body_contains_path` — JSONPath expression that must resolve to a value
- `body_matches` — full-string regex match
- `header` — `{key: value}` map of required response headers
- `body_json_equals` — exact JSON match (deep)

Anything more complex belongs in `integration-test-runner`, not here.

## Workflow

1. Resolve `stack_name` against the PR/region context (substitute `${PR_NUMBER}`).
2. `aws cloudformation describe-stacks --stack-name <resolved>` and pull the OutputValue map.
3. Substitute `{alias}` placeholders in URLs/headers/body using the outputs map.
4. For each test, run `curl` with the configured timeout and retries.
5. Apply expectations; record pass/fail.
6. Print TSV. Exit non-zero if any test failed.

## Do not

- Do not invent endpoints not declared in the YAML. The smoke-test spec is the source of truth.
- Do not put secrets in the YAML. Use `${ENV_VAR}` placeholders and inject them at runtime.
- Do not paste raw curl output into context. The skill's compact output IS the agent-legible view.
- Do not run smoke tests against prod from local — only via the deploy workflow.
- Do not skip a failing test by deleting it. Mark it `@known-red` and triage per the red-test policy.

## Relationship to other skills

- **`deploy-pr-stack`** (M3) — runs this immediately after a successful deploy.
- **`integration-test-runner`** (M5) — heavier sibling for full integration suites.
- **`cfn-stack-events`** (M1) — pivot here when verify fails because the stack is still rolling back.
- **`cloudwatch-query`** (M1) — pivot here when verify fails to see the handler errors.

## Learning-loop note

A smoke-test failure that surfaces a bug not covered by an existing test should add a new entry to the YAML in the same PR that fixes the bug. That's how the smoke suite grows from real failures rather than aspiration.
