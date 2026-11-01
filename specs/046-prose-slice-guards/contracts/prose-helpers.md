# Contract: the prose suite's helpers

All live in `pipeline/tests/prose.bats`. Callers read them through `$( )`, so
every diagnostic goes to STDERR and a failure returns 1.

## `prose_slice <file> <open-ere> <close-ere> <raw|flat> <name> [<declared-line>...]`

Prints the region of `<file>` from the one line matching `<open-ere>` to the
first later line matching `<close-ere>`, inclusive. Carriage returns are
stripped before matching. One awk pass takes the slice and counts the lines
matching the opener.

| Condition | Exit | Message names |
|---|---|---|
| fewer than 5 arguments | 1 | the argument count |
| `<raw\|flat>` is anything else | 1 | `<name>` and the bad form |
| `<file>` missing, not a regular file, or unreadable | 1 | `<name>` and `<file>` |
| awk itself failed | 1 | `<name>`, the status and both patterns |
| slice empty (opener matched nothing) | 1 | `<name>` and the opener |
| opener matches more than one line | 1 | `<name>` and the opener |
| slice did not start on the opener (near-unreachable) | 1 | `<name>` and the first line |
| closer not found (slice ran to end of file) | 1 | `<name>`, the closer, and the last line |
| a declared line is inside the slice zero times, or more than once | 1 | `<name>`, the count, and the line |
| grep itself failed while handling the inner lines | 1 | `<name>` and the status |
| an empty declared line | 1 | `<name>` |
| an inner line is heading-shaped (`^(\*\*\|__\|#{1,6} )`, column 0) and not declared | 1 | `<name>` and each such line |
| otherwise | 0 | — prints the slice, `raw` as lines, `flat` through `prose_flat` |

A declared line is compared to each inner line as a whole, case-sensitive,
fixed string, and must appear there exactly once: zero means the declaration
is stale, more than one means the line was duplicated. It admits only that one
line; every other heading-shaped inner line still fails. Indented headings
and a bare `#` are not detected on purpose (an indented `# comment` in a fenced
shell block would fail as a restructure), nor are setext headings (their
`---` underline is also a horizontal rule).

## `prose_flat`

Reads stdin, writes stdout: carriage returns removed, every line feed turned
into a space, runs of spaces squeezed to one (`tr -d '\r' | tr -s '\n' ' '`).
Exit 0. Any argument is refused with exit 1 and a message, because a call
written `prose_flat "$file"` would otherwise flatten empty stdin and every
absence check on it would pass. Callers feed it the way their old code did:
`< "$file"` for a whole document, `<<<"$var"` for a slice already held, or a
pipe after a site-specific step.

## `pf_walk <raw|flat>`

The pre-flight walk slice, written once: `prose_slice` on the orchestrator from
`The script only reports; the decisions are yours` to `**Base branch:**`,
declaring the walk's one bold-led line.

## `prose_refuse_walk <file>`, and the refusing test

Walks `<file>`, skipping the bodies of the helpers listed inside it —
`prose_slice`, `prose_flat` and `prose_refuse_walk`; a new helper is added to
that list. A body runs from a column-0 `name() {` line to the next line that
is exactly `}`. It fails naming each line that holds a bare range or an inline
flatten:

- a range: a slash pattern, optional spaces, a comma, then a second slash
  pattern, a line-ending backslash, or the end of the line — in either quote
  style, after awk options, or in `sed -n`; and the expression form
  `$0 ~ …, $0 ~ …`;
- a flatten: `tr`, with any options, whose first set holds `\n` or `\012`
  (with or without other characters, either quote style) and whose second set
  is spaces; a line ending in `tr` and an open quote (the split shape);
  `paste -s`.

These are the spellings known when it was written, not every possible one.

It also fails when it walked zero lines, when a named helper body was not
found exactly once, or when a body never closes (a `@test` line, a column-0
`name() {` line, or the end of the file reached while skipping). The refusing
test, "no bare awk range slice and no inline flatten outside the two helpers",
runs it on `prose.bats` itself; its name predates the third helper and is
kept because the records cite it.
