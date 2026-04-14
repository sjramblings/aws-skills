---
name: postmortem-capture
description: >-
  Captures a structured postmortem when a deploy, test, or critical command
  fails. Use when the user says "postmortem", "five whys", "capture this
  failure", "what went wrong", or auto-invoked by the post-tool-use-capture
  hook on cdk deploy / npm test / pytest non-zero exits. Writes
  `docs/learnings/&lt;YYYY-MM-DD&gt;-&lt;slug&gt;.md` with the 5-whys schema
  (symptom, root-cause, detection-gap, fix, golden-principle-delta,
  lint-proposal). Pushes the learning to the VCS cross-project index.
  Closes the inner feedback loop of the harness — the failure becomes a
  learning that prevents recurrence on the next project.
context: fork
skills:
  - cfn-stack-events
  - cloudwatch-query
  - cloudtrail-investigator
  - vcs
allowed-tools:
  - Read
  - Write
  - Bash(git:*)
  - Bash(date:*)
  - Bash(jq:*)
  - Bash(bash:*)
---

# postmortem-capture — close the failure feedback loop

Every deploy / test failure is a teaching moment for the harness. Without a capture step, the lesson stays in the agent's head for one session and then evaporates. With one, it becomes a durable artifact that compounds across projects via the VCS cross-project index.

This skill is the *only* mechanism by which `docs/learnings/` grows. Hand-written learnings are fine, but the auto-capture path is what makes the loop reliable.

## When invoked

- Auto: by the `post-tool-use-capture.sh` hook on non-zero exit of `cdk deploy`, `npm test`, `pytest`, `cdk destroy`.
- Manual: when the user says "postmortem", "five whys", "write this up", "what went wrong".
- Required: any CFN failure surfaced via `cfn-stack-events`, any IAM finding via `cloudtrail-investigator`, any production incident.

## The schema

```markdown
---
title: <one-line title>
date: 2026-04-15
project: <project slug>
session_id: <claude code session uuid>
status: open|fixed|deferred
severity: low|med|high|critical
labels: [confused-deputy, sqs, bedrock, ...]
---

## Symptom
What was observed. One paragraph max. Should be reproducible from
this description alone.

## Root cause
The actual underlying cause. Apply 5-whys: keep asking "but why" until
you reach a system property you can change, not a person you can blame.

## Detection gap
Why didn't we catch this earlier? Was a lint missing? A skill not
invoked? An environment difference? A doc out of date?

## Fix
What changed (file paths + commit SHAs once landed). Include both the
immediate fix and any structural change.

## Golden principle delta
- New principle proposed: P-XX "..."
- OR: existing principle P-YY needs sharper wording
- OR: none — this was a one-off

## Lint proposal
A specific lint that would catch this at synth/commit time, OR the
existing lint that should be sharpened. If no lint is feasible (runtime
issue, environment issue), explain why.

## Cross-project links
- VCS namespace: harness/learnings/<project>
- Related learnings: ...
```

## Workflow

1. **Determine context.** Read environment vars: `HARNESS_PROJECT`, `CLAUDE_SESSION_ID`, `CAPTURE_SOURCE` (e.g. `cdk-deploy-failed`). If running interactively, ask the user for any missing.
2. **Pick a slug.** Lowercase, hyphen-separated, derived from the title. Example: `2026-04-15-confused-deputy-s3-content-bucket`.
3. **Gather evidence.** Read the most recent `cfn-stack-events`, `cloudwatch-query`, or `cloudtrail-investigator` output if available in `.harness-cache/`. Embed the relevant rows verbatim under the `## Symptom` section.
4. **Five-whys interview.** Ask the user (or self-prompt) the 5 whys. If any of the 5 are weak ("because the test was flaky"), keep going.
5. **Write the file.** `docs/learnings/<slug>.md` with the schema above. Front-matter complete. Each section non-empty.
6. **Update the index.** Append a row to `docs/learnings/INDEX.md`.
7. **Push to VCS.** Run `vcs ingest --namespace harness/learnings/<project> --file docs/learnings/<slug>.md` (best-effort; local file is source of truth).
8. **If `golden-principle delta` is non-empty**, run `golden-principles-enforcer` to draft the principle update.
9. **If `lint-proposal` is non-empty**, hand off to the user with a one-line description of where the lint should land.
10. **Commit the learning** as a separate commit with message `docs(learnings): capture <slug>`.

## Do not

- Do not skip the 5-whys with "we don't know yet". Defer the postmortem entirely if you genuinely don't know — `status: open` is a valid state.
- Do not write the postmortem from a single CFN error string. Always run at least one legibility skill (`cfn-stack-events` / `cloudwatch-query` / `cloudtrail-investigator`) for evidence.
- Do not blame people. Blame missing lints, missing skills, missing docs. Lopopolo: failures are signal about the *environment*, not about effort.
- Do not let the file grow unbounded. Each learning should fit on one screen. If the symptom is complex, link to a separate file under `docs/runbooks/`.
- Do not paste raw cdk output, kubernetes yaml, or 200-line stack traces into the file. Compact view only.

## Relationship to other skills

- **`cfn-stack-events` / `cloudwatch-query` / `cloudtrail-investigator`** — evidence sources. Always pull from these.
- **`golden-principles-enforcer`** — chained after this skill to propose principle deltas.
- **`vcs`** — destination for cross-project ingest.
- **`session-start-brief`** (hook) — reads recent learnings on next session start, so the loop closes.

## Learning-loop note

This IS the learning loop. The harness compounds because every failure landed via this skill becomes a future-session signal. Skipping this skill on a real failure is the single most damaging thing an agent can do to the harness's long-term value.
