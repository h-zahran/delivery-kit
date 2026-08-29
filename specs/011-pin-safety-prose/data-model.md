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

**Validation rules.** Every slice, before it is searched:

1. Its first line matches `open`. A slice that opened somewhere else is a
   slice of the wrong region.
2. Its last line matches `close`. This is the one that matters: an awk range
   whose closing pattern never matches runs silently to end of file, and the
   pin then searches the whole document while claiming to search a section —
   the exact failure FR-007 exists to prevent, arriving through the back door.
3. It contains no heading-shaped line (`^**` or `^#` through `^######`) other
   than the closing one. A heading appearing inside means the document was
   restructured underneath the slice.

Rule 2 is FR-008. Rules 1 and 3 are the existing G-slice pin's own checks,
reused because they have already caught a real restructuring once.

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
| `P5` red-flag rows | `## Red flags` → `## When a phase fails` | raw | 7 rows + completeness | FR-005, FR-005a |

Thirteen clause anchors, seven row anchors, one completeness assertion.

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

Data rows are identified as lines matching `^| ` minus the header
`| Thought | Reality |`. The `|---|---|` separator does not match `^| ` and is
excluded by construction, not by a special case.

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
