// cost-instrumentation.ts — Bedrock cost tracking from day 1.
//
// Two exports:
//
//  1. CostInstrumentationConstruct — attach to a stack to get:
//     - a CloudWatch metric filter that counts Bedrock InvokeModel
//       input + output tokens out of the calling Lambda's log group
//     - an AWS Budgets monthly cost alarm scoped via stack tags
//     - a per-stack CloudWatch dashboard with token + cost widgets
//     - required cost-allocation tags (owner, cost-center,
//       data-classification, harness:env, harness:project)
//
//  2. withCostInstrumentation(client) — wraps a BedrockRuntimeClient so
//     each invoke logs a structured line the metric filter can parse:
//       BEDROCK_USAGE model=... input_tokens=... output_tokens=...
//
// Required by golden principle P-08. Caught at static-analysis time by
// tools/lints/bedrock-cost-instrumentation.ts.

import * as cdk from "aws-cdk-lib";
import * as cw from "aws-cdk-lib/aws-cloudwatch";
import * as logs from "aws-cdk-lib/aws-logs";
import * as budgets from "aws-cdk-lib/aws-budgets";
import { Construct } from "constructs";

const REQUIRED_TAGS = [
  "owner",
  "cost-center",
  "data-classification",
  "harness:env",
  "harness:project",
];

export interface CostInstrumentationProps {
  /** Lambda log groups to attach the metric filter to. */
  readonly logGroups: logs.ILogGroup[];

  /** Project slug — applied as harness:project tag and dashboard name. */
  readonly project: string;

  /** Environment short name (pr|uat|prod). Applied as harness:env. */
  readonly env: "pr" | "uat" | "prod";

  /** Owner GitHub handle. Applied as owner tag. */
  readonly owner: string;

  /** Cost center for billing attribution. Applied as cost-center tag. */
  readonly costCenter: string;

  /** Data classification (public/internal/confidential/restricted). */
  readonly dataClassification: "public" | "internal" | "confidential" | "restricted";

  /** Monthly budget in USD. Default 100. */
  readonly monthlyBudgetUsd?: number;

  /** SNS topic ARN to notify at 80% / 100% breach. Optional. */
  readonly notificationTopicArn?: string;
}

export class CostInstrumentationConstruct extends Construct {
  public readonly dashboard: cw.Dashboard;

  constructor(scope: Construct, id: string, props: CostInstrumentationProps) {
    super(scope, id);

    const stack = cdk.Stack.of(this);
    const monthlyLimit = props.monthlyBudgetUsd ?? 100;

    // 1. Apply required tags to the stack — propagate to every resource.
    cdk.Tags.of(stack).add("owner", props.owner);
    cdk.Tags.of(stack).add("cost-center", props.costCenter);
    cdk.Tags.of(stack).add("data-classification", props.dataClassification);
    cdk.Tags.of(stack).add("harness:env", props.env);
    cdk.Tags.of(stack).add("harness:project", props.project);

    // 2. Metric filter per log group — counts input + output tokens.
    // Pattern matches lines emitted by withCostInstrumentation():
    //   BEDROCK_USAGE model=... input_tokens=N output_tokens=N
    for (const [i, lg] of props.logGroups.entries()) {
      new logs.MetricFilter(this, `BedrockInputTokens${i}`, {
        logGroup: lg,
        metricNamespace: `harness/${props.project}`,
        metricName: "BedrockInputTokens",
        filterPattern: logs.FilterPattern.literal(
          '[..., marker="BEDROCK_USAGE", model, input_tokens_kv, output_tokens_kv]'
        ),
        metricValue: "$input_tokens_kv",
        defaultValue: 0,
        dimensions: { Env: props.env },
      });

      new logs.MetricFilter(this, `BedrockOutputTokens${i}`, {
        logGroup: lg,
        metricNamespace: `harness/${props.project}`,
        metricName: "BedrockOutputTokens",
        filterPattern: logs.FilterPattern.literal(
          '[..., marker="BEDROCK_USAGE", model, input_tokens_kv, output_tokens_kv]'
        ),
        metricValue: "$output_tokens_kv",
        defaultValue: 0,
        dimensions: { Env: props.env },
      });
    }

    // 3. Monthly budget scoped to the stack via cost-allocation tags.
    // Requires harness:project tag to be ACTIVE in Billing preferences
    // (one-time setup per account).
    const subscribers: budgets.CfnBudget.SubscriberProperty[] = [];
    if (props.notificationTopicArn) {
      subscribers.push({
        subscriptionType: "SNS",
        address: props.notificationTopicArn,
      });
    }

    new budgets.CfnBudget(this, "MonthlyBudget", {
      budget: {
        budgetName: `harness-${props.project}-${props.env}`,
        budgetType: "COST",
        timeUnit: "MONTHLY",
        budgetLimit: { amount: monthlyLimit, unit: "USD" },
        costFilters: {
          TagKeyValue: [
            `user:harness:project$${props.project}`,
            `user:harness:env$${props.env}`,
          ],
        },
      },
      ...(subscribers.length > 0 && {
        notificationsWithSubscribers: [
          {
            notification: {
              notificationType: "ACTUAL",
              comparisonOperator: "GREATER_THAN",
              threshold: 80,
              thresholdType: "PERCENTAGE",
            },
            subscribers,
          },
          {
            notification: {
              notificationType: "ACTUAL",
              comparisonOperator: "GREATER_THAN",
              threshold: 100,
              thresholdType: "PERCENTAGE",
            },
            subscribers,
          },
        ],
      }),
    });

    // 4. Dashboard — token + cost widgets per stack.
    this.dashboard = new cw.Dashboard(this, "CostDashboard", {
      dashboardName: `harness-${props.project}-${props.env}-cost`,
    });

    this.dashboard.addWidgets(
      new cw.GraphWidget({
        title: "Bedrock tokens (input + output)",
        left: [
          new cw.Metric({
            namespace: `harness/${props.project}`,
            metricName: "BedrockInputTokens",
            statistic: "Sum",
            period: cdk.Duration.minutes(5),
            dimensionsMap: { Env: props.env },
          }),
          new cw.Metric({
            namespace: `harness/${props.project}`,
            metricName: "BedrockOutputTokens",
            statistic: "Sum",
            period: cdk.Duration.minutes(5),
            dimensionsMap: { Env: props.env },
          }),
        ],
        width: 12,
      }),
      new cw.SingleValueWidget({
        title: "Estimated monthly charges (account)",
        metrics: [
          new cw.Metric({
            namespace: "AWS/Billing",
            metricName: "EstimatedCharges",
            statistic: "Maximum",
            period: cdk.Duration.hours(6),
            dimensionsMap: { Currency: "USD" },
          }),
        ],
        width: 6,
      }),
    );
  }
}

