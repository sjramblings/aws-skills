---
owner: "@{{OWNER}}"
updated: 2026-04-15
status: active
---

# Red Test Policy

Golden principle P-12: **known-red tests block commits. Never defer a failing test to "fix later."**

## Why

viking-context-service Phases 2–5: `bedrock.test.ts` had a model-ID
mismatch that persisted across four phases because it was marked
as "known flaky" and ignored. The real bug masked a correctness issue
in the Bedrock region-prefix logic that would not surface until
Phase 6 retrospective.

Deferred red tests compound interest: every phase that builds on top
of them adds more code that will be invalidated when the underlying
fix lands. This is technical debt with the worst possible compounding.

## The policy

- A failing test blocks the commit. The PreToolUse hook
  `pre-commit-red-test-block.sh` runs the fast test suite on every
  `git commit` and aborts if any test reports failure.
- A test marked `@known-red` (via test framework annotation, e.g.
  `test.skip('@known-red ...')`) is tracked as tech debt in
  `docs/QUALITY_SCORE.md` and must be resolved within **7 days** of
  being marked, or the PR that marked it must be reverted.
- There is no "snooze" mechanism. If a test is flaky, the fix is
  either to deflake it or to delete it.

## Exceptions

- **Known external outage:** you may `@known-red` a test whose failure
  is caused by a verified third-party outage. The marker must include
  the incident ID and must be removed within 24h of outage resolution.
- **Pending architectural change:** a test that is deliberately
  failing as part of a TDD cycle on the same PR is fine. The commit
  that makes it pass must land in the same PR.

## Enforcement

- Pre-commit: `templates/.claude/hooks/pre-commit-red-test-block.sh` (M5)
- CI: the existing `lint.yml` + test workflows
- Tracking: `docs/QUALITY_SCORE.md` updates `known-red count` weekly

## References

- viking-context-service retrospective Phase 5 bedrock.test.ts
- Golden principle: P-12
- Hook: `.claude/hooks/pre-commit-red-test-block.sh`
