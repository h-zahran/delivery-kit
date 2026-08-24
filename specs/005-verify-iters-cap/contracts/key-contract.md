# Key contract — `maxVerifyIters` and the J paragraph

## The documentation sites (exact strings)

1. Orchestrator Configuration table (`pipeline/skills/pipeline/SKILL.md`), appended row:

   ```
   | `maxVerifyIters` | 5 | Phase J cap |
   ```

2. `pipeline/docs/configuration.md` JSON block, appended entry (after `implementer`):

   ```
   "maxVerifyIters": 5
   ```

3. `pipeline/docs/configuration.md` key table, appended row:

   ```
   | `maxVerifyIters` | Verification fix-loop cap; a breach stops and asks, and a breach waved through is recorded in the commit message and the pull request. |
   ```

Identity binds the key name, the default (`5`, rendered `5` in the
orchestrator's Default column and `5` in the JSON block — a NUMBER, not
`null`, because unlike the command keys this one has a real default the
document states), and the phase it caps. Description prose follows each
table's own style (research R1).

Note the asymmetry with the preceding phase deliberately: `implementer` is
`unset`/`null` because "work it out" is meaningless for it; `maxVerifyIters` is
`5` in both files because the default is real and the seed states it. Two keys,
two conventions, both correct — do not "harmonise" them.

## The J paragraph (verbatim, from the plan of record)

The final sentence of the J paragraph is REPLACED by:

> Loop until clean against baseline, at most `maxVerifyIters` iterations; a cap
> breach is a conditional stop — show the failures that survived and ask whether
> to continue; a hard failure still stops the run outright.

> **AMENDED at H.5 convergence (2026-08-24)**: the seed's wording ended at
> "a conditional stop". Convergence found that FR-003 requires a breach to SHOW
> the remaining failures, and that J left it to convention while C states it
> outright — so the clause "— show the failures that survived and ask whether to
> continue" was INSERTED into the seed's sentence. This is an insertion into a
> plan-of-record quotation and is recorded here rather than made quietly. The
> shipped text is above; `quickstart.md` §3 was updated to match.

The owner's clarify answer is added immediately after it, as its own sentence:

> A breach the owner waves through carries a duty the other caps do not: record
> the surviving failures in the state file, and carry them into the commit
> message and the pull-request body. J is the last full-suite check before code
> leaves the machine, and a red that reaches a reviewer as green is the one
> outcome this gate exists to prevent.

The J paragraph's first four sentences are byte-identical. This is the ONE
reworded sentence, and research R2 records both justifications for it.

## The changelog entry (FR-004, STRICT surface)

One Added entry under the existing `## [Unreleased]` heading: the key, its
default of 5, that a breach is a conditional stop, and that a breach waved
through is recorded into the commit and the pull request. No version stamp, no
banned spellings.

## What must NOT move

- Suite counts: house `1..121`, prose `1..11` — growth exactly zero. (These are
  the counts the PREVIOUS phase moved to, on the owner's instruction; they are
  the correct baseline for this phase and any movement here is a finding.)
- `handoff/**` — untouched.
- Every pinned string the prose suite and the portability gates already guard,
  including the `implementer` consent surface the previous phase pinned.
- The J paragraph's first four sentences.

## AMENDED at I — deep review (2026-08-24): the redaction clause

