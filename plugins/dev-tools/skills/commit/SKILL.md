---
name: commit
description: Create a git commit following Conventional Commits format. Use when the user wants to commit changes or asks to create a commit.
disable-model-invocation: false
user-invocable: true
allowed-tools: Bash
argument-hint: "[optional message]"
---

# Git Commit with Conventional Commits Format

Create commits following our standardized format.

## Commit Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

## Types (required)
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation only
- **style**: Formatting, no code change
- **refactor**: Code restructuring
- **perf**: Performance improvement
- **test**: Adding/fixing tests
- **chore**: Build, deps, tooling
- **ci**: CI/CD changes

## Scopes (optional, project-specific)
- `cdk` - CDK infrastructure
- `api` - REST API / Lambda
- `graphql` - AppSync / GraphQL
- `frontend` - React frontend
- `agents` - Bedrock AgentCore / MCP
- `deps` - Dependencies

## Rules
1. Type must be lowercase from allowed list
2. Subject: lowercase, imperative mood, no period, max 50 chars
3. Body: wrap at 72 chars, explain what/why
4. Footer: `Closes #123` or `BREAKING CHANGE: description`

## Examples
- `feat(api): add user authentication endpoint`
- `fix(frontend): resolve button alignment issue`
- `docs(readme): update installation instructions`
- `chore(deps): upgrade aws-cdk-lib to 2.170.0`
- `refactor(cdk): simplify stack dependencies`

## Workflow

1. Run `git status` to see staged changes
2. Run `git diff --staged` to understand what's being committed
3. Draft a commit message following the format above
4. Ask user to confirm the commit message
5. Execute `git commit -m "message"` with the confirmed message
6. Show `git log -1` to confirm the commit

If user provides $ARGUMENTS, use it as the commit message (validate it first).
