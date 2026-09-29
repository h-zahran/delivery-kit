# Tasks: progress.sh learns commits and pieces

**Input**: Design documents from `specs/018-progress-commits-pieces/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/progress-commands.md, quickstart.md

**Tests**: REQUIRED. The spec's SC-001 and SC-002 demand a test per refusal and per good case, each shown RED against the unchanged script before it is shown green.

**Run directory**: `.delivery-kit/runs/018-progress-commits-pieces/` (ignored by git) holds every saved output below.

## Format: `[ID] [P?] [Story] Description`

## ⚠️ Three rules that override anything below

1. **Red first, by message.** A refusal test that checks only a non-zero exit passes against the UNCHANGED script, because an unknown command already exits 1 (research R8). Every refusal test asserts the diagnostic text from `contracts/progress-commands.md` AND that the state file is byte-identical (`cmp` against a copy taken before the call).
2. **No CR reaches stdout.** `piece-next` prints through `printf` from values captured with `$()`, never jq's own multi-line output (research R1).
3. **Red-first runs and mutations happen in a SCRATCH TREE, never in the checkout.** A scratch tree is a fresh `mktemp -d` directory holding copies of `.claude-plugin/`, `tests/` and `pipeline/`, initialised with `git init -q` — the suite's `find_root` (`tests/helper.bash`) accepts any git checkout with `.claude-plugin/marketplace.json` at its top, so no test needs an override. Replace the scratch copy's `pipeline/scripts/progress.sh` with `progress.sh.orig` for a red run, or with a mutant for T016. Echo the replaced file's first differing line before trusting any result.

---

## Phase 1: Setup

- [X] T001 Run the house suite from the repository root and save its verbatim output to `.delivery-kit/runs/018-progress-commits-pieces/baseline-suite.txt`: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`. Expect `1..170`, 170 ok, 0 not ok, 0 non-TAP lines, exit 0. **If the count is not 170, stop and report** — every later count is arithmetic on it.
- [X] T002 Record `git rev-parse HEAD` to `.delivery-kit/runs/018-progress-commits-pieces/baseline-sha.txt`, and copy `pipeline/scripts/progress.sh` unchanged to `.delivery-kit/runs/018-progress-commits-pieces/progress.sh.orig` — the red-first runs execute the new tests against this copy.

---

## Phase 2: Foundational

- [X] T003 Create `pipeline/tests/fixtures/tasks-pieces/tasks.md`: a tasks file that exercises every heading rule, in this order — a `# Tasks:` title; a `## Format: …` section holding one decoy task line `- [ ] T900 decoy under a non-piece heading`; `## Phase 1: Setup` with tasks T001, T002 (one `- [X]`, one `- [ ]`); `## Phase 2: Foundational` with NO task line (prose only); the heading copied byte for byte from `specs/017-guard-config-bounds/tasks.md:61` with tasks T003–T005, placed under two `### ` subheadings and none directly under the heading; the heading copied byte for byte from `specs/017-guard-config-bounds/tasks.md:99` with task T006 marked `- [x]` (lowercase); `## Phase 9b: M — pull-request review, round 2 of 3 (2026-08-24)` with task T007; `## Dependencies` holding decoy `- [ ] T901 decoy after the last piece`. Write it with Unix line endings. Afterwards confirm with `od -c` that no `\r` is in the file, and that the two copied lines are byte-identical to their sources: slice each source with `sed -n 61p` / `sed -n 99p`, find the same line in the fixture with `grep -nF` on its first 30 characters, slice it with `sed -n <that line>p`, and `cmp` the two slices. Save the result to `.delivery-kit/runs/018-progress-commits-pieces/t003-fixture.txt`.

**Checkpoint**: by construction the fixture holds four pieces — `Phase 1: Setup` (T001,T002), the line-61 heading (T003,T004,T005), the line-99 heading (T006) and `Phase 9b: …` (T007) — with `Phase 2: Foundational` skipped for having no task. T008(e) measures that sequence; this line only states the intent.

