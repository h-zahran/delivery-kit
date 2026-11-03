# Tasks: Pre-flight checks the base it resolved, and reads the whole tree

**Input**: `specs/052-preflight-usable-base-and-status/` (spec.md, plan.md, research.md, data-model.md, contracts/stops.md, quickstart.md)

**Tests**: test-first. Each new test is written and shown red against the unchanged script before its rule lands (FR-010).

Test command for a phase: `bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/preflight.bats` (Phases 1 to 3) or `bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/prose.bats` (Phase 4), run in the FOREGROUND, output redirected to a NEW file in the run directory, its exit status captured on the next line. Never pipe a test run into `tail`. Kill only PIDs you started. The full suite is the pipeline's J phase.

## Phase 1: The fixtures leave the enclosing checkout (US5)

**Goal**: every `$FIX/<name>` probe reads a repository of its own on branch `main` with a commit, so the base check of Phase 2 cannot stop it in CI's detached checkout (research R6).

**Independent Test**: `pipeline/tests/preflight.bats` is green against the UNCHANGED script, with the same plan line as before.

- [X] T001 [US5] In `pipeline/tests/preflight.bats`, add a `setup_file` function above `setup()`: copy `"$ROOT/pipeline/tests/fixtures"` with `cp -R` to `"$BATS_FILE_TMPDIR/fixtures"`, `git init -q -b main` there, `git add .` and one commit with the identity on the command line as `seed` gives it (`-c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false`), and `export FIX_REPO="$BATS_FILE_TMPDIR/fixtures"`. In `setup()`, change `FIX="$ROOT/pipeline/tests/fixtures"` to `FIX="$FIX_REPO"`. Rewrite the file's header comment (lines 5 to 11) to say the fixtures are copied into a scratch repository on `main` once per file, because a CI pull-request checkout is detached with no `main` and pre-flight now checks the base exists (feature 052, research R6). If `ROOT` is not set in `setup_file`, load what sets it first (read `tests/helper.bash`).
- [X] T002 [US5] Run `pipeline/tests/preflight.bats` against the UNCHANGED script. A test that writes into `$FIX`, or that needs the fixtures inside this checkout, goes red: give it its own copy (`cp -R "$FIX/<name>" "$BATS_TEST_TMPDIR/"` in a seeded repository) and change none of its assertions. Rerun until green: the plan line equals the ok count, no skip, and the plan line equals the count before T001. Record the plan line and any test changed in `specs/052-preflight-usable-base-and-status/measurements.md`.

**Checkpoint**: the fixtures no longer depend on the checkout's branches.

---

## Phase 2: One usable-base check for every source (US1, US2) 🎯 MVP

**Goal**: a base from any source must be a local branch with a commit and no tag of its name; `HEAD` outside `refs/heads/` stops (FR-001 to FR-005, FR-008, FR-011).

**Independent Test**: the spec's cases 1a to 1f, 4a, 4b and 5a each stop pre-flight with the message `contracts/stops.md` gives; a normal repository reports as before.

