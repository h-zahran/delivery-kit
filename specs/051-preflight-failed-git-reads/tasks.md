# Tasks: Pre-flight stops stating a failed git read as fact

**Input**: `specs/051-preflight-failed-git-reads/` (spec.md, plan.md, research.md, data-model.md, contracts/stops.md, quickstart.md)

**Tests**: test-first. Each new test is written and shown red against the unchanged script before the stops land (FR-007).

Test command for a phase: `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` (Phase 1) or `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` (Phase 2), run in the FOREGROUND. The full suite is the pipeline's J phase.

## Phase 1: Pre-flight stops on the three failed reads (US1, US2, US3, US4) 🎯 MVP

**Goal**: `preflight.sh` stops, naming the case, on a detached `HEAD` or a commit-less branch when the base comes from the current checkout, and on a failed status read; only with a usable git.

**Independent Test**: `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` passes; quickstart.md steps 1 to 4 print what they say.

- [X] T001 [US1] In `pipeline/tests/preflight.bats`, after the test "base branch: the override beats the configured name where there is no remote", add the test "base branch: a branch with no commit yet stops pre-flight, naming the fix": `git init -q -b work` a repository in `$BATS_TEST_TMPDIR/unborn`, no remote, `probe --dir <repo>` with no base flag; assert `[ "$status" -eq 1 ]`, `[ -z "$output" ]`, and that `$stderr` holds `no commit yet`, `make a first commit` and `--base-branch`. Then, in the same repository, `probe --dir <repo> --base-branch main` and assert status 0, `.baseBranch == "main"`, `.baseBranchSource == "configured"` and `not_read_is '[]'` (the stop is for the current-checkout source only).
- [X] T002 [US1] In `pipeline/tests/preflight.bats`, after T001's test, add the test "base branch: a detached HEAD stops pre-flight, naming the fix": a repository in `$BATS_TEST_TMPDIR/detached`, `git init -q -b work`, `seed`, `git checkout -q --detach`, no remote, `probe --dir <repo>`; assert status 1, empty `$output`, and `$stderr` holding `HEAD is detached`, `check out a branch` and `--base-branch`. Then, after `git checkout -q work`, `probe --dir <repo>` and assert status 0, `.baseBranch == "work"`, `.baseBranchSource == "current branch"` (the positive control: the same repository on its branch reports).
- [X] T003 [US2] In `pipeline/tests/preflight.bats`, after the existing tree-dirty test (find it by `tree.dirty`), add the test "a working tree whose status cannot be read stops pre-flight": a repository in `$BATS_TEST_TMPDIR/badindex`, `git init -q -b work`, `seed`, an untracked file, then `printf garbage > .git/index`; `probe --dir <repo> --base-branch main`; assert status 1, empty `$output`, and `$stderr` holding `status could not be read`, and NOT holding `index` (git's own text, FR-002b). As its precondition, assert that `git -C <repo> rev-parse --git-dir` exits 0 (git is still usable, research R4).
- [X] T004 [US4] In `pipeline/tests/preflight.bats`, existing test "an unusable git with no base flag names the base fields, and never a device skip" (feature 050: a refused, commit-less repository probed with no base flag), add one line after its `baseBranchSource` assertion: `[ "$(jq -r '.baseBranch' <<<"$output")" = "" ]`. Add no other line and edit no existing line. With the other unusable-git tests, this is the other direction of FR-007: it goes red if either stop loses its `gitUsable` guard (T009 mutants e and f).
- [X] T005 [US1] Run `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` against the UNCHANGED script in the FOREGROUND, output to a new file in the run directory, and confirm T001-T003 are red and every other test, T004's included, green. Record the red list for T009.
- [X] T006 [US1] In `pipeline/scripts/preflight.sh`, in the base-branch block's last `else` (the current-branch source): keep `base_source="current branch"` and `base=""`; when `git_usable` is `true`, set `base` from `git symbolic-ref --quiet --short HEAD 2>/dev/null`, and on its failure `die` with the detached message from `contracts/stops.md`; then `git rev-parse --verify --quiet HEAD >/dev/null 2>&1` or `die` with the no-commit message. When `git_usable` is not `true`, run no git read here. Replace the `dirty=` lines: when `git status --porcelain 2>/dev/null` succeeds, `dirty=true` if its output is non-empty; when it fails and `git_usable` is `true`, `die` with the status message; leave `mark_not_read tree.dirty` as it is. Each message starts lower-case after `preflight: `, names the case and the fix, and holds no variable (FR-002b). A comment above each read says why the read was chosen (research R1, R4), with the measured exit statuses, and that the stop fires only with a usable git (R5).
- [X] T007 [US1] Run `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` in the FOREGROUND, output to a new file. For each test now red that probes a commit-less repository with no base flag and expects a report, add `seed` after its `git init` (the file's existing helper) and change nothing else in it (FR-008). Rerun until green: the plan line equals the ok count, no skip. Record in `measurements.md` the list of tests that got a `seed`.
- [X] T008 [US3] Commit nothing yet. Make a detached worktree of `HEAD` under the run's scratch directory, copy the changed `pipeline/scripts/preflight.sh` and `pipeline/tests/preflight.bats` into it, and run `pipeline/tests/preflight.bats` there in the FOREGROUND (research R3: CI checks out detached). Green. Then run quickstart.md steps 1 to 4 and check each result. Then the differential FR-004 and SC-002 need (Principle II): with the script from `main` (`git show main:pipeline/scripts/preflight.sh` into a scratch file) and the changed one, probe the same repositories where every read succeeds — this checkout with `--base-branch main`; a seeded repository with no remote and no base flag; the same with an untracked file; a commit-less repository with `--base-branch main` — and compare each pair's stdout as `jq -S .` and each exit status: identical. Record all three in `measurements.md`, then remove the worktree with `git worktree remove`.
- [X] T009 [US4] Write `specs/051-preflight-failed-git-reads/measurements.md`: date, commit, git and bash versions; the T005 red list; the T007 seed list; T008's result; and a mutation table (FR-007), run in a git worktree, never the main checkout: each mutant applied to a COPY of the script, the suite pointed at it with `PREFLIGHT_UNDER_TEST`, the mutated line echoed to prove it landed, and the tests that went red recorded: (a) drop the detached `die`; (b) drop the no-commit `die`; (c) drop the status `die`; (d) put back `git rev-parse --abbrev-ref HEAD` for the base name; (e) drop the `git_usable` guard on the base read; (f) drop the `git_usable` guard on the status `die`. Every new test must go red under at least one mutant; say which. A mutant that changed nothing is NO-OP, not a pass.

**Checkpoint**: pre-flight refuses each failed read, and the refusal is pinned.

---

## Phase 2: The documentation says pre-flight stops (US4)

**Goal**: `configuration.md` says the three cases stop pre-flight; the section's pin follows.

**Independent Test**: `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` passes; deleting the new sentence in a copy turns the pin red.

- [ ] T010 [US4] In `pipeline/docs/configuration.md`, section "Fields the report did not read", replace the sentence "It does not cover a read that fails under a usable git: on a branch with no commit yet, `baseBranch` reads `HEAD`, and that is not in the list." with one stating that a read that fails under a usable git is never a placeholder in the list: pre-flight stops instead and says why — when the base branch comes from the current checkout and that checkout is a detached `HEAD` or a branch with no commit yet, and whenever the working tree's status cannot be read. Change no other sentence in the section.
- [ ] T011 [US4] In `pipeline/tests/prose.bats`, test "the report's notRead list is documented where a reader of the report finds it", replace the old sentence inside the `SECTION` heredoc with T010's sentence, copied from the file, and add a comment line naming feature 051 beside the 050 one. Run `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` in the FOREGROUND: green. Then, in a worktree, delete T010's sentence in a copy and confirm the test goes red; record it in `measurements.md`.

**Checkpoint**: the shipped page tells a reader of the report what happens.

---

## Phase 3: Release pipeline 1.7.5

**Goal**: installed copies get the change (FR-009).

- [ ] T012 In `pipeline/CHANGELOG.md`, add `## [1.7.5] - 2026-11-02` above `## [1.7.4]` with `### Highlights` (one line) and `### Fixed` (the three stops, each with the case it closes; `notRead` unchanged; closes issue #106), in the file's style; set `"version": "1.7.5"` in `pipeline/.claude-plugin/plugin.json`; set the pipeline entry's version to `1.7.5` in `.claude-plugin/marketplace.json` with `sed`, never `jq` (`git diff --stat` shows one line changed there).
- [ ] T013 Run `bash scripts/check-versions.sh` (rc 0, pipeline released at 1.7.5) and `bash "$HOME/bats/bin/bats" tests` in the FOREGROUND: green.

---

## Dependencies

- Phase 1 before Phase 2 (the docs describe the stops). Phase 3 last.
- In Phase 1: T001-T004 (tests) before T005 (red run) before T006 (script) before T007-T009.
- In Phase 2: T011 after T010.

## Parallel examples

- None: Phase 1 tasks all edit `preflight.bats` or depend on one that does; Phase 2 is two dependent steps; Phase 3 is one release.

## Implementation strategy

Phase 1 alone closes the issue (MVP); Phase 2 makes the shipped page say so; Phase 3 ships it.
