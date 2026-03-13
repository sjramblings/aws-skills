# AgentCore Policy Service

> **Status**: GA

## Overview

Amazon Bedrock AgentCore Policy provides deterministic authorization controls for agent tool access. Policy engines intercept requests at the Gateway boundary before tool execution, enforcing fine-grained rules written in the Cedar policy language.

## How It Works

1. A **policy engine** is attached to a Gateway
2. When an agent invokes a tool through the Gateway, the policy engine evaluates the request
3. **Cedar policies** define permit/forbid rules based on principal, action, resource, and conditions
4. The request is allowed or denied before reaching the target tool

## Cedar Policy Language

Cedar is a purpose-built authorization language. Policies are deterministic — no LLM involved in enforcement.

**Example — allow a specific agent to use a search tool**:
```cedar
permit(
  principal == Agent::"my-agent",
  action == Action::"invoke",
  resource == Tool::"web-search"
);
```

**Example — forbid write operations during maintenance window**:
```cedar
forbid(
  principal,
  action == Action::"invoke",
  resource == Tool::"database-write"
) when {
  context.maintenanceMode == true
};
```

## Natural Language Authoring

Describe rules in plain English and auto-generate validated Cedar policies:

```bash
# Generate Cedar policy from natural language description
aws bedrock-agentcore-control start-policy-generation \
  --policy-engine-identifier <ENGINE_ID> \
  --description "Allow the support agent to read customer data but not delete it" \
  --region us-west-2

# Check generation status
aws bedrock-agentcore-control get-policy-generation \
  --policy-engine-identifier <ENGINE_ID> \
  --policy-generation-identifier <GENERATION_ID> \
  --region us-west-2

# List policy generations
aws bedrock-agentcore-control list-policy-generations \
  --policy-engine-identifier <ENGINE_ID> \
  --region us-west-2

# List generated policy assets
aws bedrock-agentcore-control list-policy-generation-assets \
  --policy-engine-identifier <ENGINE_ID> \
  --policy-generation-identifier <GENERATION_ID> \
  --region us-west-2
```

## CLI Commands

### Policies

```bash
# Create a policy
aws bedrock-agentcore-control create-policy \
  --policy-engine-identifier <ENGINE_ID> \
  --policy-name my-policy \
  --region us-west-2

# Get policy details
aws bedrock-agentcore-control get-policy \
  --policy-engine-identifier <ENGINE_ID> \
  --policy-identifier <POLICY_ID> \
  --region us-west-2

# List policies
aws bedrock-agentcore-control list-policies \
  --policy-engine-identifier <ENGINE_ID> \
  --region us-west-2

# Update policy
aws bedrock-agentcore-control update-policy \
  --policy-engine-identifier <ENGINE_ID> \
  --policy-identifier <POLICY_ID> \
  --region us-west-2

# Delete policy
aws bedrock-agentcore-control delete-policy \
  --policy-engine-identifier <ENGINE_ID> \
  --policy-identifier <POLICY_ID> \
  --region us-west-2
```

### Policy Engines

```bash
# Create a policy engine (attach to a gateway)
aws bedrock-agentcore-control create-policy-engine \
  --policy-engine-name my-engine \
  --region us-west-2

# Get policy engine details
aws bedrock-agentcore-control get-policy-engine \
  --policy-engine-identifier <ENGINE_ID> \
  --region us-west-2

# List policy engines
aws bedrock-agentcore-control list-policy-engines \
  --region us-west-2

# Update policy engine
aws bedrock-agentcore-control update-policy-engine \
  --policy-engine-identifier <ENGINE_ID> \
  --region us-west-2

# Delete policy engine
aws bedrock-agentcore-control delete-policy-engine \
  --policy-engine-identifier <ENGINE_ID> \
  --region us-west-2
```

## Gateway Integration

Policies enforce at the gateway boundary. Attach a policy engine to a gateway, then add policies:

1. `create-policy-engine` with gateway reference
2. `create-policy` with Cedar policy content
3. Tool invocations through the gateway are now subject to policy evaluation
4. Monitor policy evaluation results in CloudWatch

## Related Services

- [Gateway Service](../gateway/README.md) — where policies are enforced
- [Identity Service](../identity/README.md) — principals used in policy rules
- [AWS Policy Documentation](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/policy.html)
- [Cedar Language Reference](https://docs.cedarpolicy.com/)