- [X] T003 [US1] In `pipeline/tests/preflight.bats`, after the test "base branch: an override that exists only on origin is refused, naming the command that fixes it", add the test "base branch: a usable base is checked from every source": scratch repositories under `$BATS_TEST_TMPDIR`, each `git init -q -b work` and `seed` unless the case says otherwise. Cases, each asserting status 1, empty `$output`, and the exact `$stderr` line from `contracts/stops.md` with its label from `data-model.md`: (1a) no commit, `--base-branch main` → "has no commit yet" when `HEAD` is `refs/heads/main` (init with `-b main`, no `seed`); (1b) `--base-branch main`, no `main` anywhere → "is not a branch here or on origin (the baseBranch key)"; (1c) `git tag main`, `--base-branch main` → "is not a branch here or on origin"; (1d) `git branch main; git tag main`, `--base-branch main` → "is a tag as well as a branch"; (1e) `git remote add origin https://github.com/example/thing.git`, `git update-ref refs/remotes/origin/main HEAD`, `git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main`, no local `main` → "exists only on origin; create the local branch first: git branch --track main origin/main (origin/HEAD; pass a base branch with the run's --base-branch flag)"; (1f) as 1e plus `git branch main; git tag main` → the tag message with the origin/HEAD label; (5a) `git tag work`, no base flag, no remote → the tag message with the current-branch label; (no-commit-object) `git branch main`, then overwrite `.git/refs/heads/main` with `git rev-parse 'HEAD^{tree}'` → "does not name a commit (the baseBranch key)" (research: `update-ref` refuses a tree, a written ref file does not). Positive controls in the same test: after `git branch main` with no tag, `--base-branch main` → status 0, `.baseBranch == "main"`; 1e after `git branch -q --track main origin/main` → status 0, `.baseBranchSource == "origin/HEAD"`.
- [X] T004 [US2] In `pipeline/tests/preflight.bats`, after T003's test, add the test "base branch: HEAD outside refs/heads/ stops pre-flight, naming the fix": (4a) `seed`, `git tag v1`, `git symbolic-ref HEAD refs/tags/v1`, no remote, no base flag; (4b) `seed`, `git update-ref refs/remotes/origin/main HEAD`, `git symbolic-ref HEAD refs/remotes/origin/main`, no remote, no base flag. Each: status 1, empty `$output`, `$stderr` exactly the HEAD-outside line of `contracts/stops.md`, and `$stderr` NOT holding `v1` or `origin/main` (FR-008). Positive control: `git symbolic-ref HEAD refs/heads/work` → status 0, `.baseBranch == "work"`.
- [X] T005 [US1] Run `pipeline/tests/preflight.bats` against the UNCHANGED script. Confirm T003 and T004 are red and every other test green. Record the red list in `measurements.md`.
- [X] T006 [US1] In `pipeline/scripts/preflight.sh`, turn the override's existence and tag checks (the block after `branch_ok "$base_override" --base-branch-override`) into a function `base_usable <name> <label>` defined beside `branch_like`, checking in the order of research R1 with the messages of `contracts/stops.md`, each name printed through a `shown` copy (add its variable to the `shown` list's line and its comment's rule holds). The override block calls `branch_ok` then `base_usable "$base_override" --base-branch-override`. In the name-check `case` after base resolution, each non-override branch calls `base_usable "$base" "<the same label it passes to branch_ok>"` after `branch_ok`. Every git read in it is an exit status, stderr to `/dev/null`. A comment above the function gives the rule, why one function serves every source (Principle IV), the unborn exception (FR-011), and the measured cases (spec Context).
- [X] T007 [US2] In `pipeline/scripts/preflight.sh`, the current-branch source: change `git symbolic-ref --quiet --short HEAD` to `git symbolic-ref --quiet HEAD` and keep its `rc` case; on rc 0, `case` the ref: `refs/heads/*` sets `base="${ref#refs/heads/}"`; anything else `die`s with the HEAD-outside message of `contracts/stops.md`. 051's no-commit stop stays after it, unchanged. Update the comment above the read with research R2's table in words (why `--short` was wrong: `heads/<name>` beside a tag, `v1`, `origin/main`).
- [X] T008 [US1] Run `pipeline/tests/preflight.bats`. For each test now red that is not T003 or T004 and whose fixture names a base that does not exist as a usable local branch (research R4), give the fixture that base — `git branch main` after its `seed`, or the name of a branch it already has — and change none of its assertions (FR-011). Rerun until green: plan line equals ok count, no skip. Record the list of tests changed, and why each, in `measurements.md`.
- [X] T009 [US5] The CI rig (research R6), in the run's scratch directory, never the main checkout: `git clone --depth 1 "file://$PWD" <rig>`, then in it `git checkout -q --detach`, delete every local branch with `git update-ref -d refs/heads/<name>` for each name `git for-each-ref --format='%(refname)' refs/heads` lists, `git remote remove origin`; copy the CHANGED `pipeline/scripts/preflight.sh` and `pipeline/tests/preflight.bats` over the rig's; run `pipeline/tests/preflight.bats` in the rig: green. Positive control: in the same rig, restore the test file from `HEAD` of this checkout (fixtures inside the checkout again) with the CHANGED script, run it, and confirm the `$FIX` tests go red with "is not a branch here or on origin". Record both runs (plan line, ok count, red count) in `measurements.md`. Remove the rig folder.
- [X] T010 [US5] Differential (FR-011, SC-003), Principle II: with the script from `main` (`git show main:pipeline/scripts/preflight.sh` into a scratch file) and the changed one, probe the same repositories where the base is usable — this checkout with no flag; a seeded repository on `main` with no remote; the same with `--base-branch main` and an untracked file; the same with `--base-branch-override main` — and compare each pair's stdout as `jq -S .` and each exit status: identical. Record in `measurements.md`.

