#!/usr/bin/env bash
# post-deploy-verify/scripts/verify.sh
# Runs declarative smoke tests defined in YAML against a deployed CFN stack.
# See SKILL.md.

set -euo pipefail

SPEC=""
PR=""
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
BAIL=0

die() { echo "post-deploy-verify: $*" >&2; exit 2; }
usage() {
  cat <<'EOF' >&2
Usage: verify.sh --spec docs/smoke-tests/<service>.yaml [--pr N] [--region R] [--bail]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec) SPEC="${2:?}"; shift 2 ;;
    --pr) PR="${2:?}"; shift 2 ;;
    --region) REGION="${2:?}"; shift 2 ;;
    --bail) BAIL=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -z "$SPEC" ]] && usage
[[ ! -f "$SPEC" ]] && die "spec file not found: $SPEC"
command -v yq >/dev/null 2>&1 || die "yq not installed (brew install yq)"
command -v jq >/dev/null 2>&1 || die "jq not installed"
command -v curl >/dev/null 2>&1 || die "curl not installed"

# --- 1. resolve stack name ---
stack_name=$(yq -r '.stack_name' "$SPEC")
if [[ -n "$PR" ]]; then
  stack_name="${stack_name//\$\{PR_NUMBER\}/$PR}"
fi
[[ -z "$stack_name" || "$stack_name" == "null" ]] && die "stack_name missing in $SPEC"

# --- 2. fetch CFN outputs ---
region_arg=()
[[ -n "$REGION" ]] && region_arg=(--region "$REGION")

stack_json=$(aws cloudformation describe-stacks --stack-name "$stack_name" "${region_arg[@]}" --output json 2>&1) || {
  echo "$stack_json" >&2
  die "describe-stacks failed for $stack_name"
}
outputs_json=$(echo "$stack_json" | jq -c '.Stacks[0].Outputs // [] | map({(.OutputKey): .OutputValue}) | add // {}')

# --- 3. build alias map ---
# `outputs:` block in YAML maps short-alias -> CFN OutputKey
alias_map=$(yq -o=json '.outputs' "$SPEC")
substitutions=$(echo "$alias_map" | jq -c --argjson out "$outputs_json" '
  to_entries
  | map({key: .key, value: ($out[.value] // null)})
  | from_entries
')

# --- 4. defaults ---
default_timeout=$(yq -r '.defaults.timeout_seconds // 10' "$SPEC")
default_retries=$(yq -r '.defaults.retries // 1' "$SPEC")
default_retry_delay=$(yq -r '.defaults.retry_delay_seconds // 1' "$SPEC")

# --- 5. iterate tests ---
test_count=$(yq -r '.tests | length' "$SPEC")
fail_count=0

printf "NAME\tSTATUS\tCODE\tELAPSED\tDETAIL\n"

for i in $(seq 0 $((test_count - 1))); do
  name=$(yq -r ".tests[$i].name" "$SPEC")
  method=$(yq -r ".tests[$i].request.method // \"GET\"" "$SPEC")
  url_tpl=$(yq -r ".tests[$i].request.url" "$SPEC")
  body=$(yq -r ".tests[$i].request.body // \"\"" "$SPEC")
  headers_json=$(yq -o=json ".tests[$i].request.headers // {}" "$SPEC")

  expect_status=$(yq -r ".tests[$i].expect.status // \"\"" "$SPEC")
  expect_status_in=$(yq -o=json ".tests[$i].expect.status_in // []" "$SPEC")
  expect_body_contains=$(yq -r ".tests[$i].expect.body_contains // \"\"" "$SPEC")
  expect_body_path=$(yq -r ".tests[$i].expect.body_contains_path // \"\"" "$SPEC")

  # substitute {alias} placeholders + ${ENV_VAR}
  url="$url_tpl"
  while read -r alias_kv; do
    k=$(echo "$alias_kv" | jq -r '.key')
    v=$(echo "$alias_kv" | jq -r '.value // ""')
    url="${url//\{$k\}/$v}"
    body="${body//\{$k\}/$v}"
  done < <(echo "$substitutions" | jq -c 'to_entries[]')
  url=$(envsubst <<<"$url")
  body=$(envsubst <<<"$body")

  # build curl args
  curl_args=(-sS -o /tmp/post-verify-body.$$ -w "%{http_code} %{time_total}" --max-time "$default_timeout" -X "$method")
  while read -r hkv; do
    k=$(echo "$hkv" | jq -r '.key')
    v=$(echo "$hkv" | jq -r '.value')
    v=$(envsubst <<<"$v")
    curl_args+=(-H "${k}: ${v}")
  done < <(echo "$headers_json" | jq -c 'to_entries[]')
  if [[ -n "$body" ]]; then
    curl_args+=(--data-raw "$body")
  fi

  # retry loop
  attempt=0
  result=""
  while (( attempt < default_retries )); do
    result=$(curl "${curl_args[@]}" "$url" 2>&1) || true
    if [[ "$result" =~ ^[0-9]{3}\  ]]; then break; fi
    attempt=$((attempt + 1))
    sleep "$default_retry_delay"
  done

  code=$(echo "$result" | awk '{print $1}')
  elapsed=$(echo "$result" | awk '{print $2}')
  body_resp=$(cat /tmp/post-verify-body.$$ 2>/dev/null || echo "")
  rm -f /tmp/post-verify-body.$$

  detail="-"
  status="PASS"

  # status check
  if [[ -n "$expect_status" && "$expect_status" != "null" ]]; then
    if [[ "$code" != "$expect_status" ]]; then
      status="FAIL"
      detail="expected ${expect_status} got ${code}"
    fi
  elif [[ "$expect_status_in" != "[]" && "$expect_status_in" != "null" ]]; then
    if ! echo "$expect_status_in" | jq -e --arg c "$code" 'index($c | tonumber)' >/dev/null; then
      status="FAIL"
      detail="status ${code} not in ${expect_status_in}"
    fi
  fi

  # body_contains
  if [[ "$status" == "PASS" && -n "$expect_body_contains" && "$expect_body_contains" != "null" ]]; then
    if [[ "$body_resp" != *"$expect_body_contains"* ]]; then
      status="FAIL"
      detail="body missing literal: ${expect_body_contains}"
    fi
  fi

  # body_contains_path (jq)
  if [[ "$status" == "PASS" && -n "$expect_body_path" && "$expect_body_path" != "null" ]]; then
    if ! echo "$body_resp" | jq -e "$expect_body_path" >/dev/null 2>&1; then
      status="FAIL"
      detail="body path missing: ${expect_body_path}"
    fi
  fi

  ms=$(awk -v t="$elapsed" 'BEGIN{printf "%dms", t*1000}')
  printf "%s\t%s\t%s\t%s\t%s\n" "$name" "$status" "$code" "$ms" "$detail"

  if [[ "$status" == "FAIL" ]]; then
    fail_count=$((fail_count + 1))
    if (( BAIL == 1 )); then break; fi
  fi
done

if (( fail_count > 0 )); then
  echo "post-deploy-verify: ${fail_count}/${test_count} test(s) failed" >&2
  exit 1
fi
exit 0
