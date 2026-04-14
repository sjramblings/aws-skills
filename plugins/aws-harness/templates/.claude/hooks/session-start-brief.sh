#!/usr/bin/env bash
# session-start-brief.sh
# SessionStart hook. Injects ~20 lines of context the agent needs to be
# situationally aware: pending postmortems, recent learnings, active
# exec-plans, and (if VCS available) cross-project lessons matching the
# current branch name.
#
# Output format: a JSON envelope with `additionalContext` containing the
# brief markdown. The agent sees this as part of its initial context.
#
# Always exits 0.

set -uo pipefail

# Consume stdin (hook protocol)
input="$(cat)"
_=${input}

# Skip if not in a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo '{"continue": true}'
  exit 0
fi
repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# Resolve project info
project="unknown"
if [[ -f .harness-manifest.json ]]; then
  project=$(jq -r '.bootstrap.project_name // "unknown"' .harness-manifest.json)
fi
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")

# 1. Pending postmortems
pending_dir=".harness-cache/pending-postmortems"
pending_count=0
pending_list=""
if [[ -d "$pending_dir" ]]; then
  pending_count=$(find "$pending_dir" -name '*.json' | wc -l | tr -d ' ')
  pending_list=$(find "$pending_dir" -name '*.json' -exec basename {} .json \; | head -3)
fi

# 2. Recent learnings (last 5)
recent_learnings=""
if [[ -d docs/learnings ]]; then
  recent_learnings=$(find docs/learnings -name '*.md' ! -name 'INDEX.md' -type f \
    -exec ls -t {} + 2>/dev/null | head -5 \
    | while read f; do
        title=$(grep -m1 '^title:' "$f" 2>/dev/null | sed 's/title: *//')
        date=$(grep -m1 '^date:' "$f" 2>/dev/null | sed 's/date: *//')
        echo "  - ${date}: ${title:-$(basename "$f")}"
      done)
fi

# 3. Active exec-plans
active_plans=""
if [[ -d docs/exec-plans/active ]]; then
  active_plans=$(find docs/exec-plans/active -name '*.md' -type f 2>/dev/null \
    | while read f; do
        echo "  - $(basename "$f" .md)"
      done | head -5)
fi

# 4. Cross-project lessons (best-effort VCS query)
cross_project=""
if command -v vcs >/dev/null 2>&1; then
  query=$(echo "$branch" | tr '/-_' ' ' | tr '[:upper:]' '[:lower:]')
  cross_project=$(vcs find --namespace "harness/learnings" --query "$query" --limit 3 2>/dev/null | head -3 || true)
fi

# Build the brief
brief=$(cat <<EOF
## Harness session brief — ${project} @ ${branch}

EOF
)

if [[ "$pending_count" != "0" && "$pending_count" != "" ]]; then
  brief+=$'\n'"### ⚠ Pending postmortems: ${pending_count}"$'\n'
  brief+="$(echo "$pending_list" | sed 's/^/  - /')"$'\n'
  brief+=$'\n'"_Run \`postmortem-capture\` to flesh these out before starting new work._"$'\n'
fi

if [[ -n "$recent_learnings" ]]; then
  brief+=$'\n'"### Recent learnings"$'\n'"$recent_learnings"$'\n'
fi

if [[ -n "$active_plans" ]]; then
  brief+=$'\n'"### Active exec-plans"$'\n'"$active_plans"$'\n'
fi

if [[ -n "$cross_project" ]]; then
  brief+=$'\n'"### Cross-project lessons matching '${branch}'"$'\n'"$cross_project"$'\n'
fi

brief+=$'\n'"---"$'\n'"_Brief from session-start-brief.sh; full canon in docs/golden-principles.md._"

# Output via JSON envelope
jq -nc --arg ctx "$brief" '{continue: true, additionalContext: $ctx}'
exit 0
