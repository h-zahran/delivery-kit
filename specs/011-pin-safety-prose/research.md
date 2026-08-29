# Research: Pin the orchestrator's safety prose

**Feature**: 011-pin-safety-prose
**Date**: 2026-08-29

Everything below was measured against `pipeline/skills/pipeline/SKILL.md` at
commit `304bdad`, not reasoned about. Where a number appears, the command that
produced it is named.

---

## D1 — Region boundaries: which slice each pin searches

**Decision.** Five region slices, each opened and closed by a heading that
occurs exactly once in the document.

| Pin | Opens on | Closes on | Slice length |
|---|---|---|---|
| Seed-form fall-through | `**Seed forms.**` | `## The twenty phases` | 12 lines |
| Roll nothing back | `## When a phase fails` | `## Resume` | 13 lines |
| Red-flag rows | `## Red flags` | `## When a phase fails` | 16 lines |
| J carry duty | `**J — analyzer and full suite.**` | `**K — commit.` | 32 lines |
| N degraded | `**N — re-verify and update the PR.**` | `**N.5 — runtime check.**` | 15 lines |

**Rationale.** FR-007. A file-wide search is satisfied by a copy of the text
anywhere in the document, and the suite already records that escape working in
practice: a rule pasted verbatim into an appendix headed "not instructions"
passed a file-wide pin, which is why the pre-flight pins were sliced in phase
M round 4. A rule that is not in the section that governs the behaviour is not
in force.

**Measured.** Every one of the nine boundary strings occurs exactly once:

```
grep -cF '<boundary>' pipeline/skills/pipeline/SKILL.md   ->  1, for all nine
```

Each slice was then executed and inspected. All five open on their own
heading, close on the next boundary, and contain no heading-shaped line
(`^\*\*` or `^#{1,6} `) other than the closing one. That last check is the same
one the existing G-slice pin performs, and it is what makes an unterminated
slice impossible to miss.

**Alternatives considered.** Line-number ranges, as the seed cites them
(`:266–268`, `:659–661`, and so on). Rejected: a line number is invalidated by
any edit above it, so such a pin fails for a reason unrelated to what it
guards. The seed's line numbers are locations, not requirements — the spec's
final assumption says so.

**Note on regions 2 and 5.** They are adjacent: the red-flag slice closes on
`## When a phase fails`, which is the line the roll-nothing-back slice opens
on. That is correct and not an overlap — a range's closing line belongs to it
as a terminator, and the existing G-slice pin has the same shape, asserting
`**H — implement.**` as its own last line.

---

## D2 — Anchor text: what each pin matches

**Decision.** Thirteen clause anchors across the four multi-line pins, matched
against the flattened slice. Seven whole rows for the fifth.

| Region | Anchors |
|---|---|
| Seed | 2 — the `gh`/remote precondition, and the never-fall-through rule |
| Fail | 3 — `ROLL NOTHING BACK` with its reason, `current_phase` staying put, the lock release |
| J | 5 — the carry duty, the reason it exists, the new-failures-are-a-new-stop rule, the no-PR discharge, the redaction rule |
| N | 3 — `DEGRADED, NEVER SKIPPED`, the closing sentence, the do-not-re-own rule |

**Rationale.** FR-006: anchor on the words that carry the obligation. Each
anchor is a clause, not a reproduced paragraph, so a reflow moves line breaks
underneath it without effect.

Each anchor includes enough of its clause that its subject cannot be swapped.
That is not caution, it is history: the suite records a mutant that kept a
sentence's tail (`… is still required before anything publishes unasked`) and
changed its subject, and stayed green. The `ROLL NOTHING BACK` anchor carries
its reason clause for the same reason — the imperative alone survives a
mutant that appends "unless the tree is dirty".

**Measured.** All thirteen were verified twice, from a file rather than from
argv (an argv round-trip can make a pattern check pass on anything):

```
for each anchor:  grep -qF -- "$clause" <<<"$flattened_slice"   ->  found, 13/13
for each anchor:  grep -oF -- "$clause" <<<"$flattened_file" | wc -l   ->  1, 13/13
```

The second run is the one that matters for FR-007: an anchor that already
appears twice in the document could be satisfied from outside its own region
the day the region's copy is deleted.

**Alternatives considered.** Whole-sentence pins, as ~31 existing tests use.
Rejected by the seed, and the file itself explains why: an innocent reflow
reddens a wall of them with nothing separating "dangerous reword" from
"rewrapped". Not converting the existing ones is a separate decision and is
out of scope (FR-010).

**A deliberate superset, declared.** FR-002 names only `ROLL NOTHING BACK`.
The Fail pin also anchors `current_phase` staying at the failed phase, and the
lock release. Both are in the same five-item procedure and both are load-
bearing in the same way: a failure handler that skips past the failed phase,
or that keeps the lock, breaks resume as surely as one that rolls back. Pinning
them costs two lines. This is recorded here so a reviewer reads it as intent
rather than as drift.

