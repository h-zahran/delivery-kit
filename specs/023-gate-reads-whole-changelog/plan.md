# Implementation Plan: The release gate reads the whole changelog, and one suite check

**Branch**: `023-gate-reads-whole-changelog` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/023-gate-reads-whole-changelog/spec.md`

## Summary

Three repository-level changes, no plugin change:

1. `scripts/check-versions.sh --released <plugin>` refuses every line
   beginning `## ` that is not a dated version heading, anywhere in that
   plugin's changelog, naming the line (research R1).
2. A new `scripts/check-suite.sh <expected> <tap-file>` gives the one verdict
   a feature quickstart needs on a saved house-suite run (R2), and
   `CONTRIBUTING.md` says to call it (R4).
3. A dated note appended below clause C4 of the 016 contract (R5).

Two tests are added: one in `tests/portability.bats` for (1), one in a new
`tests/check-suite.bats` for (2) (R3).

## Technical Context

**Language/Version**: bash, written to run on bash 3.2 as well as 5.x —
macOS CI may run the system `/bin/bash` 3.2, and the repository already
guards against its traps (`scripts/context-guard/field-order-mutation.sh:37`
notes the empty-array one). So: no `mapfile`, no empty array expanded under
`set -u`, no `${var,,}`; counting is done in `awk` (research R6)

**Primary Dependencies**: `grep`, `awk`, `jq` (already required by the gate);
bats 1.11.0 for the tests

**Storage**: files

**Testing**: the house suite from the root,
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`;
shellcheck as CI runs it (it discovers `scripts/check-suite.sh` itself)

**Target Platform**: CI on Ubuntu, macOS and Windows; contributors' machines

**Project Type**: repository tooling (gate scripts and their tests)

**Performance Goals**: not applicable

**Constraints**: the "one version-agreement script" test stays green
unchanged (exactly one `run bash <script>.sh` in `tests/portability.bats`,
exactly one `bash <script>.sh` in `ci.yml`); the default gate run's output is
unchanged; STRICT vocabulary and no machine path on `scripts/` and
`CONTRIBUTING.md`; no count in their prose; messages print no absolute path

**Scale/Scope**: two scripts, two tests, three documents

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | The gate's new rule fails with a named line; the suite check refuses an empty file, a missing file and a bad count rather than passing on nothing. |
| II. Measure; never assert | Every claim in the spec is measured at `5831822`; the quickstart re-measures. |
| III. A gate must be shown able to go red | Each test plants the defect and asserts the named refusal; mutants that remove each rule are run (quickstart block 4) and must turn the tests red. |
| IV. One implementation, many callers | The release rule stays inside the one gate script. The suite check exists to replace hand copies; it gets its own file so the gate's one-script pin is untouched. **Named departure:** IV asks that a test pin callers to the one implementation. The suite check's callers are future quickstarts under `specs/`, which no test reads, and the seed fixes the suite at exactly two new tests; `CONTRIBUTING.md` carries the rule instead, and the departure is recorded here. |
| V. Derive coverage | The gate judges every `## ` line of the file, not a listed set of spellings. |
| Changelogs are history | No plugin changelog changes. The 016 record gains an appended note; no existing line changes. |
| Development workflow | Suite from the root, three systems, every path named, no plugin release. |

Result: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/023-gate-reads-whole-changelog/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── release-form.md
│   └── check-suite.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
scripts/check-versions.sh                          # release rule (R1)
scripts/check-suite.sh                             # new (R2)
tests/portability.bats                             # +1 test (R3)
tests/check-suite.bats                             # new, 1 test (R3)
CONTRIBUTING.md                                    # one paragraph (R4)
specs/016-release-two-plugins/contracts/version-agreement.md   # appended note (R5)
```

**Structure Decision**: the suite check is a sibling of the gate in
`scripts/`, the repository's tooling directory; its test is a new file so
`tests/portability.bats` keeps exactly one `run bash <script>.sh` line.

## Post-design Constitution Check

Re-checked after research, data model, contracts and quickstart: PASS.

## Complexity Tracking

None.
