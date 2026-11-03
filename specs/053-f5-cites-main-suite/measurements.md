# Measurements — 053

Each entry is a record of one run on the date given, not a claim about the
current files.

## T003 — the key split changes nothing (2026-11-03)

- `pipeline/tests/suite-cache.bats` after T001 and T002: `1..70`, 70 ok,
  0 not ok, exit 0 — the same plan line as before the split.
- Differential: `suite-key 053-f5-cites-main-suite` on this checkout (HEAD
  `a5c160c`, the Phase 1 edits uncommitted) printed
  `c01bdd8011184f5db83583f63bd10b543b83fd3d` from `main`'s script and from
  the changed script: identical.

## T004-T006 — the cited line names commit and command (2026-11-03)

- Against the Phase 1 script, `suite-cache.bats` `1..71`: 4 not ok (25, 35,
  36, 37) — the three changed summary assertions and the new files-mode
  test; every other test ok.
- After T005: `1..71`, 71 ok, 0 not ok, exit 0.

## T008-T010 — suite-base start and the runner (2026-11-03)

- T008, against the Phase 2 script: `base-suite.bats` `1..10`, 10 not ok.
- First run after T009: 9 of 10; test 8 was red for the test's own fault —
  its stub printed a `#` comment BEFORE the plan line, which the green rule
  refuses. The comment moved after the plan line; no code changed.
- T010: `base-suite.bats` + `suite-cache.bats` `1..81`, 81 ok, exit 0; no
  `suite-base-run` process left afterwards (`ps`).
- Mutation, landed (printed `2743:  : mutated-no-cd`): the runner no longer
  enters the checkout, so it takes its key in the main tree, spec directory
  included. Red: test 1 (the --base lookup misses) and test 5 (no green
  base record to find). Test 7 stayed green: its stub writes nothing, so
  the main tree's status cannot show the difference; test 1 is the guard.

## T012-T014 — suite-base wait (2026-11-03)

- T012, against the Phase 3 script: `base-suite.bats` `1..17`, tests 11 to
  17 not ok, 1 to 10 ok.
- Found while T012 ran: test 16 stops a runner with KILL, which runs no
  trap, and the runner's heartbeat loop (`while :`) lived on as an orphan,
  writing for ever. It was stopped by its pid, and the loop now runs only
  while the runner's id answers (`while kill -0 "$$"`); test 16 asserts the
  heartbeat no longer moves 6 s after its runner is gone.
- T014: three runs in a row, each `1..17`, 17 ok, exit 0; no
  `suite-base-run` process left 6 s after each.
- Mutation 1, landed (`2804:  : mutated-fresh`): the heartbeat's age is no
  longer checked. Red: test 15 (a process whose heartbeat was stale was
  signalled).
- Mutation 2, landed (line 2744 loops on `:`): red: test 16 (the heartbeat
  moved after its runner was gone). The mutant's orphan loop was then
  stopped by its pid.

## T015-T019 — the skill and the docs (2026-11-03)

- T015, against the unchanged prose: `prose.bats` `1..99`, 96 ok, 3 not ok
  (43 the F.5 pins and span, 64 the new B test, 65 the phases.md pins).
- T019, after T016 and T018: `prose.bats` + `skills.bats` `1..111`, 111 ok,
  exit 0.

## T020-T021 — release 1.8.0 (2026-11-03)

- `bash scripts/check-versions.sh`: exit 0,
  `pipeline: plugin=1.8.0 marketplace=1.8.0 changelog=1.8.0 state=released`.
- Root suite `bash "$HOME/bats/bin/bats" -r tests`: `1..140`, 140 ok, exit 0.

## T022 — the real suite through suite-base on 065ab80 (2026-11-03)

- Scratch detached worktree of `065ab80`, throwaway run `999-q` with the
  real `testCommand`, the Phase 6 script. `start` at 11:31:01 UTC printed
  `base suite started on commit 065ab807e7ea6188a79505dd527d29741f6816eb`;
  `wait --slice 60` exited 2 seven times, then `base suite ended: green`
  at 11:38:34 — 7 min 33 s, against F.5's 6 min 6 s on the main tree for
  the same commit (the machine was otherwise idle; not investigated).
- `suite-lookup 999-q --base`: exit 0,
  `1..934, 934 ok (0 skipped), 0 not ok, exit 0 — recorded
  2026-11-03T11:38:33Z by run 999-q on commit
  065ab807e7ea6188a79505dd527d29741f6816eb, command "bash
  \"$HOME/bats/bin/bats\" -r --print-output-on-failure tests handoff/tests
  pipeline/tests team/tests" — for these files without the untracked
  specs/999-q/`.
- The background TAP: `1..934`, 934 ok — the same plan line and count as
  this run's F.5 TAP. The record's key is `62b4305…`, the key research R1's
  probe recorded by hand for the same commit and command.
- Section 4: HEAD, `git status --porcelain=v1` and `git branch --list` of
  the main tree identical before and after; `git worktree list` differed
  only by the scratch worktree, removed after.

## Phase I — the review round's fixes (2026-11-03)

- Five lenses at once: contract (6 MEDIUM, 9 LOW), security (1 MEDIUM, 5
  LOW), tests (3 HIGH, 3 MEDIUM, 7 LOW), bugs (14 candidates), simplify
  (3 MEDIUM, 13 LOW); then the bugs lens's re-read of the fixes (12). Every
  finding and its disposition is in the run's `review-I.txt`.
- After the fixes: `base-suite.bats` `1..27`, 27 ok, three runs in a row;
  `suite-cache.bats` + `prose.bats` + `skills.bats` `1..182`, 182 ok; the
  analyzer exits 0; no `suite-base-run` process left.
- Mutations, each landed (its line printed) and each red on its target
  test: the limit rewritten per call; no heartbeat write; the exit code
  dropped; no key comparison at start; no TMPDIR check; no admin removal in
  the fallback (first SURVIVED: given the full path, git 2.53 removes a
  missing worktree's record itself, so the test now breaks the checkout's
  `.git` file to reach the fallback); a default limit of 905; no TERM in
  base_stop; the unchecked tree printed; no abandoned check.
