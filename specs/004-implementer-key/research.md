# Research: pre-answer the implementer gate — the loop closes

## R1 — What "character-identical across the two files" binds

- **Decision**: the key NAME (`implementer`), the legal value set
  (`claude`, `handoff`), and the default (unset — rendered `unset` in
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
