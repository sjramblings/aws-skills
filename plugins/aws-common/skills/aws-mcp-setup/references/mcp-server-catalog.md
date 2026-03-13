# AWS MCP Server Catalog

> Source: https://github.com/awslabs/mcp — 40+ servers across infrastructure, AI/ML, data, and developer tools.

## Remote Servers (no local install)

### AWS MCP Server (Preview)
- **Endpoint**: `https://aws-mcp.us-east-1.api.aws/mcp` (via `mcp-proxy-for-aws`)
- **Auth**: AWS credentials (SigV4)
- **Purpose**: Comprehensive AWS API support + documentation + SOPs
- **Config**: See SKILL.md Option A

### AWS Knowledge MCP Server (GA)
- **Endpoint**: `https://knowledge-mcp.global.api.aws`
- **Auth**: None
- **Tools**: `search_documentation`, `read_documentation`, `recommend`, `list_regions`, `get_regional_availability`
- **Config**: `{ "type": "http", "url": "https://knowledge-mcp.global.api.aws" }`

## Infrastructure & IaC

### AWS IaC MCP Server (GA)
- **Package**: `awslabs.aws-iac-mcp-server@latest`
- **Purpose**: CloudFormation docs, CDK best practices, construct examples, security validation, deploy troubleshooting
- **Config**: `claude mcp add aws-iac -- uvx awslabs.aws-iac-mcp-server@latest`

### AWS Cloud Control API MCP Server (GA)
- **Package**: `awslabs.ccapi-mcp-server@latest`
- **Purpose**: Direct AWS resource management with security scanning and best practices

### AWS CloudFormation MCP Server (GA)
- **Package**: `awslabs.cfn-mcp-server@latest`
- **Purpose**: Direct CloudFormation resource management via Cloud Control API

## Containers

### Amazon EKS MCP Server (GA)
- **Package**: `awslabs.eks-mcp-server@latest`
- **Purpose**: Kubernetes cluster management and application deployment on EKS
- **Config**: `claude mcp add aws-eks -- uvx awslabs.eks-mcp-server@latest`

### Amazon ECS MCP Server (GA)
- **Package**: `awslabs.ecs-mcp-server@latest`
- **Purpose**: Container orchestration and ECS application deployment

### Finch MCP Server (GA)
- **Package**: `awslabs.finch-mcp-server@latest`
- **Purpose**: Local container building with ECR integration

## Serverless

### AWS Serverless MCP Server (GA)
- **Package**: `awslabs.aws-serverless-mcp-server@latest`
- **Purpose**: Complete serverless application lifecycle with SAM CLI
- **Config**: `claude mcp add aws-serverless -- uvx awslabs.aws-serverless-mcp-server@latest`

### AWS Lambda Tool MCP Server (GA)
- **Package**: `awslabs.lambda-tool-mcp-server@latest`
- **Purpose**: Execute Lambda functions as AI tools for private resource access

### AWS Step Functions Tool MCP Server (GA)
- **Package**: `awslabs.stepfunctions-tool-mcp-server@latest`
- **Purpose**: Execute complex workflows and business processes

## AI & Machine Learning

### Amazon Bedrock KB Retrieval MCP Server (GA)
- **Package**: `awslabs.bedrock-kb-retrieval-mcp-server@latest`
- **Purpose**: Query enterprise knowledge bases with citation support

### Amazon Bedrock AgentCore MCP Server (GA)
- **Package**: `awslabs.amazon-bedrock-agentcore-mcp-server@latest`
- **Purpose**: Documentation access on AgentCore platform services and APIs

### Nova Canvas MCP Server (GA)
- **Package**: `awslabs.nova-canvas-mcp-server@latest`
- **Purpose**: AI image generation using Amazon Nova Canvas

### AWS Bedrock Data Automation MCP Server (GA)
- **Package**: `awslabs.aws-bedrock-data-automation-mcp-server@latest`
- **Purpose**: Analyze documents, images, videos, and audio files

### Amazon SageMaker AI MCP Server (GA)
- **Package**: `awslabs.sagemaker-ai-mcp-server@latest`
- **Purpose**: SageMaker AI resource management and model development

### Amazon Q Business MCP Server (GA)
- **Package**: `awslabs.amazon-qbusiness-anonymous-mcp-server@latest`
- **Purpose**: AI assistant for ingested content with anonymous access

## Data & Analytics

### Amazon DynamoDB MCP Server (GA)
- **Package**: `awslabs.dynamodb-mcp-server@latest`
- **Purpose**: DynamoDB expert design guidance and data modeling

### Amazon Aurora PostgreSQL MCP Server (GA)
- **Package**: `awslabs.postgres-mcp-server@latest`
- **Purpose**: PostgreSQL database operations via RDS Data API

### Amazon Aurora MySQL MCP Server (GA)
- **Package**: `awslabs.mysql-mcp-server@latest`
- **Purpose**: MySQL database operations via RDS Data API

### Amazon Redshift MCP Server (GA)
- **Package**: `awslabs.redshift-mcp-server@latest`
- **Purpose**: Data warehouse operations and analytics queries

### Amazon DocumentDB MCP Server (GA)
- **Package**: `awslabs.documentdb-mcp-server@latest`
- **Purpose**: MongoDB-compatible document database operations

