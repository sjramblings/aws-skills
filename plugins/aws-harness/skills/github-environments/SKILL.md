---
name: github-environments
description: >-
  Creates and configures GitHub environments (`pr`, `uat`, `prod`) with
  required reviewers, deployment branch restrictions, and OIDC-role variables
  for AWS deploys. Use when the user says "set up github environments",
  "create github environment", "branch protection", "OIDC role", "github
  environment for prod", or when bootstrapping a new AWS project so the
  pr-stack / deploy workflows have somewhere to run. Wraps `gh api` calls —
  never pastes raw environment JSON into context.
context: fork
allowed-tools:
  - Bash(gh api:*)
  - Bash(gh repo view:*)
  - Bash(gh variable:*)
  - Bash(gh secret:*)
  - Bash(jq:*)
  - Bash(bash:*)
---

# github-environments — per-env GitHub config

Creates the three GitHub environments the harness expects, plus the OIDC + variable wiring. Run once per repo after `harness-init`. Idempotent — safe to re-run.

## Environments created

| Name | Purpose | Protection | Branches allowed |
|---|---|---|---|
| `pr` | Per-PR ephemeral stacks | None (throwaway) | Any PR branch |
| `uat` | Push-to-main UAT deploys | 1 reviewer required | `main` only |
| `prod` | Release-tag prod deploys | 2 reviewers + 10min wait | Tags matching `v*.*.*` only |

## Variables set (per env)

- `AWS_DEPLOY_ROLE_ARN` — the IAM role assumed via OIDC for that env
- `AWS_PRIMARY_REGION` — region the deploy targets
- `HARNESS_ENV` — short tag (`pr` / `uat` / `prod`) used by tagging + lints

## Secrets

By default this skill sets **no secrets** — OIDC is preferred over long-lived access keys. If you must inject a secret (e.g. third-party API key for integration tests), use `gh secret set --env <name>` by hand and document it in `docs/SECURITY.md`.

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/github-environments/scripts/setup.sh \
  --repo <owner>/<repo> \
  --uat-role <arn> --uat-region <region> \
  --prod-role <arn> --prod-region <region> \
  [--pr-role <arn>] \
  [--uat-reviewer <user-or-team>] \
  [--prod-reviewers <user1,user2>]
```

Arguments:
- `--repo` — GitHub repo in `owner/name` form. Required.
- `--uat-role`, `--prod-role` — IAM role ARNs for OIDC assume. Required.
- `--uat-region`, `--prod-region` — AWS region per env. Required.
- `--pr-role` — optional; defaults to `--uat-role` (the PR env shares the UAT role unless you've set up a separate sandbox role).
- `--uat-reviewer` — GitHub username or team slug for UAT reviews.
- `--prod-reviewers` — comma-separated list of 1-2 prod reviewers.

## What the script does

For each environment (`pr`, `uat`, `prod`):

1. `gh api -X PUT repos/<repo>/environments/<name>` — creates or updates the env
2. Sets deployment branch policy:
   - `pr` → custom branches allowed, no restriction
   - `uat` → protected branches only
   - `prod` → tag pattern `v*.*.*`
3. Sets wait timer (prod only, 10 minutes)
4. Sets required reviewers (uat: 1, prod: 2)
5. `gh variable set --env <name>` for the three variables above

## Pre-flight

The script verifies:
- You are authenticated to the GitHub API (`gh auth status`)
- The repo exists and you have admin access (required to configure environments)
- The IAM role ARNs parse as valid ARNs

## Do not

- Do not hard-code role ARNs into the script. They come from flags or `.harness-manifest.json#bootstrap`.
- Do not create a `main` environment — use `uat` for main-branch deploys. The naming is deliberate so the workflows are unambiguous.
- Do not grant the `pr` environment access to prod secrets. That's how sandbox becomes prod by accident.
- Do not set `AWS_DEPLOY_ROLE_ARN` as a secret — it's non-sensitive, use a variable so it surfaces in workflow logs for debugging.

## Relationship to other skills

- **`deploy-pr-stack`** (M3) — relies on the `pr` environment existing with `AWS_DEPLOY_ROLE_ARN` set.
- **`capability-probe`** (M2) — the `.github/workflows/capability-probe.yml` template expects `vars.AWS_DEPLOY_ROLE_ARN` and `vars.AWS_PRIMARY_REGION`.
- **`security-review-aws`** (M4) — will inspect the IAM role trust policy and fail if it doesn't scope `token.actions.githubusercontent.com` to this specific repo.

## Learning-loop note

Any misconfiguration found after the fact (e.g. prod env letting PRs deploy, missing reviewers, wrong trust policy) should become a learning under `docs/learnings/` with a `lint-proposal` that extends `security-review-aws` to catch the misconfig statically.
