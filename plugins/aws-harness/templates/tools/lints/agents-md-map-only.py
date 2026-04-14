#!/usr/bin/env python3
"""
agents-md-map-only — AGENTS.md must stay a MAP (links only, under 150 lines).
Golden principle P-14. Lopopolo: "AGENTS.md as table of contents."

Heuristic:
- total non-blank lines <= 150
- at least 30% of non-blank lines contain a markdown link `[...](...)`
- no fenced code blocks that run more than 30 lines (no encyclopedia dumps)

Emits JSON Finding[] array to stdout.
"""
from __future__ import annotations

import json
import os
import re
import sys

LIMIT_LINES = 150
LINK_RATIO = 0.30
CODE_BLOCK_MAX = 30
LINK_RE = re.compile(r"\[[^\]]+\]\([^)]+\)")


def main() -> int:
    findings: list[dict] = []
    path = "AGENTS.md"
    if not os.path.isfile(path):
        print(json.dumps(findings))
        return 0

    try:
        raw = open(path, encoding="utf-8").read()
    except OSError as e:
        findings.append({
            "severity": "low",
            "lint": "agents-md-map-only",
            "resource": path,
            "message": f"AGENTS.md unreadable: {e}",
        })
        print(json.dumps(findings))
        return 0

    lines = raw.splitlines()
    non_blank = [ln for ln in lines if ln.strip()]

    # (1) line budget
    if len(non_blank) > LIMIT_LINES:
        findings.append({
            "severity": "low",
            "lint": "agents-md-map-only",
            "resource": path,
            "message": (
                f"AGENTS.md has {len(non_blank)} non-blank lines "
                f"(budget: {LIMIT_LINES}). It must be a MAP, not an encyclopedia. "
                "Move content into docs/ and link to it."
            ),
        })

    # (2) link density
    link_lines = sum(1 for ln in non_blank if LINK_RE.search(ln))
    if non_blank:
        ratio = link_lines / len(non_blank)
        if ratio < LINK_RATIO:
            findings.append({
                "severity": "low",
                "lint": "agents-md-map-only",
                "resource": path,
                "message": (
                    f"AGENTS.md link density {ratio:.0%} < {int(LINK_RATIO * 100)}%. "
                    "Keep AGENTS.md a table of contents: links > prose."
                ),
            })

    # (3) big fenced code blocks
    in_code = False
    code_start = 0
    for i, ln in enumerate(lines, 1):
        if ln.lstrip().startswith("```"):
            if in_code:
                size = i - code_start
                if size > CODE_BLOCK_MAX:
                    findings.append({
                        "severity": "low",
                        "lint": "agents-md-map-only",
                        "resource": path,
                        "message": (
                            f"Fenced code block at line {code_start} spans {size} lines "
                            f"(budget: {CODE_BLOCK_MAX}). Move to docs/references/."
                        ),
                    })
                in_code = False
            else:
                in_code = True
                code_start = i

    print(json.dumps(findings))
    return 0


if __name__ == "__main__":
    sys.exit(main())
