# Feature Specification: release pipeline 1.2.0 and handoff 2.1.1

**Feature Branch**: `016-release-two-plugins`

**Created**: 2026-09-03

**Status**: Draft

**Input**: Campaign 2, Phase 16 of `main-plan.md` (lines 1558–1625), quoted
verbatim into `.delivery-kit/runs/016-release-two-plugins/seed.md`.

This is a **release** feature. It ships no behaviour. Every line of behaviour it
publishes is already merged on `main`; what is missing is the act of naming a
version and closing the two changelog headings that have stood open since
2026-08-25.

## Clarifications

### Session 2026-09-03

- Q: Nothing in the suite catches a dangling `## [Unreleased]` heading — that is
  why one survived a whole release cycle. Close that gap in this run? → A: No —
  keep the seed's scope. Five files change and nothing else; FR-008 is verified
  by direct search rather than by trusting the agreement gate, and the gap stays
  recorded and open for a later phase.

Two candidate questions were **resolved by measurement instead of being asked**,
because a fact that can be checked must not be put to a person:

- Whether the root `CHANGELOG.md` is a sixth file needing a version stamp. It is
  not. It is a pure index of links to the two plugin changelogs and contains no
  version number at all.
- Whether any other tracked file carries one of the two outgoing version
  strings. None does. Searching the tree outside the changelogs, the specs and
  the plan finds exactly four: two in `.claude-plugin/marketplace.json` and one
  in each plugin manifest. Two further matches exist and MUST NOT change — a
  comment in `pipeline/scripts/preflight.sh` and one in
  `pipeline/tests/prose.bats`, both of which describe what the 1.1.0 release
  did, and are history rather than current version records.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Someone installing the plugins gets a named version (Priority: P1)

A person adds this marketplace and installs `pipeline` or `handoff`. Today the
manifest says 1.1.0 and 2.1.0, and the work merged since those numbers were
stamped is invisible to them: there is no version they can name to say "I have
the one where pre-flight stops on a missing git" or "I have the one where the
context guard costs three processes instead of four". After this feature, both
plugins carry a version that includes that work, and the three places that
record a version agree with each other.

**Why this priority**: This is the whole feature. Nothing else in it delivers
value on its own.

**Independent Test**: Run `scripts/check-versions.sh` from the repository root.
It prints one line per plugin naming the manifest, marketplace and changelog
version it read, and exits non-zero if any pair disagrees. Then read the two
version lines back and confirm they are the intended new numbers rather than
merely equal to each other.

**Acceptance Scenarios**:

1. **Given** the tree at the start of this feature, **When**
   `jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json`
   runs, **Then** it prints `handoff 2.1.0` and `pipeline 1.1.0`.
2. **Given** the tree at the end of this feature, **When** the same command
   runs, **Then** it prints `handoff 2.1.1` and `pipeline 1.2.0`.
3. **Given** the tree at the end of this feature, **When**
   `bash scripts/check-versions.sh` runs from the repository root, **Then** it
   exits 0 and prints `pipeline: plugin=1.2.0 marketplace=1.2.0 changelog=1.2.0`
   and `handoff: plugin=2.1.1 marketplace=2.1.1 changelog=2.1.1`.

---

### User Story 2 - A reader can tell which release contains a change (Priority: P2)

Someone reads `handoff/CHANGELOG.md` wanting to know whether their installed
copy has the three measured guard corrections. Today those entries sit under
`## [Unreleased]`, which answers "not in any release" — and that answer has been
wrong for a full release cycle, because the entries beneath it describe work
that merged and shipped in fact if not in name.

**Why this priority**: The changelog is the only document that maps a change to
a version. An open heading breaks that map silently.

**Independent Test**: `grep -c '^## \[Unreleased\]' pipeline/CHANGELOG.md
handoff/CHANGELOG.md` returns 0 for both files, and the content that was beneath
each heading is byte-identical to what it was before.

**Acceptance Scenarios**:

1. **Given** both changelogs after this feature, **When** the `Unreleased`
   heading is searched for, **Then** neither file contains one.
2. **Given** either changelog after this feature, **When** the first heading in
   the file is read, **Then** it matches `^## \[[0-9]+\.[0-9]+\.[0-9]+\] -
   [0-9]{4}-[0-9]{2}-[0-9]{2}$` exactly, trailing anchor included.
3. **Given** either changelog, **When** everything below the changed heading
   line is compared against the same range before the change, **Then** the two
   are byte-identical.

---

### User Story 3 - The release can be tagged (Priority: P3)

After the merge, the owner pushes `pipeline-v1.2.0` and `handoff-v2.1.1`. CI's
tag gate resolves the plugin directory from the tag and compares the tag's
version against that directory's manifest.

**Why this priority**: It happens after this feature's pull request merges, so
it cannot be completed inside the feature — but the feature is what makes it
pass, and stamping a version the tag gate would reject is a defect this feature
owns.

