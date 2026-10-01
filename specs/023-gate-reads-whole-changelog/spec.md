# Feature Specification: The release gate reads the whole changelog, and one suite check

**Feature Branch**: `023-gate-reads-whole-changelog`

**Created**: 2026-10-01

**Status**: Draft

**Input**: Seed `## Phase 24: the release gate reads the whole changelog, and
one suite check` from `main-plan.md`, quoted verbatim in the run's `seed.md`.

## Context

The pipeline 1.3.0 release (`specs/022-release-pipeline-1-3-0/`) recorded three
gaps it could not close inside its own three lines (its `research.md`, R7).
This feature closes them. Nothing here is inside a plugin: `scripts/`, `tests/`
and `specs/` belong to the repository, so no plugin is released.

Measured 2026-10-01 at `main` = `5831822`:

- `scripts/check-versions.sh` reads the FIRST `## ` heading of a plugin's
  changelog (`grep -m1`) and, under `--released <plugin>`, refuses only when
  that first heading is not the version heading. An `## [Unreleased]` heading
  lower in the file passes both the default run and `--released`.
- Eleven feature quickstarts under `specs/` hold a hand-written copy of the
  house-suite result check. Only the `021` and `022` copies count skipped
  tests.
- Clause C4 of `specs/016-release-two-plugins/contracts/version-agreement.md`
  reads "**Enforced by**: **NOTHING.**", which stopped being true on
  2026-09-03, when commit `f5e4090` made a tag run's agreement step pass
  `--released` — first released in pipeline 1.2.1 and handoff 2.2.0, after
  the 1.2.0 tags. (The seed says "since 1.2.0"; measured at piece 3 with
  `git log -S'set -- --released' -- .github/workflows/ci.yml` and
  `git tag --contains`, that is one release early.)
- Every `## ` heading in both plugin changelogs today is a dated version
  heading (`## [X.Y.Z] - YYYY-MM-DD`): 6 in `pipeline`, 12 in `handoff`.

## Clarifications

### Session 2026-10-01

- Q: When a release tag is pushed, which changelog headings should the
  release check refuse? → A: Any undated heading: every line beginning
  `## ` that is not exactly a dated version heading
  (`## [X.Y.Z] - YYYY-MM-DD`), wherever it sits in the file. This covers
  `## [Unreleased]` and every other spelling of it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A tag cannot ship a changelog that still says "unreleased" (Priority: P1)

A maintainer pushes a release tag. CI's agreement step runs the gate in its
release form. If the plugin's changelog still holds an undated `## `
heading anywhere — `## [Unreleased]` or any other spelling, above the
version heading or below it — the step fails and names the line.

**Why this priority**: this is the gap that let a release leave an open
heading in the frozen history; only a one-off quickstart check caught it last
time, and CI never runs a quickstart.

**Independent Test**: in a fixture copy of the repository, plant
`## [Unreleased]` below a released heading, and separately an undated
heading of another spelling; the release form refuses each and names the
line, and the default form still passes.

**Acceptance Scenarios**:

1. **Given** a fixture whose changelog has a dated version heading first and
   an `## [Unreleased]` heading further down, **When** the gate runs with
   `--released <plugin>`, **Then** it exits non-zero, says the tree is not
   released, and names the line number of the planted heading.
2. **Given** the same fixture, **When** the gate runs with no argument,
   **Then** it exits 0 and prints its usual report.
3. **Given** a fixture whose `## [Unreleased]` heading is ABOVE the version
   heading (the shape the gate already refuses), **When** the gate runs with
   `--released`, **Then** it still refuses, as today.
4. **Given** a fixture whose changelog holds, below its version heading, an
   undated heading spelled differently (for example `## unreleased`),
   **When** the gate runs with `--released`, **Then** it refuses and names
   that line.
5. **Given** the real tree, **When** the gate runs with no argument, **Then**
   its output and exit status are unchanged from `5831822`.

---

### User Story 2 - A feature quickstart checks the suite with one shared script (Priority: P2)

A contributor writing a feature quickstart needs to prove the house suite
passed with an exact count. Instead of hand-writing the check again, they call
one script with the expected count and the saved test output.

**Why this priority**: eleven copies already exist and already differ; every
new copy is another place a fix will not reach.

**Independent Test**: feed the script one passing output and one output for
each failure shape; it passes only the first, and names the reason for each
failure.

**Acceptance Scenarios**:

1. **Given** a TAP file whose plan line is `1..N` with N `ok` lines and
   nothing else, **When** the script runs with expected N, **Then** it exits 0.
2. **Given** a TAP file with any one of: a plan line other than `1..N`; fewer
   `ok` lines than the plan; one skipped test; one `not ok`; one line that is
   neither TAP nor a comment; **When** the script runs with expected N,
   **Then** it exits non-zero and names that reason.
3. **Given** an empty file, or a path that does not exist, **When** the
   script runs, **Then** it exits non-zero and names that reason.
4. **Given** the contributing guide, **When** a contributor reads how to
   verify a feature, **Then** it tells them to call this script rather than
   write their own check.

---

### User Story 3 - The release record tells the truth about C4 (Priority: P3)

