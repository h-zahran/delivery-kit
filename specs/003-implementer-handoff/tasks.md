# Tasks: the implementer handoff package, upgraded

**Input**: Design documents from `/specs/003-implementer-handoff/`

**Prerequisites**: plan.md, spec.md, research.md, contracts/package-contract.md, quickstart.md

**Tests**: Test-first is MANDATED by the plan of record: the new prose test lands and is SEEN RED (recorded) before the SKILL.md edit. Suite grows exactly `1..118` → `1..119`; prose `1..8` → `1..9`.

**Organization**: US2 (the pin) runs first in strict red→green order — appending the test before the prose exists gives the red observation for free; US1 (the seven-part contract) turns it green; the mutation check proves the binding; US3 (changelog) rides last.

## Phase 1: Setup

None — three existing files, no scaffolding.

---

## Phase 2: Foundational

None.

---

## Phase 3: User Story 2 — the pin, red-first (Priority: P2, runs first: it is the gate)

**Goal**: one new test in `pipeline/tests/prose.bats` pinning the seven part names; red seen before the prose exists.

**Independent Test**: quickstart.md §3.

- [X] T001 [US2] Append ONE new `@test` to `pipeline/tests/prose.bats` (no new file), matching the file's existing `grep -qF` style: seven fixed-string assertions against `pipeline/skills/pipeline/SKILL.md`, one per canonical name in `contracts/package-contract.md` (straight quotes in `Validation before "done"`).
- [X] T002 [US2] RED GATE: run `bash /c/Users/h_zah/bats/bin/bats pipeline/tests/prose.bats` with the UNMODIFIED SKILL.md; the new test MUST fail; record the failing output verbatim in this file's Completion notes. A pass here is a hard stop (the test tests nothing).

**Checkpoint**: red recorded; `1..9` with exactly one failure.

---

## Phase 4: User Story 1 — the seven-part contract in G (Priority: P1)

**Goal**: the G section specifies the package's seven parts by name; every pre-existing sentence byte-identical.

**Independent Test**: quickstart.md §1–§2.

- [X] T003 [US1] In `pipeline/skills/pipeline/SKILL.md`, append to the **G — implementer gate** section (after its last existing sentence, before the H heading) the compact seven-part list per `contracts/package-contract.md` — R1's shape: one item per part, bolded canonical name, dash, content requirements. Add near, never reword: the derived-forbidden-list sentence, the VOID sentences, and "`--auto` never collapses this gate: it spends money" stay byte-identical, as does every other existing G sentence.
- [X] T004 [US2] GREEN GATE: re-run the focused prose suite — `1..9`, 9 ok, all eight pre-existing tests still green; run quickstart §1–§2 greps and record outputs.
- [X] T005 [US1] MUTATION CHECK (SC-004): remove ONE part name from the G section by targeted edit; run the focused prose suite; the new test MUST go red; restore the text byte-exact by targeted edit (NEVER `git checkout --`); re-run green. Record both observations verbatim in Completion notes.

**Checkpoint**: contract in place, pin proven to bind.

---

## Phase 5: User Story 3 — changelog (Priority: P3)

- [X] T006 [US3] Add an `### Added` entry for the seven-part package contract under the existing `## [Unreleased]` heading in `pipeline/CHANGELOG.md`. No version stamp. STRICT surface: describe, never name, banned spellings (P2 precedent).

---

## Phase 6: Polish & validation

- [X] T007 Run quickstart.md §4 and §5: full house suite from the repo root — expect `1..119`, 119 ok, 0 non-TAP (growth exactly +1) — and the changelog heading order. Record outputs in Completion notes. Any other count is a finding.

---

## Dependencies & Execution Order

- Strictly sequential: T001 → T002 (red) → T003 → T004 (green) → T005 (mutation) → T006 → T007. No `[P]` tasks: the three files are few and the red→green→mutation spine is order-dependent; T006 is independent of T005 in file terms but rides after it so the mutation evidence is complete before anything else moves.

## Implementation Strategy

Test-first is the spine: T002's red observation is a gate, not a formality, and T005's mutation is the proof the pin binds to every name rather than to the file's existence. All edits are additive; the byte-identity of existing G sentences is checked by diff inspection at T003 and by the eight pre-existing prose tests at T004.

## Completion notes (evidence)