**Checkpoint**: no unusable base reaches phase B; a usable one reports as before.

---

## Phase 3: The clean-tree read sees what git hides (US3)

**Goal**: `--untracked-files=normal --ignore-submodules=none` on the status read; an `assume-unchanged` entry counts as dirty; `skip-worktree` and a clean sparse checkout do not (FR-006).

**Independent Test**: cases 2b, 2d and the submodule case report `tree.dirty: true`; 2c and a clean sparse checkout report `false`.

- [X] T011 [US3] In `pipeline/tests/preflight.bats`, after the test "a working tree whose status cannot be read stops pre-flight", add the test "tree: work the repository's configuration hides from git status is dirty": seeded repositories on `main`, each probed with `--base-branch main`, asserting `.tree.dirty`: (2b) a committed file, `git config status.showUntrackedFiles no`, an untracked file → `true`; (2d) a committed file marked `git update-index --assume-unchanged`, unchanged → `true`; (submodule) a second scratch repository with one commit added as submodule `s` with `git -c protocol.file.allow=always submodule add -q <path> s` and committed, then a new commit inside `s`, then `git config submodule.s.ignore all` → `true`; then the same after `git config --unset submodule.s.ignore` and `git config diff.ignoreSubmodules all` → `true`. Then (2d) from a subfolder: a file in `sub/`, the `assume-unchanged` file at the top, probe with `--dir <repo>/sub` → `true` (the `:/` scope, research R3).
- [X] T012 [US3] In `pipeline/tests/preflight.bats`, after T011's test, add the test "tree: a skip-worktree file and a clean sparse checkout are not dirty": (2c) a committed file marked `git update-index --skip-worktree` and then changed → `false` (a documented limit, FR-006); (sparse) folders `a/` and `b/` each with a committed file, `git sparse-checkout set a` → `false`. And the failed listing: in a repository whose `git status` succeeds, a search path built with the file's `shimdir` holding `$PROBE_TOOLS` less `git`, plus a hand-written `git` shim in it that exits 1 when its arguments hold `ls-files` and execs the real git (its path read with `command -v git` before the shim is written) otherwise, passed with `probe --path` → status 1, empty `$output`, `$stderr` exactly the index-listing line of `contracts/stops.md`.
- [X] T013 [US3] Run `pipeline/tests/preflight.bats` against the Phase 2 script: T011's cases and T012's failed-listing case red, T012's `false` cases green, everything else green. Record in `measurements.md`.
- [X] T014 [US3] In `pipeline/scripts/preflight.sh`, the `dirty=` block: add `--untracked-files=normal --ignore-submodules=none` to `git status --porcelain`; after it, count entries with a lowercase tag: `au="$(git ls-files -v -- ':/' 2>/dev/null | awk '/^[a-z] / { n++ } END { print n + 0 }')" || die "<the index-listing message>"`, and `[ "$au" = 0 ] || dirty=true`. Keep `mark_not_read tree.dirty` as it is. A comment gives research R3's table in words: what each flag closes, why `-v` and not `-f`, why `:/`, why awk reads every line (`tests/pipefail.bats`), and the two documented limits (2a, 2c).
- [X] T015 [US3] Run `pipeline/tests/preflight.bats`: green, plan line equals ok count, no skip. Repeat T010's differential for a clean tree and a tree with one untracked file: identical to `main`'s script.

**Checkpoint**: the clean-tree answer covers what the owner put in scope.

---

## Phase 4: The documentation says what is checked and what is not (US4)

**Goal**: `configuration.md` states the base rule, the tree rule, and the limits (FR-007, FR-009).

**Independent Test**: `pipeline/tests/prose.bats` passes; deleting any new sentence in a copy turns a pin red.

