# AgentCore Evaluations Service

> **Status**: Preview

## Overview

Amazon Bedrock AgentCore Evaluations provides automated agent quality assessment using LLM-as-judge techniques. Evaluate agent responses for helpfulness, accuracy, safety, and custom criteria — either in real-time during execution or on-demand against stored traces.

## Evaluator Types

- **Built-in**: Pre-configured evaluators (e.g., `Builtin.Helpfulness`, `Builtin.Faithfulness`) — ready to use without configuration
- **Custom**: Account-specific evaluators with custom prompts and scoring criteria

## Evaluation Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Online** | Real-time evaluation during agent execution | Production quality monitoring |
| **On-demand** | Batch evaluation of stored traces | Regression testing, quality audits |

## CLI Commands

### Evaluators

```bash
# Create a custom evaluator
aws bedrock-agentcore-control create-evaluator \
  --evaluator-name my-evaluator \
  --region us-west-2

# Get evaluator details
aws bedrock-agentcore-control get-evaluator \
  --evaluator-identifier <EVALUATOR_ID> \
  --region us-west-2

# List evaluators
aws bedrock-agentcore-control list-evaluators \
  --region us-west-2

# Update evaluator
aws bedrock-agentcore-control update-evaluator \
  --evaluator-identifier <EVALUATOR_ID> \
  --region us-west-2

# Delete evaluator
aws bedrock-agentcore-control delete-evaluator \
  --evaluator-identifier <EVALUATOR_ID> \
  --region us-west-2
```

### Online Evaluation Configuration

```bash
# Create online evaluation config (attaches evaluator to a runtime)
aws bedrock-agentcore-control create-online-evaluation-config \
  --online-evaluation-config-name my-eval-config \
  --region us-west-2

# Get online evaluation config
aws bedrock-agentcore-control get-online-evaluation-config \
  --online-evaluation-config-identifier <CONFIG_ID> \
  --region us-west-2

# List online evaluation configs
aws bedrock-agentcore-control list-online-evaluation-configs \
  --region us-west-2

# Update online evaluation config
aws bedrock-agentcore-control update-online-evaluation-config \
  --online-evaluation-config-identifier <CONFIG_ID> \
  --region us-west-2

# Delete online evaluation config
aws bedrock-agentcore-control delete-online-evaluation-config \
  --online-evaluation-config-identifier <CONFIG_ID> \
  --region us-west-2
```

## Framework Integration

Evaluations work with any framework that emits OpenTelemetry/OpenInference traces:

| Framework | Integration |
|-----------|-------------|
| **Strands** | Built-in OpenTelemetry instrumentation |
| **LangGraph** | OpenTelemetry callback handler |
| **Custom** | Add OpenInference span attributes to traces |

## Quotas

| Resource | Limit |
|----------|-------|
| Evaluation configs per account | 1,000 |
| Active evaluation configs | 100 |
| Token throughput | 1M tokens/min |

## Related Services

- [Runtime Service](../runtime/README.md) — agents being evaluated
- [Observability](../observability/README.md) — traces used for evaluation
- [AWS Evaluations Documentation](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/evaluations.html)