The security lens found that the duty sentence above opens a NEW outbound path
the product's redaction discipline did not reach. Redaction is stated exactly
once in the orchestrator (the handoff package: "where a source holds a
credential, an endpoint or a token, the package carries the fact and its
location, never the value"), and it is bound to an artefact that stays on the
machine or goes to one chosen implementer. The J duty carries raw `testCommand`
failure output into a commit message and a pull-request body — text that leaves
the machine — and under `--auto` the commit and push gates are collapsed, so no
human reads that body before it is published. Test output routinely carries
absolute paths with usernames, hostnames, environment values echoed in assertion
diffs, and tokens inside HTTP error bodies.

A THIRD paragraph is therefore ADDED to the J slice, after the duty paragraph.
It is an ADDITION, not a reword: both pinned sentences above are byte-identical
afterwards, and FR-005 is not engaged because no existing sentence was made
false. The shipped text is:

> Redaction binds that carry exactly as it binds the handoff package: where a
> surviving failure's output holds a credential, an endpoint or a token, record
> the fact and its location, never the value. A commit message and a
> pull-request body leave the machine, and under `--auto` no gate stands between
> them and whoever can read the repository.

**EXTENDED at M round 1, then CORRECTED at M round 2 (2026-08-24)**: round 1
added a degraded-path carve-out to the END of this paragraph, because the duty
stated the carry into a pull-request body UNCONDITIONALLY while L names three
degradations where no pull request exists — no remote (L stops after K), a
non-GitHub remote, or no `gh` (L pushes and prints a comparison URL). A literal
executor would block looking for a body that will never exist, or invent one.
Round 2 found the carve-out FILED UNDER THE WRONG TOPIC SENTENCE: the
unconditional instruction lives in the DUTY paragraph, while this paragraph's
opener scopes it to credential handling, so an executor reading the duty never
reaches the exception. The two sentences were therefore MOVED into the duty
paragraph, and this paragraph is restored to its phase-I form — the quote above
is once again the T010 text exactly. Round 2 also caught an overstatement in the
moved wording: on the no-remote path the commit never leaves the machine at all,
so "the sole OUTBOUND carrier" was false; it now reads "the commit message
carries it alone". Moved and corrected on the record, never silently.

It extends an existing, already-stated discipline by name rather than inventing
a second one. Three constraints were checked before it was written and measured
after: it contains no occurrence of `maxVerifyIters` (quickstart §2 pins that
count at `2` — measured `2` after), it reproduces neither §3 flattened grep
string (measured `1`, `1`, `1` and `0` after), and it adds no `^**` heading line
that would move any `prose.bats` slice. Prose + portability measured `1..32`,
32 ok, 0 not ok, exit 0 after the addition.

Recorded here rather than made quietly, exactly as H.5's insertion was.


## AMENDED at M round 2 (2026-08-24): the record's address, and the carve-out's home

Two ADDITIONS to the duty paragraph. Neither reworded a pinned sentence: the
duty's own first two sentences and the J cap sentence are byte-identical, and
FR-005 is not engaged because no existing sentence was made false.

The shipped duty paragraph, in full and current:

> A breach the owner waves through carries a duty the other caps do not:
> record the surviving failures in the state file, and carry them into the
> commit message and the pull-request body. J is the last full-suite check
> before code leaves the machine, and a red that reaches a reviewer as green
> is the one outcome this gate exists to prevent. The record lands under
> `gates.J`, beside the answer that waved it through — the same key every
> answered stop already writes. That answer covers the failures it names and
> no others: a later breach on a DIFFERENT set of failures is a new stop,
> asked afresh. The never-re-ask rule suppresses a repeat of the same
> question, never a first sight of a new one, and a run that inherits an
> answer for failures no human has seen has waved through exactly what this
> duty exists to surface. Where a degradation named at L leaves no pull
> request to carry — no remote, a non-GitHub remote, no `gh` — the commit
> message carries it alone and the duty is discharged there. The duty names
> three destinations because three usually exist; it never waits on one that
> cannot.

**Why `gates.J` was adopted, stated precisely so the record is not misread.**
This does NOT overturn the contract lens's phase-I ruling. That ruling stands:
FR-003a asks for a STORE and the shipped sentence gives it one, and the
orchestrator names a store without a field in three other places. What changed is
that phase M round 1 SHIPPED A READER. T014 added a sentence to phase N ordering
it to treat a failure the owner accepted at J's cap breach as inherited rather
than re-owned — and nothing findable told N which failures those are. A reader
pointed at an address that does not exist is a NEW defect introduced by that fix,
not the old deferral resurfacing, and it is fixed here rather than deferred
again. `gates` needs no other change: it is already in the ground rules' list of
hand-written state keys, and `gates.constitution` is direct precedent for a
CONDITIONAL STOP — not a table gate — recording its answer there. A recorded gate
answer is also what suppresses a re-ask, so the same sentence closes the
resume-into-J question that round 1 raised separately.

Constraints checked before writing and MEASURED after: no occurrence of the
key's name anywhere in either addition (quickstart section 2's count stays `2` —
measured `2`), neither section 3 grep string reproduced, and no `^**` heading
line added. Quickstart section 3 gained a grep for the new sentence, because a
shipped sentence with no check is the relocation hole phase I already found once.
This makes NINE unpinned sites, not eight; research R3 and every copy of the
count were updated in the same breath.


**EXTENDED again at M round 3 (2026-08-24)**: round 3 found that `gates.J`
combined with the ground rule "a re-entered gate whose answer is already
recorded in `gates` never re-asks" would AUTO-WAVE a different failure set. The
recorded answer was about one specific set of surviving failures, but the
suppression is keyed to the gate, not to the set the answer covered — so a run
resumed into J after new commits, breaching on reds no human had seen, would find
`gates.J` populated and treat the stop as answered. That is a safety regression
introduced by round 2's own fix, and it is fixed here rather than queued. Three
sentences were added scoping the answer to the failures it names. The quote above
is the CURRENT shipped paragraph, re-extracted from `SKILL.md` and byte-compared
after the edit, not retyped.