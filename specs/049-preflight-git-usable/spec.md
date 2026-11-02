# Feature Specification: Pre-flight asks whether git will work here, not only whether it can be found

**Feature Branch**: `049-preflight-git-usable`

**Created**: 2026-11-02

**Status**: Draft

**Input**: Seed kept verbatim in the run directory as `seed.md`: GitHub issue #35, "preflight: the git probe tests findability, not usability".

## Context

`pipeline/scripts/preflight.sh` reports `capabilities.git` from `command -v
git`. That answers "can git be found", not "will git work on this
repository". A git that is found but refuses this repository — most often
git's ownership check, `detected dubious ownership`, on a Windows checkout
made by another user, a shared or network checkout, or a container whose
checkout belongs to another UID — reports `capabilities.git: true`. Every
git read in the script then fails as it would with no git at all, each
failure is swallowed, and the report reads an empty base branch, a
`current branch` source that was never taken, a remote of `none` that was
never looked for, and a clean tree nothing examined. Pre-flight decision 11
never fires, and the run dies later, in phase B.

Feature 013 (`specs/013-preflight-git-probe/`) disclaimed this case on
purpose, in its spec's Edge Cases, in its contract's "What the probe does
NOT promise", and in `pipeline/CHANGELOG.md`. This feature closes it.

