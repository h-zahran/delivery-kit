# Feature Specification: The constitution NUL check answers the same way under any load

**Feature Branch**: `047-preflight-nul-race`

**Created**: 2026-11-02

**Status**: Implemented

**Input**: Seed kept verbatim in the run directory as `seed.md`: a race in `pipeline/scripts/preflight.sh`'s constitution NUL check, found during feature 046.

## Context

Pre-flight decides whether the repository's constitution is "set". A
constitution saved as UTF-16 or UTF-32 holds NUL bytes; pre-flight must then
warn and read it as **not set**, so the run offers to write one instead of
planning against a document it cannot read.

The check pipes the file's first 4,096 bytes through `od` into `grep -q ' 00'`
while the script runs with `pipefail`. `grep -q` stops at its first match and
closes the pipe; the program still writing can then be killed by SIGPIPE, the
pipeline reports failure, and the check takes the "no NUL" branch. The
constitution is then read as **set** — the wrong answer, in the direction the
comment above the check says it must never fail ("fail toward offering, never
toward set").

Measured on 2026-11-02 with that exact pipeline on the `constitution-nul`
fixture: 0 wrong answers in 300 runs on a quiet machine, 30 in 400 with extra
CPU load. It failed one `preflight.bats` test once in a full-suite run on a
loaded machine. A sweep of every tracked shell script that sets `pipefail`
found no other pipe into `grep -q`.

## Clarifications

### Session 2026-11-02

- Q: Should this run also release the fix as pipeline 1.7.2, or leave the release for later? → A: Release 1.7.2 in this run (FR-007).

## User Scenarios & Testing *(mandatory)*

The users are people running `/pipeline` (who rely on pre-flight's answer) and
maintainers of this repository (who rely on the suite being stable).

### User Story 1 - A NUL-holding constitution is always read as not set (Priority: P1)

A developer whose constitution was saved as UTF-16 starts a run on a busy
machine. Today pre-flight sometimes calls that constitution set and plans
against it. After this change it always warns and reads it as not set.

**Why this priority**: it is the wrong answer in the unsafe direction, and it
also makes the suite flaky on a loaded machine.

**Independent Test**: a test forces the reader to stop early (so a writer that
keeps writing would be killed) and checks the answer is still "NUL found". It
fails on the old code every time, not only under load.

**Acceptance Scenarios**:

1. **Given** the `constitution-nul` fixture, **When** pre-flight runs, **Then** it warns about NUL bytes and reports `constitutionSet: false`, every time.
2. **Given** a test that makes the NUL check's reader exit at its first match while the writer still has output, **When** the old check runs, **Then** it answers wrongly; **When** the new check runs, **Then** it answers "NUL found".
3. **Given** every other constitution fixture (`constitution-set`, `constitution-unset` — the fresh-init shape — `constitution-bom` and `constitution-unclosed`), **When** pre-flight runs, **Then** its output is byte-identical to before.

---

### User Story 2 - The same mistake cannot come back unseen (Priority: P2)

A maintainer later writes another pipe into `grep -q` in a script that sets
`pipefail`. A test names the line and fails.

**Why this priority**: the bug class is easy to write and almost never shows
on a quiet machine; only a walk over the scripts catches it reliably.

**Independent Test**: add one such pipe to a scratch copy of a shipped script;
the test fails and names the file and line.

**Acceptance Scenarios**:

1. **Given** the repository after the fix, **When** the test walks every tracked shell script that sets `pipefail`, **Then** it finds no pipe into `grep -q` (or `grep --quiet`) and says how many files it walked.
2. **Given** a scratch copy with one such pipe added, **When** the test runs on it, **Then** it fails naming the file and line.
3. **Given** a walk that found zero scripts, **When** the test runs, **Then** it fails rather than passing on nothing.

### Edge Cases

- **A file shorter than 4,096 bytes, or empty**: unchanged behaviour — an
  empty or NUL-free file goes on to the normal parse.
- **An unreadable constitution file**: unchanged — the existing `2>/dev/null`
  behaviour stands; this change does not widen or narrow it.
- **A NUL after the first 4,096 bytes**: unchanged — only the head is checked,
  as today.
- **The walk's own source**: the refusing test must not flag itself or test
  fixtures; it walks shipped scripts only (tracked `*.sh` and `*.bash` outside
  `.specify/` and test directories).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The NUL check MUST reach its answer without depending on the
  exit status of a program that a reader may stop reading from early.
- **FR-002**: For every existing constitution fixture, pre-flight's stdout and
  stderr MUST be byte-identical before and after the change, and the change
  MUST touch nothing else pre-flight reports.
- **FR-003**: A committed test MUST reproduce the old failure deterministically
  — by forcing the early-exit condition, not by load — and MUST fail on the old
  check and pass on the new one. The run MUST show it failing on the old code.
- **FR-004**: A committed test MUST walk every tracked shipped shell script
  that sets `pipefail` and fail, naming file and line, on a pipe into
  `grep -q` or `grep --quiet`; it MUST fail when it walked zero scripts; it
  MUST be shown able to go red.
- **FR-005**: The fix MUST work on bash 3.2 with BSD tools (macOS CI), on
  Git Bash (Windows CI) and on Linux, with no new dependency.
- **FR-006**: `pipeline/CHANGELOG.md` MUST describe the fix (first under its
  unreleased section; FR-007 then dates that section as 1.7.2).
- **FR-007**: This run MUST release the fix as pipeline 1.7.2: the version in
  `pipeline/.claude-plugin/plugin.json` and the `pipeline` entry of
  `.claude-plugin/marketplace.json` both read `1.7.2`, the changelog's
  section is headed `## [1.7.2] - <date>`, the repository's version-agreement
  and release-gate checks pass, and after the merge a `pipeline-v1.7.2` tag
  points at the release commit with CI's tag step green.
- **FR-008**: The full suite MUST stay green, with the plan line equal to the
  ok count in each test root, and no skipped test.

### Key Entities

- **NUL check**: the decision "the constitution's first 4,096 bytes hold a
  NUL byte", which sends pre-flight to "not set, with a warning".
- **Early-exit reader**: a reader that stops at its first match and closes its
  input pipe while a writer may still be writing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The deterministic test fails on the old check in 10 of 10 runs
  and passes on the new one in 10 of 10 runs.
- **SC-002**: The exact load reproduction from the context (400 runs under
  extra CPU load) gives 0 wrong answers with the new check (30 with the old).
- **SC-003**: Every existing constitution fixture produces byte-identical
  pre-flight output before and after.
- **SC-004**: The refusing test goes red on a planted pipe into `grep -q`, and
  on a walk over zero scripts.
- **SC-005**: The full suite passes in all four roots, no test skipped.
- **SC-006**: After the merge, tag `pipeline-v1.7.2` exists on the release commit and CI's tag step for it succeeds.

## Assumptions

- Only the head-of-file NUL check changes; the rest of the constitution parse
  is out of scope.
- The refusing test covers `grep -q`/`--quiet` after a pipe in scripts that
  set `pipefail`. Other early-exit readers (`head`, `grep -m`) are not part of
  it: the one such site found (`progress.sh` reading one character for an
  emptiness check) uses only the output, not the status, and is correct.
