// zod-parse-at-boundary — handler accesses event.body without Zod parse.
// Golden principle P-07. Source: VCS ULID lowercasing bug #3.
// This lint is source-file based (grep-style), not CFN template based.

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
  const handlerDirs = ["src/handlers", "src/functions", "lambda", "handlers"];
  const searched: string[] = [];
  for (const d of handlerDirs) {
    if (fs.existsSync(d)) searched.push(...walk(d));
  }
  if (searched.length === 0) return findings;

  for (const file of searched) {
    let content = "";
    try {
      content = fs.readFileSync(file, "utf8");
    } catch {
      continue;
    }
    const usesEventBody = /\bevent\.body\b/.test(content);
    if (!usesEventBody) continue;
    const hasZodParse = /\bz(?:\.object|\.record|\.array|\.string|\.number|\.union|\.discriminatedUnion)|\bZod\b|\.parse\(|\.safeParse\(/.test(content);
    if (!hasZodParse) {
      findings.push({
        severity: "medium",
        lint: "zod-parse-at-boundary",
        resource: file,
        message: `Handler reads event.body without Zod parse. Parse at boundary. See docs/references/parse-at-boundary-llms.txt.`,
      });
    }
  }
  return findings;
}
