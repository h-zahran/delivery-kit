# Research: a cap for the J loop

Four decisions. Each records what was chosen, why, and what was rejected.

## R1 — Placement of the key: append, never insert

- **Decision**: the key row lands at the END of the orchestrator's
  Configuration table and at the END of `pipeline/docs/configuration.md`'s JSON
  block and key table — after `implementer` in all three — never beside the
  other caps.
- **Rationale**: appending is the standing lesson of P2 and P4. Inserting
  `maxVerifyIters` between `maxReviewRounds` and `maxParallelAgents` would read
  better, because the caps would then sit together — but an insertion moves
  every row beneath it, and moved rows are how this project has broken pinned
  strings before. Readability is worth less than a table that cannot silently
  shift.
- **Alternatives considered**: grouping it with the other caps (rejected, as
  above — and the cost is only that a reader scanning for caps finds four in
  three places rather than four in one); alphabetical ordering (rejected: no
  table in either file is alphabetical, so it would be a new convention
  introduced by a phase that is not about conventions).

## R2 — The J paragraph: one sentence is REPLACED, and that is sanctioned

- **Decision**: the final sentence of the J paragraph — "Loop until clean
  against baseline or a hard failure stops the run." — is replaced by the
  seed's exact wording: "Loop until clean against baseline, at most
  `maxVerifyIters` iterations; a cap breach is a conditional stop; a hard
  failure still stops the run outright." The owner's clarify answer is then
  added as its own sentence after it, not folded into the seed's.
- **Rationale**: this is a REWORD, and the constraint says add near, never
  reword. It is sanctioned twice over. First, the seed itself quotes the
  replacement text, so the plan of record asks for it. Second, and
  independently, adding a cap makes the old sentence FALSE — the loop no
  longer runs until clean; it runs at most N and then stops to ask. FR-005 and
  the standard the previous phase settled on both say a sentence this change
  makes false is fixed, not preserved. Recorded here so no later reviewer has
  to rediscover which of the two justifications applies: both do.
- **Alternatives considered**: appending the cap sentence and leaving the old
  one standing (REJECTED — that is precisely the defect four review rounds
  chased last phase: two sentences in one paragraph disagreeing about whether
  a loop is bounded, with the older and shorter one reading as authoritative);
  rewording the old sentence in place rather than replacing it (rejected: the
  seed specifies the replacement verbatim, and matching it exactly is cheaper
  to verify than a paraphrase).
- **No other sentence moves.** The J paragraph's first four sentences —
  analyzer, classification against `test_baseline`, pre-existing versus new,
  fan-out — are untouched and remain byte-identical.

## R3 — No test this phase, and the debt this creates, stated plainly

- **Decision**: NO new test and NO assertion additions. The suite stays
  `1..121` and prose stays `1..11`, per the seed's own acceptance criteria and
  `main-plan.md`'s Global Constraints.
- **What guards the change**: NOTHING automated does. The unpinned surface is
  EIGHT things: the three site strings (orchestrator table row, JSON entry,
  configuration key row), the reworded J sentence, and the sentence carrying
  the owner's record-the-red duty. The changelog entry makes a sixth if you
  count it, and it should be counted. **Phase I's mutation testing added two
  more, and the count above was SIX until it did.** Site seven is the
  conditional-stops enumeration `SKILL.md` carries as "a cap breach in C, F, J
  or M" — T007 wrote J into it, and reverting that revert passes the whole
  `1..121` suite and every quickstart check. Site eight is the redaction
  paragraph phase I added to the J slice, recorded as an amendment in
  `contracts/key-contract.md`. Both are now covered MANUALLY by quickstart §6
  and §3 respectively, which is cover, not a pin. One correction to the review
  that found them: it reported the changelog entry as absent from this
  enumeration too, and it was not — the entry is site six above and always
  was. What was true of the changelog is the separate, real point that NO
  command anywhere read it, which quickstart §6 now does. The existing
  prose suite pins the gate rows, the never-bend table, the G slice and the
  `implementer` consent surface — none of which this change touches.
- **The debt this creates is NEW, and is NOT the debt P4 paid.** `main-plan.md`
  tells P5 and P6 that the prose-pin debt is PAID and must not be re-queued:
  that instruction is about P3's and P4's quoted sentences, and it is correct.
  This phase adds its own unpinned surface — eight sites, enumerated above — and
  that is a fresh
  item, recorded here so it cannot be waved away by pointing at the paid one.
- **The technique is known and costs nothing in count.** P4 proved it twice:
  a fixed-string check appended inside an existing `@test` moves no number.
  What P4 also proved is that hosting a contract inside a test named for
  something else pays for a frozen count in test-name accuracy — so the
  honest spend here is a NEW test named for loop caps, which WOULD move the
  count to `1..12` / `1..122` and would breach the seed's acceptance criteria.
- **Alternatives considered**: spending it now inside the existing
  "consent surface outside the G slice" test (REJECTED — `maxVerifyIters` is
  not a consent key and does not belong in a test named for one; this is the
  exact mistake a P4 reviewer caught and the project corrected); spending it
  now in a new test (rejected THIS PHASE only, because the seed and the plan of
  record both freeze the count — it is the owner's call to override, as they
  did last phase, and it is surfaced rather than assumed).
- **OWNER RULING (2026-08-24)**: surfaced at the end of phase D and ruled —
  RECORD, do not spend. The seed's acceptance criteria freeze the count and
  the owner chose to respect them. The eight unpinned sites are named above so
  a later phase can spend this without rediscovering them, and the option of
  hiding them inside the existing consent test was refused outright rather
  than weighed — that trade was already made once and corrected.

## R4 — The owner's clarify answer is a new obligation, not a restatement

- **Decision**: "proceed anyway" at a J cap breach records the surviving
  failures in three places — the run's state file, the commit message, and the
  pull-request body. This is written as its own sentence in the J paragraph and
  carried into the configuration page and the changelog entry.
- **Rationale**: the seed asked for "the same shape as F and M". The owner's
  answer deliberately makes J's cap differ in exactly one respect, and the
  reason is structural rather than stylistic: C, F and M all breach BEFORE the
  commit gate has anything to commit, whereas J is the last full-suite check
  before code leaves the machine. A waved-through red at J is the only cap
  breach that can reach a reviewer's screen as green.
- **Alternatives considered**: recording only in the state file (rejected: a
  reviewer reads the pull request, not `.delivery-kit/`); refusing to let a J
  breach be waved through at all (rejected by the owner, and rightly — it
  strands a run on a genuinely unfixable flake); saying nothing and treating J
  exactly like F and M (rejected by the owner).
- **Consequence to state honestly**: this makes the four capped loops NOT
  identical, which touches SC-004's wording. SC-004 asks that a reader who
  understands one cap understands all four — that still holds: the shape is
  identical and J carries one documented addition. The addition is named in
  the J paragraph itself so the difference is discoverable where it applies.
