---

description: "Task list for the release gate starting fewer processes, with its walk tested on its own"
---

# Tasks: The release gate starts fewer processes, and its walk is tested on its own

**Input**: Design documents from `specs/033-gate-fewer-processes/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: the spec asks for tests (FR-003, FR-007, SC-002, SC-004). Each
new test is written FIRST and shown red against the gate as it stands,
where it can be (the held-values, whole-line and apostrophe tests pass on the
old gate by design, and say so). Five tests are added, none removed; the
suite reads `1..431` (research R9).

**Run directory**: `$RUN` = `.delivery-kit/runs/033-gate-fewer-processes/`.

**Pieces**: each `## Phase` below is one piece and one commit.

**Commit messages**: no `Co-Authored-By`, no `Claude-Session` and no
"Generated with" line, in any commit or pull-request text this run writes.

**Rules every task keeps** (research R6, R8; spec FR-010 to FR-012):

- Every gate run in a test goes through `gate_run` or `run bash -c '…' _
  <args>` with the data as arguments, never `run bash <script>.sh` (test
  652 counts those); the walk runs as `awk -f`, never as a `.sh`.
- No test file and no CI line holds the text `select(.name == $n)` in any
  spacing; the gate's text keeps it (test 652's marker). A `jq` program in
  a test selects an entry by position.
- A fixture never reads the code under test: the tests hold their own
  copies of `DATED_RE`, `LINE_LIMIT` and `QUOTE_CUT`, and one test proves
  them equal to the gate's.
- New and moved assertions match text in the shell (`[[ $s == *"$want"* ]]`),
  never with `grep … < <(printf …)`.
- Every `tr`, `grep`, `wc` or `awk` on a file or output that may hold a
  byte which is not valid text runs under `LC_ALL=C`; a locale rule is also
  tested with `LANG` UTF-8 and `LC_ALL` unset (`forms_utf8`).
- Bash 3.2 and the BSD awk: no interval expressions in awk patterns, no
  `\/` inside a pattern substitution, no `mapfile`, no `${s,,}`.
- `scripts/` comments: STRICT vocabulary, no machine path, no count in
  prose. Every test failure echoes its clause first.
- Kill only processes you started; never `wait` without a PID in a test.

## Phase 1: Setup — the differential harness, proved on the unchanged gate

**Purpose**: the tool that proves FR-002 exists, and is shown able to go
red, before the gate changes.