**Independent Test**: For each intended tag, strip the `-v` suffix, read
`<plugin>/.claude-plugin/plugin.json`, and confirm the two halves match — the
same three lines the workflow runs.

**Acceptance Scenarios**:

1. **Given** the tag `pipeline-v1.2.0`, **When** its version half is compared
   with `pipeline/.claude-plugin/plugin.json`, **Then** they are equal.
2. **Given** the tag `handoff-v2.1.1`, **When** its version half is compared
   with `handoff/.claude-plugin/plugin.json`, **Then** they are equal.

---

### Edge Cases

- **The agreement gate is blind to a dangling `## [Unreleased]` heading, and
  that is why one survived a release cycle.** `scripts/check-versions.sh` reads
  the changelog with `grep -m1` against a pattern anchored to
  `## [X.Y.Z] - YYYY-MM-DD`. An `## [Unreleased]` heading does not match that
  pattern, so it is skipped and the FIRST MATCHING heading is read — today
  `## [1.1.0] - 2026-08-24`, which agrees with the 1.1.0 manifest. The gate is
  therefore green on exactly the state this feature exists to fix. Two
  consequences: this feature cannot use a green agreement gate as evidence that
  the heading was folded, and the absence of any check for a dangling heading is
  a real gap. **The gap is recorded, not closed here** — closing it means adding
  a test, and this feature's constraint is six version strings and two headings,
  nothing else.
- **`grep -m1` reads the first MATCHING heading, not the first heading.** If a
  new heading is written in a format the pattern rejects, the gate silently
  reads an older release's version and reports a version disagreement rather
  than a format complaint. A wrong diagnostic on a correct-looking file is worse
  than a red, so the heading format is verified directly rather than inferred
  from the gate passing.
- **The date is the release date, not a placeholder.** `<today>` in the seed
  resolves to 2026-09-03. Both headings carry the same date because both are
  stamped in the same act.
- **The two plugins take different bumps for different reasons**, and the two
  must not be reasoned about as one. See FR-013 and FR-014.
- **A tag pushed before the merge lands would name a version that is not on
  `main`.** Tagging is explicitly after the merge and outside this feature.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `pipeline/.claude-plugin/plugin.json`'s `version` MUST become
  `1.2.0`.
- **FR-002**: The marketplace entry whose `name` is `pipeline` in
  `.claude-plugin/marketplace.json` MUST have its `version` become `1.2.0`.
  Selection MUST be by name, never by array position.
- **FR-003**: `pipeline/CHANGELOG.md`'s `## [Unreleased]` heading MUST become
  `## [1.2.0] - 2026-09-03`.
- **FR-004**: `handoff/.claude-plugin/plugin.json`'s `version` MUST become
  `2.1.1`.
- **FR-005**: The marketplace entry whose `name` is `handoff` MUST have its
  `version` become `2.1.1`. Selection MUST be by name.
- **FR-006**: `handoff/CHANGELOG.md`'s `## [Unreleased]` heading MUST become
  `## [2.1.1] - 2026-09-03`.
- **FR-007**: The content beneath each changed heading MUST be byte-identical
  before and after. Nothing is added, removed or reordered. This MUST be
  demonstrated by comparison, not asserted.
- **FR-008**: Neither changelog may contain a `## [Unreleased]` heading when
  this feature ends.
- **FR-009**: Each new heading MUST satisfy
  `^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$`, including the
  trailing anchor, because that is the pattern the agreement gate parses.
- **FR-010**: Exactly five files may change: the two manifests, the marketplace
  manifest, and the two changelogs. Any other changed path is a defect of this
  feature, not a bonus. This count is measured, not assumed — see Clarifications:
  the root `CHANGELOG.md` holds no version number, and no tracked file outside
  those five records a current plugin version. The two remaining matches for the
  outgoing versions are historical comments and MUST be left alone.
- **FR-011**: `bash scripts/check-versions.sh`, run from the repository root,
  MUST exit 0 and MUST print the two new version triples. Because of the
  blindness recorded in Edge Cases, a passing run is necessary and NOT
  sufficient; FR-008 is verified independently.
- **FR-012**: The full house suite MUST report `1..163`, 163 ok, 0 not ok, 0
  non-TAP. The command is named here rather than referred to, because a
  requirement that points at a command elsewhere is not testable on its own, and
  because naming only the root `tests` directory silently skips both plugins'
  suites and still reports green:

  ```bash
  bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
  ```

  It MUST be run from the repository root. A suite can pass in a worktree and
  fail at the root; the root is the verdict.
- **FR-013**: The pipeline bump MUST be **minor**. Measured on 2026-09-03: its
  `## [Unreleased]` section carries an `### Added` heading — pre-flight now
  probes `git`, reports it beside `jq`, `gh` and `adb`, and stops the run when it
  is absent. A new key in the pre-flight report and a new stop are added
  capability, and added capability is a minor bump.
