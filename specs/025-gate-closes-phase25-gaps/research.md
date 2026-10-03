# Research: The release gate closes the gaps Phase 25 left

Every decision below leans to refusing. Phase 25 showed that a rule made
cleverer leaks a wrong pass, and a rule made stricter does not
(`specs/024-gate-every-heading-form/research.md`, R2 and R3). A narrowing
(R6 to R9) is the one place this phase makes a rule pass MORE, and each is
allowed only behind the proof of R10.

## R1 — A CR is refused, not split

- **Decision**: at the top of the walk, before the fence rules, any line
  whose raw text holds a CR byte is refused: `line <n> holds a carriage
  return, which Markdown reads as a line end: '<text>'`, the CR shown as
  `?` by the masking every quote uses.
- **Rationale**: the owner's answer at clarify. Splitting would add a
  second way to read a line inside a walk that already reads lines one
  way. A CR inside a fence is refused too: Markdown would split the line,
  and a split line can close the fence.
- **Portability**: `index($0, "\r")` is plain in every awk. Windows gawk
  strips a CR before an LF in text mode, so tests plant a LONE CR, which
  every awk keeps. `.gitattributes` forces LF, so a CRLF cannot reach a
  commit; on a working copy where one could exist, the gate refuses it,
  which fails closed.
- **Alternatives considered**: split at CR (rejected at clarify); refuse
  only a CR followed by text that looks like a heading (a cleverer rule:
  rejected, for the reason above).

## R2 — The first-heading text is masked in both forms

- **Decision**: the default form's `UNRELEASED-ABOVE:` field and the
  release form's first-heading refusal replace every non-printable
  character with `?`, with a bash pattern substitution on `$first` (a
  bracket class `[![:print:]]`), and the refusal also cuts `$first` to the
  quoted length of R4 with the same marker.
- **Rationale**: the walk's `show()` already masks every line it quotes;
  these two are the only quotes outside it. Both real first headings are
  plain ASCII (measured 2026-10-03: 0 bytes outside `\040-\176`), so the
  default output on the real tree does not change (FR-007).
- **Portability**: pattern substitution with a bracket class runs on bash
  3.2. Under a C locale a non-ASCII byte is shown as `?` too; that is a
  wider mask, never a narrower one.

## R3 — A line longer than 1,000 bytes is refused before it is read

- **Decision**: the first rule of the walk, before R1: a line whose
  `length()` exceeds the limit is refused, `line <n> is <len> bytes
  long, longer than the release form judges: '<cut text>'`, with `<len>`
  in bytes and the message saying `bytes`. The limit is
  a named value set once in the script and read by awk from the
  environment (R4), so no count appears in prose.
- **Rationale**: the owner's answer at clarify. The nested-quote cost
  grows much faster than the line (400,000 markers: 123 s); at 1,000
  characters it is too small to measure. The longest real line is 107.
- **Measured shape**: awk reads an 800 KB line and measures it at once;
  the refusal then exits before any marker loop runs.

## R4 — Every quoted text is cut to 200 characters, and masked byte by byte

- **Decision**: `show()` masks, then cuts: a text longer than the cut
  length is shown as its first 200 characters followed by ` [cut]`. Every
  quote in the walk already goes through `show()`; the first-heading
  refusal (R2) cuts the same way in bash, and the bash masking and cut of
  `$first` run under `LC_ALL=C` too, so both cuts count bytes and mask
  every byte outside printable ASCII. The cut and the line limit are
  set ONCE, as shell variables near the dated pattern, and reach awk
  through the environment as the pattern does, so the bash and awk cuts
  cannot drift.
- **The walk's awk runs with `LC_ALL=C`.** Analysis measured that under a
  UTF-8 locale `gsub(/[^[:print:]]/, "?")` leaves an invalid byte raw: a
  lone `\x9b` (a bare CSI to a terminal) reached the output unmasked.
  Under C every byte outside the printable ASCII range is masked, and
  `length()` counts bytes, so the line limit is a byte limit. Neither
  real changelog line is long enough for the difference to matter, and
  a wider mask only refuses or hides more, never less.
- **Rationale**: one place to cut and one place to mask, so no quote can
  escape either.

## R5 — A NUL byte is caught before any grep or awk reads the file

- **Decision**: in the per-plugin loop, before the dated-heading `grep`,
  count NUL bytes with `tr -cd '\000' < file | wc -c` and die, in both
  forms, with `<plugin>: CHANGELOG.md holds a NUL byte, which the gate
  cannot read — this tree is NOT released`.
- **Rationale**: today `grep` prints `Binary file … matches` into `head`,
  the version extraction then fails under errexit, and the gate exits 1
  with no output (measured in both forms). What an awk does with a NUL
  differs between the CI awks, so the check runs before awk too. The real
  tree holds no NUL byte, so FR-007 holds.

## R6 — Narrowing 1: a fence on a numbered list's later item