- [X] T001 Write `specs/033-gate-fewer-processes/proof/differential.sh <base>` per research R10: it makes a scratch worktree of `HEAD`, copies over it the working tree's `scripts/check-versions.sh`, `scripts/check-versions-walk.awk` (when present) and `tests/portability.bats`, moves the new gate to `scripts/check-versions.new.sh` beside the walk file, writes the old gate (`git show <base>:scripts/check-versions.sh`) outside the worktree, and installs at `scripts/check-versions.sh` a wrapper that runs both with the same working directory, arguments and environment, compares standard output, standard error and exit status, logs any difference (working directory, arguments, both sides with bytes shown by `od -c`) to a log outside the worktree, then prints the new gate's standard output, then its standard error, and exits with its status. The wrapper turns off the shell options the gate turns off, writes no temp file with `mktemp` (paths fixed at install time, names from `$$` and `RANDOM`), and never fails the test it runs in on its own account. It logs a START line before and a DONE line after each compared run, and classifies each run AT LOG TIME, while the fixture still exists (the suite's `teardown` deletes it): LF when the tree's `*/.claude-plugin/plugin.json` name or version, or a marketplace entry's version or source, holds a line feed, or two marketplace entries share a name (the second found at T013, research R5) (read with `jq`, by position, never `select(.name == $n)`); PLAIN otherwise.
- [X] T002 In the same script, run `tests/portability.bats` over the wrapper, its copy of the test file and of `tests/helper.bash` given doubled limits (every `timeout <N>` and the per-test `BATS_TEST_TIMEOUT`, each edit confirmed landed by a count), because each run now runs two gates. Then build the fixture shapes of research R1 as one-plugin trees (each in both forms), plus a name holding an inner `\n\n`, and run the wrapper on each; one of them, LF1, is a plugin whose `plugin.json` name is `x\ny` in directory `x`, so its "does not match its directory" line prints the name. The verdict (research R10): a difference on a PLAIN run is UNEXPECTED, on every system; on Windows (`uname -s` MINGW, MSYS or CYGWIN) LF1 MUST differ, and on any other system no run may differ. Every START must have its DONE (a run cut short compared nothing). Coverage is pinned PER TEST: the script first runs the same file over a second wrapper that only logs a START per gate run, keyed by the test's name (`BATS_TEST_DESCRIPTION`), and runs the new gate (the plain pass); then, for every test green over the comparing wrapper, its compared runs must equal its plain-pass runs. A test red over the comparing wrapper is allowed only when a rule read from its body puts it in the expected-red set — it reads, copies or greps `scripts/check-versions.sh` (not only runs it), counts `jq` starts, or sets `SHELLOPTS` or `BASHOPTS` for the gate — and the script prints each such test with its runs lost; any other red test fails the differential. When the gate under test is byte-identical to the old one (T004), no run may differ on any system. A test that runs no gate is outside the comparison, whatever its result. `DIFF_FILTER` (a `bats -f` pattern) limits the suite passes for trying the harness and prints that the run is not a verdict. Print `DIFFERENTIAL OK (<runs> runs, <lf> LF runs, <differ> differing)` and exit 0 only when all of that holds.
- [X] T003 In the same script, the control: the same wrapper with the new gate mutated by one byte in its report line's format string — the `printf '%s: plugin=%s … state=%s\n'` line, `state=%s` → `stat=%s`, exactly one occurrence changed, confirmed by a count before and after — over `bats -f 'manifest, marketplace entry and changelog agree' tests/portability.bats`; print `CONTROL OK` only when at least one UNEXPECTED difference is logged and no run crashed. Remove the worktree on exit (trap), even on failure.
- [X] T004 Run `bash specs/033-gate-fewer-processes/proof/differential.sh 2b38f74` on the unchanged tree: expect `DIFFERENTIAL OK` with 0 differences and `CONTROL OK`. Record the run (date, runs, verdicts) under "Measurements after the build" in `specs/033-gate-fewer-processes/research.md`, marked as the harness's own proof on the old gate.
- [X] T005 Measure the "before" side of research R11 on `2b38f74` (`jq` starts per gate run on the real tree, both forms, with a logging `jq` first on `PATH`; one gate run's time, three runs) and record them in the dated table in `specs/033-gate-fewer-processes/research.md`. `tests/portability.bats` alone is timed at T028, old and new alternating, so both sides meet the same load; the table says so.

**Checkpoint**: the harness reports no difference on an unchanged gate and catches a one-byte mutant.

---

## Phase 2: Foundational — the tests hold their own copies of the walk's values

**Purpose**: the values the direct walk tests will pass exist at file
scope, and are proved equal to the gate's (FR-008).

- [X] T006 In `tests/portability.bats`, hoist the test file's own copies of the dated heading pattern (now a local near line 1259), `line_limit=1000` (near 2338) and `quote_cut=200` (near 3234) to file scope, as `HELD_DATED_RE`, `HELD_LINE_LIMIT` and `HELD_QUOTE_CUT`, and make each former use read the file-scope copy. Behaviour of every existing test unchanged.
- [X] T007 Add the test "the tests hold the walk's three values as the gate sets them" to `tests/portability.bats`: it reads the gate's `dated_re=`, `line_limit=` and `quote_cut=` assignment lines from `$ROOT/scripts/check-versions.sh` (the only place a test reads the gate's text for this) and asserts each equals the held copy byte for byte, echoing the clause `V1:` on failure. Show it red with a held copy changed by one byte (confirm the change landed), then restore.

**Checkpoint**: `bats -f 'hold the walk' tests/portability.bats` green; the file's other tests unchanged.

---

## Phase 3: User Story 1 — one read per file, every message unchanged (Priority: P1) 🎯 MVP

**Goal**: 1 + N `jq` processes per run; every message byte-identical
(research R1, R2, R4, R5).

**Independent Test**: the process-count test; the differential.

- [X] T008 [US1] Add the test "the gate starts one jq for the marketplace and one per plugin" to `tests/portability.bats`: a directory holding an executable `jq` that appends one byte to a log and then runs the real `jq` (found before `PATH` changes), put first on `PATH` for a gate run in a two-plugin fixture (`forms_base`), both forms; it asserts the log's byte count equals one plus the number of `*/.claude-plugin/plugin.json` in the fixture, counted by the test (clause `C1:`). Run it: red now (14 starts on two plugins).
- [X] T009 [US1] In `scripts/check-versions.sh`, add beside `shown` a function that cuts one length-prefixed field off a variable under `LC_ALL=C` (data-model.md: digits, `:`, that many bytes), and refuses — returning non-zero, so the caller dies with that file's "could not be read" line — a length that is not all digits, a length past the end, or a missing field.
- [X] T010 [US1] In `scripts/check-versions.sh`, replace the marketplace shape check (`:174`) and the entry list (`:766`) with one `jq -b -e -s -j` process (research R2): `market_shape` unchanged; when it holds, `[.[0].plugins[] | [.name, (.source // "")] | @tsv] | join("\n")` then `.`. Keep the `case` on its status (0, 1, other) and both messages exactly; check and remove the `.`; set `entries_tsv` from it. Only the `jq` call moves to the top: the empty check (`:768-771`) stays after the forward loop, where it is today, so a tree with `"plugins": []` and a plugin directory still stops first at the forward loop's "no marketplace entry" line. Move the `:745-765` comment to the new read, saying what it reads now and why the `printf` loop still feeds the walk.
- [X] T011 [US1] In `scripts/check-versions.sh`, replace the plugin shape check (`:320`) and the name and version reads (`:326`, `:328`) with one `jq -b -e -s -j --slurpfile m .claude-plugin/marketplace.json` process on `plugin.json` (research R1, data-model.md): `plugin_shape` unchanged; when it holds, the five fields and `.`. Bind the stripped name as `$n` and select entries with `select(.name == $n)`. Keep the `case` on its status and both messages exactly; cut the fields into `pn`, `pv`, the entry flag, `mv`, `ms` with T009's function, then check and remove the `.` and that nothing is left (a failure of any: `die "$p_s: plugin.json could not be read"`). Trailing line feeds are removed in `jq` by a recursive `endswith("\n")` step, never by `sub("\n+$"; …)` (Oniguruma's `$` also matches before an inner line feed). Correct the comments this makes false: `:43-47` (the CR note: `-b` writes none now; say what still strips one and why it stays harmless) and `:318` ("its shape once, before any read of it": shape and reads now share one process).
- [X] T012 [US1] In `scripts/check-versions.sh`, replace the three marketplace reads (`:360`, `:362`, `:375`) by tests of the values T011 cut, at the same place in the loop, with the same three messages in the same order. Replace the comment at `:347-353` with one that says the three diagnostics stay three, the three processes became one, and why (research R1, R3) — never describing code that is gone.
- [X] T013 [US1] Run T008's test: green (3 starts on two plugins). Run `tests/portability.bats` whole: every test green. Run `bash specs/033-gate-fewer-processes/proof/differential.sh 2b38f74`: `DIFFERENTIAL OK` with no UNEXPECTED difference, and `CONTROL OK`.
- [X] T014 [US1] Add plants to the existing test "every value masked" (near line 2775) of `tests/portability.bats`, so the merged read is judged on all three CI systems and their jq versions (FR-004), not only by the Windows differential: a `plugin.json` name holding `é`, a four-byte character and bytes that are not valid UTF-8 (written with `jq`'s `\u` escapes or as raw bytes, never through a `printf` format holding `\u0000`), in a directory it cannot match; a marketplace version holding the same, against a different `plugin.json` version; a `plugin.json` version `true` (the boolean); and the same name plant run once more with `LANG` set to a UTF-8 locale and `LC_ALL` unset (`forms_utf8`). Each asserts the gate's exact line, every non-ASCII byte shown as one `?` (so a cut misplaced by one byte, or counted in characters, changes the line), and the boolean refused with the shape message. No test is added: the count stays.
- [X] T015 [US1] Mutants, each confirmed landed before its red is believed (SC-004): T009's function cutting one byte short; `LC_ALL=C` dropped from T009's function (T014's UTF-8 plant goes red); the entry flag ignored (always `1`); `mv` and `ms` swapped; `-b` dropped (on Windows: the differential reports UNEXPECTED on a PLAIN run whose value holds a CR, or LF1 changes); the `.` check removed and a value given a trailing line feed by a fixture. Each must turn a named test, or the differential, red, or be recorded as a survivor with the measurement that shows why (the `.` terminator: it guards nothing reachable, research R4). The open check `{ : < … }` before each read keeps its Phase 27 test; the walk file's open check has no mutant of its own (T017 (b) is caught by `-f` first): say so in research. Record each outcome in `specs/033-gate-fewer-processes/research.md`.

**Checkpoint**: 3 `jq` starts on the real tree; the differential clean.

---

## Phase 4: User Story 2 — the walk lives in its own file (Priority: P1)

**Goal**: the walk file, found beside the gate, checked, its failures
named (research R6, R7).

**Independent Test**: quickstart blocks 3 to 5.

- [X] T016 [US2] Add the test "a walk refusal reaches the log as one whole line" to `tests/portability.bats`: a released one-plugin fixture with one undated `## Notes ##[x` heading below its release heading; `--released` exits 1, and the LAST line of `$output` equals exactly `check-versions.sh: <plugin>: line <N> … — this tree is NOT released`, the middle built from the walk text the test expects, with `##[` shown as `#?[` (clause `W1:`); the line before it is the plugin's report line (bats `run` joins standard output, which carries the report, and standard error). It passes on the old gate: record that it pins today's line, so it guards the move.
- [X] T017 [US2] Add the test "the gate stops when its walk file is missing, not a file, or fails" to `tests/portability.bats`: a copy of the gate and its walk file in a scratch `scripts/`, a released fixture beside it, run from the fixture with the copy's relative path: (a) walk file removed → exit 1 and `the heading walk check-versions-walk.awk beside the gate could not be read — this tree is NOT released`; (b) a directory at its path → the same; (c) a walk file holding `BEGIN { exit 3 }` → exit 1 and `the heading walk did not run to the end — this tree is NOT released`; and every output passes `forms_no_path` (clause `W2:`). Run it: red now (there is no walk file).
- [X] T018 [US2] Create `scripts/check-versions-walk.awk`: a header of `#` comments (what it is; that only the gate runs it, as `awk -f` on the changelog; the environment values it reads, `DATED_RE`, `LINE_LIMIT` and `QUOTE_CUT`, named without a count, and that the gate runs it under `LC_ALL=C`; that its steps are explained above the call in the gate and in `specs/024-gate-every-heading-form/research.md` R2), then lines `:545` to `:728` of `scripts/check-versions.sh` byte for byte (copy them with `sed -n`, never by retyping). Mode as the other scripts in `scripts/`.
- [X] T019 [US2] In `scripts/check-versions.sh`: work out the walk's path once, near the top, from `BASH_SOURCE` (its directory part, or `.` when it has none); at the walk, check `[ -f ]` and open it (`{ : < …; } 2>/dev/null`) and stop with T017's first message otherwise; run `awk -f` on `"./$p/CHANGELOG.md"` with the same environment as today, standard error discarded, and stop with T017's second message on a non-zero status; delete the old inline program (`:544-729`); keep the comment block above the call, updated to name the file and to say why the walk's errors are discarded and its status checked (replacing `:535-537`'s "awk exits 0 either way" reasoning only where it no longer holds).
- [X] T020 [US2] Add the test "an apostrophe in the walk file's comments is harmless" to `tests/portability.bats`: a copy of the gate and walk file with `# isn't` added as the walk file's first line (confirm it landed), and the released fixture passes (clause `W3:`). It cannot fail on the old gate (no file); say so in its comment.
- [X] T021 [US2] Run quickstart blocks 1 and 3 to 5, in one script (block 1 defines what the others use; the walk's text unchanged; the gate's line is prefix + walk text + suffix; the failure rules), T016, T017, T020, and `tests/portability.bats` whole: all green.
- [X] T022 [US2] Mutants, each confirmed landed (SC-004): the walk found from the working directory (`.`) — the release-form tests go red; the `-f` check removed — T017 (b) red; the status check removed — T017 (c) red; one byte of the walk body changed — quickstart block 3 red. Record outcomes in `specs/033-gate-fewer-processes/research.md`.

**Checkpoint**: the gate runs its walk from the file; every failure has its own line.

---

## Phase 5: User Story 2 — the tests run the walk directly (Priority: P1)

**Goal**: about 98 gate runs that test only the walk become direct runs
(research R8's inventory).

**Independent Test**: `tests/portability.bats` green, with fewer gate
runs, counted by the logging-wrapper method of T005.

- [X] T023 [US2] Add to `tests/portability.bats` the helpers `walk_on <file>` (runs `LC_ALL=C DATED_RE="$HELD_DATED_RE" LINE_LIMIT="$HELD_LINE_LIMIT" QUOTE_CUT="$HELD_QUOTE_CUT" awk -f "$ROOT/scripts/check-versions-walk.awk"` on the file as standard input), `walk_refuses <file> <fragment>…` (the walk's output is not empty and holds each fragment, matched in the shell, and passes `gate_safe`'s byte rules) and `walk_passes <file>` (empty output, status 0), with a comment giving research R8 as the reason.
- [X] T024 [US2] Convert the MOVE tests (research R8: lines near 1952, 1973, 2047, 2166, 2190, 2263, 2289) to run every plant through `walk_on`, keeping each test's name, plants, fragments and clause IDs; each test's base run becomes `walk_passes` on the normalised changelog.
- [X] T025 [US2] Convert the walk-only runs of the SPLIT tests (lines near 1697, 1725, 1735, 2009, 2061, 2088, 2126, 2226, 2340) to `walk_on`, and keep end to end exactly the runs research R8 names: every default-form run (G5, H8), G6's other-plugin run, K3's 1,001-byte line and its 400-byte checks, K4's cut value, K4 under UTF-8, both K5 NUL runs, and one `## Notes` refusal with its dated base.
- [X] T026 [US2] Prove the conversion lost no check: for each converted test, mutate the walk file so the refusal that test checks no longer fires (one mutant per test, confirmed landed) and see the test go red; record the table in `specs/033-gate-fewer-processes/research.md`. Count the gate runs of `tests/portability.bats` again (logging wrapper): record before and after.
- [X] T027 [US2] Run `tests/portability.bats` whole: green; no test over 40 s alone on Windows (`--timing`).

**Checkpoint**: the walk's forms are tested without a copied tree; the gate's own wiring still end to end.

---

## Phase 6: User Story 3 — the speed, recorded (Priority: P2)

- [ ] T028 [US3] Measure the "after" side of research R11 on the branch, alternating with `2b38f74` runs as T005 did, and complete the dated table in `specs/033-gate-fewer-processes/research.md`: `jq` starts per run (both forms), one gate run's time, `tests/portability.bats` alone, gate runs per file.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T029 Run the whole quickstart as one script (extract every `bash` block of `specs/033-gate-fewer-processes/quickstart.md` in order into a file in the session's scratch directory, run it with `bash`): it ends `ALL OK`. Fix the quickstart, not the check, if a block is wrong about what it tests.
- [ ] T030 Run the house suite from the root, `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > <tap>`, and judge it with `bash scripts/check-suite.sh 431 <tap>`; run shellcheck as CI does (`mapfile -d '' files < <(git ls-files -z -- '*.sh' '*.bash' ':(exclude).specify/'); shellcheck --norc -f gcc -- "${files[@]}"`); it reads the working tree, so nothing need be staged.
- [ ] T031 Sweep for stale text: every comment in `scripts/check-versions.sh` and `tests/portability.bats` that named line numbers, the inline program, "three queries", jq's CR (`:43-47`), "shape once, before any read" (`:318`), or a count this feature changed, and `CONTRIBUTING.md` where it describes the gate; correct each, adding no count to prose. Then reread `research.md` R8 and R10 against what was built and correct any line, count or name that moved.

SC-007 (CI green on three systems, a run confirmed to exist, every job's steps read) is checked by the pipeline at phases L to N, after the push; no task here can.

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7.
- Phase 3 needs the harness (Phase 1). Phase 4 needs nothing from Phase 3
  but edits the same file, so it follows it. Phase 5 needs Phase 2's held
  values and Phase 4's walk file.
- Within a phase, tasks run in order: each edits `scripts/check-versions.sh`
  or `tests/portability.bats`, and no two may edit one file at once.

## Parallel Opportunities

None inside the pieces: every task edits one of the same two files. The
measurement runs of T005 and T028 may run while code is read, never while
a test runs (timing).

## Implementation Strategy

Phase 1 and 2 first (the harness and the held values). Phase 3 is the MVP:
the process count falls and the differential proves nothing else moved.
Phase 4 and 5 deliver the walk file and the faster suite. Stop at any
checkpoint and the tree is green.
