#!/usr/bin/env bash
# harness-self-review.sh
# Local meta-loop runner. Mines ~/.claude/projects/*/*.jsonl for friction
# patterns and (optionally) opens GitHub issues against sjramblings/aws-skills
# with proposed harness improvements.
#
# This was originally a GitHub Actions workflow but session logs live on
# the maintainer's local machine, so a self-hosted runner was overkill.
# Run this directly, or schedule it via launchd / cron — see the
# "Scheduling" section at the bottom.
#
# Usage:
#   ./harness-self-review.sh                    # weekly defaults, dry-run
#   ./harness-self-review.sh --open-issues      # actually open GitHub issues
#   ./harness-self-review.sh --days 14          # custom window
#   ./harness-self-review.sh --threshold 5      # custom frequency floor

set -uo pipefail

# Resolve repo root from this script's location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "${REPO_ROOT}"

DAYS=7
THRESHOLD=3
OPEN_ISSUES=0
MAX_ISSUES=5
REPO="sjramblings/aws-skills"

usage() {
  cat <<'EOF' >&2
Usage: harness-self-review.sh [--days N] [--threshold N] [--open-issues]
                              [--max-issues N] [--repo owner/name]

Mines local Claude Code session logs for friction patterns and (with
--open-issues) opens GitHub issues against the harness repo with
proposed improvements. Defaults are dry-run.

Schedule weekly via launchd or cron — see the comment at the bottom of
the script.
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="${2:?}"; shift 2 ;;
    --threshold) THRESHOLD="${2:?}"; shift 2 ;;
    --open-issues) OPEN_ISSUES=1; shift ;;
    --max-issues) MAX_ISSUES="${2:?}"; shift 2 ;;
    --repo) REPO="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "harness-self-review: unknown arg $1" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$HOME/.claude/projects" ]]; then
  echo "harness-self-review: ~/.claude/projects not found; nothing to mine" >&2
  exit 0
fi

mkdir -p .harness-cache

echo "harness-self-review: mining $DAYS days of session logs (threshold=$THRESHOLD)"

bash plugins/aws-harness/skills/session-log-miner/scripts/mine.sh \
  --days "$DAYS" \
  --threshold "$THRESHOLD" \
  --output json \
  > .harness-cache/miner-output.json

PATTERN_COUNT=$(jq '.patterns | length' .harness-cache/miner-output.json)
echo "harness-self-review: ${PATTERN_COUNT} pattern(s) above threshold"

if [[ "$PATTERN_COUNT" == "0" ]]; then
  echo "harness-self-review: nothing to propose; exit clean"
  exit 0
fi

# Show TSV summary unconditionally
echo ""
echo "Patterns found:"
jq -r '.patterns[] | "  \(.frequency)x  \(.type): \(.fingerprint)"' .harness-cache/miner-output.json
echo ""

if (( OPEN_ISSUES == 1 )); then
  if ! command -v gh >/dev/null 2>&1; then
    echo "harness-self-review: gh CLI not installed; cannot open issues" >&2
    exit 2
  fi
  echo "harness-self-review: opening issues against ${REPO}..."
  bash plugins/aws-harness/skills/harness-improvement-proposer/scripts/propose.sh \
    --input .harness-cache/miner-output.json \
    --repo "$REPO" \
    --max-issues "$MAX_ISSUES"
else
  echo "harness-self-review: dry-run mode (use --open-issues to file proposals)"
  bash plugins/aws-harness/skills/harness-improvement-proposer/scripts/propose.sh \
    --input .harness-cache/miner-output.json \
    --repo "$REPO" \
    --max-issues "$MAX_ISSUES" \
    --dry-run
fi

# Append a row to the harness QUALITY_SCORE.md history table
score_file="plugins/aws-harness/docs/QUALITY_SCORE.md"
if [[ -f "$score_file" ]]; then
  week=$(date -u +%Y-W%V)
  if ! grep -q "^| ${week} |" "$score_file"; then
    echo "| ${week} | ${PATTERN_COUNT} | weekly self-review |" >> "$score_file"
    echo "harness-self-review: appended ${week} row to QUALITY_SCORE.md"
  fi
fi

exit 0

# -----------------------------------------------------------------------
# Scheduling
# -----------------------------------------------------------------------
#
# macOS (launchd) — runs every Sunday at 10:00 local time:
#
#   cp plugins/aws-harness/scripts/com.sjramblings.harness-self-review.plist \
#      ~/Library/LaunchAgents/
#   launchctl load ~/Library/LaunchAgents/com.sjramblings.harness-self-review.plist
#
# Linux (cron) — same schedule:
#
#   crontab -e
#   0 10 * * 0 cd /path/to/aws-skills && bash plugins/aws-harness/scripts/harness-self-review.sh --open-issues
#
# Manual ad-hoc run:
#
#   bash plugins/aws-harness/scripts/harness-self-review.sh --days 7 --open-issues
#
# Dry-run preview (default, no --open-issues):
#
#   bash plugins/aws-harness/scripts/harness-self-review.sh
