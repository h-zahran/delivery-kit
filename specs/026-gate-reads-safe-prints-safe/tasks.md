---

description: "Task list for the release gate reading only what it can judge and printing only what is safe"
---

# Tasks: The release gate reads only what it can judge, and prints only what is safe

**Input**: Design documents from `specs/026-gate-reads-safe-prints-safe/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: the spec asks for tests (FR-010, FR-013, SC-005). Each new test
is written FIRST and shown red against the gate as it stands before the
code it covers is written. Two tests are added; the suite reads `1..251`.

**Run directory**: `$RUN` = `.delivery-kit/runs/026-gate-reads-safe-prints-safe/`.

**Pieces**: each `## Phase` below is one piece and one commit.

**Commit messages**: no `Co-Authored-By`, no `Claude-Session` and no
"Generated with" line, in any commit or pull-request text this run writes.

**Every gate run in a test** goes through `run bash -c '…' _ <args>` with
the data as arguments, never `run bash <script>.sh` (the one-script test
counts those), and every captured output passes `forms_no_path`. Every
`tr`, `grep`, `wc` or `awk` a test runs on a file or an output that may
hold a byte which is not valid text runs under `LC_ALL=C`. Every test
failure echoes its contract clause first (`L1: …`), and a fixture failure
`fixture: …`.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: User Story 1 — the gate reads only a regular changelog of bounded size (Priority: P1)

**Goal**: L1-L4 in `contracts/release-gate.md`.

**Independent test**: the new test `the gate reads only a regular
changelog of bounded size` passes, and fails against the gate at `$BASE`.

- [X] T001 [US1] In `tests/portability.bats`, after the test "--released refuses a byte or a line it cannot judge", add the test `the gate reads only a regular changelog of bounded size` (ASCII name). It builds a one-plugin fixture with `forms_base one`, then, each plant on its own copy of `$base` (`cp -r`), checks:
  - (L1) in the judged plugin's directory, a copy of its changelog as `real.md`, then `CHANGELOG.md` replaced by a link to `real.md`; and, on another copy, by a broken link to `missing.md`. Each link is made with `MSYS=winsymlinks:nativestrict ln -s <target> CHANGELOG.md 2>/dev/null || true` (or inside an `if`, as quickstart block 6 does), so a link that cannot be made reaches the `[ -L ]` decision and never ends the test under errexit, and is checked with `[ -L ]` before it is believed. Where it is a link, both forms exit non-zero with `is a symbolic link` and the plugin name. Where no link was made: if `uname -s` matches `MINGW*`, `MSYS*` or `CYGWIN*`, write in its place a regular file holding the target path (what a checkout makes there) and assert both forms exit non-zero with `no changelog heading`; on any other system, fail with `fixture: …` (research R5). The test prints exactly one line, `echo "# links: made" >&3` or `echo "# links: not available here" >&3`, as soon as the first `[ -L ]` decides and before any assertion, so a failing run prints it too: file descriptor 3, because bats hides a passing test's output, and the `# ` prefix, because `scripts/check-suite.sh` counts any other line as stray output. If the second link's outcome differs from the first's, fail with `fixture: …`.
  - (L2) a directory named `CHANGELOG.md`: both forms exit non-zero with `is not a regular file`.
  - (L3) the changelog padded with `Plain text.` lines (12 bytes each) while at least 12 bytes are left to 262,144, then one line of `y`s, its newline included, holding exactly what is left, and no line when nothing is left (computed from the size read with `LC_ALL=C wc -c <` and arithmetic; under 12 bytes, so inside the line limit). Write the padding with one `LC_ALL=C awk -v BINMODE=3` program, as quickstart block 6 does, never a per-line bash loop: bats' debug trap made such a loop take 19 s (measured at F). Assert the size is exactly 262,144 (`fixture: …` if not); `--released` exits 0. Then `printf y >>` the file, assert exactly 262,145, and assert `--released` exits non-zero saying `262145 bytes` and `262144`, and the default form exits 0.
  - (L4) the changelog removed: both forms exit non-zero with `no changelog heading in the pinned`, and no output line starts with `grep:` or `jq:` (FR-014).
  Assert every refusal names the plugin, and every output passes `forms_no_path`. Run it against the gate as it stands and save to `$RUN/t001-red.txt`: it must fail on an L clause, not a fixture error.
