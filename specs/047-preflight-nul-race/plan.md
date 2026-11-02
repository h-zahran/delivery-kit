# Implementation Plan: The constitution NUL check answers the same way under any load

**Branch**: `047-preflight-nul-race` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/047-preflight-nul-race/spec.md`

## Summary

`pipeline/scripts/preflight.sh` decides "the constitution holds a NUL byte"
with `head | od | grep -q ' 00'` under `pipefail`; `grep -q`'s early exit can
kill `od` with SIGPIPE and flip the answer to "set". The fix captures `od`'s
whole output first and tests it with a `case` pattern, so no reader stops
early. A test in `pipeline/tests/preflight.bats` forces the early exit with a
fake `od` on `PATH` (a NUL line, then about 1 MB more), which makes the old
check wrong every time. A new `tests/pipefail.bats` walks every tracked shipped
script that sets `pipefail` and refuses a pipe into `grep -q`. The same pull
request releases pipeline 1.7.2.

## Technical Context

**Language/Version**: bash (3.2 on the macOS runner, 5.x on Linux and Git Bash)

**Primary Dependencies**: coreutils `head`, `od`; bats-core 1.11.0; jq

**Storage**: N/A

**Testing**: bats; full suite = `testCommand` (four roots); shellcheck = `analyzeCommand`

**Target Platform**: CI on ubuntu-24.04, macos-26, windows-2025; local Ubuntu (uutils coreutils)

**Project Type**: Claude Code plugin repository (shell scripts + tests)

**Performance Goals**: none; the captured `od` output is at most about 12 KB (4,096 bytes as hex)

**Constraints**: byte-identical pre-flight output on every existing fixture; no skipped test (CI fails a skip); no new dependency

**Scale/Scope**: one line of `preflight.sh`, one new test in `preflight.bats`, one new test file, a changelog entry, a version bump in two manifests

## Constitution Check

| Principle | How this plan meets it | Status |
|---|---|---|
| I. Silence is the failure that matters | The fix removes a wrong "set" that no message reported. The refusing test fails when it walked zero scripts. | PASS |
| II. Measure; never assert | SC-001 (10/10 each way), SC-002 (400 runs under load) and SC-003 (fixture byte identity) are run and recorded in `measurements.md` with date and commit. | PASS |
| III. A gate must be shown able to go red | The deterministic test is run against the old line (red) before the fix; the refusing test gets planted-line and zero-file controls, committed as fixture tests. | PASS |
| IV. One implementation, many callers | Not affected: one check, one caller. | PASS |
| V. Derive coverage; never enumerate it | The refusing test walks `git ls-files`, filtered by content (`pipefail`), instead of naming scripts. | PASS |

## Project Structure

### Documentation (this feature)

```text
specs/047-preflight-nul-race/
├── spec.md
├── plan.md
├── research.md
├── quickstart.md
├── measurements.md      # written during implementation
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
pipeline/scripts/preflight.sh        # the NUL check (one statement)
pipeline/tests/preflight.bats        # the deterministic regression test
tests/pipefail.bats                  # new: the refusing walk and its controls
pipeline/CHANGELOG.md                # Fixed entry, then the 1.7.2 heading
pipeline/.claude-plugin/plugin.json  # version 1.7.2
.claude-plugin/marketplace.json      # pipeline entry 1.7.2 (edited with sed)
```

**Structure Decision**: as listed; no new directories.

## Complexity Tracking

None.
