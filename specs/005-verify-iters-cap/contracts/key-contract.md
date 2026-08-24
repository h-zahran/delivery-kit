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

It extends an existing, already-stated discipline by name rather than inventing
a second one. Three constraints were checked before it was written and measured
after: it contains no occurrence of `maxVerifyIters` (quickstart §2 pins that
count at `2` — measured `2` after), it reproduces neither §3 flattened grep
string (measured `1`, `1`, `1` and `0` after), and it adds no `^**` heading line
that would move any `prose.bats` slice. Prose + portability measured `1..32`,
32 ok, 0 not ok, exit 0 after the addition.

Recorded here rather than made quietly, exactly as H.5's insertion was.
