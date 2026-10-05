# Research: The release gate reads only what it can judge, and prints only what is safe

Every fact here was measured on 2026-10-04 at `main` = `4016666` (whose
`scripts/check-versions.sh` equals `6fd91f3`'s), in Git Bash (bash 5.3.9,
gawk 5.4, grep 3.0, jq 1.8.1), unless it says otherwise.

## R1 — A changelog that is a link, or not a regular file, is refused before any read

- **Decision**: in the per-plugin loop, before the NUL check (the first
  read today), in both forms:
  1. `[ -L "./$p/CHANGELOG.md" ]` refuses: the changelog is a symbolic
     link, which the gate does not follow. A broken link is a link, so it
     is refused here, not reported as missing.
  2. `[ -e … ] && [ ! -f … ]` refuses: the changelog exists and is not a
     regular file (a directory, a device, a pipe).
  3. A missing changelog falls through to today's diagnostic (FR-002).
  The message names the plugin, masked (R3), and says "this tree is NOT
  released" only for the plugin `--released` names, as the NUL message
  does.
- **As built** (H, then I): the `-L` refusal comes first; then
  `if [ -f … ]` holds the open check (R11), the size (R2) and the NUL
  check, and `elif [ -e … ]` refuses what is not a regular file. Step 2
  is that `elif`, not a second test.
- **Rationale**: `[ -f ]` follows a link, so today a link to a device
  skips the NUL check and `grep` reads the device: a link to
  `/dev/urandom` ran the default form until it was killed at 20 s.
  Refusing every link is simpler than judging where it points, and a
  wrong refusal is acceptable.
- **Alternatives**: follow a link only inside the repository (more code,
  and a link can change after the check); refuse only links to
  non-regular files (a link to a regular file outside the tree would
  still be read and its first `## ` line printed).

## R2 — The size limit: 262,144 bytes, the release form only, read without reading the file

- **Decision**: one value, `changelog_limit=262144`, set beside
  `line_limit`. For the plugin `--released` names only, after R1 and
  before the NUL check, the size is read with `LC_ALL=C wc -c < file` and
  compared with arithmetic (BSD `wc` pads with spaces). Over the limit:
  refused, naming the plugin, the size and the limit. The default form
  never refuses for size (the owner's answer at C).
- **Where**: inside the existing `if [ -f "./$p/CHANGELOG.md" ]` block,
  before the NUL count. Outside it, a missing changelog would make the
  redirection fail under errexit with bash's own "No such file" line
  (measured by the analyst at F), not the gate's diagnostic (FR-002).
  The size is printed as `$((size))`, so BSD `wc`'s padding never
  reaches the message.
- **Rationale**: in Git Bash, `wc -c <` on a regular file read 1 GiB in
  139 ms, the same as an empty file, so it reads no content there. On
  Linux and macOS this is not measured. It does not need to be: R1 has
  already refused a link and any non-regular file, so `wc` never meets a
  device, and the files the tests size are near 256 KB, so even a `wc`
  that read the whole file stays fast. The NUL check reads the whole
  file, so it must come after the size check for the released plugin.
- **Alternatives**: `stat` (its options differ between GNU and BSD);
  refusing in the default form too (the owner chose not to).
- **Found at H (T008)**: the limit reshaped two Phase 26 plants in
  "--released refuses a byte or a line it cannot judge". Its 800,001-byte
  quote-marker line and its 400,000-byte dense line were now refused for
  the file's size before the walk could refuse them for their length, so
  the test went red. The quote-marker line now fills the room left under
  the limit, less 8,192 bytes, measured on the copy at test time. The
  dense line guarded the walk's `show()` cutting before it masks, through
  the per-test timeout alone: sized to the room, a `show()` that masks
  first passed that test in 48.6 s here (19.7 s unchanged), so the
  timeout no longer caught it (measured). The size limit now bounds that
  cost instead: no line the release form walks can be longer than the
  limit. So at H.7 the dense line became 2,000 bytes, enough to check the
  refusal, the cut and the mask, and no longer walked at full size on
  every run. No wall-clock assertion was added: one would fail under CI
  load. The tests hold their own copy of the limit, `changelog_limit`.

## R3 — One masking function, setting a variable, no process

- **Decision**: `quoted()` becomes `shown <name> <value>`: it cuts the
  value at the quote cut with the cut marker, masks every byte outside
  printable ASCII as `?` under the C locale, and stores the result in the
  variable `<name>` with `printf -v`. Each value of the print-site table
  is passed through it once, where it is read, into a `_s` copy (`p_s`,
  `pn_s`, `pv_s`, `mv_s`, `cv_s`, `ms_s`, `head_s`, `first_s`, `en_s`,
  `es_s`, `rel_s`, `arg_s`); every message and the report line print the
  copy, and every comparison keeps the raw value. Every `_s` name is
  declared once, empty, beside `shown`: ShellCheck cannot see an
  assignment made through `printf -v "$1"` and reports each copy as
  SC2154, exit 1, which turns CI's shellcheck job red (measured at F,
  iteration 3). No `disable` directive. Each is written `name=''`: a
  bare `name=` followed by another word is reported as SC1007 (measured
  at F, iteration 4).