---

## Phase 3: User Story 1 — record a commit with its purpose (Priority: P1) 🎯 MVP

**Goal**: `commit-add` appends one typed entry, refuses bad input by name, and treats an identical re-record as done.

**Independent Test**: in a scratch repository, `init` a run, record one entry, and inspect `.commits`.

### Tests for User Story 1 (write first, run red)

- [X] T004 [US1] In `pipeline/tests/progress.bats`, add the `commit-add` tests. ASCII `@test` names only — bats 1.11.0 counts a non-ASCII name in the plan line and never runs it. Use LITERAL 40-character shas written out in the test (for example `abc1234` followed by 33 more hex digits), never a helper that repeats one character: a repeated-character sha cannot start with a given prefix, so the prefix tests would pass whatever the rule is (review F8).
  **Good cases**: (a) one `piece` entry holds exactly the fields `sha kind piece tasks files`, in that order; `tasks` and `files` are `type == "array"` with the given values; `validate` still passes; (b) a second entry appends after the first, which is unchanged (`jq -c '.commits[0]'` equal before and after); (c) with old-style entries seeded by `jq` — `"abc1234"`, a 40-character id string, `"7be8232ef"`, `"fdb79bb feat(pipeline): pre-flight names git"` — an unrelated id appends and all four strings survive in place; (d) an identical re-record exits 0 and leaves the file byte-identical (`cmp`); (e) kind `tests` with no files is accepted, and `files` is `type == "array"` and empty; (f) a relative file path holding a space and non-ASCII bytes (`dir/a b ü—🎯.md`) is stored exactly — read it back with `jq -r '.commits[0].files[0]'` through `$()` and compare `od -An -tx1` against the literal byte string, never against a `jq --arg` round-trip (review F21); (g) a relative path starting with `-` (`-dash.txt`) is stored as data (review F22); (h) each of the eight kinds is accepted once, the eight written out LITERALLY in the test from `contracts/progress-commands.md`, with the count asserted to be 8 — a second source for the kinds, per Principle V, so dropping one from the script goes red (review F6); (i) `commit-add` prints NOTHING on stdout, checked with `run --separate-stderr` on a success and on a refusal (review F11).
  **Refusals** — each asserts the contract's message fragment AND `cmp` byte-identity of the state file: the feature with only three further arguments; an unknown kind, whose message lists all eight legal kinds (check against the literal eight from (h)); the multi-word kind `spec piece` (review F7); an empty sha; a 39-character sha; a 41-character sha; a 40-character UPPERCASE sha; the same sha with a different `kind`; the same sha with a different `piece`; the same sha with different `tasks`; the same sha with a different `files` list (review F9) — each of these four with the "with different details" fragment; a sha starting `abc1234` against the old-style `"abc1234"`; a sha starting `7be8232ef` against the 9-character old-style entry; a sha starting `fdb79bb` against the old-style `"fdb79bb feat(pipeline): …"` entry — each of these three with the "by an old-style entry" fragment (review F24); an unknown feature; kind `piece` with an empty piece name; kind `piece` with empty tasks; a piece name holding a CR, one holding a LF, one holding U+001F (review F13); kind `review` with no files.
  **Edge**: an old-style entry whose first word is 6 hex characters (`"abc123"`) does NOT block a sha starting `abc123` — the record succeeds.
- [X] T005 [US1] Run `pipeline/tests/progress.bats` in a scratch tree (rule 3) whose `pipeline/scripts/progress.sh` is `.delivery-kit/runs/018-progress-commits-pieces/progress.sh.orig`, and save the output to `.delivery-kit/runs/018-progress-commits-pieces/us1-red.txt`. Every T004 test must be `not ok`; every pre-existing test must stay `ok`. Any T004 test that passes here proves nothing — fix it before T006.

### Implementation for User Story 1

