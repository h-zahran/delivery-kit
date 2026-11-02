# Feature Specification: Pre-flight stops stating a failed git read as fact

**Feature Branch**: `051-preflight-failed-git-reads`

**Created**: 2026-11-02

**Status**: Draft

**Input**: Seed kept verbatim in the run directory as `seed.md`: GitHub issue #106, "preflight: two git reads that fail under a usable git are still reported as fact".

## Context

`pipeline/scripts/preflight.sh` prints one JSON report. Feature 050 added
`notRead`, which names each field that holds a placeholder because git is
not usable here. With a **usable** git, `notRead` is `[]` by construction,
yet two of the script's git reads can still fail, and the report states
their output as fact.

Measured again 2026-11-02, git 2.53.0, against `main` at `68dc597`:

| Case | Read | Exit | Report says | `notRead` |
|---|---|---|---|---|
| `git init`, no commit yet, no base flag, no `origin` | `git rev-parse --abbrev-ref HEAD` | 128, prints `HEAD` | `baseBranch: "HEAD"`, `baseBranchSource: "current branch"` | `[]` |
| one commit, one untracked file, `.git/index` overwritten with garbage | `git status --porcelain` | 128, prints nothing | `tree.dirty: false` | `[]` |
| one commit, `HEAD` detached, no base flag, no `origin` | `git rev-parse --abbrev-ref HEAD` | 0, prints `HEAD` | `baseBranch: "HEAD"`, `baseBranchSource: "current branch"` | `[]` |

