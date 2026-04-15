---
name: harness-improvement-proposer
description: >-
  Takes session-log-miner JSON output, clusters friction patterns by theme,
  and drafts improvement proposals as GitHub issues against the aws-skills
  repo. Use when the user says "propose harness improvements", "harness
  upgrades", "what should we improve", "review session friction", or
  invoked weekly by `plugins/aws-harness/scripts/harness-self-review.sh`
  (a local script — runs on Steve's machine where the session logs
  live). Each proposal is an issue
  (never an auto-PR — human triage required) labeled
  `harness-self-improvement`, with the worst exemplar session IDs linked
  for reproduction.
context: fork
skills:
  - session-log-miner
allowed-tools:
  - Read
  - Bash(gh issue create:*)
  - Bash(gh api:*)
  - Bash(gh issue list:*)
  - Bash(jq:*)
  - Bash(python3:*)
  - Bash(bash:*)
---

# harness-improvement-proposer — clusters → issues

The hands of the M9 meta-loop. The miner's eyes find friction; this skill turns it into actionable GitHub issues against the harness repo. Per Lopopolo: *"identify what is missing — tools, guardrails, documentation — and feed it back into the repository, always by having Codex itself write the fix."*

**Critical:** proposals are *issues*, never *PRs*. Human triage decides whether a friction pattern is real, what the fix should be, and whether to land it. The proposer is allowed to be wrong; the human is the filter.

## When invoked

- Auto: weekly via `plugins/aws-harness/scripts/harness-self-review.sh` (local script — schedule via launchd / cron; see the Scheduling block at the bottom of the script).
- Manual: when Steve runs `propose harness improvements` or after a particularly painful session.

## Inputs

- JSON output from `session-log-miner` (passed via stdin or `--input <file>`)
- Optional `--repo owner/name` — defaults to `sjramblings/aws-skills`

## Proposal types

For each friction pattern from the miner, the proposer decides which type of fix to propose:

| Friction type | Proposed fix type |
|---|---|
| `raw-aws-blob-read` | **skill-upgrade**: tighten the existing legibility skill description so the agent picks it up; OR **new-skill** if no wrapper exists |
| `repeated-tool-failure` | **new-lint** (if the failure is structural) OR **skill-upgrade** (if the wrapper is wrong abstraction) |
| `aborted-tool-call` | **new-reference-doc** explaining why the action was needed; OR **hook-change** narrowing the matcher |
| `long-stuck-turn` | **new-reference-doc** giving the agent grounding for the recurring stuck pattern |
| `missing-access` | **new-skill** OR **hook-change** widening allowed-tools |
| `agents-md-miss` | **new-reference-doc** added under `docs/references/`; AGENTS.md updated to link it |

## Workflow

1. **Load miner output.** From stdin or `--input`. Validate schema.
2. **For each pattern**, decide:
   - **Skip** if frequency below `--min-frequency` (default 3)
   - **Skip** if a `harness-self-improvement` issue already exists with the same fingerprint (dedupe by title)
3. **Generate proposal markdown** per pattern with:
   - Pattern type + frequency + projects affected
   - Top 3 exemplar session IDs (local hashes only)
   - Recommended fix type + concrete suggestion (e.g. "tighten cloudwatch-query SKILL.md description triggers")
   - Acceptance criteria (how to know the fix worked: same pattern absent from next week's mine)
4. **Open the issue** via `gh issue create --label harness-self-improvement --label source:session-logs`. Title format: `[harness-self-improvement] <pattern-type>: <fingerprint>`.
5. **Track in `.harness-cache/proposals-history.json`** so the next run can compare and report regressions.

## Usage

```bash
# Pipe miner output
bash plugins/aws-harness/skills/session-log-miner/scripts/mine.sh --days 7 \
  | bash plugins/aws-harness/skills/harness-improvement-proposer/scripts/propose.sh \
      --repo sjramblings/aws-skills [--dry-run] [--min-frequency 3]

# Or feed a saved file
bash plugins/aws-harness/skills/harness-improvement-proposer/scripts/propose.sh \
  --input miner-output.json --dry-run
```

Arguments:
- `--input <path>` — read miner JSON from file. Default: stdin.
- `--repo owner/name` — target repo for issues. Default: `sjramblings/aws-skills`.
- `--dry-run` — print proposal markdown but do not open issues.
- `--min-frequency N` — minimum frequency to consider. Default 3.
- `--max-issues N` — safety cap on issues opened per run. Default 5.

## Issue body schema

```markdown
## Friction pattern detected

- **Type**: `raw-aws-blob-read`
- **Frequency**: 8 occurrences across 4 sessions
- **Projects affected**: harness-pilot-hello, viking-context-service
- **Last seen**: 2026-04-15T08:42:00Z
- **Fingerprint**: `aws logs filter-log-events instead of cloudwatch-query`

## Exemplar sessions (local hashes)

- abc123def456
- f00ba12345
- 9988aabbccdd

## Proposed fix

**Type**: `skill-upgrade`

The `cloudwatch-query` skill (M1, `plugins/aws-harness/skills/cloudwatch-query/SKILL.md`) exists but is being bypassed. Likely cause: the `description` field doesn't trigger on the natural-language phrases the agent is using. Tighten the description to explicitly include "filter log events", "search logs", "find errors in logs".

## Acceptance criteria

- This pattern has frequency 0 in next week's `session-log-miner` run
- OR the pattern's frequency drops by ≥50%
```

## Privacy boundary

- Issue bodies contain only: pattern type, frequency, fingerprints (one-line summaries of the *type* of API call, not the actual command), local session hashes, project slugs.
- **Never** contains: prompts, user messages, code snippets, file contents, or any other transcript content.
- The local session ID is a SHA1 hash of the file path — Steve can resolve it locally; nobody else can.

## Do not

- Do not auto-open PRs. Issues only. Human decides the fix.
- Do not skip dedup. Re-opening the same issue weekly is noise.
- Do not propose fixes for patterns with `frequency < min-frequency` (default 3 sessions over 2+ days).
- Do not include raw transcript content in issue bodies. Pattern fingerprints only.
- Do not run this on a machine that doesn't own the session logs being mined.

## Relationship to other skills

- **`session-log-miner`** (M9) — produces this skill's input.
- **`golden-principles-enforcer`** (M6) — different layer. Enforcer runs at the project level and proposes principles from project failures. Proposer runs at the harness level and proposes harness changes from agent friction.
- **`postmortem-capture`** (M6) — different axis. Postmortem captures *deploy* failures. Proposer captures *agent* friction from the inverse: the agent struggled, what was missing.

## Graduation signal

The harness has fully closed the meta-loop when at least one `harness-self-improvement` issue has been authored, merged into a fix, and the next week's mine shows the same pattern dropped from the output. Track that count in `plugins/aws-harness/docs/QUALITY_SCORE.md`.
