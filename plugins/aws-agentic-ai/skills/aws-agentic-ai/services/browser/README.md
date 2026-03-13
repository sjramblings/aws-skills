# AgentCore Browser Service

> **Status**: GA

## Overview

Amazon Bedrock AgentCore Browser provides a fast, secure, cloud-based browser runtime enabling AI agents to interact with websites at scale without infrastructure management. Each session runs in complete isolation with auto-scaling.

## Core Capabilities

- **Cloud-Based Runtime**: High-performance browser instances with auto-scaling, zero infrastructure
- **Isolated Sessions**: Each browsing session runs in a fully isolated environment
- **Web Interaction**: Navigate, click, fill forms, execute JavaScript, extract content, take screenshots
- **Session Management**: Handle cookies, local storage, and sessions across page navigations
- **Browser Profiles**: Reusable configurations for common browsing patterns

## CLI Commands

### Browser CRUD

```bash
# Create a browser resource
aws bedrock-agentcore-control create-browser \
  --browser-name my-browser \
  --region us-west-2

# Get browser details
aws bedrock-agentcore-control get-browser \
  --browser-identifier <BROWSER_ID> \
  --region us-west-2

# List browsers
aws bedrock-agentcore-control list-browsers \
  --region us-west-2

# Delete browser
aws bedrock-agentcore-control delete-browser \
  --browser-identifier <BROWSER_ID> \
  --region us-west-2
```

### Browser Profile CRUD

```bash
# Create a browser profile (reusable configuration)
aws bedrock-agentcore-control create-browser-profile \
  --browser-profile-name my-profile \
  --region us-west-2

# Get browser profile
aws bedrock-agentcore-control get-browser-profile \
  --browser-profile-identifier <PROFILE_ID> \
  --region us-west-2

# List browser profiles
aws bedrock-agentcore-control list-browser-profiles \
  --region us-west-2

# Delete browser profile
aws bedrock-agentcore-control delete-browser-profile \
  --browser-profile-identifier <PROFILE_ID> \
  --region us-west-2
```

## Use Cases

- **Web Scraping**: Extract structured data from websites at scale, monitor changes
- **Workflow Automation**: Automate form submissions, multi-step web workflows, authentication flows
- **Content Verification**: Validate web content, check link integrity, verify page rendering

## Best Practices

- Use headless mode for non-visual operations
- Set appropriate timeouts for page loads
- Validate all URLs before navigation
- Use the Identity service for credentials needed to access protected sites
- Close browser sessions when done to manage costs

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Page Load Timeout | Page takes too long to load | Increase timeout or optimize target page |
| Element Not Found | Cannot locate page element | Use explicit waits or verify selector |
| Session Terminated | Browser session unexpectedly ends | Check resource limits and session timeout |
| Authentication Required | Cannot access protected pages | Configure credentials via Identity service |

## Related Services

- [Runtime Service](../runtime/README.md) — agent execution
- [Code Interpreter](../code-interpreter/README.md) — process scraped data
- [Memory Service](../memory/README.md) — store extracted data
- [AWS Browser Documentation](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/browser.html)
