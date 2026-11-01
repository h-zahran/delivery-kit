# Tasks: Every prose slice is guarded, and the slice helper's guards are tested

**Input**: Design documents from `specs/046-prose-slice-guards/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/prose-helpers.md, quickstart.md

**Tests**: this feature IS tests. The guard tests (US2) and the refusing test (US3) are the deliverable, not optional extras.

**Organization**: every code task edits the one file `pipeline/tests/prose.bats`, so no two tasks can run in parallel; tasks are strictly ordered. Each phase leaves `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` green.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (none here: one file)
- **[Story]**: US1, US2, US3 from spec.md

## Phase 1: Foundational — the helpers take a file and declared lines

**Purpose**: give `prose_slice` its new contract and add `prose_flat`, without changing any haystack. Blocks every story.

- [X] T001 In `pipeline/tests/prose.bats`, add `prose_flat()` directly above `prose_slice()`: reads stdin, runs `tr -d '\r' | tr '\n' ' ' | tr -s ' '`, takes no arguments; comment it per contracts/prose-helpers.md (why stdin: callers keep `<` for whole documents, which must never go through a herestring). Change the flat branch at the end of `prose_slice` to `prose_flat <<<"$s"`.
- [X] T002 In `pipeline/tests/prose.bats`, change `prose_slice` to `prose_slice <file> <open-ere> <close-ere> <raw|flat> <name> [<declared-line>...]`: arity becomes "at least 5" (message names the count), every `$ORCH` inside the helper becomes the `<file>` argument, the unreadable-file message names `<file>` (not "the orchestrator"), and the header comment's usage line matches. Keep every other guard and comment's meaning; update comments that say "the orchestrator" or "$ORCH" where they now mean the file argument.
- [X] T003 In `pipeline/tests/prose.bats`, add declared-line support to `prose_slice`'s inner-heading check: remove each inner line that equals a declared line exactly (whole line, fixed string — `grep -vxF` with one `-e` per declared line, or an equivalent that admits only identical lines) before testing for `^\*\*|^#{1,6} `; with no declared lines the check is unchanged. Comment why a prefix match is refused (research R2).
- [X] T004 In `pipeline/tests/prose.bats`, insert `"$ORCH"` as the first argument of every existing `prose_slice` call, with a script that counts the calls before and after and refuses to write unless every call matched once (no call left in the old 4-argument shape); echo the count. Run `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` and confirm the plan line equals the ok count (68 at `f72276c`).

**Checkpoint**: helpers in their new shape; suite unchanged and green.

---

## Phase 2: User Story 1 — every slice is guarded (Priority: P1) 🎯 MVP

**Goal**: all 13 bare `awk '/open/,/close/'` range sites go through `prose_slice`, so a renamed boundary turns red.

**Independent Test**: `grep -nE "awk '/[^']*/,/" pipeline/tests/prose.bats` prints nothing; renaming `**H — implement.**` or `**Base branch:**` in a scratch worktree turns prose.bats red with a boundary message (quickstart §3).

- [ ] T005 [US1] In `pipeline/tests/prose.bats`, convert the two G→H slices (tests "the handoff package names its seven parts" and "the G pre-answer contract is pinned sentence by sentence") to `prose_slice "$ORCH" '^\*\*G — implementer gate\.\*\*' '^\*\*H — implement\.\*\*' raw '<name>' || return 1`, keeping each test's pins byte-for-byte; in the seven-parts test remove the hand-rolled head/tail guards the helper now covers, and in the pre-answer test flatten the held slice with `prose_flat <<<"$g"`.
- [ ] T006 [US1] In `pipeline/tests/prose.bats`, convert the five pre-flight walk slices (`^The script only reports; the decisions are yours` → `^\*\*Base branch:\*\*`, in the tests "the implementer key's consent surface is pinned outside the G slice", "the git stop is pinned in both surfaces a reader meets it in", "the gate floor counts the review question, and every commit names every path", "a tracked state file stops a re-entry, and a plain-string gates.G takes the review answer" and "each rare path's old site still sends the run to its section") to `prose_slice "$ORCH" … raw|flat 'pre-flight walk' '<the exact **Read item 11 before item 1.** line>'`, keeping each test's form (raw where the old code kept lines, flat where it flattened) and pins byte-for-byte; remove each site's hand-written empty/close checks the helper now covers, and the comment that says the walk "keeps the awk range" because the helper refuses it — replace it with one line saying the bold line is declared.
- [ ] T007 [US1] In `pipeline/tests/prose.bats`, convert the two probe-block slices (`^Project type : ` → `^Will skip `) and the one `^Will skip ` → `^The script only reports; the decisions are yours` slice to `prose_slice "$ORCH" …`, keeping each form and pin byte-for-byte.
- [ ] T008 [US1] In `pipeline/tests/prose.bats`, convert the three `pipeline/docs/configuration.md` slices (`^## Resolving the layers$` → `^## Keys$` twice; `^## The Implementer line$` → `^## The state directory$` once, declaring its `**Implementer:** …` line) to `prose_slice "<that file>" … flat '<name>' [declared line]`, keeping pins byte-for-byte; remove the hand-written empty check the helper now covers.
- [ ] T009 [US1] Run `grep -nE "awk '/[^']*/,/" pipeline/tests/prose.bats` (expect no output) and `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` (expect green, plan line = ok count).

**Checkpoint**: US1 complete; every slice guarded.

---

## Phase 3: User Story 2 — the helper's guards are proven to fire (Priority: P2)

**Goal**: one committed test per guard (research R4).

**Independent Test**: each new test passes; deleting its guard in a scratch worktree turns it red (T019).

- [ ] T010 [US2] In `pipeline/tests/prose.bats`, add a fixture function (in the helpers region, below `prose_slice`) that writes a small document into `$BATS_TEST_TMPDIR` with known `## Open`, body, `## Close` lines and returns its path; then add tests, each using `run --separate-stderr prose_slice …` and asserting `[ "$status" -eq 1 ]` plus the guard's own message words on `$stderr`: (a) arity — 4 arguments; (b) form — `falt`; (c) unreadable — a missing path, message names the path; (d) unreadable — a directory, message names the path.
- [ ] T011 [US2] In `pipeline/tests/prose.bats`, add tests, same shape: (e) empty — an opener matching nothing; (f) duplicate opener — a fixture with the opener twice; (g) unterminated — a closer matching nothing, message says UNTERMINATED; (h) undeclared inner heading — a fixture with `**Note.**` inside, message prints that line.
- [ ] T012 [US2] In `pipeline/tests/prose.bats`, add a test that a declared inner line is admitted (status 0, slice printed) and that, with the same declaration, a second undeclared heading-shaped line in the slice still fails with status 1 and is named; add a test that `prose_flat` turns `"a\r\nb  c\n"` into exactly `a b c ` (bytes compared).
- [ ] T013 [US2] Run `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats`: green, plan line = ok count = 68 + the tests added.

**Checkpoint**: US2 complete.

---

## Phase 4: User Story 3 — one flatten, and no inline copy can return (Priority: P3)

**Goal**: every flatten site uses `prose_flat`; a test refuses new inline copies (research R3, R5).

**Independent Test**: `grep -n "tr '\\\\n' ' '" pipeline/tests/prose.bats` shows only `prose_flat`'s body; adding one inline copy or bare range to a scratch copy turns the refusing test red naming the line.

- [ ] T014 [US3] In `pipeline/tests/prose.bats`, replace every remaining inline flatten with `prose_flat`, keeping each site's input mode (`< "$file"`, `<<<"$var"`, or a pipe after the site's own `sed 's/^> //'` or awk step) and any post-step (`sed 's/ $//'`), and dropping a now-redundant `tr -d '\r'` before it; include the split-line site whose `'\n'` is a literal newline. Do it with a script that counts sites before and after and refuses to write on a mismatch; echo both counts.
- [ ] T015 [US3] In `pipeline/tests/prose.bats`, add the refusing test per contracts/prose-helpers.md: walk this file with awk, skip only the bodies of `prose_slice()` and `prose_flat()` (from the `name() {` line to the next line that is exactly `}`), fail naming each line holding a bare range with a named closer or an inline flatten (one-line or the split shape); print the number of lines walked; fail when it is zero or when either helper body was not found. Build its needles from parts so its own source does not match them.
- [ ] T016 [US3] Run `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats`: green, plan line = ok count.

**Checkpoint**: all stories complete.

---

## Phase 5: Polish — prove it (records only)

**Purpose**: the measurements the constitution requires (FR-004, FR-009, SC-002, SC-006). Writes only `specs/046-prose-slice-guards/differential.md`; every mutation runs in a scratch git worktree, never the main checkout.

- [ ] T017 Write the byte-identity differential (research R6) into `specs/046-prose-slice-guards/differential.md`: for every converted site, evaluate the old haystack expression (from `f72276c`) and the new one against the current documents, `cmp` them, and record site, byte count and result, with the date and both commits. Every row must say identical.
- [ ] T018 Run the boundary-rename sweep (research R7) in a scratch worktree: derive each distinct boundary from the `prose_slice` calls in `pipeline/tests/prose.bats`, rewrite that line in its document, echo the mutated line, run prose.bats, record red/green, restore, confirm the restore; append the table to `specs/046-prose-slice-guards/differential.md`. Every boundary must go red.
- [ ] T019 Run the positive controls (FR-009) in a scratch worktree: for each tested guard in `prose_slice`, remove its condition, echo the change, run prose.bats, confirm that guard's test goes red; add one inline flatten and one bare range and confirm the refusing test goes red naming each line; append the table to `specs/046-prose-slice-guards/differential.md`.
- [ ] T020 Measure SC-006: run prose.bats three times at `f72276c` and three times on this branch, alternating, on this machine; append the wall times and the growth to `specs/046-prose-slice-guards/differential.md`. Growth must be ≤ 25%.

---

## Dependencies & Execution Order

- Phase 1 blocks everything (new helper signature).
- Phase 2 (US1) depends on Phase 1 (declared lines, file argument).
- Phase 3 (US2) depends on Phase 1 only; it is ordered after US1 because both edit the same file.
- Phase 4 (US3) depends on Phases 1-3: the refusing test must see no bare range left (US1) and must not flag the guard tests' fixtures.
- Phase 5 depends on all of the above.

## Parallel Opportunities

None in the code: every task edits `pipeline/tests/prose.bats`. In Phase 5, T018-T020 use separate scratch worktrees and could run side by side, but all three append to `differential.md`, so they are serialised.

## Implementation Strategy

MVP is Phase 1 + Phase 2 (US1): it closes the silent hole the issue is about. US2 and US3 then harden it. Commit per phase (one piece each).
