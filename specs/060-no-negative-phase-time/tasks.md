# Tasks: A phase time is never negative

**Input**: `specs/060-no-negative-phase-time/` (spec.md, plan.md, quickstart.md)

**Tests**: the spec asks for them (FR-004), so the test comes first and is seen red.

Each phase is one review piece. No setup or foundational phase is needed.

---

## Phase 1: User Story 1, a re-entered phase never shows a false time (Priority: P1) 🎯 MVP

**Goal**: A phase whose end is earlier than its start reads `seconds: null` (FR-001 to FR-004).

**Independent Test**: `"$HOME/bats/bin/bats" -f 'phase time' pipeline/tests/progress-git.bats` passes.

- [ ] T001 [US1] In `pipeline/tests/progress-git.bats`, add a test named with `phase time`: with fixed timestamps, a phase whose `done` is earlier than its `started` reads `.phases.<p>.seconds` as null, asserted with `jq -c`, and `type` is `null`; the timestamps stay in the file; a phase with `started` equal to `done` reads 0, and a normal one reads the difference; a timestamp that does not parse reads null, and a phase with no `done` has no `seconds` key. Add a second test that drives the real commands: `phase-start`, `phase-done`, `phase-start` again with its stamp later than the old `done`, `metrics`, then asserts null; then `phase-done` with a later stamp, `metrics`, and asserts the new end minus the new start. Run them and see the first red.
- [ ] T002 [US1] In `pipeline/scripts/progress.sh`, in `METRICS_JQ`, make the `seconds` condition require `$d >= $s`, and add to the comment above it that a re-entered phase with no new end reads null. Run `pipeline/tests/progress-git.bats` until green, and run `shellcheck --norc -f gcc pipeline/scripts/progress.sh`.
- [ ] T003 [US1] Plant faults through `.delivery-kit/runs/060-no-negative-phase-time/fault-harness.sh`, which T001's author copies from run 059's and keeps with a green control: `$d >= $s` as `$d > $s`, so a 0 reads null; the condition removed; the condition inverted. Each must go RED. Record the results in `specs/060-no-negative-phase-time/plan.md`, under a section named "Faults".

**Checkpoint**: run 059's shape reads null, and 0 stays 0.

---

## Phase 2: Release records

**Purpose**: pipeline 1.12.1 (FR-005).

- [ ] T004 In `pipeline/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, set the pipeline's version to 1.12.1. In `pipeline/CHANGELOG.md`, add `## [1.12.1] - 2026-11-06` with the fix. Run `bash scripts/check-versions.sh`.

---

## Dependencies & Execution Order

Phase 1, then Phase 2. Within Phase 1, tasks run in order. One actor runs them all: they touch few files, and nothing fans out.
