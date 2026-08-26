---

description: "Task list for 007-machine-path-guard"
---

# Tasks: the machine path leaves the repository

**Input**: Design documents from `/specs/007-machine-path-guard/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Test tasks ARE included. This feature's product IS a pair of checks,
and the specification requires test-first ordering explicitly (SC-010).

## Format: `[ID] [P?] [Story] Description`

- `[P]` = may run in parallel (different files, no dependency on incomplete work)
- `[US1]`/`[US2]`/`[US3]` = the user story the task serves
- Setup, Foundational and Polish tasks carry no story label

## ⚠️ Three rules that bind every task below

1. **Never write a banned path shape joined** in any file under
   `specs/007-machine-path-guard/`, `main-plan.md`, or anywhere outside root
   `tests/`. These documents live inside the surface the scan reads. Only
   `tests/portability.bats` may spell them literally, because root `tests/` is
   excluded by construction.
2. **Write patterns with an exact-bytes file write, never a shell heredoc.**
   Measured 2026-08-26: the heredoc route silently drops one backslash level and
   reports every branch of the pattern dead. Prove what landed with
   `sed -n '<line>p' <file> | cat -A` before running anything (research R3).
3. **Fire a positive control before believing any clean result.** A scan
   reporting nothing and a scan that has stopped working are the same output.

## Phase 1: Setup — capture the "before", because it is destroyed by Phase 3

- [X] T001 Record the suite baseline by running `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests` from the repository root; capture the plan line and the ok/not-ok counts verbatim into `.delivery-kit/runs/007-machine-path-guard/baseline-suite.txt`. Expect `1..121`, 121 ok, 0 not ok, exit 0.
- [X] T002 [P] Record the "before" scan counts into `.delivery-kit/runs/007-machine-path-guard/baseline-scans.txt`, firing each positive control FIRST and capturing its output too. Build the two Windows shapes from parts (`d=$(printf 'D:%s' '\')`, `c=$(printf 'C:%sUsers%s' '\' '\')`). Expect controls `1 1 1 1`, negative control `0`, and real counts `35`, `1`, `0`, `1`.
- [X] T003 [P] Record the exact file-and-line inventory into `.delivery-kit/runs/007-machine-path-guard/baseline-inventory.txt` — 37 distinct `file:line` pairs across 17 files — so Phase 3's diff can be checked against it line by line.

**Checkpoint**: the "before" state is on disk. After Phase 3 it cannot be re-measured.

## Phase 2: Foundational — build the scan and watch it FAIL

**BLOCKING.** SC-010 requires the scan to be seen red against the un-scrubbed
tree. That evidence is only obtainable before Phase 3, so the scan is built
here rather than inside User Story 2. User Story 2 then makes it trustworthy
and permanent.

- [X] T004 Add the `TREE_PATHS` pattern variable to `tests/portability.bats`, near the existing `BANNED_PATHS` at `:28`, as one extended-regular-expression alternation of four branches: drive root, Windows users prefix, Git-Bash home prefix followed by `[A-Za-z0-9_]`, and agent-projects prefix followed by `[A-Za-z0-9-]`. Assemble it exactly once (FR-010). Do NOT modify `BANNED_PATHS` (FR-022).
- [X] T005 Prove T004's line landed byte-exact: run `sed -n '<line>p' tests/portability.bats | cat -A` and read the backslashes on screen. A missing backslash here makes every later result meaningless (research R3).
- [X] T006 Add the surface enumeration to `tests/portability.bats`: `git ls-files -- . ':(exclude)tests/'`. Do NOT use `git grep` for the scan — it exits 1 for a bad path and cannot distinguish clean from could-not-look (research R1, contract C4).
- [X] T007 Add the non-empty guard to `tests/portability.bats`: fail loudly if the enumeration returns nothing, and print the count it found. An empty operand list turns `grep` into a read of standard input, which reports cleanly on nothing (research R2, contract C6).
- [X] T008 [FR-009, FR-011, FR-015] Add the tree-wide scan check to `tests/portability.bats` as a `@test` with an ASCII-only name, asserting `[ "$status" -eq 1 ]` over the enumerated operands. Never `-ne 0`, never a bare count comparison (contract C4, research R6).
- [X] T009 **Run the scan against the un-scrubbed tree and confirm it FAILS**, naming the offending files. Capture the failure output verbatim into `.delivery-kit/runs/007-machine-path-guard/scan-red-before-scrub.txt`. A green here means the scan is broken and Phase 3 must not start (SC-010).

**Checkpoint**: the scan exists and has been proven capable of failing on the real tree, not a fixture.

## Phase 3: User Story 1 — the maintainer stops publishing their own identity (P1) 🎯 MVP

**Goal**: remove all 37 lines. Delivers the entire privacy value on its own.

**Independent test**: the four scans return zero from a fresh clone, each with
its control fired first.

Every task below is a **token substitution only** (FR-007, ruling 10): the
surrounding word, number, date and line break stay byte-identical. These files
are dated evidence of completed runs, and a record edited for style stops being
evidence. Locate sites with the T002/T003 inventory, never by typing the account
name.

Replacement forms: the test-runner path becomes `bash "$HOME/bats/bin/bats"`
(the spelling `CONTRIBUTING.md:8-9` already documents). A prose path with no
portable equivalent takes the literal four characters `<user>` in place of the
account name. The absolute working-directory path takes `<repo root>`.

- [X] T010 [P] [US1] Scrub `main-plan.md` — 3 lines: two carrying the test-runner path, and the opening Spec line's per-machine agent-projects pointer, which becomes the memory file's basename with no path (FR-006).
- [X] T011 [P] [US1] Scrub `specs/001-pipeline-101-polish/` — 6 lines across 4 files: `plan.md` (1; note this line carries TWO invocations), `quickstart.md` (3 — two test-runner paths plus the `Prerequisites: repo root` absolute drive path, which becomes `<repo root>`), `spec.md` (1), `tasks.md` (1).
- [X] T012 [P] [US1] Scrub `specs/002-constitution-probe/` — 6 lines across 3 files: `plan.md` (1), `quickstart.md` (3), `tasks.md` (2).
- [X] T013 [P] [US1] Scrub `specs/003-implementer-handoff/` — 4 lines across 3 files: `plan.md` (1), `quickstart.md` (2), `tasks.md` (1). **Do NOT touch `tasks.md:103`** — it is an elided reference with no account name, and it is the recorded deferral of this very sweep (FR-008).
- [X] T014 [P] [US1] Scrub `specs/004-implementer-key/` — 3 lines across 2 files: `plan.md` (1), `quickstart.md` (2).
- [X] T015 [P] [US1] Scrub `specs/005-verify-iters-cap/` — 3 lines across 2 files: `plan.md` (1), `quickstart.md` (2).
- [X] T016 [P] [US1] Scrub `specs/006-release-1-1-0/` — 12 lines across 2 files: `quickstart.md` (2, one of which is an elided form that still carries the account name at `:14`), `tasks.md` (10, of which two are temp-directory paths taking `<user>`). **Do NOT touch `quickstart.md:127` or `tasks.md:1219`** — elided, no account name (FR-008). Preserve the `$BATS` → `PATH` → fallback resolution order at `quickstart.md:232`, replacing only the fallback arm.
- [X] T017 [US1] Verify the scan now passes (FR-001, SC-001): run the tree-wide check and confirm it goes from the T009 red to green. Capture into `.delivery-kit/runs/007-machine-path-guard/scan-green-after-scrub.txt`.
- [X] T018 [US1] Review `git diff` line by line against T003's inventory: exactly 37 changed lines across 17 files, and every one differs by a path token alone (FR-001, FR-004, FR-005, FR-007, SC-002). Confirm every test-runner replacement is byte-identical to the spelling `CONTRIBUTING.md:9` already documents (FR-002), and that `specs/006-release-1-1-0/quickstart.md:232` still resolves `$BATS` then `PATH` before its fallback (FR-003).
- [X] T019 [US1] Confirm the three elided references are byte-identical to their previous versions: `specs/003-implementer-handoff/tasks.md:103`, `specs/006-release-1-1-0/quickstart.md:127`, `specs/006-release-1-1-0/tasks.md:1219` (FR-008, SC-003, contract C3).

**Checkpoint**: the account name is gone from the tracked tree. The exposure is closed.

## Phase 4: User Story 2 — the guard that would have caught it exists (P2)

**Goal**: make the Phase 2 scan trustworthy and permanent, not merely present.

**Independent test**: plant a path, watch the suite fail by name; remove it,
watch it pass.

- [X] T020 [US2] Add the positive-control `@test` to `tests/portability.bats`: write a synthetic account-name fixture into the test's own temporary directory, fire **the same `TREE_PATHS` variable** at it, and assert `[ "$status" -eq 0 ]`. Same variable, not a copy and not a re-spelling (FR-010, FR-012, contract C5).
- [X] T021 [US2] Add the comment above T020's control in `tests/portability.bats` stating exactly what it proves — that the scan is CAPABLE of failing — and what it does not prove: that the scan fails only when it should (FR-013). A positive control proves one direction only.
- [X] T022 [US2] Add a SECOND assertion **inside T020's existing control test** in `tests/portability.bats` — do NOT create a third `@test` — firing `TREE_PATHS` at an elided reference (the prefix followed by an ellipsis) and asserting it does NOT match. Two new `@test` blocks total, or the suite lands on 124 and contradicts SC-005. The narrowing is also proven live, because the three real elided references sit inside the scanned surface (FR-014, contract C3).
- [X] T023 [US2] Verify the exit-2 path by hand in `tests/portability.bats`: temporarily point T006's enumeration at a directory that does not exist, run the check, and confirm it FAILS rather than reporting a clean surface. Restore the line and confirm green. Record both outcomes (contract C4, SC-004).
- [X] T024 [US2] Plant a banned path in a tracked file outside root `tests/`, run the suite, confirm it fails and names the file; remove it and confirm green returns. Record both outcomes (SC-004, quickstart section 7).
- [X] T025 [US2] Add the cross-reference comment to the existing `BANNED_PATHS` at `tests/portability.bats:28` naming `TREE_PATHS`, and the matching comment on `TREE_PATHS` naming `BANNED_PATHS`. Each states that they are separate on purpose, cover different surfaces, and that changing one is a prompt to consider the other. Neither may claim they are kept in step automatically, because nothing does that (FR-022, SC-009, contract C7).
- [X] T026 [US2] Confirm `BANNED_PATHS`'s own expression is byte-identical to its previous version — the comment above it may change, the pattern may not (FR-022, FR-023, contract C7).

**Checkpoint**: the guard is proven in both directions and cannot silently switch itself off.

## Phase 5: User Story 3 — the record stops describing a repository that no longer exists (P3)

**Goal**: two records tell the truth about the surface this feature changed.

**Independent test**: read each corrected record against the tree and find no
false statement.

- [X] T027 [P] [US3] Correct the stale comment at `tests/portability.bats:102-114`, then check each of its factual claims against the actual tree and record the check (SC-007) — `ls docs/specs` must fail, `ls docs/handoffs` must succeed, `git ls-files specs/ | wc -l` must be non-zero. Keep the design rationale, which is still valid. Fix only the false facts: `docs/specs` no longer exists (the specs moved to root `specs/`, which IS tracked); `docs/handoffs` does still exist, untracked. Name `TREE_PATHS` as the mechanism that now covers `specs/` for paths, and state that the vocabulary scans still do not (FR-017, FR-018).
- [X] T028 [P] [US3] Amend Campaign 1 ruling 8 in `main-plan.md` with the dated worktree decision: both registrations under `.claude/worktrees/` were removed on 2026-08-26; both branches are KEPT and remain unpushed, being the only carriers of the 221-commit pre-rewrite history, which has no merge base with `main` and includes private commits; verification checks 5-6 are closed by the removal (FR-019). Verbatim text is in the seed at `.delivery-kit/runs/007-machine-path-guard/seed.md`, requirement 8.

**Checkpoint**: no record in the repository makes a false claim about what is scanned.

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T029 [FR-015, SC-006 note] Portability across the three continuous-integration platforms is NOT verifiable locally; it is proven by the matrix after the push gate, and a red there is this feature's to fix. Locally, run the full house suite from the repository root: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`. Expect `1..123`, 123 ok, 0 not ok, 0 non-TAP. Any other number is a finding, not a footnote (SC-005).
- [X] T030 Confirm every new `@test` name is pure ASCII — the suite's own check at `tests/portability.bats:164` fails silently by omission otherwise, which has cost a dead detector here before.
- [X] T031 **Execute** `specs/007-machine-path-guard/quickstart.md` — extract every bash block and RUN it, in order. Do not read it and declare it correct; a shell escape that reads fine can still be broken. Fix the quickstart if any block fails.
- [X] T032 Verify no file this feature produced trips the guard it built: run quickstart section 11 over `specs/007-machine-path-guard/` and confirm every line ends in `0` (FR-021, SC-008).
- [X] T033 Confirm `pipeline/CHANGELOG.md` and `handoff/CHANGELOG.md` are both untouched (`git diff --stat main -- pipeline/CHANGELOG.md handoff/CHANGELOG.md` prints nothing) — no changelog entry belongs to either plugin — this feature changes no behaviour a user can observe (FR-020).
- [X] T034 Confirm no `SHIPPED_ROOT`, `SHIPPED_HANDOFF` or `SHIPPED_PIPELINE` list was widened (FR-016), and that this feature added no banned vocabulary to any scanned surface — `git grep -inE 'flutter|dart|pubspec|supabase|gradle|graphify|speckit|superpowers' -- specs/007-machine-path-guard/ tests/` must return nothing new against `main` (SC-011).

## Dependencies & Execution Order

### Phase dependencies

```
Phase 1 (Setup)          → must finish first; Phase 3 destroys what it measures
Phase 2 (Foundational)   → BLOCKS Phase 3; T009's red is unobtainable afterwards
Phase 3 (US1)            → depends on Phase 2
Phase 4 (US2)            → depends on Phase 2 (extends the same file)
Phase 5 (US3)            → depends on Phase 3 for main-plan.md ordering
Phase 6 (Polish)         → last
```

### The one deviation from priority order, and why

The template puts user stories in priority order, and the scan (User Story 2)
would normally follow the scrub (User Story 1). It does not here. SC-010
requires the scan to be **seen failing against the real un-scrubbed tree**, and
that evidence is destroyed the moment Phase 3 lands. So the scan itself moves
into Foundational, and User Story 2 keeps everything that makes it trustworthy:
the control, the narrowing fixture, the exit-2 proof, the plant-and-remove
demonstration, and the cross-reference comments.

User Story 1 still stands alone as the MVP — the scrub closes the exposure with
or without the rest.

### File-level serialisation

`tests/portability.bats` is touched by T004, T006, T007, T008, T020, T021,
T022, T025 and T027. **Never two agents on that file at once.** Everything in
Phase 2 and Phase 4 that names it runs serially.

`main-plan.md` is touched by T010 (Phase 3) and T028 (Phase 5). Phase ordering
already serialises them.

### Parallel opportunities

- Phase 1: T002 and T003 together.
- Phase 3: T010 through T016 are seven disjoint file sets — all `[P]`, capped at
  three concurrent agents.
- Phase 5: T027 and T028 touch different files — both `[P]`.

## Parallel Example: Phase 3

```
# Three agents, disjoint file sets, no shared file:
agent 1 → T011  specs/001-pipeline-101-polish/   (4 files, 6 lines)
agent 2 → T012  specs/002-constitution-probe/    (3 files, 6 lines)
agent 3 → T016  specs/006-release-1-1-0/         (2 files, 12 lines)
# then T010, T013, T014, T015 in the next batch.
```

## Implementation Strategy

**MVP is User Story 1**, but it cannot be proven without Phase 2. The smallest
honest increment is therefore Phase 1 → Phase 2 → Phase 3, which closes the
exposure and demonstrates that the closure is real.

**Stop rule**: a red the T001 baseline does not carry is a full stop. Report it;
never mark a task `[X]` past it. An inherited red is reported, never owned.

**Do not commit.** Phase K of the pipeline stages and commits, by name, after
the gate. Leave everything uncommitted.

## Notes

- The counts in this file are measurements taken 2026-08-26 at `b819a4c`, not
  estimates: 37 lines, 17 files, 132 files enumerated, 121 checks rising to 123.
  An earlier draft said 36 lines across 18 files; that was wrong because the
  drive-root file and the agent-projects file are both already inside the 17.
- `git grep` appears in the quickstart for convenience at a prompt. It must not
  appear in the suite — see research R1.
