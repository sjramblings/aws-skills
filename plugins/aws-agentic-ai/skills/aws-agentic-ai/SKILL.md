---
name: aws-agentic-ai
aliases:
  - bedrock-agentcore
description: AWS Bedrock AgentCore comprehensive expert for deploying and managing all AgentCore services. Use when working with Gateway, Runtime, Memory, Identity, Evaluations, Policy, or any AgentCore component. Covers MCP target deployment, credential management, agent evaluation, Cedar policies, schema optimization, runtime configuration, memory management, and identity services. Trigger phrases include bedrock-agentcore-control, AgentCore, agent runtime, MCP gateway, tool access policy, agent evaluation.
context: fork
model: sonnet
skills:
  - aws-mcp-setup
allowed-tools:
  - mcp__aws-mcp__*
  - mcp__awsdocs__*
  - Bash(aws bedrock-agentcore-control *)
  - Bash(aws bedrock-agentcore-runtime *)
  - Bash(aws bedrock *)
  - Bash(aws s3 cp *)
  - Bash(aws s3 ls *)
  - Bash(aws secretsmanager *)
  - Bash(aws sts get-caller-identity)
  - Bash(aws logs *)
  - Bash(aws cloudwatch *)
hooks:
  PreToolUse:
    - matcher: Bash(aws bedrock-agentcore-control create-*)
      command: aws sts get-caller-identity --query Account --output text
      once: true
---

# AWS Bedrock AgentCore

AWS Bedrock AgentCore provides a complete platform for deploying and scaling AI agents with nine core services. This skill guides you through service selection, deployment patterns, and integration workflows using AWS CLI (`bedrock-agentcore-control`).

## AWS Documentation Requirement

Always verify AWS facts using MCP tools (`mcp__aws-mcp__*` or `mcp__*awsdocs*__*`) before answering. The `aws-mcp-setup` dependency is auto-loaded — if MCP tools are unavailable, guide the user through that skill's setup flow.

## Service Selection Guide

Use this table to pick the right service README for the task at hand:

| Service | When to Use | Status | Documentation |
|---------|-------------|--------|---------------|
| **Gateway** | Convert REST APIs into MCP tools for agents; manage gateway lifecycle and targets | GA | [`services/gateway/README.md`](services/gateway/README.md) |
| **Runtime** | Deploy and scale agents in serverless containers or direct code; manage endpoints | GA | [`services/runtime/README.md`](services/runtime/README.md) |
| **Memory** | Add short-term and long-term conversation memory to agents | GA | [`services/memory/README.md`](services/memory/README.md) |
| **Identity** | Manage API keys, OAuth credentials, workload identities, and token vault | GA | [`services/identity/README.md`](services/identity/README.md) |
| **Code Interpreter** | Let agents execute code in isolated sandboxes | GA | [`services/code-interpreter/README.md`](services/code-interpreter/README.md) |
| **Browser** | Let agents interact with websites (scrape, fill forms, take screenshots) | GA | [`services/browser/README.md`](services/browser/README.md) |
| **Observability** | Trace, monitor, and debug agent performance with CloudWatch and X-Ray | GA | [`services/observability/README.md`](services/observability/README.md) |
| **Evaluations** | Assess agent quality with LLM-as-judge techniques (online and on-demand) | Preview | [`services/evaluations/README.md`](services/evaluations/README.md) |
| **Policy** | Enforce deterministic authorization controls on agent tool access with Cedar | GA | [`services/policy/README.md`](services/policy/README.md) |

## Common Workflows

### Deploy an Agent Runtime

**Decision**: Container deployment (Strands, LangGraph, CrewAI, custom) vs. direct code deployment (S3 zip for simple `/invocations` + `/ping` handlers).

**MANDATORY - READ DETAILED DOCUMENTATION**: See [`services/runtime/README.md`](services/runtime/README.md) for full setup including endpoint management, framework support, and authentication.

**Quick Workflow**:
1. Build container image (or zip code for direct deployment)
2. Push to ECR (or upload zip to S3)
3. `create-agent-runtime` with container URI or S3 artifact
4. Wait for runtime version to reach `READY`
5. `create-agent-runtime-endpoint` (or use the auto-created `DEFAULT` endpoint)
6. `invoke-agent-runtime` to test

### Set Up an MCP Gateway

