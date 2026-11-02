# Implementation Plan: A forked skill's robot moves to DONE when its work is over

**Branch**: `048-mc-fork-done` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

## Summary

A forked skill's robot bounces back into RUNNING after it finishes. The
`turn.complete` hook marks it done; five seconds later `reconcile()` sees the
engine list report it `idle`, and the revive rule — written for a helper that
waits on its own background job — turns it back to `running`; the next pass
maps `idle` to an idle robot, drawn under RUNNING as "resting…". The fix stores
on each run whether it joined from the list (a forked skill), and for such a
run reads a listed `idle` as done: it neither revives it nor maps it to idle.
A listed `running`, `waiting` or `pending` still revives it. Spawned helpers
are untouched. Released as mission-control 0.9.7.

## Technical Context

**Language/Version**: TypeScript/TSX, a Claude Code mod (engine 2.1.316)

**Primary Dependencies**: the mod engine (`$.agent.list()`, `turn.complete`, `$.state`); its test runner `claude plugin test`

**Storage**: `$.state` (the `agents` list); the new field is optional, so a run an older version stored reads as not forked

**Testing**: `claude plugin test mission-control` (133 tests at `f569e9f`, about 20 s); `claude plugin validate mission-control`; the repository's bats roots for the release checks

**Target Platform**: Claude Code on Linux, macOS, Windows (the mod runs in the engine)

**Project Type**: Claude Code plugin (mod)

**Constraints**: the validator refuses `$` passed to a function defined inside `register` (helpers taking `$` stay top-level); no change to spawned helpers' behaviour

**Scale/Scope**: `mission-control/types/index.d.ts` (one optional field), `mission-control/hooks/register.tsx` (`addRun`, `reconcile`, the status mapping), `mission-control/hooks/forked.test.tsx` (new tests), changelog, release files

## Constitution Check

| Principle | How this plan meets it | Status |
|---|---|---|
| I. Silence is the failure that matters | Today the pane silently says "resting…" for a finished task. The fix makes the state true; the old-state fallback (no `forked` field) is today's behaviour, not a new silent path. | PASS |
| II. Measure; never assert | The cause was read from the engine's types and the code path; the new tests are run red on the old code before the fix, and the result recorded. | PASS |
| III. A gate must be shown able to go red | Each new test gets a positive control (the rule removed in a scratch copy). | PASS |
| IV. One implementation, many callers | One status function decides a listed status for a run; `reconcile` uses it for both the change check and the write. | PASS |
| V. Derive coverage; never enumerate it | Not affected. | PASS |

## Project Structure

```text
specs/048-mc-fork-done/      spec.md plan.md research.md quickstart.md tasks.md measurements.md checklists/
mission-control/types/index.d.ts
mission-control/hooks/register.tsx
mission-control/hooks/forked.test.tsx
mission-control/CHANGELOG.md
mission-control/.claude-plugin/plugin.json      (0.9.7)
.claude-plugin/marketplace.json                 (mission-control entry 0.9.7, sed)
```

## Complexity Tracking

None.
