---
name: doc-gardener
description: >-
  Recurring background agent that keeps docs/ honest. Use when the user says
  "doc garden", "stale docs", "garden the docs", "tidy docs", "doc audit", or
  invoked daily by the doc-gardener.yml cron workflow. Scans docs/ for stale
  exec-plans, broken cross-links, orphan ADRs, missing owner front-matter,
  stale TODO markers, and AGENTS.md drift. Opens narrowly-scoped fix PRs
  labeled `doc-gardener` that auto-merge after CI passes (Lopopolo's
  "under 1 minute review" garbage-collection pattern).
context: fork
skills:
  - golden-principles-enforcer
allowed-tools:
  - Read
  - Write
  - Bash(git:*)
  - Bash(gh:*)
  - Bash(grep:*)
  - Bash(find:*)
  - Bash(jq:*)
  - Bash(python3:*)
  - Bash(bash:*)
---

# doc-gardener — recurring documentation cleanup

Documentation rots. Without a recurring sweep, AGENTS.md grows past 150 lines, exec-plans linger in `active/` after they're done, ADRs reference functions that were renamed three sprints ago, and TODO markers from January are still there in October.

This skill is the harness's garbage collector. It runs daily via cron, opens narrowly-scoped fix PRs (one issue per PR), labels them `doc-gardener`, and lets CI auto-merge them after the standard checks pass. Per Lopopolo: "Most of these can be reviewed in under a minute and automerged."

## What it scans

1. **Stale active exec-plans** — files under `docs/exec-plans/active/` with no progress-log entry in >30 days. Action: open PR moving the file to `docs/exec-plans/completed/` (or marking it stale).
2. **Broken cross-links** — markdown links in `docs/` pointing to files that don't exist. Action: open PR removing or fixing the link.
3. **Orphan ADRs** — files under `docs/design-docs/` that no other doc links to. Action: flag (don't auto-fix — orphans may be standalone).
4. **Missing front-matter** — required keys (`owner`, `updated`, `status`) absent from any `docs/**/*.md`. Action: open PR adding the missing keys with sensible defaults.
5. **Stale TODO markers** — `TODO`, `FIXME`, `XXX` markers in `docs/` older than 14 days (by git blame). Action: flag in a single review issue (don't auto-fix — TODOs need human triage).
6. **AGENTS.md drift** — line count >150 OR link density <30%. Action: flag (delegate to `agents-md-map-only` lint output).
7. **Learning index gaps** — `docs/learnings/INDEX.md` missing entries for files that exist on disk. Action: open PR rebuilding the index.
8. **Stale principles** — principles in `golden-principles.md` not referenced by any learning in 90+ days AND with no enforcing lint. Action: flag for review (do NOT auto-delete).

## Usage

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/doc-gardener/scripts/garden.sh \
  [--scope all|stale-plans|cross-links|front-matter|todos|index] \
  [--dry-run] [--open-prs] [--max-prs 5]
```

Arguments:
- `--scope` — which checks to run. Default `all`.
- `--dry-run` — report findings only, do not edit or open PRs.
- `--open-prs` — open one PR per fixable finding. Off by default (so local invocations don't accidentally spam the repo).
- `--max-prs` — safety cap. Default 5.

## Output

Compact TSV:

```
SCOPE         FINDING                                    FILE                                         ACTION
stale-plans   no progress in 47 days                     docs/exec-plans/active/migrate-stripe.md     auto-archive
cross-links   broken link to docs/runbooks/old-svc.md    docs/SECURITY.md:42                          auto-fix
front-matter  missing owner key                          docs/runbooks/payments.md                    auto-fix
todos         TODO older than 39 days                    docs/ARCHITECTURE.md:81                      flag
index         3 learnings missing from INDEX.md          docs/learnings/INDEX.md                      auto-fix
```

When `--open-prs` is set, each `auto-*` action becomes a separate PR labeled `doc-gardener` with a single-file diff.

## PR conventions

- **Branch**: `chore/doc-gardener-<scope>-<short-slug>`
- **Title**: `chore(docs): <one-line description>`
- **Body**: identifies the lint, the file, and what changed. Always under 10 lines.
- **Label**: `doc-gardener` (the workflow auto-merges PRs with ONLY this label and ONLY `docs/**` file changes).
- **Author**: the GitHub Actions bot; the workflow runs under the `pr` environment with limited scope.

## Do not

- Do not auto-fix anything outside `docs/**` or `AGENTS.md`. The workflow's auto-merge is restricted to docs-only PRs precisely because it cannot review code changes.
- Do not delete principles, ADRs, or runbooks. Mark stale, surface to humans, never auto-remove.
- Do not bundle multiple findings into one PR. One issue, one PR — that's what makes the under-1-minute review possible.
- Do not touch `docs/learnings/<date>-<slug>.md` content. Those are append-only; only the INDEX is allowed to be regenerated.
- Do not run with `--open-prs` against `main` from a developer machine. Cron-only.

## Relationship to other skills

- **`golden-principles-enforcer`** (M6) — cross-checks stale principles. Doc-gardener calls it for the principle audit.
- **`agents-md-map-only` lint** (M4) — doc-gardener surfaces the lint findings as flags; the lint itself does the static check.
- **`postmortem-capture`** (M6) — doc-gardener never modifies `docs/learnings/<date>-*.md` files; it only regenerates the INDEX.
- **`architecture-drift-detector`** (M7) — sibling skill. Both run from the same cron workflow but have different scopes (docs hygiene vs structural drift).

## Learning-loop note

Doc-gardener is the M7 garbage collector for `docs/`. Every doc-gardener PR that gets reverted is a signal that the lint or scope is wrong — feed those back to the harness as a learning so the gardener gets sharper over time.
