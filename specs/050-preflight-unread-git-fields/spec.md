# Feature Specification: The pre-flight report says which git fields it never read

**Feature Branch**: `050-preflight-unread-git-fields`

**Created**: 2026-11-02

**Status**: Draft

**Input**: Seed kept verbatim in the run directory as `seed.md`: GitHub issue #36, "preflight: the report still speaks confidently from git reads that never ran".

## Context

`pipeline/scripts/preflight.sh` prints one JSON report. When git cannot be
used here, four of its fields still read as established fact. Measured
2026-11-02 against this tree, for each reason feature 049 names:

| Field | Emitted, for `absent`, `broken`, `refused-ownership` and `no-repository` alike | What it asserts |
|---|---|---|
| `baseBranch` | `""` | no base branch |
| `baseBranchSource` | `"current branch"` | the current checkout was read |
| `remote.kind` | `"none"` | a remote was looked for and not found |
| `tree.dirty` | `false` | a tree was examined and is clean |

Each reason was produced for real: git off the search path, a git stub that
exits 1, `GIT_TEST_ASSUME_DIFFERENT_OWNER=1`, and a folder under
`GIT_CEILING_DIRECTORIES`. The first three ran in a repository with a GitHub
`origin` and an untracked file, so a read that ran would have said `github`
and `true`.

The `L` and `M` entries in `willSkip` follow from `remote.kind` and carry the
same false claim: "no git remote".

With a base branch given by an override, `baseBranch` and
`baseBranchSource` (`override`) are real; only the other fields are unread.
A base branch given by configuration is not: the resolution order is the
override, then `origin/HEAD`, then the configured base, so `configured`
claims that no `origin/HEAD` was published, and with git not usable nobody
looked (decided at phase I, Session 2026-11-02).

The issue predates feature 049 (`specs/049-preflight-git-usable/`). 049 added
`capabilities.gitUsable` (a boolean) and `gitReason` (why git cannot be used).
So the report already carries a flag that says git did not work. What it
does not carry is which fields that makes unread, and nothing in the report
or its documentation says that these four fields mean nothing when
`gitUsable` is false.

Today no consumer reads the JSON without first reading `gitUsable`:
pre-flight decision 11 fires first and stops the run, the probe block marks
the unread lines (`pipeline/docs/rare-paths.md`, "The probe block without
git"), and `pipeline:status` reads the state file, not this report. The
harm is to a future reader of the JSON, which the issue names.

The probe's stdout contract (`specs/013-preflight-git-probe/contracts/capabilities.md`,
restated in `specs/049-preflight-git-usable/contracts/`) says no existing key
changes its name, its type or its meaning. Feature 013 deferred this gap for
exactly that reason ("Known gaps, deferred with cause", third bullet).

## Clarifications

### Session 2026-11-02

- Q: How should the report say which fields were not read? → A: An additive marker list: one new key that names the unread fields; an empty list when git works; no existing key changes (FR-001).
- Q: Should this run also release the change as pipeline 1.7.4? → A: Yes, release 1.7.4 in this run (FR-010).
- Q (phase I review): `origin/HEAD` ranks above a configured base and is not read when git is not usable; should `notRead` name a configured base too? → A: Name it; only an override is exempt (FR-001a, FR-003).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A reader of the report can tell an unread field from a read one (Priority: P1)

A script or a person reads the pre-flight JSON in a place where git cannot
be used. Today the report says the current branch was read, no remote
exists and the tree is clean. After this feature, the report itself says
which of those fields were never read, so the reader does not take them as
fact.

**Why this priority**: It is the issue. Principle I: a field that reports a
read that never ran is a silence.

**Independent Test**: Run `preflight.sh` for each unusable reason. Every
git-derived field is shown, by the report alone, as not read.

**Acceptance Scenarios**:

1. **Given** git is absent, **When** pre-flight runs, **Then** the report
   names `baseBranch`, `baseBranchSource`, `remote.kind`, `tree.dirty` and
   the `L` and `M` skip entries in its not-read list.
2. **Given** git is found but broken, refuses the repository for ownership,
   or opens no repository, **When** pre-flight runs, **Then** the report marks the
   same fields the same way.
3. **Given** git cannot be used and a base branch comes from an override,
   **When** pre-flight runs, **Then** `baseBranch` and `baseBranchSource`
   are reported as today, not marked, and the other fields are marked. A
   base branch from configuration is marked like one from git.

---

### User Story 2 - Nothing changes where git works (Priority: P1)

An owner runs pre-flight in a normal repository. Every field reads as it
does today.

**Why this priority**: Every real run takes this path.

**Independent Test**: Run the existing suite. Every existing test of a
usable git stays green with no edit to its assertions.

**Acceptance Scenarios**:

1. **Given** a usable git, **When** pre-flight runs, **Then** every field
   that exists today holds the value and type it holds today.

---

### User Story 3 - The rule cannot be deleted silently (Priority: P2)

A later change removes the marking, or the documentation that says what it
means. A test goes red.

**Why this priority**: Principle III. The display-layer fix from #33 is
already pinned; the new report-level rule needs the same.

