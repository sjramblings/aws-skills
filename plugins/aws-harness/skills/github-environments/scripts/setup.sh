#!/usr/bin/env bash
# github-environments/scripts/setup.sh
# Creates pr/uat/prod GitHub environments with OIDC role vars, deployment
# branch policies, required reviewers, and wait timers.
# See SKILL.md.

set -euo pipefail

REPO=""
PR_ROLE=""
UAT_ROLE=""
UAT_REGION=""
PROD_ROLE=""
PROD_REGION=""
UAT_REVIEWER=""
PROD_REVIEWERS=""

die() { echo "github-environments: $*" >&2; exit 2; }
usage() {
  cat <<'EOF' >&2
Usage: setup.sh --repo owner/repo
                --uat-role ARN --uat-region REGION
                --prod-role ARN --prod-region REGION
                [--pr-role ARN]
                [--uat-reviewer USER-OR-TEAM]
                [--prod-reviewers user1,user2]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:?}"; shift 2 ;;
    --pr-role) PR_ROLE="${2:?}"; shift 2 ;;
    --uat-role) UAT_ROLE="${2:?}"; shift 2 ;;
    --uat-region) UAT_REGION="${2:?}"; shift 2 ;;
    --prod-role) PROD_ROLE="${2:?}"; shift 2 ;;
    --prod-region) PROD_REGION="${2:?}"; shift 2 ;;
    --uat-reviewer) UAT_REVIEWER="${2:?}"; shift 2 ;;
    --prod-reviewers) PROD_REVIEWERS="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -z "$REPO" || -z "$UAT_ROLE" || -z "$UAT_REGION" || -z "$PROD_ROLE" || -z "$PROD_REGION" ]] && usage
[[ -z "$PR_ROLE" ]] && PR_ROLE="$UAT_ROLE"

# --- preflight ---
gh auth status >/dev/null 2>&1 || die "gh not authenticated (run 'gh auth login')"
gh api "repos/${REPO}" >/dev/null 2>&1 || die "repo ${REPO} not accessible"

validate_arn() {
  [[ "$1" =~ ^arn:aws:iam::[0-9]+:role/ ]] || die "invalid role ARN: $1"
}
validate_arn "$PR_ROLE"
validate_arn "$UAT_ROLE"
validate_arn "$PROD_ROLE"

echo "github-environments: configuring repo=${REPO}"

# --- helper: create or update env ---
create_env() {
  local name="$1"
  local wait_timer="$2"
  local reviewers_json="$3"

  gh api -X PUT "repos/${REPO}/environments/${name}" \
    -f "wait_timer=${wait_timer}" \
    --input <(cat <<EOF
{
  "wait_timer": ${wait_timer},
  "reviewers": ${reviewers_json},
  "deployment_branch_policy": null
}
EOF
    ) >/dev/null
  echo "  ✓ env: ${name}"
}

set_var() {
  local env="$1" key="$2" val="$3"
  gh variable set "$key" --env "$env" --repo "$REPO" --body "$val" >/dev/null
  echo "    var: ${key}=${val}"
}

set_branch_policy() {
  local name="$1" policy="$2"
  # policy is one of: null, {"protected_branches":true,"custom_branch_policies":false}, or custom
  gh api -X PUT "repos/${REPO}/environments/${name}" \
    --input <(echo "{\"deployment_branch_policy\": ${policy}}") >/dev/null
}

# --- reviewers: map usernames to IDs ---
reviewer_json_for() {
  local spec="$1"
  [[ -z "$spec" ]] && { echo "[]"; return; }

  local out='[]'
  IFS=',' read -ra list <<<"$spec"
  for item in "${list[@]}"; do
    item="${item// /}"
    [[ -z "$item" ]] && continue
    # Try user first
    if uid=$(gh api "users/${item}" --jq '.id' 2>/dev/null); then
      out=$(echo "$out" | jq --argjson id "$uid" '. + [{type:"User", id:$id}]')
    else
      echo "    warn: reviewer '${item}' not found as user; skipping (teams require org-level setup)" >&2
    fi
  done
  echo "$out"
}

# --- env: pr ---
create_env "pr" 0 "[]"
set_var "pr" "AWS_DEPLOY_ROLE_ARN" "$PR_ROLE"
set_var "pr" "AWS_PRIMARY_REGION"  "$UAT_REGION"
set_var "pr" "HARNESS_ENV"          "pr"
# pr allows any branch
set_branch_policy "pr" '{"protected_branches":false,"custom_branch_policies":true}'
# ensure default branch policy is permissive — no tags restriction
gh api -X POST "repos/${REPO}/environments/pr/deployment-branch-policies" \
  --input <(echo '{"name":"*"}') >/dev/null 2>&1 || true
gh api -X POST "repos/${REPO}/environments/pr/deployment-branch-policies" \
  --input <(echo '{"name":"*/*"}') >/dev/null 2>&1 || true

# --- env: uat ---
uat_reviewers=$(reviewer_json_for "$UAT_REVIEWER")
create_env "uat" 0 "$uat_reviewers"
set_var "uat" "AWS_DEPLOY_ROLE_ARN" "$UAT_ROLE"
set_var "uat" "AWS_PRIMARY_REGION"  "$UAT_REGION"
set_var "uat" "HARNESS_ENV"          "uat"
# uat = protected branches only (main)
set_branch_policy "uat" '{"protected_branches":true,"custom_branch_policies":false}'

# --- env: prod ---
prod_reviewers=$(reviewer_json_for "$PROD_REVIEWERS")
create_env "prod" 600 "$prod_reviewers"
set_var "prod" "AWS_DEPLOY_ROLE_ARN" "$PROD_ROLE"
set_var "prod" "AWS_PRIMARY_REGION"  "$PROD_REGION"
set_var "prod" "HARNESS_ENV"          "prod"
# prod = tags matching v*.*.* only
set_branch_policy "prod" '{"protected_branches":false,"custom_branch_policies":true}'
gh api -X POST "repos/${REPO}/environments/prod/deployment-branch-policies" \
  --input <(echo '{"name":"v*.*.*","type":"tag"}') >/dev/null 2>&1 || true

echo "github-environments: done"
echo ""
echo "Verify at: https://github.com/${REPO}/settings/environments"
