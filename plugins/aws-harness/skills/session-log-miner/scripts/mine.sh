#!/usr/bin/env bash
# session-log-miner/scripts/mine.sh
# Mines ~/.claude/projects/*/*.jsonl for friction patterns. Privacy-safe:
# reads only local files, returns structured patterns + session IDs (no
# raw transcript content).
# See SKILL.md.

set -uo pipefail

DAYS=7
PROJECTS_FILTER="all"
OUTPUT="json"
THRESHOLD=3

usage() {
  cat <<'EOF' >&2
Usage: mine.sh [--days N] [--projects all|p1,p2] [--output json|tsv] [--threshold N]
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="${2:?}"; shift 2 ;;
    --projects) PROJECTS_FILTER="${2:?}"; shift 2 ;;
    --output) OUTPUT="${2:?}"; shift 2 ;;
    --threshold) THRESHOLD="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
if [[ ! -d "$PROJECTS_DIR" ]]; then
  echo "session-log-miner: $PROJECTS_DIR not found; nothing to scan" >&2
  exit 0
fi

# Hand off to python — JSONL stream parsing + pattern extraction is much
# clearer in python than bash.
python3 - "$PROJECTS_DIR" "$DAYS" "$PROJECTS_FILTER" "$OUTPUT" "$THRESHOLD" <<'PYEOF'
import datetime as dt
import hashlib
import json
import os
import re
import sys
from collections import defaultdict

projects_dir, days, projects_filter, output, threshold = sys.argv[1:6]
days = int(days)
threshold = int(threshold)

cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days)

allowed_projects = None
if projects_filter != "all":
    allowed_projects = {p.strip() for p in projects_filter.split(",") if p.strip()}

# Friction pattern detectors.
# Each detector reads a list of events and yields (pattern_type, fingerprint).
RAW_AWS_PATTERNS = [
    (r"\baws\s+cloudformation\s+describe-stack-events\b", "aws cloudformation describe-stack-events instead of cfn-stack-events"),
    (r"\baws\s+logs\s+filter-log-events\b", "aws logs filter-log-events instead of cloudwatch-query"),
    (r"\baws\s+logs\s+start-query\b", "aws logs start-query instead of cloudwatch-query"),
    (r"\baws\s+cloudtrail\s+lookup-events\b", "aws cloudtrail lookup-events instead of cloudtrail-investigator"),
]

MISSING_ACCESS_RE = re.compile(
    r"\b(I (?:don'?t|do not) have access to|I cannot (?:access|run|execute)|I'?m unable to|I lack (?:permission|access))\b",
    re.IGNORECASE,
)

def session_id_from_path(path):
    """Hash the file path so we get a stable but local-only reference."""
    return hashlib.sha1(path.encode()).hexdigest()[:12]

def parse_session(path):
    """Yield events from a JSONL file. Tolerant of malformed lines."""
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue
    except OSError:
        return

def extract_text(event):
    """Return a flat string of any 'text' fields in the event content."""
    if not isinstance(event, dict):
        return ""
    chunks = []
    msg = event.get("message", event)
    content = msg.get("content") if isinstance(msg, dict) else None
    if isinstance(content, str):
        chunks.append(content)
    elif isinstance(content, list):
        for c in content:
            if isinstance(c, dict) and c.get("type") == "text":
                chunks.append(c.get("text", ""))
    return " ".join(chunks)

def extract_tool_use(event):
    """Return (tool_name, command_or_input, error?) for a tool_use event."""
    if not isinstance(event, dict):
        return None
    msg = event.get("message", event)
    content = msg.get("content") if isinstance(msg, dict) else None
    if not isinstance(content, list):
        return None
    for c in content:
        if isinstance(c, dict) and c.get("type") == "tool_use":
            tool = c.get("name", "")
            inp = c.get("input", {})
            cmd = ""
            if isinstance(inp, dict):
                cmd = inp.get("command") or inp.get("file_path") or json.dumps(inp)[:200]
            return (tool, str(cmd))
    return None

def extract_tool_result(event):
    """Return (is_error, content_snippet) for a tool_result event."""
    if not isinstance(event, dict):
        return None
    msg = event.get("message", event)
    content = msg.get("content") if isinstance(msg, dict) else None
    if not isinstance(content, list):
        return None
    for c in content:
        if isinstance(c, dict) and c.get("type") == "tool_result":
            is_err = c.get("is_error", False)
            tc = c.get("content", "")
            if isinstance(tc, list):
                tc = " ".join(x.get("text", "") for x in tc if isinstance(x, dict))
            return (is_err, str(tc)[:300])
    return None

# --- accumulator ---
patterns = defaultdict(lambda: {
    "type": "",
    "frequency": 0,
    "sessions": set(),
    "projects_affected": set(),
    "last_seen": "",
})

sessions_scanned = 0