Both reads end in `2>/dev/null || true` inside `$( )`. In the first case the
command prints `HEAD` and then fails, and the output is kept. In the second
the failure leaves the output empty, which reads as a clean tree. In the
same unborn repository `git symbolic-ref --short HEAD` exits 0 and prints
the branch name (`master` under git's default), and with a detached `HEAD`
it exits 1, so it tells all three states apart where the current read
cannot: the detached case exits 0, and an exit check alone would miss it.
Naming the unborn branch does not rescue the run: in that repository
`git checkout -b feat master` exits 128 ("'master' is not a commit"), so
phase B cannot cut a branch from it.

Consequences today:

- The probe block prints `Base branch : HEAD (from current branch)` as
  fact, and phase B would cut the feature branch from `HEAD`.
- Pre-flight decision 5 (dirty tree) passes a tree nobody examined.

The other git reads in the report are not in scope. `git remote get-url
origin` exits non-zero for a repository with no `origin`, and that is a
real answer (`remote.kind: "none"`), not a failed read. `git symbolic-ref
--quiet --short refs/remotes/origin/HEAD` failing means no `origin/HEAD`
is published, which the resolution order already treats as an answer.

## Clarifications

### Session 2026-11-02

- Q: When pre-flight cannot read the base branch or the tree status under a usable git, what should it do? → A: Stop, naming the read: no commit yet, a detached `HEAD`, or a status read that failed; `notRead` stays as feature 050 made it (FR-001 to FR-003).
- Q: Should this run also release the change as pipeline 1.7.5? → A: Yes, release 1.7.5 in this run (FR-009).
- Q (phase I review): a base branch name read from the repository is never checked before B types it into commands; how far should this run go? → A: Check every source: `origin/HEAD`, the `baseBranch` key and the current branch get the override's check (FR-010). Whether such a base exists with a commit is left to a follow-up issue.
- Phase I review: "pass a base branch" fixes a branch with no commit only when another branch has a commit (an orphan branch in a repository with history); in a repository with no commit an override is refused, since it must already be a local branch. So that stop asks for a first commit, or a base branch that has one (FR-001). A `HEAD` naming a branch git cannot read is not a detached `HEAD`, and stops with its own message (FR-002).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pre-flight stops when the current checkout gives no base branch (Priority: P1)

An owner starts a run where the base branch must come from the current
checkout (no override, no published `origin/HEAD`, no configured base), and
that checkout has no commit yet or is a detached `HEAD`. Today the report
says the base branch is `HEAD`. After this feature, pre-flight stops,
names the reason, and says what to do.

**Why this priority**: It is the first half of the issue. Phase B cuts the
feature branch from this value, and in both states it cannot.

**Independent Test**: In a fresh `git init` folder, and again in a
repository with a detached `HEAD`, run `preflight.sh` with no base flag.
It exits non-zero, prints no report, and its message names the case.

**Acceptance Scenarios**:

1. **Given** a repository with no commit yet, no `origin` and no base flag,
   **When** pre-flight runs, **Then** it stops, and its message says the
   branch has no commit yet and names the fix: make a first commit, or
   pass a base branch that has one.
2. **Given** a detached `HEAD` with no `origin` and no base flag, **When**
   pre-flight runs, **Then** it stops, and its message says `HEAD` is
   detached and names the fix (check out a branch, or pass a base branch).
3. **Given** a repository with a commit on a named branch and no `origin`,
   **When** pre-flight runs, **Then** `baseBranch` is that branch's name
   and `baseBranchSource` is `current branch`, as today.

---

### User Story 2 - A tree whose status cannot be read is not reported clean (Priority: P1)

An owner starts a run in a repository whose index is damaged. Today the
report says the tree is clean, and decision 5 lets the run go on. After
this feature, pre-flight stops and says the working tree could not be read.

**Why this priority**: It is the second half of the issue. Decision 5 is
the guard against committing over someone's work.

**Independent Test**: In a repository with one commit, one untracked file
and `.git/index` overwritten with garbage, run `preflight.sh`. It exits
non-zero, prints no report, and its message says the tree's status could
not be read.

**Acceptance Scenarios**:

1. **Given** a usable git and a status read that fails, **When** pre-flight
   runs, **Then** it stops, and its message says the working tree's status
   could not be read.
2. **Given** a usable git and a clean tree, **When** pre-flight runs,
   **Then** `tree.dirty` is `false`, as today; with an untracked file it is
   `true`, as today.

---

### User Story 3 - Nothing changes where every read succeeds (Priority: P1)

An owner runs pre-flight in a normal repository. Every field reads as it
does today.

**Why this priority**: Every real run takes this path.

**Independent Test**: Run the existing suite. Every existing test of a
usable git stays green with no edit to its assertions, except an assertion
that pins the old wording this feature replaces.

**Acceptance Scenarios**:

1. **Given** a usable git and reads that succeed, **When** pre-flight runs,
   **Then** every field holds the value and type it holds today, and
   `notRead` is `[]`.

---

### User Story 4 - The rule cannot be deleted silently (Priority: P2)

A later change removes the new check, or the documentation that says what
it means. A test goes red.

**Why this priority**: Principle III.

**Independent Test**: Revert each new check in the script, then delete the
documentation sentence. Each mutation turns at least one test red.

**Acceptance Scenarios**:

1. **Given** the script no longer makes one of the three stops (no commit
   yet, detached `HEAD`, failed status read), **When** the suite runs,
   **Then** a test fails and names the case.
2. **Given** the documented meaning is deleted, **When** the suite runs,
   **Then** a prose test fails.

### Edge Cases

- **A missing `origin`.** `git remote get-url origin` failing is a real
  answer. It must not be treated as a failed read.
- **No published `origin/HEAD`.** The symbolic-ref read failing is a real
  answer: the resolution order moves on to the configured base.
- **An override, a published `origin/HEAD` or a configured base.** The
  current-checkout read does not run, so the base stop cannot fire; those
  values behave as today, even on an unborn or detached checkout. The
  status read still runs, and its stop still fires.
- **A repository with no commit yet but a base from a flag.** The status
  read succeeds there (exit 0), so pre-flight reports as today.
- **A detached `HEAD`.** There is no branch to name. Pre-flight stops
  rather than name `HEAD` as one.
- **The flag errors already stop pre-flight.** The new stops take the same
  shape: a message on stderr, a non-zero exit, no report on stdout.
- **An unusable git.** Feature 050's behaviour stands: the same fields are
  in `notRead`, and decision 11 stops the run first.
- **A damaged index with a usable git elsewhere.** `git rev-parse
  --git-dir` still succeeds, so `gitUsable` stays `true`; only the status
  read fails.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: With a usable git, when the base branch comes from the
  current checkout and that checkout is on a branch with no commit yet,
  pre-flight MUST stop: a message on stderr that says so and names the fix
  (make a first commit, or pass a base branch that has one), a non-zero
  exit, and no report on stdout. "Pass a base branch" means the run's `--base-branch`
  flag or the `baseBranch` configuration key, which reach the script as
  `--base-branch-override` and `--base-branch`.
- **FR-002**: With a usable git, when the base branch comes from the
  current checkout and `HEAD` is detached, pre-flight MUST stop the same
  way, with a message that says `HEAD` is detached and names the fix
  (check out a branch, or pass a base branch). The read that tells these
  states apart MUST NOT be an exit-status check of `git rev-parse
  --abbrev-ref HEAD`, which exits 0 on a detached `HEAD`. A `HEAD` that
  names a branch git cannot read MUST stop with its own message, not the
  detached one. (Phase I.)
- **FR-002a**: With a usable git, when the working tree's status read
  fails, pre-flight MUST stop the same way, with a message that says the
  working tree's status could not be read. It MUST NOT report
  `tree.dirty: false` for it.
- **FR-002b**: No message of the stops in FR-001, FR-002 and FR-002a MAY
  print git's own error text, a path outside the repository, or a value
  from the repository's configuration: it names the case and the fix. (The
  FR-010 stop prints the refused name as the override's refusal does: cut
  at 200 bytes, each byte that is not printable ASCII shown as `?`. The
  report printed that name in full before, so nothing is widened.)