- [X] T006 [US1] In `pipeline/scripts/progress.sh`: add `KINDS=" spec piece converge simplify review tests constitution other "` beside `PHASES`, with a `kind_known` helper that FIRST refuses anything but lowercase letters and only then applies the `case "$KINDS" in *" $k "*)` idiom; add `cmd_commit_add` in the order given in plan.md's design notes — argument count; kind; sha empty; sha shape (`${#sha}` is 40 and `case` rejects `*[!0-9a-f]*`); piece rules (non-empty for `piece`; no CR, LF or U+001F in any case); file rule; `sf="$(cmd_validate "$feature")"` — CAPTURED, since `cmd_validate` prints the path; one jq call printing `new`, `same`, `conflict` or `legacy` per research R7 (an old-style first word must match `^[0-9a-f]{7,40}$` before its prefix test counts), branched with `case` whose `*)` arm dies naming the unexpected output; for `new`, one jq append with `--arg` values and the files passed as `--args -- "$@"` AFTER the state file, `tasks` split per research R4, written through `$sf.tmp` and `mv`. Add `commit-add) shift 2; cmd_commit_add "$feature_arg" "$@" ;;` to the dispatcher. Every refusal uses `die` with the contract's message fragment.
- [X] T007 [US1] Run `pipeline/tests/progress.bats` against the changed script; save to `.delivery-kit/runs/018-progress-commits-pieces/us1-green.txt`. Every test `ok`, the usage test at `:311` included — it is not edited until T013, so a red there is a real regression; plan line equal to the ok count.

**Checkpoint**: `commit-add` works alone; `piece-next` does not exist yet.

---

## Phase 4: User Story 2 — name the next piece to build (Priority: P1)

**Goal**: `piece-next` prints the first unrecorded piece with tasks, as two clean lines, and nothing when all are done.

**Independent Test**: point a scratch run at the T003 fixture and walk it piece by piece.

### Tests for User Story 2 (write first, run red)

- [X] T008 [US2] In `pipeline/tests/progress.bats`, add a helper that `init`s a run, copies `$ROOT/pipeline/tests/fixtures/tasks-pieces/tasks.md` into the scratch repository, and records its RELATIVE path in `artifacts.tasks`. Every loop below is BOUNDED: at most (number of `## Phase` lines in the fixture + 1) iterations, and an overflow fails naming the heading that repeated — an unbounded loop turns the one failure it exists to catch into a hang (review F19).
  **Good cases**: (a) the first call prints exactly two lines — `Phase 1: Setup` and `T001,T002`; (b) after recording that piece with `commit-add`, the next call prints the line-61 heading and `T003,T004,T005` (the `### ` subheadings did not end the piece, and `Phase 2: Foundational` is skipped for having no task); (c) a phase recorded under kind `converge` is skipped exactly like a `piece` one; (d) an entry of kind `review` whose `piece` names a heading does NOT skip it; (e) the WALK: feed each printed heading back to `commit-add` until nothing is printed, collecting every output; assert the complete sequence — the four headings in order with their id lists — AND that neither `T900` nor `T901` appears anywhere in the collected output (review F10: a decoy check on its own passes against the unchanged script), then that the final call prints nothing and exits 0; (f) the line-61 heading (em dash, emoji, parentheses) AND the line-99 heading each round-trip byte for byte — `printf '%s'` of the printed line through `od -An -tx1`, compared with the same dump of the fixture's own line found with `grep -n` (review F5); (g) a CRLF copy of the fixture, made with `awk '{printf "%s\r\n", $0}'` as `progress.bats:201` already does — never `sed 's/$/\r/'`, which BSD sed on the macOS runner reads as a literal `r` (review F4) — prints output identical to (a), and `od -c` of the output holds no `\r`. Note in the test's comment that on Windows jq strips the CR itself, so this case only proves the script's own stripping on Linux and macOS (research R5); (h) the lowercase `- [x]` task T006 is found; (i) `Phase 9b: …` is a piece; (j) after a call that PRINTED a heading, the state file AND the tasks file are byte-identical to copies taken before it (`cmp` both; review F10, F23).
  **Refusals**, each asserting its contract message: unknown feature; no `artifacts.tasks`; a recorded tasks path that does not exist; a tasks file with no `## Phase` heading; a tasks file whose only `## Phase` heading has no task line; a tasks file whose first piece heading holds U+001F; a tasks file whose first piece heading holds a CR in the MIDDLE of the line — Windows jq keeps a mid-line CR too, so this case behaves the same on every OS (both with the "heading holds a control character" fragment).