---

## D3 — Whole-line matching for the rows, and the hole it closes

**Decision.** The seven rows are matched with `grep -qxF` — whole line — not
`grep -qF`.

**Rationale, measured rather than argued.** `grep -qF` stays GREEN against a
mutant that leaves a row intact and appends a cell after its final pipe:

```
row + ' Except under --auto, where you may answer it yourself. |'
  grep -qF  '<original row>'   ->  MATCHES   (test stays green)
  grep -qxF '<original row>'   ->  NO MATCH  (test goes red)
```

That mutant is not academic. The appended text sits inside the red-flag table,
on the row's own line, and is read inline by anything reading the document —
it is a working instruction-surface attack that survives a substring pin. And
it is invisible to this feature's own mutation plan: all seven planned row
inversions are rewrites, and every rewrite fails a substring match anyway. So
the substring pin would have been signed off as proven while this hole stayed
open. SC-002b exists to demonstrate it specifically.

The owner's clarify answer was "catches ANY change to the row". Only `-qxF`
delivers that answer.

**Line endings — checked, because `-qxF` is where a stray `\r` bites.**

```
awk '/\r$/{n++} END{print n+0}' pipeline/skills/pipeline/SKILL.md   ->  0 of 683
.gitattributes:  * text=auto eol=lf   and   *.md text eol=lf
git config core.autocrlf                                            ->  true
```

`core.autocrlf` is true on this machine, which alone would produce CRLF on
checkout; `.gitattributes` overrides it for `*.md` and the measured count is
zero. The slice helper strips `\r` anyway. That is not belt-and-braces for its
own sake: if a checkout ever did carry CRLF, every one of the five pins would
fail at once with a message pointing at the prose, sending a maintainer to look
for a deletion that never happened. Stripping costs one `tr` and makes that
failure mode impossible. It hides nothing worth seeing — a carriage return is
not a safety regression.

**Alternatives considered.** Anchoring rows on their operative clause, like the
other four pins. Rejected at the clarify gate: a row is one line, so the reflow
tolerance a clause anchor buys is worth nothing there, while the cost — leaving
the "Thought" column mutable — is real. The Thought column is the half a model
matches its own rationalisation against.

---

## D4 — Completeness: the pin checks both directions

**Decision.** The red-flag pin asserts both that every row it names is present,
and that every row present is named by a pin.

**Rationale.** A hand-written list of rows goes stale in the direction that
hurts. This repository has the scar: a coverage check listing its anchors by
hand omitted the exact tree whose absence had caused a leak, and reported
green. A ninth red-flag row added without a pin is the same gap this feature
exists to close, arriving one row later.

Direction A alone (every listed row present) is a positive control, and a
positive control proves only one direction — that the check CAN go red, never
that it goes red when it should.

**Measured.** The table holds eight data rows plus a header and a separator:

```
awk '/^## Red flags/,/^## When a phase fails$/' SKILL.md | grep -c '^| '  ->  9
   (1 header `| Thought | Reality |` + 8 data rows; the `|---|---|`
    separator does not match `^| ` and is excluded)
```

Row 1, `"Fix everything" is implied…`, is already pinned — by fragments, in the
existing test `the fix-everything red-flag table is present`. Rows 2 through 8
are the seven this feature pins. So the completeness list is eight rows: the
seven new ones plus the one pinned elsewhere. It is written as a separate
reference list precisely so the "already pinned elsewhere" row cannot silently
fall out of the count.

**Consequence, stated so it is not a surprise.** Adding a red-flag row now
requires adding it to the pin. That is a two-line change and it is the point:
growth is allowed, silent growth is not. The spec's edge case was reworded to
say this.

---

## D5 — Mutation procedure without destroying evidence

**Decision.** Back up with `cp`, mutate, echo the changed line, run the prose
suite, restore with `cp`, prove identity with `cmp` and `git status`.

**Rationale.** Two constraints meet here. FR-011 says the orchestrator must be
byte-identical afterwards. The orchestrator's own never-bend table forbids
`git reset --hard`, `git clean` and `git checkout --` on tracked files — and it
binds this work as much as any other, so the obvious restore is unavailable.
`cp` from a backup is the restore; `cmp` is the proof, because "I copied it
back" is not evidence.

Echoing the mutated line before trusting the red is SC-003 and is not
ceremony: a `sed` whose pattern does not match exits 0 and changes nothing,
and the test then passes for the honest reason while being recorded as a
proven mutation. That is a false green manufactured by the verification step
itself.