- **FR-002c**: `notRead` MUST keep feature 050's contract unchanged: it is
  `[]` whenever `capabilities.gitUsable` is `true`.
- **FR-003**: A failed `git remote get-url origin` and a missing
  `origin/HEAD` MUST keep their meaning today: they are answers, not failed
  reads.
- **FR-004**: When every read succeeds, every key the report carries today
  MUST keep its value and its type.
- **FR-005**: `capabilities`, `gitReason`, `remote.ghPresent`,
  `remote.ghCommand`, `tree.runsLive`, `tree.liveRuns` and
  `tree.unreadableRuns` MUST NOT change for this feature.
- **FR-006**: The new stops MUST be documented in
  `pipeline/docs/configuration.md`, "Fields the report did not read", which
  today says the unborn case is outside `notRead` and reads `HEAD`; that
  sentence is replaced by one that says pre-flight stops instead, and the
  shipped sentence is pinned by a prose test.
- **FR-007**: Every new assertion MUST be shown able to go red: each new
  test is run once against a mutant that removes what it guards, and the
  red is recorded.
- **FR-008**: An existing test that runs pre-flight on a branch with no
  commit and no base flag, and expects a report, MUST be given a first
  commit, so it still tests what it tested; its assertions do not change.
- **FR-009**: This run MUST release the change as pipeline 1.7.5: a dated
  `## [1.7.5] - <date>` entry in `pipeline/CHANGELOG.md` that states what
  changed, the version in `pipeline/.claude-plugin/plugin.json`, and the
  pipeline entry's version in `.claude-plugin/marketplace.json`, with
  `scripts/check-versions.sh` passing. The release is its own piece, after
  the change and its tests.
- **FR-010**: With a usable git, a base branch from `origin/HEAD`, the
  `baseBranch` key or the current branch MUST pass the check an override
  passes (git's legal-name rule, the name printed back unchanged, and only
  letters, digits, `.`, `_`, `-` and `/`); a name that fails it MUST stop
  pre-flight, naming the source. With git not usable nothing is checked,
  as for an override. (Phase I.)

### Key Entities

- **A failed read**: a git read the script runs under a usable git that
  gives no real answer: the status read exiting non-zero, or the
  current-checkout read finding no commit or no branch.
- **`notRead`**: the report's list of fields holding a placeholder, from
  feature 050.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In all three measured cases of the Context table, pre-flight
  stops instead of stating the read's output as fact (0 of 3 reports, from
  3 of 3 today).
- **SC-002**: The full suite passes, and every existing assertion on a
  usable git with successful reads is unchanged.
- **SC-003**: Each new check, when removed, turns at least one test red.

## Assumptions

- git 2.53.0 is the measured version; the behaviour of `rev-parse
  --abbrev-ref HEAD` on an unborn branch (prints `HEAD`, exits 128) and of
  `symbolic-ref --short HEAD` (prints the name, exits 0) holds for the git
  versions CI runs.
- No consumer outside this repository reads the report.
