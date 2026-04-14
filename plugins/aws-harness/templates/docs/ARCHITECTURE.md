---
owner: "@{{OWNER}}"
updated: 2026-04-14
status: draft
---

# Architecture — {{PROJECT_NAME}}

> Keep this in sync with the code. An `architecture-drift-detector` skill (M7) will compare this diagram against the synthesized CDK construct tree and flag divergence.

## System diagram

```mermaid
flowchart LR
  subgraph client[Client]
    C[Caller]
  end
  subgraph aws[AWS account {{SANDBOX_ACCOUNT}} / {{UAT_REGION}}]
    API[API]
    C --> API
  end
```

Replace the placeholder diagram with the real one as the system takes shape.

## Components

| Component | Layer | Purpose | Owner |
|---|---|---|---|
| _to be filled_ | | | |

## Cross-cutting concerns

- **Observability:** CloudWatch logs + metrics + X-Ray traces. Queryable via `cloudwatch-query` skill.
- **Auth:** _to be decided_
- **Configuration:** SSM Parameter Store for cross-construct discovery (do not use CloudFormation Outputs for inter-stack wiring — causes circular dependencies). Pattern proven in viking-context-service.

## Dependency direction rules

Within each business domain, code depends forward through layers: `Types → Config → Repo → Service → Runtime → UI`. Cross-cutting concerns enter through `Providers` only. Enforced by structural tests (coming in M4).
