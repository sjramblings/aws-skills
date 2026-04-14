---
owner: "@{{OWNER}}"
updated: 2026-04-14
status: active
---

# Quality Score — {{PROJECT_NAME}}

Rolling quality grade. Updated by CI and by the `golden-principles-enforcer` daily cron (M6).

| Dimension | Score (0-10) | Trend | Notes |
|---|---|---|---|
| Test coverage (integration) | — | — | No tests yet |
| Lint health (custom lints green) | — | — | Lints land in M4 |
| Doc freshness (exec-plans updated <7d) | — | — | Enforced by M7 doc-gardener |
| Legibility-skill adoption (raw AWS calls vs wrapped) | — | — | Measured starting M1 |
| Golden-principle recurrence rate | — | — | Zero recurrence target |
| Time-to-first-green-deploy | — | — | Target: <4h |

## History

| Date | Overall | Delta | Trigger |
|---|---|---|---|
| _scaffolded_ | — | — | harness-init M0 |
