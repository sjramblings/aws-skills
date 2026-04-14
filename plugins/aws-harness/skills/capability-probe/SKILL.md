---
name: capability-probe
description: >-
  Phase-1 pre-flight that validates AWS service availability, IAM access, and
  marketplace subscription status BEFORE any application logic is written.
  Use when the user says "capability probe", "bedrock availability", "model
  check", "can I use X in region Y", "precheck", "preflight", or before
  starting a new project, adding a new Bedrock model, or moving a stack to a
  new region. Outputs a yes/no matrix of `(model, region) -> ok | iam-missing
  | not-subscribed | profile-mismatch | throttled | not-available`. Blocks
  doomed paths (wrong region prefix, missing marketplace subscription, missing
  IAM grant) before you build against them.
context: fork
skills:
  - cloudtrail-investigator
allowed-tools:
  - Bash(aws bedrock list-foundation-models:*)
  - Bash(aws bedrock list-inference-profiles:*)
  - Bash(aws bedrock get-foundation-model:*)
  - Bash(aws sts get-caller-identity:*)
  - Bash(aws iam simulate-principal-policy:*)
  - Bash(aws marketplace-catalog list-entities:*)
  - Bash(jq:*)
  - Bash(bash:*)
---

# capability-probe — Phase 1 pre-flight

**Rule:** run this before writing application logic that depends on Bedrock models, region-specific services, or marketplace-gated features. Principle P-01 in the harness golden principles.

The viking-context-service retrospective documented this lesson three times: the team churned on Bedrock model IDs (`apac.` → `us.` → `global.` inference profile prefixes), marketplace subscription misses, and IAM gaps — each discovered mid-implementation after application logic was already built against a broken assumption. This skill exists so that never happens again.

## What it validates

For each `(model-id, region)` pair in the probe matrix:

1. **Availability.** Is the foundation model published in that region? (`aws bedrock list-foundation-models --region <r>`)
2. **Inference profile prefix.** If the model is cross-region, does the right prefix (`us.`, `apac.`, `global.`) exist in that region? (`aws bedrock list-inference-profiles --region <r>`)
3. **IAM grant.** Does the calling identity have `bedrock:InvokeModel` + `bedrock:InvokeModelWithResponseStream` on the model ARN? (`aws iam simulate-principal-policy`)
4. **Marketplace subscription.** If the model requires an EULA/marketplace agreement, is the account subscribed? (flagged by error code on `get-foundation-model`)
5. **Account identity.** `aws sts get-caller-identity` — confirms you're hitting the right account.

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/capability-probe/scripts/probe.sh \
  --models "us.anthropic.claude-sonnet-4-5-20250929-v1:0,amazon.nova-micro-v1:0" \
  --regions "us-east-1,ap-southeast-2" \
  [--skip-iam] [--skip-marketplace] [--output json|tsv]
```

Arguments:
- `--models <list>` — comma-separated model IDs. Required.
- `--regions <list>` — comma-separated region codes. Required.
- `--skip-iam` — skip the IAM simulate-principal-policy check. Default: on.
- `--skip-marketplace` — skip the marketplace subscription check. Default: off.
- `--output <format>` — `tsv` (default) or `json`.
- `--cache <path>` — write a result file; default `.harness-cache/capability-probe.json`.

## Output

TSV matrix:

```
MODEL                                             REGION         STATUS             DETAIL
us.anthropic.claude-sonnet-4-5-20250929-v1:0      us-east-1      ok                 profile=us.anthropic.claude-sonnet-4-5
us.anthropic.claude-sonnet-4-5-20250929-v1:0      ap-southeast-2 profile-mismatch   wrong prefix for region; try apac.
amazon.nova-micro-v1:0                            us-east-1      ok                 -
amazon.nova-micro-v1:0                            ap-southeast-2 not-available      model not published in region
anthropic.claude-opus-4-v1:0                      us-east-1      not-subscribed     marketplace EULA required
```

Possible `STATUS` values: `ok`, `not-available`, `profile-mismatch`, `iam-missing`, `not-subscribed`, `throttled`, `error`.

## Cache + freshness

The skill writes `<repo>/.harness-cache/capability-probe.json` with a timestamp. The M3 pre-deploy hook (`pre-tool-use-deploy-guard.sh`) reads this file and blocks `cdk deploy` if it's older than 24 hours or missing. Re-run this skill any time the probe matrix changes (new model, new region, new account).

## Do not

- Do not cache probe results in source control. The cache lives under `.harness-cache/` and is gitignored.
- Do not proceed with any task that depends on a `STATUS != ok` row. Fix the gap first (file a ticket, subscribe, fix IAM, switch prefix) or remove the model/region from the matrix.
- Do not assume `ok` in one region means `ok` in another — Bedrock availability varies per region per model.
- Do not use this skill as a long-running health check. It's a pre-flight gate, not a monitor.

## Relationship to other skills

- **`cloudtrail-investigator`** — if the probe shows `iam-missing` and you need to know exactly which action/resource the caller lacks, follow up with `cloudtrail-investigator --error AccessDenied --service bedrock.amazonaws.com`.
- **`aws-agentic-ai`** skill (to be upgraded in M4) — will refuse to scaffold AgentCore resources if the probe matrix has any red rows.
- **`deploy-pr-stack`** (M3) — the per-PR deploy workflow calls `capability-probe.yml` as a required check.

## Boring-tech gate

This skill also enforces the "boring tech first" principle (golden principle P-11). If you're about to build on an exotic pattern (e.g. streaming responses through API Gateway proxy, Lambda Web Adapter with MCP), call this skill and then write a short ADR under `docs/design-docs/` documenting what you tried, what you learned, and why the boring alternative either works or doesn't. This is the gate that would have saved the VCS team from discovering the REST API Gateway + streaming response incompatibility during UAT.

## Learning-loop note

Any `profile-mismatch`, `not-subscribed`, or `iam-missing` result that makes it past the probe (because someone skipped it) must end up as a learning in `docs/learnings/` via `postmortem-capture` (M6). That's how P-01 earns its keep.
