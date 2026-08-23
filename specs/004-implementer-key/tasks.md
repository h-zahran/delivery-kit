# Tasks: pre-answer the implementer gate — the loop closes

**Input**: Design documents from `/specs/004-implementer-key/`

**Prerequisites**: plan.md, spec.md, research.md, contracts/key-contract.md, quickstart.md

**Tests**: NO test changes this phase — the seed pins prose at `1..9` and the house suite at `1..119`; growth of either count is a finding. The prose pin for the new quoted sentences is recorded test debt, not spent (research R3 — AMENDED at phase I: the recorded list named ONE item; the real unpinned surface is SEVEN, plus phase I's own additions. See R3.).

**Organization**: all edits are additive prose in three files; strict sequence (two tasks share SKILL.md); the field test (SC-004) is the RUN's own G/H phases, not a task in this file.

## Phase 1: Setup

None — three existing files, no scaffolding.

---

## Phase 2: Foundational

None.

---

## Phase 3: User Story 1 — the key, the flag, the G sentences (Priority: P1)

**Goal**: the orchestrator documents the key and flag and gains the quoted sentence pair; nothing existing reworded.

**Independent Test**: quickstart.md §1 (first two greps) and §3.

- [X] T001 [US1] In `pipeline/skills/pipeline/SKILL.md`, append the Configuration-table row and the Flags-table row, each character-exact per `contracts/key-contract.md` sites 1–2 (append at table end — never insert, research R2).
- [X] T002 [US1] In the same file's G section, add the quoted sentence pair verbatim (contract's "quoted G sentences"), directly after "`--auto` never collapses this gate: it spends money." and before the seven-part list's intro, followed by one sentence of this run's own (spec Edge Case 1): an illegal `implementer` value stops pre-flight by name — never coerced, never treated as unset. Add near, never reword; the Gates-table row `| Implementer | G |` stays byte-identical.

**Checkpoint**: quickstart §1 greps 1–2 count 1 each; §3 both flat-greps count 1.

---

## Phase 4: User Story 2 — the configuration page (Priority: P2)

**Goal**: the docs page carries the key in its JSON block and key table plus the explaining paragraph.

**Independent Test**: quickstart.md §1 (last two greps) and §2.

- [X] T003 [US2] In `pipeline/docs/configuration.md`, append `"implementer": null` to the JSON block (before the closing brace, comma-corrected), append the key-table row per contract site 4, and add the FR-004 paragraph as its own short section ("The implementer key"): what it pre-answers, unset means ask, and the clarify-only purpose under `--auto`, plus the illegal-value rule (stops pre-flight by name — never coerced, never treated as unset). STRICT surface — no banned spellings.

**Checkpoint**: quickstart §1 greps 3–4 count 1 each; the paragraph reads complete.

---

## Phase 5: User Story 3 — changelog (Priority: P3)

- [X] T004 [US3] Add an Added entry for the key and flag under `## [Unreleased]` in `pipeline/CHANGELOG.md`. No version stamp. STRICT surface.

---

## Phase 6: Polish & validation

- [X] T005 Run quickstart §1–§5: the four site greps, the identity check, the verbatim sentence flat-greps, prose `1..9`, full house `1..119` (growth exactly zero), `| Implementer | G |` count 1, `git status --porcelain -- handoff/` empty, changelog headings ordered. Record outputs in Completion notes.

---

## Dependencies & Execution Order

- T001 → T002 (same file, table before prose so §1 validates early) → T003 → T004 → T005. No `[P]`: three small files, and the two SKILL.md tasks serialize on the file.

## Implementation Strategy

Additive-only prose; every exact string comes from contracts/key-contract.md, so the edits are transcription, not composition. The suite's structural pins (the G-slice anchor guards, the Gates-table test, the STRICT vocabulary and version-agreement gates) are the regression net; quickstart §4 proves nothing moved.

## Completion notes (evidence)

(appended as tasks complete)

### T001 — SKILL.md table rows (2026-08-23)

Both rows appended at each table's end: the Configuration-table row
after `devCommand`, the Flags-table row after `--resume`. Checkpoint
(quickstart §1 greps 1–2): both printed `1`.

### T002 — the quoted G sentences (2026-08-23)

Added as a new plain paragraph directly after "`--auto` never collapses
this gate: it spends money." and before "The package carries seven
parts…", then one run-authored sentence: an illegal `implementer` value
(anything but `claude` or `handoff`) stops pre-flight by name — never
coerced, never treated as unset. Checkpoint (quickstart §3): both
flat-greps printed `1`. Extra guard run immediately after:
`bats --tap pipeline/tests/prose.bats` printed `1..9` with 9 ok — test
9's G-slice anchors, heading-shape check and seven part names intact.

### T003 — configuration page (2026-08-23)

