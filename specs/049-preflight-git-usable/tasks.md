# Tasks: Pre-flight asks whether git will work here, not only whether it can be found

**Input**: `specs/049-preflight-git-usable/` (spec.md, plan.md, research.md, data-model.md, contracts/capabilities.md, quickstart.md)

**Tests**: test-first. Each fixture test is written and shown red against the unchanged script before the classifier lands (FR-011, FR-012).

Test command for a phase: `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` (Phase 1) or `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` (Phase 2), run in the FOREGROUND. The full suite is the pipeline's J phase.

## Phase 1: The probe reports whether git is usable, and why (US1, US2, US3) 🎯 MVP

**Goal**: `preflight.sh` reports `capabilities.gitUsable` and `gitReason` from one classifier, and an unusable git behaves as an absent one does at the name checks.

**Independent Test**: `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` passes; quickstart.md steps 1 to 3 print the expected values.

- [X] T001 [US1] In `pipeline/tests/preflight.bats`, in the "the git capability" block after the two existing git tests, add a helper `git_isolate` that writes an empty file `$BATS_TEST_TMPDIR/gitconfig` and exports `GIT_CONFIG_GLOBAL` to it and `GIT_CONFIG_NOSYSTEM=1` (research R3: an empty file, never `/dev/null`). Add the test "the capability report names a git that refuses the repository for ownership": `git init -q` a repository in `$BATS_TEST_TMPDIR/owned`, call `git_isolate`, export `GIT_TEST_ASSUME_DIFFERENT_OWNER=1`; FIRST assert the precondition (plain `git -C <repo> rev-parse --git-dir` exits non-zero, and with `-c safe.directory='*'` exits 0), failing with a message that names the precondition; then `probe --dir <repo> --base-branch main` and assert status 0, `jq -e .` parses, `.capabilities.git == true`, `.capabilities.gitUsable` is the boolean `false` (`type == "boolean"`), and `.gitReason == "refused-ownership"`. Then assert nothing was configured (FR-005): `$BATS_TEST_TMPDIR/gitconfig` is still empty, and the repository's `.git/config` is byte-identical to a copy taken before the probe.
- [X] T002 [US1] In `pipeline/tests/preflight.bats`, add "an unusable git reports names unchecked, as an absent one does": the same refused repository (with one seeded commit and a branch `integration`), `probe --dir <repo> --base-branch-override integration --feature-branch new-work`; assert status 0, one parseable document, `.gitReason == "refused-ownership"`, and stderr does NOT hold "is not a branch here or on origin" (the wrong cause the unchecked override reported before, research R5).
- [X] T003 [US2] In `pipeline/tests/preflight.bats`, add "the capability report names a git that opens no repository here": `mkdir $BATS_TEST_TMPDIR/plain`, export `GIT_CEILING_DIRECTORIES=$BATS_TEST_TMPDIR`, call `git_isolate`; precondition: plain and lifted `git -C <dir> rev-parse --git-dir` both exit non-zero; then probe it and assert status 0, `.capabilities.git == true`, `.capabilities.gitUsable` boolean `false`, `.gitReason == "no-repository"`.
- [X] T004 [US2] In `pipeline/tests/preflight.bats`, add "the capability report names a git that is found but cannot run": a shim directory built with `shimdir` from `PROBE_TOOLS` minus git (derive it the way the absent test does), plus a `git` script that prints nothing and exits 1; precondition: that `git --version` exits non-zero; `probe --path <dir> --dir "$FIX/other" --base-branch main`; assert status 0, `.capabilities.git == true`, `.capabilities.gitUsable` boolean `false`, `.gitReason == "broken"`.
- [X] T005 [US3] In `pipeline/tests/preflight.bats`, extend "the capability report names git present when git is findable" with `.capabilities.gitUsable` boolean `true` and `.gitReason == "usable"`, and extend "the capability report names git absent, and the report survives it" with `.capabilities.gitUsable` boolean `false` and `.gitReason == "absent"`. Do not edit any existing assertion; only add lines.
- [X] T006 [US3] In `pipeline/tests/preflight.bats`, add (the reason-set test moved to T014: its second side is text T012 writes, so in this piece it could only be red.) And "the script probes git in one place" (Principle IV): exactly one `command -v git` in `pipeline/scripts/preflight.sh`, outside comments.
- [X] T007 [US1] Run `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` against the UNCHANGED script and confirm T001-T006's new assertions are red (record which, for T010).
- [X] T008 [US1] In `pipeline/scripts/preflight.sh`, replace `have_git=false; command -v git ... && have_git=true` (after `cd "$dir"`) with the classifier from plan.md (absent, broken, usable, refused-ownership, no-repository; exit codes only; `-c safe.directory='*'` on the one `rev-parse --git-dir` call), setting `git_present`, `git_usable`, `git_reason`, and `have_git="$git_usable"`; update the comment above it to say what each step decides, why message text is never read, and why the lifted call is safe (research R1, R2). Delete the second probe `git_present=false; command -v git ...` near the gh probe and rewrite its comment block to point at the classifier. Add `--argjson git_usable "$git_usable" --arg git_reason "$git_reason"` to the final `jq -n`, `gitUsable: $git_usable` inside `capabilities` after `git`, and `gitReason: $git_reason` after `capabilities`.
- [X] T009 [US1] Run `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats`: green, plan line equals the ok count, no skip. Run quickstart.md steps 1-3 and check the printed values.
- [X] T010 [US1] Write `specs/049-preflight-git-usable/measurements.md`: date, commit, git version; the T007 red list; and a mutation table (FR-012) — each of these applied to a COPY of the script, the suite pointed at it with `PREFLIGHT_UNDER_TEST`, the mutated line echoed to prove it landed, and the tests that went red: (a) drop `-c safe.directory='*'`; (b) swap `refused-ownership` and `no-repository`; (c) remove the `git --version` step; (d) `have_git` back to `git_present`; (e) `--argjson git_usable` to `--arg`. Every new test must go red under at least one mutation; say which.