// -----------------------------------------------------------------------
// withCostInstrumentation — Bedrock client wrapper.
// -----------------------------------------------------------------------
// Logs a structured line on every invoke that the metric filter parses:
//   BEDROCK_USAGE model=us.anthropic.claude-... input_tokens=123 output_tokens=456
//
// The lint at tools/lints/bedrock-cost-instrumentation.ts checks for the
// presence of this wrapper at static-analysis time.
//
// Type is intentionally loose — any client exposing .send(command) works.

type SendCapable = {
  send: (command: any) => Promise<any>;
};

export function withCostInstrumentation<T extends SendCapable>(client: T): T {
  const originalSend = client.send.bind(client);

  client.send = async (command: any) => {
    const response = await originalSend(command);

    let model = command?.input?.modelId ?? "unknown";
    let inputTokens = 0;
    let outputTokens = 0;

    try {
      if (response?.usage) {
        inputTokens = response.usage.inputTokens ?? 0;
        outputTokens = response.usage.outputTokens ?? 0;
      } else if (response?.body) {
        const decoded = typeof response.body === "string"
          ? response.body
          : new TextDecoder().decode(response.body);
        const parsed = JSON.parse(decoded);
        inputTokens = parsed?.usage?.input_tokens ?? parsed?.usage?.inputTokens ?? 0;
        outputTokens = parsed?.usage?.output_tokens ?? parsed?.usage?.outputTokens ?? 0;
      }
    } catch {
      // Swallow — instrumentation must never break the call.
    }

    // Structured log line — the metric filter pattern depends on this exact format.
    console.log(
      `BEDROCK_USAGE model=${model} input_tokens=${inputTokens} output_tokens=${outputTokens}`
    );

    return response;
  };

  return client;
}

// -----------------------------------------------------------------------
// requireTags — runtime guard for use in CDK constructs that don't yet
// have the CostInstrumentationConstruct attached.
// -----------------------------------------------------------------------

export function requireTags(scope: Construct, tags: Record<string, string>) {
  for (const required of REQUIRED_TAGS) {
    if (!(required in tags)) {
      throw new Error(
        `cost-instrumentation: required tag '${required}' missing. ` +
        `See docs/references/cost-dashboard-llms.txt and golden principle P-08.`
      );
    }
  }
  for (const [k, v] of Object.entries(tags)) {
    cdk.Tags.of(scope).add(k, v);
  }
}
