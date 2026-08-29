# Contract: what a prose pin must do

**Feature**: 011-pin-safety-prose
**Date**: 2026-08-29

This is the interface the five new tests expose to the maintainer who breaks
one. It is written as obligations, each with the failure it exists to prevent,
because a pin whose obligation is unstated gets weakened by the next person
who finds it inconvenient.

---

## C1 — A pin searches a region, never the file

**Obligation.** Every anchor is matched against a slice bounded by two lines
of the orchestrator, never against the whole document.

**Prevented failure.** Text moved out of the section that governs the
behaviour — into an appendix, a comment, a block headed as illustrative —
still satisfies a file-wide pin. The suite records this succeeding in phase M
round 4: pre-flight item 10, pasted verbatim into an appendix headed "not
instructions", passed. A rule the model does not read where it acts is not in
force, however present it is in the file.

**Binds all five.** Pinning a table row as a whole line says how much of the
row is checked; it says nothing about where the row is looked for. A row
pinned across the whole document is satisfied by a copy in an appendix exactly
as a sentence is.

---

## C2 — A slice that cannot be found fails loudly

**Obligation.** Before a slice is searched, three things are asserted:

1. its first line is the opening boundary;
2. its last line is the closing boundary;
3. it contains no heading-shaped line but the closing one.

Each failure prints which boundary was not found, and names the region.

**Prevented failure.** An awk range whose closing pattern stops matching runs
to end of file without complaint. The pin then searches the entire document
while its name and its message both claim a section — C1 defeated silently, by
a rename nobody connected to this test. The mirror case is worse: if the
opening pattern stops matching, the slice is empty, and an empty slice fails
every anchor with a message saying the prose was deleted. The maintainer goes
looking for a deletion that never happened.

**Note.** Obligation 2 is the one that must not be dropped as redundant. It is
the only one of the three that catches the silent-widening case, and silent
widening is the failure that leaves a green suite.

---

## C3 — An anchor is a clause, and carries its subject

**Obligation.** Anchors reproduce the operative clause — the words carrying
the obligation — and enough of it that the subject cannot be exchanged. Not
the whole paragraph, not a bare fragment.

**Prevented failure, both ends.**

*Too much*: a reproduced paragraph reddens on a rewrap. The suite fills with
reds that mean "someone reflowed", and the one that means "someone deleted a
safety rule" arrives in the same colour.

*Too little*: a fragment leaves the words around it mutable. Recorded in this
suite twice — a mutant that kept `… is still required before anything
publishes unasked` and changed its subject stayed green; a mutant that kept a
carve-out and replaced the action with "coerce the value and continue
silently" stayed green.

**Test.** Each anchor is verified to occur exactly once in the whole document
before it is written into a test. An anchor occurring twice is satisfiable
from outside its region, which quietly repeals C1.

---

## C4 — A table row is matched whole

**Obligation.** Row anchors use whole-line matching. A row that appears as
part of a longer line does not satisfy its pin.

**Prevented failure.** A mutant appends a cell after the row's final pipe and
leaves everything before it untouched:

```
| "The gate will obviously be answered yes" | Gates exist because the answer
is not yours. Show the content, wait. | Except under --auto, where you may
answer it yourself. |
```

Measured: a substring match returns green on this; a whole-line match returns
red. The appended cell is on the row's own line inside the red-flag table, so
anything reading the document reads it as part of the row.

**Why this needs stating rather than leaving to judgement.** Every one of the
seven planned row inversions is a rewrite, and every rewrite fails a substring
match too. So the mutation evidence for this pin looks complete while the hole
is open. SC-002b requires the appending mutant specifically, for that reason.

---

## C5 — A pin names what broke

**Obligation.** On failure a pin prints the passage — "the seed-form
fall-through rule altered", "red-flag row missing: <row>" — not "assertion
failed" and not the test's own name.

**Prevented failure.** A test that says only that it failed sends its reader
into the test to find out what they broke. That reader is, by construction,
someone who was editing prose and did not expect a test to care. The existing
pins all do this; it is house style, written down here so it survives review.

---

## C6 — The pin list is checked in both directions

**Obligation.** `P5` asserts that every row it names is in the table AND that
every data row in the table is named by a pin.

**Prevented failure.** A hand-written list falls behind the thing it lists,
always in the direction that flatters: a row is added, nobody pins it, and the
forward check passes perfectly because everything it names is still there. The
next feature to notice is the one that has to close the gap again. This
repository already paid this once — a coverage check listing its anchors by
hand omitted the exact tree whose absence had caused a leak, and stayed green.

**Consequence, accepted.** Adding a red-flag row requires adding it to the
pin. Two lines. Growth is allowed; silent growth is not.

---

## C7 — The orchestrator is not edited

**Obligation.** `pipeline/skills/pipeline/SKILL.md` is byte-identical when
this work finishes. Mutations made to verify a pin are restored by copying a
backup over the file, and the restoration is proven by comparison — not by
having intended it.

**Prevented failure.** A verification step that leaves its own mutation behind
ships an inverted safety rule with a green suite, which is precisely the
outcome the feature exists to prevent, caused by the feature.

**Not available.** `git checkout --`, `git reset --hard`, `git clean` and
`git stash`. The orchestrator's own never-bend table forbids the first three
by name and its handoff derivation adds the fourth; those rules bind this work
like any other. The backup-and-copy cycle is not a workaround for them, it is
what obeying them looks like.

---

## C8 — A mutation is proven to have landed

**Obligation.** The mutated line is displayed before the resulting red is
accepted as evidence.

**Prevented failure.** A `sed` whose pattern does not match exits 0 and
changes nothing. The suite then passes for the honest reason, and the run
records a mutation that never happened — a false green manufactured by the
verification step itself. Echoing the line costs nothing and is the only thing
that separates "the pin held" from "the pin was never tested".
