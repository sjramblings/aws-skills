#!/usr/bin/env bash
# golden-principles-enforcer/scripts/enforce.sh
# Diffs recent learnings against docs/golden-principles.md and proposes
# additions, sharpenings, and audit issues. Always exits 0; never auto-edits
# the principles file.
# See SKILL.md.

set -uo pipefail

LEARNINGS_DIR="docs/learnings"
PRINCIPLES_FILE="docs/golden-principles.md"
SINCE_DAYS=30
OPEN_PR=0
JSON_OUT=0

usage() {
  cat <<'EOF' >&2
Usage: enforce.sh [--learnings-dir DIR] [--principles FILE] [--since-days N]
                  [--open-pr] [--json]
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --learnings-dir) LEARNINGS_DIR="${2:?}"; shift 2 ;;
    --principles) PRINCIPLES_FILE="${2:?}"; shift 2 ;;
    --since-days) SINCE_DAYS="${2:?}"; shift 2 ;;
    --open-pr) OPEN_PR=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

[[ ! -f "$PRINCIPLES_FILE" ]] && { echo "enforce: principles file not found: $PRINCIPLES_FILE" >&2; exit 0; }
[[ ! -d "$LEARNINGS_DIR" ]] && { echo "enforce: learnings dir not found: $LEARNINGS_DIR" >&2; exit 0; }

mkdir -p .harness-cache
proposals=".harness-cache/principle-proposals.md"

# Use python for the heavy lifting — easier than bash for parsing markdown.
python3 - "$LEARNINGS_DIR" "$PRINCIPLES_FILE" "$SINCE_DAYS" "$proposals" "$JSON_OUT" <<'PYEOF'
import datetime as dt
import json
import os
import re
import sys

learnings_dir, principles_file, since_days, out_path, json_out = sys.argv[1:6]
since_days = int(since_days)
json_out = json_out == "1"

# --- parse principles ---
ROW_RE = re.compile(
    r"^\|\s*(P-\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*(yes|no|advisory)\s*\|",
    re.IGNORECASE | re.MULTILINE,
)

with open(principles_file, encoding="utf-8") as f:
    principles_text = f.read()

principles = []
for m in ROW_RE.finditer(principles_text):
    pid, principle, backing, source, advisory = m.groups()
    principles.append({
        "id": pid,
        "principle": principle.strip(),
        "backing": backing.strip(),
        "source": source.strip(),
        "advisory": advisory.lower(),
    })
existing_principle_texts = [p["principle"].lower() for p in principles]

# --- parse learnings ---
cutoff = dt.date.today() - dt.timedelta(days=since_days)
learnings = []
for fname in sorted(os.listdir(learnings_dir)):
    if not fname.endswith(".md") or fname == "INDEX.md":
        continue
    path = os.path.join(learnings_dir, fname)
    try:
        content = open(path, encoding="utf-8").read()
    except OSError:
        continue
    fm_match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not fm_match:
        continue
    fm = {}
    for line in fm_match.group(1).splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    try:
        d = dt.date.fromisoformat(fm.get("date", ""))
    except ValueError:
        continue
    if d < cutoff:
        continue

    delta_match = re.search(r"## Golden principle delta\n(.*?)(?=\n## |\Z)", content, re.DOTALL)
    lint_match = re.search(r"## Lint proposal\n(.*?)(?=\n## |\Z)", content, re.DOTALL)
    delta = delta_match.group(1).strip() if delta_match else ""
    lint = lint_match.group(1).strip() if lint_match else ""

    if delta and "TODO" not in delta and "none" not in delta.lower()[:20]:
        learnings.append({
            "file": path,
            "date": str(d),
            "title": fm.get("title", ""),
            "delta": delta,
            "lint_proposal": lint,
        })

# --- propose adds (group by similar text) ---
def normalize(s):
    return re.sub(r"[^a-z0-9 ]", " ", s.lower()).strip()

adds = []
seen_adds = set()
for L in learnings:
    # naive: each learning with non-empty delta becomes a candidate add
    delta_norm = normalize(L["delta"])[:120]
    if not delta_norm or delta_norm in seen_adds:
        continue
    # skip if very similar to an existing principle
    if any(normalize(p)[:80] in delta_norm or delta_norm in normalize(p) for p in existing_principle_texts):
        continue
    seen_adds.add(delta_norm)
    adds.append({
        "source_learning": L["file"],
        "title": L["title"],
        "delta": L["delta"][:300],
        "lint_proposal": L["lint_proposal"][:200],
    })

# --- audit backing ---
lints_dir = "tools/lints"
existing_lints = set()
if os.path.isdir(lints_dir):
    existing_lints = set(os.listdir(lints_dir))

LINT_REF_RE = re.compile(r"`([^`]+\.(?:ts|py|yml))`")
audit_issues = []
for p in principles:
    if p["advisory"] in ("yes", "advisory"):
        continue
    refs = LINT_REF_RE.findall(p["backing"])
    if not refs and not any(kw in p["backing"].lower() for kw in ["construct", "hook", "skill", ".yml"]):
        audit_issues.append(f"{p['id']}: backing cell has no lint reference and no runtime keyword")
        continue
    for r in refs:
        base = os.path.basename(r)
        if base.endswith(".yml"):
            continue  # workflow, allowed
        if base not in existing_lints:
            audit_issues.append(f"{p['id']}: references missing lint file `{base}`")

# --- output ---
result = {
    "generated_at": dt.datetime.utcnow().isoformat() + "Z",
    "since_days": since_days,
    "adds": adds,
    "sharpen": [],  # not yet implemented — needs LLM heuristics
    "audit_issues": audit_issues,
    "summary": {
        "principles_total": len(principles),
        "learnings_window": len(learnings),
        "adds_proposed": len(adds),
        "audit_issues": len(audit_issues),
    },
}

if json_out:
    print(json.dumps(result, indent=2))
else:
    out_lines = [
        f"# Principle proposals — {dt.date.today()}",
        "",
        f"_window: last {since_days} days; {len(learnings)} learning(s) considered_",
        "",
        f"## Add ({len(adds)})",
        "",
    ]
    for a in adds:
        out_lines.append(f"- **(new)** {a['title']}")
        out_lines.append(f"  - Source: `{a['source_learning']}`")
        out_lines.append(f"  - Delta: {a['delta']}")
        if a["lint_proposal"]:
            out_lines.append(f"  - Lint proposal: {a['lint_proposal']}")
        out_lines.append("")
    out_lines.append(f"## Audit issues ({len(audit_issues)})")
    out_lines.append("")
    for issue in audit_issues:
        out_lines.append(f"- {issue}")
    out_lines.append("")

    rendered = "\n".join(out_lines)
    print(rendered)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(rendered)
PYEOF

# --- optional: open draft PR ---
if (( OPEN_PR == 1 )) && command -v gh >/dev/null 2>&1; then
  if [[ -s "$proposals" ]]; then
    branch="chore/principle-proposals-$(date -u +%Y%m%d)"
    git checkout -b "$branch" 2>/dev/null || git checkout "$branch"
    cp "$proposals" "docs/principle-proposals-pending.md"
    git add "docs/principle-proposals-pending.md"
    git commit -m "chore(principles): proposal $(date -u +%Y-%m-%d)" >/dev/null 2>&1 || true
    git push -u origin "$branch" >/dev/null 2>&1 || true
    gh pr create --draft --title "chore(principles): propose updates from learnings" --body "Auto-generated by golden-principles-enforcer. Review and merge into docs/golden-principles.md." 2>/dev/null || true
  fi
fi

exit 0
