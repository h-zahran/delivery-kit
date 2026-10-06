# Implementation Plan: The release gate closes what Phase 27 deferred

**Branch**: `027-gate-closes-phase27-deferrals` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/027-gate-closes-phase27-deferrals/spec.md`

## Summary

One repository-level change, no plugin change. In
`scripts/check-versions.sh`: the gate refuses a symbolic link at every
path it reads, before any tool reads through it (research R1); checks
each JSON file's shape once with `jq`'s own errors discarded, so no `jq`
line reaches the output and "not JSON", "wrong shape" and "could not be
read" stay distinct (R2); shows `##[` as `#?[` in every printed value,
with a probe measuring the runner once in this pull request's CI (R3);
turns off `xtrace`, `verbose`, `noglob` and `keyword`, then `dotglob`
and `nocasematch` (`shopt -u`, added at review), at its first command,
and records `noexec`, `onecmd` and `BASH_ENV` as limits (R4);
and normalises a marketplace source with no process (R5). Three test
helpers are made to check what they claim (R6). The walk does not
change, so the Phase 26 proof stands (R7). One test is added; the suite
reads `1..252` (R8).

## Technical Context

**Language/Version**: bash, written to run on bash 3.2 as well as 5.x
(`printf -v`, `[ -L ]`, `[[ =~ ]]`, quoted patterns; research R9)

**Primary Dependencies**: `jq`, `grep`, `tr`, `wc`, `awk` (already used by
the gate); bats 1.11.0 for the tests

**Storage**: files

**Testing**: the house suite from the root,
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
judged by `bash scripts/check-suite.sh 252`; shellcheck as CI runs it

**Target Platform**: CI on Ubuntu, macOS and Windows; contributors' machines

**Project Type**: repository tooling (a gate script and its tests)

**Performance Goals**: a link refused in under 2 s (SC-001); the walk's
cost per marketplace entry falls (SC-004; figures in research R5)

**Constraints**: the "one version-agreement script" test stays green
unchanged; both forms print as at `5a78ea4` on the real tree; the walk's
text does not change; STRICT vocabulary, no machine path and no count in
prose on `scripts/`; no `\/` inside a pattern substitution; every byte
tool that may meet a byte which is not valid text runs under `LC_ALL=C`

**Scale/Scope**: one script, one test file (one new test, plants in three
others), no document outside the spec directory

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | `SHELLOPTS=noexec` and `onecmd` make the gate exit 0 having printed nothing (measured at D). No line of the gate can stop that, so it is recorded as a limit beside `BASH_ENV` (the owner's ruling covers `BASH_ENV`, and the owner confirmed these two at gate G, 2026-10-06), and named in the pull request; every case the gate can reach now ends with its own line. |
| II. Measure; never assert | Each deferral was measured at `5a78ea4`; R2's `jq` statuses, R4's options table and R5's cost were measured here; the `##[` behaviour is measured on a runner by this pull request's CI and recorded before merge. |
| III. A gate must be shown able to go red | The base-gate mutant (quickstart block 5) and one mutant per new rule and per changed test helper (tasks). |
| IV. One implementation, many callers | The rules stay inside the one gate both callers run; the callers do not change. |
| V. Derive coverage | The read-path table and the `jq`-read list are derived from the script; the P0 scan derives print sites from the script rather than listing them. |
| Changelogs are history | No changelog changes. |
| Development workflow | Suite from the root, three systems, every path named, no plugin release. |

Result: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/027-gate-closes-phase27-deferrals/
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
└── check-versions.sh       # link checks, shape checks, ##[ mask, options off, norm_source by name
tests/
└── portability.bats        # one new test; plants in the P, TRAILING and K tests; P0, K3, gate_safe
```

**Structure Decision**: the options line is the gate's first command,
at line 2, before the header comments; the repository-level link checks
sit before the `-f marketplace.json` test, and its open and shape checks
after `command -v jq`; in the loop, `shown p_s` moves above the
per-plugin link checks, which sit before the `-f plugin.json` test, and
its shape check after its open check; the reverse walk's link check before its `-f` test; the `##[`
step at the end of `shown` and on `refusal` after the walk. The new
test sits after the TRAILING test, before the `.claude/` test.

## Post-design Constitution Check

Re-checked after research, data model, contract and quickstart: PASS.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| A temporary probe in the P test (X2) | FR-003 needs a runner's own behaviour, and nothing may be pushed before gate L | A probe branch pushed before H is a push before gate L; measuring nowhere leaves FR-003 unmet |
| A shape check before the reads | `jq -e` exits 5 both for "not JSON" and for a lookup on a string (measured), so the lookup alone cannot name the fault | Discarding `jq`'s errors at each read would turn a malformed file into "no entry named …" |
| Link checks placed by hand at each read path (Principle V) | The read paths are expressions in the script (`./$p/…`, `./$ed/…`), not names a scan can collect as the P0 scan collects `die` lines | A derived scan of every `-f`, `jq` and redirect path is left for a later phase (research R1); the read-path table is derived from the script once, at this phase |
