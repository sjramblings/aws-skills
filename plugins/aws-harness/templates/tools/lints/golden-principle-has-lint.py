#!/usr/bin/env python3
"""
golden-principle-has-lint — every enforced principle in golden-principles.md
must have a backing lint file under tools/lints/, OR be marked advisory.

Parses the principles table:
| ID | Principle | Backing | Source learning | Advisory? |

For each row with Advisory? = 'no', the Backing column must reference a file
that exists under tools/lints/ (or a skill name, which is allowed when the
backing is runtime not compile-time).

Emits JSON Finding[] array.
"""
from __future__ import annotations

import json
import os
import re
import sys

PRINCIPLES_FILE = "docs/golden-principles.md"
LINTS_DIR = "tools/lints"

ROW_RE = re.compile(
    r"^\|\s*(P-\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*(yes|no|advisory)\s*\|",
    re.IGNORECASE | re.MULTILINE,
)
LINT_REF_RE = re.compile(r"`([^`]+\.(?:ts|py))`")


def main() -> int:
    findings: list[dict] = []

    if not os.path.isfile(PRINCIPLES_FILE):
        print(json.dumps(findings))
        return 0

    try:
        content = open(PRINCIPLES_FILE, encoding="utf-8").read()
    except OSError as e:
        findings.append({
            "severity": "low",
            "lint": "golden-principle-has-lint",
            "resource": PRINCIPLES_FILE,
            "message": f"unreadable: {e}",
        })
        print(json.dumps(findings))
        return 0

    existing_lints = set()
    if os.path.isdir(LINTS_DIR):
        existing_lints = {f for f in os.listdir(LINTS_DIR) if f.endswith((".ts", ".py"))}

    for match in ROW_RE.finditer(content):
        pid, _principle, backing, _source, advisory = match.groups()
        if advisory.lower() in ("yes", "advisory"):
            continue

        # Scan backing cell for referenced lint file(s).
        lint_refs = LINT_REF_RE.findall(backing)
        lint_files = [os.path.basename(r) for r in lint_refs if r.endswith((".ts", ".py"))]

        # Allow backing to be a skill-name or workflow (runtime enforcement), in
        # which case no lint file is required. Detect by presence of '.yml' or
        # 'skill' keyword.
        runtime_backing = ".yml" in backing or "skill" in backing.lower() or "construct" in backing.lower() or "hook" in backing.lower()

        if not lint_files and not runtime_backing:
            findings.append({
                "severity": "low",
                "lint": "golden-principle-has-lint",
                "resource": f"{PRINCIPLES_FILE}#{pid}",
                "message": (
                    f"Principle {pid} backing cell has neither a lint file reference "
                    f"nor a runtime backing. Add a lint under tools/lints/ or mark advisory."
                ),
            })
            continue

        missing = [f for f in lint_files if f not in existing_lints and not f.endswith(".yml")]
        if missing and not runtime_backing:
            findings.append({
                "severity": "low",
                "lint": "golden-principle-has-lint",
                "resource": f"{PRINCIPLES_FILE}#{pid}",
                "message": (
                    f"Principle {pid} references missing lint(s): {', '.join(missing)}. "
                    f"Create them under {LINTS_DIR}/ or mark principle advisory."
                ),
            })

    print(json.dumps(findings))
    return 0


if __name__ == "__main__":
    sys.exit(main())
