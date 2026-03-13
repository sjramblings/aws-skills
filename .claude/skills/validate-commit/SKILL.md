---
name: validate-commit
description: Validate a commit message against Conventional Commits format
disable-model-invocation: false
user-invocable: true
argument-hint: "<commit-message>"
---

# Commit Message Validator

Validate that the provided commit message follows our Conventional Commits format.

## Check these rules:

1. **Type check**: Is the type one of: feat, fix, docs, style, refactor, perf, test, chore, ci?
2. **Type format**: Is the type lowercase?
3. **Scope format**: If scope exists, is it in parentheses and lowercase?
4. **Separator**: Is there a colon and space after type/scope?
5. **Subject start**: Does subject start with lowercase?
6. **Subject mood**: Is it imperative mood (add, fix, update - not added, fixed, updated)?
7. **Subject ending**: No period at the end?
8. **Subject length**: Under 50 characters?

## Usage

```
/validate-commit "feat(api): add authentication"
```

## Output

For valid messages: ✅ Valid commit message
For invalid messages: ❌ Invalid - list specific issues and suggest fix