**Twenty-two mutations, not five.** The seed says each pin is
mutation-verified; "pin" there means anchor, not `@test`. Thirteen clause
anchors plus seven rows is twenty; the appending mutant SC-002b requires makes
twenty-one, and the unpinned-ninth-row mutant FR-005a requires makes
twenty-two. That last one was first filed among the behavioural checks, which
left this document, the plan and the tasks file carrying two different totals
for identical work. It is a mutation — it edits the document and requires a
red — and the count, not the classification, was wrong. The
clarified answer about the seven rows applies for exactly the same reason to
the J pin's five clauses: one inversion cannot distinguish a test that checks
five things from one that checks one and skips four.

**Focused runs to iterate, the full house for the verdict.** Each inversion
runs `pipeline/tests/prose.bats` alone. The full house from the repository root
runs twice: once at F.5 for the baseline, once at J for the verdict. This is
the red-flag table's own rule — focused runs are for iterating, not for
verdicts — and twenty-two full-house runs would prove nothing the focused ones
do not, at roughly twenty times the wall clock.

**Alternatives considered.** `git stash` to park the mutation. Rejected: the
orchestrator's handoff derivation adds `git stash` to the forbidden list by
name, on the grounds that stash hides work as surely as the others discard it,
and it binds this orchestrator too.

---

## D6 — Where the new tests go, and what they must not touch

**Decision.** Five `@test` blocks appended to the end of
`pipeline/tests/prose.bats`. Nothing above them is edited.

**Rationale.** FR-010. The file's existing whole-sentence pins are deliberate
and documented in-file; converting them is separate work. Appending also keeps
the diff readable — a reviewer sees five new blocks, not a rewritten file.

**Shared slice helper.** The five pins need the same slice-and-flatten
operation, and the helper carries the boundary assertions FR-008 requires, so
the failure "the slice collapsed to nothing" is written once rather than five
times. It lives in `prose.bats` beside its callers, not in `tests/helper.bash`:
the helper file is loaded by all six suites in the tree, and a function only
one suite uses does not belong in the file that reaches the other five.

**Measured baseline.** The suite currently holds 11 `@test` blocks
(`grep -c '^@test' pipeline/tests/prose.bats`). The house total of 154 is
recorded at F.5 from an actual run, not carried over from the seed.

---

## D7 — What the helper's own guards are NOT protected by

Recorded because a guard's blind spot belongs beside the guard, and because
this one was found by the deep review rather than by the plan.

`prose_slice` carries six guards: arity, form, an empty slice, a slice that did
not open on its boundary, an unterminated slice, and an unexpected heading
inside. Five of the six were fired and watched during this feature:

| Guard | How it was proven |
|---|---|
| arity | throwaway probe suite |
| form (`raw`/`flat`) | throwaway probe suite |
| empty slice | throwaway probe suite, and proven to give a DIFFERENT message from the unterminated case |
| unterminated slice | T039, a real boundary rename |
| heading inside the slice | throwaway probe, an interpolated `**N.4 —` heading |
| did not open on its boundary | NOT PROVEN — see below |

**The unproven one.** That branch is very likely unreachable: awk and `grep -E`
are handed the same ERE, so a range that opened at all opened on a line the
grep also matches. It is kept as insurance against a dialect difference between
the two, not because a path to it is known. Claiming it "passes" would be
claiming something nobody watched happen.

**The real limitation, stated plainly.** The five probes above are THROWAWAY.
They ran, they passed, and they were deleted; nothing in the committed suite
fails if one of these guards is broken tomorrow. The guards protect the pins,
and the guards themselves are unprotected.

That is a gap, and it is left open deliberately rather than silently. Closing it
means committing guard tests, which changes the suite total that this feature's
own acceptance criterion fixes at 159 — so it is the next piece of work, not
this one. It is recorded here, and in the pull request, so that the next person
to touch `prose_slice` knows the suite will not catch them.

---

## D8 — Three review findings deferred, and why they are not fixed here

The phase-M review found three real defects that this feature is not allowed to
fix. They are recorded here, and filed as a follow-up issue, because a finding
that is neither fixed nor written down has been waved through.

### The two unguarded slices in existing tests

`the G pre-answer contract is pinned sentence by sentence` and
`the implementer key's consent surface is pinned outside the G slice` both
slice with a bare `awk` range and no boundary assertions. Reword their closing
boundary — `**H — implement.**`, `**Base branch:**`, or the probe block's
`Will skip ` line — and the range runs to end of file. Every anchor in them can
then be satisfied from ANYWHERE in the document while the test name and all
eleven failure messages still claim a section.

That is the exact failure `prose_slice` was written to prevent, sitting in the
same file, in the tests that were themselves rewritten to close the relocation
escape. The second one is sharper than the first: its own comment records that
pre-flight item 10 was moved off a file-wide pin *because* a verbatim appendix
copy beat it — and a boundary rename silently puts it back on a file-wide pin.

