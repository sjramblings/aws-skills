# AgentCore Code Interpreter Service

> **Status**: GA

## Overview

Amazon Bedrock AgentCore Code Interpreter enables agents to securely execute code in isolated sandbox environments, supporting data analysis, computational tasks, and dynamic code execution.

## Core Capabilities

- **Isolated Sandboxes**: Each execution runs in a completely isolated environment with no cross-contamination
- **Framework Integration**: Works with LangGraph, CrewAI, Strands, and other agent frameworks
- **Multi-Language**: Execute code in Python, JavaScript, and other languages
- **File Operations**: Upload and download files for processing
- **Network Modes**: Public, sandbox (no network), or VPC — configured at creation time

## CLI Commands

```bash
# Create a code interpreter resource
aws bedrock-agentcore-control create-code-interpreter \
  --code-interpreter-name my-interpreter \
  --region us-west-2

# Get code interpreter details
aws bedrock-agentcore-control get-code-interpreter \
  --code-interpreter-identifier <INTERPRETER_ID> \
  --region us-west-2

# List code interpreters
aws bedrock-agentcore-control list-code-interpreters \
  --region us-west-2

# Delete code interpreter
aws bedrock-agentcore-control delete-code-interpreter \
  --code-interpreter-identifier <INTERPRETER_ID> \
  --region us-west-2
```

## Use Cases

- **Data Analysis**: Process and analyze datasets, perform statistical calculations, generate visualizations
- **Computational Workflows**: Run scientific computations, business logic, batch processing
- **Dynamic Testing**: Test code snippets, validate algorithms, prototype solutions

## Best Practices

- Validate all code inputs before execution
- Use resource limits to prevent denial of service
- Set appropriate timeout values for expected workload
- Minimize data transfer in and out of sandboxes
- Use sandbox network mode when external access is not needed

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Execution Timeout | Code exceeds timeout limit | Increase timeout or optimize code |
| Memory Limit Exceeded | Code runs out of memory | Process data in chunks |
| Package Import Errors | Required packages not found | Check available packages or use custom runtime |
| Permission Denied | Insufficient IAM permissions | Verify IAM policy for code interpreter access |

## Related Services

- [Runtime Service](../runtime/README.md) — agent execution environment
- [Memory Service](../memory/README.md) — store computation results
- [AWS Code Interpreter Documentation](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/code-interpreter.html)
