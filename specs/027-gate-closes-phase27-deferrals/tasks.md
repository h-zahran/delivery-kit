---

description: "Task list for the release gate closing what Phase 27 deferred"
---

# Tasks: The release gate closes what Phase 27 deferred

**Input**: Design documents from `specs/027-gate-closes-phase27-deferrals/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: the spec asks for tests (FR-013, FR-016, SC-006). Each new
plant is written FIRST and shown red against the gate as it stands before
the code it covers is written. One test is added; the suite reads
`1..252`.

**Run directory**: `$RUN` = `.delivery-kit/runs/027-gate-closes-phase27-deferrals/`.

**Pieces**: each `## Phase` below is one piece and one commit.

**Commit messages**: no `Co-Authored-By`, no `Claude-Session` and no
"Generated with" line, in any commit or pull-request text this run writes.

**Every gate run in a test** goes through `gate_run` or `run bash -c '…' _
<args>` with the data as arguments, never `run bash <script>.sh` (the
one-script test counts those), and every captured output passes
`forms_no_path`. Every `tr`, `grep`, `wc` or `awk` a test runs on a file
or an output that may hold a byte which is not valid text runs under
`LC_ALL=C`; a locale-dependent rule is also tested with `LANG` set to a
UTF-8 locale and `LC_ALL` unset (`forms_utf8`), as CI runners set them.
Every test failure echoes its contract clause first (`N1: …`), and a
fixture failure `fixture: …`. Every `ln` that may fail is followed by
`|| true` and judged by `[ -L ]`. No `\/` inside a pattern substitution,
in the gate or the tests. New test code runs on bash 3.2 and the BSD awk
too (macOS CI): no interval expressions in an awk pattern, there either.
Every `jq` program in the tests selects an entry by position
(`json_set`, `.plugins += […]`), never `select(.name == $n)`, which is
the marker the version-agreement test refuses outside the gate. A NUL
inside a JSON value is written with `jq` as the `\u0000` escape, never
through a `printf` format or `$'…'` (bash 4.2+ turns `\u0000` into a raw
NUL, which is not JSON; macOS bash 3.2's `printf` has no `\u`). Message assertions match the whole message
from `data-model.md`, from `check-versions.sh: ` on, where a fragment
could match a longer message too.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: User Story 1 — the gate follows no link (Priority: P1)

**Goal**: N1-N5 and N7 in `contracts/release-gate.md` (N6 needs Phase 2's open check, and is planted there).

**Independent test**: the new test `the gate follows no link, and keeps
its own shell options` passes, and fails against the gate at `$BASE`.

- [X] T001 [US1] In `tests/portability.bats`, after the test "a TRAILING malformed marketplace entry cannot escape the reverse walk", add the test `the gate follows no link, and keeps its own shell options` (ASCII name). It builds the one-plugin fixture `$base` with `forms_base one` and, each plant on its own `cp -r` copy of `$base`, checks each exit 1 with the clause's whole message from `data-model.md` and the output printed safely (`gate_safe`). No link or component check reads anything the form sets (research R8), so N1 runs in both forms (`gate_run "$c"` and `gate_run "$c" --released "$copied"`) to show that, and N2-N4 and N7 run in the default form only (research R8: the test's runs are budgeted under 30 s). The plants run in this order: N7 first (it needs no link, so against an older gate the first red is N7 on every system), then N1-N5:
  - (N1, both forms) `$copied/.claude-plugin/plugin.json` replaced by a link to a JSON file outside the copy (written in `$TEST_DIR`, its name `OUTSIDE-NAME`): `check-versions.sh: <copied>: plugin.json is a symbolic link, …`, and the output never holds `OUTSIDE-NAME`;
  - (N2) `.claude-plugin/marketplace.json` replaced by a link to a copy outside the fixture; then, on another copy, the repository `.claude-plugin` directory moved outside and linked back; then, on a third, `marketplace.json` replaced by a broken link: each says `check-versions.sh: .claude-plugin/marketplace.json is a symbolic link, …` or `check-versions.sh: .claude-plugin is a symbolic link, …` (never "run me from the repository root");
  - (N3) the plugin directory moved outside the copy and linked back under its name; then, on another copy, its `.claude-plugin` directory moved and linked back: each says `check-versions.sh: <copied>: the plugin directory is a symbolic link, …` or `check-versions.sh: <copied>: .claude-plugin is a symbolic link, …`, naming this plugin;
  - (N4) a second marketplace entry `{name: "ghost", source: "./via/x"}` where `via` is a link to a directory outside the copy holding `x/.claude-plugin/plugin.json`; then, each on its own copy, `{name: "ghost", source: "./nest/x"}` where `nest` is a real directory with no `.claude-plugin` and `nest/x/.claude-plugin` is a link, and again where only `nest/x/.claude-plugin/plugin.json` is a link (a top-level source is met by the forward loop first, so only a nested source reaches the reverse walk's own two checks): each `check-versions.sh: marketplace entry 'ghost': source '<source>' passes through a symbolic link`, in the default form only (research R8);
  - (N7) marketplace entries whose source is `./` followed by `a/a/…` (its first component a real directory, the rest missing), each on its own copy, in the default form, under `timeout 15` where the system has one: 2,046 components (under `source_limit`) and 65 components each give `check-versions.sh: marketplace entry '<name>': source '<source>' has more than 64 components`, the source cut as every value is; 64 components gives the whole `check-versions.sh: marketplace entry '<name>': source '<source>' names no plugin directory` (not refused for its count, and the walk stops at the first missing component).
  Links are made with `MSYS=winsymlinks:nativestrict ln -s <target> <name> 2>/dev/null || true`. (N5) Once, the test prints `# nolinks: made` or, where `[ -L ]` says the first link was not made, `# nolinks: not available here`, through file descriptor 3; outside Windows (`uname -s` not MINGW, MSYS or CYGWIN) an unmade link is a `fixture:` failure, as L1 does; where links are not available, the link plants are not run and the line says so. Run it against the gate as it stands and save to `$RUN/t001-red.txt`: it must fail on an N clause, not a fixture error.
- [X] T002 [US1] In `scripts/check-versions.sh`, add the link refusals of research R1 and `data-model.md` "A read path", each with the gate's own message, each before anything reads through the path:
  - the repository `.claude-plugin` and `marketplace.json` (`[ -L ]` on each) BEFORE the `-f .claude-plugin/marketplace.json` test (`:86` at `$BASE`), so a broken link is refused as a link, not as "run me from the repository root";
  - in the per-plugin loop, move `shown p_s "$p"` (`:177`) above the new checks, so a message names this plugin and never the one before; then, before the `-f plugin.json` test (`:175`): `[ -L "./$p" ]` (never `$dir`: `[ -L dl/ ]` is false for a link, measured) when `./$p/.claude-plugin` exists or is a link (`[ -e … ] || [ -L … ]`), then `[ -L "./$p/.claude-plugin" ]`, then `[ -L "./$p/.claude-plugin/plugin.json" ]`;
  - in the reverse walk, after the absolute and `..` checks and before its `-f` test (`:653`), inside `if [ -n "$ed" ]` (the `-z "$ed"` test stays where it is): first the component count, taken from `ed` before any file test (`nsl='[!/]'`, the pattern held in a variable as `norm_source` holds its own, no `\/`, no process: `t=${ed//$nsl/}`, components `${#t} + 1`), refusing a source of more than 64 (`component_limit`, beside `source_limit`); then every cumulative prefix (`./a`, then `./a/b`, …), built with `${rest%%/*}` and `${rest#*/}` (prefix and suffix removal) and stopping when `${rest%%/*}` equals `$rest` (with no `/` left, `${rest#*/}` returns `rest` unchanged, so a loop that waits for it to change never ends), or at the first prefix that is neither a link nor there (`[ -e ]` after the `[ -L ]` test); then its `.claude-plugin`, then `plugin.json`. The prefix walk is skipped when `ed` equals the `ed` the walk last checked (entries naming the same source cost one walk);
  - `component_limit` joins the P test's `die_raw` allowlist beside `source_limit`, in this task, so P0 stays green.
  Each check written as an `if`, not `A && B || C` (CI's shellcheck 0.9.0 reports that shape). Run T001's test, the P test (its P0 scan reads the new `die` lines), the one-script test and the version-agreement test, saved to `$RUN/t002-green.txt`; shellcheck as CI runs it; quickstart blocks 1-3 (`$RUN/qs-1-3.sh`: R1 ok, R2 ok).
- [X] T003 [US1] One mutant per link check, each in a scratch worktree holding this tree, each shown landed (the changed line echoed) and `bash -n` clean before its red is believed: each check of T002 removed, and `shown p_s` put back below the checks (N3 red on the message); N1-N4 red on their own clause where this system makes links, including the reverse walk's `.claude-plugin` and `plugin.json` checks (the nested N4 plants); the component count removed (N7 red: the 65- and 2,046-component sources not refused), set one lower (the 64-component source red) and one higher (the 65-component source red), and taken inside the loop again (the 65-component source red: the walk stops at its first missing component). Save to `$RUN/t003-mutants.txt`, with the rig.

**Checkpoint**: T001's test green; every link mutant red; real tree and walk unchanged.

## Phase 2: User Story 2 — no program but the gate speaks, and no option changes it (Priority: P1)

**Goal**: J1-J2, N6, X1-X2, O1 in `contracts/release-gate.md`.

**Independent test**: the TRAILING test, the P test and the new test pass,
and fail against the gate at the end of Phase 1 on J1, X1 and O1.

- [ ] T004 [US2] In `tests/portability.bats`, add plants (no new test):
  - (J1, J2) in the TRAILING test, AFTER its existing plants and each on its own fixture directory: a trailing entry whose `name` is the object `{"::error title=x::y": 1}`; `.plugins` set to the string `::error title=x::y` followed by ESC `[2K`; a `marketplace.json` of two JSON documents (`{"plugins": "x"}` then a valid one: `jq -e` judges only the last, measured); a `marketplace.json` that is valid JSON of the wrong type (`[]`); a `marketplace.json` that is not JSON (`{"plugins": [`); an empty `marketplace.json` (not JSON: research R2); a `plugin.json` that is not JSON; an empty `plugin.json` (not JSON: research R2); a `plugin.json` whose `name` is a number; a `plugin.json` that is `[]`; a `plugin.json` of two JSON documents; a `plugin.json` whose `version` holds a NUL, and a marketplace entry whose `source` holds one, each written with `jq` as the `\u0000` escape (a raw NUL byte is not JSON: research R2). Each exits 1 with the gate's whole line from `data-model.md` "A JSON file's shape" ("is not valid JSON" for the not-JSON and empty plants, the wrong-shape line for the others, including the two-document, `[]` and NUL plants of each file, and no output line holds `ignored null byte`); and the TRAILING test's comment says its first plant (a `name` that is an object) is now stopped by the shape check before the `@tsv` read it was written for (research R2), no output line starts with `jq:`, and the output is printed safely;
  - (X1) in the P test, after P6 and before P0: a `plugin.json` version `1.0.0 ##[error]x`, a first changelog heading `## [Unreleased] ##[error]x` above the release (release form), and a changelog line the walk refuses holding `##[error]x` (release form), that last one also under `forms_utf8`: each output holds no `##[` in any line and holds `#?[` where it was;
  - (X2) in the P test, at its start, only when `GITHUB_ACTIONS` is `true` (so a local run prints nothing and the suite check stays clean): five lines through file descriptor 3, `##[warning]p28 probe: start of line`, `# x ##[warning]p28 probe: mid-line`, `##[group]p28 probe: group`, `##[endgroup]` and `::warning::p28 probe: control`, under a comment saying the probe is temporary, measured once in CI and removed before merge (research R3);
  - (N6) in the new test, after O1 (so against the Phase 1 gate the first red in this test is O1 on every system): where a mode of 000 stops a read (Linux and macOS, not as root; decided as L5 decides, and printed as `# unreadable:` there), a `marketplace.json` made unreadable: `check-versions.sh: .claude-plugin/marketplace.json could not be read` alone, never "is not valid JSON";
  - (O1) in the new test, AFTER the N plants and before N6 (so against an older gate its first red is an N clause): for each of `xtrace`, `verbose`, `noglob`, `keyword`, run the fixture `$base` (not the real tree) in both forms with `env SHELLOPTS="$o"` on the inner gate command only (in the `run bash -c` wrapper's own command line it makes xtrace trace test paths, and `SHELLOPTS=$o bash` inside bash is a read-only variable that runs the gate without the option, measured), and compare with one run per form without it, made once: exit and standard output equal, and standard error (captured to a file in `$TEST_DIR`, not through `$( )`) exactly as FR-006 allows, from the test's own copy of the gate's first two lines (never read from the gate): for `xtrace` the one line `+ set +o xtrace +o verbose +o noglob +o keyword`; for `verbose` the `#!` line and `set +o xtrace +o verbose +o noglob +o keyword`; for `noglob` and `keyword` nothing. A line placed lower would let `verbose` echo the header and `xtrace` trace values (measured at F: with the line at :166 both forms kept their exit and standard output while `verbose` echoed 166 lines).
  Run the three tests against the gate as it stands and save to `$RUN/t004-red.txt`: J1, X1 and O1 must each fail on their clause, not a fixture error.
- [ ] T005 [US2] In `scripts/check-versions.sh` (research R2, R3, R4; `data-model.md`):
  - at line 2, directly after the `#!` line and before the header comments (so `verbose` echoes nothing but those two lines): `set +o xtrace +o verbose +o noglob +o keyword` (this exact spelling: O1 compares standard error with it); the comment saying why, and that `noexec`, `onecmd` and `BASH_ENV` cannot be stopped from inside, goes below it (research R4);
  - after `command -v jq` (`:89`, so a missing `jq` keeps its own message and is never read as "not valid JSON"): an open check on `marketplace.json` (`.claude-plugin/marketplace.json could not be read`), as Phase 27's on `plugin.json`; then its shape check, `jq -e -s` on standard input with its standard error discarded and exactly the filter research R2 gives (an empty input sent to `error`, so it reads as not JSON; `length == 1` and `.[0] | type == "object"` before anything else, so valid JSON of the wrong type cannot raise a runtime error; no NUL in any string): status 1 the wrong-shape line, any other non-zero status "is not valid JSON"; the same for `plugin.json` after its open check, on standard input as `:188` reads it (native Windows `jq` cannot open a path holding `:`); every later `jq` read with `2>/dev/null` and, where it assigns, `|| die` with the gate's own line;
  - in `shown`, after the mask, `##[` shown as `#?[`, the pattern and replacement held in variables (the pattern quoted, `${s//"$hh"/$hm}`); the same step on the walk's refusal text after the walk, in bash, so the walk's text does not change.
  Run the three tests and the one-script test, saved to `$RUN/t005-green.txt`; shellcheck; quickstart blocks 1-3.
- [ ] T006 [US2] One mutant per rule, as T003: the options line removed (O1 red); the options line moved below the header comments (O1 red on `verbose`'s standard error); each shape check removed (J1 or J2 red); for each file, `-s`, `length == 1 and` and `.[0] |` removed together (the two-document plant red; removing `-s` alone breaks every file and shows nothing); the type guard removed (the `[]` plant red, read as "not valid JSON"); the empty-input `error` removed from each filter (that file's empty plant red: without it an empty file exits 1, the wrong-shape line); the NUL test removed from each filter (the NUL plants red); the `marketplace.json` open check removed (N6 red, Linux and macOS only, as L5's); the `##[` step removed from `shown` (X1 red) and from the refusal (X1 red). No mutant removes a later read's `2>/dev/null`: once the shape check has passed, no plant can make a later read fail (that discard is a backstop; research R2 says so). Save to `$RUN/t006-mutants.txt`.

**Checkpoint**: the three tests green; every mutant red; real tree and walk unchanged.

## Phase 3: User Story 3 — the walk costs no process per entry, and the tests check what they claim (Priority: P2)

**Goal**: C1, T1-T3 in `contracts/release-gate.md`.

**Independent test**: C1 passes under its bound; each changed helper's
control goes red under its mutant.

- [ ] T007 [US3] In `tests/portability.bats`:
  - (C1) in the TRAILING test, AFTER the J plants (so against an older gate on Windows the J plants still fail first): the first plugin plus 2,000 entries `{name: "x<i>", source: "./<first plugin>"}`, built with one `jq` program, run under `timeout 15` where `command -v timeout` finds one: exit 1, refused for its count (`marketplace lists`), the system printed through file descriptor 3 as `# walk: <uname -s>`;
  - (T1) `die_raw` in the P test also reports `printf -v`, `read` and `for` into a name ending `_s`, a `$(` not followed by `(` inside a `die` message, and continues a `die` line ending in `\` onto the next line; its control plants one line of each and must name each exactly; no apostrophe inside the awk program;
  - (T2) the K test's quote-marker plant keeps its size from the room under the limit, with the margin cut from 8,192 bytes to what the plant needs (64), and drops the 50,000-pair floor; its only floor is that the line is longer than the line limit (the tests' own copy, 1000), so it fits whenever the copy leaves room under the size limit for the margin and a 1,001-byte line;
  - (T3) `gate_safe` removes only the gate's own ` — this tree is NOT released` before it checks, and also fails any line holding `##[`; in its control, `ok — ok` moves from the must-pass case to the must-fail list, the suffix becomes the must-pass case, and `a — b` and `x ##[y` join the must-fail list (each must fail with exactly 1). The gate's other em dash, in "run me from the repository root — …" (`:87`), is never in a test's output that `gate_safe` reads; if one is, it fails, as it should.
  Run the P, K and TRAILING tests against the gate as it stands and save to `$RUN/t007-red.txt`: C1 red where a process per entry costs enough to pass the bound (this machine), every other change green (they change tests, not the gate).
- [ ] T008 [US3] In `scripts/check-versions.sh`: `norm_source <name> <value>` sets the named variable with `printf -v`; both walks call it with no `$( )` (research R5). Measure the cost before and after on the seed's fixture (the first plugin plus 400 entries), same run, save to `$RUN/t008-cost.txt`, and write both figures into research R5. Run the P, K and TRAILING tests and the one-script test, saved to `$RUN/t008-green.txt`; shellcheck; quickstart blocks 1-3.
- [ ] T009 [US3] Mutants, as T003: the subshell restored (C1 red here; say on which systems it can go red); each new P0 shape removed from `die_raw` (its control red); `gate_safe` back to removing every em dash, and without its `##[` rule (its control red each time); and for T2, a run of the K test in a scratch worktree whose copied changelog is padded to about 200,000 bytes: green now, and a `fixture:` failure with the 50,000-pair floor put back (with the 64-byte margin that floor fails above 262,144 − 64 − 100,004 = 162,076 bytes of copy; the run states the figure it used). Save to `$RUN/t009-mutants.txt`.

**Checkpoint**: the four tests green; every mutant red; real tree and walk unchanged.

## Phase 4: Polish

- [ ] T010 Time the L, P, K, TRAILING and new tests on the final code (`bats -T`), save to `$RUN/t010-times.txt`; a test over 30 s has its runs reduced before going on (each gate run now starts one or two more `jq`, and the new test makes about 30 gate runs: O1's eight runs are the first to share or drop). Then run the whole of `quickstart.md` (blocks 1-8) as one extracted script with `bash`, in the background, with a timeout of at least 30 minutes; save to `$RUN/final-quickstart.txt`. It ends `ALL OK`.

**Not an H task (FR-003, X2)**: after gate L, read the first pull request
run's annotations for each test job (`gh api`, from PowerShell) and its
log as the runner rendered it (`gh run view --log`), record in research
R3 what the runner did with each probe line, annotation and rendering
both, with the run id; then remove the probe in the first commit after that run, and before
merge show `grep -c 'p28 probe' tests/portability.bats` printing `0`.
Read the `# nolinks:` and `# walk:` lines of each system for the pull
request body.

## Dependencies & Execution Order

- Phase 1 before Phase 2: O1 lives in the test T001 adds.
- Phase 2 before Phase 3: T007's `gate_safe` change applies to the J
  plants T004 adds, and C1 reads the walk T005 leaves.
- Within each phase, the order is test (red), code, mutants.
- T010 last, on the tree that is committed.

## Parallel Opportunities

None worth taking: every task edits `scripts/check-versions.sh` or
`tests/portability.bats`, and two agents never edit one file in a batch.

## Implementation Strategy

Each phase is one piece and one commit, reviewable alone: Phase 1 closes
the reads through a link, Phase 2 the lines no one masked and the
options, Phase 3 the cost and the tests' own blind spots. The MVP is
Phase 1, because it is the only one that stops the gate reading a file
outside the checkout.
