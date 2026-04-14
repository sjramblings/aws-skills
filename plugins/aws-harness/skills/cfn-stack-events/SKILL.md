---
name: cfn-stack-events
description: >-
  Compact, agent-legible view of CloudFormation stack events. Use when the user
  asks "why did my deploy fail", "stack failed", "cfn events", "rollback
  reason", "what broke in the deploy", or when a `cdk deploy` / `aws
  cloudformation deploy` command exits non-zero and you need to know which
  resource failed and why. Returns a compact table of failed events —
  timestamp, logical ID, resource type, status, and reason — instead of the
  raw firehose from `aws cloudformation describe-stack-events`.
context: fork
allowed-tools:
  - Bash(aws cloudformation describe-stack-events:*)
  - Bash(aws cloudformation list-stacks:*)
  - Bash(aws cloudformation describe-stacks:*)
  - Bash(jq:*)
  - Bash(bash:*)
---

# cfn-stack-events — compact CloudFormation failure view

The raw `describe-stack-events` API returns every event for a stack: CREATE_IN_PROGRESS, UPDATE_IN_PROGRESS, CREATE_COMPLETE, etc. For a stuck or failed deploy, 90%+ of those are noise. This skill returns only the events that matter: the ones with a `*_FAILED` status or a non-empty `ResourceStatusReason`, collapsed to the minimum fields an agent needs to diagnose.

## When to use

- A `cdk deploy` / `aws cloudformation deploy` just exited non-zero.
- The user says "deploy failed", "cfn events", "why is my stack stuck", "rollback reason", "what broke".
- You're about to paste raw CloudFormation event JSON into context — stop and use this skill instead.

## Do not

- Do not call `aws cloudformation describe-stack-events` directly. Always go through the wrapper script. This is the harness legibility rule: raw AWS API blobs are banned from agent context.
- Do not guess stack names. If the user hasn't given you one, list stacks first (`aws cloudformation list-stacks --stack-status-filter CREATE_FAILED UPDATE_FAILED ROLLBACK_IN_PROGRESS ROLLBACK_COMPLETE UPDATE_ROLLBACK_FAILED CREATE_COMPLETE UPDATE_COMPLETE` filtered to recent) or ask.

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/cfn-stack-events/scripts/fetch.sh <stack-name> [--limit N] [--region REGION] [--since DURATION]
```

Arguments:
- `<stack-name>` — required. The CloudFormation stack name.
- `--limit N` — max events to return. Default 20. Hard cap 50.
- `--region REGION` — AWS region. Defaults to `AWS_REGION` env or your CLI default.
- `--since DURATION` — only events newer than `<N>m|h|d`. Default `2h`.

## Output format

A compact TSV table with exactly these columns:

```
TIMESTAMP            LOGICAL_ID              TYPE                        STATUS             REASON
2026-04-14T09:12:33Z MyFunctionRole          AWS::IAM::Role              CREATE_FAILED      API: iam:CreateRole User: ... is not authorized...
2026-04-14T09:12:45Z MyStack                 AWS::CloudFormation::Stack  ROLLBACK_IN_PROGRESS The following resource(s) failed to create: [MyFunctionRole]
```

- Reason text is truncated at 240 characters. The full reason is available via `--full` if you explicitly need it.
- Rows are sorted newest-first.
- Only events with `*_FAILED` status or a non-empty `ResourceStatusReason` are included.

## Interpreting results

1. **Find the first FAILED row from the bottom of the cascade.** CloudFormation rolls back forward — the oldest `*_FAILED` row is usually the root cause; everything after is cleanup.
2. **The `REASON` field is the agent's primary signal.** Read it literally. Most CloudFormation errors are self-describing ("is not authorized", "already exists", "invalid parameter", "quota exceeded").
3. **If the reason mentions a policy / principal / condition**, cross-reference with `docs/references/confused-deputy-llms.txt` and the confused-deputy lint (M4).
4. **If the reason mentions a quota or throttle**, escalate to the user — quota increases are out of the agent's autonomous scope.
5. **If the reason is empty or says "internal failure"**, pivot to `cloudtrail-investigator` to see what the service principal actually tried to do.

## Common patterns

| Reason snippet | Likely cause | Next step |
|---|---|---|
| `is not authorized to perform: <action>` | IAM gap | Check `security-review-aws` output; add the missing action or role mapping |
| `already exists` | Duplicate logical or physical ID | Rename or import; check `cdk.json` context |
| `Embedded stack ... was not successfully created` | Nested stack failure | Re-run with the child stack name |
| `The maximum number of ... has been reached` | Service quota | Ask user; do not auto-retry |
| `Resource creation cancelled` | Upstream resource failed; this row is collateral | Find the real failure above |
| `UPDATE_ROLLBACK_FAILED` | Broken state — stack needs manual intervention | Escalate; do not re-deploy |

## Relationship to other skills

- **`cloudtrail-investigator`** — call this when `cfn-stack-events` returns an empty reason or a vague "internal failure". CloudTrail shows the actual API call the service tried.
- **`cloudwatch-query`** — call this when a Lambda or ECS task inside the stack crashed during CREATE. CFN event will say "resource creation failed"; CloudWatch logs will say _why_.
- **`postmortem-capture`** (M6) — auto-invoked by hook when a deploy fails. It will call this skill under the hood.

## Learning-loop note

Every non-trivial failure you diagnose with this skill should end in a `docs/learnings/<date>-<slug>.md` entry via the `postmortem-capture` skill (M6). The whole point of the harness is that the same CFN failure never bites twice.
