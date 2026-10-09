# Research: The release gate starts fewer processes, and its walk is tested on its own

All measurements: 2026-10-08, this machine (Windows, Git Bash, bash 5.x,
jq 1.8.1, gawk), against `main` = `2b38f74` unless a line says otherwise.
The scripts that took them were run from the session's scratch directory;
each is described closely enough here to be run again.

## R1 — One `jq` process per `plugin.json`, answering the marketplace too

**Decision.** For each plugin, one `jq` process reads `plugin.json` on
standard input (as today) and the marketplace through
`--slurpfile m .claude-plugin/marketplace.json` (a fixed relative path,
as `:360`, `:362` and `:375` pass it today). It runs `plugin_shape`
unchanged; on a wrong shape it outputs `false` (exit 1 under `-e`); on an
error (not JSON, empty) it exits with jq's own status, as today. Otherwise
it outputs, as length-prefixed fields (R4): the name, the version, `1` or
`0` for "an entry has this name", the matching entries' versions, and
their sources — each computed the way the old reads computed it:

| Old read | Old value | New field |
|---|---|---|
| `:326` `jq -r '.name // empty'` in `$( )` | trailing line feeds stripped by `$( )` | `.[0].name // ""`, trailing line feeds removed |
| `:328` `.version // empty` | same | same, for `.version` |
| `:360` `jq -e … select(.name == $n)` | exit 0 when an entry matched (entries are objects, so truthy) | `1` when the list of matches is not empty |
| `:362` `… \| .version // empty` in `$( )` | one line per match, joined by line feeds, trailing line feeds stripped | `[matches \| .version // empty] \| join("\n")`, trailing line feeds removed |
| `:375` `… \| .source // empty` | same | same, for `.source` |

`$n` was the stripped name; the new read compares `.name` with the same
stripped name, inside the same process, and binds it as `$n`: test 652
("one version-agreement script …") requires the gate's text to hold
`select(.name == $n)` (its marker regex) and the callers' text not to. The old code ran the three
marketplace reads only after `pn` equalled the directory name; the new
read computes them always, and the gate uses them only at the same point,
so the order of messages does not change.

**Measured.** A prototype ran the new read and the six old reads (each
with `-b`, so both give the Linux bytes; see R5) over 21 fixtures: a
plain pair; a missing, `null` and `false` name and version; empty
strings; a name and a version ending in line feeds, and a CR before a
line feed; a name holding a line feed matched against an entry whose name
ends in one; three entries sharing a name, one with a version ending in a
line feed and one with none; `""`, `null` and `false` entry values; a tab,
a backslash, `##[`, `::`, a non-ASCII and a four-byte character; extra
keys; `[]`; a number for the name; text that is not JSON; an empty file;
two documents; a NUL; no entries; and bytes that are not valid UTF-8. The
exit status classes (0, 1, other) agreed on every fixture, and every field
agreed except one: the version `1\r\n`, which the old read gave as `1`
and the new as `1\r`. That one came from the prototype running the old
reads WITH `-b`, which the old gate never did: the old gate itself, in text
mode, read `1\r`, as the new one does (measured at T015; R5).

**jq's `+`.** Every `+` in the new program joins two strings on purpose:
a length written by the program (`"\(utf8bytelength):"`) and a value the
shape check has made a string (`// ""` turns a missing, `null` or `false`
one into `""`). No `+` adds numbers, so the trap that broke a one-`jq`
refactor here before (a string reading joined where a sum was meant)
cannot arise.

**A race, recorded.** If the marketplace stops being readable between the
top read and a plugin's read, `--slurpfile` fails, `jq` exits with an
error status, and the gate says `<plugin>: plugin.json is not valid JSON`
where the old gate said `.claude-plugin/marketplace.json could not be
read`. No fixture can build this (it needs the file changed mid-run); the
wrong file is named only in a race, and the gate still refuses.