- [X] T002 [US1] In `scripts/check-versions.sh`: add `changelog_limit=262144` beside `line_limit`, with a comment that holds no count; in the per-plugin loop, before the NUL check, refuse in this order (research R1, R2; data-model.md): a symbolic link (`[ -L ]`), anything that exists and is not a regular file, and, inside the existing `if [ -f "./$p/CHANGELOG.md" ]` block and for the plugin `--released` names only, a size over the limit read with `LC_ALL=C wc -c <` and printed as `$((size))`. Each message names the plugin and adds ` — this tree is NOT released` only for the named plugin, as the NUL message does: move the two `unreleased` lines (`:210`-`:211` at `$BASE`) above the link check, so all four refusals read the current plugin's suffix (inside the `[ -f ]` block they would be unset under `set -u` for the first plugin, and stale for a later one). Add `2>/dev/null` to the `head` grep (`:238`), whose failure the gate reports itself on the next line (research R11), so a missing changelog prints only the gate's own line (L4), and rewrite the comment at `:228`-`:234` (at `$BASE`), which says grep's own "No such file" line would print. The `first` grep (`:262`) is left alone: the gate dies at `:239` before it on any changelog it cannot read (measured at F). Run T001's test and the one-script test (`$RUN/t002-green.txt`), record T001's wall time there (over 30 s: reduce its runs before going on), shellcheck as CI runs it, and check both forms on the real tree print as at `$BASE` (quickstart block 2) and the walk's sha256 is unchanged (quickstart block 3).
- [X] T003 [US1] One mutant per rule, each in a scratch worktree holding this tree, each shown landed (the changed line echoed) before its red is believed: the link check removed (L1 red where this system makes links; say so); the file-type check removed (L2 red); the size check removed (L3 red); the size comparison off by one (L3 red); the `2>/dev/null` removed from the `head` grep (L4 red). Save to `$RUN/t003-mutants.txt`.

**Checkpoint**: T001's test green; five mutants red; real tree unchanged.

## Phase 2: User Story 2 — nothing read from a file can write into the log (Priority: P1)

**Goal**: P1-P6 in `contracts/release-gate.md`.

**Independent test**: the new test `the gate prints every value masked`
passes, and fails against the gate at `$BASE`.

- [ ] T004 [US2] Re-derive the print-site table from `scripts/check-versions.sh` as it stands after T002: list every `die` and `printf` line and every variable each one prints (`grep -nE 'die "|printf '`, which is the same on GNU and BSD grep), save to `$RUN/t004-sites.txt`, and compare with the spec's table. Any value or site the table lacks is added to the spec's table and to research R3 before T006 (Principle V: derived, not remembered).
- [ ] T005 [US2] In `tests/portability.bats`, after T001's test, add the test `the gate prints every value masked, and no line starts with ::` (ASCII name). It builds its fixture with `forms_base one` (a valid, released one-plugin fixture) and runs each plant on a fresh `cp -r` copy of `$base`. `F` below is the forged text `1.0.0`, a line feed, `::error title=x::y`, ESC `[2K`. Every `jq` edit selects by position (`.plugins[0]`, `.plugins += […]`), never by name: a by-name selection is the marker the one-script test refuses (`tests/portability.bats`, "one version-agreement script"). The plants, each with the exit it must give once T006 is in:
  - (P1) `plugin.json` version set to `F`: exit 1 (the report line, then plugin against marketplace). `plugin.json` name set to `F`: exit 1 (name against directory).
  - (P2) `.plugins[0].version` set to `F`: exit 1. `.plugins[0].source` set to `F`: exit 1 (source does not resolve). An appended entry `{name: F, source: ("./ghost" + F)}`: exit 1 (names no plugin directory). An appended entry `{name: F, source: ("/abs" + F)}`: exit 1 (an absolute path). These two reach the reverse walk, which reads the entries through `@tsv`: there a line feed arrives as the two characters `\n` and ESC arrives raw.
  - (P3) the plugin directory renamed to `::` + ESC + `x`, with its `plugin.json` name, `.plugins[0].name` and `.plugins[0].source` (`./` + the name) set to match. Set the `plugin.json` name BEFORE the rename: native Windows `jq` cannot open a path holding `:` or ESC (research R4; measured again at F). Check every `jq` edit's exit status in this test and fail with `fixture: …` on a non-zero one. Then: exit 0, and the report line starts with `?:?x: plugin=`. The same with a directory named space, `::`, ESC, `x`: exit 0, and the report line starts with `??:?x: plugin=`. On a fresh copy, the `plugin.json` name set to a different value before the directory is renamed to `::` + ESC + `x`: exit 1, and the output holds `::?x` in that message.
  - (P4) `--released` with the argument `a` ESC `b`: exit 1, the output holds `a?b`. An unknown argument `x` ESC `y`: exit 1, the output holds `x?y`.
  - (P5) `--released <copied>` with the line `## [Unreleased] ` ESC `[2K` written above the changelog's first line: exit 1; the output holds `## [Unreleased] ?[2K` in the report line's state and in the refusal, and that refusal holds the em dash bytes `\342\200\224`.
  - (P6) `plugin.json` version set to 250 `x`s: exit 1; the output holds 200 `x`s followed by ` [cut]`, and never 201 `x`s in a row. An unknown argument `x`, the byte `\x9b`, `é` (`\xc3\xa9`), `y`, run under `LC_ALL=$utf8` from `forms_utf8`: exit 1; the output holds `x???y`.
  For every run: assert the exit given above; pass the output through `forms_no_path`; assert with one program, `LC_ALL=C awk -v BINMODE=3`, that after every em dash is removed no byte is outside space to `~` and no line matches `^[ ]*::` (research R6); and assert the masked fragment named above, matched as a quoted literal (`case "$output" in *"$frag"*)`, as `forms_refused` does, or `"??:?x: plugin="*` for a line start), never as a bare glob: `?` is the mask character and also a glob wildcard, so a bare pattern would match the unmasked text too (measured at F: with the leading-space rule removed, a bare `??:?x:\ plugin=*` matched ` ?:?x: plugin=`); or for `F` the fragments `1.0.0?` and `::error title=x::y?[2K`, which avoid the line feed: native Windows `jq` writes it as CR LF, so the masked text holds one `?` or two there. The two appended entries are the exception: `@tsv` has already turned the line feed into a backslash and `n`, both printable, so their fragment is `1.0.0\n::error title=x::y?[2K` (a literal backslash and `n`; measured at F). Run it against the gate as it stands and save to `$RUN/t005-red.txt`: it must fail on a P clause, not a fixture error.
