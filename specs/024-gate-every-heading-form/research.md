# Research: the release gate reads every level-2 heading form

All measurements 2026-10-02 at `main` = `33c972b` (the gate is unchanged
since `8bc9b5a`: `git diff 8bc9b5a 33c972b -- scripts tests` is empty).

## R1 — One walk over the file, in the one gate

- **Decision**: the release form's whole-file rule (the awk program in
  `scripts/check-versions.sh` that follows the first-heading check) is
  replaced by one awk program that reads the changelog line by line and
  keeps a small state (data-model.md): an open fence, whether a list item
  can be open, and the previous line. It prints the first refusal and
  stops.
- **Rationale**: a heading's form depends on its neighbours (a setext
  underline needs the line above; a fence or a list item changes how later
  lines read), which a one-line pattern cannot see. Constitution IV: the
  rule stays in the one script both callers run.
- **Alternatives considered**: a Markdown parser (none ships on all three
  CI systems; a new dependency for a gate); a chain of `grep` passes
  (cannot carry state from line to line).

## R2 — How one line is read

- **Decision**, in this order, for each line:
  1. **Tabs.** Expand tabs to spaces with tab stops every 4 columns
     (CommonMark), so every indent is counted in columns. The refusal still
     quotes the raw line.
  2. **Quotes.** Repeatedly remove leading spaces, then `>` and one optional
     space, counting the quote depth. `ind` is the number of leading spaces
     left after the last `>` (or on the line, when it has none). Inside an
     open fence this step is replaced by step 3's own reading.
  3. **Open fence.** A fence is followed only while its shape is clean; at
     the first line that makes it unclear, the walk refuses that line
     (R7) rather than guess where the fence ended. Clean is judged on the
     raw text, with no column arithmetic. The opener's PREFIX is everything
     on its line before the fence characters (spaces, `>` markers and list
     markers); its CONTINUATION prefix is that text with every character
     but `>` turned into a space (`- ```` gives two spaces; `  > ```` gives
     `  > `). Inside the fence, for each line (tabs already expanded):
     - a line equal to the continuation prefix, then a run of the fence's
       character at least as long as the opener's, then only spaces, closes
       the fence; the line is skipped;
     - a blank line (only spaces and `>`) is content only when, with
       trailing spaces removed, it equals the continuation prefix with
       trailing spaces removed (the `>` markers in the same places);
     - a line that starts with the continuation prefix is content, unless
       what follows it is any number of spaces and then a closer shape (a
       run of the fence's character at least as long, then only spaces),
       which is unclear: no indent arithmetic decides whether such a line
       closes the fence, because a `>` written without its optional space
       shifts every later column by one;
     - any other line is unclear.
     A line carrying the whole continuation prefix continues every
     container the fence sits in (each `>` present, a list item's indent
     present), so a skipped line can never be one Markdown reads as outside
     the fence. Everything else is refused, which fails closed. The real
     fence at `handoff/CHANGELOG.md` lines 316–319 is clean: its opener is
     two spaces then three backticks, the lines between start with two
     spaces, and the closer is two spaces then three backticks.
  4. **List state.** An unindented line (`ind` 0, quote depth 0) that is
     not blank, not a list marker and not a quote clears "a list item can
     be open" when the previous line was blank (only spaces: a line of `>`
     markers alone, deep in an item, is text and clears nothing); an unindented ATX heading
     or fence clears it whatever came before. (Straight after item text, an
     unindented text line is a lazy continuation and does not clear it.)
  5. **Setext.** If the text after the spaces is one or more `-` then only
     spaces, and the previous line was a text line, refuse the PREVIOUS
     line as a setext heading. This runs before list markers are removed:
     a bare `-` under a text line is an underline, not an empty list item.
     Otherwise the line goes on to step 6.
  6. **List markers and quotes, in any order.** Repeatedly remove leading
     spaces, then either a list marker (`-`, `*`, `+`, or digits then `.` or
     `)`, then a space or the end of the line) or a `>` with its one
     optional space, until neither applies: `- > ## Notes` is a heading in a
     quote in an item, and `- > ```` opens a fence whose prefix holds that
     `>`. Any list-marker removal sets "a list item can be open"; a bare `-`
     that step 5 did not refuse reaches this step and is an empty list
     item.
  7. **Fence opener.** Text (after spaces) of three or more backticks with
     no further backtick, or three or more tildes, opens a fence, at ANY
     indent, unless Markdown might not open it: on an ordered list marker
     other than `1`, or below any line that started with `<` after its
     containers, the opener is refused instead (added at phase I, when
     review passed a heading under each). Otherwise: record its character, length, prefix and continuation prefix
     (step 3), and its line and text. The line is not judged. An opener
     indented four or more columns is indented code to CommonMark; reading
     it as a fence is safe, because step 3 refuses any later line that
     lacks the four-space prefix.
  8. **Indented code.** `ind` of four or more, with no list marker removed
     on this line and no list item able to be open: not judged; the line
     counts as text for step 5 (it may be a lazy paragraph line).
  9. **ATX.** Text (after spaces) of `##` then a space or the end: refused
     unless the RAW line is exactly canonical.
  10. **Previous line.** Blank (only spaces) or text (every other line
      outside a fence, a fence closer included). An earlier design kept a
      third kind, "other", for headings, fence lines and `-` runs; review
      at phase I passed a setext heading through each of them, so the
      kind was dropped: stricter, not cleverer.
  At the end of the file, an open fence is refused, naming its line and
  text, unless something was already refused (R4a).
