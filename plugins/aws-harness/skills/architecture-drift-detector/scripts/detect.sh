#!/usr/bin/env bash
# architecture-drift-detector/scripts/detect.sh
# Diffs docs/ARCHITECTURE.md (mermaid + components table) against
# cdk synth output. Reports drift as TSV.
# See SKILL.md.

set -uo pipefail

APP="./cdk"
DOC="docs/ARCHITECTURE.md"
JSON_OUT=0
FAIL_ON_DRIFT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP="${2:?}"; shift 2 ;;
    --doc) DOC="${2:?}"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    --fail-on-drift) FAIL_ON_DRIFT=1; shift ;;
    *) shift ;;
  esac
done

if [[ ! -f "$DOC" ]]; then
  echo "architecture-drift-detector: $DOC not found; nothing to diff" >&2
  exit 0
fi

# Ensure synth is fresh
if [[ -d "$APP" ]] && [[ ! -d "$APP/cdk.out" || "$APP/cdk.json" -nt "$APP/cdk.out" ]]; then
  ( cd "$APP" && npx cdk synth --quiet >/dev/null 2>&1 ) || {
    echo "architecture-drift-detector: cdk synth failed" >&2
    exit 0
  }
fi

# Collect synthesized resources
templates=()
if [[ -d "$APP/cdk.out" ]]; then
  while IFS= read -r -d '' f; do
    templates+=("$f")
  done < <(find "$APP/cdk.out" -name '*.template.json' -print0 2>/dev/null)
fi

if [[ ${#templates[@]} -eq 0 ]]; then
  echo "architecture-drift-detector: no cdk.out templates; nothing to diff" >&2
  exit 0
fi

python3 - "$DOC" "$JSON_OUT" "${templates[@]}" <<'PYEOF'
import json
import re
import sys

doc_path = sys.argv[1]
json_out = sys.argv[2] == "1"
template_paths = sys.argv[3:]

INTERESTING_TYPES = {
    "AWS::Lambda::Function",
    "AWS::SQS::Queue",
    "AWS::SNS::Topic",
    "AWS::S3::Bucket",
    "AWS::DynamoDB::Table",
    "AWS::ApiGateway::RestApi",
    "AWS::ApiGatewayV2::Api",
    "AWS::StepFunctions::StateMachine",
    "AWS::Events::Rule",
    "AWS::KMS::Key",
}

# --- code side ---
code_components = {}  # logical_id -> cfn_type
for path in template_paths:
    try:
        tpl = json.load(open(path, encoding="utf-8"))
    except Exception:
        continue
    for lid, res in (tpl.get("Resources") or {}).items():
        t = res.get("Type", "")
        if t in INTERESTING_TYPES:
            code_components[lid] = t

# --- doc side ---
try:
    doc_text = open(doc_path, encoding="utf-8").read()
except OSError:
    doc_text = ""

doc_components = {}  # logical_id -> declared_type (may be None)

# Mermaid: capture node IDs inside ```mermaid ... ``` fences
mermaid_blocks = re.findall(r"```mermaid\n(.*?)\n```", doc_text, re.DOTALL)
NODE_RE = re.compile(r"^\s*([A-Z][A-Za-z0-9_]+)\s*[\[\(\{]", re.MULTILINE)
for block in mermaid_blocks:
    for nid in NODE_RE.findall(block):
        doc_components.setdefault(nid, None)

# Components table
table_match = re.search(
    r"##\s+Components\s*\n\n?\|.*?\|\s*\n\|[\s\-:|]+\|\s*\n((?:\|.*\|\s*\n?)+)",
    doc_text,
)
if table_match:
    for row in table_match.group(1).strip().splitlines():
        parts = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(parts) >= 3:
            lid = parts[0]
            t = parts[2]
            if lid and not lid.startswith("_"):
                doc_components[lid] = t if t else None

# --- diff ---
findings = []
code_ids = set(code_components.keys())
doc_ids = set(doc_components.keys())

for lid in sorted(code_ids - doc_ids):
    findings.append({
        "kind": "in-code-only",
        "logical_id": lid,
        "doc_type": "-",
        "code_type": code_components[lid],
        "note": "new resource not in ARCHITECTURE.md",
    })

for lid in sorted(doc_ids - code_ids):
    findings.append({
        "kind": "in-doc-only",
        "logical_id": lid,
        "doc_type": doc_components.get(lid) or "-",
        "code_type": "-",
        "note": "doc lists a component absent from code",
    })

for lid in sorted(code_ids & doc_ids):
    declared = doc_components.get(lid)
    actual = code_components[lid]
    if declared and declared != "-" and declared != actual:
        findings.append({
            "kind": "type-mismatch",
            "logical_id": lid,
            "doc_type": declared,
            "code_type": actual,
            "note": "doc and code disagree on type",
        })

if json_out:
    print(json.dumps({"findings": findings, "summary": {
        "in_code_only": sum(1 for f in findings if f["kind"] == "in-code-only"),
        "in_doc_only": sum(1 for f in findings if f["kind"] == "in-doc-only"),
        "type_mismatch": sum(1 for f in findings if f["kind"] == "type-mismatch"),
    }}, indent=2))
else:
    print("KIND\tLOGICAL_ID\tDOC_TYPE\tCODE_TYPE\tNOTE")
    for f in findings:
        print(f"{f['kind']}\t{f['logical_id']}\t{f['doc_type']}\t{f['code_type']}\t{f['note']}")

# exit code via stderr marker
if findings:
    sys.stderr.write(f"DRIFT_COUNT={len(findings)}\n")
PYEOF

# --- fail-on-drift ---
if (( FAIL_ON_DRIFT == 1 )); then
  # Re-run quietly to count
  count=$(python3 - "$DOC" 1 "${templates[@]}" 2>/dev/null <<'PYEOF' | jq '.findings | length' 2>/dev/null || echo 0
import json, re, sys
doc_path = sys.argv[1]
json_out = sys.argv[2] == "1"
template_paths = sys.argv[3:]
INTERESTING={"AWS::Lambda::Function","AWS::SQS::Queue","AWS::SNS::Topic","AWS::S3::Bucket","AWS::DynamoDB::Table","AWS::ApiGateway::RestApi","AWS::ApiGatewayV2::Api","AWS::StepFunctions::StateMachine","AWS::Events::Rule","AWS::KMS::Key"}
code={}
for p in template_paths:
    try:
        t=json.load(open(p))
    except: continue
    for lid,res in (t.get("Resources") or {}).items():
        if res.get("Type","") in INTERESTING:
            code[lid]=res["Type"]
try:
    doc=open(doc_path).read()
except: doc=""
mermaid=re.findall(r"```mermaid\n(.*?)\n```",doc,re.DOTALL)
NODE=re.compile(r"^\s*([A-Z][A-Za-z0-9_]+)\s*[\[\(\{]",re.MULTILINE)
docids=set()
for b in mermaid:
    for nid in NODE.findall(b): docids.add(nid)
m=re.search(r"##\s+Components\s*\n\n?\|.*?\|\s*\n\|[\s\-:|]+\|\s*\n((?:\|.*\|\s*\n?)+)",doc)
if m:
    for row in m.group(1).strip().splitlines():
        parts=[c.strip() for c in row.strip().strip("|").split("|")]
        if len(parts)>=3 and parts[0] and not parts[0].startswith("_"): docids.add(parts[0])
findings=len((set(code)-docids)|(docids-set(code)))
print(json.dumps({"findings": [None]*findings}))
PYEOF
)
  if (( count > 0 )); then
    echo "architecture-drift-detector: ${count} drift finding(s)" >&2
    exit 1
  fi
fi
exit 0
