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
feed or CR is inside a line; `-b` writes no CR (the old `${es%$'\r'}` stays,
harmless).

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
  a guard should `nl` ever change, and its mutant survives (recorded with
  the mutants below).
- Only five fields per plugin, so the cutting is constant work (R3's cost
  is per record).
- A field whose length is not digits, or a length past the end, or bytes
  left over, is a hard failure with the gate's own line ("could not be
  read"), never a silent wrong value.

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
  then the old program's text from `:545` to `:728` byte for byte (R7).
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
  `LC_ALL=C` set from the test file's own copies. Its base run (a whole
  normalised fixture through the gate) becomes one walk run on the
  normalised changelog.
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
- The two "at most 400 bytes" checks (`:2368`, `:2431`) measure the gate's
  whole line, so they stay in the end-to-end K3 run.
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
  afterwards, so this cannot wait.
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
  differ.
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
   the fault on a system where a file can be unreadable.

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
