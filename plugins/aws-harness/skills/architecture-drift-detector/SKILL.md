---
name: architecture-drift-detector
description: >-
  Compares the components declared in docs/ARCHITECTURE.md (mermaid diagram +
  components table) against the actual CDK construct tree from cdk synth, and
  flags divergence. Use when the user says "architecture drift", "diagram vs
  code", "is the architecture doc up to date", "drift check", or invoked daily
  by the doc-gardener workflow. Reports components present in code but missing
  from the doc, components in the doc but absent from code, and type
  mismatches. Never auto-edits the doc — always opens a flagging issue.
context: fork
allowed-tools:
  - Bash(cdk synth:*)
  - Bash(npx:*)
  - Bash(jq:*)
  - Bash(python3:*)
  - Bash(grep:*)
  - Bash(find:*)
  - Bash(bash:*)
  - Read
---

# architecture-drift-detector — docs vs code

`docs/ARCHITECTURE.md` is the system map. The moment the code drifts away from it, the doc becomes a lie — and a lying map is worse than no map. This skill catches drift early so the human can decide: update the doc, or fix the code.

## What it compares

| Source | What it looks for |
|--------|-------------------|
| `docs/ARCHITECTURE.md` mermaid block | Node IDs and labels; treated as the declared component set |
| `docs/ARCHITECTURE.md` "Components" table | Component IDs, types, and notes |
| `cdk.out/*.template.json` | Real `Resources` map: logical IDs and CFN types |

It then computes three diff sets:

1. **In code, missing from doc** — new construct added without updating ARCHITECTURE.md
2. **In doc, missing from code** — component documented but not present in synth
3. **Type mismatch** — same logical ID, different CFN type than the doc claims

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/architecture-drift-detector/scripts/detect.sh \
  [--app ./cdk] [--doc docs/ARCHITECTURE.md] [--json] [--fail-on-drift]
```

Arguments:
- `--app` — CDK app dir. Default `./cdk`.
- `--doc` — architecture doc path. Default `docs/ARCHITECTURE.md`.
- `--json` — JSON output instead of TSV.
- `--fail-on-drift` — exit non-zero if any drift is detected. Off by default (advisory).

## Output (TSV)

```
KIND              LOGICAL_ID            DOC_TYPE              CODE_TYPE           NOTE
in-code-only      ContentBucketEnc      -                     AWS::KMS::Key       new resource not in doc
in-doc-only       LegacyHandler         AWS::Lambda::Function -                   doc lists a component that no longer exists
type-mismatch     ProcessQueue          AWS::SQS::Queue       AWS::SQS::QueuePolicy doc says Queue, code says QueuePolicy (likely a doc typo)
```

## What counts as "in the doc"

The skill parses the architecture doc looking for:

1. **Mermaid nodes** — `^\s*([A-Z][A-Za-z0-9_]+)\s*\[[^\]]+\]` inside ```` ```mermaid ```` fences
2. **Component table rows** — table under a `## Components` heading, columns `ID | Component | Type | Notes`

A component is "in the doc" if it appears in either the mermaid OR the table.

## Recognized resource categories

To avoid noise, the skill only diffs major construct types:

- `AWS::Lambda::Function`
- `AWS::SQS::Queue`
- `AWS::SNS::Topic`
- `AWS::S3::Bucket`
- `AWS::DynamoDB::Table`
- `AWS::ApiGateway::RestApi` / `AWS::ApiGatewayV2::Api`
- `AWS::StepFunctions::StateMachine`
- `AWS::Events::Rule`
- `AWS::KMS::Key`

Boilerplate (IAM roles, log groups, custom resources, lambda permissions) is ignored — they're an implementation detail, not architecture.

## Do not

- Do not auto-edit `docs/ARCHITECTURE.md`. The human decides whether the doc or the code is wrong.
- Do not run during a `cdk deploy` — only against synthed templates. CDK synth is fast and side-effect-free; deploys are not.
- Do not flag every renamed logical ID as drift. CDK rename = same component, different ID. The skill currently does not track renames; it surfaces both as separate findings and lets the human merge.

## Relationship to other skills

- **`doc-gardener`** (M7) — same daily cron workflow, but doc-gardener handles hygiene while this skill handles structural drift.
- **`security-review-aws`** (M4) — operates on the same `cdk.out/*.template.json` files.
- **`postmortem-capture`** (M6) — when drift causes an incident (the doc said one thing, the code did another), capture the gap as a learning.

## Learning-loop note

A repeated drift finding for the same component is a signal: either the architecture doc needs a refactor, or the harness needs a smarter rename detector. Track recurring drift in `docs/QUALITY_SCORE.md` under "doc freshness".