- **The store**: `printf -v "$1" '%s' "${s//[![:print:]]/?}$t"`. The
  value is never the format: a forged value may hold `%` or `\`, both
  printable, so the mask keeps them.
- **Rationale**: one function is the "one masking point" the seed asks
  for, so a new message cannot quote a value another way. `quoted()` is
  called through `$( )` today, a subshell per call; the report line runs
  on every plugin on every run, about a hundred runs per suite, and a
  process costs 0.1 s or more on Windows (measured in Phase 26).
  `printf -v` is in bash since 3.1, so bash 3.2 has it (measured here:
  it sets a variable holding an escape byte).
- **The report line's first field**: after masking, the leading spaces
  of `p_s`, and a `:` that directly follows them (or starts the field), become `?` on that line only
  (FR-006), so the line cannot start with `::`, with or without spaces
  before it. The actions runner trims leading white space before it
  tests for `::` (read from its source, `TryParseV2`; not measured), so
  a directory named ` ::error::x` must not print ` ::error::x: plugin=…`.
  Every other line starts with `check-versions.sh:`.
- **The CR/LF strip on the report line goes**: masking shows a line feed
  as `?` instead of dropping it. On the real tree no value holds either,
  so the output is unchanged (FR-008).
- **The walk's own `show()` stays**: it quotes the walk's lines in awk,
  and the walk is not touched (R7).

## R4 — Directory names: the `::` case can be planted on all three systems

- **Measured**: Git Bash made a directory named `::error x` and one
  holding an escape byte, and `for d in */` read both back exactly as
  written (MSYS maps the characters NTFS forbids). Linux and macOS take
  any byte but `/` and NUL in a name.
- **Correction (analyst, F)**: that measured only the bash loop. Native
  Windows `jq` (Scoop, 1.8.1) cannot open `./::<ESC>x/.claude-plugin/plugin.json`,
  nor a path under `::error x` or `ab<ESC>c`: it exits 2 with "Invalid
  argument" and prints the path, escape byte included, in its own error.
  Read through standard input instead
  (`jq -r '.name // empty' < "./$p/.claude-plugin/plugin.json"`), the
  redirection is opened by bash, which can open the path, and `jq`'s
  errors say `<stdin>` (measured). R11 holds the rule.
- **Decision**: the print-safety test plants a plugin directory whose
  name starts with `::` and holds an escape byte, on every system, and a
  second whose name starts with a space and then `::` (R3).

## R5 — The link test on three systems

- **Measured**: in Git Bash a plain `ln -s` makes a COPY and reports
  success; only `MSYS=winsymlinks:nativestrict ln -s` made a real link
  here (this machine allows it). The windows-latest runner's git checks
  links out as plain files (`core.symlinks` off; recorded in
  `.github/workflows/ci.yml`'s bats exclusion), and whether the runner
  can make a link at run time is not known.
- **Decision**: the test makes each link with
  `MSYS=winsymlinks:nativestrict ln -s … 2>/dev/null || true` and checks
  `[ -L ]` before believing it. The `|| true` matters: `nativestrict`
  makes `ln` exit non-zero where it cannot make a link, and a bats test
  body runs under errexit, so a bare `ln` would end the test before the
  fallback below could run. Where the link exists, it asserts the link refusal and
  prints `# links: made`. Where no link was made, the fallback applies
  only when `uname -s` matches `MINGW*`, `MSYS*` or `CYGWIN*`: it asserts
  that what a checkout makes there instead, a regular file holding the
  link's target path, is refused ("no changelog heading"), and prints
  `# links: not available here`. On any other system a link not made is
  a `fixture:` failure, so a failed `ln` on Linux or macOS can never
  turn the link rule's test into the heading rule's (FR-011's named
  departure). It never skips.