- **FR-014**: The handoff bump MUST be **patch**. Measured on the same date: its
  `## [Unreleased]` section carries `### Changed` and no `### Added` heading at
  all. The reason is NOT that nothing moved — the guard now answers differently
  on three measured transcript shapes — but that all three are corrections to
  pre-existing faults in the old code, and the differential ASSERTS each
  divergence rather than hiding it. Corrections are fixes; fixes with nothing
  Added are a patch.

  The wording **"an internal refactor with identical behaviour" MUST NOT be used
  to justify this bump.** It predates Phase 17 and is false. That phrase appears
  in NEITHER changelog — verified by search on 2026-09-03 — so this requirement
  creates no pressure to edit content that FR-007 freezes. It lived in the plan
  seed alone and was corrected there before this feature began. This requirement
  binds the reasoning recorded in THIS specification, in the run's artefacts, and
  in the commit and pull-request text — none of which is one of the five files
  FR-010 permits to change.
- **FR-015**: No tag is created or pushed by this feature. Tagging follows the
  merge and belongs to the owner.

### Key Entities

- **Plugin manifest** — `<plugin>/.claude-plugin/plugin.json`. Holds `name` and
  `version`. The tag gate resolves it from the directory name, so the manifest's
  `name` and its directory must stay equal; this feature changes neither.
- **Marketplace manifest** — `.claude-plugin/marketplace.json`. Holds one entry
  per plugin, each with `name`, `version` and `source`. `source` is the field an
  installer follows; this feature changes only `version`.
- **Changelog** — `<plugin>/CHANGELOG.md`. Its first heading matching the pinned
  pattern is the version the agreement gate reads.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A person reading either changelog can name the version that
  contains any entry in it. Measured as: zero `## [Unreleased]` headings across
  both files.
- **SC-002**: The three records of a version agree for both plugins. Measured as:
  `scripts/check-versions.sh` exits 0 and prints two triples, each with three
  equal values.
- **SC-003**: The published version numbers are the intended ones, not merely
  self-consistent. Measured as: the marketplace listing prints exactly
  `handoff 2.1.1` and `pipeline 1.2.0`.
- **SC-004**: The release publishes no unintended change. Measured as: the diff
  against the merge base, **excluding `.specify/`**, touches exactly five files,
  and the changelog diffs touch exactly one line each.

  The exclusion is stated in the criterion rather than left to prose, because
  deep review measured that it was unsatisfiable as originally worded. The
  constitution written earlier in this run lives under `.specify/` and rides
  this branch, so an unqualified diff against the merge base reports **six**
  files in every state — before the constitution is committed and after. A
  success criterion that can never be met is not a criterion. The pathspec
  `':(exclude).specify'` encodes the boundary the plan previously only narrated.
- **SC-005**: Nothing regressed. Measured as: the full house suite reports
  `1..163`, 0 not ok, and CI is green on all three operating systems.

## Assumptions

- **The release date is 2026-09-03**, the day this feature runs. Both headings
  carry it.
- **The content beneath both headings is already complete and correct.** The
  seed says so, and it was made true earlier today: commits `10ad24a` and
  `c2259d5` corrected four stale claims under handoff's `## [Unreleased]`
  heading — it said two asserted divergences where the harness asserts three,
  and named fifteen of sixteen transcript shapes. That correction had to precede
  this feature, because FR-007 forbids editing the content once it is stamped.
- **Phase 17 is merged**, which the seed required. `main` is at `c2259d5`, with
  Phase 17 at `90615c3` beneath it, CI green.
- **`releaseCommand` is unset for this repository**, so the pipeline's release
  gate has no command to run. Publishing here means merging the pull request and
  pushing two tags, both of which are the owner's acts, after this feature.
- **The dangling-heading gap is left open by an answered decision, not by
  oversight.** No test currently catches a `## [Unreleased]` heading surviving a
  release. The question was put to the owner at the clarify gate on 2026-09-03
  and the answer was to keep the seed's scope: five files, nothing else. Adding
  the test remains correct and remains unscheduled. It is recorded here, in the
  Clarifications section, and in `contracts/version-agreement.md` clause C4, so
  the next planning pass inherits it rather than rediscovering it. **An earlier
  draft of this bullet also claimed the project constitution recorded it. That
  was false** — the constitution discusses derived coverage at length under
  Principle V and never mentions this gap — and the claim was removed at deep
  review rather than made true, because FR-010 forbids this feature editing a
  sixth file.

- **The gap is wider than C4 alone describes**, and the deep review measured how
  much wider. Reverting all five files to the merge base — the release entirely
  undone, both `## [Unreleased]` headings back — leaves the full suite green at
  163 ok, 0 not ok. Nothing in the repository can distinguish a released tree
  from an unreleased one. C4 says a dangling heading is undetected; the truer
  statement is that the release itself is undetectable. Recorded, not fixed: the
  clarify-gate answer stands.
