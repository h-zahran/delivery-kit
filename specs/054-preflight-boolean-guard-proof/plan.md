# Implementation Plan: Prove the pre-flight boolean-type guard, then close issue #34

**Branch**: `054-preflight-boolean-guard-proof` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/054-preflight-boolean-guard-proof/spec.md`

## Summary

A mutation rig makes one throwaway worktree of a commit, flips one
`--argjson <var>` to `--arg <var>` in a scratch copy of its
`pipeline/scripts/`, proves the flip landed, runs the worktree's
`pipeline/tests/preflight.bats` against the copy (through the suite's own
`PREFLIGHT_UNDER_TEST` hook), and records every red test
by name. It derives its mutants from the code: every `--argjson` variable that
fills a boolean field of a real report. That is nine today (the seven the spec
names, plus `git` and `runs_live`, which already carry type assertions). It
runs them twice: on the base commit, then on the finished branch. The base table decides which fields need a new assertion
(expected: `speckit.present` and `speckit.versionInRange`). One new test walks
a whole report and refuses any string `"true"` or `"false"`. The 013 spec's
open gap entry is marked closed, and the pull request carries `Closes #34`.

## Technical Context

**Language/Version**: bash (3.2 on macOS CI, 5.x on Linux and Git Bash), jq 1.6+

**Primary Dependencies**: git (worktree), jq, bats 1.11

**Storage**: none; the rig writes only to a `mktemp` folder and stdout

**Testing**: bats (`pipeline/tests/preflight.bats`); the rig is a measurement, not a suite

**Target Platform**: Linux, macOS, Windows Git Bash (CI runs all three for the suite; the rig runs here only)

**Project Type**: CLI plugin (shell scripts plus skill prose)

**Performance Goals**: none; the rig runs seven worktrees, at most 3 at a time (`maxParallelAgents`)

**Constraints**: the rig never changes the main checkout; no process stopped but its own; no skip in CI; no production code change

**Scale/Scope**: two or three new assertion lines and one new test in `preflight.bats`; one rig script; one entry in `specs/013-preflight-git-probe/spec.md`

## Constitution Check

| Principle | How this plan holds it |
|---|---|
| I. Silence is the failure | The rig reports NO-OP for a mutation that changed nothing, and refuses a mutant that fails `bash -n`. On the finished branch, a mutant that turns no test red, or not its own guard, fails the rig (FR-011) instead of passing. |
| II. Measure; never assert | Which fields have the hole is decided by the base-commit run, not by a search. Both tables are dated and name their commit (SC-005). |
| III. A gate must be shown able to go red | Every assertion, old and new, is shown red by its mutant. The FR-012 test is shown red by every mutant and green on its own fixture. The rig never edits a tracked file: it mutates scratch copies only, and checks at the end that its worktree's script is byte-identical to the commit. |
| IV. One implementation | No rule is duplicated. The FR-012 test checks every field with one walk. |
| V. Derive coverage | The FR-012 test names no field, so a future boolean is covered on arrival. The rig's mutant list is derived, not typed: the boolean paths of a real report, joined to the `field: $var` lines of the report template and the `--argjson` names. The rig stops if the derived list lacks any of the seven the spec names. |

Gate result: PASS, no departure.

## Project Structure

### Documentation (this feature)

```text
specs/054-preflight-boolean-guard-proof/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── measurements.md      # the two mutant tables (FR-005, SC-005)
├── mutate.sh            # the rig (measurement only, not a suite)
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
pipeline/tests/preflight.bats            # new assertions + the FR-012 test
specs/013-preflight-git-probe/spec.md     # gap entry marked CLOSED (FR-006)
```

**Structure Decision**: the rig lives in the feature's spec folder. It is
evidence for this feature, like `measurements.md`, and is not part of any
suite. It must still pass the analyzer, which reads every tracked `*.sh`.

## Complexity Tracking

None.
