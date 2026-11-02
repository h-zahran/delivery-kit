# Tasks: The constitution NUL check answers the same way under any load

**Input**: `specs/047-preflight-nul-race/` (spec.md, plan.md, research.md, quickstart.md)

**Tests**: test-first. The regression test is written and shown red on the old line before the fix.

## Phase 1: User Story 1 — a NUL-holding constitution is always read as not set (Priority: P1) 🎯 MVP

**Goal**: the NUL check no longer depends on the exit status of a writer a reader may leave.

**Independent Test**: `bash "$HOME/bats/bin/bats" -f 'NUL' pipeline/tests/preflight.bats` passes; with the old line restored it fails.

- [ ] T001 [US1] In `pipeline/tests/preflight.bats`, add a test whose name contains `NUL` (quickstart filters on it) next to "a constitution saved in an unreadable encoding warns and reads as not set": it writes a fake `od` into `$BATS_TEST_TMPDIR` (drains stdin, prints ` ff fe 23 00`, then about 1 MB of non-NUL lines; same `#!/usr/bin/env bash` stub pattern as the jq-without-`-b` test), runs `PATH="$d:$PATH" probe --dir "$FIX/constitution-nul" --base-branch main`, and asserts status 0, the `NUL bytes` warning on stderr, and `.speckit.constitutionSet == false` (as a JSON boolean). Run it against the unchanged `preflight.sh` and confirm it FAILS; record the output for T010.
- [ ] T002 [US1] In `pipeline/scripts/preflight.sh`, replace the NUL check's `head -c 4096 "$const_file" 2>/dev/null | od -An -tx1 | grep -q ' 00'` with a capture of `od`'s whole output (`hex="$(…)" || hex=''`) and a `case` match on `*' 00'*` (research R1), keeping the warning text and both branches exactly as they are; update the comment above the check to say why the output is captured (a reader that stops early under `pipefail` can kill `od` and flip the answer).
- [ ] T003 [US1] In `pipeline/CHANGELOG.md`, add `## [Unreleased]` above `## [1.7.1]` with a `### Fixed` entry describing the race and the fix in the file's existing style.
- [ ] T004 [US1] Run `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats`: green, plan line equals the ok count, no skip.

**Checkpoint**: the bug is fixed and pinned.

---

## Phase 2: User Story 2 — the same mistake cannot come back unseen (Priority: P2)

**Goal**: a walk refuses a pipe into `grep -q` in any shipped script that sets `pipefail`.

**Independent Test**: `bash "$HOME/bats/bin/bats" tests/pipefail.bats` passes; a planted line turns it red, naming file and line.

- [ ] T005 [US2] Create `tests/pipefail.bats` (load `helper` like the other root tests): a helper `pipefail_walk` that reads paths on stdin, keeps files whose text holds `pipefail`, prints each line that pipes into `grep` with `-q` in any flag group or `--quiet` as `<path>:<line>: <text>`, prints `walked N files`, and returns 1 on any hit or on zero files kept; a test that feeds it `git ls-files '*.sh' '*.bash'` from the repository root minus `.specify/` and test directories and expects success; and fixture tests in `$BATS_TEST_TMPDIR` for: a planted `| grep -q`, a planted `| grep -qE`, a planted `| grep --quiet` (each red, naming the line), a script WITHOUT `pipefail` holding the same line (not flagged), and an empty path list (red). Build any planted text from parts if the repository's own walk would otherwise flag this test file (it does not walk `.bats` files, but keep the fixtures readable).
- [ ] T006 [US2] Run `bash "$HOME/bats/bin/bats" tests/pipefail.bats`: green, no skip.

**Checkpoint**: both stories complete.

---

## Phase 3: Release pipeline 1.7.2

**Goal**: installed copies get the fix (FR-007).

- [ ] T007 Release: in `pipeline/CHANGELOG.md` turn `## [Unreleased]` into `## [1.7.2] - 2026-11-02` (add a short `### Highlights` line in the style of 1.7.1); set `"version": "1.7.2"` in `pipeline/.claude-plugin/plugin.json`; set the pipeline entry's version to `1.7.2` in `.claude-plugin/marketplace.json` with `sed`, never `jq` (check `git diff --stat` shows a one-line change there). Do not open a new `## [Unreleased]`.
- [ ] T008 Run `bash scripts/check-versions.sh` (rc 0, pipeline released at 1.7.2) and any tests that pin versions (`bash "$HOME/bats/bin/bats" tests`): green.

---

## Phase 4: Polish — prove it (records only)

- [ ] T009 Write `specs/047-preflight-nul-race/measurements.md`: SC-001 — the T001 test run 10 times against the old line (in a scratch worktree at `e255029` with the test copied in) and 10 times against the new: 0/10 and 10/10 passes; SC-002 — the 400-run load reproduction from the spec (8 busy loops) on the old pipeline and on the new capture: wrong answers counted; SC-003 — pre-flight stdout and stderr on every `pipeline/tests/fixtures/constitution-*` fixture, old script against new, compared byte for byte.
- [ ] T010 In the same file, record the positive controls: the T001 test's red output on the old line (from T001), and for `tests/pipefail.bats` the fixture tests going red when the walk's `-q` rule is narrowed (e.g. to `-q` only, dropping flag groups) and when the zero-file check is removed (run in a scratch worktree).

---

## Dependencies & Execution Order

- Phase 1: T001 → T002 → T003 → T004 (test first, red, then fix).
- Phase 2 needs nothing from Phase 1 except that the bug line is gone (the walk would otherwise flag `preflight.sh:322`): run after Phase 1.
- Phase 3 after Phases 1-2. Phase 4 last.
- SC-006 (the `pipeline-v1.7.2` tag and its CI tag step) happens after the merge, which the pipeline never does: the orchestrator does it after DONE, from `origin/main` after a fetch.

## Parallel Opportunities

T005 (new file) could run beside Phase 1, but the walk's real-repository test is red until T002 lands, so it is sequenced after it.

## Implementation Strategy

Phase 1 alone fixes the bug. Phase 2 guards it. Phase 3 ships it. One commit per phase.
