#!/usr/bin/env bash
# capability-probe/scripts/probe.sh
# Phase-1 preflight: validates (model, region) matrix against Bedrock
# availability, inference-profile prefixes, IAM grants, and marketplace
# subscription. Writes .harness-cache/capability-probe.json.
# See SKILL.md.

set -euo pipefail

MODELS=""
REGIONS=""
CHECK_IAM=0
CHECK_MARKETPLACE=1
OUTPUT="tsv"
CACHE_PATH=".harness-cache/capability-probe.json"

die() { echo "capability-probe: $*" >&2; exit 2; }
usage() {
  cat <<'EOF' >&2
Usage: probe.sh --models "id1,id2" --regions "r1,r2" [--check-iam]
                [--skip-marketplace] [--output tsv|json] [--cache path]

Validates (model, region) pairs for Bedrock availability, inference-profile
prefix alignment, optional IAM grant, and marketplace subscription.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --models) MODELS="${2:?}"; shift 2 ;;
    --regions) REGIONS="${2:?}"; shift 2 ;;
    --check-iam) CHECK_IAM=1; shift ;;
    --skip-iam) CHECK_IAM=0; shift ;;
    --skip-marketplace) CHECK_MARKETPLACE=0; shift ;;
    --output) OUTPUT="${2:?}"; shift 2 ;;
    --cache) CACHE_PATH="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -z "$MODELS" || -z "$REGIONS" ]] && usage
[[ "$OUTPUT" != "tsv" && "$OUTPUT" != "json" ]] && die "--output must be tsv or json"

# --- confirm identity ---
account=$(aws sts get-caller-identity --query Account --output text 2>&1) || {
  echo "$account" >&2
  die "sts get-caller-identity failed — check credentials"
}
caller_arn=$(aws sts get-caller-identity --query Arn --output text)

# --- derive expected prefix per region ---
region_prefix() {
  case "$1" in
    us-east-1|us-east-2|us-west-1|us-west-2)                   echo "us." ;;
    ap-northeast-1|ap-northeast-2|ap-south-1|ap-southeast-1|ap-southeast-2) echo "apac." ;;
    eu-west-1|eu-west-2|eu-west-3|eu-central-1|eu-north-1)     echo "eu." ;;
    *) echo "global." ;;
  esac
}

IFS=',' read -ra MODEL_LIST <<<"$MODELS"
IFS=',' read -ra REGION_LIST <<<"$REGIONS"

# --- collect results ---
results_json='[]'

