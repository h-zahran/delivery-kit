# Implementation Plan: Remove repeated and serial work from a pipeline run

**Branch**: `057-repeated-serial-work` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/057-repeated-serial-work/spec.md`

## Summary

Part A adds `scripts/run-suite.sh`. It runs each `*.bats` file under the four test roots at the same time, and prints one TAP report that `progress.sh tap-check` accepts. `.delivery-kit.json`'s `testCommand` calls it. Part B adds a section "The fault harness" to `pipeline:spec-review`, and one short pointer in the orchestrator. The change ships as pipeline 1.10.0.

## Technical Context

**Language/Version**: bash, with bash 3.2 as the floor (macOS CI). Markdown for the skill and docs.

**Primary Dependencies**: POSIX `find`, `sort`, `awk`, `xargs -P`, `mktemp`. bats 1.11.0 at `$HOME/bats/bin/bats`, or `BATS_BIN`. No new dependency.

**Storage**: Temporary files only, removed on every exit. The harness lives at `.delivery-kit/runs/<feature>/fault-harness.sh`, not tracked.

**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests`, which this run keeps as its recorded `testCommand`. New tests: `tests/run-suite.bats`, and pins in `pipeline/tests/skills.bats`.

**Target Platform**: The script runs on the owner's Linux machine and on any developer's. Its tests run in CI on Linux, macOS and Windows, with a stand-in test runner. CI's real suite stays serial and sharded.

**Project Type**: Claude Code plugin marketplace (`projectType` other).

**Performance Goals**: The full suite in under 120 seconds on the owner's machine (serial: about 561 seconds).

**Constraints**: `pipeline/skills/pipeline/SKILL.md` grows by at most 100 bytes (65,315 of 65,536 today). `tap-check` and `suite-record` do not change.

**Scale/Scope**: One script of about 120 lines, one new test file, one config line, one skill section, one pointer, one docs paragraph, three version records.

## Constitution Check

| Principle | How this feature meets it |
|---|---|
| I. Silence is the failure that matters | The script's exit 0 needs every file's exit status, plan and count to agree, and at least one test. A missing status file is a fault. A root with no test file is a fault. A harness reports a fault that changed no byte. |
| II. Measure; never assert | Part A's numbers are measured, and FR-025 measures the final script at the root. Part B's saving stays a soft estimate until run 2 measures it. |
| III. A gate must be shown able to go red | `tests/run-suite.bats` forces each fault. Each prose pin goes red under a fault run. |
| IV. One implementation, many callers | The verdict stays in `tap-check`. The script only produces the report. The harness rule lives once, in `pipeline:spec-review`, and the orchestrator points at it. |
| V. Derive coverage; never enumerate it | The test files come from `find`, as `bats -r` does. A test holds the script's root list equal to CI's matrix, so a new root cannot be skipped silently. |

No violations. Re-checked after design: no change.

## Project Structure

### Documentation (this feature)

```text
specs/057-repeated-serial-work/
├── spec.md
├── plan.md
├── research.md
├── quickstart.md
├── measurements.md
├── contracts/run-suite.md
└── tasks.md
```

### Source Code (repository root)

```text
scripts/run-suite.sh                 new: the side-by-side suite command
tests/run-suite.bats                 new: its tests, with a stand-in test runner
.delivery-kit.json                   testCommand calls the script
CONTRIBUTING.md                      names the faster command beside the serial one
pipeline/skills/spec-review/SKILL.md new section: The fault harness
pipeline/skills/pipeline/SKILL.md    one pointer, at most 100 bytes
pipeline/docs/phases.md              one paragraph for readers
pipeline/tests/skills.bats           pins for the harness rules
pipeline/CHANGELOG.md                1.10.0
pipeline/.claude-plugin/plugin.json  1.10.0
.claude-plugin/marketplace.json      1.10.0
```

**Structure Decision**: Part A stays in `scripts/`, which no plugin ships, because `testCommand` is this repository's own setting. Part B ships in the plugin, because every pipeline user plants faults.

## Complexity Tracking

None. The internal per-file mode exists only because `xargs` needs a command to call.
