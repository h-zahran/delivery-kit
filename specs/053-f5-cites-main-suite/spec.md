# Feature Specification: F.5 cites a green suite result for main's commit

**Feature Branch**: `053-f5-cites-main-suite`

**Created**: 2026-11-03

**Status**: Draft

**Input**: GitHub issue #110 — "pipeline: F.5 reuses a green suite result for main's commit instead of running the full suite again". The issue text is kept verbatim in the run's `seed.md`.

## Background *(context for the requirements)*

Phase F.5 records the test baseline: the full `testCommand` result on the
files as they were before the feature. It may already cite a kept result
instead of running: `progress.sh suite-lookup <feature> --base` exits 0 for a
GREEN record whose key matches the base branch's files without the run's
untracked spec directory. Under the default `suiteReuse` mode `commit`, that
key covers the files' bytes and modes, HEAD's commit id, every tracked path's
index entry, the exact `testCommand`, the platform and the mode.

At F.5 the feature branch has no commit of its own yet, so HEAD is the base
branch's commit. A green record made on a clean checkout of that commit, with
the same command, platform and mode, has exactly the key `--base` looks up.
No such record exists today, because nothing runs the suite on the base
branch's commit after a pull request merges: the last full run of the
previous feature ran on its pull-request branch, and this repository merges
by rebase, which gives `main` new commit ids. So every run's F.5 runs the
suite from zero — about 9 minutes here (run 052: 929 tests, 07:10:37 to
07:19:35).

## Clarifications

### Session 2026-11-03

- Q: Who records the green test result for `main`'s new commit after a pull request merges? → A: The next run, in the background: a fresh run whose base commit has no green record starts the suite on that commit at pre-flight, in a separate clean checkout, and F.5 cites the result.
- Q: When F.5 starts and the background suite run is still going, what does F.5 do? → A: It waits, with a limit of about one full-suite time. If the limit passes, or the background run fails or ends red, F.5 runs the suite itself, as today.
- Q: Is the background run on by default, or behind a config key? → A: On by default whenever `suiteReuse` is `commit` or `files`; `suiteReuse: off` turns it off with every other reuse. One line says it started (printed in B, see FR-001).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The next run's F.5 cites main's result (Priority: P1)

The owner merges a pipeline pull request. A green full-suite result for the
merged `main` commit gets recorded where `suite-lookup --base` reads it. The
owner starts the next run; its F.5 cites that result, quoting its two lines
verbatim, instead of running the suite.

**Why this priority**: it is the whole value of the issue — the largest
single cost in a run that can be removed without dropping a check.

**Independent Test**: on a scratch repository, record a green result for a
clean checkout of the base commit by the feature's mechanism, then start a
run (spec directory untracked, HEAD at the base commit) and call
`suite-lookup <feature> --base`: it exits 0 and prints the record's path and
counts, naming the commit the record was made on.

**Acceptance Scenarios**:

1. **Given** a green record made by the feature's mechanism for `main`'s
   commit, **When** a new run's F.5 calls `suite-lookup --base` with the same
   `testCommand`, platform and `suiteReuse` mode, **Then** it exits 0 and F.5
   records the two printed lines as `test_baseline` without running the suite.
2. **Given** the same record, **When** F.5 cites it, **Then** the cited text
   names the record's commit, its command and its counts, and F.5 quotes it
   verbatim.

---

### User Story 2 - Nothing that should run is skipped (Priority: P1)

Whenever the kept result does not hold for the files F.5 sees, F.5 runs the
suite exactly as it does today.

**Why this priority**: "No check is dropped" is the issue's first rule; a
faster run that cites a result that does not hold is worse than a slow one.

**Independent Test**: for each mismatch in the edge cases below, the lookup
exits 1 with a reason, and F.5's documented rule is to run the suite.

**Acceptance Scenarios**:

1. **Given** no record for `main`'s commit, **When** F.5 looks up, **Then**
   the lookup exits 1 and F.5 runs the suite.
2. **Given** a RED record for `main`'s commit, **When** F.5 looks up, **Then**
   the lookup exits 1 and F.5 runs the suite.
3. **Given** a green record for an earlier `main` commit, or for other files,
   another `testCommand`, another platform or another `suiteReuse` mode,
   **When** F.5 looks up, **Then** the lookup exits 1 and F.5 runs the suite.

---

### User Story 3 - The record is made without the pipeline merging (Priority: P2)

The pipeline still never merges. The record for the merged commit is made
by the first run that finds `main` at a commit with no green record: on a
fresh run, as early as the run can (in B, right after `init` creates the
state file — a fresh run has no state file at pre-flight), it starts the
full suite on that commit by itself, in the background, in a separate clean checkout of that commit, so
F.5 can cite the result when it is ready. No human step is needed.

**Why this priority**: without a maker the lookup has nothing to find; the
choice of maker decides who spends the suite's time and when.

**Independent Test**: perform the chosen mechanism on a scratch repository
and check that a record exists whose key is the one `suite-lookup --base`
computes for a new run on that commit.

**Acceptance Scenarios**:

1. **Given** `main` at a merged commit with no record, **When** the chosen
   mechanism runs, **Then** exactly one record is written for that commit,
   green only when the suite passed by the green rule.
2. **Given** the mechanism, **When** it runs, **Then** it never merges, never
   pushes, and never changes a tracked file, the index, HEAD or a branch.

### Edge Cases

- A record for `main`'s commit made under `files` mode is not reused by a run
  under `commit` mode, and the reverse; the mode is in the key today.
