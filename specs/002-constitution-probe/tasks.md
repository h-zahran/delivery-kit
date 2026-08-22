# Tasks: constitution — probe it, print it, offer it once

**Input**: Design documents from `/specs/002-constitution-probe/`

**Prerequisites**: plan.md, spec.md, research.md, contracts/probe-contract.md, quickstart.md

**Tests**: Test-first is MANDATED by the seed: the two new bats tests land and are SEEN RED (recorded) before the script changes. Suite grows exactly `1..116` → `1..118`.

**Organization**: US2 (script + tests) is the load-bearing story and runs first in strict red→green order; US1 (prose) depends on the boolean existing; the changelog rides last.

## Phase 1: Setup (fixtures)

- [X] T001 [P] Create fixture `pipeline/tests/fixtures/constitution-unset/`: mirror the minimal `.specify` shape the existing `other` fixture carries, plus `.specify/memory/constitution.md` in template-placeholder shape (`[PROJECT_NAME]`, `[PRINCIPLE_1_NAME]` tokens). Plain files only, no dependencies.
- [X] T002 [P] Create fixture `pipeline/tests/fixtures/constitution-set/`: same shape, `.specify/memory/constitution.md` carrying short real principles (no placeholder tokens).

---

## Phase 2: Foundational

None — the fixtures are the only prerequisite.

---

## Phase 3: User Story 2 — the boolean, test-first (Priority: P2, runs first: it is load-bearing)

**Goal**: `preflight.sh` emits `speckit.constitutionSet` per the contract table; two appended tests prove it both ways; red seen first.

**Independent Test**: quickstart.md §1 and §2.

- [X] T003 [US2] Append two tests to `pipeline/tests/preflight.bats` (no new file), mirroring the file's existing `--dir` fixture pattern: one asserting `.speckit.constitutionSet == false` against `fixtures/constitution-unset`, one asserting `true` against `fixtures/constitution-set`.
- [X] T004 [US2] RED GATE: run `bash /c/Users/h_zah/bats/bin/bats pipeline/tests/preflight.bats` with the UNMODIFIED script; both new tests MUST fail; record the failing output verbatim in this file's Completion notes. A pass here is a hard stop (the tests test nothing).
- [X] T005 [US2] Implement in `pipeline/scripts/preflight.sh` per research R1: compute `constitutionSet` (absent → false; placeholder-token grep → false; no non-blank non-comment content → false; else true) and emit it inside the `speckit` object. Same flags, same keys plus this one, stdout pure JSON.
- [X] T006 [US2] GREEN GATE: re-run the focused suite; both new tests pass, all previous preflight tests still pass; run quickstart §1's three commands and record outputs.

**Checkpoint**: boolean proven both ways; contract otherwise unchanged.

---

## Phase 4: User Story 1 — the probe line and the one-time offer (Priority: P1)

**Goal**: pre-flight text prints the Constitution line and offers `/speckit-constitution` once when unset.

**Independent Test**: quickstart.md §3.

