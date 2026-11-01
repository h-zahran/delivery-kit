# Contract: the prose suite's two helpers

Both live in `pipeline/tests/prose.bats`. Callers read them through `$( )`, so
every diagnostic goes to STDERR and a failure returns 1.

## `prose_slice <file> <open-ere> <close-ere> <raw|flat> <name> [<declared-line>...]`

Prints the region of `<file>` from the one line matching `<open-ere>` to the
first later line matching `<close-ere>`, inclusive. Carriage returns are
stripped before matching.

| Condition | Exit | Message names |
|---|---|---|
| fewer than 5 arguments | 1 | the argument count |
| `<raw\|flat>` is anything else | 1 | `<name>` and the bad form |
| `<file>` missing, not a regular file, or unreadable | 1 | `<name>` and `<file>` |
| slice empty (opener matched nothing) | 1 | `<name>` and the opener |
| opener matches more than one line | 1 | `<name>` and the opener |
| slice did not start on the opener (near-unreachable) | 1 | `<name>` and the first line |
| closer not found (slice ran to end of file) | 1 | `<name>`, the closer, and the last line |
| an inner line is heading-shaped and not declared | 1 | `<name>` and each such line |
| otherwise | 0 | — prints the slice, `raw` as lines, `flat` through `prose_flat` |

A declared line is compared to each inner line as a whole fixed string. It
admits only an identical line; every other heading-shaped inner line still
fails.

## `prose_flat`

Reads stdin, writes stdout: carriage returns removed, every line feed turned
into a space, runs of spaces squeezed to one. Exit 0. Takes no arguments.
Callers feed it the way their old code did: `< "$file"` for a whole document,
`<<<"$var"` for a slice already held, or a pipe after a site-specific step.

## The refusing test

Walks `pipeline/tests/prose.bats`, skipping only the two helper bodies, and
fails naming each line that holds a bare awk range with a named closer or an
inline flatten pipeline. It also fails when it walked zero lines or did not
find both helper bodies.
