# Research: Every prose slice is guarded

All counts are a record of one run on 2026-11-01 at `f72276c`.

## R1. Where the bare ranges are, and which the helper would refuse today

Command: `grep -nE "awk '/[^']*/,/" pipeline/tests/prose.bats`.
13 sites over 6 distinct slices:

| Slice (open → close) | Document | Sites | Inner heading-shaped line today |
|---|---|---|---|
| `**G — implementer gate.**` → `**H — implement.**` | orchestrator | 2 | none |
| `The script only reports; the decisions are yours` → `**Base branch:**` | orchestrator | 5 | `**Read item 11 before item 1.** It is the one decision that fires out of` |
| `Project type : ` → `Will skip ` | orchestrator | 2 | none |
| `Will skip ` → `The script only reports; the decisions are yours` | orchestrator | 1 | none |
| `## Resolving the layers` → `## Keys` | configuration.md | 2 | none |
| `## The Implementer line` → `## The state directory` | configuration.md | 1 | `**Implementer:** \`preflight.sh\` never reads \`.delivery-kit.json\`, so this` |

Every opener matches exactly one line of its document (measured with
`grep -cE`), so the duplicate-opener guard passes on all six.

- **Decision**: two slices need a declared inner line; the other four go
  through the helper unchanged.
- **Rationale**: the inner-heading guard is right to refuse an unknown bold
  line; it is wrong only about these two known ones.
- **Alternatives considered**: (a) drop the inner-heading guard for these
  calls — rejected, it switches off FR-005's protection for the whole slice;
  (b) move the boundary — rejected, it changes what the pins search (FR-004).

## R2. How a declared inner line is matched

- **Decision**: extra arguments after `<name>`; each is a whole line, matched
  with `grep -vxF` against the inner lines before the heading check.
- **Rationale**: fixed-string, whole-line matching cannot accidentally admit a
  different heading; a rewrapped paragraph changes the line and fails loudly
  with the existing "unexpected heading-shaped line" message, which prints it.
- **Alternatives considered**: an ERE prefix (`^\*\*Read item 11`) — rejected,
  a prefix admits any line that starts the same way, which is the shape the
  guard exists to refuse.

## R3. The flatten helper's shape

Command: `grep -c "tr -s ' '" pipeline/tests/prose.bats` → 55 lines; one of
them is inside `prose_slice`, and one site (lines 974-975) writes `'\n'` as a
real newline inside the quotes. Inputs reach the idiom three ways: `< "$file"`
(whole documents), `<<<"$var"` (slices already held), and a pipe (after
`tr -d '\r'`, `sed 's/^> //'`, or an awk section walk).

- **Decision**: `prose_flat` reads stdin and runs `tr -d '\r' | tr '\n' ' ' |
  tr -s ' '`. Each site keeps its own input mode: `prose_flat < "$file"`,
  `prose_flat <<<"$slice"`, `… | prose_flat`. A site's pre-steps (`sed 's/^>
  //'`) and post-steps (`sed 's/ $//'`) stay at the site.
- **Rationale**: keeping the input mode keeps the bytes (a herestring adds one
  trailing newline, which becomes the trailing space the pins already live
  with), and keeps whole documents off herestrings, which hang Git Bash at
  ~64 KB. Stripping CR everywhere changes nothing on LF documents (all `*.md`
  are pinned to LF by `.gitattributes`); the differential (R6) shows it.
- **Alternatives considered**: a file-argument helper (`prose_flat <file>`) —
  rejected, it cannot take a slice already held without a temp file.

## R4. Guard tests

- **Decision**: one `@test` per guard, each building a small fixture document
  in `$BATS_TEST_TMPDIR`, calling the helper through `run --separate-stderr`,
  and asserting `$status` is exactly 1 and stderr carries the guard's own
  message words. Guards: arity, form, unreadable (missing file), unreadable
  (a directory), empty slice, opener matched twice, unterminated, undeclared
  inner heading; plus one test that a declared line is admitted while a second
  undeclared heading in the same slice still fails.
- **Rationale**: an exact status catches a guard that falls through (status 0)
  or crashes (127, 2); the message proves WHICH guard fired, so a different
  guard catching the same fixture cannot pass the test.
- **Alternatives considered**: one test looping over guards — rejected, its
  first red hides every later guard.
- The "did not open on its boundary" guard stays untested; its existing
  NEAR-UNREACHABLE comment already gives the reason (FR-006).

## R5. The refusing test

- **Decision**: a test walks `pipeline/tests/prose.bats` line by line in awk,
  skips the bodies of `prose_slice()` and `prose_flat()` (from the `name() {`
  line to the next line that is exactly `}`), and fails naming each line that
  holds a bare range (`awk '/…/,/`) or a flatten (`tr '\n' ' '`, or a line
  ending in `tr '`, the split shape). It prints how many lines it walked and
  fails when that is zero, or when the skipped helper bodies are not both
  found. Its own needles are built from parts so its source does not match
  them.
- **Rationale**: derived coverage (principle V); a body-skip that silently
  skips nothing, or everything, would make it vacuous, so both are asserted.
- **Alternatives considered**: grep with a hand list of exempt line numbers —
  rejected, numbers go stale on the first edit.

## R6. Proving byte-identity (FR-004)

- **Decision**: during implementation, a scratch script extracts, for every
  converted site, the old haystack expression and the new one, evaluates both
  against the current documents, and `cmp`s them. The result table (site,
  bytes, identical yes/no) is written to `differential.md` with the date and
  the two commits.
- **Rationale**: principle II — "unchanged" must be produced by running.

## R7. Boundary-rename sweep (SC-002) and guard controls (FR-009)

- **Decision**: run in a scratch git worktree, never the main checkout. For
  each distinct boundary derived from the `prose_slice` calls, rewrite that
  one line of the document, echo the mutated line to prove it landed, run
  prose.bats, and record red/green; then restore and confirm the restore. For
  each guard, delete the guard's condition in the worktree's copy of the
  helper and confirm its test goes red. Results go into `differential.md`.
- **Rationale**: memory of earlier rigs — a mutation that did not land is a
  false green; an orphaned rig in the main checkout mutated a tracked file.
