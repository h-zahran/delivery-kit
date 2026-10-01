# Feature Specification: Release pipeline 1.3.0

**Feature Branch**: `022-release-pipeline-1-3-0`

**Created**: 2026-10-01

**Status**: Draft

**Input**: Seed `## Phase 23: release pipeline 1.3.0` from `main-plan.md`,
quoted verbatim in the run's `seed.md`.

## Context

Campaign 3 changed how a pipeline run builds, commits and shows its work
(Phases 19–22, merged as PRs #47–#51; `main` = `d9a085e`). Every one of those
changes is described under `## [Unreleased]` in `pipeline/CHANGELOG.md`, and
none of them reaches an installed user until the plugin is released. This
feature is that release: it stamps a version and does nothing else.

All four prior phases are on `main` before this one starts — the seed's first
line, written because Campaign 2 released before its last phases landed and
left a fix unreleased for a cycle. Measured at `d9a085e`: the `[Unreleased]`
block carries the piece flow and pause mode (P19, P20), the late commits, K's
commit list, L's stops and the review guide (P21), and the status skill's new
stops (P22).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An installed user gets Campaign 3 (Priority: P1)

A developer who refreshes the `pipeline` plugin from the marketplace receives
version 1.3.0, and its changelog tells them, under a dated 1.3.0 heading, what
changed since 1.2.1.

**Why this priority**: it is the whole feature. Without the stamp, the
marketplace still offers 1.2.1 and the four merged phases ship to nobody.

**Independent Test**: read the three version sites and the version-agreement
gate's report; each names 1.3.0 and the gate reports the plugin released.

**Acceptance Scenarios**:

1. **Given** `main` at `d9a085e`, **When** the release lands, **Then** the
   marketplace lists `handoff 2.2.0` and `pipeline 1.3.0`, the pipeline
   manifest says `1.3.0`, and the pipeline changelog's top version heading is
   `## [1.3.0] - 2026-10-01`.
2. **Given** the release has landed, **When** the changelog is searched for an
   `## [Unreleased]` heading, **Then** there is none.
3. **Given** the release has landed, **When** the text under the new heading is
   compared with the text under `## [Unreleased]` at `d9a085e`, **Then** it is
   byte-identical.

---

### User Story 2 - The maintainer can tag with confidence (Priority: P2)

After the owner merges, the maintainer tags `pipeline-v1.3.0` from `main`, and
CI's tag gate confirms that the tag matches the manifest version.

**Why this priority**: the tag is what the release is found by; a tag that
disagrees with the manifest is a broken release. The tag itself is pushed
after the merge, outside this run.

**Independent Test**: the version-agreement gate passes on the pull request;
after the merge, the tag run's "tag matches the manifest version" step reports
`success` (not `skipped`).

**Acceptance Scenarios**:

1. **Given** the release branch, **When** the version-agreement gate runs,
   **Then** it reports `pipeline … state=released` and exits 0.
2. **Given** the merged release, **When** the tag `pipeline-v1.3.0` is pushed,
   **Then** the tag-gate step inside the "version agreement" job concludes
   `success`.

---

### Edge Cases

- **A second `[Unreleased]` site**: a link reference at the changelog's foot
  would survive a heading-only search. Measured at `d9a085e`: the string
  `Unreleased` occurs exactly once in `pipeline/CHANGELOG.md`, on the heading.
- **The handoff plugin**: nothing under `handoff/` changed since
  `pipeline-v1.2.1` (measured: `git log pipeline-v1.2.1..main -- handoff/` is
  empty), so it is not stamped and its 2.2.0 stays.
- **A JSON reformat**: rewriting `marketplace.json` through a JSON tool
  reflows its `tags` arrays; the version edit must change one line in each
  JSON file and nothing else.
- **A stale count elsewhere**: the stamp must not create a new place that
  states the version. Measured at `d9a085e` with
  `git grep -n -F 1.2.1 d9a085e -- ':!specs/' ':!main-plan.md'`: `1.2.1`
  occurs as a current version only in the two JSON files; the other hits are
  released changelog headings (`pipeline` 1.2.1 and `handoff` 1.2.1), which
  are history and stay.
- **A wrong date or a wrong version that still agrees**: a heading dated the
  wrong day, or all three sites stamped `1.3.1`, passes the agreement gate in
  both its forms (measured at I by mutation). Only this feature's own checks
  hold the two release facts: the exact version (S1, S2) and the exact
  heading with its date (S3). The tag-name step in CI would catch a wrong
  version, but only after the merge.
- **A tag name already taken**: an old tag `v1.3.0` exists, from the handoff
  plugin's 1.3.0 release (`handoff/CHANGELOG.md`, 2026-08-18), before tags
  carried a plugin prefix. The pipeline tag is `pipeline-v1.3.0`, which does
  not exist locally or on `origin` (measured). The two must not be confused
  when the tag is pushed and its CI run is read.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The pipeline manifest (`pipeline/.claude-plugin/plugin.json`)
  MUST give the version `1.3.0`.
- **FR-002**: The pipeline entry in `.claude-plugin/marketplace.json` MUST give
  `1.3.0`; the handoff entry MUST still give `2.2.0`.
- **FR-003**: `pipeline/CHANGELOG.md`'s `## [Unreleased]` heading MUST become
  `## [1.3.0] - 2026-10-01`, and no `## [Unreleased]` heading may remain.
- **FR-004**: The text beneath that heading MUST be byte-identical to the
  `[Unreleased]` block at `d9a085e`: nothing added, removed or reordered.
- **FR-005**: Nothing under `handoff/` may change.
- **FR-006**: The change set MUST be exactly three shipped files, one changed
  line each, plus this feature's own spec directory.
- **FR-007**: The full house suite, run from the repository root over all
  three suite paths, MUST report the P22 plan line (`1..240`) with every test
  ok, none failing and no non-TAP output.
- **FR-008**: The version-agreement gate (`scripts/check-versions.sh`) MUST
  report both plugins `state=released` and exit 0.
- **FR-009**: The version is a MINOR bump (1.2.1 → 1.3.0), because G gains a
  question and a stop and H, K and L change what they commit and show.

### Key Entities

- **Version site**: one place that states the plugin's current version — the
  manifest, the marketplace entry, and the changelog's top heading. The three
  must agree.
- **Released block**: the changelog text under a dated version heading;
  immutable once stamped.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All three pipeline version sites read `1.3.0`, and the handoff
  sites still read `2.2.0`.
- **SC-002**: Zero `## [Unreleased]` headings remain in the pipeline
  changelog.
- **SC-003**: The diff against `d9a085e`, outside the spec directory, is three
  files with one line changed in each.
- **SC-004**: The house suite reports 240 of 240 ok, matching its plan line.
- **SC-005**: CI on the pull request passes on all three operating systems,
  and a run is confirmed to exist before its result is read. Each result is
  read as a STEP conclusion inside its job, not only the job's own colour. On
  the pull request, these steps must conclude `success`: "Run the test
  suites" in each of the three test jobs, the agreement step ("every plugin's
  manifest, marketplace entry and changelog agree") and the shell-analysis
  job's steps. Some steps skip on a pull request by design (the tag step, the
  bats-tree check on Windows, the bats install on a cache hit); those are not
  failures there. On the tag run after the merge, the "tag matches the
  manifest version" step must conclude `success` — `skipped` there means the
  gate never ran.

## Assumptions

- Today's date, 2026-10-01, is the release date in the heading.
- The installed orchestrator for this run is 1.2.1; this run uses its
  single-commit flow, and a fresh `## [Unreleased]` heading is not opened (the
  1.2.1 release did not open one either).
- Tagging, the tag CI run and the plugin refresh happen after the owner's
  merge, outside this run.
