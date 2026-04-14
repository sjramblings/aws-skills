// cdk-encryption-required — queues, topics, buckets must use encryption at rest.
// Golden principle P-03. Source: VCS Council finding S-03.

import { Finding, CfnTemplate, CfnResource } from "./lint-types";

export function lint(template: CfnTemplate): Finding[] {
  const findings: Finding[] = [];
  const resources = template.Resources || {};

  for (const [id, res] of Object.entries(resources) as [string, CfnResource][]) {
    const t = res.Type;
    const p = res.Properties || {};

    if (t === "AWS::SQS::Queue") {
      if (!p.KmsMasterKeyId && !p.SqsManagedSseEnabled) {
        findings.push({
          severity: "high",
          lint: "cdk-encryption-required",
          resource: id,
          message: "SQS queue has no encryption-at-rest. Set SqsManagedSseEnabled=true or KmsMasterKeyId.",
        });
      }
    }

    if (t === "AWS::SNS::Topic") {
      if (!p.KmsMasterKeyId) {
        findings.push({
          severity: "high",
          lint: "cdk-encryption-required",
          resource: id,
          message: "SNS topic has no KmsMasterKeyId. Enable encryption at rest.",
        });
      }
    }

    if (t === "AWS::S3::Bucket") {
      const enc = p.BucketEncryption?.ServerSideEncryptionConfiguration;
      if (!enc || (Array.isArray(enc) && enc.length === 0)) {
        findings.push({
          severity: "critical",
          lint: "cdk-encryption-required",
          resource: id,
          message: "S3 bucket missing BucketEncryption. Require SSE-KMS or SSE-S3.",
        });
      }
    }

    if (t === "AWS::DynamoDB::Table") {
      const sse = p.SSESpecification;
      if (!sse || sse.SSEEnabled !== true) {
        findings.push({
          severity: "high",
          lint: "cdk-encryption-required",
          resource: id,
          message: "DynamoDB table missing SSESpecification.SSEEnabled=true.",
        });
      }
    }
  }

  return findings;
}