**MANDATORY - READ DETAILED DOCUMENTATION**: See [`services/gateway/README.md`](services/gateway/README.md) for gateway lifecycle, target types, authentication matrix, and deployment strategies.

**Quick Workflow**:
1. `create-gateway` — create the gateway resource
2. Upload OpenAPI/Smithy schema to S3 (or configure Lambda/MCP server target)
3. Create credential provider if using API key auth
4. `create-gateway-target` — link schema, credentials, and endpoint
5. Verify target reaches `READY` status
6. Test tool invocation through the gateway

### Secure Tool Access with Policies

**MANDATORY - READ DETAILED DOCUMENTATION**: See [`services/policy/README.md`](services/policy/README.md) for Cedar language, policy engine setup, and natural language authoring.

**Quick Workflow**:
1. `create-policy-engine` — attach to a gateway
2. Write Cedar policies (or use `start-policy-generation` from natural language)
3. `create-policy` — add policies to the engine
4. Test tool invocations — policies enforce at gateway boundary
5. Monitor with CloudWatch for policy evaluation metrics

### Evaluate Agent Quality

**MANDATORY - READ DETAILED DOCUMENTATION**: See [`services/evaluations/README.md`](services/evaluations/README.md) for evaluator types, evaluation modes, and framework integration.

**Quick Workflow**:
1. `create-evaluator` — define evaluation criteria (built-in or custom)
2. `create-online-evaluation-config` — attach evaluator to a runtime for real-time assessment
3. Monitor evaluation results in CloudWatch
4. Iterate on agent behavior based on evaluation feedback

### Managing Credentials

**MANDATORY - READ DETAILED DOCUMENTATION**: See [`cross-service/credential-management.md`](cross-service/credential-management.md) for unified credential management patterns across all services.

**Quick Workflow**:
1. Use Identity service credential providers for all API keys and OAuth tokens
2. Link providers to gateway targets via ARN references
3. Rotate credentials quarterly through credential provider updates
4. Monitor usage with CloudWatch metrics

### Monitoring Agents

**MANDATORY - READ DETAILED DOCUMENTATION**: See [`services/observability/README.md`](services/observability/README.md) for metrics, logs, traces, dashboards, and alarms.

**Quick Workflow**:
1. Observability is built-in via OpenTelemetry — no dedicated CLI commands to enable it
2. Query metrics with `aws cloudwatch get-metric-statistics`
3. Tail logs with `aws logs tail`
4. Query traces with `aws xray get-trace-summaries`
5. Set up alarms for error rates and latency

## Service-Specific Documentation

### Gateway Service
- **Overview**: [`services/gateway/README.md`](services/gateway/README.md)
- **Deployment Strategies**: [`services/gateway/deployment-strategies.md`](services/gateway/deployment-strategies.md)
- **Troubleshooting**: [`services/gateway/troubleshooting-guide.md`](services/gateway/troubleshooting-guide.md)

### All Services
Each service has comprehensive documentation in its respective directory:
- [`services/runtime/README.md`](services/runtime/README.md)
- [`services/memory/README.md`](services/memory/README.md)
- [`services/identity/README.md`](services/identity/README.md)
- [`services/code-interpreter/README.md`](services/code-interpreter/README.md)
- [`services/browser/README.md`](services/browser/README.md)
- [`services/observability/README.md`](services/observability/README.md)
- [`services/evaluations/README.md`](services/evaluations/README.md)
- [`services/policy/README.md`](services/policy/README.md)

## Cross-Service Resources

- **Credential Management**: [`cross-service/credential-management.md`](cross-service/credential-management.md) — Unified credential patterns, security practices, rotation procedures

## Related Skills

- **CDK Infrastructure**: For defining AgentCore resources as CDK constructs (infrastructure-as-code), use the `aws-cdk-development` skill. It covers `aws_cdk.aws_bedrock_agentcore_alpha` L2 constructs for Runtime, Gateway, GatewayTarget, Browser, CodeInterpreter, and Memory.

## Additional Resources

- **AWS Documentation**: [Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html)
- **API Reference**: [Bedrock AgentCore Control Plane API](https://docs.aws.amazon.com/bedrock-agentcore-control/latest/APIReference/)
- **AWS CLI Reference**: [bedrock-agentcore-control commands](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/bedrock-agentcore-control/index.html)
