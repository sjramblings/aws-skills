// bedrock-cost-instrumentation — Bedrock client instantiated without
// cost-instrumentation wrapper. Golden principle P-08. Enforced from M8
// onward (harness cost-instrumentation construct ships in M8).

import * as fs from "fs";
import * as path from "path";
import { Finding, CfnTemplate } from "./lint-types";

function walk(dir: string, out: string[] = []): string[] {
  let entries: fs.Dirent[] = [];
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name === "node_modules" || e.name === "cdk.out" || e.name === ".git") continue;
      walk(p, out);
    } else if (/\.(ts|js|mjs)$/.test(e.name)) {
      out.push(p);
    }
  }
  return out;
}

export function lint(_template: CfnTemplate): Finding[] {
  const findings: Finding[] = [];
  const roots = ["src", "lib", "handlers", "lambda"];
  const files: string[] = [];
  for (const r of roots) {
    if (fs.existsSync(r)) files.push(...walk(r));
  }
  for (const file of files) {
    let content = "";
    try {
      content = fs.readFileSync(file, "utf8");
    } catch {
      continue;
    }
    // Detect raw Bedrock client usage
    const usesBedrock = /BedrockRuntimeClient|BedrockClient|@aws-sdk\/client-bedrock/.test(content);
    if (!usesBedrock) continue;
    // Allow if wrapped via helper
    const wrapped = /withCostInstrumentation\s*\(/.test(content);
    if (!wrapped) {
      findings.push({
        severity: "medium",
        lint: "bedrock-cost-instrumentation",
        resource: file,
        message: "Bedrock client instantiated without cost-instrumentation wrapper. Use withCostInstrumentation(client). See docs/references/cost-dashboard-llms.txt.",
      });
    }
  }
  return findings;
}
