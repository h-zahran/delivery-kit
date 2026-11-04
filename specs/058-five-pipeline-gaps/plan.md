# Implementation Plan: Close the five pipeline gaps

**Branch**: `058-five-pipeline-gaps` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/058-five-pipeline-gaps/spec.md`

## Summary

Five small fixes to the pipeline plugin, shipped as pipeline 1.11.0. `suite-base start` gets exit 3 for a run record that cannot serve it. The probe block shows the test command and its layer. A new `progress.sh branch-cut` replaces B's branch sentence. `prose_slice` gets an opt-in form without the closing line, and region tests switch to it. `state-set` and `preflight.sh` take tracked values from a JSON file, so no shell reads them.

## Technical Context

**Language/Version**: bash, with bash 3.2 as the floor (macOS CI). Markdown for the skill and docs.

**Primary Dependencies**: git, jq (1.6 and later), awk, grep. bats 1.11.0 for tests. No new dependency.

**Storage**: The run's state file, `.delivery-kit/runs/<feature>/progress.json`, through `progress.sh`. New key: `config.testCommandFrom`. New record: `gates.B` on a "go on with no test command" answer.

**Testing**: `bash scripts/run-suite.sh`, this run's recorded `testCommand`. Changed: `pipeline/tests/base-suite.bats`, `pipeline/tests/progress.bats`, `pipeline/tests/preflight.bats`, `pipeline/tests/prose.bats`. New: `pipeline/tests/branch-cut.bats`.

**Target Platform**: Linux, macOS (bash 3.2) and Windows Git Bash in CI. The Windows rules recorded in memory hold: `jq -b` where it exists, no `mapfile`, `grep --`, no herestring on large input.

**Project Type**: Claude Code plugin marketplace (`projectType` other).

**Performance Goals**: The suite's run time stays within 10% of run 057's 98 to 102 s.

**Constraints**: `pipeline/skills/pipeline/SKILL.md` stays under 65,536 bytes (65,411 today). The branch piece lands first, because it frees the bytes.

**Scale/Scope**: About 120 lines of bash, about 40 tests, one mechanical switch across about 99 `prose_slice` calls, four doc pages, three version records.

## Constitution Check

| Principle | How this feature meets it |
|---|---|
| I. Silence is the failure that matters | Exit 3 replaces a silent exit 0. B stops on it. A `go on with none` makes F.5, J and N say no suite ran. An opt-in slice that comes back empty is refused. A values file with an unknown key is refused. |
| II. Measure; never assert | The audit's 14 tests are named from a run on `126f045`. The `--values-file` report is compared byte for byte with the flag form. The DONE report measures run 1's savings from state files. |
| III. A gate must be shown able to go red | Each exit status test goes red under its own mutant. The 056 mutant runs against the opt-in. The fault harness (`pipeline:spec-review`) holds the mechanics. |
| IV. One implementation, many callers | Trailers from the file go through `trailer-check.sh`, the same file as the flags. The override goes through `base_usable`. `state-set`'s file form joins the inline path before its checks. |
| V. Derive coverage; never enumerate it | The audit starts from a measured red set, not from a reading. The switch script counts calls and refuses a mismatch. A test holds every `base suite not started` line in `progress.sh` to a named status. |

No violations. Re-checked after design: no change.

## Project Structure

### Documentation (this feature)

```text
specs/058-five-pipeline-gaps/
├── spec.md
├── plan.md
├── research.md
├── quickstart.md
├── contracts/commands.md
├── audit-prose-slice.md    written in the prose_slice piece
└── tasks.md
```

### Source Code (repository root)

```text
pipeline/scripts/progress.sh         branch-cut; suite-base exit 3; state-set --json-file; started line
pipeline/scripts/preflight.sh        --values-file
pipeline/scripts/trailer-check.sh    comment only
pipeline/skills/pipeline/SKILL.md    B's text, probe line, pointers
pipeline/docs/configuration.md       file forms; "The Test command line"
pipeline/docs/phases.md              the start's statuses
pipeline/docs/rare-paths.md          "No test command"
pipeline/README.md                   sample probe block
pipeline/tests/base-suite.bats       statuses
pipeline/tests/branch-cut.bats       new
pipeline/tests/progress.bats         state-set file form; usage line
pipeline/tests/preflight.bats        --values-file
pipeline/tests/prose.bats            prose_slice forms; switched callers; B's pins
pipeline/CHANGELOG.md                1.11.0
pipeline/.claude-plugin/plugin.json  1.11.0
.claude-plugin/marketplace.json      1.11.0
```

**Structure Decision**: Everything ships in the `pipeline` plugin, except `prose.bats`, which is its test file. The logic goes to the scripts, and the skill only points at it.

## Order

1. Branch cut first: it frees the skill's bytes.
2. JSON through a file next: gap 1's stop needs the file form to record a command.
3. Base suite status, with the rare path.
4. Probe line and layer.
5. `prose_slice` last among the fixes: B's prose must be final before its pins switch.
6. Release.

## Complexity Tracking

None.