- [ ] T006 [US2] In `scripts/check-versions.sh`: replace `quoted()` with `shown <name> <value>` (cut at `quote_cut` with ` [cut]`, then mask every byte outside printable ASCII as `?`, under `LC_ALL=C`, stored with `printf -v`; research R3); give every value of the print-site table a `_s` copy made where it is read; print only the copies in every `die` message and the report line; drop the report line's CR/LF strip; in the report line's first field, show the leading spaces and a `:` that directly follows them (or starts the field) as `?`. Read `plugin.json` through standard input (`jq -r '.name // empty' < "./$p/.claude-plugin/plugin.json"`, and the same for the version; research R4, R11). Define `quote_cut` and `shown` above the argument loop, because the unknown argument (`:90` at `$BASE`) is printed through it, and declare every `_s` name once, empty, beside `shown` (`p_s='' pn_s='' pv_s='' mv_s='' cv_s='' ms_s='' head_s='' first_s='' en_s='' es_s='' rel_s='' arg_s=''`), so ShellCheck sees an assignment (research R3); no `disable` directive. Update the comments that name `quoted()` (near `:109` and `:309` at `$BASE`) to name `shown`, and rewrite the comments at `:106`-`:112`, above `line_limit` (`:113`) (`quote_cut` now sits apart from `line_limit`), `:116`-`:124`, `:137`-`:142` (`jq` no longer receives the path) and `:245`-`:249` (at `$BASE`) to describe `shown` and the masking that replaces the strip; `:309` is outside the walk's hashed text, so R2 still holds (check it). Comparisons keep the raw values; the gate's own text is never passed through `shown`. Run T005's and T001's tests and the one-script test (`$RUN/t006-green.txt`), record T005's wall time there (over 30 s: reduce its runs before going on), shellcheck, quickstart blocks 2 and 3 (real tree unchanged, walk unchanged).
- [ ] T007 [US2] One mutant per rule, each in a scratch worktree, each shown landed: `shown` without its mask (P1 red); `shown` without its cut (P6 red); `shown` without its `LC_ALL=C` (P6 red); `$pv` printed raw in the plugin/marketplace message (P1 red); `$en` printed raw in the "names no plugin directory" message (P2 red); the report line's leading-`:` rule removed (P3 red); its leading-space rule removed (P3 red); `shown` applied to the whole "sits above the released heading" message (P5 red: the em dash is masked); `plugin.json` read by path again (P3 red on Windows, where native `jq` cannot open the name; on Linux and macOS it survives, and the record says so). Save to `$RUN/t007-mutants.txt`.

**Checkpoint**: T005's test green; nine mutants red on Windows (eight elsewhere, the ninth named as surviving there); real tree and walk unchanged.

## Phase 3: Polish

- [ ] T008 Run the whole of `quickstart.md` (blocks 1-8) as one extracted script with `bash`, in the background, with a timeout of at least 30 minutes; save to `$RUN/final-quickstart.txt`. It ends `ALL OK`, with both new tests red against the base gate, one naming an L clause and one a P clause, neither a `fixture:`, `R1 ok`, `R2 ok`, SC-001 and SC-003, and SC-006 read by `scripts/check-suite.sh 251`.

**Not an H task (the CI half of SC-006 and FR-011)**: at phases L and N,
read the `# links:` line of each operating system's job from the CI log,
and put all three in the pull-request body.

## Dependencies & Execution Order

- Phase 1 before Phase 2: T006 reprints the messages T002 adds, so it
  must see them, and T004 derives the sites from the script after T002.
- The `2>/dev/null` on the changelog grep is in T002, not T006: L4,
  a US1 clause, needs it.
- Within each phase, the order is test (red), code, mutants.
- T008 last, on the tree that is committed.

## Parallel Opportunities

None worth taking: every task edits `scripts/check-versions.sh` or
`tests/portability.bats`, and two agents never edit one file in a batch.

## Implementation Strategy

Each phase is one piece and one commit, reviewable alone: Phase 1 closes
the hang and the size gap, Phase 2 the log forgery. The MVP is Phase 1,
because it removes the only way the gate can run until it is killed.
