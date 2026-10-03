# Implementation Plan: The release gate closes the gaps Phase 25 left

**Branch**: `025-gate-closes-phase25-gaps` | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/025-gate-closes-phase25-gaps/spec.md`

## Summary

One repository-level change, no plugin change. The release form of
`scripts/check-versions.sh` gains two refusals at the top of its walk (a
line over 1,000 bytes, a CR byte) and the gate gains one before any file
read (a NUL byte, in both forms); the walk runs under the C locale, and
every quoted text is masked byte by byte and cut; and the four
wrong refusals Phase 25 accepted are each narrowed behind an oracle proof
with a positive control, or kept with the reason recorded (research R1 to
R10). The `--released` test helpers in `tests/portability.bats` pass data
as arguments, check every output for absolute paths in every spelling,
prove every plant landed, and can fail in their own self-checks (R11). One
test is added (R12); the suite reads `1..249`.

## Technical Context

**Language/Version**: bash, written to run on bash 3.2 as well as 5.x; awk
as gawk and the BSD awk on macOS run it, with no interval expressions
(research R13)

**Primary Dependencies**: `awk`, `grep`, `jq`, `tr` (already required by
the gate); bats 1.11.0 for the tests; for the proof only, Python with
markdown-it-py 4.0.0 (installed here; not a repository dependency)

**Storage**: files

**Testing**: the house suite from the root,
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
judged by `bash scripts/check-suite.sh 249`; shellcheck as CI runs it

**Target Platform**: CI on Ubuntu, macOS and Windows; contributors' machines

**Project Type**: repository tooling (a gate script and its tests)

**Performance Goals**: a 400,000-marker line refused in under 2 s (SC-002)

**Constraints**: the "one version-agreement script" test stays green
unchanged; the default run's output on the real tree is unchanged; the
first-heading check keeps reading the first `## ` line; STRICT vocabulary
and no machine path on `scripts/`; no count in its prose (the limits are
values in code, never words in a comment); messages print no absolute
path; the fixture helper never reads a pattern from the gate

**Scale/Scope**: one script, one test file (one new test, plants added to
four existing ones, helpers hardened), one proof script in the spec
directory, no document outside the spec directory

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | The NUL byte, today a silent exit 1, gains a message (K5); a CR, the last known wrong pass, is refused (K1); every narrowing is behind a proof, and a failed proof keeps the refusal (FR-010). |
| II. Measure; never assert | Every gap was measured at `ceff931`; the quickstart re-measures the default output against `$BASE`, and the proof records every case and verdict. |
| III. A gate must be shown able to go red | The base-gate mutant (quickstart block 4), one mutant per new rule and per helper change (tasks), and a positive control for every narrowing (R10). |
| IV. One implementation, many callers | Every rule stays inside the one gate both callers run; the fixture keeps its own wider rule, never a copy (FR-017). |
| V. Derive coverage | The proof enumerates shapes by combination, not by a listed set (R10). |
| Changelogs are history | No changelog changes. |
| Development workflow | Suite from the root, three systems, every path named, no plugin release. |

Result: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/025-gate-closes-phase25-gaps/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── release-form.md
├── proof/
│   └── enumerate.py        # the narrowing proof (R10); run-time evidence
├── checklists/
│   └── requirements.md
└── tasks.md                # created by the tasks phase
```

### Source Code (repository root)

```text
scripts/
└── check-versions.sh       # NUL check, masked first heading, walk rules
tests/
└── portability.bats        # helpers hardened, plants added, one new test
```

**Structure Decision**: the NUL check sits in the per-plugin loop before
the dated-heading `grep`; the first-heading masking edits the two lines
that print `$first`; the walk's new rules sit at the top of its per-line
block, and the narrowings edit the rules they relax. The new test sits
after the six Phase 25 tests.

## Post-design Constitution Check

Re-checked after research, data model, contract and quickstart: PASS.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Four narrowings add state to a walk Phase 25 kept small | The owner asked for every wrong refusal to be attempted | Keeping all four refused is simpler, and it stays the outcome for any narrowing whose proof fails (FR-010) |
| A Python proof script in the spec directory | A reference CommonMark reader is the only oracle that found the Phase 25 wrong passes | Random fuzz found none of them; a hand-written list of shapes is the enumeration Principle V forbids |
