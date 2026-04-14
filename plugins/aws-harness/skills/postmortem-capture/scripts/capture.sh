#!/usr/bin/env bash
# postmortem-capture/scripts/capture.sh
# Writes docs/learnings/<slug>.md with the 5-whys schema. Best-effort
# VCS ingest. Always exits 0 so a hook never blocks the real workflow.
# See SKILL.md.

set -uo pipefail

TITLE=""
SLUG=""
PROJECT="${HARNESS_PROJECT:-}"
SESSION="${CLAUDE_SESSION_ID:-unknown}"
SOURCE="${CAPTURE_SOURCE:-manual}"
SYMPTOM=""
ROOT_CAUSE=""
DETECTION_GAP=""
FIX=""
PRINCIPLE_DELTA=""
LINT_PROPOSAL=""
SEVERITY="medium"
EVIDENCE_FILE=""

usage() {
  cat <<'EOF' >&2
Usage: capture.sh --title "..." [--slug short-slug] [--project name]
                  [--session ID] [--source cdk-deploy-failed|...]
                  [--symptom TEXT] [--root-cause TEXT] [--detection-gap TEXT]
                  [--fix TEXT] [--principle-delta TEXT] [--lint-proposal TEXT]
                  [--severity low|medium|high|critical]
                  [--evidence path/to/cfn-events.tsv]

Writes docs/learnings/<date>-<slug>.md and appends to docs/learnings/INDEX.md.
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="${2:-}"; shift 2 ;;
    --slug) SLUG="${2:-}"; shift 2 ;;
    --project) PROJECT="${2:-}"; shift 2 ;;
    --session) SESSION="${2:-}"; shift 2 ;;
    --source) SOURCE="${2:-}"; shift 2 ;;
    --symptom) SYMPTOM="${2:-}"; shift 2 ;;
    --root-cause) ROOT_CAUSE="${2:-}"; shift 2 ;;
    --detection-gap) DETECTION_GAP="${2:-}"; shift 2 ;;
    --fix) FIX="${2:-}"; shift 2 ;;
    --principle-delta) PRINCIPLE_DELTA="${2:-}"; shift 2 ;;
    --lint-proposal) LINT_PROPOSAL="${2:-}"; shift 2 ;;
    --severity) SEVERITY="${2:-}"; shift 2 ;;
    --evidence) EVIDENCE_FILE="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "postmortem-capture: unknown arg $1" >&2; exit 0 ;;
  esac
done

if [[ -z "$TITLE" ]]; then
  echo "postmortem-capture: --title required" >&2
  exit 0
fi

# Resolve project name from .harness-manifest.json if not provided
if [[ -z "$PROJECT" && -f .harness-manifest.json ]]; then
  PROJECT=$(jq -r '.bootstrap.project_name // "unknown"' .harness-manifest.json 2>/dev/null || echo "unknown")
fi
[[ -z "$PROJECT" ]] && PROJECT="unknown"

# Auto-derive slug from title if missing
if [[ -z "$SLUG" ]]; then
  SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' \
    | cut -c1-60)
fi

DATE=$(date -u +%Y-%m-%d)
filename="${DATE}-${SLUG}.md"
filepath="docs/learnings/${filename}"

# Ensure target dir exists
mkdir -p docs/learnings

# Don't clobber an existing file — append a counter suffix
counter=1
while [[ -e "$filepath" ]]; do
  filepath="docs/learnings/${DATE}-${SLUG}-${counter}.md"
  counter=$((counter + 1))
done

# Embed evidence (compact) if a file was provided
evidence_block=""
if [[ -n "$EVIDENCE_FILE" && -f "$EVIDENCE_FILE" ]]; then
  evidence_block=$'\n```\n'"$(head -30 "$EVIDENCE_FILE")"$'\n```\n'
fi

# Write the learning file
cat > "$filepath" <<EOF
---
title: ${TITLE}
date: ${DATE}
project: ${PROJECT}
session_id: ${SESSION}
source: ${SOURCE}
status: open
severity: ${SEVERITY}
labels: []
---

## Symptom

${SYMPTOM:-_TODO: one paragraph, reproducible from this description alone._}
${evidence_block}

## Root cause

${ROOT_CAUSE:-_TODO: apply 5-whys until you reach a system property you can change._}

## Detection gap

${DETECTION_GAP:-_TODO: what should have caught this earlier? Missing lint? Skill not invoked? Doc out of date?_}

## Fix

${FIX:-_TODO: file paths + commit SHAs once landed._}

## Golden principle delta

${PRINCIPLE_DELTA:-_TODO: new principle proposed, OR existing principle to sharpen, OR 'none — one-off'._}

## Lint proposal

${LINT_PROPOSAL:-_TODO: specific lint that would catch this at synth/commit time, OR explain why no lint is feasible._}

## Cross-project links

- VCS namespace: \`harness/learnings/${PROJECT}\`
- Related learnings: _none yet_
EOF

# Append to INDEX.md (skip header lines)
index="docs/learnings/INDEX.md"
if [[ -f "$index" ]]; then
  # Add row under "## Entries" if a marker exists, otherwise append
  if grep -q "^## Entries" "$index"; then
    # Insert immediately after the "## Entries" line
    tmp=$(mktemp)
    awk -v row="- [${DATE}](${filename}) — ${TITLE} (${SEVERITY})" '
      { print }
      /^## Entries/ && !done { print ""; print row; done=1 }
    ' "$index" > "$tmp" && mv "$tmp" "$index"
  else
    printf "\n- [%s](%s) — %s (%s)\n" "$DATE" "$filename" "$TITLE" "$SEVERITY" >> "$index"
  fi
fi

echo "postmortem-capture: wrote ${filepath}"

# Best-effort VCS ingest
ingest_script="$(dirname "$0")/ingest-to-vcs.sh"
if [[ -x "$ingest_script" ]]; then
  bash "$ingest_script" --namespace "harness/learnings/${PROJECT}" --file "$filepath" || true
fi

exit 0