The probe's stdout contract (`specs/013-preflight-git-probe/contracts/capabilities.md`,
guarantee 3) says no existing key changes its name, type or MEANING; new
keys may be added. So `capabilities.git` keeps its meaning ("git can be
found") and a new key carries usability. This settles the issue's "one key
or two" question: two.

## Clarifications

### Session 2026-11-02

- Q: Should this run also release the fix as pipeline 1.7.3? → A: Yes, release 1.7.3 in this run (FR-014).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A git that refuses the repository stops the run at pre-flight (Priority: P1)

An owner runs `/pipeline` in a checkout that git refuses because of its
ownership check. Today pre-flight reports git as fine and the run fails in
phase B with a git error that names nothing pre-flight said. After this
feature, pre-flight reports that git was found but will not open this
repository, says why in plain words, prints the command that fixes it for
the owner to run, and the run stops before phase A.

**Why this priority**: It is the issue. It is the common cause, and it is
the silence Principle I forbids.

**Independent Test**: Run `preflight.sh` against a repository git refuses
for ownership. The report says git is found, says it is not usable, and
names the refusal. The script exits 0 with one complete JSON document.

**Acceptance Scenarios**:

1. **Given** a repository whose owner git does not trust, **When**
   pre-flight runs, **Then** `capabilities.git` is `true`, the new
   usability key is `false`, and the reason names the ownership refusal.
2. **Given** that report, **When** the orchestrator walks the decision list,
   **Then** decision 11 fires first, names the refusal, prints the
   `safe.directory` command for the owner to run, and runs nothing itself.
3. **Given** that report, **When** the probe block is rendered, **Then**
   every field that came from a git read that did not run or did not
   succeed is marked as not read, exactly as for an absent git.

---

### User Story 2 - git found, but no repository here (Priority: P2)

An owner runs pre-flight in a folder that is not inside any git
repository. git is installed and works, but there is no repository to
read. Today this reads the same as a clean repository with no remote.
After this feature the report says so, with its own reason, and decision 11
stops the run with a message that differs from the ownership one.

**Why this priority**: The issue names it as a *different* condition that
may deserve a different message. It is less common than the refusal,
because the run is normally started inside a repository.

**Independent Test**: Run `preflight.sh` against a folder outside any
repository. The usability key is `false` and the reason names no
repository.

**Acceptance Scenarios**:

1. **Given** a folder with no repository above it, **When** pre-flight runs,
   **Then** `capabilities.git` is `true`, the usability key is `false`, and
   the reason is the no-repository one, not the refusal.

---

### User Story 3 - Nothing changes where git works (Priority: P1)

An owner runs pre-flight in a normal repository. The report is identical to
today's, plus the new keys saying git is usable.

**Why this priority**: Every real run takes this path. A regression here
breaks every run.

**Independent Test**: Run the existing suite. Every existing test stays
green with no edit to its assertions on existing keys.

**Acceptance Scenarios**:

1. **Given** a normal repository, **When** pre-flight runs, **Then** every
   existing key holds the value it holds today, the usability key is
   `true`, and the reason is the usable one.

### Edge Cases

- **git absent.** `capabilities.git` is `false`, the usability key is
  `false`, and the reason is the absent one. Decision 11 keeps today's
  message and link.
- **git found but cannot run at all** (for example a broken binary or a
  stub that exits non-zero for every command). This is reported as its own
  reason, not as a refusal and not as a missing repository.
- **A refusal git gives for a reason other than ownership.** The probe
  cannot tell every cause apart. A repository git opens only when the
  ownership check is lifted is the ownership refusal; any other failure to
  open one is reported under the no-repository reason, whose wording says
  git found no repository it would open here — never claiming there is
  none.
- **git's messages are translated.** The probe must not read git's error
  text to classify a cause, because a non-English locale changes it.
- **Name checks that need a repository.** `--base-branch`, `--branch` and
  `--spec-dir` are checked against the repository today when git is found.
  With git found but unusable, those checks would fail for the unusable
  git and report a wrong cause (for example "exists only on origin" or
  "does not exist"), or exit non-zero before the report. They must instead
  behave as they do with git absent: the names are reported unchecked and
  the report is emitted.
- **Outside the repository, with `.specify/` present.** The spec tool's own
  probes do not need git; their fields stay as they are.
- **`capabilities.jq`** is hardcoded `true` because the report could not be
  written without jq. That is a third kind of claim; it is out of scope and
  unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The report MUST keep `capabilities.git` exactly as today: a
  boolean, `true` when git can be found on the search path, `false`
  otherwise. Its name, type and meaning do not change.
- **FR-002**: The report MUST add a boolean key, `capabilities.gitUsable`,
  `true` only when git can be found, can run, and opens a repository at the
  probed folder; `false` in every other case. It MUST be a JSON boolean,
  never a string.
- **FR-003**: The report MUST add a string key, `gitReason`, holding exactly
  one of: `usable`, `absent`, `broken` (found but cannot run),
  `refused-ownership` (opens a repository only when git's ownership check is
  lifted), `no-repository` (runs, but opens no repository here, for any
  other cause). `gitReason` is `usable` exactly when `capabilities.gitUsable`
  is `true`.
- **FR-004**: The classification MUST NOT read git's message text. It
  decides from exit codes alone.
- **FR-005**: The check for the ownership refusal MUST NOT change any git
  configuration, global or local. It lifts the check for its one command
  only, and that command MUST be one that runs no hook and no program the
  repository's own configuration names: the check exists to keep an
  untrusted repository's configuration from running code, and the probe
  must not reopen that door to classify it.
- **FR-006**: When `capabilities.gitUsable` is `false`, the script MUST NOT
  run the name checks that need a repository; it MUST report the names
  unchecked, exit 0, and emit one complete document — as it does today with
  git absent.
- **FR-007**: The script MUST still exit 0 and emit one complete JSON
  document on stdout for every `gitReason`. Reporting is not failing.
- **FR-008**: Pre-flight decision 11 in `pipeline/skills/pipeline/SKILL.md`
  MUST fire when `capabilities.gitUsable` is `false`, for every reason, and
  still fire first. Its wording MUST name each reason truly: the absent case
  keeps the download link; the ownership case prints the command
  `git config --global --add safe.directory <path>` for the owner to run and
  runs nothing; the broken and no-repository cases each say what was found
  and what to check. No case installs or configures anything.
- **FR-009**: The probe block rules in `pipeline/docs/rare-paths.md` ("The
  probe block without git", "The git stop") MUST apply to every case where
  `capabilities.gitUsable` is `false`, not only to git absent. A `git` line
  in the probe block MUST say which reason holds.
- **FR-010**: This feature MUST write its own contract,
  `specs/049-preflight-git-usable/contracts/capabilities.md`, stating the
  full current promise: the new keys, their types and values, and the limit
  that a non-ownership refusal reads as `no-repository`. 013's contract is a
  dated record and is not rewritten; it gains one line at the top pointing
  to the new contract, saying its "does not promise git works" section no
  longer holds.
- **FR-011**: `pipeline/tests/preflight.bats` MUST cover each `gitReason`
  value with a fixture that produces it for real — the ownership case with a
  repository git refuses, not a stripped search path — and each test MUST
  assert the boolean type of `gitUsable`, not only its value.
- **FR-012**: Each new test MUST be shown able to go red: a mutation of the
  classifying line must turn it red, and the run must say which mutation
  turned which test red (Principle III).
- **FR-013**: Any prose pin in `pipeline/tests/prose.bats` that holds decision
  11's wording MUST be updated to the new wording, and MUST still go red when
  the wording drifts.
- **FR-014**: This run MUST release the fix as pipeline 1.7.3: a dated
  `## [1.7.3] - <date>` entry in `pipeline/CHANGELOG.md` that states what
  changed and retires 013's disclaimer by a new entry (the old entry is
  history and is not edited), the version in
  `pipeline/.claude-plugin/plugin.json`, and the pipeline entry's version in
  `.claude-plugin/marketplace.json`, with `scripts/check-versions.sh`
  passing. The release is its own piece, after the fix and its tests.

### Key Entities

- **`capabilities.git`**: unchanged — git can be found.
- **`capabilities.gitUsable`**: new boolean — git can be found, runs, and
  opens a repository here.
- **`gitReason`**: new string — which of the five states holds.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For each of the five `gitReason` values, one fixture produces
  it, and the suite asserts the value and the boolean type — five of five.
- **SC-002**: On a repository git refuses for ownership, pre-flight exits 0
  and reports `capabilities.gitUsable` as the boolean `false` with
  `gitReason` `refused-ownership`; decision 11's text names `gitUsable` as its
  trigger, held by a prose pin (FR-013).
- **SC-003**: Every pre-existing test in the suite passes with no edit to an
  assertion on an existing key.
- **SC-004**: The full suite and the analyzer are green on Linux locally and
  on all three CI operating systems.
- **SC-005**: Each new test goes red under at least one recorded mutation of
  the probe.

## Assumptions

- The pre-flight script runs with the target repository as its folder
  (`--dir`, default the current folder), so "a repository here" means the
  repository that contains that folder.
- git's ownership check can be lifted for one command by passing
  `safe.directory=*` on that command's own line; git honours that setting
  from the command line (protected configuration). A git older than the
  ownership check never refuses, so it reads `usable` or `no-repository`.
- Windows, macOS and Linux CI can each build an ownership-refused fixture,
  or the fixture forces the refusal in a portable way; the plan measures
  which.
- The `safe.directory` command printed at decision 11 names the probed
  repository's path; it is shown on the owner's own screen only and is not
  written into any commit, pull request or state file.
