---
name: security-review-aws
description: >-
  Static security scanner for CDK synth output. Use when the user says
  "security review", "confused deputy", "iam audit", "review synth",
  "cdk security scan", or before any deploy to uat/prod. Runs the harness
  custom lints against cdk.out/ and returns a compact findings table —
  severity, finding ID, resource, remediation hint. Catches the 11 defect
  classes enumerated in golden-principles P-02..P-08 and the doc/governance
  lints. Complements the design-time threat-model-stride skill with a
  run-time static check of actual CDK output.
context: fork
skills:
  - cfn-stack-events
allowed-tools:
  - Bash(cdk synth:*)
  - Bash(npx:*)
  - Bash(node:*)
  - Bash(python3:*)
  - Bash(jq:*)
  - Bash(bash:*)
  - Read
---

# security-review-aws — static security scanner

Runs every harness lint against the CDK synth output (and some source files) and returns a compact findings table. This is the "did we actually implement the threat model?" check.

## What it scans

Against `cdk.out/*.template.json` and the source tree:

1. **Confused deputy** (`cdk-confused-deputy.ts`) — service-principal grants without `aws:SourceAccount` + `aws:SourceArn`.
2. **Encryption at rest** (`cdk-encryption-required.ts`) — unencrypted queues, topics, buckets.
3. **SSL-only transport** (`cdk-ssl-only.ts`) — missing `aws:SecureTransport` enforcement.
4. **SQS visibility timeout** (`cdk-sqs-visibility-timeout.ts`) — queue visibility < 6× consumer Lambda timeout (VCS lesson `ad1c517`).
5. **FIFO maxConcurrency** (`cdk-fifo-maxconcurrency.ts`) — Lambda `reservedConcurrency=1` on FIFO SQS (VCS lesson `92d7096`).
6. **Resource tags** (`cdk-resource-tags.ts`) — missing `owner`, `cost-center`, `data-classification`, `harness:env`.
7. **Zod parse at boundary** (`zod-parse-at-boundary.ts`) — handler reads `event.body` without Zod parse.
8. **Bedrock cost instrumentation** (`bedrock-cost-instrumentation.ts`) — Bedrock client without cost-instrumentation wrapper (M8).
9. **Doc freshness** (`doc-freshness.py`) — active exec-plans with no progress-log entry in 7 days.
10. **AGENTS.md is a MAP** (`agents-md-map-only.py`) — file >150 lines or contains non-link prose.
11. **Golden-principle has lint** (`golden-principle-has-lint.py`) — any enforced principle without a backing lint file.

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/security-review-aws/scripts/review.sh \
  [--app ./cdk] [--advisory] [--json] [--fail-on critical|high|medium]
```

Arguments:
- `--app` — CDK app dir. Default `./cdk`.
- `--advisory` — report but never exit non-zero. Useful for onboarding new lints (48h soak window per P-11 risk mitigation).
- `--json` — emit JSON instead of TSV.
- `--fail-on` — minimum severity that causes non-zero exit. Default `high`.

## Workflow

1. `cdk synth --quiet` if `cdk.out/` is missing or older than the source.
2. For each `cdk.out/*.template.json`, run the CDK-level lints (the `.ts` files) via `npx ts-node tools/lints/run-lints.ts`.
3. Run the Python governance lints (`doc-freshness.py`, `agents-md-map-only.py`, `golden-principle-has-lint.py`) against the repo root.
4. Collect findings, normalize severity, sort by severity.
5. Emit a compact TSV:
   ```
   SEVERITY  LINT                      RESOURCE                         MESSAGE
   critical  cdk-confused-deputy       ContentBucket/Policy             Service-principal grant missing aws:SourceAccount / aws:SourceArn. See docs/references/confused-deputy-llms.txt
   high      cdk-sqs-visibility-timeout ProcessQueue                    Visibility timeout 30s < 6 × Lambda 180s. Set to >= 1080s.
   medium    cdk-resource-tags         MyFunction                       Missing tags: cost-center, data-classification
   ```
6. Exit non-zero if any finding ≥ `--fail-on` severity.

## Severity ladder

| Severity | Examples |
|----------|----------|
| critical | confused deputy, missing encryption, IAM wildcard on secrets |
| high | SQS timeout misalignment, FIFO concurrency, missing SSL-only |
| medium | missing tags, Zod boundary, doc freshness |
| low | AGENTS.md style, golden-principle lint backing |

## Do not

- Do not run this skill against prod stacks in a read-only AWS account — `cdk synth` needs bootstrap. Scan the CDK app locally or in the per-PR stack CI.
- Do not suppress findings with inline comments. Suppression goes through `cdk-nag` + `NagSuppressions.addResourceSuppressions` with a justification — reviewed at PR time.
- Do not pipe raw `cdk synth` output into agent context. This skill's output IS the compact view.

## Relationship to other skills

- **`threat-model-stride`** — design-time companion. Threat model says "we plan to prevent X"; this skill verifies "we actually did prevent X at synth".
- **`capability-probe`** — runtime preflight (availability); this is static (implementation).
- **`deploy-pr-stack`** — PR workflow calls this skill before every deploy.
- **`postmortem-capture`** (M6) — any finding promoted to a new lint must add an entry to `docs/learnings/` with the lint file name.

## Learning-loop note

When a new defect class appears in post-launch Council findings (like VCS had), the fix is: (1) write the fix, (2) add a lint under `tools/lints/`, (3) register in `golden-principles.md`, (4) add the learning under `docs/learnings/`. This skill picks up the new lint automatically at next run.
