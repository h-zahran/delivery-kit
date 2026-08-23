# Tasks: pre-answer the implementer gate — the loop closes

**Input**: Design documents from `/specs/004-implementer-key/`

**Prerequisites**: plan.md, spec.md, research.md, contracts/key-contract.md, quickstart.md

**Tests**: NO test changes this phase — the seed pins prose at `1..9` and the house suite at `1..119`; growth of either count is a finding. **OVERRIDDEN at phase M round 4 (2026-08-23)**: the owner ruled "fix everything, no deferred", which spent the prose-pin debt. Two tests were added; prose is `1..11` and the house suite `1..121`. Any OTHER movement is still a finding. The prose pin for the new quoted sentences is recorded test debt, not spent (research R3 — AMENDED at phase I: the recorded list named ONE item; the real unpinned surface is SEVEN, plus phase I's own additions. See R3.).

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

> The counts above (`1..9`, `1..119`) are T005's measurement on the tree as it stood at phase H, and are correct as a record of that moment. Phase M round 4 later added two tests on the owner's instruction: prose `1..11`, house `1..121`.

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

  > **SPENT at phase M round 4 (2026-08-23)**: the owner ruled "fix
  > everything, no deferred", which makes the specification change
  > authorised. `ask` is now a legal value at every layer, the contract
  > and its pinned strings were re-pinned to match, and the later-layer
  > `null` question is answered in the Configuration section: `null` is
  > silence, never an override, and `ask` is the only spelling that
  > overrides toward the stop. Security Important 3 is CLOSED.
- **Contract Minor 1 — the `--auto` flag row** ("C, G and O still
  stop.") and, in the same class, the G section's "STOP AND ASK" lead:
  both are now conditionally false with `implementer` set. Rewording is
  forbidden this phase (pinned row text; the lead is inside the G
  slice). H.7 already skipped the row with a recorded reason; the
  contract lens asked only that it be QUEUED. Both are hereby queued as
  PROSE debt — distinct from the TEST debt in research R3.

  > **WITHDRAWN at phase M round 1 (2026-08-23) — the reason above is
  > FALSE and both sentences are now FIXED.** Two independent PR
  > reviewers measured the claim and refuted it: `C, G and O still
  > stop.` occurs in exactly one place in tracked content (the row
  > itself), in no `.bats` file and in no contracts file; `STOP AND
  > ASK` likewise. `main-plan.md`'s Global Constraints enumerate the
  > pinned strings exhaustively and neither appears. What `prose.bats`
  > pins is `` `--auto` never collapses O `` — the PARAGRAPH below the
  > table, not the row — and test 9 pins four flattened G sentences,
  > not the lead. The "inside the G slice" half is refuted by this
  > run's own diff, which added two whole paragraphs inside that slice.
  > The real constraint was the plan's "add near, never reword", and
  > this run had already set it aside twice on the same ground — a
  > sentence THIS diff made false is not protected churn (H.7's docs
  > reword, phase I's Gates rewrite). Applying that ground
  > consistently: the row now reads "C and O still stop; G stops unless
  > `implementer` pre-answered it." and the lead reads "STOP AND ASK,
  > unless `implementer` pre-answered it:". Recorded as a deliberate,
  > reasoned override of the plan constraint, not an oversight.

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

### Phase M round 1 (2026-08-23, PR #17 review; 3 reviewers on opus, the run's fan-out cap)

Lenses: (1) diff scan plus in-file and test-file guidance; (2) git blame and
historical intent; (3) prior pull requests and their review record. The
repository has no root instructions file, so that lens of the review skill is
void and was not run. **Sixteen raw findings dedupe to eleven; nine fixed, two
deferred with measured reasons.** Every claim was reproduced against the real
files before it was acted on — including the two that refuted this session's
own phase I work.

Method note worth keeping: PRs #13-#17 carry ZERO GitHub reviews and zero
inline comments. This project's review record lives in the repository — the
Completion notes blocks of `specs/00N-*/tasks.md` and the
`.delivery-kit/runs/*/review-*.md` files. A future lens 3 should read those,
not the GitHub API.

**Fixed in the product**

1. **Pre-flight decision item 10 fired on the default configuration.** It read
   "resolving to anything but `claude` or `handoff`" — and the documented
   default is `null`, which IS "anything but". Read literally, a hard stop at
   pre-flight triggered in every repository that has not set the key, which is
   every repository today. Now: "a value that is neither `claude` nor
   `handoff` — unset is not a value and never stops anything". The same
   over-broad parenthetical in the G section (H.7's sentence, which sits after
   the pinned pair) was corrected to match.
2. **The `--auto` row and G's lead were false.** See the WITHDRAWN block above
   for the measured refutation of the deferral that had shielded them.
3. **Item 9 cited G as un-pre-answerable.** "like C and G it needs an answer
   only the owner can give" — the constitution offer's justification rested on
   an analogy this very diff broke, which is exactly the licence a future
   `constitution` key would need. Narrowed to "like C, and like G whenever
   `implementer` is unset".
4. **The source token was specified by an analogy that cannot carry it.** The
   phase I paragraph said it names the winning layer "exactly as
   `baseBranchSource` does". Measured against `preflight.sh:153-159`,
   `baseBranchSource` takes three values and collapses `~/.delivery-kit.json`,
   the repository's `.delivery-kit.json` and `--config` into the single word
   `configured`, with no value for a flag at all — so it cannot distinguish a
   tracked file from a typed flag, which is the ONLY distinction the paragraph
   exists to draw. Replaced with `<implementerSource>` and an enumerated layer
   list, plus an explicit instruction NOT to borrow that vocabulary.
5. **The probe block leaked a meta-instruction into printed output.** Phase
   I's line carried "— the line is omitted when the key is unset" OUTSIDE the
   angle-bracket placeholders, unlike every other line in that fenced block,
   so a model rendering it literally would print the instruction to the
   operator on a run where the key is manifestly set. The rule moved into the
   prose below, where it already half-lived.
6. **Item 10's rule was stated at the wrong altitude.** Phase I put "checked
   when configuration resolves" INSIDE item 10 — position 10 of a list whose
   preamble says "in this order" and whose item 8 says "no later item fires".
   A top-down reader met the correction only after items 6, 7 and 9 had
   appended to `.gitignore`, taken the lock and possibly written a
   constitution. The rule now also stands in the Configuration section, where
   "Resolve once, at pre-flight" actually lives.
7. **"Touches the human at clarify only" was still false, twice over.** Phase
   I conditioned the floor on `releaseCommand` unset in the orchestrator but
   left the configuration page and the changelog claiming "clarify only"
   flatly. With `releaseCommand` set, the release gate stops; with the
   constitution unset, the pre-flight offer stops — and `--auto` collapses
   neither. Both surfaces now carry both edges.
8. **The what-still-stops list disagreed across surfaces in one pull
   request.** The orchestrator named five things, the configuration page three
   (omitting the constitution offer and the missing-required-tool stop), the
   changelog none. All three now agree.
9. **The constitution offer's commit-and-push consequence.** PR #16's round-2
   review queued this item AT THIS RUN BY NAME — "configuration.md's offer
   disclosure omits the K-commit/L-push consequence (P4 edits that file —
   queue it there)" — and P4 had neither fixed it nor named it in the queue,
   the precise way that round-2 note warned a queue item gets silently
   dropped. The configuration page now states that accepting the offer means
   the run commits the constitution as its own separate commit and pushes it
   into the pull request.

Also corrected by the same round: the floor paragraph claimed a run with
`implementer` set reaches DONE unattended; with `handoff` that run PARKS and
never reaches DONE. Scoped to `claude`, matching what the other two surfaces
already said.

**Deferred, with measured reasons**

- **The unescaped pipe character in the Flags-table row.** All three lenses
  found it: the table format splits a cell on a raw pipe even inside a code
  span, so the `--implementer` row parses as three cells against a two-column
  header and the Effect text is DISCARDED when rendered. It is the only
  in-cell pipe in the repository, so no local escaping convention was
  followed. It is deferred because the broken string is CONTRACT-PINNED
  verbatim as site 2 of `contracts/key-contract.md` and T001 mandates
  character-exactness against it: fixing the orchestrator alone creates a
  contract violation, so the contract and the specification must move with it.
  That is a specification change, not a review fix. Honest scope of the
  defect: the orchestrator consumes this file as raw text, so nothing the
  pipeline DOES changes — the loss is to a human reading the table in a
  renderer, and what they lose is the sentence "beats the config key", the
  precedence fact the deferred consent-split question turns on. **Owner queue,
  named explicitly so it cannot be dropped.** Lens 3's sharper point is
  recorded too: the four-site count check reported `1` and was read as proof
  the row was correct. It proved PRESENCE and was reported as proof of a
  PROPERTY — the same failure PR #16 round 1 caught with live mutants.
- **Spending the prose-pin debt now.** Lens 3 argued, correctly, that the seed
  pins COUNTS and not test CONTENTS, and that PR #16 twice tightened
  `prose.bats` test 9 inside the SAME test at zero count movement — so one
  fixed-string check against the flattened G slice would pin the quoted pair
  at `1..9` exactly. The technique is real and is now recorded in research R3
  so the next phase does not have to rediscover it. It stays deferred because
  the plan of record and this run's tasks header both say NO test changes this
  phase, and research R3's "Alternatives considered" already weighed and
  rejected this exact move FOR THIS PHASE with P5/P6 named as the owners of
  the spend. That is a recorded scope decision, not an oversight — unlike the
  `--auto` deferral above, whose stated reason was simply untrue. The hazard
  it leaves is stated plainly: a future edit can delete the entire consent
  contract from the G section and the suite will still report `1..9`, 9 ok.

**Verification after the round-1 fixes**

Four site greps `1`, `1`, `1`, `1`; the Gates row count `1`; both pinned
sentences count `1` each against the flattened orchestrator; the new probe
line count `1` and the leaked gloss count `0`; `handoff/` untouched; the JSON
block parses with `implementer` null; prose `1..9` and portability `1..21`,
30 ok, 0 failures. Every mutated line was echoed back after its write. The
full house suite is phase N's job.

### Phase M round 2 (2026-08-23, PR #17; 3 reviewers on opus)

Lenses: (1) verify round 1's own nine fixes; (2) cross-surface consistency across
all six surfaces; (3) adversarial fresh sweep with live mutation testing on
scratch copies, positive control fired first. **Lens 1's verdict on round 1 is
the headline: all nine fixes are substantively TRUE — none was refuted.** What
the round found instead is twenty findings that dedupe to fifteen, of which
**fourteen are fixed and one deferred**. Severity is falling round on round —
round 1 found a rule that stopped every run and a deferral resting on a
non-existent pin; round 2 found dropped conditions and stale records.

The pattern worth naming, because it bit twice: **five of round 2's findings were
defects in round 1's own fix prose.** Every one is a dropped cell of the same
matrix — {unset, claude, handoff} x {`--auto`, no `--auto`} x {remote, no remote,
`releaseCommand` set or unset}. Round 1's docs floor dropped `--auto`; its
constitution paragraph dropped the no-remote case; its Gates parenthetical
dropped `handoff`. Any future edit to this feature's prose should be checked
against that matrix cell by cell before it is written.

**Fixed in the product**

1. **The Gates section promised the zero-gate run "takes a key or a flag typed
   on purpose"** — false, and self-contradicting. The resolution order places
   the value in a tracked `.delivery-kit.json` that this operator need not have
   written, and the pre-flight paragraph added by the same change says a tracked
   file "must never" pre-answer a gate without disclosure. Now: the combination
   is never a default, but is not necessarily this operator's choice either —
   which is precisely why pre-flight prints the Implementer line and names its
   layer.
2. **The `--from G` / `--resume` re-entry collision.** "Set means pre-answer"
   and "a re-entered gate whose answer is recorded never re-asks" gave
   contradictory instructions, and `progress.sh`'s `from-validate` accepts `G`,
   so the path is reachable by design. Adjudicated toward the existing rule: the
   recorded `gates.G` answer outranks both key and flag, and a disagreeing
   `--implementer` on that command line is never silently applied and never
   silently ignored — say which answer stands and which was passed over.
3. **"The top-level `implementer` field is written beside it" described a write
   nothing performs.** `progress.sh:73` creates it empty at `init`, there is no
   setter, and the State-writes rule does not authorise a hand-write. Converted
   from a description into an INSTRUCTION — descriptions of writes go stale,
   instructions do not: `gates.G` is authoritative, the top-level field is
   created empty and read by nothing, write nothing there. The same sentence now
   names `gates.G` explicitly, closing a gap the status skill had to guess at.
4. **`<implementerSource>` was unrenderable on a resume.** Only the merged value
   is carried across sessions; layer provenance was stored nowhere, and the
   command line is gone. A model would have invented a layer — most naturally
   the reassuring wrong one. Now: record the winning layer beside the merged
   value in `config`, and on a resume print the recorded layer, never a guess.
5. **The Gates parenthetical filed a set `implementer` under "nothing to ask …
   records that and moves on"** — false for `handoff`, where the run parks. A
   literal reader would have moved on to H and implemented with Claude, spending
   exactly the money the key was set to avoid. Scoped to `claude`, matching the
   floor paragraph round 1 had already scoped.
6. **The probe block regained a forward pointer.** Round 1 rightly removed a
   meta-instruction that would have been printed to the operator, but replaced
   it with nothing at the point of use, leaving the block reading as
   unconditional. The render instruction now says the Implementer line appears
   only when the key resolves to a value.
7. **The `--auto` row qualified G and left C and O reading as absolute.** Round
   1's own additions sharpened the old looseness into a contradiction: the Gates
   section says C, G and O can each have nothing to ask. Now uniform for all
   three: `--auto` collapses none of them; C and O stop when they have something
   to ask, and G stops unless `implementer` pre-answered it.
8. **The configuration page's floor dropped `--auto` from its conditions** — so
   it claimed a no-gate run for a case where K and L still stop. Both edges of
   the range are now stated with their full conditions, and the word "ceiling"
   is gone: round 1 named a case ABOVE the claim and kept a word that means
   upper bound.
9. **The constitution consequence over-claimed the push.** With no remote the
   run stops after the commit gate by design, and both gates can be declined.
   Now: the commit is what the offer settles; how far it travels depends on the
   run.
10. **The changelog condition was incomplete** (it needed "and the constitution
    is already set"), and neither STRICT surface disclosed the new pre-flight
    Implementer line — against their own established pattern, since both already
    disclose the constitution probe and the base-branch source. Both now carry
    one clause each; the changelog's short enumeration is kept deliberately.

**Fixed in the records** — every one an annotation, none a rewrite:

11. `contracts/key-contract.md` and `spec.md` FR-003 both still said "No
    existing sentence reworded" while four had been. Both annotated with the
    override and its measured basis.
12. `spec.md` US1's "everything else about G is byte-identical" annotated: G's
    lead was reworded; what the tests and the contract actually guard — the
    pinned pair and the Gates row — is still byte-identical.
13. `spec.md`'s illegal-value clause still carried the refuted "anything but"
    construction that fires on the default. Annotated, so a future rewrite
    cannot reintroduce round 1's worst find from the requirements.
14. `contracts/key-contract.md`'s FR-004 description ("One paragraph", flat
    clarify-only purpose) superseded; `plan.md` gained its FIRST amendment note,
    recording both the four-time override of "add near, never reword" and the
    fact that the shipped change is materially larger than its Summary;
    `research.md` R3's debt list extended past phase I to name round 1's and
    round 2's own additions, with the round-2 mutation measurements and the
    zero-count-movement technique recorded for whoever spends it.

**Deferred, with reason**

- **`pipeline/README.md` as a fifth documentation surface.** It describes the
  consent model ("up to five of them stop and ask") and is silent on a key that
  can remove one of the five. The reviewer that found it states plainly that it
  is NOT false — "up to five" already accommodates a pre-answered G. FR-001's
  four-site inventory is a recorded specification decision; adding a fifth
  documentation site during a review round is scope expansion, not a review fix.
  Owner queue, named.
- Carried unchanged from round 1: the unescaped pipe in the Flags-table row
  (contract-pinned; a specification change) and spending the prose-pin test debt
  (the plan and this run's tasks header both forbid test changes this phase).

**Verification after the round-2 fixes**

Four site greps `1`, `1`, `1`, `1`; Gates row `1`; both pinned sentences `1`
each against the flattened orchestrator; `handoff/` untouched; the JSON block
parses with `implementer` null; changelog headings ordered `[Unreleased]`,
`[1.0.1]`, `[1.0.0]`; prose `1..9` and portability `1..21` — `1..30`, 30 ok, 0
failures. Every mutated line echoed back after its write. Two round-2 reviewers
independently ran the FULL house suite at `1..119`, 119 ok, 0 not ok, 0 non-TAP;
phase N runs it again over the final tree.

### Phase M round 3 (2026-08-23, PR #17; 2 reviewers on opus — the cap is now spent)

Lenses: (1) the MATRIX — walk every sentence rounds 1 and 2 added or rewrote and
name the cell where it is false; (2) a final cross-surface and record-honesty
check. Both were told a clean report was the expected result.

**Both reviewers returned the same verdict independently: NOTHING
RELEASE-BLOCKING.** Ten findings dedupe to eight, every one a single clause, and
all eight are FIXED. Nothing is deferred by this round. The loop converged as it
should have — 11 findings, then 15, then 8 one-clause items, with severity
falling the whole way: round 1 found a rule that stopped every run in existence
and a deferral resting on a pin that does not exist; round 3 found dropped
matrix cells in one paragraph and a miscount in an annotation.

Reviewer 1 stated the standard it applied: report only what would hold a
release, or what costs one clause. Reviewer 2 independently re-measured the
round-1 WITHDRAWN retraction from scratch — `C, G and O still stop.` occurs once
in the whole tracked tree, `STOP AND ASK` once, neither in any `.bats` file, any
contracts file, or `main-plan.md`'s exhaustive pinned-strings list — and
confirmed it accurate. It also counted the shipped configuration section itself
and confirmed the contract's "THREE paragraphs, not one" note exact.

**Fixed — the product (all in the dropped-matrix-cell class the round 2 record
named)**

1. **The configuration page's range paragraph got BOTH ends wrong** — the one
   paragraph whose stated job is "Set this key knowing the whole range". Above
   it, it claimed the release gate stops "with `--auto` or without it", dropping
   `--auto-release`, which collapses that gate; the page had never mentioned
   `--auto-release` at all. It also named only the release gate above the claim,
   where the changelog and the contract both name the constitution offer too.
   Below it, it claimed a no-gate run without requiring a remote — with no
   remote the run stops after the commit gate by design. Both ends now carry
   their full conditions.
2. **"Without `--auto` the commit and push gates stop as they always do"** —
   false in a repository with no remote, which never reaches a push gate. The
   Gates section already carried that carve-out; this sentence dropped it.
3. **The constitution consequence claimed the commit reaches "the pull
   request"** — false with a non-GitHub remote or without `gh`, where the push
   phase prints a comparison link and there is no pull request at all. And its
   closing sentence still said the run "commits" the file, an over-claim on a
   gate the owner can decline. Now: the commit gate puts it in front of you by
   name, and how far it travels depends on the run.
4. **"`--auto-release` is still required before anything publishes"** — false
   when the owner simply answers yes at the release gate. One word: "publishes
   unasked".
5. **"On a resume, print the recorded layer; never guess one"** was unfollowable
   in the cell where the resume itself carries `--implementer` — and the stated
   rationale, "a resume has no command line left to read", is contradicted by
   the re-entry paragraph three sections later, which explicitly contemplates
   exactly that command line. The flag now wins and is what the line names.

**Fixed — the records**

6. **The reword count was four; it is five.** Every record that carried it
   (`plan.md`, `contracts/key-contract.md`, `spec.md` FR-003's note,
   `research.md` R3's unpinned list) missed the probe block's render
   instruction, reworded at M round 2 by round 2's own fix 6. All four
   corrected, each saying plainly that it read "four" until round 3 found the
   fifth.
7. **`spec.md`'s three SCOPED annotations still called "clarify only" a
   CEILING** — the exact word round 2 deleted from the configuration page,
   because a ceiling is an upper bound and cases sit above it. The contract's
   twin note had been fixed and the spec's had not, so two records disagreed
   about the same phrase. All three rewritten to "one point on a range", with
   both ends named.
8. **`spec.md` FR-004 and US2's "one paragraph" claim was unannotated** while
   the contract's identical claim had been superseded at round 2 — the same
   asymmetry, on the same requirement, that finding 7 fixed for FR-003. The
   revised annotation now carries it: three paragraphs shipped.

Also tidied: four reflow warts this run's own edits had left inside the
orchestrator — an orphaned 34-character line in item 9, a short line in item 10,
a 20-character orphan in the Implementer paragraph, and a 110-character G lead
where the paragraph wraps at about 70. Cosmetic only; the G slice's anchor line
still opens on `**G — implementer gate.**`, which is what prose test 9 greps.

**Still deferred after three rounds — unchanged, each with a measured reason**

> **ALL THREE SPENT AT ROUND 4 (2026-08-23), and the paragraph below
> saying the cap is spent is superseded.** The owner ruled "make round 4
> and fix everything, no deferred", recorded as the M-cap gate answer.
> The pipe is escaped (contract re-pinned), the test debt is paid and
> mutation-verified, and the README is a fifth documentation site. See
> the round 4 record below.

- The unescaped pipe in the `--implementer` Flags-table row: contract-pinned as
  site 2, so the fix is a specification change. Rendering-only; the orchestrator
  consumes the file as raw text.
- Spending the prose-pin test debt: the plan of record and this run's tasks
  header both forbid test changes this phase; research R3 records the
  zero-count-movement technique for whoever spends it, with live mutant
  measurements.
- `pipeline/README.md` as a fifth documentation site: not false, and FR-001's
  four-site inventory is a recorded decision.

**Honest residual.** The cap is three rounds and all three are spent, so round
3's eight fixes ship verified by the battery below and by both reviewers' own
mechanical checks — not by a fourth review round. That is the same residual PR
#16 recorded, and it is stated here rather than papered over.

**Verification after the round-3 fixes**

Four site greps `1`, `1`, `1`, `1`; Gates row `1`; both pinned G sentences `1`
each and the pinned `--auto` G sentence `1`, all against the flattened
orchestrator; `handoff/` untouched; the JSON block parses with `implementer`
null; changelog headings ordered `[Unreleased]`, `[1.0.1]`, `[1.0.0]`; prose
`1..9` and portability `1..21` — `1..30`, 30 ok, 0 failures. Every mutated line
echoed back after its write. Both round-3 reviewers ran the full house suite
themselves at `1..119`, 119 ok, 0 not ok, exit 0 on the round-2 tree; phase N
runs it again over the final tree.

### Phase M round 4 (2026-08-23, PR #17) — the cap overridden, every deferral spent

**The gate answer.** `maxReviewRounds` is 3 and round 3 had spent it. The owner
overrode the cap: *"make round 4 and fix everything no deffered and then
continue."* Recorded in the state file under `gates.M`. Phase M was re-entered
from N to do this work, which is what the idempotency rule exists for.

That instruction spent five deferrals — two from phase I, three from rounds 1
and 2 — and each is closed below with what it cost. Scope stated plainly: the
carried P2/P3 owner queue (the comment-only unclosed `<!--`, the inert
analyzer-baseline clause, `git stash` into the never-bend table, the status
skill's vocabulary for a parked run) targets content already merged on `main`
and is NOT this run's findings; it stays queued.

**Three reviewers on opus, no do-not-report carve-outs** — the previous rounds
had three; round 4 had none, including express permission to say the deferrals
should not have been spent. Lenses: (1) the `ask` ripple against a four-value
matrix; (2) adversarial mutation of the new test coverage; (3) cross-surface and
record honesty. Twenty-eight unique findings. **All fixed.**

---

#### What the deferrals cost

**1. `ask` — the command-line re-arm (phase I, security Important 3).** The
value set is now `claude`, `handoff`, `ask`. Without it an operator who cloned a
repository whose tracked `.delivery-kit.json` pre-answered the gate had NO route
back to a stopping gate: `null` in a later layer is silence, not erasure, and
there was no other spelling. `ask` is that spelling, legal at every layer.

The trap in it, caught before the reviewers saw it: **adding `ask` made the
contract-pinned quoted pair FALSE.** It read *"When `implementer` is set (config
or flag), G records the configured answer in `gates` and does not stop"* — and
`ask` IS set, and G DOES stop on it. Freezing the pin would have shipped the
exact defect class rounds 1-3 spent themselves hunting. The pair was reworded
and re-pinned, and `contracts/key-contract.md` records why. It was then re-pinned
a SECOND time later in the round, when a reviewer showed the new `ask` sentence
("it records nothing") reads as "writes nothing to `gates`" — against the rule
that every gate records its answer. It now says `ask` pre-answers nothing and G
records the owner's answer like any asked gate.

Coverage stated rather than implied, since this is the value's whole purpose:
`--implementer ask` on a FRESH run whose configuration says `claude` works
through ordinary precedence (flag beats key). `ask` on a RE-ENTRY whose
`gates.G` already holds an answer works through the re-entry rule below — which
had to be rewritten for it.

**2. The later-layer-`null` merge semantic (phase I, security Important 3's
second half).** Now answered: `null` in a later layer is silence, never an
override; `ask` is the only spelling that overrides toward the stop. Stated in
the Configuration section, on the configuration page and in the changelog. A
round-4 reviewer then caught that stating it as a UNIVERSAL rule — which it is —
quietly makes `verifyCommand`, `releaseCommand` and `devCommand` impossible to
return to unset from a later layer, on the least reversible key in the product.
Round 4 did not create that limit; it documented the merge and exposed it. The
consequence is now stated honestly on both surfaces rather than left as a trap.
Giving those three keys their own re-arm value is real feature work no finding
asked for, and is not smuggled in here.

**3. The unescaped pipe (rounds 1-3, all three lenses).** `\|` escapes added to
the flag row; the contract's site 2 moved with it in the same amendment, since
the whole reason it was deferred was that the contract pinned the broken string.

**4. The prose-pin test debt (recorded by P2, P3 and P4; spent here).** See
below — it was spent twice.

**5. `pipeline/README.md` as a fifth documentation site (round 2).** The
plugin's front door describes the consent model and was silent on a key that
removes one of its five stops. It now names the key and `ask`.

**Security Important 1 is CLOSED, not deferred.** The phase I lens offered three
routes; (a) state the residual invariant honestly and (b) reconcile the
"G always stops" contradiction both shipped at phase I. Route (c) — ruling that
a config-sourced key does not collapse G under `--auto` — was the alternative,
and the re-arm plus the pre-flight disclosure line close the operational gap
that made it attractive. It remains available as a design option; it is not
outstanding work.

---

#### The test-debt spend, and why it was made twice

First shape: six consent sentences pinned inside test 9 and the `--auto` row
inside test 6, keeping the count frozen at `1..9` per PR #16's precedent, plus
one new test for the sites with no host. Mutation-verified: the two mutants
round 2 had recorded as live green both went red.

A round-4 reviewer ran 33 mutations against that and returned the most useful
finding of the run. Two parts:

- **The deletion hazard is genuinely closed.** Deleting the consent contract
  from the G section — one sentence, whole paragraph, or the entire section —
  is red at every granularity. That claim in research R3 is true as written.
- **The claim that the consent surface is "guarded by measurement" was
  OVERSTATED.** The verification had been deletion-shaped. The reviewer
  assembled a document that says the key collapses K, L *and* O, that illegal
  values are silently coerced to `claude`, that the disclosure line is never
  printed, and that a later `null` erases an inherited value — and **the entire
  suite passed it**. Sixteen inversions survived. Fourteen were ordinary
  pin-cuts: the pin stopped one word short of the operative clause, so the
  carve-out survived while the action was inverted.

It also judged the organisation, and was right: hosting the consent contract
inside a test named *"the handoff package names its seven parts"* hid it from
anyone auditing consent coverage, and paying for a frozen count in test-name
accuracy is the wrong trade. So the spend was redone. As shipped:

- `the G pre-answer contract is pinned sentence by sentence` — its own G slice,
  eleven whole sentences including both halves of the re-entry rule.
- `the implementer key's consent surface is pinned outside the G slice` — the
  pre-flight decision walk (SLICED, not file-wide: a reviewer beat the first
  version by pasting item 10 verbatim into an appendix headed "not
  instructions"), the probe block sliced to itself, the merge rule and its
  consequence, and whole sentences from both STRICT surfaces.
- Test 6 keeps the `--auto` row and the publish assurance, where they belong,
  and now greps the FLATTENED file — the raw form went red on an innocent
  rewrap and green on a subject swap.

Every pin now runs through the operative clause. Prose `1..9` -> `1..11`, house
`1..119` -> `1..121`. `main-plan.md`, both acceptance criteria, the contract's
"What must NOT move", `quickstart.md`, `plan.md`, `spec.md` SC-002/SC-003 and
research R3 all carry the override; P5 and P6 are told the debt is PAID.

**Acceptance battery, re-run after the restructure — 17 mutations, 17 correct.**
Positive control first, every mutation echoed back before running, baseline
green before and after. All fourteen published inversions now RED, the
relocation attack RED, and both false positives GREEN (the innocent rewrap, and
an illustrative second JSON block that used to mask a broken canonical one).

The harness itself lied once and the control caught it: an early run reported
every mutation green INCLUDING the positive control, because the mutation driver
invoked `bash` from Python and that shell could not resolve the `/c/...` path to
`bats`. A check that passes on everything proves nothing. Recorded because it is
the second time this project has been saved by firing a control first.

**The residual, stated rather than absorbed.** What grep pinning cannot catch is
prose ADDED beside a pin that contradicts it — the pin still matches. A denylist
naming that target would defeat itself the moment the target changed wording,
which is the anti-pattern this repository's own portability comments warn
against. So it is recorded in research R3 instead. `prose.bats`'s header has
said it from the start: regression guards, not proofs.

---

#### The three product bugs round 4 found in round 4's own work

1. **The re-entry rule contradicted itself.** The Implementer paragraph said a
   typed `--implementer` wins on a resume; the G re-entry paragraph said the
   recorded answer outranks both the key and the flag. Worse, record-always-wins
   killed `ask` in exactly the cell an operator needs it. Resolved by flipping
   the round-2 adjudication, which was made before `ask` existed: the recorded
   answer outranks the CONFIGURATION KEY — an inherited file never quietly flips
   an answer the run holds — but a flag typed on the re-entry command line WINS,
   because typing it is a present-tense act, and it is never applied silently.
   Where it overturns a parked `handoff`, the superseded package is VOIDed,
   which finally gives that rule a stated trigger.
2. **The null-merge over-reach** — fixed as described above.
3. **"`ask` … records nothing"** — fixed, and re-pinned.

Plus, in the same pass: pre-flight item 9 now covers `ask`; the Gates
parenthetical says "a pre-answered `implementer`" rather than naming only
`claude`, which was under-inclusive for `handoff`; and the third illegal-value
site carries the unset carve-out explicitly instead of by implicature.

#### The record defects, and the pattern worth keeping

Reviewer 3's verdict: *"The product is coherent … the haste is entirely in the
records."* Round 4 repeated the exact asymmetry round 3 had just fixed twice —
annotate one instance of a claim, leave the identical claim unannotated three
files over — and then skipped the one artefact every prior round produced, its
own record, while `main-plan.md` already cited that record as evidence. Twenty
stale claims across nine files were corrected in one pass, including
`main-plan.md` contradicting itself about P4's own counts and leaving P5 and the
P6 RELEASE run a number that would have made them call the paid debt a
regression.

The lesson, for whoever ships the next change here: **write the records last.**
Round 4's own F7 — an annotation quoting bytes that changed later in the same
round — is what happens otherwise.

#### Verification

Five site strings count 1 each; both quoted-block sentences and the whole
re-pinned block count 1 against the flattened orchestrator; `| Implementer | G |`
counts 1; `handoff/` untouched; the FIRST configuration JSON block parses with
`implementer` null; changelog headings ordered. Prose `1..11` and portability
`1..21` — `1..32`, 0 failures. Full house suite over the final tree: recorded
below the line. Every mutated line was echoed back after its write.

Full house suite over the final tree, from the repository root:
`1..121`, 121 ok, 0 not ok, 0 non-TAP, exit 0 — the frozen baseline plus
exactly the two owner-ordered tests, and nothing else moved.

#### Round 4 record verification (2026-08-24)

The round-4 fix pass was the largest of the run and was itself unreviewed, so
one focused verifier checked the records against the tree — counts,
quotations, pointers, byte-identity — rather than opening a fifth review
round, which would have defied the owner's "then continue".

**Mechanical core came back green**: prose plus portability `1..32`; the full
house suite `1..121`, 121 ok, 0 not ok, 0 non-TAP, contiguous; all five site
strings count 1 and are byte-identical; the contract's quoted G block appears
once against the flattened orchestrator and is genuinely four sentences;
`| Implementer | G |` counts 1; every command in `quickstart.md` §1-§5 runs
verbatim and matches its documented output; every cross-reference resolves. No
shipped surface still describes a two-value enum, and none still says the
recorded answer outranks the flag.

**Six record defects found and fixed**, every one the same asymmetry this run
kept repeating:

1. SC-003's supersession note described the FIRST shape of the test spend as
   if it had shipped — `1..10`/`1..120` and one new test, written before the
   restructure and never re-trued. It contradicted SC-002 three lines above.
2. The Edge Case bullet freezing the counts was missed while both its
   siblings were updated.
3. `main-plan.md`'s P4 Requirements 1 and 2 still specified a two-value enum
   and quoted the pre-round-4 sentence pair in the present tense — in a
   section the same pass had edited two paragraphs further down, so not
   exempt as historical.
4. US1's Acceptance Scenario 2 quoted the same dead bytes. FR-003 escaped
   only because FR-002's note sits adjacent to it.
5. "FIVE pre-existing regions were reworded" is SEVEN: round 4 itself
   reworded the Configuration section's "`null` means *work it out*" line and
   the H-park paragraph's "the answer stands" sentence, narrated both in this
   record, and updated the count in neither. Corrected in all three places.
6. Three of the eleven pins in the G pre-answer test were fragments while the
   test's own comment claimed whole sentences. Rather than weaken the claim,
   the three pins were extended to whole sentences; the claim is now true.

Two residues are left deliberately and are NOT defects: the round-2 record
still states the pre-flip re-entry adjudication, and the phase-I record still
quotes the pre-`ask` probe line. Both are dated logs of what was true when
written, both are reversed in later round records, and a reader in round order
reaches the truth. Rewriting a dated log to match a later tree would destroy
the audit trail these records exist to keep.