- **Today**: `odd` refuses any fence opener on an ordered marker other
  than `1`, because after a text line such a marker does not start a list.
- **Candidate rule**: an ordered marker other than `1` does NOT set `odd`
  when the previous line was blank, OR when the previous line was itself
  an accepted ordered item (its first marker ordered, the same delimiter,
  the same raw text before the marker, a non-empty item, and not itself
  `odd`). Anything else still sets `odd`. Neither the line nor the
  previous item counts as an ordered item unless its number has one to
  nine digits, counted with a loop: the walk's marker pattern accepts any
  run of digits, and CommonMark accepts at most nine.
- **Why it might be safe**: CommonMark lets a non-`1` ordered item start
  a list after a blank line, and lets any item continue a list it is
  already in; the danger is only a first item interrupting a paragraph.
- **Known traps to enumerate**: `Para`, `1.` (empty, so not a list), `2. `
  + fence, which is why the previous item must be non-empty; and
  `1234567890. a`, `2. ` + fence, `   ## x`, a closer, which analysis
  found PASSING a heading when the digit count was unbounded.

## R7 — Narrowing 2: a fence after an HTML block that has ended

- **Today**: one `<` line refuses every later fence opener in the file.
- **Candidate rule**: split the `<` lines in two. A line whose text after
  its markers begins `<!`, `<?`, or (any letter case) `<script`, `<pre`,
  `<style` or `<textarea` keeps today's rule: every later opener is
  refused. Any other `<` line holds an HTML block that CommonMark ends at
  a blank line, so a spaces-only line clears it.
- **Why it might be safe**: CommonMark's HTML block kinds 6 and 7 end at a
  blank line; kinds 1 to 5 end only at their own end marker, which the
  walk does not track, so they stay sticky. A prefix match such as
  `<prefix>` falling into the sticky kind only refuses more.
- **Every `<` line is classified, whatever the current state.** Today's
  code sets `html` only while it is clear. Under R7 that would let a soft
  `<x` hide a hard `<!--` on the next line: analysis found `<x`, `<!--`,
  a blank line, a fence, `-->`, `## x`, a fence PASSING a heading that
  CommonMark renders (`<x` is paragraph text, which `<!--` interrupts).

## R8 — Narrowing 3: a `-` run under an ATX heading

- **Today**: every non-blank line is text above an underline, so
  `### Notes` then `---` is refused.
- **Candidate rule**: a line is a HEADING for the underline test, not
  text, only when its raw text, after tab expansion, is an ATX heading of
  any level indented zero to three columns, with no quote marker and no
  list marker on the line, and no list item can be open. Phase 25's H3
  plant `### x` then `---` passes under this rule, so it moves from the
  refused list to the passing plants.
- **Why it might be safe**: such a line is an ATX heading to CommonMark in
  every position (it interrupts a paragraph), and a `-` run under a
  heading is a thematic break. Deep, quoted and listed `###` lines, which
  review found passing a setext heading in Phase 25, stay text.

## R9 — Narrowing 4: a `-` run after an empty quote line

- **Today**: `> Notes`, `>`, `> ---` is refused, because `>` is not blank.
- **Candidate rule**: a line whose raw text is `>` at column zero followed
  only by `>` and spaces is an EMPTY QUOTE line for the underline test,
  not text. It stays non-blank for every other rule (list clearing keeps
  reading only a spaces-only line as blank).
- **Why it might be safe**: such a line is a blank line inside a block
  quote, which ends any paragraph, so a `-` run under it is a thematic
  break. A deep `>` (indented) stays text: review found that one passing.

## R10 — The proof each narrowing needs

- **Decision**: a checked-in enumeration script,
  `specs/025-gate-closes-phase25-gaps/proof/enumerate.py`, generates every
  sequence of ONE TO THREE lines before, then an opener or heading
  prefix, a body and a line after, each case framed as a changelog: the
  release heading, a blank line, `Plain text.`, a blank line, then the
  case. Its vocabulary covers each narrowing's shapes in every container
  the Phase 25 rig covers (none, quote, list, nested list, list in quote,
  quote in list, indented), the Phase 25 vocabulary, ordered markers of
  one, nine and ten digits, the HTML starts of both kinds and their end
  markers (`-->`, `</details>`), and body lines both at column zero and at
  the opener's continuation indent. For each case it asks the reference
  reader (markdown-it-py, CommonMark mode) whether a level-2 heading other
  than the release heading is rendered, and runs the walk extracted
  byte-for-byte from `scripts/check-versions.sh`.
- **Batch twice, then a sample one file at a time**: the walk is run in
  batch for speed, twice, in two case orders (as generated, and reversed).
  A state variable the batch reset misses would carry a refusal from one
  case into the next, so the two orders would disagree; every case where
  they disagree is rerun one file per walk run, and so is a random sample
  (fixed seed) of 2,000 cases the reader renders as a level-2 heading. A
  per-file rerun of every such case is not feasible: about 2 million
  cases at about 43 ms a run. The script finds `bash` with
  `shutil.which`, never the bare name (on Windows that reaches WSL's
  bash), and prints its case count and run time.
