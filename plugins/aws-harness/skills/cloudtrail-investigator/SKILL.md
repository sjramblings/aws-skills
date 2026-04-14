---
name: cloudtrail-investigator
description: >-
  Compact CloudTrail event lookup for agent-legible audit and IAM debugging.
  Use when the user asks "who called", "cloudtrail", "audit event", "who
  deleted", "what API was called", "why did permission fail", or when you're
  diagnosing IAM access-denied errors, confused-deputy vulnerabilities,
  unexpected resource changes, or cross-account activity. Returns a compact
  timeline — timestamp, principal, event source, event name, error code,
  error message — instead of the raw CloudTrail event JSON.
context: fork
allowed-tools:
  - Bash(aws cloudtrail lookup-events:*)
  - Bash(jq:*)
  - Bash(bash:*)
---

# cloudtrail-investigator — compact audit trail view

Raw CloudTrail events are enormous nested JSON blobs with fields the agent doesn't need. This skill returns only the signals that matter for debugging access denials, tracking who changed what, and catching confused-deputy attempts: `timestamp, principal, event_source, event_name, error_code, error_message, source_ip, resources`.

## When to use

- `cdk deploy` or an API call failed with `AccessDenied` / `UnauthorizedOperation` — use this to see exactly which API call the principal tried.
- Diagnosing a confused-deputy defect — filter by event source + resource ARN to see which account was the caller.
- "Who deleted the bucket?" / "Who rotated the key?" / "Who touched prod?" investigations.
- Verifying an OIDC role is actually being assumed from GitHub Actions (not manually).
- After `cfn-stack-events` returns an empty `ResourceStatusReason`, pivot here to see the underlying API call.

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/cloudtrail-investigator/scripts/investigate.sh \
  [--user NAME] [--role NAME] [--service SRC] [--event NAME] \
  [--error CODE] [--resource ARN] [--since <N>m|h|d] [--region REGION] \
  [--limit N]
```

Flags (all optional, at least one required):

- `--user <name>` — filter by IAM user name (matches `userIdentity.userName`).
- `--role <name>` — filter by assumed-role name (matches any part of `userIdentity.arn` containing the role).
- `--service <src>` — filter by event source like `s3.amazonaws.com`, `bedrock.amazonaws.com`.
- `--event <name>` — filter by event name like `PutObject`, `InvokeModel`, `AssumeRoleWithWebIdentity`.
- `--error <code>` — filter by error code. Common values: `AccessDenied`, `UnauthorizedOperation`, `ThrottlingException`.
- `--resource <arn>` — filter events that reference this resource ARN.
- `--since <duration>` — window, e.g. `30m`, `2h`, `1d`. Default `1h`. Max `7d` (CloudTrail lookup-events window limit).
- `--region <region>` — defaults to `AWS_REGION`.
- `--limit N` — max rows. Default 30, cap 100.

## Output format

Compact TSV:

```
TIMESTAMP            PRINCIPAL                   EVENT_SOURCE           EVENT_NAME           ERROR              MESSAGE
2026-04-14T09:14:02Z arn:aws:sts::123:assumed-role/gha-deploy/i-xyz  s3.amazonaws.com  PutObject  AccessDenied  User: ... is not authorized...
2026-04-14T09:13:55Z arn:aws:sts::456:assumed-role/agentcore-runtime  bedrock-agentcore.amazonaws.com PutContent  -  -
```

Rows sorted newest-first. `MESSAGE` truncated at 200 chars. Use `--full` to see the raw JSON for one specific event.

## Do not

- Do not call `aws cloudtrail lookup-events` directly. Always go through `investigate.sh` — harness legibility rule: raw AWS API blobs banned from agent context.
- Do not query without at least one filter flag. An unfiltered 1-hour lookup will return thousands of events.
- Do not ask CloudTrail for windows > 7 days via `lookup-events` — the API doesn't support it. For longer windows, use Athena on CloudTrail S3 export (not in scope for M1).

## Interpreting results

1. **`ERROR` column is primary.** `AccessDenied`, `UnauthorizedOperation`, `InvalidSignatureException` tell you the exact failure type.
2. **`PRINCIPAL` reveals the caller.** For IAM users it's `arn:aws:iam::<acct>:user/<name>`. For assumed roles it's `arn:aws:sts::<acct>:assumed-role/<role>/<session>`. The account number tells you cross-account attempts — central to confused-deputy detection.
3. **`EVENT_SOURCE` is the target service** the principal tried to call, and `EVENT_NAME` is the specific API.
4. Cross-reference the `PRINCIPAL` account with your own — if they differ and there's no source-account condition on the resource policy, that's a confused-deputy finding. File it to `postmortem-capture`.

## Common investigation patterns

| Symptom | Flags to use |
|---|---|
| `cdk deploy` getting AccessDenied | `--role <your-deploy-role> --error AccessDenied --since 30m` |
| Lambda runtime permission error | `--role <lambda-role> --error AccessDenied --since 1h` |
| "Who deleted X?" | `--event DeleteObject --resource <arn> --since 1d` |
| Confused deputy suspicion on S3 bucket | `--service s3.amazonaws.com --resource <bucket-arn> --since 6h` then inspect `PRINCIPAL` accounts |
| Bedrock model invocation failure | `--service bedrock.amazonaws.com --event InvokeModel --error AccessDenied --since 30m` |

## Relationship to other skills

- **`cfn-stack-events`** — start there for deploy failures. Pivot here when the CFN reason is empty or vague.
- **`cloudwatch-query`** — for application logs (what the code did). Use CloudTrail for API-level activity (what AWS saw).
- **`security-review-aws`** (M4) — the static scanner. Use it proactively; use this skill reactively during incidents.

## Learning-loop note

Every confused-deputy, cross-account, or unexpected-principal finding from this skill is a must-capture learning. Feed it into `postmortem-capture` (M6) so `golden-principles.md` gets updated and the corresponding lint (e.g. `cdk-confused-deputy.ts` in M4) starts catching it at synth time.
