---
name: harness-init
description: >-
  Scaffolds an AWS project repository with the Claude Code harness: docs/
  system-of-record, AGENTS.md map, .claude/ hooks, .github/ workflows, custom
  lints, and learning store. Use when the user says "harness init", "scaffold
  harness", "bootstrap aws project", "set up harness", or runs the /harness-init
  slash command. Applies Lopopolo's harness engineering principles to AWS/CDK
  projects: legibility, knowledge-base-as-system-of-record, mechanical
  enforcement, feedback loops, and per-PR ephemeral stacks.
context: fork
allowed-tools:
  - Read
  - Write
  - Bash(git init)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git status)
  - Bash(git branch:*)
  - Bash(gh repo:*)
  - Bash(gh api:*)
  - Bash(mkdir:*)
  - Bash(cp:*)
  - Bash(ls:*)
  - Bash(cat:*)
  - Bash(test:*)
---

# harness-init — AWS project bootstrap

Scaffolds a new (or existing) AWS project with the full Claude Code harness. Run this once per project. Re-run with `--upgrade` to pull in later harness milestones.

## What it creates

A project repo with this layout (source: `templates/` in the `aws-harness` plugin):

```
AGENTS.md                 # ~100-line MAP — links only, never an encyclopedia
.harness-manifest.json    # lockfile: harness version + files scaffolded
docs/
  ARCHITECTURE.md
  SECURITY.md
  RELIABILITY.md
  QUALITY_SCORE.md
  golden-principles.md
  design-docs/
  exec-plans/active/
  exec-plans/completed/
  product-specs/
  threat-models/
  learnings/INDEX.md
  references/
  runbooks/
  smoke-tests/
.claude/
  settings.json           # hook wiring (M6 will populate)
  hooks/                  # empty in M0; filled at M5/M6
.github/
  workflows/              # empty in M0; filled at M3/M7
tools/
  lints/                  # empty in M0; filled at M4
  scripts/
```

## Core invariants (enforced mechanically later; human discipline now)

1. **AGENTS.md is a MAP, not an encyclopedia.** Keep it under 150 lines. Link to `docs/`. Never duplicate content.
2. **Every signal the agent needs must be reachable via a skill that returns compact output.** Raw CloudFormation, CloudTrail, CloudWatch API blobs are banned from agent context. Use the harness legibility skills (`cfn-stack-events`, `cloudwatch-query`, `cloudtrail-investigator` — shipped in M1).
3. **Plans are first-class artifacts.** Exec plans live in `docs/exec-plans/active/` with a progress-log and a decision-log, checked in, versioned.
4. **Failures are signal.** Every deploy/test failure becomes an entry in `docs/learnings/<YYYY-MM-DD>-<slug>.md`, feeds `golden-principles.md`, and proposes a lint.
5. **Start small, validate end-to-end, grow.** Don't ship M1 skills into a project whose M0 scaffold hasn't been dogfooded.

## Workflow the agent should follow when invoked

1. **Check target directory.** If the user hasn't specified one, ask. If the target already has a `.harness-manifest.json`, ask before proceeding (idempotency — never clobber).
2. **Ask five bootstrap questions:**
   - Project name (slug)
   - Primary AWS region for UAT (default: `us-east-1`)
   - Primary AWS region for Prod (default: `ap-southeast-2`)
   - Sandbox AWS account ID (for per-PR ephemeral stacks)
   - Owner handle (GitHub username)
3. **Copy templates.** For every file under the plugin's `templates/` directory, copy to the target repo, substituting `{{PROJECT_NAME}}`, `{{UAT_REGION}}`, `{{PROD_REGION}}`, `{{SANDBOX_ACCOUNT}}`, `{{OWNER}}` placeholders.
4. **Write `.harness-manifest.json`** recording the harness version, the list of files scaffolded, and the answers to the bootstrap questions.
5. **`git init` + first commit** if the target isn't already a git repo. Commit message: `chore: bootstrap harness scaffold (M0)`.
6. **Print a next-steps summary** pointing at `AGENTS.md`, `docs/golden-principles.md`, and the M1 upgrade path.

## Retrofit mode (`--retrofit`)

When run on an existing repo (like `viking-context-service`):
- Do NOT overwrite any existing `AGENTS.md`, `docs/`, `.claude/`, `.github/workflows/` files.
- Write any new templated file only if it doesn't already exist.
- Still write `.harness-manifest.json` with a `mode: retrofit` field.
- Print a diff summary of what was added and what was skipped.

## Upgrade mode (`--upgrade`)

- Read the target repo's `.harness-manifest.json` to find the current harness version.
- Diff against the plugin's shipped version.
- For each newly-added or changed template file, prompt the user to accept/reject/diff.
- Update the manifest on success.

## What NOT to do

- Do not create a GitHub repo, create environments, or push anything in M0. Those come in M3 via the `github-environments` skill.
- Do not run `cdk init` or add dependencies. This skill only scaffolds harness files.
- Do not write code into `docs/` — those are placeholders the user fills in as they design.

## Where to find the templates

Inside this plugin at `../../templates/` (relative to this SKILL.md). Resolve via the plugin root. If the plugin is installed in read-only mode, copy from the skill's installed path.
