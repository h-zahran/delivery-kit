# Research: pre-answer the implementer gate — the loop closes

## R1 — What "character-identical across the two files" binds

- **Decision**: the key NAME (`implementer`), the legal value set
  (`claude`, `handoff` — widened to include `ask` at phase M round 4,
  owner-ordered), and the default (unset — rendered `unset` in
  the orchestrator's Meaning-table column and `null` in the JSON block,
  the two files' existing convention) are identical; the surrounding
  description prose follows each table's own style. The exact strings
  per site are pinned in contracts/key-contract.md.
- **Rationale**: the seed says "names and defaults character-identical
  across the two files", and the files' EXISTING keys already render
  "unset" as `null` in JSON (`verifyCommand`, `releaseCommand`) — the
  precedent the seed's own author shipped. Binding description prose
  would make the two audiences read the same sentence twice.
- **Alternatives considered**: byte-identical full rows (rejected: the
  two tables have different column sets — Meaning vs What-it-does —
  so full-row identity is impossible without restructuring a table,
  which "add near, never reword" forbids).

## R2 — Placement of the new rows and sentences

- **Decision**: the key row lands at the END of each table (after
  `devCommand` in the orchestrator's Configuration table and the JSON
  block; after the last row of each key/flags table) — append, never
  insert. The quoted G sentence pair lands directly after "`--auto`
  never collapses this gate: it spends money." and before the
  seven-part list's intro — the sentences modify WHEN G stops, so they
  sit with the gate's stop semantics, not with the package contract.
  The configuration.md paragraph lands after the constitution-offer
  paragraph in "The spec tool" section's vicinity — its own short
  section "The implementer key" after "The state directory".
- **Rationale**: appending is the P2 lesson (inserting renumbers,
  renumbering is rewording); the sentence pair's placement keeps the
  G paragraph's reading order: when it stops → what the package is →
  how the park works.
- **Alternatives considered**: inserting the row alphabetically
  (rejected: neither table is alphabetical); placing the sentences
  after the park paragraph (rejected: a reader would learn the park
  before learning the gate might not stop at all).
- **SUPERSEDED at H.7 (2026-08-23)**: the docs section did NOT ship
  after "The state directory". H.7 relocated it to sit after "Base
  branch", which is the page's per-key pattern. The Decision bullet
  above records the intent; the shipped placement is after "Base
  branch". Raised by the phase I contract and tests lenses (M2).

## R3 — No test this phase; what guards the change

- **Decision**: NO new test and NO assertion additions — the suite
  stays `1..119` and prose stays `1..9` by the seed's own acceptance
  criteria. What guards the change: the existing prose test 9 pins the
  whole G slice's anchor structure and its byte-identity sentences (a
  reword would go red); the Gates-table test pins `| Implementer | G |`;
  the STRICT vocabulary and version-agreement gates cover the two
  STRICT files; and quickstart §2's extract-and-diff is the manual
  identity check. A prose pin for the new quoted sentence pair is
  RECORDED TEST DEBT for a later phase (joins the standing queue).
- **Rationale**: the plan of record freezes the counts this phase; the
  quoted pair sits inside the G slice, where structural guards already
  constrain drift even without a dedicated pin.
- **Alternatives considered**: adding the pin inside existing test 9
  (rejected THIS phase: the seed's acceptance criteria pin prose at
  `1..9 ok` with "all pinned strings intact" — an assertion addition is
  legal by count but the seed names no new pin, and P5/P6 own the
  test-debt spend; recorded, not spent).