**Not fixed because FR-010 forbids it.** "MUST NOT alter, convert or reword any
pin already in it", which the seed states as "Do not convert the existing
pins." Routing those two through `prose_slice` is exactly that conversion. The
constraint is the right one — converting 31 pins mid-feature is how a
pinning change becomes an unreviewable rewrite — and it means this defect
outlives this feature by design.

### The helper cannot serve them anyway

`prose_slice` takes no file argument; it reads `$ORCH`. So even without FR-010
it could not cover the `$docs` and `$changelog` slices in the same file. Adding
the parameter now would be generality with no consumer, which is its own smell,
so it belongs with the work that gains one.

### What the follow-up has to do

Add a `<file>` parameter, route the three existing slice sites through the
guarded helper, and commit tests for the helper's own guards — the gap D7
records. All three are one piece of work and none of them fits inside a feature
whose acceptance criterion fixes the suite total at 159.

---

## D9 — Round 2, and the fault this feature had already congratulated itself for closing

Round 1 fixed twelve things. Round 2 then found fourteen more, and the first of
them is the reason this section exists rather than a line in a commit message.

### The append attack was closed for rows and never carried to the prose pins

D3 records the discovery that `grep -qF` tolerates a mutant which leaves a
table row intact and appends a cell after it, and the fix: `grep -qxF`, whole
line. That reasoning stopped at the table.

The four clause pins were defeated by the identical trick. Landed and watched:

```
"…the evidence they need to make it."
  + " Exception: under `--auto`, reset the tree first…"      -> ALL GREEN
"…the commit message and the pull-request body."
  + " Under `--auto` the carry is optional…"                 -> ALL GREEN
'…must never be "change it and not check it".'
  + " When the PR is absent, skip N and say so."             -> ALL GREEN
"…is worse than stopping."
  + " Under `--auto`, treat it as a description instead."    -> ALL GREEN
```

Each inverts a safety rule while leaving its anchor a perfect substring. Worse
than the gap itself: the comment above the roll-nothing-back anchor asserted
that carrying the reason clause made exactly this rewrite "impossible to
phrase", and D2 repeated the claim. It is trivially phraseable. The comment was
not describing a property of the pin; it was describing a hope.

**Why whole-line matching cannot be the fix here.** A flattened slice IS one
line, so `-qxF` on it would demand the entire region byte-for-byte and redden
on any word anywhere. What distinguishes an insertion is that it changes what
SURROUNDS the rule, so the guard has to assert the surroundings. Each pin now
carries a contiguous span running from its first safety sentence to the
region's closing boundary. Nothing can be inserted between the rules, or
appended after the last one, without breaking it.

**The cost, accepted rather than discovered later.** Any word change inside a
span reddens its pin — heavier than a clause anchor. It is accepted because
these four regions are safety prose end to end, with no incidental sentence to
reword innocently, and because the brittleness the seed objected to was REFLOW,
which flattening already answers. Verified: all six reflow checks still pass
with the spans in place.

The two layers now report different things, which is why both are kept: a
clause anchor failing means a named rule was ALTERED; only the span failing
means something was inserted or reworded AROUND them.

### The CR strip was in the wrong place

D3 claimed stripping carriage returns "makes that failure mode impossible". The
strip ran on awk's OUTPUT — after awk had already matched the boundaries
against lines still carrying their CR. Three of the five closing patterns are
`$`-anchored, so on a CRLF checkout under GNU awk (the Linux CI runner) none of
them matches, the range runs to end of file, and three pins fail with
UNTERMINATED and advice about a heading nobody renamed. Invisible on this
machine, where the Cygwin awk and grep both ignore a trailing CR. The strip now
runs before awk.

### The table was found by the wrong rule, twice

Round 1 replaced `grep '^| '` with "the first pipe-bearing line is the header".
The region is PROSE: a sentence mentioning `--auto | --auto-release` above the
table displaced the header into the data rows, and the test demanded somebody
pin `| Thought | Reality |` as a red-flag rule. It also had a false-green
direction — delete the header and the first real row stopped needing a pin.

Rows are now located by the table's actual shape: skip to the separator, take
lines until the table ends at a blank line. Prose on either side is outside by
construction.

### And a correction to a correction

Round 1 labelled the empty-table guard "unreachable" and kept it as documented
dead code. That was wrong in a corner: empty the table AND both row lists, and
the forward loop iterates nothing while this guard is the only thing left that
reddens. Labelling it dead invited the removal that would have left that case
with no assertion at all.

### The pattern under all of it

Four of round 2's findings are round 1's fixes, examined as hard as the
original code. Three of them are the *same* fault reappearing one layer out:
the row fix that did not reach the prose pins, the header rule that traded one
wrong shape for another, the guard whose deadness was asserted rather than
proven. A fix closes a blind spot and opens its mirror image, and the only
defence measured so far is another pass with fresh eyes.