- [X] T007 [US1] In `pipeline/skills/pipeline/SKILL.md`, add the `Constitution : <set / not set — plan gates run against an empty document>` line to the pre-flight probe block (matching the block's existing column style), and append to the pre-flight decision list the one-time offer: when `constitutionSet` is false, OFFER `/speckit-constitution` once — the principles are the owner's to write, declining is fine, the offer is not repeated within a run, and the answer is recorded in the state file's `gates` key. Add near, never reword: every pinned string stays byte-identical.

**Checkpoint**: probe-line grep hits once; prose.bats 1..8 ok.

---

## Phase 5: Changelog

- [X] T008 Add `## [Unreleased]` with an `### Added` entry for the probe + offer to `pipeline/CHANGELOG.md`, above `## [1.0.1] …`. No version stamp. STRICT surface, count-free.

---

## Phase 6: Polish & validation

- [X] T009 Run quickstart.md §3 and §4 checks; then the full house suite from the repo root: expect `1..118`, 118 ok, 0 non-TAP. Any other count is a finding.

---

## Dependencies & Execution Order

- T001, T002 parallel (different trees). Then strictly: T003 → T004 (red) → T005 → T006 (green) → T007 → T008 → T009.
- T007 waits for T005 so the prose never describes a key that does not exist.

## Implementation Strategy

Test-first is the spine: the red observation (T004) is a gate, not a formality. Fan-out only for the fixture pair; everything else is one file at a time.

## Completion notes (evidence)

- T004 RED (2026-08-22, unmodified script), verbatim:

  ```
  not ok 19 constitutionSet is false on a fresh-init-shaped constitution
  # (in test file pipeline/tests/preflight.bats, line 166)
  #   `[ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ]' failed
  not ok 20 constitutionSet is true once the constitution carries real principles
  # (in test file pipeline/tests/preflight.bats, line 172)
  #   `[ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "true" ]' failed
  ```

  Both fail on the `constitutionSet` assertion itself (the key is absent, jq yields `null`), not on fixture setup — the tests bind to the contract.

- T009 GREEN (2026-08-22, repo root, after resume from the mid-H handoff), verbatim:

  Quickstart §3 — prose:

  ```
  $ grep -n "not set — plan gates run against an empty document" pipeline/skills/pipeline/SKILL.md
  118:Constitution : <set / not set — plan gates run against an empty document>
  $ grep -n "speckit-constitution" pipeline/skills/pipeline/SKILL.md
  177:   running `/speckit-constitution` once — the principles are the
  $ bash /c/Users/h_zah/bats/bin/bats pipeline/tests/prose.bats
  1..8   (all 8 ok)
  ```

  Quickstart §4 — changelog headings:

  ```
  $ grep -n '^## \[' pipeline/CHANGELOG.md | head -3
  5:## [Unreleased]
  16:## [1.0.1] - 2026-08-22
  35:## [1.0.0] - 2026-08-20
  ```

  Full house suite (repo root, `bats -r tests handoff/tests pipeline/tests`):

  ```
  BATS_EXIT=0
  1..118
  OK_COUNT=118
  NOT_OK_COUNT=0
  NON_TAP=0
  ```

  Exactly the expected count: the F.5 baseline was `1..116`; the two new constitution tests account for the growth to `1..118`. No other change.

- Phase I deep review (2026-08-22, three lenses on opus agents), fixed in-run:

  1. SKILL.md decision item 9: the `gates`-recording sentence was unsatisfiable on a fresh run (no state file exists at pre-flight; decline-then-resume would re-offer, against US1/AC3). Appended the timing clause mirroring the seed-deferral pattern: record immediately on a resume; on a fresh run hold the answer and write it once B's `init` creates the state file.
  2. Contract row 3 + research R1: a file whose only content is a multi-line `<!-- … -->` block measures `true` (the comment regex is line-scoped). Recorded as the accepted false positive — the real 0.16.5 template's comments are all single-line — rather than landing an untested multi-line stripper in the polish phase.
  3. `preflight.bats` no-speckit test: added one `constitutionSet == false` assertion — pins absent-file → `false` (US2/AC3) with zero TAP-count movement. Focused suite after: `1..20`, 20 ok; prose `1..8`, 8 ok.
  4. research R1 false-negative wording broadened to the regex's real reach (`[RFC2119]`, checked `[X]` boxes — any bracketed token starting with a capital).
  5. preflight.sh comment: unconditional-emission rationale reworded to the true reason (the value derives from the file alone).

  Deferred, pin-blocked (suite growth frozen at +2, prose at 1..8 by the spec's own success criteria): an empty-content-row test, prose pins for the two new pinned strings (joins the P1 owner-queue prose-pin debt), a changelog `[Unreleased]` assertion (partial coverage already via the portability version-agreement and vocabulary gates), a pin for the `[ALL_CAPS]` false negative. Noted, no action: security lens verdict COMPLIANT (one Minor: symlink-followed 1-bit probe — strictly narrower than pre-existing `.specify/` reads, no fix required); accepting the offer dirties the tree after the dirty-tree gate (K's by-name file list is the catch); the probe line names its rendered alternatives, not its JSON field (wording is pinned).