- **AMENDED at phase I (2026-08-23)**: the recorded debt above named ONE
  item (the quoted-pair pin). The phase I tests lens measured the real
  unpinned surface at SEVEN, and mutation-tested two of them on scratch
  copies: deleting the quoted pair stays green, and deleting the WHOLE
  new G paragraph stays green (it adds no heading-shaped line, so test
  9's structure check is indifferent to it). The full debt list is now:
  (1) the quoted G sentence pair; (2) the four site row strings;
  (3) the Gates exception sentence; (4) pre-flight decision item 10;
  (5) the configuration.md "The implementer key" section; (6) the
  changelog bullet; (7) the JSON block's parseability with
  `implementer` null — checked by NOTHING in any suite. Items 3-6 are
  H.7's own additions and were never enrolled. Phase I's additions
  (the pre-flight Implementer probe line and paragraph, the Gates
  floor paragraph, the `gates`-authoritative sentence, the docs and
  changelog floor sentences) join the same queue, unpinned. Still
  RECORDED, NOT SPENT: the counts stay frozen this phase.
- **EXTENDED at phase M rounds 1-2 (2026-08-23)**: the list above was written
  at phase I and so cannot name what the two review rounds then added. Also
  unpinned: the reworded `--auto` flags row, G's reworded lead, pre-flight
  item 9's reworded clause, the probe block's reworded render instruction,
  the resolution-time enum check, the `gates.G`
  authority-and-re-entry paragraph, the rewritten Gates section, and the
  configuration page's range paragraph, disclosure paragraph and
  constitution-consequence paragraph. A round-2 reviewer measured the cost
  with live mutants on scratch copies, positive control fired first:
  inverting the G pre-answer sentence to "G STILL STOPS AND ASKS" and
  restoring the refuted "anything but" trigger BOTH leave the suite at
  `1..30` green. The technique for spending this debt at ZERO count
  movement is known and precedented twice in PR #16 — one fixed-string
  check appended inside prose test 9, against the whitespace-flattened G
  slice.
- **SPENT at phase M round 4, owner-ordered (2026-08-23)**: the owner
  overrode the review cap with "fix everything, no deferred", so this
  debt is no longer recorded — it is paid. The spend was made TWICE: the
  first shape put six consent sentences inside test 9 to keep the count
  frozen, and a round-4 reviewer showed that hid the consent contract in
  a test named for the handoff package — paying for a frozen count in
  name accuracy. As shipped there are TWO new tests: `the G pre-answer
  contract is pinned sentence by sentence` and `the implementer key's
  consent surface is pinned outside the G slice`; the `--auto` row and
  the `--auto-release` assurance stayed in test 6, where they belong.
  Prose `1..9` -> `1..11`, house `1..119` -> `1..121`; SC-002 and SC-003
  both carry the override, as do `plan.md`, `main-plan.md`, the contract
  and `quickstart.md`. Mutation-verified on a scratch copy with a positive control
  fired first: both mutants this record had measured as LIVE GREEN now
  go RED, plus two new ones, and the restored baseline is green. The
  hazard this list named — "a future edit can delete the entire consent
  contract from the G section and the suite will still report 1..9" — is
  closed by measurement, not by assertion.
- **SCOPE OF THAT CLAIM, stated honestly (phase M round 4)**: a reviewer
  ran 33 mutations and split the claim in two. "The named DELETION
  hazard is closed by measurement" — TRUE, verified at three
  granularities. "The consent surface is guarded by measurement" — was
  OVERSTATED: the first spend was deletion-shaped, and sixteen INVERSIONS
  survived it, including a document asserting that the key collapses the
  release gate and that illegal values are silently coerced. Fourteen of
  those were pin-cuts and are now fixed and re-verified RED, along with a
  relocation attack the sliced pins now catch. What remains uncatchable
  by grep pinning is prose ADDED beside a pin that contradicts it; a
  denylist naming that target would defeat itself, so the limit is
  recorded here instead. `prose.bats`'s own header says it: regression
  guards, not proofs.

## R4 — The field test (SC-004) is the run, not a file

- **Decision**: this run answers G with "handoff" (the owner's typed
  answer at the live gate — the key this feature ADDS cannot pre-answer
  the run that adds it). The park writes the package per the P3
  contract; the owner hands it to a cheap model; `--resume` consumes
  the report per the park paragraph. Evidence lands in tasks.md
  Completion notes: the package path, the park's state-file writes, the
  external report verbatim, and the resume's verification outputs.
- **Rationale**: P4's seed exists to field-test P3's machinery
  end-to-end; the pre-answer key closes the loop for FUTURE runs.
- **Alternatives considered**: none — this is the plan of record's
  stated purpose for the phase.
