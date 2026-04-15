---
name: session-log-miner
description: >-
  Mines Claude Code session transcripts (`~/.claude/projects/*/*.jsonl`)
  for friction patterns. Use when the user says "mine session logs",
  "session friction", "harness telemetry", "what's the agent struggling
  with", or invoked weekly by `plugins/aws-harness/scripts/harness-self-review.sh`
  (a local script — see Scheduling below). Extracts six
  friction event classes (repeated tool failures, aborted tool calls,
  long stuck turns, missing-access patterns, raw AWS blob reads,
  AGENTS.md lookup misses) and emits compact JSON for the
  harness-improvement-proposer to cluster.
context: fork
allowed-tools:
  - Read
  - Bash(find:*)
  - Bash(jq:*)
  - Bash(python3:*)
  - Bash(bun:*)
  - Bash(node:*)
  - Bash(bash:*)
---

# session-log-miner — extract friction from Claude Code transcripts

This is the first half of M9, the meta-feedback loop. The harness's inner loop (M6) captures *deploy/test* failures. This loop captures *agent* friction — moments where the agent struggled, retried, hit a missing capability, or fell back to raw AWS blobs. Each one is a signal that the harness has a missing or under-used skill.

Per Lopopolo: "When the agent struggles, treat it as a signal: identify what is missing — tools, guardrails, documentation — and feed it back into the repository."

## Source data

`~/.claude/projects/<project-slug>/*.jsonl` — one JSONL file per session, each line a structured event (user message, assistant message, tool use, tool result). The miner reads only Steve's local files; nothing is shipped off-machine. Pattern extraction returns structured friction records + session IDs (no raw transcript content).

## What it extracts

| Pattern | Detection rule | Friction signal |
|---|---|---|
| `repeated-tool-failure` | Same tool name + same error code, ≥3 retries within 10 turns | Tool is fragile or wrong abstraction |
| `aborted-tool-call` | User rejected a tool call, then session continued without success | Permission too coarse; user didn't trust the action |
| `long-stuck-turn` | Assistant turn with no tool call, >2000 tokens, followed by retry | Agent stuck reasoning without grounding |
| `missing-access` | Assistant message contains "I don't have access to" / "I cannot" / "I'm unable to" | Capability gap |
| `raw-aws-blob-read` | Bash tool with `aws cloudformation describe-stack-events`, `aws logs filter-log-events`, `aws cloudtrail lookup-events` directly (NOT through the harness skill wrapper) | Legibility skill under-used |
| `agents-md-miss` | Read tool on `AGENTS.md` followed within 2 turns by Read on a doc not linked from AGENTS.md | Map missing a useful pointer |

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/session-log-miner/scripts/mine.sh \
  [--days 7] [--projects all|harness-pilot,viking-context-service] \
  [--output json|tsv] [--threshold 3]
```

Arguments:
- `--days N` — rolling window. Default 7.
- `--projects` — comma-separated list of project slugs to scan, or `all`. Default `all`.
- `--output` — `json` (default, for the proposer) or `tsv` (human-readable).
- `--threshold N` — minimum occurrence count across distinct sessions before a pattern is reported. Default 3 (avoid one-off noise).

## Output (JSON)

```json
{
  "scanned_at": "2026-04-15T09:00:00Z",
  "window_days": 7,
  "projects": ["harness-pilot-hello", "viking-context-service"],
  "sessions_scanned": 142,
  "patterns": [
    {
      "type": "raw-aws-blob-read",
      "frequency": 7,
      "sessions": ["abc123...", "def456...", "..."],
      "fingerprint": "aws logs filter-log-events instead of cloudwatch-query",
      "last_seen": "2026-04-15T08:42:00Z",
      "projects_affected": ["harness-pilot-hello", "viking-context-service"]
    }
  ]
}
```

## Privacy boundary

- Reads only files under `~/.claude/projects/` that Steve owns.
- Never ships raw transcript content off-machine.
- Output contains: pattern fingerprints, frequency counts, session IDs (UUID hashes — local-only references), affected project slugs.
- Never includes message content, prompts, or code snippets from the transcripts.

## Do not

- Do not write to `~/.claude/projects/`. Read-only.
- Do not run with `--threshold 1` in cron — single occurrences are noise. Use the default 3.
- Do not pipe raw JSONL into agent context. The output IS the compact view.
- Do not invoke this skill in a customer/end-user project — it's for the harness maintainer (Steve) only.

## Relationship to other skills

- **`harness-improvement-proposer`** (M9) — consumes this skill's JSON output and clusters into GitHub issues.
- **`postmortem-capture`** (M6) — different axis. Postmortem captures *deploy* failures; miner captures *agent* friction.
- **`golden-principles-enforcer`** (M6) — runs at the project level. The miner runs across projects via the harness self-review workflow.

## Learning-loop note

This skill is the eyes of the meta-loop. The proposer is the hands. Together they let the harness improve itself from its own usage telemetry — exactly the compounding investment Lopopolo identified.
