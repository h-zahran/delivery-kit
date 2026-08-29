# Data model: the five pins

**Feature**: 011-pin-safety-prose
**Date**: 2026-08-29

There is no runtime data here. What this document models is the static
structure the five tests share, so that implementation and review can check
one shape five times instead of arguing five times.

---

## Entity: a region slice

The bounded excerpt of the orchestrator that one pin is allowed to search.

| Field | Meaning | Constraint |
|---|---|---|
| `open` | awk regex matching the first line | Must match exactly one line in the document |
| `close` | awk regex matching the last line | Must match exactly one line, after `open` |
| `form` | `raw` or `flat` | `flat` collapses newlines to single spaces |

**Validation rules.** SIX, and the count is stated because a miscount here is
what invites someone to delete the one that matters. Every slice, before it is
searched:

1. The orchestrator is a readable FILE — `-f` as well as `-r`, because a
   directory is readable and would otherwise produce five pins blaming missing
   prose.
2. The slice is non-empty. An empty slice means the opening boundary matched
   nothing.
3. Its first line matches `open`. NEAR-UNREACHABLE in practice — awk's range
   only starts emitting on a matching line — and labelled as such in-file.
4. Its last line matches `close`. **This is the one that must never go.** An
   awk range whose closing pattern never matches runs silently to end of file,
   and the pin then searches the whole document while claiming a section — the
   exact failure FR-007 exists to prevent, arriving through the back door.
5. `open` matches exactly once in the document. awk's range operator RESTARTS
   on every later match, silently concatenating disjoint regions into one slice.
6. It contains no heading-shaped line (`^**` or `^#` through `^######`) other
   than the closing one. A heading inside means the document was restructured
   underneath the slice. Fires on any bold-led line, not only a heading — an
   accepted cost, recorded in-file.

Rule 4 is FR-008. Rules 3 and 6 are the existing G-slice pin's own checks,
reused because they have already caught a real restructuring once. Rules 1, 2
and 5 came from review rounds 2 and 3, each after a measured wrong-message or
silent-widening failure.

**The `\r` strip.** Every slice passes through `tr -d '\r'` before anything
compares against it. The document carries no carriage returns today and
`.gitattributes` pins `*.md` to LF, so this changes nothing now; it exists so
that a checkout that somehow did carry them fails on line endings nowhere,
rather than failing all five pins at once with a message about missing prose.

---

## Entity: an anchor

One string a pin requires to be present in its slice.

| Field | Meaning |
|---|---|
| `text` | The operative clause, verbatim |
| `match` | `contains` (flattened slices) or `whole-line` (table rows) |
| `message` | What is printed when it is missing |

**Validation rules.**

1. `text` occurs exactly once in the whole document. An anchor with two
   occurrences can be satisfied from outside its region the day its own copy
   is deleted, which silently converts a region pin back into a file-wide one.
2. `text` carries the subject of its obligation, not only the predicate. A
   fragment that reads true about a different subject is satisfied by a mutant
   that swaps the subject — recorded in this suite as having actually happened.
3. `message` names the passage, not the test (FR-009).

**`contains` versus `whole-line`.** The four flattened pins use `contains`,
because a clause is by definition part of a longer line once the slice is
flattened. The row pins use `whole-line`, because a row IS a line and a
`contains` match is defeated by appending a cell after the final pipe — see
research D3, where that mutant is measured passing.

---

## Entity: a pin

One `@test` block. Five of them.

| Pin | Slice | Form | Anchors | FR |
|---|---|---|---|---|
| `P1` seed-form fall-through | `**Seed forms.**` → `## The twenty phases` | flat | 2 | FR-001 |
| `P2` roll nothing back | `## When a phase fails` → `## Resume` | flat | 3 | FR-002 |
| `P3` J carry duty | `**J — analyzer…**` → `**K — commit.` | flat | 5 | FR-003 |
| `P4` N degraded | `**N — re-verify…**` → `**N.5 — runtime check.**` | flat | 3 | FR-004 |
| `P5` red-flag rows | `## Red flags` → `## When a phase fails` | raw + flat | 8 rows + completeness + span | FR-005, FR-005a |

Thirteen clause anchors, EIGHT row anchors, one completeness assertion, and
five insertion spans.

Eight rather than seven: the forward loop whole-line checks all eight data
rows, including the one whose pin is owned by another test. That was a
deliberate hardening — the eighth row's only other pin is two file-wide
substrings, so it could be cut from the table and pasted into an appendix with
everything green. Undercounting it here would hide exactly the hardening that
closed a relocation escape.

---

## Entity: the completeness assertion

`P5` alone carries a second, opposite check.

**Forward** — every row in the pin list appears in the table. Catches deletion,
rewording, and appended text.

**Reverse** — every data row in the table appears in a reference list of eight:
the seven this pin owns, plus `"Fix everything" is implied…`, which is pinned
by the existing test rather than here. A row present in the table and absent
from that list is a new red-flag row nobody pinned, and it goes red naming
itself.

Data rows are found by the table's SHAPE: skip to the separator line — pipes,
dashes, colons and spaces, carrying at least one of each of the first two —
then take lines until the table ends at a blank line, resuming if another
separator follows.

**This replaced an earlier rule that was measured broken, and the earlier rule
is recorded here because a reader reconciling code against this document would
otherwise "fix" the code back to it.** That rule was: lines matching `^| `,
minus the literal header `| Thought | Reality |`, with the `|---|---|`
separator excluded "by construction". Every clause of it failed:

- `^| ` misses three row spellings GFM renders identically — no space after the
  pipe, up to three leading spaces, and a body row with the leading pipe
  omitted — so a row added in any of them was pinned by nobody.
- Excluding the header by its literal text meant renaming the header produced a
  red instructing the maintainer to pin a table header as a red-flag rule.
- A formatter that pads the separator to `| --- | --- |` defeats the separator
  exclusion, and a plain `---` thematic break elsewhere in the region was taken
  as the separator.
- Taking the header as "the first pipe-bearing line" broke on prose: the region
  is prose, and a sentence mentioning `--auto | --auto-release` displaced it.

**Why both.** Forward alone is a positive control: it proves the pin can go
red, never that it goes red when it should. A hand-written list that has
fallen behind the table passes forward perfectly.

---

## Relationships

```
prose.bats
  |
  +-- slice helper  (shared; owns the three validation rules and the \r strip)
  |     |
  |     +-- P1 ... P5 each call it with their own open/close/form
  |
  +-- P5 additionally owns the two-direction completeness check
```

The helper is defined in `prose.bats`, not in `tests/helper.bash`. The shared
helper is loaded by all six suites in the tree; a function used by one suite
does not belong in the file that reaches the other five.

---

## What is NOT modelled here

- The orchestrator's content. It is read-only input (FR-011).
- The existing eleven tests. Untouched (FR-010).
- Any state that survives a run. These tests read a file and assert; there is
  nothing to persist.
