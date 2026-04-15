---
owner: "@sjramblings"
updated: 2026-04-15
status: active
---

# Harness Quality Score

Meta-metrics for the `aws-harness` plugin itself. Distinct from
project-level `docs/QUALITY_SCORE.md` files (which the harness scaffolds
into target projects). This file tracks how well the **harness** is
working across all projects that use it.

Updated by `plugins/aws-harness/scripts/harness-self-review.sh` (local
weekly cron, M9) and by manual review.

## Current scores (0–10)

| Dimension | Score | Trend | Notes |
|---|---|---|---|
| Agent friction per session | — | — | First week of M9 telemetry |
| Legibility-skill adoption % | — | — | (raw AWS calls vs wrapped) |
| Capability-probe gate save count | — | — | Times P-01 blocked a doomed path |
| Golden-principle recurrence rate | 0 | flat | Zero recurrence target |
| Time-to-first-green-deploy | — | — | Target: <4h |
| Doc-gardener auto-merge rate | — | — | New in M7 |
| Pending postmortems backlog | — | — | New in M6 |
| Self-improvement issues opened | 0 | — | New in M9 |
| Self-improvement issues resolved | 0 | — | New in M9 |

## History

| Week | Patterns found | Trigger | Notes |
|---|---|---|---|
| 2026-W15 | (initial) | M9 ship | First mine baseline |
| 2026-W16 | 3 | weekly self-review | First real run from local script |

## Graduation gate

The harness has fully closed the meta-loop when **all** of these are
true for 14 consecutive days:

- At least one `harness-self-improvement` issue has been authored,
  fixed, and merged
- The targeted friction pattern's frequency has dropped by ≥50% in
  the next week's mine
- Zero recurrence of any defect class in `golden-principles.md` P-01
  through P-15
- Time-to-first-green-deploy < 4 hours on a fresh greenfield trial

Track progress here weekly.
