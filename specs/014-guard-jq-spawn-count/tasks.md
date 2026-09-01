---

description: "Task list for 014-guard-jq-spawn-count"
---

# Tasks: The context guard stops counting jq

**Input**: Design documents from `/specs/014-guard-jq-spawn-count/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/extraction.md](./contracts/extraction.md),
[quickstart.md](./quickstart.md)

**Tests**: **No test tasks, deliberately.** The acceptance criteria fix the suite
size and forbid editing the hook's own suite. Every claim this change makes is
verified by a measurement recorded in the run or by an existing test staying
green. Adding a test here would break the acceptance it is meant to support.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel — different files, no dependency on incomplete work
- **[Story]**: which user story the task serves
- Every task names the exact files it touches

## Path Conventions

- the hook: `handoff/hooks/context-guard.sh`
- the tripwire suite, NEVER edited: `handoff/tests/context-guard.bats`
- changelog: `handoff/CHANGELOG.md`

---

## Phase 1: Setup — measure everything BEFORE touching anything

Each of these produces a number that cannot be recovered later. Do them first.

- [X] T001 Record the pre-change suite baseline. Run the full house suite from
      the repository root, redirecting to a file — never a pipe, which hands the
      block `tail`'s status and cuts the plan line. Record the plan line, the
      `ok` count and the `not ok` count. Do NOT read the number from the seed:
      it says `1..162` and is stale by the test Phase 13 added.
- [X] T002 Record the pre-change jq counts on all three configuration paths,
      using the counting rig in [quickstart.md](./quickstart.md) step 1. Expect
      8 / 12 / 16 whole-run. Confirm the shim counts one token per INVOCATION,
      not per line — two jq programs span several lines and a line-counting shim
      reports nearly double.
- [X] T003 [P] Record the hook's comment inventory before the change:
      `grep -cE '^[[:space:]]*#' handoff/hooks/context-guard.sh`, plus the
      file's line count. FR-009 is checked against this. Use `[[:space:]]`, not
      `\s`: many comments in this file are indented, and `\s` is a GNU extension
      that matches nothing on the macOS runner — a pattern that scans nothing
      and a pattern that finds nothing report the same number.
- [X] T004 [P] Run the two probes in [quickstart.md](./quickstart.md) steps 2
      and 3 and keep the output verbatim. They compare jq EXPRESSIONS — today's
      extraction against both candidate spellings — not the hook itself. They
      are the evidence that the seed's suggested spelling is unusable, and
      review rounds will ask for it.

---

## Phase 2: Foundational

None. The change is two local rewrites inside one existing file.

---

## Phase 3: User Story 1 — the guard costs less per tool call (Priority: P1)

**Goal**: one helper invocation per source instead of one per field.

**Independent test**: the counts in T002 fall on all three paths.

- [X] T005 [US1] Edit `handoff/hooks/context-guard.sh`: after the availability
      check, add ONE jq invocation extracting all four payload fields, joined by
      the unit separator written as a jq escape, captured with `$()` and split
      with `IFS=$'\037' read -r`. Preserve every default exactly, including the
      `unknown` placeholder for the session identifier, which moves into the jq
      program. Place it BEFORE the subagent check, which now reads the extracted
      variable. Add a comment stating why the separator is not a tab, naming the
      measured consequence — this is the single most deletable line in the
      change and the one whose removal is most dangerous.
- [X] T006 [US1] In the same file, remove the three now-redundant assignments
      and make the subagent check test the extracted variable. Leave the
      configuration-precedence comment block exactly where it is: it explains
      precedence, not extraction, and moving it would lose its context. Same
      file as T005, so strictly sequential after it.
- [X] T007 [US1] In the same file, replace `read_config`'s four per-file jq
      calls with one, split the same way, applying `tostring` after the empty
      default so numbers join predictably on a jq older than this machine's.
      Keep the early return for a missing file as the function's first act.
      Sequential after T006.
- [X] T008 [US1] Re-run the counting rig. Expect 5 / 6 / 7 whole-run, and 2 / 3
      / 4 for the pre-transcript slice. Record BOTH columns — quoting only the
      slice would flatter the result.

---

## Phase 4: User Story 2 — nothing the guard does changes (Priority: P1)

**Goal**: identical behaviour, proven rather than asserted.

**Independent test**: the hook's own suite passes with an empty diff.

- [X] T009 [US2] Run `handoff/tests/context-guard.bats` and confirm green, then
      run `git diff --stat -- handoff/tests/context-guard.bats` and confirm it
      is EMPTY. A test that needed editing is proof the behaviour changed —
      stop, do not edit the test.
- [X] T010 [US2] Build the equivalence matrix required by SC-004: for each of
      the eight fields, compare the value the old extraction yields against the
      new one, byte for byte, across inputs covering present, absent, `null` and
      empty-string. Record the table. A single mismatch is a stop.
- [X] T011 [US2] Run the two probes from T004 again, this time with the exact
      expressions the CHANGED hook uses, and confirm the main-session payload
      still proceeds and the subagent payload still exits — SC-005, demonstrated
      directly rather than inferred from the suite. Then drive the real hook
      once with each payload and confirm the same two outcomes, because the
      probes test expressions and only the hook tests the hook.

---

## Phase 5: User Story 3 — the record survives (Priority: P2)

- [X] T012 [US3] Compare the comment inventory against T003, and read every
      removed comment line:
      `git diff -- handoff/hooks/context-guard.sh | grep -E '^-[[:space:]]*#'`.
      The `[[:space:]]*` is load-bearing — an `^-#` anchor misses every indented
      comment and reports a comfortable zero. Comments may move; the record must
      not shrink. Justify any removal line by line, or restore it.