- **The log line**: bats hides a passing test's standard output, so the
  line goes to file descriptor 3 (`echo "# links: made" >&3`); the `# `
  prefix keeps it a TAP comment, which `scripts/check-suite.sh` does not
  count as stray output. Exactly one such line per run. The first CI run
  measures the runner; at L and N the `# links:` line of each system is
  read from the CI log and the PR body reports it.
- **Targets**: a regular file (a copy of the live changelog: today it
  passes, so a mutant without the rule goes red) and a missing file (a
  broken link). Never a device: with the rule removed, a link to
  `/dev/urandom` would hang the test until the 60 s timeout instead of
  naming the clause.

## R6 — What a test may treat as printable

- **Decision**: a print-safety check passes an output when, with every
  em dash (the bytes `\342\200\224`, the gate's own text) removed, no
  byte is outside space to `~` and no line matches `^[ ]*::`. One awk
  program does both, run as `LC_ALL=C awk -v BINMODE=3 …` (as
  `scripts/check-suite.sh` runs its awk); no `tr` range is needed.
- **Rationale**: FR-007 keeps the gate's own em dash; SC-002 counts
  every other byte. `BINMODE=3` because Windows gawk in text mode drops
  a CR before an LF, and native Windows `jq` writes an embedded line
  feed as CR LF: without it the check would never see that CR.
- **Changed at H.7**: the check is `gate_safe` in
  `tests/portability.bats`, bash `[[ =~ ]]` under `local LC_ALL=C`, with
  no process: a CR is caught as any other byte, so no awk and no
  `BINMODE` are needed. The rule it applies is unchanged. Phase I added a
  control at the top of the P test: an escape, a `::` line after spaces
  and a lone CR must each make it return exactly 1, and the em dash must
  pass.

## R7 — The walk does not change, so the proof stands

- **Decision**: nothing inside the walk's awk program changes. The
  quickstart checks that the walk's sha256, as the proof script extracts
  it, is still `24c123b1b203af88fdcd745f3c4cba58ba6289e1612cf13f7bf1708d46314896`,
  the walk the Phase 26 proof judged (8,120,580 cases, 0 wrong passes).
  If the walk changes, FR-008 requires the proof again.

## R8 — Tests and their count

- **Decision**: two tests, after the Phase 26 tests: one for each user
  story, each with its own fixture (FR-013). The suite reads `1..251`.
  - **Regular-file test**: a link to a regular file and a broken link
    (both forms), a directory (both forms), a changelog one byte over
    the limit (the release form refuses; the default form passes) and
    one exactly at the limit (the release form passes), and a missing
    changelog (the gate's own diagnostic, both forms). About 12 gate
    runs.
  - **Print-safety test**: forged values in `plugin.json` (version,
    name), in `marketplace.json` (version, source, and an appended
    entry's name and source), plugin directories named `::…` and ` ::…`
    with an escape byte, an escape byte in the `--released` argument and
    in an unknown argument, a first heading holding an escape sequence
    above the release (`--released`), and a value over the quote cut in
    a UTF-8 locale. Each run is checked by R6's rule, and for the masked
    text. About 15 gate runs counting the fixture's own, two of which
    exit at argument parsing (0.06 s); the others take 1.1 to 1.6 s
    here (measured at F).
- **Rationale**: the print-safety test's 13 full runs at 1.1 to 1.6 s
  take about 20 s; under load (up to 4 s a run) they could near the 60 s
  timeout. So each test's wall time is recorded when it first goes
  green, and one over 30 s has its runs reduced: a split would change
  the suite count FR-013 fixes.

## R9 — Portability

- `printf -v`, `${s:0:n}`, `[ -L ]` and `wc -c` work on bash 3.2 and
  BSD; `wc`'s padding is removed by arithmetic. Every `tr`, `grep`,
  `wc` and `awk` that may meet a byte which is not valid text runs under
  `LC_ALL=C` (FR-009): macOS `tr` under a UTF-8 locale stops at such a
  byte (Phase 26, research R14).

## R10 — Found and left out

- `plugin.json` and `marketplace.json` are read with `jq`, but a link
  from either to a device never reaches `jq`: the gate's `[ -f ]` tests
  follow the link and fail on a device, and the gate stops on its own
  message (measured at F, iteration 3, at `4016666`: a `plugin.json`
  link gave `marketplace entry 'handoff': source './handoff' names no
  plugin directory`, exit 1, 0.5 s; a `marketplace.json` link gave
  `run me from the repository root — …`, exit 1, 0.26 s). A link from
  either to a regular file is still read. That is older than this
  phase, outside the seed (which names the changelog), and fails
  closed; it is recorded here for a later phase.
- **Found at I, left out** (deep review, three reviewers):
  - A `jq` type error on a malformed `marketplace.json` quotes up to 11
    escaped characters of the offending value in `jq`'s own message.
    `jq` escapes a control byte there, so no `::` line can start; a C1
    byte or a bidirectional mark can still reach a UTF-8 log raw. Older
    than this phase, and outside the print-site table.
  - Each marketplace entry costs about 27 ms (a `$(norm_source)` per
    entry, a process here). Recorded beside the deferred job time limit
    (spec Assumptions): a fork can make the walk slow, not wrong.
  - Nothing guarded the order inside `shown` (cut, then mask). Left out
    at I on the claim that the size limit bounds what a mask-first order
    would cost. **Wrong, found at M (round 1)**: the limit bounds the
    changelog only, and a `plugin.json` value has no size limit.
    Masking a value whole took 0.5 s at 50 KB and 6.1 s at 200 KB here
    (it grows with the square of the length); the gate as built takes
    1.3 s on a version of 1,000,000 escape bytes. **Closed at M**: P6
    plants that version and runs the gate under `timeout 20`; the
    mask-first mutant goes red.
- **Found at I, closed beyond the seed**: the walk read its entries from
  a herestring, and Git Bash hung, naming nothing, on a herestring of
  65,536 to about 65,700 bytes; a fork reaches that size through one
  entry's name. The loop is now fed by `printf` over the assigned text.
  The test plants a 65,600-byte walk input and runs the gate under
  `timeout 30`; its mutant (the herestring back) goes red on Windows
  only, where the hang lives.

## R11 — Other programs' own errors

- **Found at F**: a program the gate runs prints the path it was given
  in its own error, raw. A missing changelog printed
  `grep: ./handoff/CHANGELOG.md: No such file or directory` (from `:238`
  at `4016666`; `:262` is never reached, because the gate dies at `:239`)
  before the gate's own line, and `jq` names
  the `plugin.json` path it could not open (`:146`, `:147`).
- **Decision**: `plugin.json` is read through standard input (R4). The
  `head` grep (`:238`), whose failure the gate reports itself on the
  next line, gets `2>/dev/null`: the gate's own `die` follows, so
  nothing is lost. A missing changelog then prints only the gate's own
  diagnostic (FR-002, FR-014). The `first` grep (`:262`) is not changed:
  on a changelog it cannot read, the gate has already died at `:239`
  (measured at F, iteration 2), so no test could show a change there
  matters.
- **Rationale**: masking cannot reach another program's error text, so
  the only safe way is not to hand that program a value it would print.
- **Found at I**: reading through standard input moves the leak to the
  shell. When bash cannot open a redirect's file, it prints the path
  raw, before the gate says anything.
- **Decision (I)**: before the two `jq` reads of `plugin.json`, and
  before the changelog's size and NUL reads, the gate opens the file
  once with the shell's error discarded:
  `{ : < f; } 2>/dev/null || die "<plugin>: … could not be read"`. That
  is safe only because `-f` (and, for the changelog, `-L`) has already
  refused a pipe, whose open would wait for ever. The test (L5) needs a
  file a mode of 000 makes unreadable: Linux and macOS, not as root. On
  Windows the sub-check cannot run and prints `# unreadable: not
  available here`, so its mutant goes red only on the Linux and macOS
  runners.
- **Found at M (round 1)**: with `POSIXLY_CORRECT` in the caller's
  environment, bash runs in POSIX mode. There a failed redirect on `:`,
  a special builtin, ends the script before `|| die` runs, so the open
  check above printed nothing. Measured wider: GNU grep then reads the
  `--` after a pattern as a file name, so the default form printed
  `grep: --: No such file or directory` and a raw path in the report
  line's `state=`. **Decision (M)**: the gate unsets `POSIXLY_CORRECT`
  beside `GREP_OPTIONS`, which turns POSIX mode off and keeps the
  variable from every program it runs, and runs `set +o posix`. L6
  compares both forms with and without it; L5 runs its unreadable
  `plugin.json` once more in POSIX mode (Linux and macOS).
