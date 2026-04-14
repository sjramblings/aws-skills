# AWS Skills for Claude Code

Claude Code plugins for AWS development with specialized knowledge and MCP server integrations, including CDK, serverless architecture, cost optimization, and Bedrock AgentCore for AI agent deployment.

## Plugins

### 0. AWS Common Plugin (Dependency)

Shared AWS agent skills including AWS Documentation MCP configuration for querying up-to-date AWS knowledge.

**Features**:
- AWS MCP server configuration guide
- Documentation MCP setup for querying AWS knowledge
- Shared by all other AWS plugins as a dependency

**Note**: This plugin is automatically loaded as a dependency by other plugins. Install it first if installing plugins individually.

### 1. AWS CDK Plugin

AWS CDK development skill with integrated MCP server for infrastructure as code.

**Features**:
- AWS CDK best practices and patterns
- Pre-deployment validation script
- Comprehensive CDK patterns reference

**Integrated MCP Server**:
- AWS CDK MCP (stdio)

### 2. AWS Cost & Operations Plugin

Cost optimization, monitoring, and operational excellence with 3 integrated MCP servers.

**Features**:
- Cost estimation and optimization
- Monitoring and observability patterns
- Operational best practices

**Integrated MCP Servers**:
- AWS Pricing
- AWS Cost Explorer
- Amazon CloudWatch

### 3. AWS Serverless & Event-Driven Architecture Plugin

Serverless and event-driven architecture patterns based on Well-Architected Framework.

**Features**:
- Well-Architected serverless design principles
- Event-driven architecture patterns
- Orchestration with Step Functions
- Saga patterns for distributed transactions
- Event sourcing patterns

### 4. AWS Agentic AI Plugin

AWS Bedrock AgentCore comprehensive expert for deploying and managing AI agents.

**Features**:
- Gateway service for converting REST APIs to MCP tools
- Runtime service for deploying and scaling agents
- Memory service for managing conversation state
- Identity service for credential and access management
- Code Interpreter for secure code execution
- Browser service for web automation
- Observability for tracing and monitoring

### 5. AWS Harness Plugin

A complete Claude Code harness for building and deploying AWS software the agent-first way. Based on Ryan Lopopolo's [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering) — humans design environments, agents execute. Ships **17 skills**, **11 custom CDK lints**, **9 GitHub Actions workflows**, **4 hooks**, and a **15-principle golden canon** derived from real production lessons.

**The single command**:

```bash
/harness-init
```

Bootstraps a new (or existing) AWS project with the full scaffold: `docs/` system-of-record, `AGENTS.md` map, `.claude/` hooks, `.github/workflows/`, custom lints, per-PR ephemeral stack workflows, threat-model templates, and the learning loop.

**What you get on day 1**:

| Capability | Skills |
|---|---|
| Agent-legible AWS observability | `cfn-stack-events`, `cloudwatch-query`, `cloudtrail-investigator` |
| Phase-1 preflight gate | `capability-probe` (Bedrock model + region + IAM + marketplace) |
| Per-PR ephemeral stacks | `deploy-pr-stack`, `github-environments`, $5/day Budget guard |
| Security from Phase 1 | `threat-model-stride`, `security-review-aws`, 11 custom CDK lints |
| Self-verifying deploys | `post-deploy-verify` (YAML smoke tests), `integration-test-runner` |
| Failure → learning loop | `postmortem-capture`, `golden-principles-enforcer`, 4 hooks |
| Recurring doc cleanup | `doc-gardener`, `architecture-drift-detector` |
| Bedrock cost tracking | `withCostInstrumentation()` wrapper + `CostInstrumentationConstruct` |
| Self-improvement loop | `session-log-miner`, `harness-improvement-proposer` |

**Core invariants**:
1. **Legibility first** — raw CloudFormation, CloudWatch, and CloudTrail JSON are banned from agent context. Always go through the wrapper skills.
2. **AGENTS.md is a MAP** (under 150 lines, links only — enforced by lint).
3. **Plans are first-class artifacts** — checked into `docs/exec-plans/`.
4. **Failures are signal** — every deploy/test failure becomes a learning, every learning feeds a principle, every principle gets a backing lint.
5. **Start small, validate end-to-end, grow**.

**11 custom lints** (each with remediation hint that injects into agent context):

`cdk-confused-deputy`, `cdk-encryption-required`, `cdk-ssl-only`, `cdk-sqs-visibility-timeout`, `cdk-fifo-maxconcurrency`, `cdk-resource-tags`, `zod-parse-at-boundary`, `bedrock-cost-instrumentation`, `doc-freshness`, `agents-md-map-only`, `golden-principle-has-lint`.

