#!/usr/bin/env bash
# cfn-stack-events/scripts/fetch.sh
# Compact view of CloudFormation stack failures. Returns TSV: TIMESTAMP, LOGICAL_ID, TYPE, STATUS, REASON.
# See SKILL.md for usage.

set -euo pipefail

STACK=""
LIMIT=20
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
SINCE="2h"
FULL=0

die() { echo "cfn-stack-events: $*" >&2; exit 2; }
usage() {
  cat <<'EOF' >&2
Usage: fetch.sh <stack-name> [--limit N] [--region REGION] [--since <N>m|h|d] [--full]

Returns a compact table of CloudFormation events where status is *_FAILED
or ResourceStatusReason is non-empty. Newest-first. Default limit 20, cap 50.
EOF
  exit 2
}

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) LIMIT="${2:?}"; shift 2 ;;
    --region) REGION="${2:?}"; shift 2 ;;
    --since) SINCE="${2:?}"; shift 2 ;;
    --full) FULL=1; shift ;;
    -h|--help) usage ;;
    --*) die "unknown flag: $1" ;;
    *)
      if [[ -z "$STACK" ]]; then STACK="$1"; else die "unexpected arg: $1"; fi
      shift ;;
  esac
done

[[ -z "$STACK" ]] && usage
[[ "$LIMIT" =~ ^[0-9]+$ ]] || die "--limit must be a positive integer"
(( LIMIT > 50 )) && LIMIT=50

# --- compute --since epoch ---
num="${SINCE%[mhd]}"
unit="${SINCE: -1}"
case "$unit" in
  m) secs=$(( num * 60 )) ;;
  h) secs=$(( num * 3600 )) ;;
  d) secs=$(( num * 86400 )) ;;
  *) die "--since must end in m, h, or d (e.g. 30m, 2h, 1d)" ;;
esac
if date -u -v-0S +%s >/dev/null 2>&1; then
  cutoff=$(date -u -v-"${secs}"S +%s)   # BSD date (macOS)
else
  cutoff=$(date -u -d "@$(( $(date -u +%s) - secs ))" +%s)  # GNU date
fi

# --- fetch events ---
region_arg=()
[[ -n "$REGION" ]] && region_arg=(--region "$REGION")

events_json=$(aws cloudformation describe-stack-events \
  --stack-name "$STACK" \
  "${region_arg[@]}" \
  --output json 2>&1) || {
  echo "$events_json" >&2
  die "describe-stack-events failed for stack '$STACK'"
}

# --- filter + format ---
# Keep only: *_FAILED status OR non-empty ResourceStatusReason, within --since window.
trunc=240
(( FULL )) && trunc=4000

printf "TIMESTAMP\tLOGICAL_ID\tTYPE\tSTATUS\tREASON\n"
printf "%s" "$events_json" | jq -r --argjson cutoff "$cutoff" --argjson limit "$LIMIT" --argjson trunc "$trunc" '
  .StackEvents
  | map(select(
      ((.Timestamp | sub("\\.[0-9]+"; "") | sub("Z$"; "+00:00") | fromdateiso8601) >= $cutoff)
      and
      ((.ResourceStatus | test("FAILED")) or ((.ResourceStatusReason // "") | length > 0))
    ))
  | .[0:$limit]
  | .[]
  | [
      .Timestamp,
      (.LogicalResourceId // "-"),
      (.ResourceType // "-"),
      (.ResourceStatus // "-"),
      ((.ResourceStatusReason // "")[0:$trunc] | gsub("[\t\n]"; " "))
    ]
  | @tsv
'