A reader of the 1.2.0/2.1.1 release record learns that clause C4 is now
enforced, without the dated record itself being rewritten.

**Why this priority**: a record that says "enforced by nothing" about an
enforced rule sends the next reader to re-solve a closed problem; but the
record is history and must not be edited.

**Independent Test**: diff the 016 contract against `5831822`: only added
lines, below clause C4.

**Acceptance Scenarios**:

1. **Given** the 016 contract, **When** this feature lands, **Then** a dated
   note sits below clause C4 saying that since `f5e4090` (first released in
   pipeline 1.2.1 and handoff 2.2.0) a tag run's agreement step enforces C4
   for the plugin being tagged, and since this feature the release form
   also refuses an undated heading anywhere in the file.
2. **Given** the same file, **When** it is compared with `5831822`, **Then**
   every line that existed there is unchanged.

### Edge Cases

- **The "one version-agreement script" test** (`tests/portability.bats`,
  "one version-agreement script, and both gates call it") requires exactly one
  `run bash <script>.sh` line in `tests/portability.bats` and exactly one
  `bash <script>.sh` line in `.github/workflows/ci.yml`. The new suite-check
  script's own tests therefore live outside `tests/portability.bats`, and CI
  does not call it.
- **The heading's spelling** (settled at clarify): the release form refuses
  every line beginning `## ` that is not exactly a dated version heading.
  A line is read as the gate reads its first heading today, `^## `; a
  `###` heading or deeper is not a level-2 heading and is not judged.
  Measured at `5831822`: all 18 level-2 headings in both changelogs are
  dated, so the real tree passes.
- **CRLF**: on Windows, `jq` may print CRLF and a TAP file may hold CRLF
  lines; the suite check must count the same on LF and CRLF input.
- **The default run's report**: the `state=` field keeps its current meaning
  (what sits above the version heading); it is not widened, because the CI
  log and an existing test read it.
- **The eleven existing quickstarts** are dated records and are not edited.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Under `--released <plugin>`, the gate MUST refuse when the
  plugin's changelog contains, anywhere, a line beginning `## ` that is not
  exactly a dated version heading (`## [X.Y.Z] - YYYY-MM-DD`) — which
  includes `## [Unreleased]` in any spelling — and the refusal MUST name
  the line number and say the tree is not released.
- **FR-002**: The gate's default run (no argument) MUST keep its output and
  exit status for every input it accepts today.
- **FR-003**: The gate MUST stay the single implementation both callers use;
  the "one version-agreement script" test MUST stay green unchanged.
- **FR-004**: A new script `scripts/check-suite.sh <expected> <tap-file>` MUST
  exit 0 only when the plan line is `1..<expected>`, the count of `ok` lines
  is `<expected>`, and there are 0 skipped tests, 0 `not ok` lines and 0
  lines that are neither TAP nor comments.
- **FR-005**: The suite check MUST exit non-zero, naming the reason, for each
  of: a wrong plan line; a second plan line; an `ok` count different from
  expected; a skipped test; a `not ok`; a non-TAP line; an empty file; a
  missing file; arguments that are not exactly a positive integer and a
  file.
- **FR-006**: The suite check MUST give the same verdict on LF and CRLF input.
- **FR-007**: `CONTRIBUTING.md` MUST tell a contributor that a feature
  quickstart verifies the suite by calling `scripts/check-suite.sh`.
- **FR-008**: A dated note MUST be appended below clause C4 in
  `specs/016-release-two-plugins/contracts/version-agreement.md`; no existing
  line of that file may change.
- **FR-009**: The house suite MUST grow by exactly two tests (`1..240` →
  `1..242`): one for FR-001/FR-002, one driving every FR-004/FR-005 shape.
- **FR-010**: Every changed line on `scripts/` and `CONTRIBUTING.md` (STRICT
  surfaces) MUST avoid the banned vocabulary, machine paths and counts in
  prose; no plugin file changes.

### Key Entities

- **Release form**: the gate run as `--released <plugin>`; what a tag run
  calls.
- **Suite result**: a saved TAP file from the house suite, plus the count the
  feature expects.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A changelog with `## [Unreleased]`, or another undated
  heading, below its version heading is refused by the release form (0 of
  2 planted cases slip through), and the same fixture passes the default
  form.
- **SC-002**: The suite check returns the right verdict on all ten shapes
  (one pass, nine failures — contract K2–K10), each failure for its own
  named reason, and the same verdicts on CRLF input (K11).
- **SC-003**: A mutant that restores the first-heading-only comparison makes
  the FR-001 test fail; a mutant that drops any one suite-check rule, the
  CR strip included, makes the FR-005 test fail.
- **SC-004**: The house suite reads `1..242`, 242 ok, 0 skipped, 0 not ok, 0
  non-TAP; CI passes on three operating systems, a run confirmed to exist.
- **SC-005**: The 016 contract's diff from `5831822` holds only added lines.

## Assumptions

- The installed pipeline is 1.3.0, so this run builds and commits in pieces.
- No plugin is released: neither plugin directory changes.
- The root `CHANGELOG.md` is an index and gets no entry.
