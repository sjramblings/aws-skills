---
owner: "@{{OWNER}}"
updated: 2026-04-14
status: draft
---

# Security — {{PROJECT_NAME}}

## Threat model index

| Service | STRIDE doc | Last reviewed | Sign-off |
|---|---|---|---|
| _none yet_ | | | |

STRIDE threat models live in [`threat-models/`](threat-models/). Every new service directory must have one before it can merge (enforced by `threat-model-check.yml` in M4).

## Controls matrix

| Control | Status | Lint backing | Notes |
|---|---|---|---|
| Confused-deputy protection on S3/SNS/SQS | pending | `cdk-confused-deputy.ts` (M4) | All service-principal grants must use `aws:SourceAccount` + `aws:SourceArn`. |
| Encryption at rest | pending | `cdk-encryption-required.ts` (M4) | Queues, topics, buckets must use KMS. |
| SSL-only transport | pending | `cdk-ssl-only.ts` (M4) | Bucket/queue resource policies enforce `aws:SecureTransport`. |
| SQS visibility timeout alignment | pending | `cdk-sqs-visibility-timeout.ts` (M4) | Visibility ≥ 6 × Lambda timeout. |
| Resource tagging | pending | `cdk-resource-tags.ts` (M4) | `owner`, `cost-center`, `data-classification`, `harness:env` required. |
| Zod parse at boundary | pending | `zod-parse-at-boundary.ts` (M4) | All handler inputs validated at the edge. |
| No hardcoded secrets | pending | `security-review-aws` skill (M4) | Use SSM Parameter Store or Secrets Manager. |

## Incident response

See [`runbooks/`](runbooks/) for service-specific runbooks.