- **Pass condition**, per narrowing: against the narrowed walk, 0 cases
  where the reader renders a level-2 heading and the walk passes; against
  a POSITIVE CONTROL walk at least 1. Each control is an explicit text
  substitution on the extracted walk, kept in the script and checked to
  have landed: R6 without the non-empty and nine-digit conditions, R7
  with every `<` line clearing at a blank, R8 for any `###` line, R9 for
  an indented `>`. A control substitution that changes nothing in the
  extracted walk is an error, never a skip. A narrowing that fails either
  half is reverted and its shape stays refused (FR-010). Whether the
  gate holds a narrowing is decided by running the gate's walk on that
  narrowing's passing plant: refused means REVERTED, and no control is
  run; passed means KEPT, and its control must find a wrong pass.
- **A body for every control**: the bodies include a fence opener, then an
  HTML end marker (`-->`, `</pre>`), `## x`, then a closer, so the R7
  control has a case it can fail on. Before a narrowing is judged, its
  control is confirmed to find at least one wrong pass.
- **Exit status**: non-zero for each of these, and zero otherwise: the
  gate's walk passes a rendered heading; a kept narrowing's control finds
  none; the two batch orders disagree; a sampled one-file rerun disagrees
  with the batch; a control substitution changes nothing. The controls
  are meant to find wrong passes, so those never fail the run.
- **Where the results live**: the run directory keeps every input and
  verdict; the PR body sums them up. The script is in the spec directory
  so the owner can rerun it; it is run-time evidence, not a test, and
  nothing under `tests/` needs Python.

## R11 — The test helpers

- **Arguments, not strings**: every `run bash -c` in the `--released`
  tests becomes `run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" ${3:+--released "$3"}' _ "$d" "$ROOT" "$copied"`
  (or two fixed spellings, one per form). The "one version-agreement
  script" test counts `run bash <script>.sh` lines only, so it is not
  affected.
- **Absolute paths, every spelling**: one helper, called after every
  `run` in the `--released` tests, refuses an output holding `$TEST_DIR`,
  `$ROOT`, or either in its other spellings: the `-m`, `-u` and `-w`
  forms of `cygpath` where it exists; where it does not, the `/c/…` and
  `C:/…` forms built with parameter expansion when the path has a drive
  letter. A failure names U2.
- **H8**: each test's combined copy holds EVERY refused plant of that
  test that the default form passes, each after its own `Plain text.` and
  blank line; the NUL plant (K5 stops both forms) and a first heading
  above the release (it cannot report `state=released`) are left out by
  name; contract H8 says so.
- **`forms_passes`**: takes the line it planted and calls `forms_at` on
  it first.
- **The fixture self-check**: the dropped file is checked by a second,
  independent test in bash — a `grep -c` over the raw lines for `^##`,
  fence starts and `-` runs after removing leading spaces, `>` and list
  markers with a different code path — and `mv` failing returns 1 with a
  `fixture:` message.
- **`forms_at`**: the count is taken with `|| true` and compared, so a
  missing line prints `fixture: …` instead of aborting under errexit. A
  planted line too long to pass as an argument (the 400,000-marker line
  is 800 KB; Linux caps one argument at 128 KiB) is never given to
  `forms_at`: it is found with `LC_ALL=C awk 'length($0) > <limit> { print NR }'`.
  Every awk that counts a line's length in the tests runs under
  `LC_ALL=C`, the fixture helper's included, so it counts bytes as the
  gate does.
- **Unique plant text**: the copied changelog holds `### Notes` five
  times, so a plant that must be found by its text uses a token no
  changelog holds (`### Plantnote`, `CRplant`).

## R12 — Where the new checks are tested

- **Decision**: one new test, `--released refuses a byte or a line it
  cannot judge` (lone CR, NUL in both forms, an over-long line, a 400,000
  marker line, and the cut marker), so the suite reads `1..249`. The
  masking plants join the first-heading test (`--released refuses a
  dangling Unreleased heading`). Each narrowing's passing plant joins the
  `judges no non-heading` test, and its still-refused neighbours join the
  test of their clause. The fixture helper also drops a CR line and an
  over-long line, with its own constants (FR-017).
- **Rationale**: the slowest test is about 18 s of the 60 s cap; a new
  test with about eight gate runs costs about 6 s.

## R13 — Portability

- No interval expressions; no `gensub`; no array `length`; `index`,
  `substr`, `length`, `sub`, `match` with `RSTART`/`RLENGTH` only, as in
  Phase 25. `tr -cd '\000'` and `wc -c` are POSIX; the count is compared
  with arithmetic so BSD `wc`'s leading spaces do not matter.
