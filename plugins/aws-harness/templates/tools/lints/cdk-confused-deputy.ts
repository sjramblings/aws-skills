// cdk-confused-deputy — flag service-principal grants without SourceAccount/SourceArn.
// Source: VCS commits 15e104c, b5a25bf. Golden principle P-02.
// Remediation doc: docs/references/confused-deputy-llms.txt

import { Finding, CfnTemplate, CfnResource } from "./lint-types";

const SERVICE_PRINCIPAL_PATTERNS = [
  /\.amazonaws\.com$/,
  /\.aws\.internal$/,
];

function hasServicePrincipal(principal: any): boolean {
  if (!principal) return false;
  if (typeof principal === "string") return SERVICE_PRINCIPAL_PATTERNS.some((p) => p.test(principal));
  if (typeof principal === "object") {
    const svc = principal.Service;
    if (!svc) return false;
    const list = Array.isArray(svc) ? svc : [svc];
    return list.some((s: any) => typeof s === "string" && SERVICE_PRINCIPAL_PATTERNS.some((p) => p.test(s)));
  }
  return false;
}

function hasSourceConditions(condition: any): boolean {
  if (!condition) return false;
  // condition: { StringEquals: { "aws:SourceAccount": ... , "aws:SourceArn": ... } }
  const stringEquals = condition.StringEquals || condition.StringLike || {};
  const hasAccount = "aws:SourceAccount" in stringEquals;
  const hasArn = "aws:SourceArn" in stringEquals || condition.ArnLike?.["aws:SourceArn"];
  return hasAccount || hasArn;
}

function scanPolicyDocument(doc: any): boolean {
  // returns true if every service-principal statement has source conditions
  if (!doc?.Statement) return true;
  const statements = Array.isArray(doc.Statement) ? doc.Statement : [doc.Statement];
  for (const stmt of statements) {
    if (stmt.Effect !== "Allow") continue;
    if (!hasServicePrincipal(stmt.Principal)) continue;
    if (!hasSourceConditions(stmt.Condition)) return false;
  }
  return true;
}

export function lint(template: CfnTemplate): Finding[] {
  const findings: Finding[] = [];
  const resources = template.Resources || {};
  for (const [id, res] of Object.entries(resources) as [string, CfnResource][]) {
    const t = res.Type;
    // Bucket policies
    if (t === "AWS::S3::BucketPolicy") {
      if (!scanPolicyDocument(res.Properties?.PolicyDocument)) {
        findings.push({
          severity: "critical",
          lint: "cdk-confused-deputy",
          resource: id,
          message: "Service-principal grant missing aws:SourceAccount / aws:SourceArn conditions. See docs/references/confused-deputy-llms.txt",
        });
      }
    }
    // SNS topic policies
    if (t === "AWS::SNS::TopicPolicy") {
      if (!scanPolicyDocument(res.Properties?.PolicyDocument)) {
        findings.push({
          severity: "critical",
          lint: "cdk-confused-deputy",
          resource: id,
          message: "SNS topic policy service-principal missing source conditions. See docs/references/confused-deputy-llms.txt",
        });
      }
    }
    // SQS queue policies
    if (t === "AWS::SQS::QueuePolicy") {
      if (!scanPolicyDocument(res.Properties?.PolicyDocument)) {
        findings.push({
          severity: "critical",
          lint: "cdk-confused-deputy",
          resource: id,
          message: "SQS queue policy service-principal missing source conditions. See docs/references/confused-deputy-llms.txt",
        });
      }
    }
    // KMS key policies (embedded in the key resource itself)
    if (t === "AWS::KMS::Key") {
      if (!scanPolicyDocument(res.Properties?.KeyPolicy)) {
        findings.push({
          severity: "critical",
          lint: "cdk-confused-deputy",
          resource: id,
          message: "KMS key policy service-principal missing source conditions. See docs/references/confused-deputy-llms.txt",
        });
      }
    }
  }
  return findings;
}
