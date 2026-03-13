# AgentCore CDK L2 Constructs Reference

Comprehensive API reference for `@aws-cdk/aws-bedrock-agentcore-alpha` (v2.243.0+). All examples in Python.

> **Status**: Experimental — APIs may change without backward compatibility. Breaking changes announced in release notes.

## Table of Contents

- [Import Convention](#import-convention)
- [Runtime](#runtime)
- [Gateway](#gateway)
- [Gateway Target](#gateway-target)
- [Browser](#browser)
- [Code Interpreter](#code-interpreter)
- [Memory](#memory)
- [Bedrock Model Grants](#bedrock-model-grants)
- [Testing AgentCore Stacks](#testing-agentcore-stacks)
- [Gotchas and JSII Pitfalls](#gotchas-and-jsii-pitfalls)

---

## Import Convention

```python
# Python (JSII-wrapped alpha module)
import aws_cdk.aws_bedrock_agentcore_alpha as agentcore
```

```typescript
// TypeScript
import * as agentcore from '@aws-cdk/aws-bedrock-agentcore-alpha';
```

---

## Runtime

`agentcore.Runtime` — Deploys containerized or direct-code agents on Amazon Bedrock AgentCore.

### Properties

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `runtime_name` | `str` | No | Letters, numbers, underscores only. Max 48 chars, starts with letter |
| `agent_runtime_artifact` | `AgentRuntimeArtifact` | Yes | Container or code artifact configuration |
| `execution_role` | `iam.IRole` | No | IAM role; auto-created if omitted |
| `network_configuration` | `RuntimeNetworkConfiguration` | No | Public (default) or VPC |
| `description` | `str` | No | Optional description |
| `protocol_configuration` | `ProtocolType` | No | Defaults to HTTP |
| `authorizer_configuration` | `RuntimeAuthorizerConfiguration` | No | IAM (default), Cognito, JWT, or OAuth |
| `environment_variables` | `dict[str, str]` | No | Max 50 environment variables |
| `lifecycle_configuration` | `LifecycleConfiguration` | No | Idle timeout (900s default), max lifetime (28800s default) |
| `request_header_configuration` | `RequestHeaderConfiguration` | No | HTTP header pass-through config |
| `tags` | `dict[str, str]` | No | Key-value tags |

### Artifact Factories

Four ways to provide the runtime artifact:

**1. Docker Asset (local Dockerfile)**
```python
artifact = agentcore.AgentRuntimeArtifact.from_asset(
    str(agent_dir),
    file="Dockerfile",
)
```

**2. S3 Direct Code Deployment**
```python
# JSII expects camelCase keys: bucketName, objectKey (NOT bucket_name, object_key)
artifact = agentcore.AgentRuntimeArtifact.from_s3(
    s3_location={
        "bucketName": code_bucket.bucket_name,
        "objectKey": deployed_key,
    },
    runtime=agentcore.AgentCoreRuntime.PYTHON_3_12,
    entrypoint=["main.py"],
)
```

**3. Existing ECR Repository**
```python
artifact = agentcore.AgentRuntimeArtifact.from_ecr_repository(repository, "v1.0.0")
```

**4. ECR Image URI**
```python
artifact = agentcore.AgentRuntimeArtifact.from_image_uri(
    "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-agent:v1.0.0"
)
```

### Authentication

**IAM (default)** — no `authorizer_configuration` needed.

**Cognito**
```python
runtime = agentcore.Runtime(self, "MyRuntime",
    runtime_name="my_runtime",
    agent_runtime_artifact=artifact,
    authorizer_configuration=agentcore.RuntimeAuthorizerConfiguration.using_cognito(
        user_pool, [user_pool_client], ["audience1"], ["read", "write"],
        custom_claims,
    ),
)
```

**JWT**
```python
agentcore.RuntimeAuthorizerConfiguration.using_jwt(
    "https://example.com/.well-known/openid-configuration",
    ["client1"], ["audience1"], ["read"],
)
```

**OAuth**
```python
agentcore.RuntimeAuthorizerConfiguration.using_o_auth(
    "https://github.com/.well-known/openid-configuration",
    "oauth_client_123", ["audience1"], ["openid", "profile"],
)
```

### Network Configuration

```python
# Public (default)
agentcore.RuntimeNetworkConfiguration.using_public_network()

# VPC
agentcore.RuntimeNetworkConfiguration.using_vpc(self,
    vpc=vpc,
    vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS),
)
```

VPC-based runtimes implement `ec2.IConnectable` — use `runtime.connections` for security group management:
```python
runtime.connections.allow_from(web_sg, ec2.Port.tcp(443), "Allow HTTPS")
```

### Endpoints

Pin specific versions with stable invocation points:
```python
prod_endpoint = runtime.add_endpoint("production",
    version="1",
    description="Stable production endpoint - pinned to v1",
)
```

### Lifecycle Configuration

```python
runtime = agentcore.Runtime(self, "MyRuntime",
    runtime_name="my_runtime",
    agent_runtime_artifact=artifact,
    lifecycle_configuration={
        "idle_runtime_session_timeout": cdk.Duration.minutes(10),
        "max_lifetime": cdk.Duration.hours(4),
    },
)
```

### Grant Methods

```python
# Grant another principal permission to invoke this runtime
runtime.grant_invoke_runtime(lambda_fn)       # InvokeRuntime action
runtime.grant_invoke_runtime_for_user(lambda_fn)  # InvokeRuntimeForUser action
runtime.grant_invoke(lambda_fn)               # Both actions

# Custom permissions on the runtime's own role
runtime.grant(["bedrock:InvokeModel"], ["arn:aws:bedrock:*:*:*"])
runtime.add_to_role_policy(iam.PolicyStatement(
    actions=["s3:GetObject"],
    resources=["arn:aws:s3:::my-bucket/*"],
))
```

### Useful Attributes

- `runtime.agent_runtime_id` — Runtime ID (for CfnOutput, invoke commands)
- `runtime.execution_role` — The IAM role used by the runtime

---

## Gateway

`agentcore.Gateway` — Integration point between agents and external services (MCP protocol).

### Properties

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `gateway_name` | `str` | No | Alphanumeric and hyphens only (no underscores). Max 100 chars |
| `description` | `str` | No | Max 200 chars |
| `protocol_configuration` | `IGatewayProtocolConfig` | No | MCP protocol (default) |
| `authorizer_configuration` | `IGatewayAuthorizerConfig` | No | Cognito (default), JWT, or IAM |
| `exception_level` | `GatewayExceptionLevel` | No | DEBUG or standard |
| `kms_key` | `kms.IKey` | No | KMS key for encryption |
| `role` | `iam.IRole` | No | IAM role; auto-created if omitted |
| `tags` | `dict[str, str]` | No | Key-value tags |

### MCP Protocol Configuration

```python
gateway = agentcore.Gateway(self, "MyGateway",
    gateway_name="my-gateway",
    protocol_configuration=agentcore.McpProtocolConfiguration(
        instructions="Use this gateway to connect to external MCP tools",
        search_type=agentcore.McpGatewaySearchType.SEMANTIC,
        supported_versions=[agentcore.MCPProtocolVersion.MCP_2025_03_26],
    ),
)
```

### Authorization

**Cognito (default)** — auto-creates a User Pool + client for M2M auth:
```python
gateway = agentcore.Gateway(self, "MyGateway",
    gateway_name="my-gateway",
)

# Auto-created properties:
gateway.user_pool           # Cognito User Pool
gateway.user_pool_client    # Cognito User Pool Client (None with custom auth)
gateway.token_endpoint_url  # Token endpoint for client_credentials flow
gateway.oauth_scopes        # OAuth scopes list
gateway.gateway_url         # MCP endpoint URL
gateway.gateway_id          # Gateway ID
```

**Custom JWT**
```python
agentcore.GatewayAuthorizer.using_custom_jwt(
    discovery_url="https://auth.example.com/.well-known/openid-configuration",
    allowed_audience=["my-app"],
    allowed_clients=["my-client-id"],
    allowed_scopes=["read", "write"],
    custom_claims=[
        agentcore.GatewayCustomClaim.with_string_value("department", "engineering"),
    ],
)
```

**IAM**
```python
gateway = agentcore.Gateway(self, "MyGateway",
    gateway_name="my-gateway",
    authorizer_configuration=agentcore.GatewayAuthorizer.using_aws_iam(),
)
gateway.grant_invoke(lambda_role)
```

### KMS Encryption

```python
gateway = agentcore.Gateway(self, "MyGateway",
    gateway_name="my-encrypted-gateway",
    kms_key=kms.Key(self, "GatewayKey", enable_key_rotation=True),
    exception_level=agentcore.GatewayExceptionLevel.DEBUG,
)
```

### Grant Methods

```python
gateway.grant_read(role)    # Get and List actions
gateway.grant_manage(role)  # Create, Update, Delete actions
gateway.grant_invoke(role)  # Invoke (IAM auth only)
gateway.grant(role, "bedrock-agentcore:GetGateway")
```

---

## Gateway Target

Defines tools that a Gateway hosts. Created via `gateway.add_*_target()` methods (recommended) or `GatewayTarget.for_*()` static factories.

### Target Types

| Method | Auth | Schema Type |
|--------|------|-------------|
| `add_lambda_target()` | GATEWAY_IAM_ROLE (auto) | `ToolSchema` |
| `add_open_api_target()` | API_KEY or OAUTH | `ApiSchema` |
| `add_smithy_target()` | API_KEY or OAUTH | `ApiSchema` |
| `add_mcp_server_target()` | OAuth2 | None (auto-discovery) |
| `add_api_gateway_target()` | IAM (auto) | None (derived from API) |

### ToolSchema Factories (for Lambda targets)

```python
# Inline definition
tool_schema = agentcore.ToolSchema.from_inline([
    {
        "name": "get_time",
        "description": "Returns the current UTC time.",
        "inputSchema": agentcore.SchemaDefinition(
            type=agentcore.SchemaDefinitionType.OBJECT,
            properties={},
            required=[],
        ),
    }
])

# From local file
tool_schema = agentcore.ToolSchema.from_local_asset("schemas/my-tools.json")

# From S3
tool_schema = agentcore.ToolSchema.from_s3_file(bucket, "tools/schema.json", "123456789012")
```

### ApiSchema Factories (for OpenAPI/Smithy targets)

```python
# Inline OpenAPI
api_schema = agentcore.ApiSchema.from_inline("openapi: 3.0.3\n...")

# From local file
api_schema = agentcore.ApiSchema.from_local_asset("schemas/openapi.yaml")
api_schema.bind(self)  # Required before use

# From S3
api_schema = agentcore.ApiSchema.from_s3_file(bucket, "schemas/openapi.yaml")
```

### Lambda Target Example

```python
gateway.add_lambda_target(
    "SimpleToolTarget",
    gateway_target_name="simple-tools",
    description="Simple get_time tool for demo.",
    lambda_function=simple_tool_fn,
    tool_schema=tool_schema,
)
```

Gateway role automatically gets `lambda:InvokeFunction` permission on the function.

### OpenAPI Target with API Key

```python
target = gateway.add_open_api_target("MyTarget",
    gateway_target_name="my-api-target",
    description="External API integration",
    api_schema=api_schema,
    credential_provider_configurations=[
        agentcore.GatewayCredentialProvider.from_api_key_identity_arn(
            provider_arn="arn:aws:bedrock-agentcore:...:apikeycredentialprovider/my-key",
            secret_arn="arn:aws:secretsmanager:...:secret:my-secret",
            credential_location=agentcore.ApiKeyCredentialLocation.header(
                credential_parameter_name="X-API-Key",
            ),
        ),
    ],
)
```

### MCP Server Target

```python
mcp_target = gateway.add_mcp_server_target("MyMcpServer",
    gateway_target_name="my-mcp-server",
    description="External MCP server",
    endpoint="https://my-mcp-server.example.com",
    credential_provider_configurations=[
        agentcore.GatewayCredentialProvider.from_oauth_identity_arn(
            provider_arn=oauth_provider_arn,
            secret_arn=oauth_secret_arn,
            scopes=["mcp-runtime-server/invoke"],
        ),
    ],
)
# Sync tools after creation
mcp_target.grant_sync(sync_function)
```

### API Gateway Target

```python
gateway.add_api_gateway_target("MyApiTarget",
    rest_api=api,
    api_gateway_tool_configuration={
        "tool_filters": [
            {"filter_path": "/pets/*", "methods": [agentcore.ApiGatewayHttpMethod.GET]},
        ],
    },
)
```

### Tool Naming Convention

Tools are exposed as `{target_name}__{tool_name}`. Example: target `simple-tools` with tool `get_time` becomes `simple-tools__get_time`. Lambda handlers must strip the prefix:
```python
tool_name = (event.get("toolName") or "").split("__")[-1]
```

---

## Browser

`agentcore.BrowserCustom` — Cloud browser for AI agents to interact with websites.

### Properties

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `browser_custom_name` | `str` | No | Letters, numbers, underscores. Max 48 chars |
| `description` | `str` | No | Max 200 chars |
| `network_configuration` | `BrowserNetworkConfiguration` | No | Public (default) or VPC |
| `recording_config` | `RecordingConfig` | No | S3 recording configuration |
| `execution_role` | `iam.IRole` | No | Auto-created if omitted |
| `browser_signing` | `BrowserSigning` | No | ENABLED or DISABLED |
| `tags` | `dict[str, str]` | No | Key-value tags |

### Example

```python
browser = agentcore.BrowserCustom(self, "MyBrowser",
    browser_custom_name="my_browser",
    description="Browser for web automation",
    network_configuration=agentcore.BrowserNetworkConfiguration.using_public_network(),
    recording_config={
        "enabled": True,
        "s3_location": {
            "bucketName": recording_bucket.bucket_name,
            "objectKey": "browser-recordings/",
        },
    },
)
```

### Grant Methods

```python
browser.grant_read(role)  # Get and List actions
browser.grant_use(role)   # Start, Update, Stop actions
browser.grant(role, "bedrock-agentcore:GetBrowserSession")
```

---

## Code Interpreter

`agentcore.CodeInterpreterCustom` — Secure code execution in sandbox environments.

### Properties

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `code_interpreter_custom_name` | `str` | No | Letters, numbers, underscores. Max 48 chars |
| `description` | `str` | No | Max 200 chars |
| `execution_role` | `iam.IRole` | No | Auto-created if omitted |
| `network_configuration` | `CodeInterpreterNetworkConfiguration` | No | Public (default), Sandbox, or VPC |
| `tags` | `dict[str, str]` | No | Key-value tags |

### Network Modes

```python
# Public (default) — internet access for package installs
agentcore.CodeInterpreterNetworkConfiguration.using_public_network()

# Sandbox — isolated, no internet
agentcore.CodeInterpreterNetworkConfiguration.using_sandbox_network()

# VPC
agentcore.CodeInterpreterNetworkConfiguration.using_vpc(self, vpc=vpc)
```

### Grant Methods

```python
code_interpreter.grant_read(role)  # Get and List
code_interpreter.grant_use(role)   # Start, Invoke, Stop
```

---

## Memory

`agentcore.Memory` — Manages agent conversation memory with extraction strategies.

### Properties

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `memory_custom_name` | `str` | No | Letters, numbers, underscores. Max 48 chars |
| `description` | `str` | No | Max 200 chars |
| `execution_role` | `iam.IRole` | No | Auto-created if omitted |
| `ltm_extraction_strategy` | Extraction strategy | No | Built-in or self-managed |
| `tags` | `dict[str, str]` | No | Key-value tags |

### Extraction Strategies

```python
# Built-in extraction
memory = agentcore.Memory(self, "MyMemory",
    memory_custom_name="my_memory",
    ltm_extraction_strategy=agentcore.BuiltInLtmExtractionStrategy.IMPLICIT_COMPRESSION,
)

# Self-managed (no automatic extraction)
memory = agentcore.Memory(self, "MyMemory",
    memory_custom_name="my_memory",
    ltm_extraction_strategy=agentcore.SelfManagedLtmExtractionStrategy.NONE,
)
```

---

## Bedrock Model Grants

Use `aws_cdk.aws_bedrock_alpha` for typed model grants instead of inline IAM:

```python
import aws_cdk.aws_bedrock_alpha as bedrock

# Grant direct model invocation
model = bedrock.BedrockFoundationModel.ANTHROPIC_CLAUDE_SONNET_4_V1_0
model.grant_invoke(runtime)

# Grant cross-region inference profile
inference_profile = bedrock.CrossRegionInferenceProfile.from_config(
    geo_region=bedrock.CrossRegionInferenceProfileRegion.US,
    model=bedrock.BedrockFoundationModel.ANTHROPIC_CLAUDE_SONNET_4_V1_0,
)
inference_profile.grant_invoke(runtime)
```

**Fallback** — if not using the bedrock alpha module, use inline IAM:
```python
runtime.add_to_role_policy(iam.PolicyStatement(
    actions=["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"],
    resources=[
        "arn:aws:bedrock:*:*:inference-profile/*",
        "arn:aws:bedrock:*:*:foundation-model/*",
    ],
))
```

---

## Testing AgentCore Stacks

Python pytest with CDK assertions:

```python
import aws_cdk as cdk
from aws_cdk.assertions import Template

from infrastructure.stacks import SimpleRuntimeStack

def test_simple_runtime_has_runtime_resource():
    app = cdk.App()
    stack = SimpleRuntimeStack(app, "TestStack")
    template = Template.from_stack(stack)

    template.has_resource_properties("AWS::BedrockAgentCore::Runtime", {
        "RuntimeName": "simple_runtime",
    })

def test_simple_runtime_resource_count():
    app = cdk.App()
    stack = SimpleRuntimeStack(app, "TestStack")
    template = Template.from_stack(stack)

    template.resource_count_is("AWS::BedrockAgentCore::Runtime", 1)
```

---

## Gotchas and JSII Pitfalls

### camelCase in dicts

When passing dicts for TypeScript interfaces via JSII, use **camelCase** keys:
```python
# Correct
s3_location={"bucketName": bucket.bucket_name, "objectKey": key}

# Wrong — will error: Missing required properties 'bucketName', 'objectKey'
s3_location={"bucket_name": bucket.bucket_name, "object_key": key}
```

### Naming rules

| Resource | Allowed | Example |
|----------|---------|---------|
| Runtime name | Letters, numbers, underscores | `simple_runtime` |
| Gateway name | Alphanumeric, hyphens (between chars) | `my-gateway` |
| Gateway target name | Alphanumeric, hyphens (between chars) | `simple-tools` |

### node.add_dependency()

When a runtime depends on an S3 deployment finishing first:
```python
runtime.node.add_dependency(deployment)
```

### Alpha import path

The module is `aws_cdk.aws_bedrock_agentcore_alpha` — note the `_alpha` suffix. This is separate from `aws_cdk.aws_bedrock_alpha` (Bedrock L2 constructs for models/agents).

### user_pool_client can be None

With custom JWT or IAM auth, `gateway.user_pool_client` is `None`. Guard access:
```python
cognito_client_id = (
    gateway.user_pool_client.user_pool_client_id if gateway.user_pool_client else ""
)
```

### CDK deployment role

Must have `iam:CreateServiceLinkedRole` permission for AgentCore service-linked roles.
