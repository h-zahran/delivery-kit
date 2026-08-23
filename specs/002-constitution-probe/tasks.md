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

- Phase M round 1 (2026-08-22, PR #15 review: 15 verified findings). SUPERSEDES the Phase I note's "accepted false positive" ruling: the review measured that the constitution command's own Sync Impact Report comment (bracketed tokens inside an HTML comment) flips its own output to `not set` — the unstripped grep broke the feature's happy path, which invalidates the premise the Phase I ruling stood on. Fixed this round:

  1. `preflight.sh`: HTML comments (multi-line included) now stripped by a POSIX awk pass before both checks; leading UTF-8 BOM stripped; UTF-16 BOM reads `false` (safe direction); `unset GREP_OPTIONS` beside the CDPATH guard (legacy greps honour it through 3.5, measured flipping the boolean). The `constitution-set` fixture gained BOTH comment shapes (multi-line report block + single-line example, bracketed tokens in each), so test 20 now guards the stripping. RED first, verbatim:

     ```
     not ok 1 constitutionSet is true once the constitution carries real principles
     # (in test file pipeline/tests/preflight.bats, line 173)
     #   `[ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "true" ]' failed
     ```

     GREEN after: focused `1..20` all ok. Edge measurements (scratchpad trees): UTF-16LE/BE template no-BOM → `false` (bash NUL-strip path, warning on stderr only); UTF-16LE with BOM → `false`, stderr empty; UTF-8-BOM-only file → `false`; multi-line-comment-only file → `false`; BOM + real principles → `true`; `GREP_OPTIONS=-v` poison → set fixture still `true`. Self-probe of this repo still `false`; both fixture probes unchanged.

  2. SKILL.md decision item 9 (new sentences only; pinned offer sentence untouched): read `gates.constitution` before offering (decline-then-resume no longer re-offers — the key is now named); derive the dot form when recorded; a `py`-flavour install is told the command is unavailable instead of offered; the offer is a conditional stop `--auto` does not collapse and no answer is ever invented; an abandon at item 8 ends the walk; an orphaned accepted write is the offer's own footprint at the next run's dirty-tree check. Phase B gains the mirror sentence writing the held answer in the same breath as the seed.

  3. Contract: probe-line section now says SKILL.md carries the combined template line and the rendered forms are the output contract (a fixed-string search found the old attribution false); truth-table notes rewritten for the stripping mechanism; row 3's Phase I narrowing REVERTED (comment-only files, multi-line included, now honestly read `false`). research.md R1 rewritten to the shipped mechanism, recording: false negative narrowed to tokens outside comments; BOM-less UTF-16 `false` via NUL-stripping; exotic Unicode whitespace (U+00A0/U+200B) can read a content-free file `true` — accepted, untestable under the pin.

  4. `pipeline/docs/configuration.md`: the constitution offer disclosed as pre-flight's second and larger offered write (STRICT surface — paraphrase spelling, vocabulary gate green).

  Deferred with reasons: the unconditional-emission property has no guarding fixture (needs a written-constitution/no-scaffold tree — new test blocked by the +2 pin, existing-fixture mutation barred by R2; queued with the test debt); extension-hook exposure when an accepted offer's command commits via a mandatory hook (pre-existing unmodelled class across all ten spec-tool commands, needs its own design); status-skill visibility of a run parked on the offer (different component, reads `gates` by phase letter and is not broken by the new key); exotic-whitespace edge (recorded in R1). Verification after all fixes: full house `1..118`, 118 ok, 0 non-TAP, exit 0; prose `1..8`; portability all ok.

- Phase M round 2 (2026-08-22, verification review of the round-1 fixes: 11 findings, 10 fixed, 1 deferred):

  1. `preflight.sh`: the constitution block's two command substitutions now carry the file's own `2>/dev/null || true` guard idiom — an unreadable constitution degrades to `false` instead of killing the pure-JSON contract (crash mechanism was positive-controlled by the reviewer; not reproducible on Git Bash). The double-negative `grep -qvE '^[[:space:]]*$'` became the positive `grep -q '[^[:space:]]'` (equivalent, and the house memory names `-v` pattern checks a footgun class).
  2. SKILL.md item 9 (my round-1 sentences reworked; the pinned offer sentence untouched): the `gates.constitution` read is now scoped to resumes and the fresh-run branch explicitly holds the answer aside (the old wording told a fresh run to read a file that cannot exist); a resume into a run whose plan phase already started does not offer at all (D consumed the constitution — the review caught that THIS repo's own parked run would otherwise be offered a tracked-file rewrite at phase M); the orphaned-write escape hatch is REMOVED — it contradicted item 5 (walked first, unamended) and keyed the waiver on file identity with no evidence an offer was ever made; the honest rule now stands: item 5 rightly stops, clearing the dirt is the owner's call. The Gates section's conditional-stops paragraph gains a new sentence naming the offer (the enumeration predated it).
  3. Cross-artifact drift closed with carve-out sentences (no pinned sentence reworded): the `py`-flavour exception now stands in the contract's offer section, spec FR-003, and the shipped `[Unreleased]` changelog entry. `configuration.md`'s verbs corrected: accepting rewrites the file where it exists, creates it untracked where it does not. plan.md Technical Context updated to the shipped mechanism and the five-file scope.
  4. Both fixtures gained `.specify/scripts/bash/.gitkeep` so their declared `sh` flavour resolves to a directory that exists.

  Deferred: BOM/UTF-16 guard has zero test coverage (mutation-proven by the reviewer) — same +2 pin as the rest of the test debt; queued with it. Verification after round 2: focused+prose+portability 49 ok 0 fail; probes `false`/`true`/`false` (unset/set/self); full house `1..118`, 118 ok, 0 non-TAP, exit 0.

- Phase M round 3 (2026-08-23, final round: rounds 1–2 held under re-measurement; 13 new findings). CAP REACHED — conditional stop taken; the owner answered "fix all 13 now" (recorded as the M-gate answer; design calls delegated). Dispositions:

  1. Detection redesigned (red-first: `[RFC2119]` added to the set fixture's body, test 20 seen red verbatim, then green). Placeholder check narrowed from any `[ALL_CAPS]` token to the 0.16.5 template's OWN token list (measured from this repo's template) — `[RFC2119]`/`[X]` and non-template justified slots (`[OPTIONAL_REVIEW_CADENCE]`) now read `true`, both measured. The BOM sniff became a NUL sniff on the first 4KB: UTF-16LE/BE with or without BOM and UTF-32 all read `false` WITH a named stderr warning (round-2's research claim that BOM-less UTF-16 reads false via NUL-stripping was measured wrong and is corrected). An unclosed `<!--` is kept as literal text — the 80%-unfilled-template-behind-a-stray-opener case now reads `false` (the forbidden direction closed), real-principles-after-a-stray-opener reads `true`; both measured. Silent degradation fixed: both degrade paths `warn` by name. `export LC_ALL=C` hoisted to the env block beside the CDPATH/GREP_OPTIONS guards.
  2. The `py`-flavour carve-out from round 2 was REVERTED in all four artifacts (SKILL.md, contract, spec FR-003, changelog): the reviewer verified specify-cli 0.16.5 ships python script variants and substitutes them per flavour, so the carve-out's premise was false. configuration.md never carried it.
  3. SKILL.md: abandon's consequence now stated in item 8 where the term is owned; item 9's resume guard names its observable (a D entry in the state file's `timestamps`); the fresh-run answer is held "as A holds the seed" and written as `init`'s next act, with the honest note that the write, not memory, is what once-per-run rests on; NEW ruling (owner-delegated design call): an accepted constitution write is staged by phase K as its own separate commit, named like every other path — stated in item 9 and in K.
  4. Fixtures: the doubled `scripts/.gitkeep` and the reader-less Makefiles removed (both trees now mirror the web fixture's four-file shape); `scripts/bash/.gitkeep` stays so the declared `sh` flavour resolves.
  5. Ruled against, recorded: folding the probe into one awk pass (the reviewer's own counterweights — gawk-only equivalence, zero BOM-test coverage under the pin, less legible predicates — outweigh retiring two greps).

  Named residual edges, all failing SAFE (a declinable re-offer, never a silent `set`), recorded in research R1: a template token kept outside comments; an ASCII `-->` inside a comment closing it early (HTML semantics) and leaking a report line that names a template token; exotic Unicode whitespace reading a content-free file `true`. Verification after round 3: focused+prose+portability 49 ok 0 fail; probes `false`/`true`/`false`; full house `1..118`, 118 ok, 0 non-TAP, exit 0; ten scratchpad edge trees measured as documented.
