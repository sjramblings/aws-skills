---
owner: "@{{OWNER}}"
updated: 2026-04-14
status: active
---

# Golden Principles — {{PROJECT_NAME}}

> The living canon. One principle per line. Each principle **must** have a backing lint or skill, or be marked `advisory: true`. The `golden-principle-has-lint.py` lint (M4) enforces this.
>
> Principles are added when a learning in `docs/learnings/` surfaces a recurring pattern. Do not add aspirational principles — only ones earned from real failures.

## Principles

| ID | Principle | Backing | Source learning | Advisory? |
|---|---|---|---|---|
| P-01 | Run `capability-probe` before writing application logic that depends on Bedrock models, region-specific services, or marketplace-gated features. | `capability-probe.yml` (M2) | VCS Bedrock model-ID churn | no |
| P-02 | Service-principal grants on S3/SNS/SQS require `aws:SourceAccount` **and** `aws:SourceArn` conditions. | `cdk-confused-deputy.ts` (M4) | VCS 15e104c, b5a25bf | no |
| P-03 | Queues, topics, and buckets must use encryption at rest. | `cdk-encryption-required.ts` (M4) | VCS S-03 Council finding | no |
| P-04 | Buckets and queues must enforce SSL-only via resource policy. | `cdk-ssl-only.ts` (M4) | VCS Council review | no |
| P-05 | SQS visibility timeout must be ≥ 6 × the consumer Lambda's timeout. | `cdk-sqs-visibility-timeout.ts` (M4) | VCS ad1c517 | no |
| P-06 | Do not set Lambda `reservedConcurrency = 1` on a FIFO SQS consumer — breaks ordering. Use ≥ 2 or remove the reservation. | `cdk-fifo-maxconcurrency.ts` (M4) | VCS 92d7096 | no |
| P-07 | Parse every handler input at the boundary with Zod. No trust-by-default shapes. | `zod-parse-at-boundary.ts` (M4) | VCS ULID lowercasing bug #3 | no |
| P-08 | Bedrock clients must be wrapped with `withCostInstrumentation`. Cost metrics from day 1. | `bedrock-cost-instrumentation.ts` (M8) | VCS retroactive cost instrumentation | no |
| P-09 | Every async processing handler needs a circuit breaker and a lease TTL on its DynamoDB lock. | `aws-serverless-eda` skill patterns (M4 upgrade) | VCS 844647d Phase 43 | no |
| P-10 | Cross-stack discovery uses SSM Parameter Store dynamic references (`StringParameter.valueForStringParameter`), never `CfnOutput exportName` or construct attributes passed across stacks. Both create CloudFormation exports that deadlock updates. | `cdk-no-cross-stack-exports.ts` | VCS layered-construct pattern + EdgeSignal 2026-04-15 | no |
| P-11 | Boring tech first. If a feature requires exotic infra (streaming through API GW, etc.), probe and write an ADR before building. | `capability-probe` + design-doc gate | VCS MCP+Lambda-Web-Adapter streaming | no |
| P-12 | Known-red tests block commits. Never defer a failing test to "fix later." | `pre-commit-red-test-block.sh` (M5) | VCS Phases 2-5 bedrock.test.ts drag | no |
| P-13 | Every new service directory requires a STRIDE threat model before merge. | `threat-model-check.yml` (M4) | VCS 28 post-launch Council findings | no |
| P-14 | AGENTS.md is a MAP. Under 150 lines. Links only. | `agents-md-map-only.py` (M4) | Lopopolo "AGENTS.md as table of contents" | no |
| P-15 | Active exec-plans need a progress-log entry every 7 days or they move to `completed/`. | `doc-freshness.py` (M7) | Lopopolo doc-gardening | no |

## How to add a principle

1. A learning is captured in `docs/learnings/<date>-<slug>.md`.
2. If the learning's `lint-proposal` field is non-empty and the pattern could recur, add a row here.
3. Either implement the backing lint/skill in the same PR or mark `advisory: true`.
4. Every advisory principle is reviewed weekly — either promote to enforced or delete.
