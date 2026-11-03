# Tasks: Prove the pre-flight boolean-type guard, then close issue #34

**Input**: `specs/054-preflight-boolean-guard-proof/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)

**Tests**: this feature is about tests. The suite file changed is `pipeline/tests/preflight.bats`; the rig is a measurement, not a suite.

**No release**: only tests and spec documents change; `065ab80`, the last test-only change to `preflight.bats`, shipped without a release.

---

## Phase 1: The mutation rig

**Purpose**: a rig that flips one boolean `--argjson` to `--arg` in a throwaway worktree and reports what went red. Every later phase depends on it.

- [X] T001 Create `specs/054-preflight-boolean-guard-proof/mutate.sh` per research R5 and R6 and data-model.md. Usage: `mutate.sh [--final] <commit>`. It: needs `git rev-parse --show-toplevel` to succeed; makes `mktemp -d` and a `trap` that removes only the one worktree it added (`git worktree remove --force <path>`) and that folder; adds the worktree (`git worktree add --quiet --detach <tmp>/wt <commit>`) and never edits a file in it or in the checkout it runs from. Control: `timeout 600 bash "$HOME/bats/bin/bats" --tap pipeline/tests/preflight.bats` run in the worktree, TAP to a file; prints `CONTROL green <plan line>` or exits 1 with `CONTROL red`. Derivation (R5): runs the worktree's `pipeline/scripts/preflight.sh --dir <wt> --base-branch main`, takes `paths(type == "boolean")` of its stdout, maps each path's last key to `$var` through the template's `key: $var` lines, keeps the vars named in an `--argjson <var> "` argument, and exits 1 naming any of `gh adb sk_present sk_in_range sk_const git_usable dirty` missing. Mutants, at most 3 at a time: per var, `cp -R <wt>/pipeline/scripts <tmp>/m-<var>` (the script needs its siblings), `sed` replacing `--argjson <var> "` with `--arg <var> "` in the copy's `preflight.sh`, `cmp` against the worktree's file (unchanged → `NO-OP`), `bash -n` (fails → `BAD`), print the mutated line with `grep -n -- "--arg <var> \""`, then the bats run in the worktree with `PREFLIGHT_UNDER_TEST=<tmp>/m-<var>/preflight.sh`, TAP to a file, `not ok` names collected. After all mutants, `cmp` the worktree's `preflight.sh` against `git -C <wt> show <commit>:pipeline/scripts/preflight.sh` (differs → exit 1). It prints one row per var: `var | fields | verdict | red test names`, verdicts per data-model.md (the walk test is named `no report field is the string "true" or "false"`). Exit: 1 on any `NO-OP`, `BAD`, or failed final `cmp`; with `--final`, 1 on any verdict but `CAUGHT`; else 0. Comments say why each refusal exists (Principle III, research R6). Bash 3.2-safe; passes `shellcheck --norc`.
- [X] T002 Positive controls for `specs/054-preflight-boolean-guard-proof/mutate.sh`, run by hand and recorded in `specs/054-preflight-boolean-guard-proof/measurements.md` under "Rig controls", dated: (a) a copy of the rig whose `sed` pattern matches nothing reports `NO-OP` for every var and exits 1; (b) a copy whose `sed` drops the line's trailing backslash makes `BAD` and exits 1; (c) `git status --porcelain` in the main checkout is byte-identical before and after a full rig run (SC-002). Record each command and its last lines.

**Checkpoint**: the rig is trusted: it fails on a mutation that does not land, and leaves the tree alone.

---

## Phase 2: User Story 1, base table (Priority: P1)

**Goal**: measure which fields have the hole today (FR-008, SC-005).

**Independent Test**: `measurements.md` holds the base table, dated, with commit `86b1973888e053ce903b8d45b3114be73f30bf8d`.

- [X] T003 [US1] Run `bash specs/054-preflight-boolean-guard-proof/mutate.sh 86b1973888e053ce903b8d45b3114be73f30bf8d`; write its control line and every row into `specs/054-preflight-boolean-guard-proof/measurements.md` under "Base table", with the date, the commit and the command. Below the table, name for each `CAUGHT` row the red test whose failing line reads that field (FR-003), and list the `HOLE` vars. If any var other than `sk_present` and `sk_in_range` is `HOLE`, or either of those two is not, say so in the file: the next phase adds an assertion for exactly the `HOLE` vars.

---

## Phase 3: User Story 1, the guards (Priority: P1) 🎯 MVP

**Goal**: every `HOLE` field gets a type assertion, and one walk test covers every field (FR-008, FR-012).

**Independent Test**: `pipeline/tests/preflight.bats` green; its plan line is one more than at the base commit.

- [X] T004 [US1] In `pipeline/tests/preflight.bats`, for each `HOLE` var from T003, add one line `jq -e '.<field> | type == "boolean"' <<<"$output" > /dev/null` to the existing test research R3 names for it (`speckit.present`: "the no-speckit fixture reports the tool absent, exit 0 -- reporting is not failing"; `speckit.versionInRange`: "the web fixture reads version and sh flavour, resolving the bash scripts dir"), directly after its `probe` and `status` lines and before any other line that reads that field. One comment line above each says why a type check and not `jq -r` text, in the words the gh/adb test already uses.
- [X] T005 [US1] In `pipeline/tests/preflight.bats`, add the test `no report field is the string "true" or "false"` directly after the test "capabilities reports jq true and booleans for gh and adb": `probe --dir "$FIX/web" --base-branch main`, `[ "$status" -eq 0 ]`, then `jq -e '[.. | strings | select(. == "true" or . == "false")] | length == 0' <<<"$output" > /dev/null || { echo "string booleans: $(jq -c '[paths(type == "string") as $p | select(getpath($p) == "true" or getpath($p) == "false") | $p]' <<<"$output")"; false; }`. A comment says: it names no field, so a boolean added later is covered (Principle V); it checks how the report is built, and the fixture supplies no string that is `true` or `false` (research R4).
- [X] T006 [US1] Run `bash "$HOME/bats/bin/bats" --tap pipeline/tests/preflight.bats` from the repository root into a file: green, plan line equals the ok count, and equals the base commit's plan line plus 1.

---

## Phase 4: User Story 1, finished table (Priority: P1)

**Goal**: every derived mutant is caught by its own guard and by the walk (SC-001, FR-011).

**Independent Test**: `mutate.sh --final HEAD` exits 0.

- [ ] T007 [US1] Run `bash specs/054-preflight-boolean-guard-proof/mutate.sh --final HEAD` (HEAD holds Phase 3's commit); write its control line and every row into `specs/054-preflight-boolean-guard-proof/measurements.md` under "Finished table", with the date, the commit id and the command. For each row, name the red test whose failing line reads that field. Note that the `gh` mutant also turns `remote.ghPresent` into a string (one variable fills both fields).

---

## Phase 5: User Story 2, no record calls the hole open (Priority: P2)

**Goal**: FR-006. FR-007 is done at the pull request (L), by `Closes #34` in its body.

**Independent Test**: the 013 gap entry reads CLOSED and names this feature.

- [ ] T008 [US2] In `specs/013-preflight-git-probe/spec.md`, "Known gaps, deferred with cause": prefix the entry that starts "**`gh` and `adb` keep the boolean-type hole" with `- **CLOSED by feature 054 (`specs/054-preflight-boolean-guard-proof/`), measured.**` on its own line, in the shape the other two closed entries use, and leave the entry's own text as written. Then `grep -rn -- 'boolean-type hole' specs/ pipeline/ docs/ 2>/dev/null` and confirm no other record calls the hole open (SC-003); record the grep in `measurements.md`.

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 → Phase 3 → Phase 4: each needs the one before (T004 needs T003's `HOLE` list; T007 needs Phase 3 committed).
- Phase 5 depends on nothing but the spec; it runs last so its claim ("measured") is true when written.

## Parallel Opportunities

- Inside the rig, mutants run 3 at a time (`maxParallelAgents`).
- T004 and T005 edit the same file: serial.

## Implementation Strategy

MVP is Phases 1 to 3: the hole is measured and closed. Phase 4 proves it; Phase 5 closes the records.