- `main` moved again after the record was made: the record names the old
  commit, the lookup misses, F.5 runs.
- The suite run that makes the record leaves a file behind, or a file changes
  while it runs: `suite-record` refuses as it does today, and nothing is kept.
- The checkout the record is made on is not clean (a tracked change, a staged
  change, an untracked file outside `.delivery-kit/`): the key differs from
  the one a new run computes, so the record is never found — or the
  mechanism refuses to record and says why.
- The background run works while the run's own spec phases (B to F) change
  the main working tree: it reads only its separate checkout, so those
  changes never reach the files it tests or the key it records.
- The session dies between pre-flight and F.5, and the run is resumed: F.5
  looks up as usual; it waits only for a background run whose process is
  still alive, and otherwise cites a record if one exists or runs the suite.
- The run stops before F.5 (`--until`, abandon, a hard failure): the
  background run is left to finish; the record it makes is valid for any
  later run on the same commit, and its checkout is still removed.
- The tree is dirty at pre-flight: pre-flight aborts as today, before any
  background run starts.
- No way to start a separate process group exists on the platform (no
  `setsid`, as on macOS and Git Bash): the background run still starts, and
  stopping it at the limit stops the processes it started by their own ids.
- `suiteReuse` is `off`: no record is made and none is read, as today.
- The test command is changed in `.delivery-kit.json` between the merge and
  the next run: the command is in the key, so the lookup misses and F.5 runs.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On a fresh run whose base commit has no green record, the
  pipeline MUST start, in B right after `init` creates the state file and
  the feature branch is cut, and in the background, a full
  `testCommand` run on a separate clean checkout of the base commit, and
  record its result keyed so that `suite-lookup <feature> --base` at F.5,
  whose only change from that commit is the run's own untracked spec
  directory, finds it.
- **FR-002**: The record MUST be made by the same rules as every suite record
  today: the key is taken before the run and checked again after it; the
  verdict is green only for exit code 0 and a TAP file the green rule passes;
  a red result is recorded as red and never reused.
- **FR-003**: F.5 MUST cite a found record exactly as it cites one today: the
  two lines `suite-lookup` prints, quoted verbatim, become `test_baseline`.
- **FR-003a**: When F.5 starts while the background run is still going, F.5
  MUST wait for it, for no longer than a fixed limit of 900 seconds of
  waiting (the last measured full suite here took 538 seconds; the limit is
  a documented constant, not a configuration key). When the limit passes,
  F.5 MUST stop
  the background run — only the processes that run started — and run the
  suite itself. When the background run ended without a green record (it
  failed, was refused, or is red), F.5 MUST run the suite itself.
- **FR-004**: The cited text MUST name the commit the record was made on, the
  command and the counts.
- **FR-005**: Every case where the record does not hold — none, red, another
  commit, other files, another command, platform or mode — MUST still run the
  suite at F.5, with no new way for a lookup to answer yes.
- **FR-006**: The background run MUST never merge, push, fetch, create or
  delete a branch, or change the main working tree's HEAD, index or files.
  Its separate checkout is detached at the base commit, lives in a
  temporary directory outside the working tree, and is removed when the
  background run ends, whatever the outcome. It MUST NOT take or wait on
  the repository lock, and MUST NOT write the run's state file: its own
  bookkeeping (process id, start time, commit, outcome) lives under the
  run's directory in `.delivery-kit/`. It runs with a temporary directory of its own, so its
  tests cannot share temporary files with the live session.
- **FR-006a**: The background run MUST be on by default whenever
  `suiteReuse` is `commit` or `files`, add no configuration key, and never
  start when `suiteReuse` is `off` or any other value. Whether it starts or
  not, B MUST print one line that says which, and why when it does not.
- **FR-007**: The mechanism MUST be documented where suite reuse is described
  (`pipeline/docs/phases.md`, "Reusing a suite run") and in the skill's F.5
  text, so the owner knows when it runs, what it costs and how to turn it off
  (`suiteReuse: off`).
- **FR-008**: The run's metrics MUST record whether F.5 cited a result, as a
  JSON boolean, so the measure in SC-001 can be read from
  `pipeline-run.json`.
- **FR-009**: Each new behaviour MUST ship with a test that goes red when the
  behaviour is removed or inverted (a positive control), per the
  constitution.

### Key Entities

- **Suite record**: one JSON file in `.delivery-kit/suite-results/`, named by
  its key; holds mode, HEAD commit, tree, files hash, command, platform,
  verdict, counts, the time it was recorded and the run that recorded it.
- **Base commit**: the base branch's commit a new run's feature branch starts
  from; HEAD at F.5.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a run whose base-commit result was recorded (by the
  background run or earlier), F.5 takes under 1 minute instead of about 9 (measured from its
  `phase-start` to its `phase-done` timestamps in the state file).
- **SC-002**: Zero cases in the test suite where `suite-lookup --base` exits 0
  for a record that is red, for another commit, or for other files, command,
  platform or mode.
- **SC-003**: The full suite and the analyzer stay green on all three CI
  platforms.

## Assumptions

- The default `suiteReuse` mode `commit` stays the default; no mode is
  weakened to make a rebase merge's new commit ids match.
- A record made on a clean checkout of `main`'s commit has the same key as
  `--base` computes at F.5, because at F.5 HEAD is that commit and the
  index matches it. The feature relies on this and tests it.
- What the key cannot see today (ignored files, the environment, the tools'
  versions) stays outside it, as documented; a separate checkout without
  ignored files is covered by that same documented limit.
- The measure is read from the next real run after release, not inside this
  run.
