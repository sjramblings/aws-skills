---
service: {{SERVICE_NAME}}
owner: "@{{OWNER}}"
status: draft
created: {{DATE}}
reviewed: -
---

# Threat model — {{SERVICE_NAME}}

STRIDE analysis. Every component and every threat entry must be specific — no "N/A", no boilerplate. If a category truly doesn't apply, write one sentence explaining why.

## Components

| ID | Component | Type | Notes |
|----|-----------|------|-------|
| C1 | _e.g. IngestionHandler_ | AWS::Lambda::Function | _brief role_ |
| C2 | _e.g. ContentBucket_ | AWS::S3::Bucket | |
| C3 | _e.g. ProcessQueue_ | AWS::SQS::Queue (FIFO) | |

## STRIDE matrix

### S — Spoofing

| ID | Threat | Likelihood | Impact | Mitigation | Status |
|----|--------|-----------|--------|------------|--------|
| S1 | Unauthenticated caller invokes API | low | high | API Gateway + Cognito / IAM auth | mitigated |
| S2 | Cross-account service principal writes to C2 without source-account condition (confused deputy) | med | high | `tools/lints/cdk-confused-deputy.ts` + resource policy with `aws:SourceAccount` + `aws:SourceArn` | mitigated |

### T — Tampering

| ID | Threat | Likelihood | Impact | Mitigation | Status |
|----|--------|-----------|--------|------------|--------|
| T1 | Handler trusts untyped `event.body` shape | med | med | Zod parse at boundary + `tools/lints/zod-parse-at-boundary.ts` | mitigated |
| T2 | Object in C2 replaced via direct S3 PUT | low | high | Bucket versioning + SSL-only policy + SSE-KMS | mitigated |

### R — Repudiation

| ID | Threat | Likelihood | Impact | Mitigation | Status |
|----|--------|-----------|--------|------------|--------|
| R1 | API action with no audit trail | low | med | CloudTrail data events on C2 + structured logs with request ID | mitigated |

### I — Information disclosure

| ID | Threat | Likelihood | Impact | Mitigation | Status |
|----|--------|-----------|--------|------------|--------|
| I1 | C2 object listing readable by broader principals than intended | med | high | Least-privilege IAM + S3 Block Public Access + bucket policy | mitigated |
| I2 | SQS queue payload readable from untrusted consumer | low | med | KMS encryption + IAM scope + `tools/lints/cdk-encryption-required.ts` | mitigated |

### D — Denial of service

| ID | Threat | Likelihood | Impact | Mitigation | Status |
|----|--------|-----------|--------|------------|--------|
| D1 | Runaway rollup cascade exhausts Bedrock tokens | med | high | Circuit breaker + cost kill-switch in handler (VCS lesson, Phase 43) | mitigated |
| D2 | SQS visibility timeout < 6× Lambda timeout causes message redelivery storm | med | high | `tools/lints/cdk-sqs-visibility-timeout.ts` | mitigated |

### E — Elevation of privilege

| ID | Threat | Likelihood | Impact | Mitigation | Status |
|----|--------|-----------|--------|------------|--------|
| E1 | Lambda execution role has wildcard bedrock:InvokeModel | low | high | Scope to specific model ARNs; IAM review | mitigated |
| E2 | FIFO consumer with reservedConcurrency=1 breaks ordering (DoS-via-disorder) | low | med | `tools/lints/cdk-fifo-maxconcurrency.ts` | mitigated |

## Accepted risks

| ID | Risk | Justification | Runbook |
|----|------|---------------|---------|
| _none yet_ | | | |

## Sign-off

Must be checked by a reviewer OTHER than the author in a separate commit. The `threat-model-check.yml` workflow enforces this.

- [ ] Reviewed by: @<reviewer-handle>
- Date: <YYYY-MM-DD>
- Notes:
