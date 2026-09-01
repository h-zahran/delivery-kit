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
      the unit separator ~~written as a jq escape~~, captured with `$()` and
      split with ~~`IFS=$'\037' read -r`~~. **← BOTH STRUCK SPELLINGS ARE
      SUPERSEDED BY T018 AND T020. DO NOT IMPLEMENT THEM.** The separator is
      defined once as `US=$'\037'` and handed to jq with `--arg`, so no escape
      appears in the jq source; the split is parameter expansion, because `read`
      stops at the first newline and silently drops every field after it.
      `contracts/extraction.md` forbids `read` here by name.
      Preserve every default exactly, including the
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
      calls with one, split the same way — which, per T005's superseded note, is
      **parameter expansion and never `read`** — applying `tostring` after the
      empty default so numbers join predictably on a jq older than this
      machine's.
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
      run `git diff --stat 45e6b12 -- handoff/tests/context-guard.bats` and confirm it
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
      `git diff 45e6b12 -- handoff/hooks/context-guard.sh | grep -E '^-[[:space:]]*#'`.
      **Pin the baseline to that commit id.** A bare `git diff` compares the
      WORKING TREE, so once this work is committed the diff is empty and the
      check reports a comfortable zero having scanned nothing — measured after
      `640e99d`: 0 lines of diff, count 0. Against `45e6b12` the diff is 120
      lines and the count is still 0, which is the real answer.
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

---

## Phase 7: Convergence — review round 1 found two real regressions

Added during phase M. `/code-review` at high effort built a differential harness
and found that the change as first committed (`765ce87`) was **not** behaviour-
preserving, in two ways the suite could not see. Both were reproduced
independently before being acted on.

- [X] T018 Fix the truncation. `read` consumes only the FIRST line, while the
      per-field `$()` it replaced captured all of them, so a JSON string value
      containing a newline truncated the result and silently dropped every field
      after it. Measured: `windowTokens` of `"5\n999999"` lost the threshold, the
      token cap and the byte cap; the committed hook reported the default 45%
      where the pre-change hook reported the configured 50%. Replaced `read`
      with parameter expansion, which splits on the separator alone and leaves
      embedded newlines inside their field, exactly as `$()` did.
- [X] T019 Fix the abort. The payload jq program lacked the `map(tostring)` the
      configuration program already had, so a field of an unexpected type made
      jq exit 5, leaving the payload empty, the transcript empty and the guard
      silent — the one direction this hook must never fail in. Measured with a
      `cwd` that is an object. Added `map(tostring)`.
- [X] T020 Collapse the separator to ONE definition. It had been hard-coded in
      four places in two spellings; a merge resolving one hunk and not the other
      would leave jq joining on one byte and the shell splitting on another.
      Now `US=$'\037'` once, handed to jq with `--arg`. This also removes the
      `\u` escape from the source, which six separate tools had by then silently
      decoded into a raw control byte.
- [X] T021 Re-prove behaviour is unchanged with a purpose-built differential:
      the PRE-CHANGE hook from `origin/main` against the fixed hook, over 26
      payload and configuration shapes including both regression cases, nulls,
      leading zeros, out-of-range values, string numbers, booleans, an object
      `cwd`, a missing transcript and an empty payload, comparing stdout and
      exit code. **26 identical, 0 different.**
- [X] T022 Re-run the counting rig, the hook suite, the full house suite and the
      analyser against the fixed hook. **Done 2026-09-01.** Hook suite `1..58`,
      0 failures, and `git diff --stat` on `handoff/tests/context-guard.bats`
      empty. House suite `1..163`, 0 failures. `shellcheck --norc` 0.11.0 clean
      over all 5 tracked shell files, the hook among them. Counting rig from
      `quickstart.md` step 1: **5 / 6 / 7** jq invocations for zero, one and two
      configuration files — the target, unchanged by the fix.
- [X] T023 Correct the documents review findings 3 and 5 called out: the
      changelog's unqualified "behaviour is unchanged" claim, and the
      data-model / contract wording that states a single-line, no-carriage-return
      guarantee the implementation does not enforce. **Done 2026-09-01**, and
      the scope was extended — see below.

**T023's scope was extended, deliberately and on evidence.** Findings 3 and 5
named three files. A grep for every copy of the claims found that T018's fix had
*also* falsified `plan.md`, `research.md` and `quickstart.md`, which still
specified `IFS=$'\037' read -r` as the splitter. The reviewer could not have
flagged those — they were accurate when the review ran, and the fix is what made
them stale. Leaving them would have had the next reader rebuild the regression
from the plan. The eight files and what changed:

| File | Change |
|---|---|
| `handoff/CHANGELOG.md` | the flat "behaviour is unchanged" claim replaced by what was measured (the 26-shape differential), plus the two regressions it caught |
| `specs/…/data-model.md` | split described as parameter expansion, not `read`; the carriage-return "guarantee" narrowed to what the capture enforces; a new rule for `map(tostring)` |
| `specs/…/contracts/extraction.md` | "One behaviour difference" → "Two hazards the join creates"; the newline hazard named, and `read` forbidden as the splitter |
| `specs/…/plan.md` | insertion-point table corrected; the here-string paragraph replaced (no here-string ships); `read` named as superseded |
| `specs/…/research.md` | dated "Amended"/"Superseded in part" notes under Decisions 1 and 2 and Finding C — appended, never rewritten, because they are dated decision records |
| `specs/…/quickstart.md` | §4 retitled and narrowed; a runnable block added that pins the embedded-newline case. **Extracted and executed**, not just written: field 1 keeps `p \r \n q`, field 2 keeps `z` |
| `specs/…/tasks.md` | this record |
| `handoff/hooks/context-guard.sh` | T018–T020's fix, unchanged since |

Two measurements were taken here rather than inherited, because the old wording
turned on them: `jq` emits `\r\n`, and `$()` under MSYS2 bash strips **both**
trailing bytes — so the original CR claim was right about the trailing case and
wrong as a general guarantee, since a newline *inside* a value arrives as `\r\n`
in that field. Both re-measured 2026-09-01.
- [X] T024 Commit and push the fix. **Done** — `640e99d`, pushed to PR #37,
      CI 5/5 green (version agreement, tests on ubuntu/macos/windows, shell
      analysis). Phase M then continued into round 2; see Phase 8.

**Not addressed, and each needs a decision rather than typing:**

- ~~Review finding 4 — nothing pins the positional parsing, so changing the
  separator or reordering either jq array leaves the whole suite green while
  installing the wrong setting.~~ **FALSIFIED BY MEASUREMENT, 2026-09-01 — see
  Phase 9.** The suite does not stay green: every transposition of both arrays
  turns it red. This paragraph is left struck rather than deleted because the
  round-1 and round-2 reviews both rested on it.
- Review finding 7 — `input=$(cat)` plus `printf | jq` is a two-process detour
  for a value with one consumer, on the very metric this change exists to
  reduce. In scope by subject, but it changes stdin handling on the
  jq-missing path, which a behaviour-preserving refactor should not do casually.
- Review finding 8 — the transcript path still spends three jq calls and a
  `grep`, and is the larger half of the available win. Out of scope for this
  seed; a good next phase.

---

## Phase 8: Convergence — review round 2 found no code defect, three doc defects

`/code-review` at high effort, round 2 of the `maxReviewRounds` 3 cap, against
`640e99d`. **No correctness bug in the hook.** The reviewer built its own
29-shape differential independently of ours and reached the same verdict — all
identical in stdout and exit code, including the firing path — and separately
confirmed the CRLF behaviour, the jq `// "" | tostring` precedence, that a raw
`0x1F` survives MSYS2 argv conversion to the native `jq.exe`, and that no raw
`0x1F` byte has leaked into any tracked file.

- [X] T025 Correct the one copy of the forbidden spelling that T023's sweep
      missed: **this file's own task text.** T005 prescribed
      `IFS=$'\037' read -r` and T007 said "split the same way", both still
      marked `[X]`. This repo drives implementation from task lists, so a
      resumed `speckit-implement` or `speckit-converge` reading T005 as the
      specification would re-emit `read` and rebuild the newline-truncation
      defect, with all 163 tests staying green. Struck inline with an explicit
      "DO NOT IMPLEMENT" marker rather than deleted, so the record survives.
- [X] T026 Correct `quickstart.md` sections 2 and 3, whose "candidate" blocks
      demonstrated `IFS="$US" read` and the `join("\u001f")` source escape as
      **correct** — both removed from the hook by T018 and T020. Neither fixture
      contains a newline, so both blocks passed and endorsed the construct the
      contract now forbids: a positive control proving only the direction that
      flatters it. Rewritten to the shipped spelling (`--arg US`, parameter
      expansion), and **executed, not merely edited** — every bash block in the
      file was extracted and run.
- [X] T027 Fix a false green found while executing those blocks, which review
      did not flag. Sections 7 and 5, and T012 and T009 here, ran
      `git diff -- <path>` with no baseline. That compares the WORKING TREE, so
      the moment this work was committed the diff became empty and the
      comment-survival check reported a comfortable **0 of 0** — scanning
      nothing and finding nothing print the same number. Measured at `640e99d`:
      unpinned diff 0 lines, count 0; pinned to `45e6b12`, diff 120 lines, count
      still 0, which is the real answer. Positive control: the reversed diff
      finds **62** removed comment lines, so the check can go red. All four
      sites now pin `45e6b12`. A branch name would not have fixed it — once this
      merges, `main` is where the change ARRIVED and the diff empties again.
- [X] T028 Re-verify and re-commit after T025–T027.

**Still open after round 2, and each needs a decision rather than typing** —
carried unchanged from round 1, and round 2 re-raised the first of them:

- ~~**Finding 4 / round 2's third finding** — nothing executable pins the field
  order, the separator byte, or the splitter, for either jq array. Reordering
  one array (say `.maxBytes` ahead of `.thresholdTokens`) installs the byte cap
  as the token threshold; every value is a positive integer, so it passes
  validation, the guard fires at 10,000 tokens instead of 650,000, and all 163
  tests stay green.~~ **CLOSED — the last sentence is false, and Phase 9 below
  gives the measurement. `.maxBytes` ahead of `.thresholdTokens` is the
  reviewer's own example, and it turns five named tests red.** Struck rather
  than deleted: two review rounds rested on this claim and the record of that
  should survive its correction.
- **Finding 7** — `input=$(cat)` plus `printf | jq` is a two-process detour for
  a value with one consumer, on the very metric this change exists to reduce.
  In scope by subject, but it changes stdin handling on the jq-missing path.
- **Finding 8** — the transcript path still spends three jq calls and a `grep`,
  and is the larger half of the available win. Out of scope for this seed.

---

## Phase 9: Finding 4 is closed by falsification, not by a test

The owner approved adding a test to close review finding 4. Building it
falsified the finding, so **no test was added and the suite stays at 163.**

- [X] T029 Write the candidate tripwire (two tests, one per jq array, in a NEW
      file so `context-guard.bats` stays unedited) and confirm it green against
      the real hook. Done; the file is preserved, unused, at
      `docs/tools/context-guard-field-order.bats.candidate`.
- [X] T030 Prove it by mutation before trusting it — the whole point being that
      a test which cannot go red is worth nothing. Built a rig covering **every
      transposition of both jq arrays**, twelve in total, run inside a detached
      git worktree so the real working tree is never touched.
- [X] T031 **The finding is false.** The existing 58-test suite goes RED on all
      twelve. Hand-verified twice, because an aggregate is not proof:

      | Reorder | What the EXISTING suite does |
      |---|---|
      | `.thresholdTokens` <-> `.maxBytes` — the reviewer's own example | 5 red: tests 21, 32, 33, 35, 58 — exactly the right ones |
      | `.session_id` <-> `.cwd` — the subtlest, and the one this change created | **46 of 58 red**, including test 24 |

      The positional coupling is pinned **emergently**: every configuration
      setting and every payload field already has a dedicated behavioural test
      asserting its observable effect, so a reorder cannot move a value without
      moving an assertion. That is stronger evidence than the candidate test
      would have added, and it costs no seed override.
- [X] T032 Record the result and delete nothing. The rig, its output table and
      the unused candidate test live in `docs/tools/` (git-excluded, so they
      survive the session without reaching the public repository), and the two
      copies of the falsified claim above are struck in place rather than
      removed.

**Two rig defects worth carrying forward, both of which produced false
evidence before they were found:**

1. **The first rig edited the real hook in place, and its 10-minute timeout
   orphaned it.** The wrapper was killed; the script kept running and
   re-mutated the tracked file twice, unnoticed. Found by hashing the hook,
   killed by PID, restored from a saved copy — never `git checkout --`.
   **A mutation rig belongs in a worktree.**
2. **It also dropped the newline when splicing the replacement line**, fusing
   it with the next one. Every "mutant" was a syntactically broken script, so
   every suite failed and the table read as a clean sweep of catches. **Gate
   every mutant on `bash -n` before running anything**, or a broken script
   reads as a working tripwire.

**Still open, deferred by the owner to a later phase:**

- **Finding 7** — `input=$(cat)` plus `printf | jq` is a two-process detour for
  a value with one consumer, on the very metric this change exists to reduce.
  In scope by subject, but it changes stdin handling on the jq-missing path.
- **Finding 8** — the transcript path still spends three jq calls and a `grep`,
  and is the larger half of the available win. Out of scope for this seed.

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
