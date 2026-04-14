#!/usr/bin/env bash
# post-tool-use-capture.sh
# PostToolUse hook for Bash(cdk deploy:*), Bash(npm test:*), Bash(pytest:*),
# Bash(cdk destroy:*). On non-zero exit, queues a pending postmortem under
# .harness-cache/pending-postmortems/ for the agent to flesh out next turn.
#
# Hooks are NOT supposed to call expensive interactive workflows directly —
# this hook just records the failure context so the agent can run
# postmortem-capture in the next turn with full context.
#
# Always exits 0. Reads JSON tool result from stdin.

set -uo pipefail

input="$(cat)"

# Parse the relevant fields from the tool result envelope. Schema (from
# Claude Code hook docs): { tool_name, tool_input, tool_result, session_id, ... }
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
session_id=$(echo "$input" | jq -r '.session_id // ""')
exit_code=$(echo "$input" | jq -r '.tool_result.exit_code // .tool_result.code // 0')
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only consider failures
if [[ "$exit_code" == "0" || "$exit_code" == "null" ]]; then
  echo '{"continue": true}'
  exit 0
fi

# Only consider commands we care about
case "$command" in
  *"cdk deploy"*|*"cdk destroy"*|*"npm test"*|*"npm run test"*|*"pytest"*|*"python -m pytest"*|*"python3 -m pytest"*)
    ;;
  *)
    echo '{"continue": true}'
    exit 0
    ;;
esac

# Resolve project name + repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo '{"continue": true}'
  exit 0
fi
repo_root=$(git rev-parse --show-toplevel)
project="unknown"
if [[ -f "$repo_root/.harness-manifest.json" ]]; then
  project=$(jq -r '.bootstrap.project_name // "unknown"' "$repo_root/.harness-manifest.json")
fi

# Queue the failure for the next turn
mkdir -p "$repo_root/.harness-cache/pending-postmortems"
slug=$(date -u +%Y%m%d-%H%M%S)
queue_file="$repo_root/.harness-cache/pending-postmortems/${slug}.json"

jq -nc \
  --arg session "$session_id" \
  --arg cmd "$command" \
  --arg project "$project" \
  --argjson exit "$exit_code" \
  --arg tool "$tool_name" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    session_id: $session,
    project: $project,
    tool: $tool,
    command: $cmd,
    exit_code: $exit,
    captured_at: $ts,
    status: "pending-postmortem"
  }' > "$queue_file"

# Also try to grab the most recent cfn-stack-events / cloudwatch-query cache
# if they exist — these are the evidence the agent will use.
for evidence in cfn-stack-events.tsv cloudwatch-query.tsv cloudtrail.tsv; do
  if [[ -f "$repo_root/.harness-cache/$evidence" ]]; then
    cp "$repo_root/.harness-cache/$evidence" "$repo_root/.harness-cache/pending-postmortems/${slug}-${evidence}" 2>/dev/null || true
  fi
done

# Tell the agent there's a pending postmortem (visible in next session-start brief).
# Hooks are constrained — we use stopReason to nudge but allow continuation.
jq -nc \
  --arg q "$queue_file" \
  '{continue: true, hookExtra: {pending_postmortem: $q, hint: "Run postmortem-capture next turn — see .harness-cache/pending-postmortems/"}}'
exit 0