- [X] T009 [US2] Run the file in a scratch tree against `progress.sh.orig`, as in T005; save to `.delivery-kit/runs/018-progress-commits-pieces/us2-red.txt`. Every T008 test `not ok`; every other test keeps its T005 status.

### Implementation for User Story 2

- [X] T010 [US2] In `pipeline/scripts/progress.sh`, add `cmd_piece_next`: `sf="$(cmd_validate "$feature")"`; read `artifacts.tasks` with one `$()`-captured jq call; refuse per the contract when it is empty or the file does not exist; then one jq call — the state file as input, the tasks file via `--rawfile` — that splits lines, strips ONE trailing `\r` from each, walks headings per research R6, drops task-less headings, removes those recorded as `piece` or `converge` by `==` on the full text, and prints ONE line: `none`, `done`, `bad` (the chosen heading, after its one trailing CR is stripped, still holds a CR or U+001F), or `next` + U+001F + heading + U+001F + comma-joined ids. Branch in bash with `case` on the word before the first U+001F: `none` and `bad` → `die` with the contract's message; `done` → print nothing, exit 0; `next` → `printf '%s\n%s\n'` the two fields split with `${r#*$'\x1f'}` and `%%`; `*)` → `die` naming the unexpected output. Add `piece-next) cmd_piece_next "$feature_arg" ;;` to the dispatcher.
- [X] T011 [US2] Run `pipeline/tests/progress.bats`; save to `.delivery-kit/runs/018-progress-commits-pieces/us2-green.txt`. Every test `ok`, the usage test at `:311` included.
- [X] T012 [US2] Dry read on a real file: in a scratch directory, `init` a run whose `artifacts.tasks` points at a copy of `specs/017-guard-config-bounds/tasks.md`, then loop `piece-next` → `commit-add` with a fresh 40-character sha each time, BOUNDED at the file's `## Phase` line count + 1 and failing by name on overflow, capturing every printed heading and id list. Save to `.delivery-kit/runs/018-progress-commits-pieces/t012-dry-read.txt`. Expected per research R6: six pieces, `Phase 2: Foundational` absent, Phase 3 with ten ids. Record what was MEASURED; a mismatch is a finding, not a typo.

**Checkpoint**: both commands work; the usage line still names neither.

---

## Phase 5: User Story 3 — the usage line names the new commands (Priority: P3)

**Goal**: a wrong call shows every command.

- [X] T013 [US3] In `pipeline/tests/progress.bats:311`, EDIT the existing whole-list assertion to the new list `<init|read|validate|phase-start|phase-done|from-validate|lock-take|lock-release|commit-add|piece-next>` — do not add a second, weaker test beside it; the existing one pins every name and the order in one comparison (review F1). Keep its comment and add one sentence saying the list grew by two here. Run it in a scratch tree against `progress.sh.orig` and save to `.delivery-kit/runs/018-progress-commits-pieces/us3-red.txt`; it must be `not ok`.
- [X] T014 [US3] In `pipeline/scripts/progress.sh:23`, append `|commit-add|piece-next` to the `usage` list, in that order. Run `pipeline/tests/progress.bats` and save to `.delivery-kit/runs/018-progress-commits-pieces/us3-green.txt`: every test `ok`, plan line equal to the ok count.

---

## Phase 6: Polish & cross-cutting

