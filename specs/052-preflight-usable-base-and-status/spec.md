# Feature Specification: Pre-flight checks the base it resolved, and reads the whole tree

**Feature Branch**: `052-preflight-usable-base-and-status`

**Created**: 2026-11-03

**Status**: Draft

**Input**: Seed kept verbatim in the run directory as `seed.md`: GitHub issue #107, "preflight: a base branch from the repository is not checked to be usable, and git status can pass a tree it did not examine".

## Context

`pipeline/scripts/preflight.sh` prints one JSON report. Feature 051 made it
stop when the current checkout gives no base branch, and gave every base
name read from the repository the override's name check (051, FR-010). The
phase I review of 051 found five older gaps. Each predates 051.

Measured 2026-11-03, git 2.53.0, against `main` at `4d0b5cd`, with no
global or system git configuration:

| # | Case | Report today |
|---|---|---|
| 1a | no commit yet, `--base-branch main` | exit 0, `baseBranch: "main"`, source `configured` |
| 1b | `--base-branch main`, only branch is `trunk` | exit 0, `baseBranch: "main"` |
| 1c | `--base-branch main`, `main` is only a tag | exit 0, `baseBranch: "main"` |
| 1d | `--base-branch main`, `main` is a branch and a tag | exit 0, `baseBranch: "main"` |
| 1e | `origin/HEAD` → `main`, local `main` deleted | exit 0, `baseBranch: "main"`, source `origin/HEAD` |
| 1f | `origin/HEAD` → `main`, `main` also a tag | exit 0, `baseBranch: "main"` |
| 4a | `HEAD` → `refs/tags/v1`, no `origin` | exit 0, `baseBranch: "v1"`, source `current branch` |
| 4b | `HEAD` → `refs/remotes/origin/main`, no `origin` | exit 0, `baseBranch: "origin/main"` |
| 5a | current branch `main`, tag `main` too | exit 0, `baseBranch: "heads/main"` |
| 2a | a mode-000 folder holding new work | exit 0, `tree.dirty: false` |
| 2b | `status.showUntrackedFiles=no`, one untracked file | exit 0, `tree.dirty: false` |
| 2c | a tracked file marked `skip-worktree`, then changed | exit 0, `tree.dirty: false` |
| 2d | a tracked file marked `assume-unchanged`, then changed | exit 0, `tree.dirty: false` |
| 3a | `core.fsmonitor` names a program | the program ran |
| 3b | `core.hooksPath` holds `post-index-change` | the hook ran |
| 3c | `filter.x.clean` names a program | the program ran |

