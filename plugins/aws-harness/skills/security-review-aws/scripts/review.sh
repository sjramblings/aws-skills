#!/usr/bin/env bash
# security-review-aws/scripts/review.sh
# Runs harness lints against CDK synth output + repo governance files.
# See SKILL.md.

set -euo pipefail

APP="./cdk"
ADVISORY=0
JSON_OUT=0
FAIL_ON="high"

die() { echo "security-review-aws: $*" >&2; exit 2; }
usage() {
  cat <<'EOF' >&2
Usage: review.sh [--app ./cdk] [--advisory] [--json] [--fail-on critical|high|medium|low]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP="${2:?}"; shift 2 ;;
    --advisory) ADVISORY=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    --fail-on) FAIL_ON="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

findings_json='[]'

add_finding() {
  local sev="$1" lint="$2" resource="$3" message="$4"
  findings_json=$(echo "$findings_json" | jq \
    --arg sev "$sev" --arg lint "$lint" --arg res "$resource" --arg msg "$message" \
    '. + [{severity:$sev, lint:$lint, resource:$res, message:$msg}]')
}

# --- 1. ensure synth is fresh ---
if [[ -d "$APP" ]] && [[ ! -d "$APP/cdk.out" || "$APP/cdk.json" -nt "$APP/cdk.out" ]]; then
  echo "security-review-aws: running cdk synth" >&2
  ( cd "$APP" && cdk synth --quiet >/dev/null ) || {
    add_finding "critical" "cdk-synth" "-" "cdk synth failed — cannot scan templates"
  }
fi

# --- 2. collect CDK templates ---
templates=()
if [[ -d "$APP/cdk.out" ]]; then
  while IFS= read -r -d '' f; do
    templates+=("$f")
  done < <(find "$APP/cdk.out" -name '*.template.json' -print0 2>/dev/null)
fi

# --- 3. run per-template CDK lints (the .ts files via node runner) ---
lint_runner="tools/lints/run-lints.ts"
if [[ -f "$lint_runner" ]] && [[ ${#templates[@]} -gt 0 ]]; then
  for tpl in "${templates[@]}"; do
    out=$(npx --yes ts-node "$lint_runner" "$tpl" 2>/dev/null || echo "[]")
    # expected output: JSON array of {severity, lint, resource, message}
    if echo "$out" | jq -e 'type == "array"' >/dev/null 2>&1; then
      findings_json=$(echo "$findings_json" | jq --argjson new "$out" '. + $new')
    fi
  done
fi

# --- 4. run python governance lints (best-effort, never block on missing) ---
run_py_lint() {
  local script="$1" lint_name="$2"
  if [[ -f "tools/lints/$script" ]]; then
    out=$(python3 "tools/lints/$script" 2>/dev/null || echo "[]")
    if echo "$out" | jq -e 'type == "array"' >/dev/null 2>&1; then
      findings_json=$(echo "$findings_json" | jq --argjson new "$out" '. + $new')
    fi
  fi
}

run_py_lint "doc-freshness.py" "doc-freshness"
run_py_lint "agents-md-map-only.py" "agents-md-map-only"
run_py_lint "golden-principle-has-lint.py" "golden-principle-has-lint"

# --- 5. emit output ---
if (( JSON_OUT == 1 )); then
  echo "$findings_json" | jq '{
    total: length,
    bySeverity: (group_by(.severity) | map({(.[0].severity): length}) | add),
    findings: .
  }'
else
  printf "SEVERITY\tLINT\tRESOURCE\tMESSAGE\n"
  echo "$findings_json" | jq -r '
    (sort_by(
      if .severity == "critical" then 0
      elif .severity == "high" then 1
      elif .severity == "medium" then 2
      elif .severity == "low" then 3
      else 4 end
    ))
    | .[]
    | [.severity, .lint, .resource, (.message | gsub("[\t\n]"; " "))]
    | @tsv
  '
fi

# --- 6. exit code ---
if (( ADVISORY == 1 )); then
  exit 0
fi

severity_rank() {
  case "$1" in
    critical) echo 0 ;;
    high)     echo 1 ;;
    medium)   echo 2 ;;
    low)      echo 3 ;;
    *)        echo 4 ;;
  esac
}

fail_rank=$(severity_rank "$FAIL_ON")
max_rank=4
while read -r sev; do
  [[ -z "$sev" ]] && continue
  r=$(severity_rank "$sev")
  if (( r < max_rank )); then max_rank=$r; fi
done < <(echo "$findings_json" | jq -r '.[].severity')

if (( max_rank <= fail_rank )); then
  count=$(echo "$findings_json" | jq 'length')
  echo "security-review-aws: ${count} finding(s) at or above '${FAIL_ON}'" >&2
  exit 1
fi
exit 0
