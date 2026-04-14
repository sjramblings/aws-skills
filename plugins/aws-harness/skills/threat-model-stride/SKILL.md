---
name: threat-model-stride
description: >-
  Phase-1 STRIDE threat modeling for AWS services. Use when the user says
  "threat model", "stride", "security review design", "design review",
  "new service", or whenever a new service directory is being added. Takes
  a design doc (or service name) and produces docs/threat-models/&lt;service&gt;-
  stride.md with a complete STRIDE matrix and a human sign-off block. The
  threat-model-check.yml workflow blocks any PR that adds a new service
  directory without a signed STRIDE doc. Implements golden principle P-13.
context: fork
allowed-tools:
  - Read
  - Write
  - Bash(ls:*)
  - Bash(find:*)
  - Bash(git:*)
---

# threat-model-stride — Phase-1 STRIDE threat modeling

STRIDE = Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege. This skill produces one STRIDE doc per service, capturing the threats and the mitigations *before* the service ships.

The viking-context-service retrospective discovered 28 Council findings *after* launch. This skill is the "catch them at Phase 1" investment that would have prevented most of those.

## When to invoke

- A new directory is being added under `cdk/lib/` or `services/`.
- The user says "threat model", "stride", "security review design", "design review".
- A design-doc (`docs/design-docs/*.md`) is being drafted or modified.
- Before any PR that introduces a new handler, new queue, new bucket, new API, or new cross-account trust.

## Workflow

1. **Identify the service.** If the user hasn't named it, ask. Resolve to a directory path under `cdk/lib/<service>` or similar.
2. **Check if a threat model already exists.** `docs/threat-models/<service>-stride.md`. If yes, ask whether to update or start fresh.
3. **Gather context.** Read the service's design doc (`docs/design-docs/*<service>*.md`), any existing CDK constructs, and the relevant product spec.
4. **Write the threat model.** Copy `templates/threat-model.md` (included in this skill) into the target path, substituting `{{SERVICE_NAME}}` and filling in each STRIDE category with specific, actionable entries (not generic boilerplate).
5. **Enumerate components.** For each component (Lambda, DDB table, SQS queue, bucket, API route, etc.) walk the STRIDE categories and record:
   - Threat description
   - Likelihood (low/med/high)
   - Impact (low/med/high)
   - Mitigation (ideally a lint that catches it, or an explicit design constraint)
   - Status: `mitigated | accepted | deferred`
6. **Cross-reference lints.** Every lint-backed mitigation must cite the lint file (e.g. `tools/lints/cdk-confused-deputy.ts`). This closes the loop between threat model and static enforcement.
7. **Human sign-off block.** The doc ends with a `Sign-off` section containing an unchecked `- [ ]` checkbox. CI's `threat-model-check.yml` fails the PR until a reviewer checks it.

## STRIDE prompts per category

Use these as the starter questions per component:

- **Spoofing** — Can a wrong principal call this? Is there auth? OIDC? Confused deputy risk?
- **Tampering** — Can the input be modified in transit? At rest? Is there a signature or checksum? Zod boundary parse?
- **Repudiation** — Is there an audit trail? CloudTrail coverage? Request IDs in logs?
- **Information disclosure** — Encryption at rest + in transit? Least-privilege reads? PII flagging?
- **Denial of service** — Rate limits? Circuit breaker? Cost kill-switch? SQS backpressure?
- **Elevation of privilege** — IAM scopes? Service-principal source conditions? Cross-account guards?

## Output format

The generated file has this structure (matching `templates/threat-model.md`):

```markdown
---
service: <name>
owner: "@<handle>"
status: draft
created: <date>
reviewed: -
---

# Threat model — <service>

## Components
| ID | Component | Type | Notes |

## STRIDE matrix
### S — Spoofing
| ID | Threat | Likelihood | Impact | Mitigation | Status |

### T — Tampering
...

## Sign-off
- [ ] Reviewed by: @<reviewer>
- Date: <date>
- Notes:
```

## Do not

- Do not fill in the matrix with "none" or "N/A". If a category truly doesn't apply, write one sentence explaining why — that's your audit trail.
- Do not self-sign. The `threat-model-check.yml` workflow checks that the sign-off checkbox was toggled in a separate commit by a different user.
- Do not copy another service's threat model verbatim. Common mitigations are fine; specific component lists and threats must reflect the actual service.
- Do not mark everything `accepted`. Any `accepted` risk requires a 1-line justification linked to a runbook in `docs/runbooks/`.

## Relationship to other skills

- **`security-review-aws`** — the static scanner version of this. Run both. The skill is for design-time threats; the scanner catches implementation drift.
- **`capability-probe`** — preflight check. Different axis: probe is about service availability; STRIDE is about security posture.
- **`postmortem-capture`** (M6) — any post-launch security finding must update the threat model. Closing the loop.

## Graduation signal

Once `threat-model-check.yml` has passed for 5 consecutive new services, the harness has earned the right to claim "security review is Phase 1". Track that count in `docs/QUALITY_SCORE.md`.
