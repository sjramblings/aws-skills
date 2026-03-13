---
name: aws-mcp-setup
description: >-
  Configure AWS MCP servers for documentation search, API access, and
  infrastructure management. Use when setting up AWS MCP, configuring AWS
  documentation tools, troubleshooting MCP connectivity, browsing the AWS
  MCP server catalog, or when user mentions aws-mcp, awsdocs, uvx setup,
  MCP server configuration, AWS documentation search, AWS tools for Claude,
  mcp-proxy-for-aws, or knowledge-mcp. Covers the MCP Proxy for AWS
  (with uvx + credentials), the AWS Knowledge MCP Server (no auth), and
  the full catalog of 40+ specialized AWS MCP servers.
allowed-tools:
  - Bash(which *)
  - Bash(uvx --version*)
  - Bash(aws sts get-caller-identity*)
  - Bash(claude mcp *)
  - Bash(cat *mcp.json*)
  - Bash(cat *claude.json*)
  - Bash(docker pull *)
---

# AWS MCP Server Configuration Guide

## Overview

This guide helps you configure AWS MCP tools for AI agents. Three tiers are available:

| Option | Requirements | Capabilities |
|--------|--------------|--------------|
| **MCP Proxy for AWS** | Python 3.10+, uvx or Docker, AWS credentials | Full AWS API access + documentation search |
| **AWS Knowledge MCP Server** | None | Documentation search, recommendations, regional availability |
| **Specialized MCP Servers** | Python 3.10+, uvx | Domain-specific tools (IaC, EKS, ECS, Serverless, etc.) — see `references/mcp-server-catalog.md` |

## Step 1: Check Existing Configuration

Before configuring, check if AWS MCP tools are already available using either method:

### Method A: Check Available Tools (Recommended)

Look for these tool name patterns in your agent's available tools:
- `mcp__aws-mcp__*` or `mcp__aws__*` → Full AWS MCP Server configured
- `mcp__*awsdocs*__aws___*` → AWS Knowledge MCP configured

**How to check**: Run `/mcp` command to list all active MCP servers.

### Method B: Check Configuration Files

Agent tools use hierarchical configuration (precedence: local → project → user → enterprise):

| Scope | File Location | Use Case |
|-------|---------------|----------|
| Local | `.claude.json` (in project) | Personal/experimental |
| Project | `.mcp.json` (project root) | Team-shared |
| User | `~/.claude.json` | Cross-project personal |
| Enterprise | System managed directories | Organization-wide |

Check these files for `mcpServers` containing `aws-mcp`, `aws`, or `awsdocs` keys:

```bash
# Check project config
cat .mcp.json 2>/dev/null | grep -E '"(aws-mcp|aws|awsdocs)"'

# Check user config
cat ~/.claude.json 2>/dev/null | grep -E '"(aws-mcp|aws|awsdocs)"'

# Or use Claude CLI
claude mcp list
```

If AWS MCP is already configured, no further setup needed.

## Step 2: Choose Configuration Method

### Automatic Detection

Run these commands to determine which option to use:

```bash
# Check for uvx (requires Python 3.10+)
which uvx || echo "uvx not available"

# Check for valid AWS credentials
aws sts get-caller-identity || echo "AWS credentials not configured"
```

### Option A: MCP Proxy for AWS (Recommended)

**Use when**: uvx available AND AWS credentials valid

**Prerequisites**:
- Python 3.10+ with `uv` package manager (or Docker)
- AWS credentials configured (via profile, environment variables, or IAM role)

**IAM Permissions**: The proxy signs requests with your existing IAM credentials using SigV4. No special `aws-mcp:*` permissions exist — your IAM role/user needs permissions for whatever AWS services the upstream MCP server exposes (e.g., `bedrock:*` for Bedrock APIs, `bedrock-agentcore:*` for AgentCore Gateway MCP).

**Configuration** (uvx — add to your MCP settings):
```json
{
  "mcpServers": {
    "aws-mcp": {
      "command": "uvx",
      "args": [
        "mcp-proxy-for-aws@latest",
        "https://aws-mcp.us-east-1.api.aws/mcp",
        "--metadata", "AWS_REGION=us-west-2"
      ]
    }
  }
}
```

**Configuration** (Docker alternative):
```bash
docker pull public.ecr.aws/mcp-proxy-for-aws/mcp-proxy-for-aws:latest
```
```json
{
  "mcpServers": {
    "aws-mcp": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "--volume", "/full/path/to/.aws:/app/.aws:ro",
        "public.ecr.aws/mcp-proxy-for-aws/mcp-proxy-for-aws:latest",
        "https://aws-mcp.us-east-1.api.aws/mcp",
        "--metadata", "AWS_REGION=us-west-2"
      ]
    }
  }
}
```

