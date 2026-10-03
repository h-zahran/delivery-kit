# Implementation Plan: The release gate reads every level-2 heading form

**Branch**: `024-gate-every-heading-form` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/024-gate-every-heading-form/spec.md`

## Summary

One repository-level change, no plugin change: the release form of
`scripts/check-versions.sh` stops reading only lines that begin `## ` and
reads the changelog the way Markdown does, far enough to know every
level-2 heading. One awk walk keeps an open fence, whether a list item can
be open, and the previous line (research R1, R2), and every doubt leans
toward refusing (R3): it does not track each list item's text column, it
judges every deep `##` while any item can be open. The
test fixture helper in `tests/portability.bats` widens with a rule of its
own (R5), and six tests, split by contract clause, are added there.

## Technical Context

**Language/Version**: bash, written to run on bash 3.2 as well as 5.x; awk
as gawk, mawk and the BSD awk on macOS run it, with no interval
expressions (research R6)

**Primary Dependencies**: `awk`, `grep`, `jq` (already required by the
gate); bats 1.11.0 for the tests

**Storage**: files

**Testing**: the house suite from the root,
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
judged by `bash scripts/check-suite.sh 248`; shellcheck as CI runs it

**Target Platform**: CI on Ubuntu, macOS and Windows; contributors' machines

**Project Type**: repository tooling (a gate script and its tests)

**Performance Goals**: not applicable (two changelogs of a few hundred lines)

**Constraints**: the "one version-agreement script" test stays green
unchanged (the new tests call the gate through `run bash -c`); the default
gate run's output is unchanged; the Phase 24 G3 message is kept; STRICT
vocabulary and no machine path on `scripts/`; no count in its prose;
messages print no absolute path; the fixture helper never reads a pattern
from the gate

**Scale/Scope**: one script, one test file (six new tests, one helper
widened), no document outside the spec directory

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | Every new shape fails with a named line; an unclosed fence, which would otherwise hide every later line, is itself refused (H6); every simplification leans to a refusal, never to a pass (R3). |
| II. Measure; never assert | The four passing shapes were measured at `8bc9b5a`; the quickstart re-measures the default output against `$BASE` and runs the real tree through both forms. |
| III. A gate must be shown able to go red | The new tests plant every shape and assert the named refusal; the quickstart puts back the `$BASE` gate and requires the tests to go red naming a clause (block 4); block 5 plants every refused kind in the LIVE changelog and requires the fixture tests to stay green, the opposite direction. |
| IV. One implementation, many callers | The rule stays inside the one gate both callers run. The fixture's rule is not a copy: it is deliberately wider and stateless (R5), a baseline, not a second gate. |
| V. Derive coverage | The walk judges every line of the file by kind, not a listed set of spellings. |
| Changelogs are history | No changelog changes. |
| Development workflow | Suite from the root, three systems, every path named, no plugin release. |

Result: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/024-gate-every-heading-form/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── release-form.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
scripts/check-versions.sh     # the release form's walk (R1, R2)
tests/portability.bats        # normalise_to_released widened (R5); +1 test
```

**Structure Decision**: the walk replaces the release form's existing
whole-file awk program in place, after the first-heading check, so the
default form and G3 are untouched; the six new tests sit after the two
existing release-rule tests.

## Post-design Constitution Check

Re-checked after research, data model, contract and quickstart: PASS.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Six new tests where the seed asked for one | About forty gate runs in one test passed the suite's 60-second per-test timeout, which is set once in `tests/helper.bash` for every suite | Raising the timeout for one test would loosen a limit every suite shares; split by contract clause, the slowest test measured about 13 s at H and about 17 s after review added plants at I, well under the 60-second cap |
| A stateful walk instead of one line pattern | A setext heading, a fence and a list item each change how other lines read | One pattern cannot see a neighbour, so every container and underline shape would pass: the wrong pass the owner ruled out |
