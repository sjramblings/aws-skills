#!/usr/bin/env bash
# cloudtrail-investigator/scripts/investigate.sh
# Compact CloudTrail lookup-events wrapper. Returns TSV timeline.
# See SKILL.md for usage.

set -euo pipefail

USER=""
ROLE=""
SERVICE=""
EVENT=""
ERROR_CODE=""
RESOURCE=""
SINCE="1h"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
LIMIT=30
FULL=0

die() { echo "cloudtrail-investigator: $*" >&2; exit 2; }
usage() {
  cat <<'EOF' >&2
Usage: investigate.sh [--user NAME] [--role NAME] [--service SRC] [--event NAME]
                      [--error CODE] [--resource ARN] [--since <N>m|h|d]
                      [--region REGION] [--limit N] [--full]

At least one filter flag is required.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) USER="${2:?}"; shift 2 ;;
    --role) ROLE="${2:?}"; shift 2 ;;
    --service) SERVICE="${2:?}"; shift 2 ;;
    --event) EVENT="${2:?}"; shift 2 ;;
    --error) ERROR_CODE="${2:?}"; shift 2 ;;
    --resource) RESOURCE="${2:?}"; shift 2 ;;
    --since) SINCE="${2:?}"; shift 2 ;;
    --region) REGION="${2:?}"; shift 2 ;;
    --limit) LIMIT="${2:?}"; shift 2 ;;
    --full) FULL=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

# require at least one filter
if [[ -z "$USER$ROLE$SERVICE$EVENT$ERROR_CODE$RESOURCE" ]]; then
  die "at least one filter flag required"
fi

[[ "$LIMIT" =~ ^[0-9]+$ ]] || die "--limit must be integer"
(( LIMIT > 100 )) && LIMIT=100

# compute start time
num="${SINCE%[mhd]}"
unit="${SINCE: -1}"
case "$unit" in
  m) secs=$(( num * 60 )) ;;
  h) secs=$(( num * 3600 )) ;;
  d) secs=$(( num * 86400 )) ;;
  *) die "--since must end in m, h, or d" ;;
esac
(( secs > 7 * 86400 )) && die "CloudTrail lookup-events supports max 7 days"

if date -u -v-0S +%s >/dev/null 2>&1; then
  start_iso=$(date -u -v-"${secs}"S +%Y-%m-%dT%H:%M:%SZ)
else
  start_iso=$(date -u -d "@$(( $(date -u +%s) - secs ))" +%Y-%m-%dT%H:%M:%SZ)
fi

# build --lookup-attributes (CloudTrail supports at most one attribute at a time)
# We pick the most selective filter available, then post-filter the rest locally.
attr_key=""
attr_val=""
if [[ -n "$EVENT" ]];       then attr_key="EventName";    attr_val="$EVENT"
elif [[ -n "$USER" ]];      then attr_key="Username";     attr_val="$USER"
elif [[ -n "$SERVICE" ]];   then attr_key="EventSource";  attr_val="$SERVICE"
elif [[ -n "$RESOURCE" ]];  then attr_key="ResourceName"; attr_val="$RESOURCE"
fi

region_arg=()
[[ -n "$REGION" ]] && region_arg=(--region "$REGION")

lookup_args=(--start-time "$start_iso" --max-results 50)
if [[ -n "$attr_key" ]]; then
  lookup_args+=(--lookup-attributes "AttributeKey=${attr_key},AttributeValue=${attr_val}")
fi

events_json=$(aws cloudtrail lookup-events "${lookup_args[@]}" "${region_arg[@]}" --output json 2>&1) || {
  echo "$events_json" >&2
  die "lookup-events failed"
}

trunc=200
(( FULL )) && trunc=4000

echo -e "TIMESTAMP\tPRINCIPAL\tEVENT_SOURCE\tEVENT_NAME\tERROR\tMESSAGE"

echo "$events_json" | jq -r \
  --arg role "$ROLE" \
  --arg error_code "$ERROR_CODE" \
  --arg resource "$RESOURCE" \
  --argjson limit "$LIMIT" \
  --argjson trunc "$trunc" '
  .Events
  | map(
      . as $ev
      | (.CloudTrailEvent | fromjson) as $raw
      | select(
          ($role == "" or ((($raw.userIdentity.arn // "") | contains($role))))
          and
          ($error_code == "" or (($raw.errorCode // "") == $error_code))
          and
          ($resource == "" or (($raw.resources // []) | map(.ARN // "") | any(. == $resource)))
        )
      | {
          ts: $raw.eventTime,
          principal: ($raw.userIdentity.arn // $raw.userIdentity.principalId // "-"),
          source: ($raw.eventSource // "-"),
          name: ($raw.eventName // "-"),
          err: ($raw.errorCode // "-"),
          msg: (($raw.errorMessage // "-")[0:$trunc] | gsub("[\t\n]"; " "))
        }
    )
  | sort_by(.ts) | reverse
  | .[0:$limit]
  | .[]
  | [.ts, .principal, .source, .name, .err, .msg]
  | @tsv
'