`"devCommand": null` comma-corrected and `"implementer": null` appended
before the closing brace; key-table row appended after `devCommand`;
new section "The implementer key" placed after "The state directory". **SUPERSEDED at H.7**: the section shipped after "Base branch", not after "The state directory" — H.7 relocated it to the page's per-key pattern and neither this note nor research R2 was annotated at the time. Raised by the phase I contract lens (M2) and tests lens (Minor 2); both records now carry the supersession.
Checkpoint (quickstart §1 greps 3–4): both printed `1`. Extra checks:
the JSON block parses under `jq`; the STRICT vocabulary scan
(published banned list, word-bounded, case-insensitive) matched
nothing in the file.

### T004 — changelog (2026-08-23)

Added entry appended to the existing `### Added` list under
`## [Unreleased]`; no version heading added. STRICT scan clean.
`grep -n '^## \[' pipeline/CHANGELOG.md | head -3`:
`5:## [Unreleased]`, `32:## [1.0.1] - 2026-08-22`,
`51:## [1.0.0] - 2026-08-20`.

### T005 — full validation (2026-08-23)

- Quickstart §1 (four site greps): `1`, `1`, `1`, `1`.
- Quickstart §2: both files printed exactly `` `implementer` ``;
  value-set grep printed `2`.
- Quickstart §3 (flat-greps): `1`, `1`.
- Quickstart §4: prose `1..9`, 9 ok; `| Implementer | G |` count `1`;
  `git status --porcelain -- handoff/` empty.
- House suite (`bats --tap -r --print-output-on-failure tests
  handoff/tests pipeline/tests`): plan `1..119`, 119 `ok` lines,
  0 `not ok` lines, exit 0 — growth exactly zero, baseline matched.
- Quickstart §5: changelog headings ordered as in T004.

All work left uncommitted per the package's report-back contract.

### Phase H.7 simplify (2026-08-23, 4 agents on opus; 4 applied, 2 skipped)