for model in "${MODEL_LIST[@]}"; do
  model="${model// /}"
  [[ -z "$model" ]] && continue

  for region in "${REGION_LIST[@]}"; do
    region="${region// /}"
    [[ -z "$region" ]] && continue

    status="ok"
    detail="-"

    # 1. Availability — list foundation models in region and grep
    list_out=$(aws bedrock list-foundation-models --region "$region" --output json 2>&1) || {
      status="error"
      detail="list-foundation-models failed: $(echo "$list_out" | head -c 160 | tr -d '\n')"
      results_json=$(echo "$results_json" | jq --arg m "$model" --arg r "$region" --arg s "$status" --arg d "$detail" '. + [{model:$m, region:$r, status:$s, detail:$d}]')
      continue
    }

    # Inference profile prefixed models are not listed as foundation-models.
    # Strip prefix for the availability check.
    base_model="${model#us.}"
    base_model="${base_model#apac.}"
    base_model="${base_model#eu.}"
    base_model="${base_model#global.}"

    available=$(echo "$list_out" | jq --arg bm "$base_model" '.modelSummaries // [] | map(select(.modelId == $bm or .modelId == $bm + "::prepub")) | length')
    if [[ "$available" == "0" ]]; then
      status="not-available"
      detail="base model $base_model not published in $region"
      results_json=$(echo "$results_json" | jq --arg m "$model" --arg r "$region" --arg s "$status" --arg d "$detail" '. + [{model:$m, region:$r, status:$s, detail:$d}]')
      continue
    fi

    # 2. Inference profile prefix alignment
    if [[ "$model" != "$base_model" ]]; then
      expected_prefix=$(region_prefix "$region")
      model_prefix="${model%%.*}."
      if [[ "$expected_prefix" != "$model_prefix" ]]; then
        status="profile-mismatch"
        detail="model prefix ${model_prefix} doesn't match region prefix ${expected_prefix}"
        results_json=$(echo "$results_json" | jq --arg m "$model" --arg r "$region" --arg s "$status" --arg d "$detail" '. + [{model:$m, region:$r, status:$s, detail:$d}]')
        continue
      fi

      # Confirm the profile actually exists in the region
      profiles=$(aws bedrock list-inference-profiles --region "$region" --output json 2>/dev/null || echo '{"inferenceProfileSummaries":[]}')
      has_profile=$(echo "$profiles" | jq --arg m "$model" '[.inferenceProfileSummaries[]? | select(.inferenceProfileId == $m)] | length')
      if [[ "$has_profile" == "0" ]]; then
        status="profile-mismatch"
        detail="inference profile $model not found in $region"
        results_json=$(echo "$results_json" | jq --arg m "$model" --arg r "$region" --arg s "$status" --arg d "$detail" '. + [{model:$m, region:$r, status:$s, detail:$d}]')
        continue
      fi
    fi

    # 3. IAM check (optional — off by default because simulate-principal-policy requires iam:SimulatePrincipalPolicy)
    if (( CHECK_IAM == 1 )); then
      iam_out=$(aws iam simulate-principal-policy \
        --policy-source-arn "$caller_arn" \
        --action-names bedrock:InvokeModel bedrock:InvokeModelWithResponseStream \
        --resource-arns "arn:aws:bedrock:${region}::foundation-model/${base_model}" \
        --output json 2>&1) || {
          status="iam-missing"
          detail="simulate-principal-policy error: $(echo "$iam_out" | head -c 160 | tr -d '\n')"
          results_json=$(echo "$results_json" | jq --arg m "$model" --arg r "$region" --arg s "$status" --arg d "$detail" '. + [{model:$m, region:$r, status:$s, detail:$d}]')
          continue
        }
      denied=$(echo "$iam_out" | jq '[.EvaluationResults[] | select(.EvalDecision != "allowed")] | length')
      if [[ "$denied" != "0" ]]; then
        status="iam-missing"
        detail="caller lacks bedrock:InvokeModel on $base_model in $region"
        results_json=$(echo "$results_json" | jq --arg m "$model" --arg r "$region" --arg s "$status" --arg d "$detail" '. + [{model:$m, region:$r, status:$s, detail:$d}]')
        continue
      fi
    fi

    # 4. Marketplace / EULA check via get-foundation-model
    if (( CHECK_MARKETPLACE == 1 )); then
      gfm=$(aws bedrock get-foundation-model --region "$region" --model-identifier "$base_model" --output json 2>&1 || true)
      if echo "$gfm" | grep -q "AccessDeniedException\|not subscribed\|NotFoundException"; then
        status="not-subscribed"
        detail="marketplace EULA / subscription required for $base_model"
        results_json=$(echo "$results_json" | jq --arg m "$model" --arg r "$region" --arg s "$status" --arg d "$detail" '. + [{model:$m, region:$r, status:$s, detail:$d}]')
        continue
      fi
    fi

    results_json=$(echo "$results_json" | jq --arg m "$model" --arg r "$region" --arg s "$status" --arg d "$detail" '. + [{model:$m, region:$r, status:$s, detail:$d}]')
  done
done

# --- write cache ---
mkdir -p "$(dirname "$CACHE_PATH")"
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$CACHE_PATH" <<EOF
{
  "probed_at": "${timestamp}",
  "account": "${account}",
  "caller_arn": "${caller_arn}",
  "results": $(echo "$results_json" | jq '.')
}
EOF

# --- output ---
if [[ "$OUTPUT" == "json" ]]; then
  cat "$CACHE_PATH"
else
  printf "MODEL\tREGION\tSTATUS\tDETAIL\n"
  echo "$results_json" | jq -r '.[] | [.model, .region, .status, .detail] | @tsv'
fi

# --- exit code ---
red=$(echo "$results_json" | jq '[.[] | select(.status != "ok")] | length')
if [[ "$red" != "0" ]]; then
  echo "capability-probe: ${red} red row(s). Caller: ${caller_arn}" >&2
  exit 1
fi
exit 0
