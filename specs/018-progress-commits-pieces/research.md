# Research: progress.sh learns commits and pieces

Every decision below rests on a measurement taken 2026-09-29 on this machine
(Git Bash: GNU bash 5.3.9, cygwin build; jq 1.8.1 as a native Windows PE32
executable behind a Scoop shim; GNU awk 5.4.0) at `main` = `7ceabd9`, unless
stated otherwise. CI runs the same suite on ubuntu-latest, macos-latest and
windows-latest (`.github/workflows/ci.yml:67`), each installing its own jq.

## R1 — jq output keeps a carriage return on every line but the last

**Measured:** `jq -rn '"x","y"'` writes `x \r \n y \r \n`. Captured through
command substitution, it becomes `x \r \n y`: `$()` removes the trailing
line ending only, and the CR on every earlier line SURVIVES.

**Decision:** `piece-next` never prints jq's multi-line output directly. Its
jq program emits ONE line; the script captures it with `$()` (which removes
that line's CRLF) and prints the two output lines itself with `printf`.

**Rationale:** a piece name printed with a hidden CR would be passed back to
`commit-add` with the CR, stored, and then never compare equal to the heading
again. `piece-next` would offer the same piece for ever. This is the failure
the repository's memory records as "`read` is not command substitution", and
it would be silent: the heading LOOKS right on a terminal.

**Alternatives considered:** piping jq output through `tr -d '\r'` — rejected,
it strips a CR that could legitimately be inside a value and hides the
mechanism; two separate jq calls each yielding one line — works, but costs a
spawn for nothing once R3's separator exists.

## R2 — `--arg` carries a non-ASCII heading byte for byte

**Measured:** the heading at `specs/017-guard-config-bounds/tasks.md:61`
(em dash and an emoji) passed through `jq -rn --arg h "$h" '$h'` and captured
with `$()` compares byte-identical (hex dump, `cmp`) to the original.

**Decision:** pass the piece name and every other value to jq with `--arg`.
No shell-side encoding step.

## R3 — one-line output split in bash with a unit separator

**Measured:** `r="$(jq -rn '"a b" + "\u001f" + "T1,T2"')"` then
`${r%%$'\x1f'*}` and `${r#*$'\x1f'}` yield `a b` and `T1,T2` exactly.

**Decision:** `piece-next`'s jq program emits one line of the shape
`<status>US<heading>US<task ids>`, where US is U+001F. U+001F is vanishingly
unlikely in a heading a person typed; a tab is not. Unlikely is not
impossible, so a chosen heading holding U+001F — or a carriage return left
after the one trailing CR is stripped — is reported with the status `bad`
and refused by name rather than split wrongly (spec FR-010e).

**Alternatives considered:** emitting JSON and parsing it with more jq calls
— rejected as more spawns for the same result; a tab separator — rejected,
because a tab inside a heading would split it silently.

## R4 — the file list travels as positional arguments

**Measured:** `jq -c '... files: $ARGS.positional' state.json --args a "b c" 'ü—🎯'`
produced `["a","b c","ü—🎯"]` with the non-ASCII bytes intact; with no
positional arguments, `$ARGS.positional` is `[]`. The input file must come
BEFORE `--args`.

**Corrected at analyze (review F22):** it is NOT true that everything after
`--args` is positional. `jq -cn '$ARGS.positional' --args a -r` gives `["a"]`
— the `-r` is taken as an option. `--args -- -r "a b"` gives `["-r","a b"]`
(measured on 1.8.1; CI installs 1.7 or later on every OS, and the suite's
`-`-leading path test will measure each of them).

**Also measured at analyze (review F21):** Git Bash rewrites an argument that
looks like an absolute POSIX path before a native Windows program sees it —
`/tmp/x` arrives as `C:/Users/…/Temp/x`. Relative paths and headings with
spaces are untouched. A round-trip checked with `jq --arg` equality is blind
to this, because both sides are rewritten alike; the test compares a hex dump
against a literal byte string instead.

**Decision:** `commit-add` passes the remaining arguments with
`--args -- "$@"` after the state file. `tasks` is split in jq: `if $t == "" then [] else
split(",") end` — measured to give `[]` and `["T001","T002"]`.

**Version:** `$ARGS` and `--args` exist from jq 1.6. CI installs a current jq on
every OS (1.7 or later); this machine has 1.8.1.

## R5 — the tasks file is read by jq, not by a shell loop

**Measured:** `jq -rn --rawfile t crlf.txt '$t|split("\n")|map(rtrimstr("\r"))'`
reads a CRLF file into clean lines.

**Corrected at analyze (review F3):** that measurement did not measure the
`rtrimstr`. The native Windows jq strips the CR itself when it reads a file:
`printf 'a\r\nb\r\n'` read with `--rawfile` holds ZERO carriage returns
(`explode | map(select(. == 13)) | length` is `0`). So on this machine the
CRLF test passes with the `rtrimstr` deleted, and no Windows test can show
it load-bearing. It is kept because Linux and macOS jq do not strip, and the
CRLF test runs on both in CI.

**Round 2 of analyze measured a way to show it on Windows after all:** the
native jq turns `x\r\r\n` into `x\r` — it removes one CR and keeps the
other. So a CR-CR-LF heading comes out clean with the `rtrimstr` and keeps a
CR without it. The mutation check uses that input in its scratch run. It is
NOT committed as a suite test, because on Linux the same input leaves one CR
with the correct code too, and the test would be wrong there.

**Decision:** `piece-next` reads the tasks file with `--rawfile` and does the
whole walk in one jq program: split lines, strip ONE trailing CR from each,
detect piece headings and task lines, drop task-less headings, remove
recorded pieces, pick the first, and report it as `bad` if its heading
still holds a CR or U+001F. The state file is jq's input, so the
recorded pieces and the tasks text meet in one process.

**Rationale:** the script's own header forbids `while read` over jq output
(`pipeline/scripts/progress.sh:13-16`), and a shell loop over a file is the
same hazard one step removed. awk is available (`preflight.sh:119` uses it)
but would need the recorded pieces handed across a process boundary —
`awk -v` rewrites backslash escapes in the value, which would corrupt a
heading containing one.

**Alternatives considered:** awk with the recorded pieces in `ENVIRON` —
workable, but two languages for one walk and a second encoding boundary.

## R6 — how a heading is recognised

**Decision:** a line is a piece heading when `startswith("## Phase ")` and
`test("^## Phase [0-9]+[a-z]*:")`. A line that `startswith("## ")` but is not a
piece heading ends the current piece. `### ` lines never start or end a piece,
because `"### x" | startswith("## ")` is false. A task line is one matching
`^- \[[ xX]\] T[0-9]+`; its id is captured from that match.

**Rationale:** the seed's "fixed strings, not one clever regex" is about
IDENTITY: which recorded piece is which heading. That comparison is `==` on
whole strings in jq, never a pattern. Recognising the heading SHAPE needs the
digits-then-optional-letters rule the spec sets (FR-008), and a two-part check
states it more plainly than one pattern would.

**Measured against a real file:** `specs/017-guard-config-bounds/tasks.md` has
seven `## Phase <N>:` headings with 2, 0, 10, 3, 4, 7 and 2 task lines; its
Phase 3's ten tasks all sit under five `### ` subheadings. Expected yield: six
pieces, with `Phase 2: Foundational` skipped.

## R7 — the duplicate-id rule and old-style entries

**Measured:** the 17 real state files hold 32 bare-string entries: 14 are a
7-character id, 9 a full 40-character id, 1 a 9-character id, and 8 an id
followed by a space and the commit subject.

**Decision:** one jq call classifies the incoming id against the list and
prints exactly one word — `new`, `same`, `conflict` or `legacy`:

- an OBJECT entry with the same `sha`: `same` when `kind`, `piece`, `tasks` and
  `files` are all equal, else `conflict`;
- a STRING entry: take its first space-separated word; if that word is 7 to 40
  lowercase hex characters and the new id starts with it, `legacy`;
- otherwise `new`.

`same` exits 0 without writing (FR-004a). `conflict` and `legacy` refuse with
different messages (FR-004d). `new` appends and writes through a temporary
file and `mv` (FR-005). The script branches with `case`, and its default arm
dies naming the unexpected output — an `if`/`elif` chain would let an empty
or garbled answer fall through to the write (review F12).

## R8 — refusal tests must not pass on the unchanged script

**Measured by reading the dispatcher** (`progress.sh:170-181`): an unknown
command reaches `usage`, which exits 1. A refusal test that asserted only a
non-zero exit would therefore pass against the script BEFORE this feature,
proving nothing.

**Decision:** every refusal test asserts the specific diagnostic text naming
the problem, and asserts the state file byte-identical with `cmp` against a
copy taken before the call. Run against the unchanged script, each must go
red — that is the red-first proof SC-001 requires.

## R9 — edges, not centres

Each numeric or set boundary gets a test on both sides: a 39-, 40- and
41-character id; an uppercase 40-character id; a legacy first word of 6 and 7
characters; a heading with and without a letter suffix; a heading with zero
and one task. The repository's record ("a guard's reach must be measured")
is that each review round found the previous guard reaching less far than
its comment claimed, and every miss sat at an edge.