for project_slug in sorted(os.listdir(projects_dir)):
    if allowed_projects is not None and project_slug not in allowed_projects:
        continue
    project_path = os.path.join(projects_dir, project_slug)
    if not os.path.isdir(project_path):
        continue

    for fname in sorted(os.listdir(project_path)):
        if not fname.endswith(".jsonl"):
            continue
        full = os.path.join(project_path, fname)
        try:
            mtime = dt.datetime.fromtimestamp(os.path.getmtime(full), dt.timezone.utc)
        except OSError:
            continue
        if mtime < cutoff:
            continue

        sessions_scanned += 1
        sid = session_id_from_path(full)

        # Per-session state for retry detection
        recent_failures = []  # list of (tool, error_snippet)
        consecutive_text_only_turns = 0

        for event in parse_session(full):
            ev_type = event.get("type", "")
            text = extract_text(event)
            tool_use = extract_tool_use(event)
            tool_result = extract_tool_result(event)

            # 1. raw-aws-blob-read
            if tool_use and tool_use[0] in ("Bash", "BashOutput"):
                cmd = tool_use[1]
                for regex, fp in RAW_AWS_PATTERNS:
                    if re.search(regex, cmd):
                        key = ("raw-aws-blob-read", fp)
                        patterns[key]["type"] = "raw-aws-blob-read"
                        patterns[key]["frequency"] += 1
                        patterns[key]["sessions"].add(sid)
                        patterns[key]["projects_affected"].add(project_slug)
                        patterns[key]["last_seen"] = mtime.isoformat()
                        break

            # 2. missing-access
            if text and MISSING_ACCESS_RE.search(text):
                key = ("missing-access", "agent declared a capability gap")
                patterns[key]["type"] = "missing-access"
                patterns[key]["frequency"] += 1
                patterns[key]["sessions"].add(sid)
                patterns[key]["projects_affected"].add(project_slug)
                patterns[key]["last_seen"] = mtime.isoformat()

            # 3. repeated-tool-failure
            if tool_result and tool_result[0]:  # is_error
                err_snippet = tool_result[1][:80]
                # find the immediately-preceding tool_use to attribute
                # (simple sliding window: just record the error fingerprint)
                fp = err_snippet.lower()
                # crude: count how many times we've seen the same error in this session
                recent_failures.append(fp)
                same_count = sum(1 for f in recent_failures[-10:] if f == fp)
                if same_count >= 3:
                    key = ("repeated-tool-failure", fp[:60])
                    patterns[key]["type"] = "repeated-tool-failure"
                    patterns[key]["frequency"] += 1
                    patterns[key]["sessions"].add(sid)
                    patterns[key]["projects_affected"].add(project_slug)
                    patterns[key]["last_seen"] = mtime.isoformat()
                    recent_failures.clear()

            # 4. long-stuck-turn (text-only assistant message > 2000 chars,
            #    followed by a retry)
            if ev_type == "assistant" and not tool_use and len(text) > 2000:
                consecutive_text_only_turns += 1
                if consecutive_text_only_turns >= 2:
                    key = ("long-stuck-turn", "assistant stuck reasoning without tool calls")
                    patterns[key]["type"] = "long-stuck-turn"
                    patterns[key]["frequency"] += 1
                    patterns[key]["sessions"].add(sid)
                    patterns[key]["projects_affected"].add(project_slug)
                    patterns[key]["last_seen"] = mtime.isoformat()
                    consecutive_text_only_turns = 0
            elif tool_use:
                consecutive_text_only_turns = 0

# --- filter to threshold ---
filtered = []
for (ptype, fp), p in patterns.items():
    if p["frequency"] >= threshold:
        filtered.append({
            "type": ptype,
            "fingerprint": fp,
            "frequency": p["frequency"],
            "sessions": sorted(p["sessions"])[:10],  # cap to avoid huge output
            "projects_affected": sorted(p["projects_affected"]),
            "last_seen": p["last_seen"],
        })

filtered.sort(key=lambda p: -p["frequency"])

result = {
    "scanned_at": dt.datetime.now(dt.timezone.utc).isoformat(),
    "window_days": days,
    "projects_filter": projects_filter,
    "sessions_scanned": sessions_scanned,
    "threshold": threshold,
    "patterns": filtered,
    "summary": {
        "total_patterns": len(filtered),
        "by_type": {},
    },
}

for p in filtered:
    result["summary"]["by_type"][p["type"]] = result["summary"]["by_type"].get(p["type"], 0) + 1

if output == "tsv":
    print("TYPE\tFREQUENCY\tFINGERPRINT\tPROJECTS\tLAST_SEEN")
    for p in filtered:
        print(f"{p['type']}\t{p['frequency']}\t{p['fingerprint']}\t{','.join(p['projects_affected'])}\t{p['last_seen']}")
else:
    print(json.dumps(result, indent=2))
PYEOF

exit 0
