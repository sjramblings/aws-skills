#!/usr/bin/env bash
# harness-improvement-proposer/scripts/propose.sh
# Takes session-log-miner JSON (stdin or --input), clusters into proposals,
# and opens GitHub issues labeled harness-self-improvement against the
# aws-skills repo. Never opens PRs — human triage required.
# See SKILL.md.

set -uo pipefail

INPUT_FILE=""
REPO="sjramblings/aws-skills"
DRY_RUN=0
MIN_FREQ=3
MAX_ISSUES=5

usage() {
  cat <<'EOF' >&2
Usage: propose.sh [--input PATH] [--repo owner/name] [--dry-run]
                  [--min-frequency N] [--max-issues N]

Reads miner JSON from stdin or --input, opens deduped issues.
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT_FILE="${2:?}"; shift 2 ;;
    --repo) REPO="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --min-frequency) MIN_FREQ="${2:?}"; shift 2 ;;
    --max-issues) MAX_ISSUES="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

# Load miner JSON
if [[ -n "$INPUT_FILE" ]]; then
  [[ ! -f "$INPUT_FILE" ]] && { echo "propose: input file not found: $INPUT_FILE" >&2; exit 0; }
  miner_json=$(cat "$INPUT_FILE")
else
  miner_json=$(cat)
fi

if ! echo "$miner_json" | jq -e '.patterns' >/dev/null 2>&1; then
  echo "propose: input does not look like miner output (no .patterns field)" >&2
  exit 0
fi

mkdir -p .harness-cache
history_file=".harness-cache/proposals-history.json"
[[ ! -f "$history_file" ]] && echo '{"opened": []}' > "$history_file"

# Pre-fetch existing harness-self-improvement issues to dedupe
existing_titles=""
if (( DRY_RUN == 0 )) && command -v gh >/dev/null 2>&1; then
  existing_titles=$(gh issue list --repo "$REPO" --label "harness-self-improvement" --state open --limit 100 --json title --jq '.[].title' 2>/dev/null || echo "")
fi

# Iterate patterns
opened=0
echo "$miner_json" | jq -c --argjson min "$MIN_FREQ" '.patterns[] | select(.frequency >= $min)' | while read -r pat; do
  if (( opened >= MAX_ISSUES )); then
    echo "propose: max-issues cap ($MAX_ISSUES) reached" >&2
    break
  fi

  ptype=$(echo "$pat" | jq -r '.type')
  fp=$(echo "$pat" | jq -r '.fingerprint')
  freq=$(echo "$pat" | jq -r '.frequency')
  last=$(echo "$pat" | jq -r '.last_seen')
  projects=$(echo "$pat" | jq -r '.projects_affected | join(", ")')
  sessions=$(echo "$pat" | jq -r '.sessions[0:3] | map("- " + .) | join("\n")')

  title="[harness-self-improvement] ${ptype}: ${fp}"

  # Dedupe
  if [[ -n "$existing_titles" ]] && echo "$existing_titles" | grep -Fxq "$title"; then
    echo "propose: skip (already open): $title" >&2
    continue
  fi

  # Decide proposed fix type + suggestion
  case "$ptype" in
    raw-aws-blob-read)
      fix_type="skill-upgrade"
      if [[ "$fp" == *"cloudwatch-query"* ]]; then
        suggestion="The \`cloudwatch-query\` skill (M1, \`plugins/aws-harness/skills/cloudwatch-query/SKILL.md\`) is being bypassed. Tighten the \`description\` field to explicitly include phrases the agent is using (e.g. 'filter log events', 'search logs', 'find errors in logs'). If that doesn't catch it, audit the \`allowed-tools\` matchers."
      elif [[ "$fp" == *"cfn-stack-events"* ]]; then
        suggestion="The \`cfn-stack-events\` skill (M1) is being bypassed. Tighten its description to trigger on 'describe stack events', 'cfn errors', 'why did deploy fail'."
      elif [[ "$fp" == *"cloudtrail-investigator"* ]]; then
        suggestion="The \`cloudtrail-investigator\` skill (M1) is being bypassed. Tighten its description for 'lookup-events', 'audit trail', 'who called'."
      else
        suggestion="A raw AWS API call is being made directly instead of through a harness legibility wrapper. Identify the missing wrapper and add the corresponding skill, or tighten an existing one."
      fi
      ;;
    repeated-tool-failure)
      fix_type="new-lint OR skill-upgrade"
      suggestion="Same tool error fingerprint repeating ≥3 times. If structural (always fails for the same reason), add a lint to catch it at synth/commit time. If the wrapper is wrong, fix the abstraction."
      ;;
    long-stuck-turn)
      fix_type="new-reference-doc"
      suggestion="Agent is reasoning in long text-only turns instead of reaching for tools. The fix is grounding: add a \`docs/references/<topic>-llms.txt\` reference doc and link it from \`AGENTS.md\` so the agent has compact context to act on."
      ;;
    missing-access)
      fix_type="new-skill OR hook-change"
      suggestion="Agent declared a capability gap. Either add the missing skill or widen \`allowed-tools\` on an existing one."
      ;;
    aborted-tool-call)
      fix_type="hook-change OR new-reference-doc"
      suggestion="User rejected a tool call. Narrow the matcher (so the agent doesn't try this in the wrong context) or add a reference doc explaining when the tool is and isn't appropriate."
      ;;
    agents-md-miss)
      fix_type="new-reference-doc"
      suggestion="Agent read \`AGENTS.md\` then read a doc not linked from it. Add the link to the AGENTS.md map (Lopopolo: AGENTS.md is the table of contents)."
      ;;
    *)
      fix_type="investigate"
      suggestion="Unknown friction pattern type. Investigate manually."
      ;;
  esac

  body=$(cat <<EOF
## Friction pattern detected

- **Type**: \`${ptype}\`
- **Frequency**: ${freq} occurrences across distinct sessions
- **Projects affected**: ${projects}
- **Last seen**: ${last}
- **Fingerprint**: \`${fp}\`

## Exemplar sessions (local hashes — Steve can resolve)

${sessions}

## Proposed fix

**Type**: \`${fix_type}\`

${suggestion}

## Acceptance criteria

- This pattern has frequency 0 in next week's \`session-log-miner\` run, OR
- The pattern's frequency drops by ≥50%

---
_Auto-generated by harness-improvement-proposer (M9). Issue, not PR — human triage required. Do not auto-merge a fix without verifying the next mine reflects it._
EOF
)

  if (( DRY_RUN == 1 )); then
    echo "=== DRY RUN ==="
    echo "title: $title"
    echo "body:"
    echo "$body"
    echo "==============="
    opened=$((opened + 1))
    continue
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "propose: gh CLI not installed; skipping issue creation" >&2
    continue
  fi

  if gh issue create --repo "$REPO" \
       --label "harness-self-improvement" --label "source:session-logs" \
       --title "$title" --body "$body" >/dev/null 2>&1; then
    echo "propose: opened issue: $title" >&2
    opened=$((opened + 1))
    # record in history
    jq --arg t "$title" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.opened += [{"title":$t,"opened_at":$ts}]' "$history_file" \
      > "${history_file}.tmp" && mv "${history_file}.tmp" "$history_file"
  else
    echo "propose: failed to open issue: $title" >&2
  fi
done

exit 0
