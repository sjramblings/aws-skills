// cdk-fifo-maxconcurrency — FIFO queue paired with Lambda ReservedConcurrentExecutions=1
// breaks ordering. Minimum 2 or remove reservation.
// Golden principle P-06. Source: VCS commit 92d7096.

import { Finding, CfnTemplate, CfnResource } from "./lint-types";

function resolveRef(value: any): string | undefined {
  if (!value) return undefined;
  if (typeof value === "string") return value;
  if (value.Ref) return value.Ref;
  if (value["Fn::GetAtt"]) return value["Fn::GetAtt"][0];
  return undefined;
}

export function lint(template: CfnTemplate): Finding[] {
  const findings: Finding[] = [];
  const resources = template.Resources || {};

  const fifoQueues = new Set<string>();
  const lambdaReserved: Record<string, number | undefined> = {};
  const mappings: Array<{ queueId: string; fnId: string }> = [];

  for (const [id, res] of Object.entries(resources) as [string, CfnResource][]) {
    const p = res.Properties || {};
    if (res.Type === "AWS::SQS::Queue" && p.FifoQueue === true) {
      fifoQueues.add(id);
    }
    if (res.Type === "AWS::Lambda::Function") {
      lambdaReserved[id] = p.ReservedConcurrentExecutions;
    }
    if (res.Type === "AWS::Lambda::EventSourceMapping") {
      const qId = resolveRef(p.EventSourceArn);
      const fnId = resolveRef(p.FunctionName);
      if (qId && fnId) mappings.push({ queueId: qId, fnId });
    }
  }

  for (const { queueId, fnId } of mappings) {
    if (!fifoQueues.has(queueId)) continue;
    const reserved = lambdaReserved[fnId];
    if (reserved === 1) {
      findings.push({
        severity: "high",
        lint: "cdk-fifo-maxconcurrency",
        resource: fnId,
        message: `Lambda ${fnId} has ReservedConcurrentExecutions=1 consuming FIFO queue ${queueId} — breaks ordering. Use >= 2 or remove the reservation. Lesson: VCS 92d7096.`,
      });
    }
  }

  return findings;
}
