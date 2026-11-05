# Implementation Plan: Fix the base suite's red stop test, keep test runs in the foreground, and measure the deep review

**Branch**: `059-flaky-foreground-i-metrics` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/059-flaky-foreground-i-metrics/spec.md`

## Summary

Three small changes, shipped as pipeline 1.12.0. `suite-base start` and its runner add no ignore of `SIGINT`, by job control in place of `setsid`, and the stop test still sends a real `SIGINT` when it is itself started with `SIGINT` ignored: it must do nothing, and `TERM` then ends the script (FR-002). Every agent brief requires foreground test runs. A new `progress.sh i-measure` records phase I's parts, `phase-done I` refuses until each part has a record, and `progress.sh metrics` shows them in `pipeline-run.json`. The orchestrator records each lens's return (FR-012). A new record moves the old one to `earlier`, and a second `done` is refused (FR-016).

## Technical Context

**Language/Version**: bash, with bash 3.2 as the floor (macOS CI). Markdown for the skill and docs.

**Primary Dependencies**: git, jq (1.6 and later), awk, grep. bats 1.11.0 for tests. No new dependency.

**Storage**: The run's state file, through `progress.sh`. New key: `measurements.i`. New derived key in `pipeline-run.json`: `phaseI`. New run file: `.delivery-kit/runs/<feature>/findings-I.txt`.

**Testing**: `bash scripts/run-suite.sh`. Changed: `tests/run-suite.bats`, `pipeline/tests/base-suite.bats`, `pipeline/tests/skills.bats`, `pipeline/tests/prose.bats` as the pins require. New: `pipeline/tests/i-measure.bats`.

**Target Platform**: Linux, macOS (bash 3.2) and Windows Git Bash in CI. `set -m` is already used on all three by `scripts/run-suite.sh` and by the stop test.

**Project Type**: Claude Code plugin marketplace (`projectType` other).

**Performance Goals**: The next run's F.5 cites the base suite and takes under 30 s, against 155 s. `i-measure` takes under one second a call.

**Constraints**: `pipeline/skills/pipeline/SKILL.md` stays under 65,536 bytes (65,214 today). Net spend at most 200 bytes.

**Scale/Scope**: About 130 lines of bash, about 30 tests, two skill files, one doc section, three version records.

## Constitution Check

| Principle | How this feature meets it |
|---|---|
| I. Silence is the failure that matters | A red that only one start method shows is closed at its cause. `phase-done I` refuses a part with no record, so the numbers cannot vanish. A missing measure reads `missing`, never 0. An unreadable finding line is reported by number. |
| II. Measure; never assert | The cause was reproduced before the plan. The start methods were measured one by one in `research.md`. The fix runs at least 500 passes under load. |
| III. A gate must be shown able to go red | New tests go red under planted faults: a runner back on `setsid`, a child with no job control, a gate removed, a missing measure written as 0. Inverted mutants as well as deleted ones. |
| IV. One implementation, many callers | `i-measure` is the one writer of `measurements.i`. `metrics` reads it through its one jq program. |
| V. Derive coverage; never enumerate it | The gate's list of parts and the doc's list are one list, tested against each other. The rule names no phase, so a new unit in "Parallel agents" is bound with no list to go stale, and the test pins the rule's whole line. |

No violations. Re-checked after design: no change.

## Project Structure

### Documentation (this feature)

```text
specs/059-flaky-foreground-i-metrics/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/commands.md
└── tasks.md
```

### Source Code (repository root)

```text
pipeline/scripts/progress.sh              base_start, base_run, base_run_exit, base_stop; cmd_i_measure; cmd_phase_done gate; METRICS_JQ
pipeline/skills/pipeline/SKILL.md         one ground rule; I's pointer; the shorter metrics line
pipeline/skills/spec-review/SKILL.md      the same rule in the lenses' inputs
pipeline/docs/phases.md                   new section "Measuring phase I"
pipeline/CHANGELOG.md and manifests       1.12.0
tests/run-suite.bats                      stop_run's arm for SIGINT ignored at entry
pipeline/tests/base-suite.bats            the runner's command sees SIGINT not ignored
pipeline/tests/i-measure.bats             new
pipeline/tests/skills.bats                pins and the rule's test
```

**Structure Decision**: No new script file. `i-measure` lives in `progress.sh`, as every state write does.

## Pieces

1. **The base suite's signal state (US1).** Tests first. `base_start` and `base_run` use job control. `stop_run` gets its arm.
2. **Foreground rule (US2).** Skill text and its test.
3. **Measuring I (US3).** The subcommand, the gate, the metrics key, the doc, and the two skill edits.
4. **Release records.** Version 1.12.0 in the manifests and the changelog.

The proof runs (500 passes, a real base suite on the fixed code) go in the research notes at the end of piece 1, and the counts are recorded there.

## Complexity Tracking

None. The one choice that adds code is the gate in `phase-done`, and FR-011 asks for it: prose alone already failed on three runs.
