// cdk-ssl-only — buckets and queues must enforce SSL via aws:SecureTransport.
// Golden principle P-04.

import { Finding, CfnTemplate, CfnResource } from "./lint-types";

function policyEnforcesSsl(doc: any): boolean {
  if (!doc?.Statement) return false;
  const statements = Array.isArray(doc.Statement) ? doc.Statement : [doc.Statement];
  return statements.some((stmt: any) => {
    if (stmt.Effect !== "Deny") return false;
    const cond = stmt.Condition?.Bool?.["aws:SecureTransport"];
    return cond === false || cond === "false";
  });
}

export function lint(template: CfnTemplate): Finding[] {
  const findings: Finding[] = [];
  const resources = template.Resources || {};
  const buckets = new Set<string>();
  const queues = new Set<string>();
  const bucketPolicies = new Map<string, any>();
  const queuePolicies = new Map<string, any>();

  for (const [id, res] of Object.entries(resources) as [string, CfnResource][]) {
    if (res.Type === "AWS::S3::Bucket") buckets.add(id);
    if (res.Type === "AWS::SQS::Queue") queues.add(id);
    if (res.Type === "AWS::S3::BucketPolicy") {
      const ref = res.Properties?.Bucket?.Ref;
      if (ref) bucketPolicies.set(ref, res.Properties?.PolicyDocument);
    }
    if (res.Type === "AWS::SQS::QueuePolicy") {
      const queueRefs = res.Properties?.Queues || [];
      for (const q of queueRefs) {
        const ref = q?.Ref;
        if (ref) queuePolicies.set(ref, res.Properties?.PolicyDocument);
      }
    }
  }

  for (const b of buckets) {
    const policy = bucketPolicies.get(b);
    if (!policyEnforcesSsl(policy)) {
      findings.push({
        severity: "high",
        lint: "cdk-ssl-only",
        resource: b,
        message: "S3 bucket has no Deny statement for aws:SecureTransport=false. Use harness helper requireSslOnly(bucket).",
      });
    }
  }

  for (const q of queues) {
    const policy = queuePolicies.get(q);
    if (!policyEnforcesSsl(policy)) {
      findings.push({
        severity: "high",
        lint: "cdk-ssl-only",
        resource: q,
        message: "SQS queue has no Deny for aws:SecureTransport=false.",
      });
    }
  }

  return findings;
}
