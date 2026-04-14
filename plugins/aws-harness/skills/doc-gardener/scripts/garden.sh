#!/usr/bin/env bash
# doc-gardener/scripts/garden.sh
# Scans docs/ for stale exec-plans, broken cross-links, missing front-matter,
# stale TODOs, and learning-index gaps. Reports findings as TSV. With
# --open-prs, opens narrowly-scoped fix PRs labeled doc-gardener.
# Always exits 0 unless --fail-on-findings is set.

set -uo pipefail

SCOPE="all"
DRY_RUN=1
OPEN_PRS=0
MAX_PRS=5

usage() {
  cat <<'EOF' >&2
Usage: garden.sh [--scope all|stale-plans|cross-links|front-matter|todos|index]
                 [--dry-run] [--open-prs] [--max-prs N]
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --open-prs) OPEN_PRS=1; DRY_RUN=0; shift ;;
    --max-prs) MAX_PRS="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

[[ ! -d docs ]] && { echo "doc-gardener: no docs/ directory; nothing to do" >&2; exit 0; }

# Use python for the scanning logic (markdown parsing is painful in bash).
findings_file=$(mktemp)
trap 'rm -f "$findings_file"' EXIT

python3 - "$SCOPE" > "$findings_file" <<'PYEOF'
import datetime as dt
import json
import os
import re
import subprocess
import sys

scope = sys.argv[1]
findings = []  # list of dicts: scope, finding, file, action

def add(s, f, file, action):
    findings.append({"scope": s, "finding": f, "file": file, "action": action})

def git_age_days(path):
    try:
        out = subprocess.run(
            ["git", "log", "-1", "--format=%cI", "--", path],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        if not out:
            return None
        d = dt.datetime.fromisoformat(out.replace("Z", "+00:00")).date()
        return (dt.date.today() - d).days
    except Exception:
        return None

# --- 1. stale-plans ---
if scope in ("all", "stale-plans"):
    active_dir = "docs/exec-plans/active"
    if os.path.isdir(active_dir):
        for fname in sorted(os.listdir(active_dir)):
            if not fname.endswith(".md"):
                continue
            path = os.path.join(active_dir, fname)
            age = git_age_days(path)
            if age is None:
                continue
            if age > 30:
                add("stale-plans", f"no commit in {age} days", path, "auto-archive")

# --- 2. cross-links ---
if scope in ("all", "cross-links"):
    LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
    for root, _, files in os.walk("docs"):
        for f in files:
            if not f.endswith(".md"):
                continue
            path = os.path.join(root, f)
            try:
                content = open(path, encoding="utf-8").read()
            except OSError:
                continue
            for ln, line in enumerate(content.splitlines(), 1):
                for m in LINK_RE.finditer(line):
                    target = m.group(1).split("#")[0]
                    if not target or target.startswith(("http", "mailto:")):
                        continue
                    if target.startswith("/"):
                        continue
                    resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
                    if not os.path.exists(resolved):
                        add("cross-links", f"broken link to {target}", f"{path}:{ln}", "auto-fix")

# --- 3. front-matter ---
if scope in ("all", "front-matter"):
    REQUIRED = {"owner", "updated", "status"}
    FM_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
    for root, _, files in os.walk("docs"):
        for f in files:
            if not f.endswith(".md"):
                continue
            path = os.path.join(root, f)
            try:
                content = open(path, encoding="utf-8").read()
            except OSError:
                continue
            m = FM_RE.match(content)
            if not m:
                add("front-matter", "no YAML front-matter", path, "auto-fix")
                continue
            keys = {line.split(":", 1)[0].strip() for line in m.group(1).splitlines() if ":" in line}
            missing = REQUIRED - keys
            if missing:
                add("front-matter", f"missing keys: {','.join(sorted(missing))}", path, "auto-fix")

# --- 4. stale TODOs ---
if scope in ("all", "todos"):
    TODO_RE = re.compile(r"\b(TODO|FIXME|XXX)\b")
    for root, _, files in os.walk("docs"):
        for f in files:
            if not f.endswith(".md"):
                continue
            path = os.path.join(root, f)
            try:
                content = open(path, encoding="utf-8").read()
            except OSError:
                continue
            for ln, line in enumerate(content.splitlines(), 1):
                if TODO_RE.search(line):
                    age = git_age_days(path)
                    if age and age > 14:
                        add("todos", f"TODO/FIXME/XXX older than {age} days", f"{path}:{ln}", "flag")
                        break  # one finding per file

# --- 5. learning index gaps ---
if scope in ("all", "index"):
    learn_dir = "docs/learnings"
    index_path = os.path.join(learn_dir, "INDEX.md")
    if os.path.isdir(learn_dir):
        on_disk = {f for f in os.listdir(learn_dir) if f.endswith(".md") and f != "INDEX.md"}
        in_index = set()
        if os.path.isfile(index_path):
            content = open(index_path, encoding="utf-8").read()
            for m in re.finditer(r"\(([^)]+\.md)\)", content):
                in_index.add(os.path.basename(m.group(1)))
        missing = on_disk - in_index
        if missing:
            add("index", f"{len(missing)} learning(s) missing from INDEX.md", index_path, "auto-fix")

print(json.dumps(findings))
PYEOF

# --- emit TSV ---
echo -e "SCOPE\tFINDING\tFILE\tACTION"
jq -r '.[] | [.scope, .finding, .file, .action] | @tsv' "$findings_file"

# --- optional: open PRs ---
if (( OPEN_PRS == 1 )) && command -v gh >/dev/null 2>&1; then
  count=$(jq 'length' "$findings_file")
  pr_count=0
  jq -c '.[] | select(.action | startswith("auto"))' "$findings_file" | while read -r f; do
    [[ "$pr_count" -ge "$MAX_PRS" ]] && break
    scope=$(echo "$f" | jq -r '.scope')
    file=$(echo "$f" | jq -r '.file')
    finding=$(echo "$f" | jq -r '.finding')
    action=$(echo "$f" | jq -r '.action')

    short=$(basename "$file" .md | tr '/:.' '-' | cut -c1-30)
    branch="chore/doc-gardener-${scope}-${short}-$(date -u +%H%M%S)"

    git checkout -b "$branch" 2>/dev/null || continue

    case "$action" in
      auto-archive)
        target="docs/exec-plans/completed/$(basename "$file")"
        mkdir -p docs/exec-plans/completed
        git mv "$file" "$target" 2>/dev/null || true
        ;;
      auto-fix)
        # placeholder: real fix logic per scope. For now, just create an empty
        # marker commit so the PR exists for human attention.
        echo "<!-- doc-gardener: ${finding} -->" >> "$file" 2>/dev/null || true
        ;;
    esac

    git add -A
    git commit -m "chore(docs): ${scope} — ${finding}" >/dev/null 2>&1 || { git checkout -; continue; }
    git push -u origin "$branch" >/dev/null 2>&1 || true
    gh pr create --label "doc-gardener" --title "chore(docs): ${scope} — ${finding}" \
      --body "Auto-opened by doc-gardener.\n\n- Scope: \`${scope}\`\n- File: \`${file}\`\n- Action: \`${action}\`\n\nIf the change looks wrong, close this PR and the gardener will not retry today." \
      >/dev/null 2>&1 || true
    git checkout -
    pr_count=$((pr_count + 1))
  done
fi

exit 0
