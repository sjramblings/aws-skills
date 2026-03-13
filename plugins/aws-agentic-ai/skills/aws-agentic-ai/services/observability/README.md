# AgentCore Observability

> **Status**: GA

## Overview

Amazon Bedrock AgentCore provides built-in observability through OpenTelemetry integration. Agent code instruments with OpenTelemetry; telemetry data flows automatically to CloudWatch Logs, CloudWatch Metrics, and AWS X-Ray. There are no dedicated AgentCore CLI commands to enable or configure observability — it is built into the platform.

## How It Works

1. AgentCore services automatically emit traces, logs, and metrics via OpenTelemetry
2. Data is collected and routed to CloudWatch and X-Ray
3. You query and visualize using standard AWS observability tools (`aws cloudwatch`, `aws logs`, `aws xray`)

## Metrics by Service

**Gateway Metrics** (namespace: `AWS/BedrockAgentCore`):
- `TargetInvocations` — number of target invocations
- `TargetErrors` — number of target errors
- `TargetLatency` — target response latency

**Runtime Metrics**:
- `AgentExecutions` — number of agent executions
- `ExecutionDuration` — agent execution duration
- `ExecutionErrors` — number of execution failures

**Memory Metrics**:
- `MemoryReads` — number of memory read operations
- `MemoryWrites` — number of memory write operations
- `MemorySize` — total memory storage size

**Token Metrics**:
- `TokensConsumed` — total tokens used
- `TokenCost` — estimated cost

## Querying Metrics

```bash
# Get metric statistics
aws cloudwatch get-metric-statistics \
  --namespace AWS/BedrockAgentCore \
  --metric-name TargetInvocations \
  --dimensions Name=AgentId,Value=<AGENT_ID> \
  --start-time <START> \
  --end-time <END> \
  --period 300 \
  --statistics Sum Average

# Put custom metric data
aws cloudwatch put-metric-data \
  --namespace AgentCore/Custom \
  --metric-name CustomMetric \
  --value 1.0 \
  --dimensions AgentId=<AGENT_ID>
```

## Logs

```bash
# Tail agent logs
aws logs tail /aws/bedrock-agentcore/<AGENT_ID> \
  --follow \
  --format short

# Query logs with filter
aws logs filter-log-events \
  --log-group-name /aws/bedrock-agentcore/<AGENT_ID> \
  --filter-pattern "ERROR" \
  --start-time <TIMESTAMP>

# Run CloudWatch Logs Insights query
aws logs start-query \
  --log-group-name /aws/bedrock-agentcore/<AGENT_ID> \
  --start-time <START_TIMESTAMP> \
  --end-time <END_TIMESTAMP> \
  --query-string 'fields @timestamp, @message
    | filter @message like /ERROR/
    | sort @timestamp desc
    | limit 20'
```

## Traces

```bash
# Query recent traces
aws xray get-trace-summaries \
  --start-time <START_TIMESTAMP> \
  --end-time <END_TIMESTAMP> \
  --filter-expression 'service(id(name: "AgentCore", type: "AWS::Service"))'

# Get specific trace details
aws xray batch-get-traces \
  --trace-ids <TRACE_ID_1> <TRACE_ID_2>

# Get service dependency map
aws xray get-service-graph \
  --start-time <START_TIMESTAMP> \
  --end-time <END_TIMESTAMP>
```

## Dashboards

```bash
# Create CloudWatch dashboard
aws cloudwatch put-dashboard \
  --dashboard-name AgentCore-<AGENT_ID> \
  --dashboard-body file://dashboard-definition.json
```

### Dashboard Definition Example

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/BedrockAgentCore", "TargetInvocations", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "us-west-2",
        "title": "Target Invocations"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/BedrockAgentCore", "TargetErrors", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "us-west-2",
        "title": "Target Errors"
      }
    }
  ]
}
```

## Alarms

```bash
# High error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name high-error-rate-<AGENT_ID> \
  --alarm-description "Alert when error rate exceeds threshold" \
  --metric-name TargetErrors \
  --namespace AWS/BedrockAgentCore \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=AgentId,Value=<AGENT_ID> \
  --alarm-actions <SNS_TOPIC_ARN>

# High latency alarm (P95 > 2s)
aws cloudwatch put-metric-alarm \
  --alarm-name latency-high \
  --metric-name TargetLatency \
  --namespace AWS/BedrockAgentCore \
  --statistic p95 \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 2000 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=AgentId,Value=<AGENT_ID> \
  --alarm-actions <SNS_TOPIC_ARN>

# High token usage alarm
aws cloudwatch put-metric-alarm \
  --alarm-name tokens-high \
  --metric-name TokensConsumed \
  --namespace AWS/BedrockAgentCore \
  --statistic Sum \
  --period 3600 \
  --evaluation-periods 1 \
  --threshold 1000000 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=AgentId,Value=<AGENT_ID> \
  --alarm-actions <SNS_TOPIC_ARN>
```

## Best Practices

- Use appropriate sampling rates (1.0 for dev, 0.1 for prod) in your OpenTelemetry instrumentation
- Set CloudWatch log retention to 7-30 days to manage costs
- Use CloudWatch Logs Insights for complex queries instead of scanning raw logs
- Define SLOs and set meaningful alert thresholds — avoid alert fatigue
- Use composite alarms for complex conditions

## Key Performance Indicators

| Category | Metrics |
|----------|---------|
| **Availability** | Service uptime, error rate by service, failed request percentage |
| **Performance** | P50/P95/P99 latency, request throughput, operation duration |
| **Efficiency** | Token consumption rate, cost per operation, resource utilization |

## Troubleshooting

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| No traces appearing | Check if agent is instrumented with OpenTelemetry | Add OTel instrumentation to agent code |
| Missing logs | `aws logs describe-log-groups --log-group-name-prefix /aws/bedrock-agentcore` | Verify IAM permissions for CloudWatch Logs |
| High cardinality metrics | Too many unique dimension combinations | Reduce dimension cardinality, use metric filters |
| High CloudWatch costs | Excessive logging or metrics | Adjust sampling rates, reduce log retention |

## Related Services

- [Gateway Service](../gateway/README.md) — gateway metrics
- [Runtime Service](../runtime/README.md) — runtime tracing
- [Memory Service](../memory/README.md) — memory metrics
- [AWS Observability Documentation](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/observability.html)
