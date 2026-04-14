---
name: cloudwatch-query
description: >-
  Compact CloudWatch Logs Insights wrapper with a LogQL-style mini-DSL for
  agent-legible log searches. Use when the user asks "check the logs", "logs
  insights", "error logs", "metric query", "why did the lambda fail",
  "what's in the logs", or when a post-deploy smoke test, Lambda invocation,
  or integration test needs log triage. Returns top-N grouped errors
  (deduplicated by fingerprint), not raw log lines. Prevents agents from
  pasting raw CloudWatch output into context.
context: fork
allowed-tools:
  - Bash(aws logs start-query:*)
  - Bash(aws logs get-query-results:*)
  - Bash(aws logs describe-log-groups:*)
  - Bash(aws logs describe-log-streams:*)
  - Bash(jq:*)
  - Bash(bash:*)
  - Bash(sleep 1)
  - Bash(sleep 2)
  - Bash(sleep 3)
---

# cloudwatch-query — compact log & metric queries

CloudWatch Logs Insights returns raw log events. For an agent, that's a firehose: thousands of lines, most duplicates, most noise. This skill wraps Insights with a small DSL and collapses results into a grouped error report.

## The mini-DSL

```
<log-group-or-alias> [key=value ...] [last=<duration>] [limit=N] [group_by=<field>]
```

Keys:
- `level=<LEVEL>` — ERROR, WARN, INFO. Case-insensitive. Mapped to `@message like /LEVEL/` filter.
- `contains=<substring>` — free-text match. Quote multi-word values: `contains="out of memory"`.
- `status=<code>` — matches HTTP status in message (e.g. `status=5xx`, `status=500`).
- `function=<name>` — shortcut: resolves to `/aws/lambda/<name>` log group.
- `request_id=<id>` — filter by Lambda request ID.
- `last=<N><unit>` — time window: `5m`, `15m`, `1h`, `6h`, `1d`. Default `15m`.
- `limit=N` — max events scanned. Default 1000, cap 10000.
- `group_by=<field>` — group output by field. Default: fingerprint (first 120 chars of message after stripping IDs/timestamps).

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/cloudwatch-query/scripts/query.sh \
  "function=my-service-handler level=ERROR last=30m"
```

or explicit log group:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/cloudwatch-query/scripts/query.sh \
  "/aws/lambda/my-service-handler level=ERROR contains=timeout last=1h"
```

## Output format

A compact TSV table, one row per error fingerprint:

```
COUNT  FIRST_SEEN           LAST_SEEN            SAMPLE_MESSAGE
 142   2026-04-14T09:12:33Z 2026-04-14T09:47:11Z Task timed out after 15.00 seconds
  23   2026-04-14T09:22:01Z 2026-04-14T09:45:09Z AccessDeniedException: User ... not authorized to s3:GetObject
   5   2026-04-14T09:31:17Z 2026-04-14T09:31:18Z OutOfMemoryError: Java heap space
```

- Sorted by `COUNT` descending.
- `SAMPLE_MESSAGE` is truncated to 200 chars; request IDs and UUIDs are stripped so duplicates fingerprint together.
- Top 20 groups by default.

## When to use

- After a `cdk deploy` where the Lambda crashed during CREATE (CFN says "resource failed", Insights tells you the Node/Python stack trace).
- When an integration test fails with a 5xx from your API — query the handler log group.
- When a canary/smoke test misbehaves — query the relevant log group before reading diffs.
- When the user says "check the logs", "why is it slow", "any errors lately".

## Do not

- Do not call `aws logs filter-log-events` or `aws logs start-query` directly. Always go through `query.sh` — the skill's whole purpose is to prevent raw log firehose from landing in context.
- Do not default to `last=24h`. Start narrow (`15m` or `1h`). Widen only if empty.
- Do not set `limit=10000` unless you've already tried with the default and got nothing.

## Relationship to other skills

- **`cfn-stack-events`** — start there for deploy failures. If CFN says "resource failed" with no reason, pivot here with the failed resource's log group.
- **`cloudtrail-investigator`** — use that for IAM / who-called-what questions. CloudWatch is for application logs; CloudTrail is for API calls.
- **`post-deploy-verify`** (M5) — the canary harness calls this skill automatically when a smoke test fails.

## Learning-loop note

If a query surfaces a recurring error fingerprint (COUNT > 10 over a short window), that's a signal. Feed it into `postmortem-capture` (M6) so it becomes a learning + potentially a new alarm in `docs/RELIABILITY.md`.