- T002 RED (2026-08-23, unmodified SKILL.md), verbatim:

  ```
  not ok 9 the handoff package names its seven parts
  # (in test file pipeline/tests/prose.bats, line 71)
  #   `grep -qF "$part" "$ORCH" || { echo "package part missing: $part"; false; }' failed
  # package part missing: Files to provide
  ```

  The loop fails on the first absent name — the test binds to the section's content, not the file's existence.

- T004 GREEN: prose `1..9`, 9 ok, exit 0. Quickstart §1: all seven name counts exactly 1. Quickstart §2: the three pinned-sentence greps each count 1. The SKILL.md diff is 26 insertions, 0 deletions — byte-identity of every existing G sentence proven by the diff shape.

- T005 MUTATION (2026-08-23): `Forbidden list` renamed away by targeted edit →

  ```
  not ok 1 the handoff package names its seven parts
  # package part missing: Forbidden list
  ```

  → restored by targeted edit (never `git checkout --`) → prose `1..9` all ok again.

- T007 (2026-08-23, repo root): full house suite `BATS_EXIT=0`, `1..119`, OK=119, NOTOK=0, NONTAP=0 — growth over the F.5 baseline (`1..118`) exactly +1, the new prose test. Changelog headings: `[Unreleased]` (line 5) above `[1.0.1]` (line 22) above `[1.0.0]` (line 41); no new version heading.

- Phase I deep review (2026-08-23, three lenses on opus). Contract: COMPLIANT — every FR/SC/AC met, byte-identity proven by `git diff --numstat` 0-deletion shape, all seven names counted once each inside G. Tests: no FR/SC violation; independent 7/7 mutation matrix on scratchpad copies re-proved the pin. Security: no leak, but three Important flow-shape findings. Fixed in-run:

  1. The new prose test tightened inside the SAME `@test` (no count movement): it now slices the G section (awk between the G and H headings) and greps the slice for the bolded bullet form `- **<name>**` — the relocation and generic-token mutants the tests lens proved GREEN are now closed — and pins three byte-identity fragments in the slice (the derived-list opening, the G-gate `--auto` sentence, the VOID fragment), which no test in the repo pinned before (the near-miss: prose test 6 pins the O-gate twin, not the G sentence). Live mutation control after tightening: `Repository state` renamed → `not ok 1` (filtered `-f "seven parts"` invocation) → restored byte-exact → `1..9` green.
  2. SKILL.md G section gains two additive sentences after the list (no pinned sentence touched; diff still pure insertions, 38 lines): redaction binds every part (a credential, endpoint or token travels as fact-and-location, never value — the package's reader is a different, cheaper model and no redaction language existed anywhere in the document); the forbidden-list derivation carries the never-bend destructive-git rule (`reset --hard`, `clean`, `checkout --`, `stash`) — the brief mandates an uncommitted tree, the one place with no recovery point, and the reader cannot see the never-bend table. Both mirrored into contracts/package-contract.md, and the contract's test-mechanics section updated to the tightened shape.
  3. Record fidelity: T005's mutation output was produced by a `-f "seven parts"` FILTERED invocation — that is why it reads `not ok 1` rather than `not ok 9`. (This note is the fix.) Reproduction hazard recorded by the tests lens: counting the pretty formatter's output corrupts naive `grep -c` counts — use `--tap` when counting.
  4. R1/T003 placement wording reconciled with the H.7 move: see R1's amendment note.

  Skipped/accepted with reasons: heredoc↔contract-file tie (accepted with review-time byte-check — `specs/` is deliberately outside every scanned surface, a runtime dependency would be wrong coupling); changelog presence/content pin (pin-blocked debt; the STRICT vocabulary and version-agreement gates are the real partial covers); the `/c/Users/...` bats path in this spec tree (the same class already ships in specs/002, merged — recorded for a future sweep together with extending the scan operands); "never two on one file" noun elision (cosmetic); `--` hardening beyond the new test (landed there naturally; the file's older tests keep their style).

- Phase H.7 simplify (2026-08-23, 4 agents on opus): applied 3 — the Instructions part now carries the fan-out guardrails (`maxParallelAgents` cap, never two tasks on one file, and the package carries the cap's value since its reader cannot see the orchestrator; mirrored into contracts/package-contract.md); the list's intro names its lineage (the handoff plugin's field-tested shape); the block moved up beside the forbidden-list sentence it references, before the VOID cleanup paragraphs (pinned sentences byte-identical — diff still pure insertions, 30 lines). Skipped 3 with reasons — trimming the "(test counts)" gloss and the "provably the implementer's" rationale (both are the plan of record's own sentence bytes), and renaming "the analyzer baseline where one exists" to state-file keys (seed wording; its "where one exists" guard already covers the no-record case honestly). Observed gap, recorded not fixed: no phase writes an analyzer-baseline record — F.5 records `test_baseline` only; a project with a real `analyzeCommand` has nothing recorded for the package's conditional clause to carry. After fixes: prose `1..9` 9 ok; pinned-sentence greps 1 each.