**Alternatives.** One `jq` per file for `plugin.json` and one read of the
marketplace answering every plugin (the seed's wording) — rejected in R3.
Passing each plugin's name to one marketplace `jq` as `--arg` — rejected:
the arguments of one process are bounded on Windows (about 32,000
characters), and a fork sets how many plugin directories there are.

## R2 — One `jq` process for the marketplace

**Decision.** The shape check at `:174` and the entry list at `:766`
become one process: `market_shape` unchanged, then, when it holds, the
same expression `:766` runs today, `.[0].plugins[] | [.name, (.source //
"")] | @tsv`, its lines joined by line feeds, then a terminator (R4). The
reverse walk reads it as today. Its output bytes are the old ones:
`@tsv` escapes a tab, a line feed, a CR and a backslash, so no raw line
feed or CR is inside a line; `-b` writes no CR (the old `${es%$'\r'}` was
kept at first, as a guard, and removed at H.7: nothing can reach it).

The read moves from after the forward loop to the top. Its only failure
past the shape check is the file becoming unreadable between two reads in
one run; its message is the same text.

## R3 — Why the marketplace answers are not cut apart in bash

The seed asked for the per-plugin answers to come from the one
marketplace read. That needs every entry's name, version and source in
bash, cut out of one string. Measured: cutting length-prefixed records out
of a string with `${s:off:len}` under `LC_ALL=C` took 155 ms for 33,000
bytes, 2,441 ms for 132,000, and 39,358 ms for 528,000 — four times the
size, sixteen times the time. A fork sets the marketplace's size, and the
entry limit (`entries_limit`) is checked only in the reverse walk, after
the forward loop. R1 keeps the process count the seed wanted (1 + N) with
the cutting done by `jq`. Recorded as a departure from the seed's
parenthesis, in the spec (FR-001) and here.

## R4 — Fields without a separator

**Decision.** No value can hold a separator that `jq` can write: every
character but NUL can sit in a JSON string, and a NUL cannot cross `$( )`.
So each field is written as `<bytes>:<value>`, where `<bytes>` is
`utf8bytelength`, and the output ends with `.`. The gate cuts the fields
under `LC_ALL=C`, so bash counts bytes, as `shown` already does.

- **Measured:** `utf8bytelength` equals bash's byte count under `LC_ALL=C`
  for `é中😀x` (10 and 10) and for a name given as bytes that are not valid
  UTF-8 (`jq` reads them as U+FFFD, writes `ef bf bd` twice: 8 and 8).
- The terminator stops `$( )` from stripping a value's trailing line
  feeds; the gate checks it is there and removes it. Measured at T015, it
  guards nothing reachable today: `nl` removes trailing line feeds inside
  `jq`, and `$( )` keeps a lone trailing CR, on Git Bash too. It stays as
  a guard should `nl` ever change. Its mutant survived the suite at T015
  (recorded with the mutants below); since phase I the R4 test reaches it
  and every other record guard, with a `jq` on PATH that hands the gate a
  record no real read writes.
- Only five fields per plugin, so the cutting is constant work (R3's cost
  is per record).
- A field whose length is not digits, or of more than 18 digits, or a
  length past the end, or bytes left over, is a hard failure with the
  gate's own line ("could not be read"), never a silent wrong value. The
  18-digit bound came at phase I (security lens M4): a 20-digit length
  reached `[ -ge ]`, and bash printed its own error, naming the gate's
  path as invoked.

## R5 — `-b`, three jq versions, and the Windows divergence

- `-b` (`--binary`) stops Windows `jq` writing a CR before each line feed.
  It is documented since jq 1.6 and accepted on every system; CI's three
  jobs (jq 1.7, 1.8.1, 1.8.2) are the measurement that it is accepted
  there.
- `utf8bytelength` exists since jq 1.6; `--slurpfile` since 1.5; `def`
  with recursion in all three.
- **The Windows divergence (measured).** `jq -r` without `-b` on Windows
  writes `a\r\nb` for the value `a\nb`; Git Bash's `$( )` keeps an inner
  CR and strips trailing CRs with the line feeds. So the old gate read
  `a\nb` as `a\r\nb` on Windows and `a\nb` on Linux, and `1\r\n` as `1`
  on Windows and `1\r` on Linux. The new gate gives the Linux bytes on
  every system. Every such value is printed through `shown`, which masks
  CR and line feed alike as `?`, so the visible difference on Windows is
  the number of `?`. The class also holds entries sharing a name, whose
  versions or sources the old read printed one per line (`1.0.0\r\n2.0.0`
  on Windows), found by the differential at T013 (the `dup` fixture).
  Measured afterwards, old `jq -r` in text mode into Git Bash's `$( )`:
  `x\r` reads `x\r`, `x\r\n` reads `x\r` (as on Linux, where `$( )`
  strips the trailing line feeds and keeps the CR), `x\n\r` reads
  `x\r\n\r`, `a\nb` reads `a\r\nb`. So only a line feed with something
  after it diverges; a trailing CR or trailing line feeds do not. (The R1
  prototype's `1\r\n` → `1` came from running the OLD reads with `-b`,
  which the old gate never did; the real old gate read `1\r`, as the new
  one does.)
  The differential (R10) asserts it: on Windows the
  fixture LF1 must differ, any difference on a run whose tree holds no
  such line feed is a failure, and on any other system no run may differ.
- **Linux and macOS.** The differential runs on this machine only, so
  "byte-identical on Linux and macOS" rests on (a) the suite's message
  tests, which run on all three CI systems and pin every message, plus
  T014's plants of non-ASCII, four-byte and invalid bytes (FR-004), and
  (b) R1's prototype, which compared the reads' values with `-b` on both
  sides. If WSL with `jq` is available here, the differential is also run
  there once and recorded; otherwise this paragraph is the record.

## R6 — The walk file

**Decision.**

- **Name and place:** `scripts/check-versions-walk.awk`, beside the gate.
  Not `.sh`: test 652 ("one version-agreement script, and both gates call
  it") allows exactly one `run bash <x>.sh` line in `tests/portability.bats`
  and one `bash <x>.sh` line in CI, and the direct tests run the walk as
  `awk -f`.
- **Content:** a header of `#` comments (what the file is, who runs it,
  what it reads from the environment, where its steps are explained),
  then the old program's text from `:545` to `:728` byte for byte (R7),
  then, since phase I, one line: `END { print "WALK-END" }` (R12 item 7).
- **Located:** from `BASH_SOURCE`: its directory part, or `.` when it has
  none. Every fixture runs the gate as `cd "$copy" && bash
  "$ROOT/scripts/check-versions.sh"` with no `scripts/` in the copy, so a
  walk looked up from the working directory is not found and every
  release-form test goes red (the mutant SC-004 names).
- **Checked:** before the walk runs, `[ -f "$walk" ]` and `{ : < "$walk";
  } 2>/dev/null`, as every file the gate reads is opened; otherwise the
  gate stops: `<plugin>: the heading walk check-versions-walk.awk beside
  the gate could not be read — this tree is NOT released`, exit 1. The
  path is not printed: it can be absolute, and the suite's U2 check
  refuses any spelling of the test directory or the repository root.
- **Run:** `awk -f "$walk" "./$p/CHANGELOG.md"` with the same
  environment as today. Its standard error is discarded (a broken walk
  file would print its path), and its exit status is checked: anything but
  0 stops the gate with `<plugin>: the heading walk did not run to the
  end — this tree is NOT released`. Today a failing walk ends the
  assignment under `errexit` with no message at all (`:535-537` says so).
  With the "could not be read" line above, these are the two new
  messages; both fire only on a broken installation of the gate.
- **No link rule** (clarification, 2026-10-08): the walk file is code with
  the gate's own trust — CI runs the pull request's own `scripts/` — so
  a link rule on it would guard nothing. This departs from the seed's
  sentence that the Phase 27 and 28 link rules apply to it.
- **The comments.** The gate's comment block above the walk (`:514-543`)
  stays in the gate, beside the call, and names the file. The awk
  comments move with the program. The comment at `:347-353` ("these three
  queries are deliberately NOT collapsed into one … Clarity wins") is
  replaced by one stating the new read and why: R1, R3.

## R7 — The walk's text does not change

The proof is a byte comparison: lines `:545` to `:728` of
`scripts/check-versions.sh` at `2b38f74` (from `git show`) against the
walk file's lines after its header. The difference must be empty; if the
body must change, the Phase 26 proof
(`specs/025-gate-closes-phase25-gaps/proof/enumerate.py`) is rerun. The
program holds no `'` today (the string's own quotes are on `:544` and
`:729`), so nothing needs unquoting. The body keeps its six-space indent,
which awk ignores.

## R8 — The tests

Inventory of `tests/portability.bats` (an agent's read-only report,
2026-10-08; every count derived from the code): 28 tests run the gate,
about 215 times on this machine with links made.

| Verdict | Tests (line) | Gate runs that move |
|---|---|---|
| MOVE | every bare level-2 form (1952), every setext form (1973), inside a quote or list item (2047), fence end unclear (2166), fence opener (2190), judges no non-heading (2263), Phase 26 narrowed shapes (2289) | all (about 55) |
| SPLIT | undated heading below release (1697), dated with note (1725), control byte below (1735), setext shapes review found (2009), nested quote (2061), deep line (2088), fence never closes (2126), pre block (2226), byte or line it cannot judge (2340) | the walk-only runs (about 43); the default-form, other-plugin, `H8`, `K4` under UTF-8 and `K5` NUL runs stay |
| KEEP | the other twelve | none |

**Decision.**

- A MOVE test keeps its name and assertions, and runs the walk directly:
  a helper `walk_on <changelog>` runs `awk -f "$ROOT/scripts/check-versions-walk.awk"`
  on standard input, with `DATED_RE`, `LINE_LIMIT`, `QUOTE_CUT` and
  `LC_ALL=C` set from the test file's own copies. As built (Phase 5
  record below), the conversion went through the shared helpers, and each
  test's base run stayed a whole-gate run: it is the "dated base that
  passes" end to end, one run per test, and it keeps every fixture proved
  valid against the whole gate before any plant is judged.
- **The test file holds its own copies of the three values** (they exist
  today: the dated pattern at `:1259` and `quote_cut=200` at `:3234`, both
  inside functions; `line_limit=1000` at `:2338`, already at file scope);
  the first two are hoisted to file scope, all three get one name each,
  and one new test proves each equal to the gate's assignment line. A
  fixture never reads the code under test.
- **End to end, one run stays for each thing only the gate does** (the
  inventory's list): the `## Notes` refusal and a dated base that passes
  (DATED_RE handed over), K3's 1,001-byte line (LINE_LIMIT), K4's cut
  value (QUOTE_CUT), K4 under UTF-8 and X1 under `LANG` (`LC_ALL=C`
  handed over), X1's `##[` (the gate's `#?[` step), and the exit status.
- **Gap closed:** no test compares a walk refusal with its whole line. A
  new test pins one walk refusal's complete output line, prefix and
  suffix included, end to end.
- **New tests for the new rules:** the walk file missing; at the walk's
  path a directory instead (not a regular file; portable where `chmod
  000` is not on Windows); a walk that exits non-zero (a copy that
  `exit 3`s); an apostrophe in a comment of a copied walk file beside a
  copied gate (the gate still runs); and the `jq` process count (a `jq`
  wrapper on `PATH` that logs each start, then runs the real one): 1 + N.
- The two "at most 400 bytes" checks (`:2368`, `:2431`) were planned to
  measure the gate's whole line. As built, only the first does, after
  K3's end-to-end run; the second follows the direct walk run of the
  quote-marker line and measures the walk's refusal (corrected at phase I).
- K3's plant sizes itself under `changelog_limit` only because the gate
  refuses a larger file first; the direct run keeps the same plant.
- New and moved assertions match in the shell (`[[ … ]]`), never with
  `grep … < <(printf …)` (spec FR-012).
- The P0 scan (`die_raw`) keeps reading only the gate: the walk file has
  no `die` and prints only through its own `show()`, and the gate's one
  use of its output, `refusal`, is already on the scan's trusted list, as
  today. It is not widened to the walk file.

## R9 — The count

At `2b38f74`: `1..426`. This feature adds five tests (R8: the held
values, the full refusal line, the walk-file failures, the apostrophe,
the process count) and removes none; the moved runs stay inside their
tests. Expected: `1..431`, judged by `bash scripts/check-suite.sh 431`.
If tasks change the number, tasks fix it.

Phase I (deep review) added five tests: W4 (a walk awk cannot parse),
W5 (the walk found from the name the gate was run by, and not at all from
standard input), R4 (a plugin record the gate cannot cut), NL (trailing
line feeds), LB1 (a line counted in bytes under UTF-8). Expected:
`1..436`, judged by `bash scripts/check-suite.sh 436`.

## R10 — The differential (one time, at build)

**Decision** (clarification, 2026-10-08): a quickstart step, run once, its
result recorded here; no frozen copy of the old gate is kept.

- **Coverage is derived, not listed:** in a worktree of the branch, the
  gate is replaced by a wrapper that runs the old gate
  (`git show 2b38f74:scripts/check-versions.sh`) and the new one in the
  same directory with the same arguments, compares standard output,
  standard error and exit status, logs any difference with the directory's
  fixture name and the arguments, and then behaves as the new gate. The
  whole `tests/portability.bats` runs over it, so every fixture the suite
  builds is compared. The tests that read the gate's own text (test 652,
  the P0 scan, the options-line test, the held-values test) go red over
  the wrapper; they are not part of the comparison. Each run is two gates,
  so the harness's copies of the test file and helper double every
  `timeout` and the per-test limit, each edit confirmed by a count.
- **Classified while the fixture exists:** the wrapper logs START and DONE
  for every run and marks it, at log time, LF or PLAIN (does a
  `plugin.json` name or version, or a marketplace entry's version or
  source, hold a line feed, or do two entries share a name: R5). The suite's `teardown` deletes the fixture
  afterwards, so this cannot wait. Since phase I, a third mark wins over
  both: SHIM, when the `jq` the run would start is not the real one. The
  R4 test puts a `jq` on PATH that hands the new gate a record no real
  read writes; the old gate never asks for one, so the two gates were not
  given the same input, and the run is compared, logged and counted but
  not judged. A SHIM run is allowed only in a test whose own text puts a
  `jq` on PATH (a rule read from its body, like the expected-red one);
  one anywhere else fails, so a real difference cannot hide under it.
- **Coverage pinned, per test:** every START has its DONE. A plain pass
  runs the file over a wrapper that only logs each gate start by test name
  and runs the new gate; for every test green over the comparing wrapper,
  its compared runs equal its plain-pass runs. A test that stops at a red
  assertion loses its later runs, so a red test is allowed only when a
  rule read from its body places it in the expected-red set (it reads,
  copies or greps the gate's file, counts `jq` starts, or sets the gate's
  shell options), and its lost runs are printed. "More than zero runs"
  alone would not see a test that died early.
- **Extra fixtures** for what the suite does not build: the shapes of R1,
  plus a name with an inner `\n\n`, built as trees, in both forms; one of
  them, LF1, is a plugin whose name `x\ny` sits in directory `x`, so its
  mismatch line prints the name.
- **The verdict:** a difference on a PLAIN run fails, on every system. On
  Windows LF1 must differ (the asserted divergence; if it is ever
  repaired, the differential goes red); on any other system no run may
  differ. SHIM runs are left out of both rules and counted on the
  verdict line.
- **Shown able to go red:** the same run with the new gate's report-line
  format changed by one byte (`state=%s` → `stat=%s`, one occurrence,
  counted) reports an UNEXPECTED difference with no crash.

## R11 — Measurement method

- `jq` processes: a wrapper named `jq` first on `PATH`, logging one line
  per start; one gate run on the real tree, both forms, old and new.
- Time: one gate run on the real tree, and `tests/portability.bats`
  alone, old and new, alternating, three runs each, on this machine.
  Recorded in one dated table at the end of this file when measured.

## R12 — Departures, named

1. The walk file has no link rule (R6; clarification).
2. The per-plugin marketplace answers come from the plugin's own `jq`
   process, not from the one marketplace read (R1, R3).
3. On Windows, values holding a line feed are read as on Linux (R5).
4. The comment at `:347-353` is replaced: the three diagnostics stay
   three; the three processes become one (R6). This departs from a
   recorded decision in the code, not from the seed.
5. No field separator: the seed asked for "a field separator no value can
   hold"; there is none a `jq` value cannot hold that also survives `$( )`,
   so each value is length-prefixed instead (R4).
6. The walk file's own open check has no mutant: a directory at its path
   is caught by `[ -f ]` first, and `chmod 000` does not stop a read on
   Windows. Accepted; the check stays because it costs nothing and names
   the fault on a system where a file can be unreadable. Since phase I,
   W2's `unreadable` case (`chmod 000`) runs it where the mode stops a
   read (CI's Linux and macOS runners, not root), and is skipped where it
   does not (Windows); the open check's mutant is therefore caught on CI
   only.
7. **The walk file is the old body plus one rule** (phase I; spec FR-005,
   FR-006). An empty walk file, or one of comments alone, runs an empty
   awk program: it exits 0 and prints nothing, which the gate read as a
   changelog accepted (contract lens I-1, security lens I1; also a link
   to any plain text). The fix adds `END { print "WALK-END" }` after the
   body. END rules run in the order written, and after a main rule's
   `exit` too, so the token is the last line in every shape (accepted,
   refused by a main rule, refused by the body's own END): one rule to
   check in the gate and one in `walk_on`. Placed after the body, not in
   the header: there, an unclosed fence's refusal (the body's END) would
   come after the token, a second output shape. What the token proves is
   that the walk ran to its end; it does not prove the body whole (a
   rule deleted from the middle keeps it). The body's identity is
   pinned by quickstart block 3, and by the tests that drive each rule.
8. **Two seed questions are answered in research, not in the spec.** The
   seed asked the spec to list the end-to-end tests that stay (FR-007)
   and to say whether the P0 scan reads the walk file (FR-009); the spec
   points to R8 for both, where the list is derived from the test file.
9. **A review fix was measured and not applied** (security lens I2). The
   lens found the first `nl` (one line feed cut per step) quadratic in
   trailing line feeds, and proposed `sub("\n+\\z"; "")`, measured on
   trailing ones only. Measured here (jq 1.8.1): 64,000 trailing line
   feeds, 14.3 s with the old `nl`, 0.13 s with the regex; but 64,000
   line feeds before a last `x`, 0.13 s with the old `nl` and 13.8 s with
   the regex (Oniguruma retries the run from every start), and 32,000 on
   each side of an `x`, 4.0 s. Applied instead: find the last character
   that is not a line feed and cut there: the gate's own text, 0.16 to
   0.55 s on all four shapes (trailing, inner, both, line feeds alone;
   measured while a test run shared the machine), and 0.21, 0.30 and
   0.77 s for 64,000, 128,000 and 256,000 trailing ones, and equal to the old `nl`
   on 15 edge values (empty, line feeds alone, CR, NUL, two- and
   four-byte characters). It uses jq 1.5 builtins only; CI's jq 1.7 and
   1.8.2 run it at phase L.
10. **Recorded, not changed** (security lens minors): M1, a jq too old to
   know `-b` exits with a usage error, which reads as "not valid JSON" (a
   version probe would be a fourth jq start); M3, a file swapped for a
   FIFO between the `-f` test and the read makes the read wait (whoever
   can do that controls the machine); M7, a value's trailing line feeds
   are read away, as the old gate read them, for byte-identity. M2 and
   M6 were comments that said more than the code does; corrected in the
   gate (`--slurpfile` reads the marketplace in text mode on Windows,
   safe only because the marketplace's own read comes first; measured
   with the native Windows jq 1.8.1: `{"plugins":[]}`, a 0x1a byte, then
   ` garbage` is refused on standard input with `-b`, exit 5, and read as
   `[{"plugins":[]}]`, exit 0, through `--slurpfile`; a NUL is
   refused in a string VALUE, not a key).
11. **Run from standard input** (`bash -s < gate`, security lens M5), the
   gate has no path to find its walk by. At `2b38f74` that form ran the
   inline walk; on the branch it first died on `BASH_SOURCE[0]: unbound
   variable`, and since phase I the release form stops at the walk check
   with the gate's own "could not be read" line, though a walk file sits
   in the working directory (W5). A departure from "byte-identical on
   every tree" for a way of running the gate no caller uses.
12. **Built otherwise than planned:** T023's `walk_refuses` and
   `walk_passes` (the existing `forms_refused` and `forms_passes` call
   `walk_on` instead; the walk's text is masked by its own `show()`, and
   `gate_safe`'s rules apply to the gate's line end to end); and
   FR-005's proof, `specs/025-gate-closes-phase25-gaps/proof/enumerate.py`,
   finds the walk by matching the old inline program in the gate, so it
   cannot run on this tree as it stands. Its condition, a changed body,
   did not arise; a rerun would first point its extraction at the walk
   file.

## Measurements after the build

One dated record per run; each describes that run, not the current file.

**2026-10-08, the harness proving itself on the old gate (T004).**
`bash specs/033-gate-fewer-processes/proof/differential.sh 2b38f74` with
the gate unchanged: `DIFFERENTIAL OK (259 runs, 15 LF runs, 0 differing)`,
`CONTROL OK (4 of 4 runs differ)`, 1,949 s. One test was red over the
wrapper and in the expected-red set: "the gate keeps its own shell
options" (4 plain runs, 4 compared). 259 runs: the suite's gate runs plus
24 extra trees in both forms.

**R11, at `2b38f74` (T005), on the real tree, this machine:**

| Measure | `2b38f74` | branch (`069a2b6`, T028) |
|---|---|---|
| `jq` starts, default form | 14 | 3 |
| `jq` starts, `--released handoff` | 14 | 3 |
| `jq` starts, `--released pipeline` (refuses: unreleased work) | 13 | 3 |
| one default run, ms (three runs) | 2,443 / 2,330 / 2,361 | 1,152 / 1,144 / 882 |
| `tests/portability.bats` alone, s (three runs each, old and new alternating) | 471 / 498 / 462 (`1..52`) | 315 / 317 / 306 (`1..57`) |
| gate runs in `tests/portability.bats` | 210 | 151 (new tests included) |

The file is about a third faster (mean 477 s to 313 s) while it holds five
more tests; one gate run takes about half as long.

**2026-10-09, phase H.7 (simplify).** Four read-only reviews (reuse,
simplification, efficiency, altitude). Applied in the gate: the entry
flag became a length-prefixed field like every other value; the record's
cuts became one `&&` list with one message; the reads lost their `$ok`
binding (`if <shape> then … else false end`); the walk's status is
checked with `|| die`; the reverse walk's CR strip went, since `-b` and
`@tsv` leave no raw CR for it to find (R2 had kept it as a guard); an
unused initial value and two comments about the change's history went.
Applied in the tests: one fragment check (`forms_says`) for both refusal
helpers; `walk_on` as one function; `gate_run_utf8` for the locale runs
(P7 and X1); Q1, W1 and W2 through `gate_run` and `gate_says`; fewer
processes in Q1, W2, W3 and P7; V1 no longer stops silently when `grep
-c` finds nothing. Skipped, with the reason: folding W3 into W2 (the
planned count, and a red would no longer say which); `undated_below`
through `forms_refused` (it would merge G1 into G2); finding the walk
file by stripping the gate's own name (breaks on a rename); the tests'
older literal `1000` and `200` (fixture data in tests this feature did not
write). After: `tests/portability.bats` `1..57`, 57 ok, 325 s; the
differential `DIFFERENTIAL OK (199 runs, 17 LF runs, 10 differing)`,
`CONTROL OK`; shellcheck clean.

**2026-10-09, phase I (deep review), the fixes.** Three lenses at
`275c700` (contract, security, tests; the tests lens's report is kept
outside the repository). Applied: the walk's end token and the gate's
check of it (R12 item 7); W2's cases `unreadable`, `empty` and
`comments`; a linear `nl` in place of both quadratic forms (R12 item 9);
the 18-digit bound in `take` (R4); `${BASH_SOURCE[0]-}` with an empty
walk path for a gate run from standard input (R12 item 11); the gate
comments the lenses found saying more than the code does, or describing
its history; five tests (R9) and two additions to the "cannot judge"
test (the walk alone with K3's line limit, and DENSE's cut, in bytes,
then masked); P7's `utf8-mv` fragment closed on the right; the SHIM mark
in the differential (R10). The empty-walk case of W2 was run first on
the gate as it stood: red (`the gate exited 0, not 1`), then green.

Mutants, each confirmed landed (its old text found once, the gate
parsed), in a scratch worktree, each against the one test that pins it;
all 7 tests green unmutated first:

| Mutant | Red, by clause |
|---|---|
| the gate accepts a walk output without the token | W2 `empty` |
| the walk's standard error kept | W4, through U2 (the path in awk's error) |
| the bare-name branch finds no walk | W5 |
| no empty branch for standard input | W5 `stdin` (the gate passed on a walk file in the working directory) |
| `${BASH_SOURCE[0]}` without `-` | W5 `stdin` (bash's own unbound-variable line) |
| a leading zero accepted | R4 |
| no 18-digit bound | R4, through U2 (bash's `[` error names the path) |
| the colon check removed | R4 |
| bytes left over accepted | R4 |
| an entry flag other than 0 or 1 accepted | R4 |
| the terminator not checked | R4 (survived the suite at T015) |
| `nl` cuts one line feed only | NL1 |
| the name not through `nl` | NL1 |
| the walk run without `LC_ALL=C` | LB1 |
| `walk_on`'s quote cut one short | K4, the DENSE addition |
| `walk_on`'s line limit one long | K3, the direct addition |

A walk file of `BEGIN { exit 0 }` (prints nothing) turned 34 of the
file's 62 tests red, the two Phase 5 recorded green among them
("judges no non-heading", "judges none of the shapes Phase 26
narrowed"): `walk_on` now fails a walk output without its token. The 28
green run no release-form walk.

After: quickstart blocks 1-5 as one script, all ok (SC-001, FR-005 with
the token rule, FR-007, FR-006 with the empty walk); `tests/portability.bats`
`1..62`, 62 ok, 338 s, slowest test 16.1 s; shellcheck 0.11.0 over CI's
file list clean. The differential, first run: FAIL, the six refused
records of the R4 test differing as PLAIN, since the old gate never asks
for a record (old exit 0, new exit 1); the SHIM mark was added for them.
Second run, 1,195 s: `DIFFERENTIAL OK (217 runs, 19 LF runs, 10 differing;
8 under a test's own jq, 6 of them differing, not judged)`, `CONTROL OK
(4 of 4 runs differ)`; expected red over the wrapper, by the rule: W2,
W4, W5, the shell-options test and Q1.

**2026-10-09, phase J.** shellcheck 0.11.0 over CI's file list: clean.
The house suite from the root: `suite ok: 1..436, 436 ok, 0 skipped, 0
not ok, 0 non-TAP` (`bash scripts/check-suite.sh 436`), 2,098 s. Test 156
(`pipeline/tests/pending.bats`, "every edge of every refused range…"),
which timed out once at T030, passed: nothing new against the F.5
baseline (`1..426`, all ok).

**2026-10-08/09, the quickstart as one script (T029, T030).** Blocks 1-6
ok: SC-001 (14 jq starts at `2b38f74`, 3 now), FR-005, FR-007, FR-006,
FR-003 (`DIFFERENTIAL OK (199 runs, 17 LF runs, 10 differing)`, `CONTROL
OK`; expected red over the wrapper, by the rule: the shell-options test,
Q1 and W2). Block 7, the house suite: `1..431`, 430 ok, 1 not ok — test
156, "every edge of every refused range is refused, and the characters
beside them are not" (`pipeline/tests/pending.bats`), `timeout after 60s`.
This branch changes nothing under `pipeline/`; the test passed alone in
43.4 s, and passed in the F.5 baseline. It is the near-limit test the
session handoff already lists as a follow-up. The owner's answer
(2026-10-09): record it, and let phase J's full suite, the same command,
give the verdict. shellcheck 0.11.0 over CI's file list: clean.

**2026-10-08, Phase 3 mutants (T015),** each in a scratch worktree,
each confirmed landed (the old text found once before, not after, and the
file parsed), each run against `every value masked`, `one jq for the
marketplace`, `manifest, marketplace entry and changelog agree` and
`TRAILING malformed`:

| Mutant | Result |
|---|---|
| `take` cuts one byte short | 4 of 4 red |
| `LC_ALL=C` dropped from `take` | 1 red: `every value masked` (P7's UTF-8 plant) |
| the entry flag ignored | 0 red at first: no test pinned the three marketplace messages, before or after the merge. P8 added (no entry, no version, no source); then 1 red, `every value masked` |
| `mv` and `ms` swapped | 4 of 4 red |
| `-b` dropped from the plugin read | 1 red: `every value masked` (a value holding a line feed is cut wrong on Windows) |
| the `.` terminator dropped (in `jq`, the check and the strip) | SURVIVES, by measurement: the `crsource` check passes on the mutant too. Nothing reachable reaches the end of the record but a value `nl` has already stripped of trailing line feeds, and `$( )` keeps a lone trailing CR. A guard kept on purpose; R4 says so |

**2026-10-08, the differential after Phase 3 (T013).** First run: one
UNEXPECTED difference class, the `dup` tree (entries sharing a name), the
Windows divergence the classifier did not yet cover; R5 and the
classifier were widened to it, then narrowed again by measurement (a
trailing CR does not diverge). Final run, with the classifier as
committed: `DIFFERENTIAL OK (271 runs, 17 LF runs, 10 differing)`,
`CONTROL OK (4 of 4 runs differ)`, 1,313 s; the `crsource` check passed.
Expected red over the wrapper, by the rule: "the gate keeps its own shell
options" and "the gate starts one jq for the marketplace and one per
plugin" (its logger also counts the old gate's starts).

**2026-10-08, Phase 4 (T016-T022).** The walk body in
`scripts/check-versions-walk.awk` compared with `2b38f74`'s lines 545-728:
identical (`cmp`); its header is comments only. W1 passed on the gate
before the move (it pins today's line); W2 and W3 were red before the walk
file existed. Quickstart blocks 1-5 as one script: all ok. Mutants, each
confirmed landed, in a scratch worktree:

| Mutant | Result |
|---|---|
| walk found from the working directory | 4 of 4 red |
| `-f` test removed | 1 red (W2: a directory at the walk's path opened without error on Git Bash, so `-f` is what refuses it) |
| open check removed | SURVIVES: on the testable cases `-f` refuses first, and `chmod 000` does not stop a read on Windows (R12 item 6) |
| both checks removed | 1 red (W2) |
| status check removed | 1 red (W2, the failing walk) |
| one byte of the walk's text changed | 1 red (W1) |

`tests/portability.bats` alone after Phase 4: `1..57`, 57 ok, 398 s.

**2026-10-08, Phase 5 (T023-T027).** The conversion went through the
helpers, not test by test: `forms_refused`, `forms_passes` (and so
`forms_unclear`) and `undated_below`'s release-form run now run the walk
directly (`walk_on`); `forms_refused_gate` keeps the old end-to-end form,
used where the gate makes the refusal or gives the whole line (K3's
1,001-byte line with its cut and 400-byte checks, K5's NUL). Kept end to
end as before: every `forms_base` and `undated_base` run (the dated base
that must pass the whole gate), every default-form run (G5, H8), the
exact-limit K3 pass, K4 under UTF-8, the STX plant's test, and every test
the inventory marked KEEP. One assertion changed form: "refused exactly
once" counted `is NOT released` lines in the gate's output, and now
requires the walk's output to be one line.

The converted tests still depend on the walk, in a scratch worktree:

| Walk file | Converted tests red |
|---|---|
| prints nothing (`BEGIN { exit 0 }`) | 13 of 15; green: "judges no non-heading" and "judges none of the shapes Phase 26 narrowed", which assert only that the walk accepts |
| refuses every input | 15 of 15 |

Gate runs of `tests/portability.bats` (a logging line in a worktree copy,
as at T005): 210 at `2b38f74`, 151 now, the new tests' runs included.
`tests/portability.bats` alone: `1..57`, 57 ok, 311 s; slowest test 18.2 s.

`tests/portability.bats` alone after Phase 3: `1..54`, 54 ok, 345 s
(535 s at `2b38f74` earlier the same day, not alternated: T028 measures
properly).
