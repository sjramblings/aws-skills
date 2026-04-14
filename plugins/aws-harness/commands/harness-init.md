---
description: Bootstrap a new AWS project with the Claude Code harness scaffold (docs/, AGENTS.md, .claude/, .github/, lints).
---

You have been asked to initialize the Claude Code AWS harness in the current directory (or a directory the user specifies).

**Invoke the `harness-init` skill and follow its workflow exactly.**

Key points the skill will handle:

1. Confirm target directory and ask before proceeding if a `.harness-manifest.json` already exists.
2. Ask the five bootstrap questions (project name, UAT region, prod region, sandbox account, owner).
3. Copy the harness templates into the target, substituting placeholders.
4. Write `.harness-manifest.json` with the scaffolded file list and bootstrap answers.
5. `git init` and create the first commit if the target is not already a git repo.
6. Print a clear next-steps summary.

Flags the user may pass to this command:
- `--retrofit` — apply the scaffold non-destructively to an existing repo.
- `--upgrade` — pull in harness changes since the manifest's recorded version.
- `--dry-run` — show what would be copied without writing anything.
- `--target <path>` — scaffold into `<path>` instead of the current directory.

Do not skip steps. Do not invent templates that are not in `templates/`. If a template is missing, stop and report which file is missing — do not improvise content.