In each of cases 1a to 1f, 4a and 4b, phase B's `git checkout -b <feature>
<base>` fails or cuts from the wrong thing, and `<base>..HEAD` reads the
wrong commits or none. The override path already refuses 1a to 1d (it
checks `refs/heads/<name>` and refuses a name that is a tag too); the
other sources get only the name check.

Candidate hardening, measured the same day:

- `git status --porcelain --untracked-files=normal` lists the untracked
  file of 2b. It does not change 2a, 2c or 2d: git still exits 0 and
  prints nothing for them. In 2a git writes a warning to stderr.
- `git ls-files -v` tags a `skip-worktree` file `S` and an
  `assume-unchanged` file with a lowercase letter. A sparse checkout
  marks every file outside its cone `S` on a clean tree, so `S` alone is
  not a sign of hidden work.
- `-c core.fsmonitor=false -c core.hooksPath=<empty folder>` stops 3a and
  3b. It does not stop 3c: a clean or process filter still runs. With a
  `filter.x.process` program that fails, `git status` exits 128.
- Every later phase of the run (B, H, K, L) runs ordinary `git status`,
  `git add` and `git commit` in the same repository, with the same
  configuration, and runs the project's hooks on purpose. Hardening
  pre-flight alone does not stop those programs from running later in
  the same run.

## Clarifications

### Session 2026-11-03

- Q: Should pre-flight stop when the base branch it found cannot be used (items 1, 4 and 5)? → A: Stop for all: one check after the base is found, for every source, the rule the override already has (FR-001 to FR-004).
- Q: Which hidden work should pre-flight's clean-tree check catch (item 2)? → A: Flag + assume-unchanged: add `--untracked-files=normal`, and count an `assume-unchanged` file as dirty; leave `skip-worktree` and the folder with no read rights as documented limits (FR-006).
- Q: Should pre-flight's own `git status` turn off programs the repository names (item 3)? → A: Document the limit only: change no git call; say that pre-flight and the run trust the repository's own configuration, as git does for a repository the user owns (FR-007).
- Q: Should this run also release the change as pipeline 1.7.6? → A: Yes, release 1.7.6 as the run's last piece (FR-012).
- Q: Should the status read also pass `--ignore-submodules=none`, as the issue proposed? → A: Yes, add it: a changed submodule counts as dirty whatever the repository's configuration says (FR-006).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pre-flight stops when the resolved base cannot be branched from (Priority: P1)

An owner starts a run. The base branch comes from `origin/HEAD`, the
`baseBranch` key or the current checkout, and it names no local branch
with a commit, or names one that is also a tag. Today the report names it
as the base, and phase B fails or branches from the wrong place. After
this feature, pre-flight stops, names the source and the reason, and says
what to do.

**Why this priority**: It is item 1 of the issue, and the one the issue
proposes a single fix for. Phase B and every `<base>..HEAD` read depend
on it.

**Independent Test**: In each fixture 1a to 1f of the Context table, run
`preflight.sh`. It exits non-zero, prints no report, and its message
names the base, its source and the reason.

**Acceptance Scenarios**:

1. **Given** a base from `origin/HEAD` or the key that is not a local
   branch, **When** pre-flight runs, **Then** it stops; where
   `origin/<base>` exists, the message names the command that creates
   the local branch, as the override's refusal does.
2. **Given** a base from any source that is a local branch and a tag too,
   **When** pre-flight runs, **Then** it stops and says git would read
   the tag.
3. **Given** a repository with no commit and a base from the key or a
   flag, **When** pre-flight runs, **Then** it stops and says the base
   has no commit.
4. **Given** a base that is a local branch with a commit and no tag of
   that name, from any source, **When** pre-flight runs, **Then** the
   report is as today.

---

### User Story 2 - The current checkout gives a branch name or a stop (Priority: P1)

An owner starts a run whose base comes from the current checkout, and
`HEAD` names a ref outside `refs/heads/` (a tag or a remote-tracking
branch), or names a branch that is a tag too. Today the report says the
base is `v1`, `origin/main` or `heads/main`. After this feature,
pre-flight stops and says why.

**Why this priority**: Items 4 and 5 of the issue. They are the same
fault as story 1 in the current-checkout source.

**Independent Test**: In fixtures 4a, 4b and 5a, run `preflight.sh` with
no base flag. It exits non-zero, prints no report, and names the case.

**Acceptance Scenarios**:

1. **Given** `HEAD` names a ref outside `refs/heads/`, **When** pre-flight
   runs with no other base, **Then** it stops and says the current
   checkout is not a local branch.
2. **Given** the current branch is a tag too, **When** pre-flight runs
   with no other base, **Then** it stops as story 1, scenario 2 does,
   and never reports `heads/<name>`.

---

### User Story 3 - A tree with work git status did not show is not reported clean (Priority: P2)

An owner starts a run in a repository where some work is hidden from
`git status`. Today the report says the tree is clean, and decision 5
lets the run go on.

**Why this priority**: Item 2 of the issue. It changes what a clean tree
means; the owner chose its reach (Clarifications).

**Independent Test**: In fixtures 2b and 2d, run `preflight.sh`: each
gives `tree.dirty: true`. In fixtures 2a, 2c and a clean sparse
checkout, it gives `tree.dirty: false`, and the documentation names 2a
and 2c as known limits.

**Acceptance Scenarios**:

1. **Given** `status.showUntrackedFiles=no` and an untracked file,
   **When** pre-flight runs, **Then** `tree.dirty` is `true`.
2. **Given** a tracked file with the `assume-unchanged` bit, changed or
   not, **When** pre-flight runs, **Then** `tree.dirty` is `true`.
3. **Given** a clean sparse checkout, **When** pre-flight runs, **Then**
   `tree.dirty` is `false`.
4. **Given** a submodule with a new commit checked out and
   `submodule.<name>.ignore=all` in the repository's configuration,
   **When** pre-flight runs, **Then** `tree.dirty` is `true`.

---

### User Story 4 - The documentation says which repository programs run (Priority: P3)

An owner opens a repository whose configuration names programs. Item 3
of the issue asked whether pre-flight's own status read should refuse to
run them. The owner chose to document the limit and change no git call
(Clarifications): the run's later phases run the same programs anyway.

**Why this priority**: Item 3. The gain of hardening one read is bounded.

**Independent Test**: A prose test finds the sentence in
`pipeline/docs/configuration.md` that says pre-flight and the run run
the programs the repository's own configuration names.

**Acceptance Scenarios**:

1. **Given** the shipped documentation, **When** the prose suite runs,
   **Then** it finds the item-3 sentence, and a mutant that deletes it
   goes red.

---

### User Story 5 - Nothing changes in a normal repository, and the rules cannot be deleted silently (Priority: P1)

An owner runs pre-flight in a normal repository: the base is a local
branch with a commit, no tag shares its name, and `git status` shows
everything. Every field reads as it does today. A later change that
removes a new check, or the documentation of it, turns a test red.

**Why this priority**: Every real run takes this path; Principle III.

**Independent Test**: The full suite passes. Each new check, reverted
alone, turns at least one test red.

**Acceptance Scenarios**:

1. **Given** a normal repository, **When** pre-flight runs, **Then** every
   key holds the value and type it holds today, and `notRead` is `[]`.
2. **Given** one new check removed, **When** the suite runs, **Then** a
   test fails and names the case.

### Edge Cases

- **A fresh clone made with `--branch dev`.** `origin/HEAD` names `main`
  and there is no local `main`. Pre-flight now stops and prints `git
  branch --track main origin/main`, where today phase B fails.
- **An override.** It is already checked for 1a to 1d. The new check must
  not refuse an override the old check accepts, and must not print a
  second, different message for one it refuses.
- **git not usable.** Nothing is checked, as today: the base fields are
  in `notRead`, and decision 11 stops the run first.
- **A base name that fails the name check.** The name check runs first
  and its message stands; a name it refuses is never looked up.
- **A sparse checkout.** Files outside the cone are `skip-worktree` on a
  clean tree. A rule for case 2c must not stop every sparse checkout.
- **Windows.** A stderr warning (for example a line-ending warning) is
  ordinary there; git's text is never read, so no rule may rest on
  stderr being empty.
- **A commit-less orphan branch checked out, base from the key.** The
  key's base has a commit, so the report is as today; the current
  checkout is not the base.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: With a usable git, after the base is resolved from any
  source, pre-flight MUST stop unless `refs/heads/<base>` exists and
  names a commit. Where `refs/remotes/origin/<base>` exists, the message
  MUST name the command that creates the local branch (`git branch
  --track <base> origin/<base>`), as the override's refusal does today.
- **FR-002**: With a usable git, pre-flight MUST stop when
  `refs/tags/<base>` exists, whatever the base's source, saying git would
  read the tag.
- **FR-003**: Each FR-001 and FR-002 message MUST name the base's source:
  `origin/HEAD`, the `baseBranch` key, the current branch, or the
  override (whose existing messages stand unchanged, FR-011). It MUST
  print the base only through the masking copy every refusal uses: cut
  at 200 bytes, each byte that is not printable ASCII shown as `?`.
- **FR-004**: With a usable git and the base from the current checkout,
  pre-flight MUST read the full name `HEAD` points to, and MUST stop
  when it lies outside `refs/heads/`, saying the current checkout is not
  a local branch and naming the fix (check out a branch, or pass a base
  branch). It MUST NOT report `heads/<name>` as a base.
- **FR-005**: The order of checks MUST keep each existing refusal: the
  detached, unreadable and no-commit stops of 051 and the name check run
  before FR-001 and FR-002, and their messages are unchanged.
- **FR-006**: The status read MUST pass `--untracked-files=normal` and
  `--ignore-submodules=none` on its command line, so the repository's
  `status.showUntrackedFiles`, `diff.ignoreSubmodules` and
  `submodule.<name>.ignore` cannot hide an untracked file or a changed
  submodule. With a usable git, `tree.dirty` MUST also be
  `true` when any tracked file carries the `assume-unchanged` bit (a
  lowercase tag in `git ls-files -v`): git does not look at such a file,
  so pre-flight cannot tell it is clean. A failure of that read MUST stop
  pre-flight as a failed status read does (051, FR-002a). A
  `skip-worktree` file (2c) and a folder git cannot open (2a) MUST NOT
  change `tree.dirty`; FR-009 documents both as known limits. A sparse
  checkout's clean tree reports `tree.dirty: false`, as today.
- **FR-007**: Pre-flight's git calls MUST NOT change for item 3: no
  `-c core.fsmonitor`, no `-c core.hooksPath`, no filter override. The
  documentation (FR-009) MUST say that pre-flight's status read, like
  every later phase of the run, runs the programs the repository's own
  configuration names (fsmonitor, hooks, filters), as git does in a
  repository the user owns, and that git's ownership check is the guard
  against one the user does not own.
- **FR-008**: No new message MAY print git's own error text, a path
  outside the repository, or a value from the repository's configuration
  other than the base name, masked.
- **FR-009**: `pipeline/docs/configuration.md`, "Base branch" and "Fields
  the report did not read", MUST say what the new checks refuse and what
  stays a known limit, and a prose test MUST pin each new sentence.
- **FR-010**: Every new assertion MUST be shown able to go red: each new
  test is run once against a mutant that removes what it guards, and the
  red is recorded.
- **FR-011**: When the base is a local branch with a commit and no tag
  shares its name, every key the report carries today MUST keep its value
  and type. The override's existing refusals MUST keep their messages,
  with one named exception (phase D): an override that names the current
  branch before its first commit now gets FR-001's "no commit yet"
  message instead of "is not a branch here or on origin", because one
  check serves every source (Principle IV).
  An existing test whose fixture names a base that FR-001 or FR-002 now
  refuses, and that expects a report, MUST be given a fixture that has
  that base, so it still tests what it tested; its assertions do not
  change.
- **FR-012**: This run MUST release the change as pipeline 1.7.6: a
  dated `## [1.7.6] - <date>` entry in `pipeline/CHANGELOG.md` that
  states what changed, the version in `pipeline/.claude-plugin/plugin.json`,
  and the pipeline entry's version in `.claude-plugin/marketplace.json`,
  with `scripts/check-versions.sh` passing. The release is its own piece,
  after the change, its tests and its documentation.

### Key Entities

- **A usable base**: a name for which `refs/heads/<name>` exists and
  names a commit, and `refs/tags/<name>` does not exist.
- **The base's source**: one of override, `origin/HEAD`, configured,
  current branch, as `baseBranchSource` reports it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Of the nine base cases in the Context table (1a to 1f, 4a,
  4b, 5a), pre-flight reports 0 as a base (9 of 9 today).
- **SC-002**: Cases 2b and 2d report `tree.dirty: true` (`false` today);
  2a, 2c and a clean sparse checkout report `false`; cases 3a to 3c
  behave as today, and the documentation says so.
- **SC-003**: The full suite passes, and every existing assertion on a
  normal repository is unchanged.
- **SC-004**: Each new check, when removed, turns at least one test red.

## Assumptions

- git 2.53.0 is the measured version; `git show-ref --verify`,
  `git symbolic-ref --quiet HEAD` and `--untracked-files=normal` behave
  the same on the git versions CI runs (Ubuntu, macOS, Windows).
- No consumer outside this repository reads the report.
- The repository a run works in is one the owner chose; git's own
  ownership check is the guard against a repository someone else owns.
