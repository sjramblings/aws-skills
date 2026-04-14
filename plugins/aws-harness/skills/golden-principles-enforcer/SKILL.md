---
name: golden-principles-enforcer
description: >-
  Reads docs/golden-principles.md, diffs against recent learnings under
  docs/learnings/, and proposes principle additions or sharpening. Use when
  the user says "golden principles", "principle check", "review principles",
  "what should we add to principles", or invoked as a daily cron via the
  golden-principles-check workflow. Also flags any enforced principle whose
  Backing column references a missing lint file. Closes the inner half of
  the harness feedback loop.
context: fork
allowed-tools:
  - Read
  - Write
  - Bash(jq:*)
  - Bash(python3:*)
  - Bash(grep:*)
  - Bash(find:*)
  - Bash(bash:*)
---

# golden-principles-enforcer — propose, sharpen, audit

`docs/golden-principles.md` is the living canon — but it only earns its keep when:

1. New learnings get promoted to principles
2. Existing principles have backing lints (or are explicitly advisory)
3. Stale or contradictory principles get retired

This skill does the diff-and-propose work. It does NOT auto-merge — every change to `golden-principles.md` is a human-reviewed PR.

## When invoked

- Auto: daily via `golden-principles-check.yml` workflow (cron).
- Auto: by `postmortem-capture` immediately after a learning is written, when the learning's `golden principle delta` field is non-empty.
- Manual: when the user says "principle check", "review principles", "what's missing from principles".

## Workflow

1. **Load the canon.** Parse `docs/golden-principles.md` table rows (P-XX | Principle | Backing | Source learning | Advisory?).
2. **Load recent learnings.** Read every file under `docs/learnings/<date>-<slug>.md` from the last 30 days. Extract the front-matter and the `## Golden principle delta` section.
3. **Diff.** For each learning that proposes a new principle:
   - Check if a similar principle already exists (fuzzy match on the principle text + labels).
   - If new: draft a row to add.
   - If similar: draft a sharpened wording diff against the existing row.
4. **Backing audit.** For each `Advisory? = no` row, verify the Backing cell references either:
   - An existing file under `tools/lints/` (any extension)
   - An existing workflow under `.github/workflows/`
   - A skill name from the harness skills directory
   - A construct/hook reference (free text but must include the word "construct" or "hook")
5. **Stale audit.** Flag any principle that hasn't been referenced by a learning in the last 90 days AND has zero backing lint hits in the last lint run (best-effort — only checked if `.harness-cache/lint-history.json` exists).
6. **Emit a proposal.** Write `.harness-cache/principle-proposals.md` with three sections:
   - **Add:** new rows to add to `golden-principles.md`
   - **Sharpen:** existing rows to update (with a unified diff)
   - **Audit issues:** missing backing files or stale principles
7. **Optional auto-PR.** If `--open-pr` is passed and there's at least one Add or Sharpen, open a draft PR with the proposal. Title: `chore(principles): propose updates from learnings`.

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/golden-principles-enforcer/scripts/enforce.sh \
  [--learnings-dir docs/learnings] \
  [--principles docs/golden-principles.md] \
  [--since-days 30] \
  [--open-pr] \
  [--json]
```

Arguments:
- `--learnings-dir` — default `docs/learnings`
- `--principles` — default `docs/golden-principles.md`
- `--since-days` — only look at learnings newer than this. Default 30.
- `--open-pr` — open a draft PR with the proposal markdown.
- `--json` — emit a JSON proposal instead of markdown.

## Output (markdown mode)

```markdown
# Principle proposals — 2026-04-15

## Add (3)

- **P-16** Lambda timeout must be < SQS visibility timeout / 6.
  - Source: docs/learnings/2026-04-12-sqs-timeout-storm.md
  - Backing proposal: tools/lints/cdk-sqs-visibility-timeout.ts (already exists; sharpen severity to critical)

- **P-17** ...

## Sharpen (1)

- **P-05** SQS visibility timeout must be ≥ 6 × Lambda timeout
  - Diff:
    - "Set to >= 60s." → "Set to >= 6 × consumer Lambda timeout. Lint enforces."

## Audit issues (2)

- P-08 references `tools/lints/bedrock-cost-instrumentation.ts` — file exists ✓
- P-XX references `tools/lints/missing-lint.ts` — FILE NOT FOUND
- P-13 not referenced by any learning in 90+ days — review for staleness
```

## Do not

- Do not edit `docs/golden-principles.md` directly. Always go through a reviewable PR. Human taste is what golden principles encode — auto-merge would defeat the point.
- Do not propose principles based on a single one-off failure. Wait for at least 2 learnings with the same `lint-proposal` field before promoting to a principle.
- Do not delete principles silently. If a principle is stale, propose a `Sharpen` that marks it `Advisory? = yes` first; only delete after a 30-day soak.
- Do not chase 100% lint coverage. Some principles are inherently runtime / cultural and stay advisory forever — that's fine.

## Relationship to other skills

- **`postmortem-capture`** (M6) — invokes this skill immediately after writing a learning with a non-empty principle delta.
- **`doc-gardener`** (M7) — uses this skill's audit output to open the principle-update PRs as part of doc gardening.
- **`vcs`** — when this skill detects two learnings from different projects proposing similar principles, it surfaces a "cross-project principle" candidate worth higher confidence.

## Learning-loop note

This is the second half of the inner feedback loop:
```
deploy fails -> postmortem-capture -> docs/learnings/<slug>.md
                                    -> golden-principles-enforcer
                                    -> draft PR updating principles
                                    -> human review -> merge
                                    -> M4 lints catch future recurrence
```
Without this skill the learnings pile up but the canon never grows.