**Independent Test**: Revert the marking in the script, then delete the
documentation sentence. Each mutation turns at least one test red.

**Acceptance Scenarios**:

1. **Given** the script no longer marks an unread field, **When** the suite
   runs, **Then** a test fails and names the field.
2. **Given** the documented meaning is deleted, **When** the suite runs,
   **Then** a prose test fails.

### Edge Cases

- **A base branch from an override.** It outranks `origin/HEAD`, so it is
  real without git, and it must not be marked as not read. It was also not
  checked against the repository; the probe block already says so. A base
  branch from configuration ranks below `origin/HEAD`, which was not read,
  so it is marked.
- **`ghPresent` and `ghCommand`.** They sit inside `remote` but come from
  looking for `gh`, not from git. They stay as they are.
- **`willSkip` entries `L` and `M`.** They are derived from `remote.kind`.
  When `remote.kind` is not read, these entries claim "no git remote". The
  not-read list names them; an `N.5` entry does not depend on git and is
  never named.
- **`runsLive`, `liveRuns`, `unreadableRuns`.** They come from reading
  `.delivery-kit/`, not from git. They stay as they are.
- **The git reads still run when git is unusable.** Feature 049 deferred
  removing them (its phase I, "the later git reads still run for an
  unusable git"). This feature does not change whether they run: they read
  nothing a refused repository could act on (049 measured that they are not
  lifted), and the list, not their absence, is what tells the reader.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The report MUST carry one new key, a list that names every
  git-derived field that holds a placeholder because git is not usable
  here. The list is empty when `capabilities.gitUsable` is `true`, and its
  type is a list in every case. A read that fails under a usable git (an
  unborn branch, a damaged index) is outside this list, as it was outside
  049's contract.
  It is additive: no existing key changes its name, its type or its
  meaning, so the 013 stdout contract still holds unchanged.
- **FR-001a**: When `capabilities.gitUsable` is `false`, the list MUST name
  `remote.kind`, `tree.dirty`, and each `willSkip` entry derived from
  `remote.kind`; and it MUST name `baseBranch` and `baseBranchSource` exactly
  when the base branch did not come from an override. It names nothing
  else.
- **FR-002**: When `capabilities.gitUsable` is `true`, every key the report
  carries today MUST keep its value and its type.
- **FR-003**: A base branch that came from an override MUST NOT be
  reported as unread; one that came from configuration MUST be.
- **FR-004**: `remote.ghPresent`, `remote.ghCommand`, every `capabilities`
  key, `gitReason` and `tree.runsLive`, `tree.liveRuns` and
  `tree.unreadableRuns` MUST NOT change for this feature.
- **FR-005**: The script MUST still exit 0 and print one complete JSON
  document for every git reason.
- **FR-006**: The new key and what it means MUST be documented in two
  places: the probe's contract in this feature's `contracts/` folder, and
  `pipeline/docs/configuration.md`, which ships with the plugin and is where
  a reader of the report finds it. The shipped sentence is pinned by a
  prose test (User Story 3).
- **FR-007**: Every new assertion MUST be shown able to go red: each new
  test is run once against a mutant that removes what it guards, and the
  red is recorded.
- **FR-008**: The deferred gap in `specs/013-preflight-git-probe/spec.md`
  ("Several reported fields still speak confidently…") MUST be marked
  closed by this feature, after the prose settles.
- **FR-009**: The probe block's not-read rules ("The probe block without
  git", `pipeline/docs/rare-paths.md`) MUST still mark only the unread
  lines. If they are changed to read the new list, the rules and their
  verbatim pin in `pipeline/tests/prose.bats` MUST be changed together.
- **FR-010**: This run MUST release the change as pipeline 1.7.4: a dated
  `## [1.7.4] - <date>` entry in `pipeline/CHANGELOG.md` that states what
  changed, the version in `pipeline/.claude-plugin/plugin.json`, and the
  pipeline entry's version in `.claude-plugin/marketplace.json`, with
  `scripts/check-versions.sh` passing. The release is its own piece, after
  the change and its tests.

### Key Entities

- **The pre-flight report**: the JSON document `preflight.sh` prints.
- **A git-derived field**: a field whose value comes from a git read:
  `baseBranch` and `baseBranchSource` when their source is not
  `override`, `remote.kind`, `tree.dirty`, and the `willSkip`
  entries derived from `remote.kind`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For each of the four unusable reasons, a reader using only the
  report can tell every git-derived field is unread, without consulting any
  other file.
- **SC-002**: With a usable git, the report is identical to today's for the
  same repository and flags, apart from the one new key, which is an empty
  list.
- **SC-003**: Every existing test of a usable git passes without an edit to
  its assertions.
- **SC-004**: Each new guard turns red under its mutant, and each red is
  recorded in this feature's `measurements.md`.

## Assumptions

- The four unusable reasons are the ones 049 defines: `absent`, `broken`,
  `refused-ownership`, `no-repository`.
- No consumer outside this repository reads the report. The plugin is the
  only caller, and its orchestrator reads `gitUsable` first.