Every lint is tied to a real production lesson — most from the viking-context-service retrospective.

## Installation

Add the marketplace to Claude Code:

```bash
/plugin marketplace add zxkane/aws-skills
```

Install plugins individually:

```bash
# Install the common dependency first
/plugin install aws-common@aws-skills

# Then install the plugins you need
/plugin install aws-cdk@aws-skills
/plugin install aws-cost-ops@aws-skills
/plugin install serverless-eda@aws-skills
/plugin install aws-agentic-ai@aws-skills

# Install the harness — recommended for any new AWS project
/plugin install aws-harness@aws-skills
```

## Core CDK Principles

### Resource Naming

**Do NOT explicitly specify resource names** when they are optional in CDK constructs.

```typescript
// ✅ GOOD - Let CDK generate unique names
new lambda.Function(this, 'MyFunction', {
  // No functionName specified
});

// ❌ BAD - Prevents multiple deployments
new lambda.Function(this, 'MyFunction', {
  functionName: 'my-lambda',
});
```

### Lambda Functions

Use appropriate constructs for automatic bundling:

- **TypeScript/JavaScript**: `NodejsFunction` from `aws-cdk-lib/aws-lambda-nodejs`
- **Python**: `PythonFunction` from `@aws-cdk/aws-lambda-python-alpha`

### Pre-Deployment Validation

Before committing CDK code:

```bash
npm run build
npm test
npm run lint
cdk synth
./scripts/validate-stack.sh
```

## Usage Examples

### CDK Development

Ask Claude to help with CDK:

```
Create a CDK stack with a Lambda function that processes S3 events
```

Claude will:
- Follow CDK best practices
- Use NodejsFunction for automatic bundling
- Avoid explicit resource naming
- Grant proper IAM permissions
- Use MCP servers for latest AWS information

### Cost Optimization

Estimate costs before deployment:

```
Estimate the monthly cost of running 10 Lambda functions with 1M invocations each
```

Analyze current spending:

```
Show me my AWS costs for the last 30 days broken down by service
```

### Monitoring and Observability

Set up monitoring:

```
Create CloudWatch alarms for my Lambda functions to alert on errors and high duration
```

Investigate issues:

```
Show me CloudWatch logs for my API Gateway errors in the last hour
```

### Security and Audit

Audit activity:

```
Show me all IAM changes made in the last 7 days
```

Assess security:

```
Run a Well-Architected security assessment on my infrastructure
```

### Serverless Development

Build serverless applications:

```
Create a serverless API with Lambda and API Gateway for user management
```

Implement event-driven workflow:

```
Create an event-driven order processing system with EventBridge and Step Functions
```

Orchestrate complex workflows:

```
Implement a saga pattern for booking flights, hotels, and car rentals with compensation logic
```

### AWS Harness Workflow

The harness is the recommended starting point for any new AWS project. It assumes you'll be steering Claude Code through the development loop and want the environment to enforce best practices, capture learnings, and keep itself honest.

#### 1. Bootstrap a new project

```
/harness-init
```

The skill asks five questions (project name, UAT region, prod region, sandbox AWS account, owner) and scaffolds:

```
your-project/
├── AGENTS.md                    # ~100-line MAP — links only
├── .harness-manifest.json       # version lockfile
├── docs/
│   ├── ARCHITECTURE.md
│   ├── SECURITY.md
│   ├── RELIABILITY.md
│   ├── QUALITY_SCORE.md
│   ├── golden-principles.md     # 15 pre-seeded principles
│   ├── design-docs/
│   ├── exec-plans/{active,completed}/
│   ├── threat-models/
│   ├── learnings/INDEX.md
│   ├── references/              # llms.txt remediation refs
│   ├── runbooks/
│   └── smoke-tests/
├── .claude/
│   ├── settings.json            # SessionStart, PreToolUse, PostToolUse, Stop hooks wired
│   └── hooks/                   # 4 lifecycle hooks
├── .github/workflows/           # 8 GHA workflows
├── tools/
│   ├── lints/                   # 11 custom lints
│   └── scripts/
└── cdk/lib/
    └── cost-instrumentation.ts  # Bedrock token tracking from day 1
```

For an existing project use `/harness-init --retrofit` (non-destructive).

#### 2. Set up GitHub environments

```
Set up GitHub environments for my project
```

Calls the `github-environments` skill which creates `pr` / `uat` / `prod` environments with OIDC role variables, deployment branch policies, and required reviewers. Idempotent — safe to re-run.

#### 3. Run the capability probe before building

```
Run capability probe for the bedrock models I plan to use
```