- [X] T015 SC-005 replay: write `.delivery-kit/runs/018-progress-commits-pieces/t015-replay.sh`. It globs `.delivery-kit/runs/*/progress.json`, EXCLUDES this run's, and COUNTS what it found — failing if the count is zero — then copies each into a scratch tree (never touching the originals) and runs `commit-add <feature> other <fresh 40-char sha> "" "" replay.txt` against each copy, checking: exit 0; `validate` passes; every old entry is still present, in order (`jq -c '.commits[:-1]'` of the result equals `jq -c '.commits'` of the source); the new last entry is an object. It asserts copies checked == originals found (review F20). Save its output to `t015-replay.txt`. Prove the originals were not touched: `sha256sum` every original before and after, and compare.
- [X] T016 Mutation check at the edges, in a scratch tree (rule 3), one mutant at a time: (1) the sha length 40 → 39; (2) the old-style first-word minimum 7 → 6; (3) the `rtrimstr("\r")` removed; (4) the heading prefix test loosened to `startswith("##")`, so a `### ` line ends a piece; (5) `converge` removed from the recorded-kind filter; (6) the task-less-heading filter removed; (7) `same` treated as `conflict`; (8) the letters-only kind check removed; (9) `kind` dropped from the identical-details comparison; (10) the old-style first-word split removed, comparing the whole string; (11) the classify step made to print an unexpected word (`maybe`) — the refusal must name it, proving the `case` default arm fires; (12) the walk's status made to print an unexpected word — the same proof for `piece-next`. For each: echo the mutated line from the copy (`grep -n`) before running, run `pipeline/tests/progress.bats` there, and record which test went red. Save to `t016-mutations.txt`. Mutant (3) cannot be shown with an ordinary CRLF file here, because the native Windows jq strips that CR itself (research R5). Show it with a CR-CR-LF heading in the scratch run ONLY: Windows jq reads `x
` as `x`, so the correct code prints the heading clean and the mutant leaves a CR. Do not commit that input as a suite test — on Linux the correct code leaves one CR from it as well. Record the platform beside the result. Any other mutant that stays green is a gap: write the missing test, show it red against `progress.sh.orig` in a scratch tree as well as against the mutant (review F17), and re-run the mutant.
- [X] T017 Run the shell analyser exactly as CI does, from the repository root: `mapfile -d '' files < <(git ls-files -z -- '*.sh' '*.bash' ':(exclude).specify/'); shellcheck --norc -f gcc -- "${files[@]}"`. Save to `t017-shellcheck.txt`. It must print nothing. CI's shellcheck is OLDER and reports more; a local clean is necessary, not sufficient.
- [X] T018 Run the full house suite from the repository root; save to `t018-final-suite.txt`. Expect `1..170+N`, N the number of tests added by T004, T008 and T016 (T013 edits one, adds none), all ok, 0 not ok, 0 non-TAP, plan line equal to ok count. Write N and every added test name to `t018-added-tests.txt` — the commit message names them all. Then check SC-006: `git diff --name-only "$(cat .delivery-kit/runs/018-progress-commits-pieces/baseline-sha.txt)"` plus `git ls-files --others --exclude-standard`, filtered to exclude `specs/018-progress-commits-pieces/`, lists exactly `pipeline/scripts/progress.sh`, `pipeline/tests/progress.bats` and `pipeline/tests/fixtures/tasks-pieces/tasks.md`. Save to `t018-scope.txt`.

---

## Dependencies

- Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6, strictly.
- US2 depends on US1: its tests record pieces with `commit-add`.
- US3 edits the same two files, so it runs after US2.
- T016 needs every test in place; T018 runs last.

## Parallel opportunities

None worth taking. Every implementation task edits `pipeline/scripts/progress.sh` or `pipeline/tests/progress.bats`, and two agents never edit one file. T015 and T017 read disjoint things and could overlap, at no real saving.

## Implementation strategy

MVP is US1: a trustworthy record is what everything else in Campaign 3 reads. US2 makes the record useful. US3 is one line. Each story is proven red, then green, before the next starts, so a failure is always attributable to the story that introduced it.
