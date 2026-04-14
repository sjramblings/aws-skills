#!/usr/bin/env bash
# stop-learning-flush.sh
# Stop hook. If any docs/learnings/ files were added in this session,
# best-effort ingest them to VCS and refresh the principles enforcer.
#
# Always exits 0.

set -uo pipefail

input="$(cat)"
_=${input}

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo '{"continue": true}'
  exit 0
fi
repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# Find learning files modified or added in this session.
# We use git status (untracked + modified) as a proxy — the hook fires once
# per session stop, so the diff is "what's in the working tree right now".
new_learnings=$(git status --porcelain docs/learnings 2>/dev/null \
  | awk '/\?\?|A |M / {print $NF}' \
  | grep -E '\.md$' \
  | grep -v 'INDEX.md' || true)

if [[ -z "$new_learnings" ]]; then
  echo '{"continue": true}'
  exit 0
fi

count=$(echo "$new_learnings" | wc -l | tr -d ' ')

# Resolve project
project="unknown"
if [[ -f .harness-manifest.json ]]; then
  project=$(jq -r '.bootstrap.project_name // "unknown"' .harness-manifest.json)
fi

# Best-effort VCS ingest for each
ingested=0
if command -v vcs >/dev/null 2>&1; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if vcs ingest --namespace "harness/learnings/${project}" --file "$f" >/dev/null 2>&1; then
      ingested=$((ingested + 1))
    fi
  done <<<"$new_learnings"
fi

# Run the principles enforcer in the background — never block the stop hook
enforce="$repo_root/plugins/aws-harness/skills/golden-principles-enforcer/scripts/enforce.sh"
[[ ! -f "$enforce" ]] && enforce=".claude/hooks/golden-principles-enforce.sh"
if [[ -x "$enforce" ]]; then
  nohup bash "$enforce" >/dev/null 2>&1 &
fi

jq -nc \
  --argjson n "$count" \
  --argjson i "$ingested" \
  --arg project "$project" \
  '{continue: true, hookExtra: {learnings_flushed: $n, vcs_ingested: $i, project: $project}}'
exit 0