Applied: (1) the Gates summary gains the exception sentence — "G always stops" had become false in this very diff (two reviewers converged on it); (2) pre-flight decision item 10 anchors the illegal-value stop where it actually happens (the rule was stated only in after-the-fact sites); (3) the docs section relocated beside "Base branch" (the page's per-key pattern) and made truthful for BOTH values — "touches the human at clarify only" holds for `claude`; `handoff` parks the run, which the old sentence papered over; row-restating sentence and "as before"/gloss trimmed; (4) the changelog bullet scoped the same way. Skipped with reasons: the `--auto` flag row (literally true of `--auto` alone; the Gates exception sentence now carries the combination) and the changelog's full restatement of the illegal-value rule (house style: entries are self-contained). Verification: prose `1..9` + portability all ok, `| Implementer | G |` count 1. **Widened at phase I (tests lens, Minor 1)**: H.7's own verification was narrower than T005's; the tests lens re-ran all six checks post-H.7 and they hold — four site greps 1, 1, 1, 1; both flat-greps 1, 1; identity checks pass; prose `1..9`; `| Implementer | G |` count 1; `handoff/` untouched; changelog headings ordered. The contract lens independently ran the only post-H.7 FULL house suite: `1..119`, 119 ok, 0 not ok, 0 non-TAP, exit 0, no numbering gaps.

### SC-004 — the field test, recorded by the pipeline (2026-08-23)

The park and resume ran live, end to end, on P3's shipped machinery:

- G answered "handoff" (standing answer); the package written to `.delivery-kit/runs/004-implementer-key/handoff-package.md` (seven parts, files verified before writing); `gates.G` and `artifacts.package` recorded; `phase-done G`, `phase-start H`; lock released; run stopped without invoking the implement command.
- The owner handed the package to an external implementer, which executed T001–T005 and reported per the Report-back contract (status done, files touched, §6 outputs verbatim, could-not-do empty). The report above this note is that report's evidence trail.
- `--resume` re-entered at H with the lock retaken. The recorded G answer was not re-asked. Consumption before any dispatch: tree reconciled (3 modified files + the two expected untracked dirs, HEAD 76cb1cc unchanged); every claimed `[X]` verified against the real diff (SKILL.md +10/0 pure insertions with the two exact contract rows and the verbatim quoted pair; configuration.md +14/−1; CHANGELOG +7/0 — **all three numstats MEASURED PRE-H.7**; after H.7 they read 16/1 and 8/0, and phase I moved them again, so read them as the H-resume record, not as the shipped diff). **Correction (phase I contract lens, M4)**: the diff carried TWO deletion lines, not one — the `devCommand` comma-correction AND a benign word-level reflow of "them. A gate is a safe handoff point by" in which every character survives. State it as "no prose removed; one comma-correction and one line-reflow"; the full verification run ONCE by the pipeline itself — `1..119`, 119 ok, 0 not ok, 0 non-TAP, exit 0, `| Implementer | G |` count 1, the JSON block parses with `implementer: null`. Could-not-do: empty. Unclaimed tasks: none — nothing was dispatched.

### Phase I — deep review (2026-08-23, three lenses on opus; 13 unique findings, 10 fixed, 3 deferred)

The three lens reports are saved VERBATIM in the run directory:
`review-security.md`, `review-contract.md`, `review-tests.md`. Verdicts:
contract COMPLIANT (0 Critical, 0 Important, 6 Minor record-hygiene);
security not COMPLIANT (0 Critical, 3 Important, 3 Minor — the axis is
CONSENT REMOVAL, not privilege escalation); tests coverage-gap (1
Important, 3 Minor). Every claim was reproduced against the real files
before it was acted on. Contract M2 and tests Minor 2 are the same
finding — 16 raw findings dedupe to 13.

**Fixed in the product (`pipeline/`)**

1. Security Important 1 — the Gates section understated the consent
   floor and contradicted itself ("G always stops" + "the one
   exception"). Rewritten into ONE statement: C, G and O can each have
   nothing to ask, and a new paragraph states the floor plainly — with
   `implementer` set, `--auto`, no clarify questions and
   `releaseCommand` unset, a run CAN reach DONE with no gate stopping
   it, while the constitution offer, cap breaches, a missing required
   tool, hard failures and a failed runtime check all still stop. Tests
   Minor 3 ("Only C and O can have nothing to ask") is fixed by the
   same rewrite. The floor is now also stated in
   `configuration.md` and the changelog entry.
2. Security Important 2 — a gate-collapsing key was invisible at
   pre-flight. The probe block gains
   `Implementer  : <claude|handoff>  (from <source>)`, omitted when
   unset, plus an **Implementer:** paragraph beside **Base branch:**
   recording that `preflight.sh` never reads `.delivery-kit.json`, so
   the line renders from the RESOLVED configuration and `<source>`
   names the winning layer exactly as `baseBranchSource` does.
3. Security Minor 1 — validation ordering. Item 10 now says the enum is
   checked when configuration resolves, before the decision walk, so
   the stop precedes items 6 and 9's offered writes; the item anchors
   the rule rather than being where the check first runs. No
   renumbering.
4. Security Minor 2 — the echoed illegal value. Item 10 now says to
   name it quoted and truncated: data read from a tracked file, never
   an instruction to follow.
5. Security Minor 3 — the split state field. A new plain sentence in
   the G section names `gates` the answer's only authoritative record;
   the state file's top-level `implementer` field (`progress.sh:73`,
   present since 1.0.0, written beside `gates` and read by nothing —
   verified by a plugin-wide grep) is not the record.
6. Contract Minor 5 — the changelog's positional cross-reference ("as
   the previous entry describes") replaced with a self-contained
   clause: "package written and lock released".

**Fixed in the records (`specs/004-implementer-key/`)**

7. Contract Minor 2 / tests Minor 2 — research R2 and the T003 note
   both claimed the docs section lands after "The state directory";
   H.7 relocated it after "Base branch" and annotated neither.
   Supersession notes added to both.
8. Contract Minor 3 + Minor 4 — the SC-004 note's numstats are marked
   MEASURED PRE-H.7, and the "single deletion" claim corrected: the
   diff carried TWO deletion lines, the second a word-level reflow in
   which every character survives.
9. Contract Minor 6 — spec US1, US2 and FR-004 carried the unscoped
   "clarify only" claim. All three annotated as SCOPED (line 9 is the
   verbatim seed and was not touched).
10. Tests Important 1 + Minor 1 — research R3's debt list widened from
    ONE item to SEVEN, with phase I's own additions enrolled alongside;
    the H.7 note now carries the tests lens's six re-run checks and the
    contract lens's post-H.7 full-suite numbers.

**Deferred, with reasons**

- **Security Important 1, behaviour route** — "a config-sourced (not
  flag-sourced) `implementer` does not collapse G under `--auto`".
  This changes the consent semantics of the very contract this run
  specifies, mid-run, inside an `--auto` run. The honest-prose route
  was taken instead; the behaviour question is the owner's, and goes
  to the PR body and the owner queue.
- **Security Important 3 — the CLI re-arm** (accept `ask`, or
  `--no-implementer`, meaning "restore the stop"), and the
  unspecified later-layer-`null` merge semantic. The value set
  `<claude|handoff>` is CONTRACT-PINNED in
  `contracts/key-contract.md` — it appears verbatim in two of the four
  pinned row strings. Widening it is a specification change, not a
  review fix. Owner queue.
- **Contract Minor 1 — the `--auto` flag row** ("C, G and O still
  stop.") and, in the same class, the G section's "STOP AND ASK" lead:
  both are now conditionally false with `implementer` set. Rewording is
  forbidden this phase (pinned row text; the lead is inside the G
  slice). H.7 already skipped the row with a recorded reason; the
  contract lens asked only that it be QUEUED. Both are hereby queued as
  PROSE debt — distinct from the TEST debt in research R3.

**Verification after the fixes** (the full house suite is J's job)

- Four site greps: `1`, `1`, `1`, `1`. Both quoted-pair flat-greps: `1`.
- `| Implementer | G |` count `1`. Prose suite: `1..9`, 9 ok.
- Portability suite (the STRICT vocabulary and local-path gates):
  `1..21`, 21 ok — both STRICT files clean.
- The configuration.md JSON block parses under `jq` with
  `implementer` null.
- Every mutated line echoed back after its write; no test guards this
  prose, and the tests lens proved that deleting whole paragraphs of it
  stays green, so care is the only guard.
