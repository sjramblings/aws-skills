---
name: deploy-pr-stack
description: >-
  Orchestrates a per-PR ephemeral CloudFormation stack deploy for AWS/CDK
  projects. Use when the user says "deploy pr stack", "spin up an ephemeral
  env", "deploy this PR", "per-PR stack", or when invoked by the pr-stack.yml
  GHA workflow. Prefixes the stack name with `pr-<number>-<project>`, tags it
  with `harness:pr`, `harness:owner`, `harness:ttl`, runs `cdk deploy`, and
  writes deploy outputs to $GITHUB_STEP_SUMMARY (or stdout locally). The
  teardown workflow uses the same tags to GC stacks.
context: fork
skills:
  - capability-probe
  - cfn-stack-events
allowed-tools:
  - Bash(cdk:*)
  - Bash(npm:*)
  - Bash(npx:*)
  - Bash(aws cloudformation:*)
  - Bash(aws sts get-caller-identity:*)
  - Bash(jq:*)
  - Bash(bash:*)
---

# deploy-pr-stack — per-PR ephemeral environment

Every PR gets a real, isolated AWS stack in the sandbox account, deployed on PR open/sync and torn down on PR close. This is Lopopolo's per-worktree legibility pattern applied to AWS: no more "works on my machine" for IaC.

## Guarantees

1. **Unique stack name.** `pr-<NUMBER>-<PROJECT>` — no collisions across PRs.
2. **TTL tag.** `harness:ttl=72h` — the nightly GC workflow destroys any stack older than this.
3. **Ownership + identity.** `harness:owner=<actor>`, `harness:pr=<number>` so the teardown workflow and cost tooling can find it.
4. **Capability-probe gate.** Will NOT deploy if `.harness-cache/capability-probe.json` is missing or older than 24h. Re-run `capability-probe` first if blocked.
5. **Compact failure output.** On `cdk deploy` failure, automatically invokes `cfn-stack-events` to surface the root cause in the agent's context (not raw CFN JSON).
6. **Budget attached.** Calls `tools/scripts/pr-stack-budget.sh` to attach a $5/day Budget with an SNS action that triggers auto-destroy on breach.

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/deploy-pr-stack/scripts/deploy.sh \
  --pr <PR_NUMBER> --project <PROJECT_NAME> [--app <cdk-app-path>] \
  [--context key=val ...] [--region REGION] [--ttl 72h] [--no-budget]
```

Arguments:
- `--pr` — GitHub PR number. Required. Ends up in stack name + tag.
- `--project` — project slug. Required. Matches `.harness-manifest.json#bootstrap.project_name`.
- `--app` — CDK app directory. Default `./cdk`.
- `--context k=v` — repeatable; forwarded as `cdk deploy -c k=v`.
- `--region` — override AWS region. Defaults to `AWS_REGION`.
- `--ttl` — tag value for `harness:ttl`. Default `72h`. Teardown cron honors this.
- `--no-budget` — skip the Budgets attachment (don't do this by default; only when you already have a project-wide budget).

## Workflow

1. `sts get-caller-identity` — record account + caller ARN.
2. Verify `.harness-cache/capability-probe.json` exists and was written within 24h. Fail if not.
3. Build stack name: `pr-<pr>-<project>`.
4. Run `cdk deploy` with `--require-approval never --tags harness:pr=<n> harness:owner=<actor> harness:ttl=<ttl> harness:env=pr harness:project=<project>` and any user `--context` forwards.
5. On success: capture CFN outputs, write to `$GITHUB_STEP_SUMMARY` if set, else stdout.
6. Call `tools/scripts/pr-stack-budget.sh --stack-name <name>` unless `--no-budget`.
7. On failure: invoke `cfn-stack-events` with the stack name and dump the compact table.

## Do not

- Do not deploy without a fresh `capability-probe` cache. The gate exists for a reason.
- Do not deploy to prod regions from this skill — stack prefix `pr-*` is sandbox-only.
- Do not strip the `harness:ttl` tag. The nightly GC depends on it; stripping it creates an orphan.
- Do not hard-code the PR number — always derive from `GITHUB_PR_NUMBER` or `--pr`.

## Relationship to other skills

- **`capability-probe`** (M2) — preflight gate. Must run green within 24h or this skill refuses.
- **`cfn-stack-events`** (M1) — automatic on failure. Surface the reason in ≤500 tokens.
- **`github-environments`** (M3) — sets up the `pr` GitHub environment + OIDC secrets this skill relies on.
- **`post-deploy-verify`** (M5) — runs against the deployed stack outputs.
- **`postmortem-capture`** (M6) — auto-invoked if the deploy fails (via the PostToolUse hook).

## Cost safety

A harness-pilot test with 50 open PRs against a Nova Micro service should cost under $50/month with the 72h TTL and $5/day budget. If your project's per-PR cost exceeds that ceiling, tighten the TTL in `--ttl` (e.g. `24h`) or switch expensive resources to mocks/LocalStack for PR stacks only. The `pr-stack-budget.sh` script is the last-resort kill switch; set it well below your tolerance.