### Amazon Neptune MCP Server (GA)
- **Package**: `awslabs.amazon-neptune-mcp-server@latest`
- **Purpose**: Graph database queries with openCypher and Gremlin

### Amazon ElastiCache MCP Server (GA)
- **Package**: `awslabs.elasticache-mcp-server@latest`
- **Purpose**: Complete ElastiCache control plane operations

### Amazon MSK MCP Server (GA)
- **Package**: `awslabs.aws-msk-mcp-server@latest`
- **Purpose**: Managed Kafka cluster operations and streaming

## Developer Tools & Operations

### AWS IAM MCP Server (GA)
- **Package**: `awslabs.iam-mcp-server@latest`
- **Purpose**: Comprehensive IAM user, role, group, and policy management

### AWS Support MCP Server (GA)
- **Package**: `awslabs.aws-support-mcp-server@latest`
- **Purpose**: Create and manage AWS Support cases

### AWS Documentation MCP Server (GA)
- **Package**: `awslabs.aws-documentation-mcp-server@latest`
- **Purpose**: Latest AWS documentation and API references (local stdio alternative to Knowledge MCP)

### Amazon CloudWatch MCP Server (GA)
- **Package**: `awslabs.cloudwatch-mcp-server@latest`
- **Purpose**: Metrics, alarms, and logs analysis and operational troubleshooting

### AWS Cost Explorer MCP Server (GA)
- **Package**: `awslabs.cost-explorer-mcp-server@latest`
- **Purpose**: Detailed cost analysis and reporting

### AWS Pricing MCP Server (GA)
- **Package**: `awslabs.aws-pricing-mcp-server@latest`
- **Purpose**: AWS service pricing and cost estimates

## Integration & Messaging

### Amazon SNS/SQS MCP Server (GA)
- **Package**: `awslabs.amazon-sns-sqs-mcp-server@latest`
- **Purpose**: Event-driven messaging and queue management

### Amazon Location Service MCP Server (GA)
- **Package**: `awslabs.aws-location-mcp-server@latest`
- **Purpose**: Place search, geocoding, and route optimization

## Additional Servers

These servers are also available in the `awslabs/mcp` repo:

| Server | Package | Purpose |
|--------|---------|---------|
| Amazon Kendra Index | `awslabs.amazon-kendra-index-mcp-server@latest` | Enterprise search and RAG |
| Amazon Q Index | `awslabs.amazon-qindex-mcp-server@latest` | Enterprise Q index search |
| Bedrock Custom Model Import | `awslabs.aws-bedrock-custom-model-import-mcp-server@latest` | Custom model management |
| Aurora DSQL | `awslabs.aurora-dsql-mcp-server@latest` | Distributed SQL |
| Amazon Keyspaces | `awslabs.amazon-keyspaces-mcp-server@latest` | Cassandra-compatible operations |
| Timestream for InfluxDB | `awslabs.timestream-for-influxdb-mcp-server@latest` | Time-series database |
| S3 Tables | `awslabs.s3-tables-mcp-server@latest` | S3 Tables for analytics |
| IoT SiteWise | `awslabs.aws-iot-sitewise-mcp-server@latest` | Industrial IoT analytics |
| ElastiCache Valkey | `awslabs.valkey-mcp-server@latest` | Advanced caching with Valkey |
| ElastiCache Memcached | `awslabs.memcached-mcp-server@latest` | High-speed caching |
| Amazon MQ | `awslabs.amazon-mq-mcp-server@latest` | RabbitMQ/ActiveMQ brokers |
| Managed Prometheus | `awslabs.prometheus-mcp-server@latest` | Prometheus-compatible ops |
| AppSync | `awslabs.aws-appsync-mcp-server@latest` | Application backends |
| Git Repo Research | `awslabs.git-repo-research-mcp-server@latest` | Semantic code search |
| Frontend | `awslabs.frontend-mcp-server@latest` | React/web dev guidance |
| Synthetic Data | `awslabs.syntheticdata-mcp-server@latest` | Test data generation |
| OpenAPI | `awslabs.openapi-mcp-server@latest` | Dynamic API integration |

## Deprecated Servers

| Server | Replaced By |
|--------|-------------|
| AWS CDK MCP Server (`awslabs.cdk-mcp-server@latest`) | AWS IaC MCP Server |
| AWS Terraform MCP Server (`awslabs.terraform-mcp-server@latest`) | HashiCorp official Terraform MCP Server |
| Code Documentation Generator (`awslabs.code-doc-gen-mcp-server@latest`) | — |
| AWS Diagram (`awslabs.aws-diagram-mcp-server@latest`) | — |

## Configuration Patterns

### Adding a stdio server to Claude Code
```bash
claude mcp add <server-name> -- uvx <package>@latest
```

### Adding to .mcp.json (project-level)
```json
{
  "mcpServers": {
    "<name>": {
      "command": "uvx",
      "args": ["<package>@latest"]
    }
  }
}
```

### Adding to ~/.claude.json (user-level)
Same format as `.mcp.json`, applied globally across all projects.

## Source
Repository: https://github.com/awslabs/mcp
