# Measurements: 052-preflight-usable-base-and-status

Machine: Ubuntu, git 2.53.0, bash 5.x, bats from `$HOME/bats`. Base commit
`4d0b5cd`. Every run below went to its own file in the run directory, in
the foreground, with its exit status captured on the next line.

## Phase 1 — the fixtures leave the enclosing checkout (T001, T002)

- 2026-11-03: `pipeline/tests/preflight.bats` before T001 held 115
  `@test` lines (`git show HEAD:pipeline/tests/preflight.bats | grep -c
  '^@test'`).
- 2026-11-03, after T001, against the UNCHANGED script: rc 0, plan line
  `1..115`, 115 `ok`, no `not ok`, no `# skip`.
- Tests changed by T002: none. No test wrote into `$FIX` or needed the
  fixtures inside this checkout.

## Phase 2 — one usable-base check for every source (T003 to T010)

- T005, 2026-11-03, the two new tests against the UNCHANGED script: rc 1,
  plan `1..117`, 115 `ok`. Red: "base branch: a usable base is checked
  from every source" (first case 1a exited 0) and "base branch: HEAD
  outside refs/heads/ stops pre-flight, naming the fix" (exited 0).
- After T006 and T007: shellcheck clean; 18 existing tests red, every one
  on a refusal of a base that does not exist as a local branch (17 times
  "'main' is not a branch here or on origin (the baseBranch key)", once
  "'trunk' …", and the origin/HEAD tests on "'main' exists only on origin"
  or "is not a branch here or on origin (origin/HEAD; …)").
- T008, the fixtures given a base (research R4), applied by a script that
  refused to write unless every count matched: a helper `main_base` (seed,
  then a local `main` unless the commit landed on it) beside `seed`, used
  in place of `seed` or after a bare `git init` in: "remote
  classification: none, github, other"; "base branch: origin/HEAD first,
  then the override, each with its source" (also `git branch trunk`, the
  configured name it reports); "base branch: a detached HEAD stops
  pre-flight, naming the fix"; "base branch: a name from the repository
  gets the override's check, from every source"; "feature branch: the base
  from origin/HEAD is refused too, with no override"; "willSkip names
  phases L and M in a repository with no remote"; "tree reports dirty and
  runsLive from the facts on disk"; "a working tree whose status cannot be
  read stops pre-flight"; "a DONE run and an abandoned run are not live;
  each live run is named"; "an unreadable state file is warned about and
  named, never counted as live"; "the review phase is announced skipped
  for both of its causes"; "gh installed only as gh.cmd is found, named,
  and keeps the review phase"; "a usable git names nothing, even with no
  remote"; the three big-constitution tests (through `big_const`); and
  "pre-flight: abandoned false or null is live, a dot-named run is read,
  and a jq without -b reads them all". No assertion changed in any of them.
- One assertion changed, named in FR-011: "base branch: a branch with no
  commit yet stops pre-flight, naming the fix" (feature 051) expected a
  configured base in a repository with no commit to be reported; it now
  expects "'main' is not a branch here or on origin (the baseBranch key)".
  Its `not_read_is '[]'` line went with the report it read.
- After T008: rc 0, plan `1..117`, 117 `ok`, no skip.
- T009, the CI rig (`git clone --depth 1`, `HEAD` detached, every
  `refs/heads/*` deleted, `origin` removed; no ref left at all): the
  changed tests and script, rc 0, plan `1..117`, 117 `ok`. Positive
  control, the same rig with `main`'s test file (fixtures probed inside
  the checkout) and the changed script: rc 1, plan `1..115`, 70 `ok`, 45
  `not ok`.
- T010, the differential, `main`'s script against the changed one, stdout
  as `jq -S .` and the exit status: identical (rc 0) for this checkout
  with no flag; a seeded repository on `main` with no remote and no flag;
  the same with `--base-branch main` and an untracked file; the same with
  `--base-branch-override main`; a clean tree with a tracked file; a
  modified tracked file.

## Phase 3 — the clean-tree read (T011 to T015)

- T013, 2026-11-03, the two new tests against the Phase 2 script: rc 1,
  plan `1..119`, 117 `ok`. Red: "tree: work the repository's
  configuration hides from git status is dirty" (first at 2b: `tree.dirty`
  false, want true) and "tree: a skip-worktree file and a clean sparse
  checkout are not dirty" (at the failed-listing case: exit 0, want 1; its
  2c and sparse cases, which come first, passed).
- After T014: shellcheck clean; rc 0, plan `1..119`, 119 `ok`, no skip.
  `tests/pipefail.bats`: rc 0, 14 of 14.
- T015, the differential of Phase 2 repeated with the Phase 3 script:
  identical to `main`'s script (rc 0) in all six cases, a clean tree and a
  tree with one untracked file among them.

## Phase 4 — the documentation (T016 to T018)

- Two departures from the task text, named: T017's sentences went in as a
  second paragraph at the end of "Fields the report did not read", not
  inside the first one after "and whenever `git status` fails.", so the
  first paragraph's text is unchanged; and T018 updated the existing pin
  "configuration.md's Base branch section says when the current branch
  serves, and that every repository name is checked" instead of adding a
  new test, because that pin held the very sentence T016 replaces.
- 2026-11-03, the two pins: rc 0, 2 of 2.
- Mutants, each in a detached worktree of `HEAD` with the changed
  `configuration.md` and `prose.bats` copied in, one sentence deleted per
  run (the file shown to change), the two pins run: control green; RED
  for each of the seven: the `HEAD` outside `refs/heads/` sentence; "gets
  the override's checks below: …"; "A base that fails one stops
  pre-flight, naming where the base came from."; the two flags; the
  `assume-unchanged` sentence; the two limits; the repository-programs
  sentence (item 3). Every mutant turned one pin red.

## Phase 5 — mutants (T019)

2026-11-03, git version 2.53.0, bash 5.3.9(1)-release, at commit `2acccd5`.
Each mutant was applied by a script that refused unless its anchor
matched exactly once, written to a COPY of the script beside its two
siblings, checked to differ from the original and to parse, its changed
line echoed, and run as `PREFLIGHT_UNDER_TEST=<copy> bats
pipeline/tests/preflight.bats` in a detached worktree of `HEAD`. Plan
`1..119` every run; no mutant was a NO-OP.

| Mutant | Change | Red |
|---|---|---|
| a | `base_usable` not called for non-override sources | 17 (051 unborn), 32 (usable base) |
| b | the origin-only refusal dropped | 31 (override only on origin), 32 |
| c | the unborn refusal dropped | 32 |
| d | the `^{commit}` check dropped | 32 |
| e | the tag refusal dropped | 30 (override tag), 32 |
| f | `--short` put back on the `HEAD` read | 32, 33 (HEAD outside) |
| g | the `HEAD`-outside stop dropped | 33 |
| h | `--untracked-files=normal` dropped | 61 (hidden work) |
| i | `--ignore-submodules=none` dropped | 61 |
| j | the `:/` pathspec dropped | 61 |
| k | awk counts `S` (skip-worktree) too | 62 (skip-worktree, sparse) |
| l | the `ls-files` failure stop dropped | 62 |

Every new test goes red under at least one mutant: 32 under a to f, 33
under f and g, 61 under h, i and j, 62 under k and l. Mutant k inverts the
sparse rule, so the "not dirty" direction is shown able to go red too.
