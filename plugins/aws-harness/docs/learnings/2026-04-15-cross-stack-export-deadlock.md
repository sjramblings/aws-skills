---
title: Cross-stack CloudFormation export deadlock (EdgeSignal)
date: 2026-04-15
project: aws-harness
session_id: n/a
source: manual-capture
status: fixed
severity: high
labels: [cdk, cross-stack, cloudformation, exports, ssm, edge-signal]
---

## Symptom

`EdgeSignal-Api` stack updates were rejected by CloudFormation. The
`Api` stack was trying to remove the Cognito user-pool export
(`ExportsOutputRefUserPool6BA7E5F296FD7236`) but CloudFormation
refused:

> Cannot delete export `ExportsOutputRefUserPool6BA7E5F296FD7236` —
> it is imported by stack EdgeSignal-Frontend.

The `EdgeSignal-Frontend` stack was still holding an `Fn::ImportValue`
for the user pool + API URL that CDK had synthesized when Frontend
was constructed with `apiUrl: api.apiUrl` and similar props from the
Api stack.

## Root cause

**Five whys:**

1. Why did the deploy fail? CloudFormation refused to remove an export.
2. Why was there an export? CDK synthesized `CfnOutput` entries with
   `Export.Name` on the producer stack.
3. Why did CDK synthesize those? Because `FrontendStack` was
   constructed with `apiUrl: api.apiUrl` — passing construct attributes
   across a stack boundary. CDK resolves that at synth time into a
   cross-stack `Export` / `Fn::ImportValue` pair.
4. Why was Frontend reading Api attributes directly? Because the
   aws-cdk-development skill in this plugin collection was teaching
   exactly that pattern — `cdk-patterns.md` line 519-529 recommended
   `CfnOutput` with `exportName` as GOOD practice.
5. Why wasn't this caught at synth or PR time? No lint existed to
   flag `Export.Name` or `Fn::ImportValue` in synth output. Golden
   principle P-10 existed but was marked `advisory` with no backing
   lint.

The environment was actively teaching the anti-pattern and had no
mechanical enforcement to prevent it. Classic Lopopolo "failure is
signal about what's missing from the environment."

## Detection gap

- **The CDK skill was wrong.** `cdk-patterns.md` recommended
  `CfnOutput` with `exportName` as a best practice. `SKILL.md` said
  "Export values that other stacks may need" under Stack Organization.
- **The golden principle was advisory.** P-10 existed ("Cross-construct
  discovery uses SSM Parameter Store") but with `advisory: yes` and
  backing cell that pointed at "aws-cdk-development skill reference
  (M4 upgrade)" — a reference that was never actually written.
- **No lint.** Nothing statically flagged `Export.Name` or
  `Fn::ImportValue` in `cdk.out/*.template.json`.

## Fix

**Application-level** (EdgeSignal repo):

- `lib/api-stack.ts` — producer writes three SSM parameters:
  `/edgesignal/api/url`, `/edgesignal/cognito/user-pool-id`,
  `/edgesignal/cognito/user-pool-client-id`. No more public readonly
  fields exposed from the stack.
- `lib/frontend-stack.ts` — consumer drops `apiUrl` props entirely.
  Reads the three parameters via
  `ssm.StringParameter.valueForStringParameter`. Publishes a
  `config.json` alongside the Vite build using `Fn.toJsonString`.
- `bin/edgesignal.ts` — `FrontendStack` no longer receives
  `apiUrl: api.apiUrl`. Adds `frontend.addDependency(api)` so
  producer runs first on a clean deploy.
- `dashboard/src/config/runtime.ts` — new. Loads `/config.json` at
  startup, falls back to `VITE_*` env vars for local dev.
- `dashboard/src/main.tsx` — awaits `loadRuntimeConfig()` then
  `configureAmplify()` then renders.
- `dashboard/src/api/client.ts` — reads `getRuntimeConfig().apiUrl`.

`cdk synth` completes successfully with this setup.

**Harness-level** (this PR):

- `plugins/aws-cdk/skills/aws-cdk-development/references/cdk-patterns.md`
  — the "Ignoring Stack Outputs" section rewritten. The old example
  now has a ❌ and the full SSM pattern replaces it as ✅. Links to
  the remediation reference doc.
- `plugins/aws-cdk/skills/aws-cdk-development/SKILL.md` — Stack
  Organization bullet rewritten: "Cross-stack discovery via SSM
  Parameter Store, not CloudFormation exports."
- `plugins/aws-harness/templates/tools/lints/cdk-no-cross-stack-exports.ts`
  — new lint. Flags any `Outputs.*.Export.Name` (producer-side
  exports) and any `Fn::ImportValue` anywhere in `Resources`
  (consumer-side imports). Severity `high`. Smoke-tested end-to-end
  against a synthetic template — catches both.
- `plugins/aws-harness/templates/tools/lints/run-lints.ts` — new lint
  wired into the runner.
- `plugins/aws-harness/templates/docs/references/cross-stack-ssm-llms.txt`
  — new reference doc. Full EdgeSignal example: producer stack,
  consumer stack, app wiring with `addDependency`, Vite runtime
  config loader, recovery steps for existing prod stacks.
- `plugins/aws-harness/templates/docs/golden-principles.md` — P-10
  promoted from `advisory` to `no` (enforced). Backing changed from
  "skill reference" to `cdk-no-cross-stack-exports.ts`. Source
  expanded to include EdgeSignal 2026-04-15. Principle text
  rewritten to be unambiguous about what's banned.

## Golden principle delta

P-10 promoted from `advisory` to enforced. Text rewritten from the
vague "uses SSM Parameter Store, not CloudFormation Outputs" to the
explicit "uses SSM Parameter Store dynamic references
(`StringParameter.valueForStringParameter`), never `CfnOutput
exportName` or construct attributes passed across stacks. Both
create CloudFormation exports that deadlock updates."

## Lint proposal

**Implemented**: `cdk-no-cross-stack-exports.ts`. Flags:

1. **Producer side**: `Outputs.<name>.Export.Name` in any synth
   template — always high severity, always false-positive-free (if
   you have an export, you have a cross-stack binding).
2. **Consumer side**: any `Fn::ImportValue` inside `Resources`. Walks
   the resource properties tree depth-first and reports the JSON
   path of the first hit per resource so the error message pinpoints
   where.

Each finding's message links to `docs/references/cross-stack-ssm-llms.txt`
and cites principle P-10 + the EdgeSignal 2026-04-15 learning.

## Cross-project links

- VCS namespace: `harness/learnings/aws-harness`
- Related learnings:
  - `docs/learnings/INDEX.md` (M6 scaffolded)
  - VCS layered-construct pattern (SSM discovery was originally
    validated in viking-context-service)
