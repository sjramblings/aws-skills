#!/usr/bin/env bash
# integration-test-runner/scripts/run.sh
# Resolves CFN outputs into env vars, runs integration-tagged tests,
# emits compact pass/fail summary.
# See SKILL.md.

set -euo pipefail

STACK=""
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
RUNNER="auto"
BAIL=0
TIMEOUT_MINUTES=15

die() { echo "integration-test-runner: $*" >&2; exit 2; }
usage() {
  cat <<'EOF' >&2
Usage: run.sh --stack NAME [--region R] [--runner auto|vitest|jest|pytest] [--bail] [--timeout-minutes N]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK="${2:?}"; shift 2 ;;
    --region) REGION="${2:?}"; shift 2 ;;
    --runner) RUNNER="${2:?}"; shift 2 ;;
    --bail) BAIL=1; shift ;;
    --timeout-minutes) TIMEOUT_MINUTES="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -z "$STACK" ]] && usage
command -v jq >/dev/null 2>&1 || die "jq not installed"

# --- 1. fetch CFN outputs & export as STACK_<KEY> ---
region_arg=()
[[ -n "$REGION" ]] && region_arg=(--region "$REGION")

stack_json=$(aws cloudformation describe-stacks --stack-name "$STACK" "${region_arg[@]}" --output json 2>&1) || {
  echo "$stack_json" >&2
  die "describe-stacks failed for $STACK"
}

outputs=$(echo "$stack_json" | jq -r '.Stacks[0].Outputs // [] | .[] | "STACK_\(.OutputKey | ascii_upcase)=\(.OutputValue)"')
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  export "$key"="$val"
done <<<"$outputs"

# --- 2. detect runner ---
if [[ "$RUNNER" == "auto" ]]; then
  if [[ -f package.json ]]; then
    if grep -q '"vitest"' package.json; then RUNNER="vitest"
    elif grep -q '"jest"' package.json; then RUNNER="jest"
    fi
  fi
  if [[ "$RUNNER" == "auto" ]] && [[ -f pyproject.toml || -f pytest.ini || -f setup.cfg ]]; then
    RUNNER="pytest"
  fi
fi
[[ "$RUNNER" == "auto" ]] && die "could not auto-detect test runner (specify --runner)"

mkdir -p .harness-cache
report=".harness-cache/integration-test.json"

# --- 3. run tests, capture JSON report ---
start=$(date +%s)
set +e
case "$RUNNER" in
  vitest)
    timeout "${TIMEOUT_MINUTES}m" npx --yes vitest run \
      --reporter=json --reporter=default \
      --testNamePattern @integration \
      --outputFile "$report" \
      ${BAIL:+--bail 1}
    rc=$?
    ;;
  jest)
    timeout "${TIMEOUT_MINUTES}m" npx --yes jest \
      --json --outputFile="$report" \
      --testNamePattern @integration \
      ${BAIL:+--bail}
    rc=$?
    ;;
  pytest)
    timeout "${TIMEOUT_MINUTES}m" python3 -m pytest \
      -m integration \
      --json-report --json-report-file="$report" \
      ${BAIL:+--maxfail=1}
    rc=$?
    ;;
  *)
    die "unknown runner: $RUNNER"
    ;;
esac
set -e
elapsed=$(( $(date +%s) - start ))

# --- 4. parse + emit compact summary ---
total=0; pass=0; fail=0; skip=0
failed_tests='[]'

if [[ -f "$report" ]]; then
  case "$RUNNER" in
    vitest|jest)
      # both emit { numTotalTests, numPassedTests, numFailedTests, numPendingTests, testResults: [...] }
      total=$(jq -r '.numTotalTests // 0' "$report")
      pass=$(jq -r '.numPassedTests // 0' "$report")
      fail=$(jq -r '.numFailedTests // 0' "$report")
      skip=$(jq -r '.numPendingTests // 0' "$report")
      failed_tests=$(jq -c '
        [.testResults[]?.testResults[]?
         | select(.status == "failed")
         | {name: .fullName, error: (.failureMessages[0] // "" | split("\n")[0])}]
      ' "$report")
      ;;
    pytest)
      total=$(jq -r '.summary.total // 0' "$report")
      pass=$(jq -r '.summary.passed // 0' "$report")
      fail=$(jq -r '.summary.failed // 0' "$report")
      skip=$(jq -r '.summary.skipped // 0' "$report")
      failed_tests=$(jq -c '
        [.tests[]?
         | select(.outcome == "failed")
         | {name: .nodeid, error: ((.call.crash.message // .call.longrepr // "") | split("\n")[0])}]
      ' "$report")
      ;;
  esac
fi

human_elapsed=$(printf "%dm%ds" $((elapsed/60)) $((elapsed%60)))
printf "RUNNER\tTOTAL\tPASS\tFAIL\tSKIP\tELAPSED\n"
printf "%s\t%d\t%d\t%d\t%d\t%s\n" "$RUNNER" "$total" "$pass" "$fail" "$skip" "$human_elapsed"

if [[ "$failed_tests" != "[]" && "$failed_tests" != "null" ]]; then
  echo ""
  echo "FAILED:"
  echo "$failed_tests" | jq -r '.[] | "  \(.name)\n    \(.error)"'
fi

exit "$rc"