- [X] T013 [US3] Confirm every named failure is still reported: the missing-tool
      hint, the misconfigured-window note and its lower bound. Grep for each in
      the changed file. A refactor that turns a named failure into silence is a
      regression even with the suite green.

---

## Phase 6: Polish and cross-cutting

- [X] T014 [P] Add a `### Changed` entry to `handoff/CHANGELOG.md` under the
      existing `## [Unreleased]` heading, naming the reduction and stating that
      behaviour is unchanged. Report BOTH count columns. This surface has a
      restricted vocabulary and states no count that a later change falsifies —
      the process counts are a measurement of this change, not a running total,
      which is the distinction that makes them safe to write.
- [X] T015 Analyse the changed file the way CI does:
      `shellcheck --norc -f gcc` over the discovered shell files. CI runs an
      OLDER analyser than this machine and the older one reports more, so a
      local green is evidence, not proof.
- [X] T016 Run the full house suite from the repository root. Expect the SAME
      plan line as T001, `not ok` count `0`, `0` non-TAP lines, exit `0`.
- [X] T017 Execute [quickstart.md](./quickstart.md) — run every block, do not
      read it. A block that reads fine and does not run is the defect this task
      exists to catch, and this feature's quickstart carries a shell rig that
      has already been wrong once.

---

## Dependencies

```text
T001, T002        (T002 needs the rig; both must precede any edit)
T003, T004        (parallel with each other, read-only)
   ↓
T005 → T006 → T007     ← all one file, strictly sequential
   ↓
T008  (counts fall)
   ↓
T009, T010, T011  (T009 and T010 parallel; T011 after T010)
   ↓
T012, T013        (parallel — different checks, neither writes)
   ↓
T014, T015        (parallel — different files/commands)
   ↓
T016 → T017
```

**The orderings that cannot be relaxed**: T001 and T002 before T005 — a
before-number is unobtainable once the code changes. T009 before anything that
might tempt an edit to the suite.

## Parallel opportunities

| Batch | Tasks | Why safe |
|---|---|---|
| A | T003, T004 | two read-only measurements of different things |
| B | T009, T010 | a suite run and a comparison; neither writes the hook |
| C | T012, T013 | two read-only greps |
| D | T014, T015 | changelog write and an analyser run, different targets |

T005, T006 and T007 all edit one file and must never overlap.

## Implementation strategy

No MVP split. User Story 1 alone would ship a faster guard with no proof it
still works, and User Story 2 alone ships nothing. The value is the pair.

Order: Phase 1 → 3 → 4 → 5 → 6, exactly as numbered.
