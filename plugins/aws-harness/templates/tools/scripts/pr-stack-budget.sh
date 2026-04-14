#!/usr/bin/env bash
# tools/scripts/pr-stack-budget.sh
# Attaches an AWS Budget ($/day) to a per-PR stack, scoped via the
# harness:pr tag. Last-resort cost kill-switch for the per-PR ephemeral
# deploy loop.
#
# Budgets API notifications fire at 80% + 100% of the daily limit. The
# 100% notification targets an SNS topic named harness-pr-stack-budget
# (auto-created if missing) which an EventBridge rule subscribes to for
# auto-destroy. This script creates/updates the Budget only; the
# EventBridge + Lambda auto-destroy is a separate stack set up once per
# account by the github-environments skill workflow.

set -euo pipefail

STACK_NAME=""
ACCOUNT=""
DAILY_LIMIT="5"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

die() { echo "pr-stack-budget: $*" >&2; exit 2; }
usage() {
  cat <<'EOF' >&2
Usage: pr-stack-budget.sh --stack-name NAME [--account ID] [--daily-limit USD] [--region REGION]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack-name) STACK_NAME="${2:?}"; shift 2 ;;
    --account) ACCOUNT="${2:?}"; shift 2 ;;
    --daily-limit) DAILY_LIMIT="${2:?}"; shift 2 ;;
    --region) REGION="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -z "$STACK_NAME" ]] && usage
[[ "$STACK_NAME" =~ ^pr-[0-9]+- ]] || die "stack name must match pattern pr-<N>-*"

if [[ -z "$ACCOUNT" ]]; then
  ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
fi

PR_NUMBER=$(echo "$STACK_NAME" | sed -E 's/^pr-([0-9]+)-.*/\1/')
BUDGET_NAME="harness-${STACK_NAME}"

# --- ensure SNS topic for notifications exists ---
topic_arn=$(aws sns create-topic --name harness-pr-stack-budget --region "$REGION" --query TopicArn --output text)

# --- build budget spec ---
# CostFilters restrict the budget to resources tagged harness:pr=<N>. This
# requires the 'harness:pr' user-defined cost-allocation tag to be ACTIVE
# in Billing preferences for the account (one-time setup per account).
spec=$(cat <<EOF
{
  "BudgetName": "${BUDGET_NAME}",
  "BudgetLimit": { "Amount": "${DAILY_LIMIT}", "Unit": "USD" },
  "TimeUnit": "DAILY",
  "BudgetType": "COST",
  "CostFilters": {
    "TagKeyValue": [ "user:harness:pr\$${PR_NUMBER}" ]
  }
}
EOF
)

notifs=$(cat <<EOF
[
  {
    "Notification": { "NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN", "Threshold": 80.0, "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "SNS", "Address": "${topic_arn}" } ]
  },
  {
    "Notification": { "NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN", "Threshold": 100.0, "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "SNS", "Address": "${topic_arn}" } ]
  }
]
EOF
)

# --- create or update ---
if aws budgets describe-budget --account-id "$ACCOUNT" --budget-name "$BUDGET_NAME" >/dev/null 2>&1; then
  aws budgets update-budget \
    --account-id "$ACCOUNT" \
    --new-budget "$spec" >/dev/null
  echo "pr-stack-budget: updated ${BUDGET_NAME} (\$${DAILY_LIMIT}/day)"
else
  aws budgets create-budget \
    --account-id "$ACCOUNT" \
    --budget "$spec" \
    --notifications-with-subscribers "$notifs" >/dev/null
  echo "pr-stack-budget: created ${BUDGET_NAME} (\$${DAILY_LIMIT}/day)"
fi

echo "pr-stack-budget: notifications -> ${topic_arn}"
echo "pr-stack-budget: NOTE — requires 'harness:pr' cost-allocation tag ACTIVE in Billing preferences."
