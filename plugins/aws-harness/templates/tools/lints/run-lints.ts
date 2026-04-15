// Harness lint runner.
// Usage: npx ts-node tools/lints/run-lints.ts <path-to-cfn-template.json>
// Prints a JSON array of Finding[] on stdout.

import * as fs from "fs";
import * as path from "path";
import { Finding, CfnTemplate, LintFn } from "./lint-types";

import { lint as confusedDeputy } from "./cdk-confused-deputy";
import { lint as encryptionRequired } from "./cdk-encryption-required";
import { lint as sslOnly } from "./cdk-ssl-only";
import { lint as sqsVisibilityTimeout } from "./cdk-sqs-visibility-timeout";
import { lint as fifoMaxConcurrency } from "./cdk-fifo-maxconcurrency";
import { lint as resourceTags } from "./cdk-resource-tags";
import { lint as zodParseAtBoundary } from "./zod-parse-at-boundary";
import { lint as bedrockCostInstrumentation } from "./bedrock-cost-instrumentation";
import { lint as noCrossStackExports } from "./cdk-no-cross-stack-exports";

const lints: Array<{ name: string; fn: LintFn }> = [
  { name: "cdk-confused-deputy", fn: confusedDeputy },
  { name: "cdk-encryption-required", fn: encryptionRequired },
  { name: "cdk-ssl-only", fn: sslOnly },
  { name: "cdk-sqs-visibility-timeout", fn: sqsVisibilityTimeout },
  { name: "cdk-fifo-maxconcurrency", fn: fifoMaxConcurrency },
  { name: "cdk-resource-tags", fn: resourceTags },
  { name: "zod-parse-at-boundary", fn: zodParseAtBoundary },
  { name: "bedrock-cost-instrumentation", fn: bedrockCostInstrumentation },
  { name: "cdk-no-cross-stack-exports", fn: noCrossStackExports },
];

function main() {
  const templatePath = process.argv[2];
  if (!templatePath) {
    process.stderr.write("usage: run-lints.ts <template.json>\n");
    process.exit(2);
  }

  let template: CfnTemplate;
  try {
    template = JSON.parse(fs.readFileSync(templatePath, "utf8"));
  } catch (e: any) {
    process.stderr.write(`run-lints: failed to read ${templatePath}: ${e.message}\n`);
    process.exit(2);
  }

  const all: Finding[] = [];
  for (const { name, fn } of lints) {
    try {
      const findings = fn(template, templatePath);
      for (const f of findings) {
        all.push({ ...f, lint: f.lint || name });
      }
    } catch (e: any) {
      process.stderr.write(`run-lints: ${name} threw: ${e.message}\n`);
    }
  }

  process.stdout.write(JSON.stringify(all) + "\n");
}

main();