- [X] T016 [US4] In `pipeline/docs/configuration.md`, `## Base branch`: replace the sentence "A base branch read from the repository, from `origin/HEAD`, this key or the current branch, gets the override's name check below, and a name that fails it stops pre-flight." with one saying such a base gets the override's checks below — a legal name, a local branch with a commit, not a tag too — and a base that fails one stops pre-flight, naming its source; and after the sentence on a detached `HEAD`, add that a `HEAD` pointing outside `refs/heads/` (a tag, a remote's branch) stops pre-flight too. Change no other sentence there.
- [X] T017 [US4] In `pipeline/docs/configuration.md`, section "Fields the report did not read", after the sentence ending "and whenever `git status` fails.", add: (a) the clean-tree rule — the status read passes `--untracked-files=normal` and `--ignore-submodules=none`, so the repository's configuration cannot hide an untracked file or a changed submodule, and a file marked `assume-unchanged` counts as a change; (b) the limits — a file marked `skip-worktree` (a sparse checkout marks clean files so) and a folder git cannot open are not seen; (c) item 3 — pre-flight's status read, like every later phase of the run, runs the programs the repository's own configuration names (an fsmonitor, hooks, filters), as git does in a repository the user owns; git's ownership check is the guard against one the user does not own.
- [X] T018 [US4] In `pipeline/tests/prose.bats`: in the test "the report's notRead list is documented where a reader of the report finds it", update the `SECTION` heredoc to T017's text copied from the file, with a comment naming feature 052; add a test "the base branch section says every source gets the usable-base check" pinning T016's two sentences, copied from the file. Run `pipeline/tests/prose.bats`: green. In a worktree, delete each new sentence in a copy, point the pin at it, and confirm it goes red; record in `measurements.md`.

**Checkpoint**: the shipped page tells a reader what is checked and what is not.

---

## Phase 5: Mutants (US5)

**Goal**: every new rule is shown able to go red (FR-010, SC-004).

- [X] T019 [US5] In `specs/052-preflight-usable-base-and-status/measurements.md`, add a mutation table, run in a git worktree under the run's scratch directory, never the main checkout: each mutant applied to a COPY of the script, the suite pointed at it with `PREFLIGHT_UNDER_TEST`, the mutated line echoed to prove it landed, the tests that went red recorded. Mutants: (a) `base_usable` not called for non-override sources; (b) the origin-only branch dropped; (c) the unborn branch dropped; (d) the `^{commit}` check dropped; (e) the tag check dropped; (f) `--short` put back on the HEAD read; (g) the HEAD-outside `die` dropped; (h) `--untracked-files=normal` dropped; (i) `--ignore-submodules=none` dropped; (j) the `:/` pathspec dropped; (k) the awk pattern widened to count `S` (inverts the sparse rule); (l) the `ls-files` failure `die` dropped. Every new test goes red under at least one mutant; say which. A mutant that changed nothing is NO-OP, not a pass. Record date, commit, git and bash versions.

---

## Phase 6: Release pipeline 1.7.6

**Goal**: installed copies get the change (FR-012).

- [ ] T020 In `pipeline/CHANGELOG.md`, add `## [1.7.6] - 2026-11-03` above `## [1.7.5]` with `### Highlights` (one line) and `### Fixed` (the usable-base check from every source; `HEAD` outside `refs/heads/`; the status flags and `assume-unchanged`; the documented limits; closes issue #107), in the file's style; set `"version": "1.7.6"` in `pipeline/.claude-plugin/plugin.json`; set the pipeline entry's version to `1.7.6` in `.claude-plugin/marketplace.json` with `sed`, never `jq` (`git diff --stat` shows one line changed there).
- [ ] T021 Run `bash scripts/check-versions.sh` (rc 0, pipeline released at 1.7.6) and `bash "$HOME/bats/bin/bats" --print-output-on-failure tests` in the FOREGROUND: green.

---

## Dependencies

- Phase 1 before Phase 2 (the fixtures must have a base before the base is checked). Phase 2 before Phase 3 (T011's fixtures name `main`, which Phase 2 checks). Phase 4 after Phases 2 and 3 (it describes them). Phase 5 after Phases 2 to 4. Phase 6 last.
- Within each phase, tasks run in ID order: tests before the red run before the script before the follow-ups.

## Parallel examples

- None: Phases 1 to 3 all edit `preflight.bats` and `preflight.sh`; Phase 4's tasks depend on one another; Phase 5 needs every rule; Phase 6 is one release.

## Implementation strategy

Phases 1 and 2 close items 1, 4 and 5 (MVP). Phase 3 closes item 2 as the owner scoped it. Phase 4 documents item 3 and the limits. Phase 5 proves each rule can fail. Phase 6 ships it.
