#!/usr/bin/env bash
# postmortem-capture/scripts/ingest-to-vcs.sh
# Best-effort push of a learning file into the VCS cross-project index.
# Local file is source of truth; this script never blocks on failure.

set -uo pipefail

NAMESPACE=""
FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="${2:-}"; shift 2 ;;
    --file) FILE="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$NAMESPACE" || -z "$FILE" || ! -f "$FILE" ]]; then
  exit 0
fi

# vcs-cli is the canonical client (M2-onwards). Fallback to noop if missing.
if ! command -v vcs >/dev/null 2>&1; then
  echo "ingest-to-vcs: vcs CLI not installed; skipping (local file is canonical)" >&2
  exit 0
fi

vcs ingest --namespace "$NAMESPACE" --file "$FILE" >/dev/null 2>&1 || {
  echo "ingest-to-vcs: ingest failed for $FILE (best-effort, non-fatal)" >&2
}
exit 0
