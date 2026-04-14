// cdk-resource-tags — every resource must carry owner, cost-center,
// data-classification, harness:env tags.

import { Finding, CfnTemplate, CfnResource } from "./lint-types";

const REQUIRED_TAGS = ["owner", "cost-center", "data-classification", "harness:env"];

const TAGGABLE_PREFIXES = [
  "AWS::Lambda::Function",
  "AWS::SQS::Queue",
  "AWS::SNS::Topic",
  "AWS::S3::Bucket",
  "AWS::DynamoDB::Table",
  "AWS::Events::Rule",
  "AWS::ApiGateway::RestApi",
  "AWS::ApiGatewayV2::Api",
  "AWS::StepFunctions::StateMachine",
  "AWS::KMS::Key",
];

function tagKeys(tags: any): Set<string> {
  if (!tags) return new Set();
  if (!Array.isArray(tags)) return new Set();
  return new Set(tags.map((t: any) => t.Key).filter(Boolean));
}

export function lint(template: CfnTemplate): Finding[] {
  const findings: Finding[] = [];
  const resources = template.Resources || {};

  for (const [id, res] of Object.entries(resources) as [string, CfnResource][]) {
    if (!TAGGABLE_PREFIXES.includes(res.Type)) continue;
    const keys = tagKeys(res.Properties?.Tags);
    const missing = REQUIRED_TAGS.filter((t) => !keys.has(t));
    if (missing.length > 0) {
      findings.push({
        severity: "medium",
        lint: "cdk-resource-tags",
        resource: id,
        message: `Missing tags: ${missing.join(", ")}. Apply via cdk.Tags.of(stack).add(...) in the layered construct.`,
      });
    }
  }
  return findings;
}