Validates `(model, region)` availability, inference-profile prefixes (`us.` / `apac.` / `eu.` / `global.`), IAM `bedrock:InvokeModel` grants, and marketplace subscription status **before** you write application logic. Writes `.harness-cache/capability-probe.json`. The pre-deploy hook refuses to deploy if the cache is older than 24h.

This is **golden principle P-01** — running this prevents the Bedrock model-ID / region churn that cost the viking-context-service team three rounds of rework.

#### 4. Open a PR — get an ephemeral stack for free

When you push a PR that touches `cdk/`, the `pr-stack.yml` workflow:
- Runs `capability-probe` fresh
- Deploys `pr-<N>-<project>` stack tagged `harness:pr=<N>`, `harness:ttl=72h`
- Comments the CFN outputs on the PR
- On failure, automatically invokes `cfn-stack-events` for compact root-cause output (no raw CFN JSON dumped into context)

Then the chained `post-deploy-verify.yml` workflow runs:
- Smoke tests from `docs/smoke-tests/<service>.yaml`
- Integration tests tagged `@integration` against the live stack

Cost-safety belt and braces:
1. 72h TTL tag (configurable)
2. Nightly GC cron destroys expired stacks
3. Per-stack `$5/day` AWS Budget kill-switch
4. Concurrency group cancels in-flight deploys for the same PR
5. PR close → automatic `cdk destroy`

#### 5. Diagnose failures with legibility skills, not raw `aws` calls

```
Why did my deploy fail?
```

Routes through `cfn-stack-events` — returns a compact table:
```
TIMESTAMP            LOGICAL_ID         TYPE                  STATUS         REASON
2026-04-15T09:12:33Z MyFunctionRole     AWS::IAM::Role        CREATE_FAILED  API: iam:CreateRole User: ... is not authorized...
```

Other legibility skills:
- `cloudwatch-query "function=my-handler level=ERROR last=15m"` — top-N grouped errors, deduplicated by message fingerprint
- `cloudtrail-investigator --role gha-deploy --error AccessDenied --since 30m` — compact audit timeline

The harness invariant: raw CloudFormation, CloudWatch, and CloudTrail JSON are **banned from agent context**. Always use these wrappers.

#### 6. The learning loop closes itself

When a deploy fails, the `post-tool-use-capture` hook queues a pending postmortem. Next turn:

```
Capture a postmortem for that failure
```

The `postmortem-capture` skill writes `docs/learnings/<date>-<slug>.md` with the 5-whys schema (`symptom`, `root-cause`, `detection-gap`, `fix`, `golden-principle-delta`, `lint-proposal`). Best-effort VCS ingest for cross-project retrieval.

`golden-principles-enforcer` then diffs the new learning against `docs/golden-principles.md` and proposes additions in `.harness-cache/principle-proposals.md`. If the proposed principle has a viable lint, the M4 lint suite catches the recurrence at synth time forever after.

#### 7. The daily doc-gardener keeps things tidy

The `doc-gardener.yml` cron runs at 04:00 UTC daily. It:
- Archives stale `active/` exec-plans
- Fixes broken cross-links
- Adds missing front-matter
- Flags TODO markers older than 14 days
- Rebuilds `docs/learnings/INDEX.md`
- Auto-merges its own PRs (only if labeled `doc-gardener`, only docs files, only after CI green)

The `architecture-drift-detector` runs in the same workflow and opens a deduped issue if `docs/ARCHITECTURE.md` no longer matches the synthesized CDK construct tree.

#### 8. The harness improves itself

A weekly cron (`harness-self-review.yml`) runs `session-log-miner` against your `~/.claude/projects/*/*.jsonl` files, looking for friction patterns:
- Raw `aws` calls bypassing the legibility wrappers
- Repeated tool failures
- Long stuck reasoning turns
- Capability gaps
- AGENTS.md lookup misses

Then `harness-improvement-proposer` clusters them and opens GitHub issues against `aws-skills` itself with proposed fix types (skill-upgrade, new-skill, new-lint, new-reference-doc, hook-change). **Issues, never PRs** — human triage required. The harness now improves itself from its own usage telemetry.

### AI Agent Development

Deploy AI agents with Bedrock AgentCore:

```
Deploy a REST API as an MCP tool using AgentCore Gateway
```

Manage agent memory:

```
Set up conversation memory for my AI agent with DynamoDB backend
```

Monitor agent performance:

```
Configure observability for my AgentCore runtime with CloudWatch dashboards
```

## Structure

