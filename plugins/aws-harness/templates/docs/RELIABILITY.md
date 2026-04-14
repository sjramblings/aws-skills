---
owner: "@{{OWNER}}"
updated: 2026-04-14
status: draft
---

# Reliability — {{PROJECT_NAME}}

## SLOs

| Service | SLI | SLO | Error budget | Dashboard |
|---|---|---|---|---|
| _none yet_ | | | | |

## Error budgets

Track monthly consumption here as services go live.

## Runbooks

Indexed in [`runbooks/`](runbooks/). One per service. Every on-call-paging alarm must have a runbook linked from its description.

## Circuit breakers and lease TTLs

Every async processing handler must include a circuit breaker and a lease TTL on any DynamoDB processing lock. Lesson learned: viking-context-service Phase 43 retrofit (commit 844647d) added `ROLLUP_COST_CIRCUIT_BREAKER_MAX` after a runaway cascade — bake this in from day 1.

## Post-deploy verification

Every stack has a smoke-test spec in [`smoke-tests/`](smoke-tests/) consumed by the `post-deploy-verify` skill (M5).
