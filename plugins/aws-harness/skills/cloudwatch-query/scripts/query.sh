#!/usr/bin/env bash
# cloudwatch-query/scripts/query.sh
# Compact CloudWatch Logs Insights wrapper. Input is a LogQL-style mini-DSL:
#   "<log-group-or-alias> [level=X] [contains=Y] [status=Z] [function=F]
#    [request_id=R] [last=<N><unit>] [limit=N] [group_by=<field>]"
# Output: TSV table (COUNT, FIRST_SEEN, LAST_SEEN, SAMPLE_MESSAGE).
# See SKILL.md for usage.

set -euo pipefail

DSL="${1:-}"
[[ -z "$DSL" ]] && { echo "usage: query.sh \"<dsl>\"" >&2; exit 2; }

die() { echo "cloudwatch-query: $*" >&2; exit 2; }

# --- parse DSL ---
# First token is the log group (or function= alias). Rest are key=value pairs.
# Supports quoted values: contains="out of memory".
log_group=""
level=""
contains=""
status=""
request_id=""
last="15m"
limit=1000
group_by="fingerprint"

# Tokenize respecting double-quoted values.
# shellcheck disable=SC2206
read -ra tokens <<<"$(echo "$DSL" | sed -E 's/([a-z_]+)="([^"]*)"/\1=\x01\2\x01/g')"

for t in "${tokens[@]}"; do
  case "$t" in
    *=*)
      k="${t%%=*}"
      v="${t#*=}"
      v="${v//$'\x01'/}"  # strip placeholder
      case "$k" in
        level)       level="$v" ;;
        contains)    contains="$v" ;;
        status)      status="$v" ;;
        function)    log_group="/aws/lambda/$v" ;;
        request_id)  request_id="$v" ;;
        last)        last="$v" ;;
        limit)       limit="$v" ;;
        group_by)    group_by="$v" ;;
        *) die "unknown DSL key: $k" ;;
      esac
      ;;
    *)
      if [[ -z "$log_group" ]]; then log_group="$t"; else die "unexpected token: $t"; fi
      ;;
  esac
done

[[ -z "$log_group" ]] && die "log group required (positional or function=NAME)"
[[ "$limit" =~ ^[0-9]+$ ]] || die "limit must be integer"
(( limit > 10000 )) && limit=10000

# --- compute --last epoch window ---
num="${last%[mhd]}"
unit="${last: -1}"
case "$unit" in
  m) secs=$(( num * 60 )) ;;
  h) secs=$(( num * 3600 )) ;;
  d) secs=$(( num * 86400 )) ;;
  *) die "last= must end in m|h|d (e.g. 15m, 1h, 1d)" ;;
esac
now_epoch=$(date -u +%s)
start_epoch=$(( now_epoch - secs ))

# --- build Insights query string ---
# fields @timestamp, @message, @logStream
# | filter @message like /.../
# | sort @timestamp desc
# | limit N
filters=()
if [[ -n "$level" ]]; then
  # Case-insensitive LIKE
  lvl_upper=$(echo "$level" | tr '[:lower:]' '[:upper:]')
  filters+=("@message like /${lvl_upper}/")
fi
if [[ -n "$contains" ]]; then
  # Escape slashes
  esc_contains=${contains//\//\\/}
  filters+=("@message like /${esc_contains}/")
fi
if [[ -n "$status" ]]; then
  case "$status" in
    5xx) filters+=('@message like /5[0-9][0-9]/') ;;
    4xx) filters+=('@message like /4[0-9][0-9]/') ;;
    *)   filters+=("@message like /${status}/") ;;
  esac
fi
if [[ -n "$request_id" ]]; then
  filters+=("@requestId = '${request_id}'")
fi

filter_clause=""
if [[ ${#filters[@]} -gt 0 ]]; then
  filter_clause="| filter $(printf '%s | filter ' "${filters[@]}")"
  filter_clause="${filter_clause% | filter }"
fi

insights_query="fields @timestamp, @message, @logStream ${filter_clause} | sort @timestamp desc | limit ${limit}"

# --- start query ---
query_id=$(aws logs start-query \
  --log-group-name "$log_group" \
  --start-time "$start_epoch" \
  --end-time "$now_epoch" \
  --query-string "$insights_query" \
  --query 'queryId' \
  --output text 2>&1) || {
    echo "$query_id" >&2
    die "start-query failed for log group '$log_group'"
  }

# --- poll for results ---
attempts=0
status_val="Running"
while [[ "$status_val" == "Running" || "$status_val" == "Scheduled" ]]; do
  (( attempts++ ))
  if (( attempts > 30 )); then
    die "query timed out after 30 polls"
  fi
  sleep 1
  result_json=$(aws logs get-query-results --query-id "$query_id" --output json)
  status_val=$(echo "$result_json" | jq -r '.status')
done

if [[ "$status_val" != "Complete" ]]; then
  die "query ended in status: $status_val"
fi

# --- group + collapse ---
# Strip request-ids, UUIDs, timestamps from messages to fingerprint duplicates.
# Print TSV: COUNT, FIRST_SEEN, LAST_SEEN, SAMPLE_MESSAGE (first 200 chars).
echo -e "COUNT\tFIRST_SEEN\tLAST_SEEN\tSAMPLE_MESSAGE"

echo "$result_json" | jq -r '
  .results[]
  | map({ (.field): .value }) | add
  | select(.["@message"] != null)
  | [.["@timestamp"], .["@message"]]
  | @tsv
' | awk -F'\t' -v limit=20 '
  {
    ts = $1
    msg = $2
    fp = msg
    # strip UUIDs
    gsub(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/, "<uuid>", fp)
    # strip request IDs (hex 32+)
    gsub(/[0-9a-f]{16,}/, "<hex>", fp)
    # strip ISO timestamps
    gsub(/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z?/, "<ts>", fp)
    # strip numbers >= 4 digits (e.g. ports, big IDs)
    gsub(/[0-9]{4,}/, "<n>", fp)
    # truncate fingerprint key
    key = substr(fp, 1, 120)
    if (!(key in count)) {
      count[key] = 0
      first[key] = ts
      sample[key] = substr(msg, 1, 200)
    }
    count[key]++
    last[key] = ts
  }
  END {
    # sort by count desc
    n = 0
    for (k in count) {
      keys[++n] = k
    }
    # insertion sort (n is small — top 20)
    for (i = 2; i <= n; i++) {
      j = i
      while (j > 1 && count[keys[j-1]] < count[keys[j]]) {
        tmp = keys[j]; keys[j] = keys[j-1]; keys[j-1] = tmp
        j--
      }
    }
    out = (n > limit) ? limit : n
    for (i = 1; i <= out; i++) {
      k = keys[i]
      # escape tabs/newlines in sample
      s = sample[k]
      gsub(/[\t\n]/, " ", s)
      printf "%d\t%s\t%s\t%s\n", count[k], first[k], last[k], s
    }
  }
'
