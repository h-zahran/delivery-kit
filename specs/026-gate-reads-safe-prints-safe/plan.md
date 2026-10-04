# Implementation Plan: The release gate reads only what it can judge, and prints only what is safe

**Branch**: `026-gate-reads-safe-prints-safe` | **Date**: 2026-10-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/026-gate-reads-safe-prints-safe/spec.md`

## Summary

One repository-level change, no plugin change. In `scripts/check-versions.sh`,
before any tool reads a plugin's changelog, the gate refuses a symbolic
link and anything that is not a regular file, in both forms (research R1);
the release form refuses its plugin's changelog over 262,144 bytes, size
read without reading the file (R2). Every value the gate prints from a
tracked file, a directory name or the command line passes once through one
masking function, `shown`, which cuts and masks into a variable with no
process (R3); the report line cannot start with `::`. The walk does not
change, so the Phase 26 proof stands (R7). Two tests are added, one per
user story (R8); the suite reads `1..251`.

## Technical Context

**Language/Version**: bash, written to run on bash 3.2 as well as 5.x
(`printf -v`, `[ -L ]`, `wc -c`; research R9)

**Primary Dependencies**: `grep`, `jq`, `tr`, `wc`, `awk` (already used by
the gate); bats 1.11.0 for the tests

**Storage**: files

**Testing**: the house suite from the root,
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
judged by `bash scripts/check-suite.sh 251`; shellcheck as CI runs it

**Target Platform**: CI on Ubuntu, macOS and Windows; contributors' machines

**Project Type**: repository tooling (a gate script and its tests)

**Performance Goals**: a link or an over-large changelog refused in under
2 s (SC-001, SC-003)

**Constraints**: the "one version-agreement script" test stays green
unchanged; both forms print as at `4016666` on the real tree; the walk's
text does not change; STRICT vocabulary, no machine path and no count in
prose on `scripts/`; every byte tool that may meet a byte which is not
valid text runs under `LC_ALL=C`

**Scale/Scope**: one script, one test file (two new tests), no document
outside the spec directory

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | A link to a device, today a hang with no message, is refused at once with the gate's own message (L1); a forged log line can no longer reach the log (P1-P3). |
| II. Measure; never assert | Each problem was measured at `6fd91f3`; R2's size read, R4's directory names and R5's link behaviour were measured here; the windows-latest runner's link support is measured by the first CI run, and the test prints which way it took. |
| III. A gate must be shown able to go red | The base-gate mutant (quickstart block 5) and one mutant per new rule (tasks). |
| IV. One implementation, many callers | One masking function for every print site; the rules stay inside the one gate both callers run. |
| V. Derive coverage | The print-site table is derived from the script, and the tasks re-derive it from the script before the masking is applied. |
| Changelogs are history | No changelog changes. |
| Development workflow | Suite from the root, three systems, every path named, no plugin release. |

Result: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/026-gate-reads-safe-prints-safe/
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
└── check-versions.sh       # link and file-type checks, size limit, one masking function
tests/
└── portability.bats        # two new tests
```

**Structure Decision**: the link, file-type and size checks sit in the
per-plugin loop, in that order, before the NUL check; `changelog_limit`
sits beside `line_limit`; `shown` replaces `quoted`, and `shown` and
`quote_cut` move above the argument loop, because the unknown argument
(`:90` at `4016666`) is printed through `shown`; each value gets its
`_s` copy where it is read. The two tests
sit after the Phase 26 tests, before the plugin-name test.

## Post-design Constitution Check

Re-checked after research, data model, contract and quickstart: PASS.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| A masked `_s` copy beside a dozen values | Comparisons must use the raw value, output the masked one | Masking inside `die` would also mask the gate's own em dash, and a value masked before comparison could compare equal when the raw values differ |
| The link test takes one of two ways per system | The windows-latest runner may not make links, and a skipped test fails the suite check | Skipping on Windows hides a red; a link made by plain `ln -s` is a silent copy in Git Bash (measured) |
