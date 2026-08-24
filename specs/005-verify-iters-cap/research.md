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
- **What guards the change**: NOTHING automated does. **RE-ENUMERATED FROM
  SCRATCH at M round 3** — not incremented, because this count had already
  drifted twice and arithmetic is how it drifted. The basis is unchanged: one
  site per distinct shipped prose unit that could be deleted or inverted on its
  own. Read off the run's full diff against `main`, the surface is **TWELVE**:

  1. the orchestrator configuration-table row;
  2. the `configuration.md` JSON entry;
  3. the `configuration.md` key-table row;
  4. the `CHANGELOG.md` Added entry;
  5. J's reworded cap sentence;
  6. the conditional-stops enumeration, `C, F, J or M` (T007);
  7. the duty sentence pair — the record, and why J alone carries it;
  8. the redaction paragraph (T010, phase I);
  9. the `gates.J` address sentence (T019, M round 2);
  10. the answer-scoping sentences, which stop a recorded answer covering a
      later breach on different failures (M round 3);
  11. the degraded-path carve-out and the three-destinations sentence
      (T015, relocated into the duty paragraph by T020);
  12. phase N's inherited-classification paragraph (T014, M round 1).

  The count read six at phase D, eight at phase I, and nine at M round 2. Each
  of those was correct for the prose that existed when it was written; none was
  wrong arithmetic. What was wrong was reaching for arithmetic at all while the
  prose was still moving — the same class of slip this project has now met four
  times. Twelve is an enumeration, and the list above is the thing to re-read
  rather than the number.

  **All twelve now carry MANUAL cover** in `quickstart.md`: section 1 for sites
  1-3, section 3 for 5 and 7-11 (sliced to the J region, so a relocation cannot
  pass), section 6 for 4 and 6, and section 7 for 12 (sliced to N). Manual cover
  is cover, NOT a pin: nothing runs it but a human. The existing prose suite pins
  the gate rows, the never-bend table, the G slice and the `implementer` consent
  surface — none of which this change touches.
- **The debt this creates is NEW, and is NOT the debt P4 paid.** `main-plan.md`
  tells P5 and P6 that the prose-pin debt is PAID and must not be re-queued:
  that instruction is about P3's and P4's quoted sentences, and it is correct.
  This phase adds its own unpinned surface — twelve sites, enumerated above — and
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
  the owner chose to respect them. The twelve unpinned sites are named above so
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
  reason is structural rather than stylistic: J is the last FULL-SUITE check
  before code leaves the machine, and a waved-through red there is a red the
  reviewer reads as a green suite.
- **CORRECTED at M round 1 (2026-08-24)**: this rationale previously read
  "C, F and M all breach BEFORE the commit gate has anything to commit". That
  is FALSE and the first round of pull-request review caught it. The phase order
  is K (commit), L (push and open the pull request), then M (pull-request
  review) — so M breaches AFTER the commit exists and after the branch and the
  pull request are already public. Only C and F breach before a commit exists.
  The correction does not weaken the owner's ruling; it narrows the ground it
  stands on. J's claim is not "the only breach after which code is public" — it
  is "the last FULL-SUITE check", and a surviving red there is a red a reviewer
  reads as a green suite. M's exposure is real and different: a waved-through M
  breach leaves unfixed REVIEW FINDINGS on a published pull request, and M
  carries no record-the-red duty of its own. That is a NEW owner-queue item
  raised by this review, recorded rather than fixed — extending the duty to M
  is a change to phase M, outside this run's one-key scope. Corrected on the
  record, never silently, per the standard this file already sets.
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
