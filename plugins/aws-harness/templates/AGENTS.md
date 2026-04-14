# AGENTS.md — {{PROJECT_NAME}}

> **This file is a MAP, not an encyclopedia.** Keep it under 150 lines. Link to `docs/`. Never duplicate content. A lint enforces this (coming in M4).

## What this project is

One-paragraph description. Fill this in when you know what you're building. Avoid restating what any design doc already says — link instead.

## How to navigate

| If you need... | Go to |
|---|---|
| High-level architecture | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| Security posture and threat models | [`docs/SECURITY.md`](docs/SECURITY.md) |
| SLOs, error budgets, runbooks | [`docs/RELIABILITY.md`](docs/RELIABILITY.md) |
| Current quality score | [`docs/QUALITY_SCORE.md`](docs/QUALITY_SCORE.md) |
| The living canon of rules | [`docs/golden-principles.md`](docs/golden-principles.md) |
| Active work | [`docs/exec-plans/active/`](docs/exec-plans/active/) |
| Completed work (history) | [`docs/exec-plans/completed/`](docs/exec-plans/completed/) |
| ADRs / design decisions | [`docs/design-docs/`](docs/design-docs/) |
| Product specs | [`docs/product-specs/`](docs/product-specs/) |
| STRIDE threat models per service | [`docs/threat-models/`](docs/threat-models/) |
| Postmortems and learnings | [`docs/learnings/INDEX.md`](docs/learnings/INDEX.md) |
| Incident runbooks | [`docs/runbooks/`](docs/runbooks/) |
| Smoke-test specs | [`docs/smoke-tests/`](docs/smoke-tests/) |
| Long-form reference dumps | [`docs/references/`](docs/references/) |

## Operating principles (short form — full list in `golden-principles.md`)

1. **Legibility first.** Query CloudFormation via the `cfn-stack-events` skill. Query CloudWatch via `cloudwatch-query`. Query CloudTrail via `cloudtrail-investigator`. Never paste raw AWS API output into context.
2. **Capability-probe before building.** Run `capability-probe` before writing application logic that depends on Bedrock models, specific regions, or marketplace-gated services.
3. **Parse at the boundary.** Every handler that touches `event.body`, external payloads, or user input must parse with Zod (or equivalent). No trust-by-default shapes.
4. **Plans are first-class.** Non-trivial work starts with an exec plan in `docs/exec-plans/active/` with a progress log.
5. **Failures are signal.** When something fails, write a learning in `docs/learnings/`, update `golden-principles.md`, and propose a lint if the pattern could recur.
6. **Start small, validate end-to-end, grow.** Do not layer new complexity on top of an unvalidated base.

## Environments

- **Sandbox (per-PR ephemeral):** AWS account `{{SANDBOX_ACCOUNT}}`, stack prefix `pr-<number>-{{PROJECT_NAME}}`, TTL 72h.
- **UAT:** region `{{UAT_REGION}}`, deployed from `main`.
- **Prod:** region `{{PROD_REGION}}`, deployed on release tag with manual approval.

## Owner

Primary: `@{{OWNER}}`

## Harness version

Recorded in `.harness-manifest.json`. Run `/harness-init --upgrade` to pull in changes from the `aws-harness` plugin.
