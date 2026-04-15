// cdk-no-cross-stack-exports — flags any CloudFormation Export (producer
// side) or Fn::ImportValue (consumer side) in synthesized templates.
// Both create cross-stack bindings that deadlock updates.
//
// Golden principle P-10.
// Source: EdgeSignal-Frontend / EdgeSignal-Api export deadlock
// (2026-04-15). `ExportsOutputRefUserPool6BA7E5F296FD7236` pinned the
// Api stack because Frontend still held the import.
//
// Remediation: docs/references/cross-stack-ssm-llms.txt

import { Finding, CfnTemplate, CfnResource } from "./lint-types";

function hasImportValue(value: any, path: string[] = []): string[] {
  // Depth-first walk — returns the JSON path of any Fn::ImportValue found.
  if (!value || typeof value !== "object") return [];
  if (Array.isArray(value)) {
    const hits: string[] = [];
    for (let i = 0; i < value.length; i++) {
      hits.push(...hasImportValue(value[i], [...path, String(i)]));
    }
    return hits;
  }
  const hits: string[] = [];
  for (const [k, v] of Object.entries(value)) {
    if (k === "Fn::ImportValue") {
      const importedName =
        typeof v === "string"
          ? v
          : typeof v === "object" && v !== null
          ? JSON.stringify(v).slice(0, 80)
          : "?";
      hits.push(`${[...path, k].join(".")} -> ${importedName}`);
      continue; // don't recurse into the imported ref itself
    }
    hits.push(...hasImportValue(v, [...path, k]));
  }
  return hits;
}

export function lint(template: CfnTemplate & { Outputs?: any }): Finding[] {
  const findings: Finding[] = [];

  // 1. Producer side: any Output with an Export.Name is a cross-stack export.
  const outputs = (template as any).Outputs || {};
  for (const [name, output] of Object.entries(outputs) as [string, any][]) {
    const exportName = output?.Export?.Name;
    if (exportName) {
      findings.push({
        severity: "high",
        lint: "cdk-no-cross-stack-exports",
        resource: `Outputs.${name}`,
        message:
          `CloudFormation Export '${typeof exportName === "string" ? exportName : "<dynamic>"}' ` +
          `will deadlock updates when a consumer imports it. Remove 'exportName' and publish ` +
          `the value via ssm.StringParameter instead; consumers should read via ` +
          `StringParameter.valueForStringParameter. See docs/references/cross-stack-ssm-llms.txt (P-10).`,
      });
    }
  }

  // 2. Consumer side: any Fn::ImportValue anywhere in Resources.
  const resources = template.Resources || {};
  for (const [id, res] of Object.entries(resources) as [string, CfnResource][]) {
    const hits = hasImportValue(res.Properties || {});
    if (hits.length > 0) {
      findings.push({
        severity: "high",
        lint: "cdk-no-cross-stack-exports",
        resource: id,
        message:
          `Fn::ImportValue detected in resource '${id}' (at ${hits[0]}). ` +
          `Passing construct attributes across CDK stacks synthesizes into cross-stack ` +
          `imports that deadlock when the producer changes. Use SSM parameters with ` +
          `StringParameter.valueForStringParameter in the consumer instead. ` +
          `See docs/references/cross-stack-ssm-llms.txt (P-10). Lesson: EdgeSignal 2026-04-15.`,
      });
    }
  }

  return findings;
}
