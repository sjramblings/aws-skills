#!/usr/bin/env bash
# pre-commit-red-test-block.sh
# PreToolUse hook for Bash(git commit:*). Blocks commits when:
#  1. The fast test suite is currently red, OR
#  2. Any test is marked @known-red older than 7 days (see red-test policy)
#
# Hook input/output protocol: reads JSON from stdin, writes JSON to stdout.
# Returning {"continue": false, "stopReason": "..."} blocks the tool call.
# Always exits 0 — the harness convention is "never crash the harness".
#
# Enforces golden principle P-12 (red test policy).
# Reference: docs/references/red-test-policy.md

set -uo pipefail

# Parse the hook input — we don't actually need it, but we must consume stdin
# so the hook channel doesn't block.
input="$(cat)"
_=${input}  # silence unused

# Skip when not in a git repo (e.g. inside the plugin templates themselves).
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo '{"continue": true}'
  exit 0
fi

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# Determine fast test command from package.json / pyproject.toml.
test_cmd=""
if [[ -f package.json ]]; then
  if jq -e '.scripts["test:fast"]' package.json >/dev/null 2>&1; then
    test_cmd="npm run test:fast --silent"
  elif jq -e '.scripts["test:unit"]' package.json >/dev/null 2>&1; then
    test_cmd="npm run test:unit --silent"
  elif jq -e '.scripts.test' package.json >/dev/null 2>&1; then
    test_cmd="npm test --silent -- --reporter=dot --run"
  fi
elif [[ -f pyproject.toml || -f pytest.ini || -f setup.cfg ]]; then
  test_cmd="python3 -m pytest -q -m 'not integration and not slow'"
fi

if [[ -z "$test_cmd" ]]; then
  # No test runner detected — let the commit through.
  echo '{"continue": true}'
  exit 0
fi

# 1. Check stale @known-red markers
stale_red=""
if command -v grep >/dev/null 2>&1; then
  # Look for "@known-red <YYYY-MM-DD>" markers older than 7 days
  today_epoch=$(date -u +%s)
  while IFS=: read -r file line; do
    [[ -z "$file" ]] && continue
    marker_date=$(echo "$line" | grep -oE '@known-red\s+[0-9]{4}-[0-9]{2}-[0-9]{2}' | awk '{print $2}')
    [[ -z "$marker_date" ]] && continue
    if marker_epoch=$(date -u -d "$marker_date" +%s 2>/dev/null || date -u -jf "%Y-%m-%d" "$marker_date" +%s 2>/dev/null); then
      age_days=$(( (today_epoch - marker_epoch) / 86400 ))
      if (( age_days > 7 )); then
        stale_red+="${file} (${age_days}d): ${line}\n"
      fi
    fi
  done < <(grep -rEn '@known-red\s+[0-9]{4}-[0-9]{2}-[0-9]{2}' --include='*.ts' --include='*.tsx' --include='*.js' --include='*.py' . 2>/dev/null || true)
fi

if [[ -n "$stale_red" ]]; then
  reason="Pre-commit blocked: stale @known-red marker(s) >7 days old (golden principle P-12). Either fix the test or remove the marker. See docs/references/red-test-policy.md.\n\n${stale_red}"
  jq -nc --arg r "$reason" '{continue: false, stopReason: $r}'
  exit 0
fi

# 2. Run the fast test suite
output=$(eval "$test_cmd" 2>&1) || rc=$?
rc=${rc:-0}

if (( rc != 0 )); then
  # Compress output to first 20 lines + last 5 lines for the agent
  short_out=$(echo "$output" | head -20)
  tail_out=$(echo "$output" | tail -5)
  reason="Pre-commit blocked: fast test suite is RED (golden principle P-12). Fix the failing test before committing. See docs/references/red-test-policy.md.\n\n--- first 20 lines ---\n${short_out}\n--- last 5 lines ---\n${tail_out}"
  jq -nc --arg r "$reason" '{continue: false, stopReason: $r}'
  exit 0
fi

echo '{"continue": true}'
exit 0
