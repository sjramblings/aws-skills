#!/usr/bin/env bash
# deploy-pr-stack/scripts/deploy.sh
# Orchestrates cdk deploy for a per-PR ephemeral stack.
# See SKILL.md.

set -euo pipefail

PR=""
PROJECT=""
APP="./cdk"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
TTL="72h"
CONTEXTS=()
USE_BUDGET=1

die() { echo "deploy-pr-stack: $*" >&2; exit 2; }
usage() {
  cat <<'EOF' >&2
Usage: deploy.sh --pr <N> --project <slug> [--app <path>] [--context k=v ...]
                 [--region REGION] [--ttl 72h] [--no-budget]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr) PR="${2:?}"; shift 2 ;;
    --project) PROJECT="${2:?}"; shift 2 ;;
    --app) APP="${2:?}"; shift 2 ;;
    --context) CONTEXTS+=("${2:?}"); shift 2 ;;
    --region) REGION="${2:?}"; shift 2 ;;
    --ttl) TTL="${2:?}"; shift 2 ;;
    --no-budget) USE_BUDGET=0; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -z "$PR" || -z "$PROJECT" ]] && usage
[[ "$PR" =~ ^[0-9]+$ ]] || die "--pr must be an integer"

# --- 1. identity ---
identity=$(aws sts get-caller-identity --output json 2>&1) || die "sts get-caller-identity failed"
account=$(echo "$identity" | jq -r '.Account')
caller_arn=$(echo "$identity" | jq -r '.Arn')
echo "deploy-pr-stack: account=${account} caller=${caller_arn}"

# --- 2. capability-probe freshness gate ---
cache="${CAPABILITY_PROBE_CACHE:-.harness-cache/capability-probe.json}"
if [[ ! -f "$cache" ]]; then
  die "capability-probe cache missing at $cache — run 'capability-probe' first (golden principle P-01)"
fi
probed_at=$(jq -r '.probed_at' "$cache" 2>/dev/null || echo "")
[[ -z "$probed_at" || "$probed_at" == "null" ]] && die "capability-probe cache malformed: $cache"

if date -u -d "$probed_at" +%s >/dev/null 2>&1; then
  probed_epoch=$(date -u -d "$probed_at" +%s)  # GNU
else
  probed_epoch=$(date -u -jf "%Y-%m-%dT%H:%M:%SZ" "$probed_at" +%s)  # BSD
fi
now_epoch=$(date -u +%s)
age=$(( now_epoch - probed_epoch ))
if (( age > 86400 )); then
  die "capability-probe cache is $(( age / 3600 ))h old (>24h). Re-run 'capability-probe' first."
fi
echo "deploy-pr-stack: probe cache fresh (age ${age}s)"

# --- 3. stack name ---
STACK_NAME="pr-${PR}-${PROJECT}"
ACTOR="${GITHUB_ACTOR:-$(whoami)}"
echo "deploy-pr-stack: stack=${STACK_NAME} ttl=${TTL} actor=${ACTOR}"

# --- 4. cdk deploy ---
tags=(
  "harness:pr=${PR}"
  "harness:owner=${ACTOR}"
  "harness:ttl=${TTL}"
  "harness:env=pr"
  "harness:project=${PROJECT}"
)
tag_args=()
for t in "${tags[@]}"; do
  tag_args+=(--tags "$t")
done

context_args=()
for c in "${CONTEXTS[@]}"; do
  context_args+=(-c "$c")
done

region_arg=()
[[ -n "$REGION" ]] && region_arg=(--region "$REGION")

pushd "$APP" >/dev/null || die "cdk app dir not found: $APP"

set +e
cdk deploy "$STACK_NAME" \
  --require-approval never \
  --outputs-file "../.harness-cache/pr-stack-outputs-${PR}.json" \
  "${tag_args[@]}" \
  "${context_args[@]}" \
  "${region_arg[@]}"
deploy_rc=$?
set -e

popd >/dev/null

# --- 5. on failure: compact cfn-stack-events output ---
if (( deploy_rc != 0 )); then
  echo "deploy-pr-stack: deploy failed rc=${deploy_rc}; fetching compact events..." >&2
  fetch="${CLAUDE_PLUGIN_ROOT:-${PWD}}/skills/cfn-stack-events/scripts/fetch.sh"
  if [[ -x "$fetch" ]]; then
    bash "$fetch" "$STACK_NAME" --since 1h --limit 20 >&2 || true
  else
    echo "deploy-pr-stack: cfn-stack-events fetch.sh not found on path; skipping" >&2
  fi
  exit "$deploy_rc"
fi

# --- 6. write step summary ---
outputs_file=".harness-cache/pr-stack-outputs-${PR}.json"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## PR stack deployed"
    echo ""
    echo "- Stack: \`${STACK_NAME}\`"
    echo "- Actor: @${ACTOR}"
    echo "- TTL: ${TTL}"
    echo "- Account: ${account}"
    echo ""
    if [[ -f "$outputs_file" ]]; then
      echo "### CFN Outputs"
      echo ""
      echo '```json'
      cat "$outputs_file"
      echo '```'
    fi
  } >> "$GITHUB_STEP_SUMMARY"
else
  echo "=== PR stack deployed: ${STACK_NAME} ==="
  [[ -f "$outputs_file" ]] && cat "$outputs_file"
fi

# --- 7. attach budget guard ---
if (( USE_BUDGET == 1 )); then
  budget="${CLAUDE_PLUGIN_ROOT:-${PWD}}/../../templates/tools/scripts/pr-stack-budget.sh"
  # fallback to project-local copy (after harness-init)
  [[ ! -x "$budget" ]] && budget="./tools/scripts/pr-stack-budget.sh"
  if [[ -x "$budget" ]]; then
    bash "$budget" --stack-name "$STACK_NAME" --account "$account" --daily-limit 5 || {
      echo "deploy-pr-stack: budget attach failed (non-fatal)" >&2
    }
  else
    echo "deploy-pr-stack: pr-stack-budget.sh not found; skipping budget attach" >&2
  fi
fi

echo "deploy-pr-stack: done"