**Credential Configuration Options**:

1. **AWS Profile** (recommended for development):
   ```json
   "args": [
     "mcp-proxy-for-aws@latest",
     "https://aws-mcp.us-east-1.api.aws/mcp",
     "--profile", "my-profile",
     "--metadata", "AWS_REGION=us-west-2"
   ]
   ```

2. **Environment Variables**:
   ```json
   "env": {
     "AWS_ACCESS_KEY_ID": "...",
     "AWS_SECRET_ACCESS_KEY": "...",
     "AWS_REGION": "us-west-2"
   }
   ```

3. **IAM Role** (for EC2/ECS/Lambda): No additional config needed — uses instance credentials.

**CLI Options**:

| Flag | Default | Description |
|------|---------|-------------|
| `--profile` | `$AWS_PROFILE` | AWS profile for credentials |
| `--region` | `$AWS_REGION` / `us-east-1` | AWS region |
| `--metadata` | `AWS_REGION` auto-injected | Key=value pairs injected into MCP requests |
| `--read-only` | `false` | Restrict to read-only tools |
| `--timeout` | `180` | Overall timeout (seconds) |
| `--connect-timeout` | `60` | Connection timeout (seconds) |
| `--read-timeout` | `120` | Read timeout (seconds) |
| `--write-timeout` | `180` | Write timeout (seconds) |
| `--retries` | `0` | Number of retries for upstream calls |
| `--service` | Auto-inferred | AWS service name for SigV4 signing |
| `--log-level` | `INFO` | Logging level (DEBUG/INFO/WARNING/ERROR/CRITICAL) |

**Library Mode** (Python frameworks): Install `pip install mcp-proxy-for-aws` and use `aws_iam_streamablehttp_client()` for direct integration with Strands, LangChain, or LlamaIndex. See the [mcp-proxy-for-aws README](https://github.com/aws/mcp-proxy-for-aws) for client patterns.

**Reference**: https://github.com/aws/mcp-proxy-for-aws

### Option B: AWS Knowledge MCP Server (No Auth)

**Use when**:
- No Python/uvx environment
- No AWS credentials
- Only need documentation search (no API execution)

**Configuration**:
```json
{
  "mcpServers": {
    "awsdocs": {
      "type": "http",
      "url": "https://knowledge-mcp.global.api.aws"
    }
  }
}
```

For stdio-only clients, use the fastmcp proxy: `uvx fastmcp run https://knowledge-mcp.global.api.aws`

**Available Tools**:
- `search_documentation` — Search across all AWS documentation with topic-based filtering
- `read_documentation` — Retrieve and convert AWS documentation pages to markdown
- `recommend` — Get content recommendations for AWS documentation pages
- `list_regions` — Retrieve all AWS regions with identifiers and names
- `get_regional_availability` — Check regional availability for services, features, SDK APIs, and CloudFormation resources

**Knowledge Sources**: AWS docs, API references, What's New, Getting Started guides, Builder Center, Blog posts, Well-Architected guidance, CDK constructs.

### Option C: Specialized AWS MCP Servers

For domain-specific AWS tools (IaC, EKS, ECS, Serverless, databases, and more), see the full catalog in `references/mcp-server-catalog.md`.

Quick setup for the most popular servers:

```bash
# IaC (CDK, CloudFormation, security validation)
claude mcp add aws-iac -- uvx awslabs.aws-iac-mcp-server@latest

# EKS (Kubernetes cluster management)
claude mcp add aws-eks -- uvx awslabs.eks-mcp-server@latest

# Serverless (SAM CLI lifecycle)
claude mcp add aws-serverless -- uvx awslabs.aws-serverless-mcp-server@latest
```

## Step 3: Verification

After configuration, verify tools are available:

**For MCP Proxy**: Look for tools like `mcp__aws-mcp__aws___search_documentation`, `mcp__aws-mcp__aws___call_aws`

**For Knowledge MCP**: Look for tools like `mcp__awsdocs__aws___search_documentation`, `mcp__awsdocs__aws___read_documentation`

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `uvx: command not found` | uv not installed | Install with `pip install uv` or use Docker/Option B |
| `AccessDenied` error | Missing IAM permissions for target service | Add permissions for the specific AWS service being accessed |
| `InvalidSignatureException` | Credential issue | Check `aws sts get-caller-identity` |
| Tools not appearing | MCP not started | Restart your agent after config change |
| Docker mount errors | Wrong `.aws` path | Use absolute path to your `~/.aws` directory |
| Timeout errors | Slow upstream response | Increase `--timeout` and `--read-timeout` values |