- **Rationale**: this is CommonMark's container-first reading, cut down to
  what decides "is this a level-2 heading", with every cut made on the
  refusing side (R3).
- **Alternatives considered**: tracking each list item's exact text column
  and a stack of nested items (the analysis found five ways a precise
  tracker leaks a wrong pass: nested items, wide markers, a quote inside a
  list continuation, a fence that outlives its container, and an indented
  lazy line; the "can be open" flag closes the list cases by judging more).
  The next two passes found five more leaks in fences followed by column
  arithmetic (a `- ```` opener, a closer less indented than its opener, a
  `>` line inside a top-level fence, an opener indented four or more, and a
  quote that moved inside a listed fence). The prefix rule of step 3 closes
  them all: no line is skipped unless it carries the opener's whole
  container prefix. A fourth pass found two more, both closed by making the
  rule stricter, not cleverer: a blank line must equal the prefix exactly,
  and any closer shape other than the exact closer is unclear.

## R3 — Which way doubt leans

- **Decision**: every simplification errs toward refusing. While any list
  item can be open, every deeply indented `##` is judged (FR-006). HTML
  blocks are not tracked, so any fence opener below a line starting with
  `<` is refused (step 7). A `---` directly under any text line, a list
  item's included, is read as an underline. Where a fence's end depends on
  a container, the walk refuses the first unclear line instead of guessing.
- **Rationale**: the owner's ruling (spec, Clarifications and FR-007): a
  wrong refusal is acceptable because it fails closed and the owner fixes
  the changelog; a wrong pass is not.
- **Alternatives considered**: a full CommonMark reading (much larger, and
  every extra branch is a place a wrong pass can hide).

## R4 — The real tree passes

- **Decision**: no change is needed to either changelog. Walked by hand and
  by the independent analysis at F: the fenced block at
  `handoff/CHANGELOG.md` lines 316–319 sits inside a `- ` item, two columns
  in; it opens and closes at `ind` 2 and every line between is indented 2.
  Every `###` line fails step 9. Every `## ` line is canonical. Neither file
  holds a tab, a CR, a `>` line, a list-marker `##` line or a deep `##`.
- **Rationale**: H8 and SC-006 require the real tree to pass; the plan
  must not discover otherwise at H.

## R4a — One refusal, then stop

- **Decision**: the walk sets a `refused` flag when it prints a refusal and
  calls `exit`; the END block reports an open fence only when nothing was
  refused.
- **Rationale**: in every awk, `exit` inside a rule still runs END. Without
  the flag, a heading refused in a file that also left a fence open would
  print two refusals.

## R5 — The test fixture's own rule

- **Decision**: `normalise_to_released` in `tests/portability.bats` keeps
  its own, deliberately WIDER rule, with no state. On each line it expands
  nothing and removes, one at a time and repeatedly, leading spaces and
  tabs, `>` markers (one optional space or tab after), and list markers
  (`-`, `*`, `+`, or digits then `.` or `)`, then a space, a tab or the
  end). It tests the line BEFORE the first removal and AFTER every one, and
  drops it when any of those forms is: a fence opener or closer (three or
  more backticks or tildes); one or more `-` then only spaces or tabs; or
  `##` followed by a space, a tab or the end — unless the raw line is
  exactly canonical. Testing between removals matters: a bare `-` is a
  setext underline to the gate, but removing it as a list marker would
  leave an empty string the fixture keeps. It then runs the same wide test over its result and asserts
  that no line but a canonical one matches it and that at least one
  canonical heading remains.
- **Rationale**: FR-012 asks the fixture to remove every refused form with
  its own patterns; a wider rule is a superset of the gate's, so whatever
  the gate refuses, the fixture has removed. Removing every fence line
  removes any unclosed fence, and since every `##` line is removed whatever
  its indent, no deep-indent or container case is left for the gate to
  find.
- **Alternatives considered**: a second copy of the gate's walk in the test
  (two copies of one rule, which IV forbids drifting apart, and which a
  fixture does not need).

## R6 — Portability

- **Decision**: no interval expressions (`{0,3}`) in any awk pattern;
  indents are counted with a small column function. No `gensub`, no
  `match()` with an array, no array `length`. Only `sub`, `gsub`, `substr`,
  `index`, string `length` and `match` with `RSTART`/`RLENGTH`.
- **Rationale**: the three CI systems run gawk (Ubuntu's runner image and
  Git for Windows) and the BSD awk (macOS). The Phase 24 gate already uses
  `[[:print:]]` and passed CI on all three; mawk 1.3.3, which lacks
  character classes, is not on any CI system and is not claimed.

## R7 — Refusal messages

- **Decision**: each refusal is one line, every non-printable character
  shown as `?`, followed by the gate's tail `— this tree is NOT released`:
  - ATX, any container: `line <n> holds '<text>', which is not a dated
    version heading` (Phase 24's form, which its tests read);
  - setext: `line <n> holds '<text>', underlined at line <n+1>`;
  - unclosed fence: `line <n> opens a code fence that is never closed:
    '<text>'`;
  - unclear fence (step 3): `the code fence opened at line <n> may already
    have ended at line <m>, which holds '<text>'` (the opener first, so a
    blank unclear line still names something to edit);
  - an opener Markdown might not open (step 7): `line <n> opens a code
    fence on an ordered list marker other than 1, which may not start a
    list: '<text>'`, or `line <n> opens a code fence that the HTML at line
    <m> may hold: '<text>'`.
- **Rationale**: one message shape per kind; the line a maintainer must
  edit is the one named, with its text (FR-008).
