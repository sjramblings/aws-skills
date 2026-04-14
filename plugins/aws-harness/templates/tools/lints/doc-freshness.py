#!/usr/bin/env python3
"""
doc-freshness — active exec-plans need a progress-log entry within 7 days
or they must move to completed/. Golden principle P-15.

Scans docs/exec-plans/active/*.md and emits a JSON array of Finding[] to
stdout (matching the harness lint schema).
"""
from __future__ import annotations

import datetime as dt
import glob
import json
import os
import re
import sys

ACTIVE_DIR = "docs/exec-plans/active"
MAX_AGE_DAYS = 7

PROGRESS_LINE_RE = re.compile(
    r"^\s*[-*]\s*(\d{4}-\d{2}-\d{2})",
    re.MULTILINE,
)


def parse_latest_progress_date(content: str) -> dt.date | None:
    """Return the newest YYYY-MM-DD found in a progress-log line."""
    dates: list[dt.date] = []
    for m in PROGRESS_LINE_RE.finditer(content):
        try:
            dates.append(dt.date.fromisoformat(m.group(1)))
        except ValueError:
            continue
    return max(dates) if dates else None


def main() -> int:
    findings: list[dict] = []
    if not os.path.isdir(ACTIVE_DIR):
        print(json.dumps(findings))
        return 0

    today = dt.date.today()
    for path in sorted(glob.glob(os.path.join(ACTIVE_DIR, "*.md"))):
        try:
            content = open(path, encoding="utf-8").read()
        except OSError:
            continue
        latest = parse_latest_progress_date(content)
        if latest is None:
            findings.append({
                "severity": "medium",
                "lint": "doc-freshness",
                "resource": path,
                "message": (
                    "Active exec-plan has no dated progress-log entry. "
                    "Add one like '- 2026-04-15: <what happened>' or move to completed/."
                ),
            })
            continue
        age = (today - latest).days
        if age > MAX_AGE_DAYS:
            findings.append({
                "severity": "medium",
                "lint": "doc-freshness",
                "resource": path,
                "message": (
                    f"Active exec-plan last updated {age} days ago "
                    f"(latest progress-log: {latest}). Update or move to completed/."
                ),
            })

    print(json.dumps(findings))
    return 0


if __name__ == "__main__":
    sys.exit(main())
