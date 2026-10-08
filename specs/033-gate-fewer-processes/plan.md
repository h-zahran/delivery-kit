# Implementation Plan: The release gate starts fewer processes, and its walk is tested on its own

**Branch**: `033-gate-fewer-processes` | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/033-gate-fewer-processes/spec.md`

## Summary

One repository-level change, no plugin change. In
`scripts/check-versions.sh`: the marketplace's shape check and entry list
become one `jq` process (research R2); each plugin's shape check, name,
version and its three marketplace answers become one `jq` process (R1),
its fields length-prefixed so no separator is needed (R4), with `-b` so
Windows writes no CR (R5). 14 processes become 3 on the real tree. The
heading walk moves, text unchanged (R7), to
`scripts/check-versions-walk.awk`, found beside the gate from
`BASH_SOURCE` and checked before it runs (R6). In
`tests/portability.bats`: about 98 gate runs that test only the walk run
the walk directly on standard input, from the test file's own copies of
the three values the gate hands it; one end-to-end run stays for each
thing only the gate does; five tests are added (R8). A one-time
differential over every fixture the suite builds proves every message
unchanged, except an asserted Windows divergence (R5, R10).

## Technical Context

**Language/Version**: bash, written to run on bash 3.2 as well as 5.x;
awk as CI runs it (gawk; the BSD awk on macOS)

**Primary Dependencies**: `jq` (1.7, 1.8.1, 1.8.2 in CI), awk; bats
1.11.0 for the tests

**Storage**: files

**Testing**: the house suite from the root,
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
judged by `bash scripts/check-suite.sh 431`; shellcheck as CI runs it

**Target Platform**: CI on Ubuntu, macOS and Windows; contributors' machines

**Project Type**: repository tooling (a gate script, its walk, and their tests)

**Performance Goals**: 3 `jq` processes per gate run on the real tree
(SC-001); `tests/portability.bats` faster, measured, no target (SC-003)

**Constraints**: every message byte-identical to `2b38f74` but the
asserted Windows divergence; the walk's text unchanged; "one
version-agreement script" test green unchanged; STRICT vocabulary, no
machine path and no count in prose on `scripts/`; no interval
expressions in awk; no `\/` inside a pattern substitution; `LC_ALL=C` for
byte tools; tests match in the shell, never `grep … < <(printf …)`

**Scale/Scope**: one script changed, one awk file added, one test file
(five new tests, about 98 runs moved), no document outside the spec
directory

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | A missing, unreadable or failing walk file stops the gate with its own line; today a failing walk ends the run with no message (R6). A field the gate cannot cut is a hard failure, never a wrong value (R4). |
| II. Measure; never assert | The process count, the times, the parse cost, the Windows divergence and the read's agreement on 21 fixtures were measured (R1, R3, R5); "every message unchanged" is a differential (R10), and its one divergence is asserted, not allowed. |
| III. A gate must be shown able to go red | The differential with a one-byte mutant; a mutant per new rule (walk found from the working directory, field cut off by one, walk file missing) — tasks. |
| IV. One implementation, many callers | CI and the suite still call the one gate; the walk is called only by the gate. The direct tests run the same walk file the gate runs. |
| V. Derive coverage | The differential compares every fixture the suite builds, by running the suite over a wrapper, not a list of shapes (R10). The test inventory was derived from the code (R8). |
| Changelogs are history | No changelog changes. |
| Departures named | Four, in research R12, and in the spec. |
| Development workflow | Suite from the root, three systems, every path named, no plugin release. |

Result: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/033-gate-fewer-processes/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── release-gate.md
├── checklists/
│   └── requirements.md
└── tasks.md                # created by the tasks phase
```

### Source Code (repository root)

```text
scripts/
├── check-versions.sh        # two merged reads, field cutting, the walk called by path
└── check-versions-walk.awk  # new: the heading walk, text unchanged
tests/
└── portability.bats         # walk_on helper, held values hoisted, ~98 runs moved, five tests added
```

**Structure Decision**: the marketplace read replaces `:174` and feeds
the reverse walk where `:766` was; the per-plugin read replaces `:320`,
`:326`, `:328` and supplies `:360`, `:362`, `:375`'s values at their
current place in the loop. A small function cuts one field (`take`-like,
under `LC_ALL=C`), beside `shown`. The walk file's location is worked out
once near the top, after the options line; the check and call stay where
the walk runs today.

## Post-design Constitution Check

Re-checked after research, data model, contract and quickstart: PASS.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Length-prefixed fields instead of a separator | Every character but NUL can be in a JSON string, and NUL cannot cross `$( )` (R4) | A tab or line-feed separator splits a value holding one; `@tsv` escapes values, changing the bytes printed |
| The marketplace read by 1 + N processes, not 1 (departure 2) | Cutting every entry in bash is quadratic, measured (R3) | One read for all lookups: 39 s for a 528,000-byte list; names passed as `--arg`: bounded argument length on Windows |
| A one-time differential, not a permanent one | CI clones one commit and cannot read `2b38f74` (clarification) | A frozen copy of the old gate: 865 lines nobody maintains, stale at the next intended change |
