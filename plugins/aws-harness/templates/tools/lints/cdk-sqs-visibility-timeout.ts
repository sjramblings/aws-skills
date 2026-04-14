// cdk-sqs-visibility-timeout — queue visibility timeout must be >= 6 × consumer Lambda timeout.
// Golden principle P-05. Source: VCS commit ad1c517.

import { Finding, CfnTemplate, CfnResource } from "./lint-types";

function resolveRef(value: any): string | undefined {
  if (!value) return undefined;
  if (typeof value === "string") return value;
  if (value.Ref) return value.Ref;
  if (value["Fn::GetAtt"]) {
    const [logicalId] = value["Fn::GetAtt"];
    return logicalId;
  }
  return undefined;
}

export function lint(template: CfnTemplate): Finding[] {
  const findings: Finding[] = [];
  const resources = template.Resources || {};

  const queues: Record<string, number> = {};
  const lambdas: Record<string, number> = {};
  // map: queueId -> [lambdaIds...] that consume it
  const consumerMap: Record<string, string[]> = {};

  for (const [id, res] of Object.entries(resources) as [string, CfnResource][]) {
    const p = res.Properties || {};
    if (res.Type === "AWS::SQS::Queue") {
      // Default visibility timeout if unset is 30s
      queues[id] = typeof p.VisibilityTimeout === "number" ? p.VisibilityTimeout : 30;
    }
    if (res.Type === "AWS::Lambda::Function") {
      // Default Lambda timeout is 3s
      lambdas[id] = typeof p.Timeout === "number" ? p.Timeout : 3;
    }
    if (res.Type === "AWS::Lambda::EventSourceMapping") {
      const sourceArn = p.EventSourceArn;
      const functionName = p.FunctionName;
      const queueId = resolveRef(sourceArn);
      const fnId = resolveRef(functionName);
      if (queueId && fnId && queues[queueId] !== undefined) {
        (consumerMap[queueId] ??= []).push(fnId);
      }
    }
  }

  for (const [qId, vt] of Object.entries(queues)) {
    const consumers = consumerMap[qId] || [];
    for (const fnId of consumers) {
      const lt = lambdas[fnId];
      if (lt === undefined) continue;
      const required = lt * 6;
      if (vt < required) {
        findings.push({
          severity: "high",
          lint: "cdk-sqs-visibility-timeout",
          resource: qId,
          message: `Visibility timeout ${vt}s < 6 × Lambda ${fnId} timeout (${lt}s). Set to >= ${required}s. Lesson: VCS ad1c517.`,
        });
      }
    }
  }

  return findings;
}