```
.
├── .claude-plugin/
│   └── marketplace.json              # Plugin marketplace configuration
├── plugins/                          # Each plugin has isolated skills
│   ├── aws-common/
│   │   └── skills/
│   │       └── aws-mcp-setup/        # Shared MCP configuration skill
│   │           └── SKILL.md
│   ├── aws-cdk/
│   │   └── skills/
│   │       └── aws-cdk-development/  # CDK development skill
│   │           ├── SKILL.md
│   │           ├── references/
│   │           │   └── cdk-patterns.md
│   │           └── scripts/
│   │               └── validate-stack.sh
│   ├── aws-cost-ops/
│   │   └── skills/
│   │       └── aws-cost-operations/  # Cost & operations skill
│   │           ├── SKILL.md
│   │           └── references/
│   │               ├── operations-patterns.md
│   │               └── cloudwatch-alarms.md
│   ├── serverless-eda/
│   │   └── skills/
│   │       └── aws-serverless-eda/   # Serverless & EDA skill
│   │           ├── SKILL.md
│   │           └── references/
│   │               ├── serverless-patterns.md
│   │               └── eda-patterns.md
│   ├── aws-agentic-ai/
│   │   └── skills/
│   │       └── aws-agentic-ai/       # Bedrock AgentCore skill
│   │           ├── SKILL.md
│   │           ├── services/         # Service-specific docs
│   │           └── cross-service/    # Cross-service patterns
│   └── aws-harness/                  # Claude Code AWS harness (M0–M9, v1.0)
│       ├── commands/
│       │   └── harness-init.md       # /harness-init slash command
│       ├── skills/                   # 17 skills across 9 milestones
│       │   ├── harness-init/
│       │   ├── cfn-stack-events/         # M1 — legibility
│       │   ├── cloudwatch-query/         # M1
│       │   ├── cloudtrail-investigator/  # M1
│       │   ├── capability-probe/         # M2 — preflight gate
│       │   ├── deploy-pr-stack/          # M3 — ephemeral env
│       │   ├── github-environments/      # M3
│       │   ├── threat-model-stride/      # M4 — security
│       │   ├── security-review-aws/      # M4
│       │   ├── post-deploy-verify/       # M5 — verification
│       │   ├── integration-test-runner/  # M5
│       │   ├── postmortem-capture/       # M6 — inner loop
│       │   ├── golden-principles-enforcer/ # M6
│       │   ├── doc-gardener/             # M7 — gardening
│       │   ├── architecture-drift-detector/ # M7
│       │   ├── session-log-miner/        # M9 — outer loop
│       │   └── harness-improvement-proposer/ # M9
│       ├── docs/
│       │   └── QUALITY_SCORE.md      # Harness meta-metrics
│       └── templates/                # Scaffold tree copied by /harness-init
│           ├── AGENTS.md             # Map (~100 lines, links only)
│           ├── .harness-manifest.json
│           ├── .harness/
│           ├── .claude/
│           │   ├── settings.json     # Hooks wired
│           │   └── hooks/            # 4 lifecycle hooks
│           ├── .github/workflows/    # 8 GHA workflows
│           ├── docs/                 # System-of-record
│           │   ├── ARCHITECTURE.md
│           │   ├── SECURITY.md
│           │   ├── RELIABILITY.md
│           │   ├── QUALITY_SCORE.md
│           │   ├── golden-principles.md  # 15 principles
│           │   ├── design-docs/
│           │   ├── exec-plans/
│           │   ├── learnings/
│           │   ├── references/       # llms.txt remediation refs
│           │   ├── runbooks/
│           │   ├── smoke-tests/
│           │   └── threat-models/
│           ├── tools/
│           │   ├── lints/            # 11 custom lints
│           │   └── scripts/          # pr-stack-budget.sh, etc.
│           └── cdk/lib/
│               └── cost-instrumentation.ts  # Bedrock cost tracking
├── .github/workflows/
│   └── harness-self-review.yml       # M9 weekly meta-loop cron
└── README.md
```

## MCP Server Names

MCP server names use short identifiers to comply with Bedrock's 64-character tool name limit. The naming pattern is: `mcp__plugin_{plugin}_{server}__{tool}`

Examples: `awsdocs` (AWS docs), `cdk` (CDK), `cw` (CloudWatch), `sfn` (Step Functions), `sam` (Serverless), etc.

## Resources

- [Claude Agent Skills](https://docs.claude.com/en/docs/claude-code/skills)
- [AWS MCP Servers](https://awslabs.github.io/mcp/)
- [AWS CDK](https://aws.amazon.com/cdk/)
- [Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html)
- [MCP Protocol](https://modelcontextprotocol.io/)

## License

MIT License - see [LICENSE](LICENSE)