**Checkpoint**: the probe is fixed and pinned.

---

## Phase 2: The orchestrator stops for every unusable git, and says why (US1, US2)

**Goal**: decision 11, the probe-block git line and the rare-paths sections read `gitUsable` and `gitReason`; their pins follow.

**Independent Test**: `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` passes; mutating decision 11's trigger back to `capabilities.git` turns a pin red.

- [ ] T011 [US1] In `pipeline/skills/pipeline/SKILL.md`: change the probe-block line to `git          : <usable / ABSENT / BROKEN / REFUSED (ownership) / NO REPOSITORY — the run stops, see decision 11>`; change the pointer under the block and the read-me-first sentence to say `capabilities.gitUsable`; change decision 11 to `11. **git absent or unusable** (`capabilities.gitUsable` false): stop.` keeping "FIRES FIRST — before item 1 and before every other decision on this list.", saying the stop names `gitReason`, prints `https://git-scm.com/downloads` when git is absent or broken, and installs and configures nothing, and keeping the pointer to "The git stop".
- [ ] T012 [P] [US1] In `pipeline/docs/rare-paths.md`: in "The probe block without git", make the trigger `capabilities.gitUsable` false and the not-read text `— not read, git is <reason>` (keeping "and only those parts" and "the name came from a configuration file and IS established"); in "The git stop", add what to print per `gitReason` (research R6): absent → the link; broken → found but did not run, the link; refused-ownership → `git config --global --add safe.directory <the repository's path>` for the owner to run, never run by the pipeline, shown on screen only; no-repository → no repository opened here, start inside the repository or run `git rev-parse --git-dir` there to read git's own reason. Keep both headings unchanged.
- [ ] T013 [P] [US1] In `pipeline/README.md`, in the `git` requirement paragraph, say that pre-flight also stops when git is found but will not open the repository (ownership refusal, a broken git, or no repository), names which, and prints the fix to run; nothing is installed or configured for you.
- [ ] T014 [US1] In `pipeline/tests/preflight.bats`, add the reason-set test moved here from T006, "the git reasons the script assigns are the ones the git stop instructs" (Principle V): derive the set of values from `pipeline/scripts/preflight.sh`'s `git_reason=<value>` assignments, less `usable`, and the set of reasons "The git stop" in `pipeline/docs/rare-paths.md` lists as items opening with the reason in backticks; both non-empty, and equal. In `pipeline/tests/prose.bats`, update every pin and stored span the T011-T012 edits changed (the "the git stop is pinned in both surfaces" test, the pointer pins in "each rare path's old site still sends the run to its section", the rare-paths section spans, and any skill-region span that holds the changed text), and add pins for: decision 11's `capabilities.gitUsable` trigger, the `refused-ownership` safe.directory line in "The git stop", and "never run by the pipeline". Run the prose suite: green. Then mutate decision 11's trigger back to `capabilities.git` in a copy and confirm a pin goes red; record it in `measurements.md`.
- [ ] T015 [P] [US1] In `specs/013-preflight-git-probe/contracts/capabilities.md`, add one line at the top: superseded in part by `specs/049-preflight-git-usable/contracts/capabilities.md`; its "What the probe does NOT promise about git" section no longer holds. Change nothing else in that file.

**Checkpoint**: both surfaces agree with the probe.

---

## Phase 3: Release pipeline 1.7.3

**Goal**: installed copies get the fix (FR-014).

- [ ] T016 In `pipeline/CHANGELOG.md`, add `## [1.7.3] - 2026-11-02` above `## [1.7.2]` with `### Highlights` (one line) and `### Fixed` (the probe now asks whether git works here; the two new keys; decision 11 names the reason; this retires 1.x's stated limit that a found-but-broken git was not covered), in the file's style; set `"version": "1.7.3"` in `pipeline/.claude-plugin/plugin.json`; set the pipeline entry's version to `1.7.3` in `.claude-plugin/marketplace.json` with `sed`, never `jq` (`git diff --stat` shows one line changed there).
- [ ] T017 Run `bash scripts/check-versions.sh` (rc 0, pipeline released at 1.7.3) and `bash "$HOME/bats/bin/bats" tests` in the FOREGROUND: green.

---

## Dependencies

- Phase 1 before Phase 2 (the prose names keys the probe must emit). Phase 3 last.
- In Phase 1: T001-T006 (tests) before T007 (red run) before T008 (fix) before T009-T010.
- In Phase 2: T011, T012, T013, T015 touch different files; T014 after T011 and T012.

## Parallel examples

- Phase 1: none; every task edits `preflight.bats` or depends on one that does.
- Phase 2: T012, T013 and T015 in parallel after T011 starts.

## Implementation strategy

Phase 1 alone fixes the report (MVP); Phase 2 makes the orchestrator act on it; Phase 3 ships it.
