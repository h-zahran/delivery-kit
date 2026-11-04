# Implementation Plan: Phase B records config before the base suite starts

**Branch**: `056-suite-base-config-order` | **Date**: 2026-11-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/056-suite-base-config-order/spec.md`

## Summary

Phase B tells the orchestrator to run `progress.sh suite-base <feature> start`, and that command reads `config.testCommand` from the state file. The Configuration section says to record `config`, but nothing says when. Add one sentence to B, before the start command, and one to Configuration. Add a test that goes red when the order is swapped, and one that holds the command's silent path, then release as pipeline 1.9.1.

## Technical Context

**Language/Version**: Markdown (the skill), bash with bats 1.x (the test). Tests must parse and run on bash 3.2, which macOS CI uses.

**Primary Dependencies**: `prose_slice`, `prose_flat` and `pins_in` in `pipeline/tests/prose.bats`.

**Storage**: N/A

**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests`

**Target Platform**: Linux, macOS and Windows CI.

**Project Type**: Claude Code plugin marketplace (`projectType` other).

**Performance Goals**: N/A. The feature protects F.5's citation, which saves about 6 minutes in a run.

**Constraints**: `pipeline/skills/pipeline/SKILL.md` stays under 65,536 bytes (65,174 today). `pipeline/scripts/progress.sh` does not change.

**Scale/Scope**: Two sentences in the skill, one clause in `pipeline/docs/phases.md`, one sentence in `pipeline/docs/configuration.md`, two tests, three version records.

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Silence is the failure that matters | The start command's silent "not started" is the cause. FR-008 keeps the command as it is, by the seed. The sentence closes the path that reaches it. The test refuses a phase B it cannot find (`prose_slice` fails) and a start command it cannot find. | PASS, the silent exit 0 stays, named in the spec's Assumptions |
| II. Measure; never assert | The four faults are run on a mutated copy, and the results go in `measurements.md`. | PASS |
| III. A gate must be shown able to go red | The test is seen red before the sentence exists, and on each of the four faults. | PASS |
| IV. One implementation, many callers | The sentence points at Configuration and adds no second definition (FR-002). The test uses the file's existing helpers. | PASS |
| V. Derive coverage; never enumerate it | Not applicable: one ordered pair of phrases, no list. | N/A |

No violation. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/056-suite-base-config-order/
├── spec.md
├── plan.md
├── research.md
├── quickstart.md
├── measurements.md      # written during H: the four faults and their results
├── tasks.md
└── checklists/requirements.md
```

No `data-model.md` and no `contracts/`: the feature adds no data and no interface.

### Source Code (repository root)

```text
pipeline/skills/pipeline/SKILL.md     # phase B: one new sentence
pipeline/docs/phases.md               # the same order, in the base suite section
pipeline/tests/prose.bats             # one new test, beside "B starts the base suite run once the branch is cut"
pipeline/CHANGELOG.md                 # 1.9.1 entry
pipeline/.claude-plugin/plugin.json   # version
.claude-plugin/marketplace.json       # version
```

**Structure Decision**: No new file except the feature's own spec documents. See [research.md](research.md) for the wording and the test's shape.

## Complexity Tracking

Empty.
