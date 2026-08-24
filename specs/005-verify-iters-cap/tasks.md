# Tasks: a cap for the J loop

**Input**: Design documents from `specs/005-verify-iters-cap/`
**Prerequisites**: plan.md, research.md, contracts/key-contract.md, quickstart.md

**Tests**: NO test changes this phase. The seed pins prose at `1..11` and the
house suite at `1..121`; growth of either count is a finding. The prose pins for
this phase's EIGHT new sites are RECORDED test debt, not spent — the owner ruled
on it explicitly at the end of phase D (research R3). This is a NEW debt item,
distinct from the one the previous phase paid in full. The enumeration was SIX
until phase I's mutation testing found two more sites with no cover anywhere;
R3 now lists eight and quickstart §6 covers the two manually.

**Organisation**: one task per file region, ordered so nothing consumes what a
later task produces. T002 and T003 both touch
`pipeline/skills/pipeline/SKILL.md` and are therefore SERIALISED, never fanned
out together. T004 and T005 touch a different file each, so they are `[P]`
with each other and with the T002/T003 chain.

## Phase 1: Setup

- [X] T001 Verify the working tree is the `005-verify-iters-cap` branch off
      `main`, that `pipeline/` is clean apart from this run's own edits, and
      CONFIRM phase F.5 has already recorded the pre-change baseline — F.5
      produces it, this task only checks it is there. No file is edited here.

## Phase 2: User Story 1 — the cap itself (Priority: P1)

- [X] T002 Append the Configuration-table row to
      `pipeline/skills/pipeline/SKILL.md`, character-exact per
      `contracts/key-contract.md` site 1, at the END of the table after
      `implementer` — append, never insert (research R1).
      Checkpoint: `grep -cF '| \`maxVerifyIters\` | 5 | Phase J cap |'` prints `1`.

- [X] T003 Rewrite the J paragraph's FINAL sentence in
      `pipeline/skills/pipeline/SKILL.md` and add the owner's duty sentence after
      it, both verbatim per `contracts/key-contract.md`. The paragraph's first
      four sentences are byte-identical afterwards. SERIALISED after T002 — same
      file. This is the ONE reworded sentence in the change; research R2 records
      both justifications.
      Checkpoint: against the whitespace-flattened file, the replacement sentence
      and the duty sentence each count `1`, and the replaced sentence counts `0`.

## Phase 3: User Story 2 — the configuration page (Priority: P2)

- [X] T004 [P] Append `"maxVerifyIters": 5` to `pipeline/docs/configuration.md`'s
      JSON block after `implementer`, and append the key-table row after
      `implementer`'s — both character-exact per `contracts/key-contract.md`
      sites 2 and 3. Note the deliberate asymmetry recorded in the contract: this
      key's default is the NUMBER `5`, not `null`, because unlike the command
      keys it has a real default. STRICT vocabulary surface.
      Checkpoint: both greps print `1`; the first JSON block parses under `jq`
      with `.pipeline.maxVerifyIters == 5`.

## Phase 4: User Story 3 — changelog (Priority: P3)

- [X] T005 [P] Append one Added entry to the existing `### Added` list under
      `## [Unreleased]` in `pipeline/CHANGELOG.md`: the key, its default of 5,
      that a breach is a conditional stop, and that a breach waved through is
      recorded into the commit message and the pull request. No version heading.
      STRICT vocabulary surface.
      Checkpoint: `grep -n '^## \[' pipeline/CHANGELOG.md | head -3` shows
      `[Unreleased]`, `[1.0.1]`, `[1.0.0]` in that order.

## Phase 5: Polish & validation

- [X] T006 Run quickstart §1–§5 in full: the three site greps, the identity
      check, the flattened J-paragraph greps including the count of `0` for the
      replaced sentence, prose `1..11`, the full house suite `1..121` (growth
      exactly zero), `git status --porcelain -- handoff/` empty, the JSON parse,
      and the changelog heading order. Record every output verbatim in Completion
      notes — measured, never predicted.

## Dependencies & Execution Order

T001 first. T002 then T003 (same file, serialised). T004 and T005 are `[P]` with
each other and with the T002/T003 chain — three different files, no shared
region. T006 last, after everything.

Fan-out cap is 3. The largest legal batch here is {T003-chain, T004, T005} once
T002 has landed.

## Implementation Strategy

Every sentence written is checked against all eight cells of the feature's
matrix before its task is marked done: {cap not reached, cap reached and waved
through, cap reached and declined, hard failure} × {`--auto`, no `--auto`}. Four
review rounds last phase found the same defect shape repeatedly — a sentence
true in the case its author pictured and false in one they dropped — and this is
the cheap prevention.

Echo every mutated line back after writing it. No test guards this prose, and
the previous phase proved a no-op edit can otherwise read as success.

## Completion notes (evidence)

### T001–T006 (2026-08-24, implemented by Claude in-session per the G answer)

All six tasks complete. Outputs below are measured, pasted, never predicted.

**T002** — Configuration-table row appended at the END of the table, after
`implementer` (research R1: append, never insert). Mutated line echoed back:
`| \`maxVerifyIters\` | 5 | Phase J cap |` at SKILL.md:105.

**T003** — the J paragraph's final sentence REPLACED and the owner's duty
sentence added after it, both verbatim per the contract. The paragraph's first
four sentences are byte-identical. Flattened checks: replacement sentence `1`,
duty sentence `1`, J opener `1`, and — the one that matters — the REPLACED
sentence "Loop until clean against baseline or a hard failure stops the run."
counts **`0`**. It is gone, not left contradicting its replacement two lines
away, which is the exact defect four review rounds chased last phase.

**T004** — JSON entry and key-table row appended after `implementer` in
`pipeline/docs/configuration.md`. The `implementer` line gained its trailing
comma; that is the only pre-existing character touched, and it is punctuation,
not prose. First JSON block parses under `jq` with
`.pipeline.maxVerifyIters == 5` -> `true`.

**T005** — one Added entry under the existing `## [Unreleased]` heading, placed
at the TOP of the `### Added` list. Headings still order
`5:## [Unreleased]`, `55:## [1.0.1] - 2026-08-22`, `74:## [1.0.0] - 2026-08-20`.

**T006 — quickstart §1–§5, verbatim**

- §1 three site greps: `1`, `1`, `1`.
- §2 identity: both files print exactly `` `maxVerifyIters` ``; counts `2` and `2`.
- §3 flattened J greps: `1`, `1`, `1`, and `0` for the replaced sentence.
- §4 prose+house: full house suite `1..121`, **121 ok, 0 not ok, 0 non-TAP,
  exit 0** — byte-for-byte the F.5 baseline recorded before any edit, so growth
  is exactly zero and there is nothing to classify.
- §4 `git status --porcelain -- handoff/`: empty.
- §5 JSON parse `true`; changelog headings ordered as above.

**Matrix check.** Every sentence written was read against all eight cells
before its task was marked done: {cap not reached, cap reached and waved
through, cap reached and declined, hard failure} × {`--auto`, no `--auto`}. The
cell that needed care is {cap reached and waved through} × {`--auto`}: under
`--auto` the commit and push gates are collapsed, so a waved-through red would
otherwise reach a pull request with no human between it and the reviewer. That
is precisely the cell the owner's duty sentence covers, and it is why the
sentence names the pull-request body and not only the state file.

All work left uncommitted — the commit gate has not run.

## Phase 6: Convergence

- [X] T007 Add J to the Gates section's conditional-stop list in
      `pipeline/skills/pipeline/SKILL.md` — it reads "a cap breach in C, F or M"
      and this change made that false, per FR-002 (contradicts). CRITICAL class
      by shape though not by constitution: a reader consulting the canonical
      list of conditional stops is told J has none.
- [X] T008 State at J that a cap breach SHOWS the remaining failures before it
      asks, per FR-003 (partial). "Conditional stop" carries this by convention
      and C states it outright; J currently leaves it to the reader. SERIALISED
      after T007 — same file.

## Phase 7: H.7 — simplify (2026-08-24, resumed session)

Four cleanup reviewers on opus — reuse, simplification, efficiency, altitude —
dispatched in one message against the uncommitted `pipeline/` diff, scoped to
`codeRoots` (`pipeline`, `.claude-plugin`). Each brief carried the contract pins
verbatim so no reviewer could propose reverting T008's recorded insertion.

**Result: 3 of 4 clean. One fix applied, one finding carried to phase I, three
deferred with reasons.**

- [X] T009 FIXED — the changelog entry was INSERTED before the `implementer`
      entry instead of APPENDED at the end of the `### Added` list, which is what
      T005 itself instructed and what research R1 ("append, never insert") ruled.
      Verified against the convention rather than asserted: `git show 4f959f4 --
      pipeline/CHANGELOG.md` appends with trailing context `## [1.0.1]`, so the
      Unreleased list runs oldest -> newest and the newest entry belongs last.
      The inserted placement also shifted the `implementer` entry down ten lines
      — the exact risk R1 exists to avoid.
      Fix: the ten lines were MOVED, not rewritten. Proof it is a pure reorder:
      `diff <(sort old) <(sort new)` -> identical, and the line count is `117`
      before and after. Order is now constitution -> handoff package ->
      implementer -> `maxVerifyIters`, matching the git chronology, and the diff
      hunk's trailing context is now `## [1.0.1]`, the same shape as `4f959f4`.
      Nothing pinned moved: `pipeline/tests/prose.bats` checks the changelog with
      flattened `grep -qF` content assertions, never line anchors, and the
      contract's FR-004 pins the entry's CONTENT and that it sits under
      `## [Unreleased]` — not its position in the list.
      Verification after the move: prose `1..11`, 11 ok, 0 not ok, exit 0;
      portability `1..21`, 21 ok, 0 not ok, exit 0. Headings still order
      `5:## [Unreleased]`, `55:## [1.0.1] - 2026-08-22`, `74:## [1.0.0] - 2026-08-20`.

### Carried to phase I (not deferred — a lens must rule on it)

- The duty sentence names a STORE, not a FIELD: "record the surviving failures
  in the state file" never names the key. Everywhere else this product names the
  key it writes (`test_baseline`, `analyze_changelog`, `gates`), and the G slice
  goes as far as pinning a field NOT to write. The duty spans J -> K -> L, and K
  and L are documented safe handoff points; a run that breaches J, is waved
  through, and hands off at K resumes with the state file as its only memory and
  finds no named field to read. Raised independently by the altitude reviewer as
  a resume-path gap and by the efficiency reviewer as a K/L silence — one
  mechanism, deduped. The minimal complete fix names a key inside a
  CONTRACT-PINNED sentence, so it is phase I's contract-compliance lens to rule
  on, exactly as H.5's convergence amended the contract on the record.

### Deferred, with reasons

- **Reuse, low and contestable by its own author**: the changelog entry's closing
  "A hard failure still stops the run outright." repeats the tail of the pinned J
  sentence and describes behaviour this change did not alter. KEPT: it is the
  contrast that makes "conditional stop" legible, which is precisely why the
  contract-pinned J sentence carries the same clause; FR-004 does not forbid it;
  and the simplification reviewer independently found no clause in that paragraph
  that says the same thing twice. Removing it would edit a STRICT surface for no
  reader gain.
- **Altitude, out of scope by construction**: whether ALL cap breaches should
  record what survived. The reviewer argued it both ways and landed where the
  owner already did — C, F and M all breach BEFORE a commit exists, so a
  generalised rule would degenerate to "record in the state file" for three of
  four caps. Editing C, F or M is outside this run's one-key scope.
- **Altitude, pre-existing**: `pipeline/skills/status/SKILL.md` names gate phases
  and does not report a run parked at a cap breach. True for C, F and M before
  this change; J adds a fourth. Already carried in the owner queue.

### Reviewer evidence worth keeping

- The replaced sentence is GONE, re-proved independently this session: flattened
  count `0` in all three changed files, with positive controls of `1` for the new
  J sentence and `1` for the duty sentence. A paraphrase sweep found no reworded
  survival anywhere in `pipeline/` or `.claude-plugin/`.
- Suite size counted from `^@test` rather than trusted: 4 + 21 + 51 + 20 + 14 +
  11 = **121**, prose **11**. Growth exactly zero; the diff touches three `.md`
  files and zero test files.
- Site survey: `maxVerifyIters` is present at every site class the three sibling
  LOOP caps populate (orchestrator table, phase paragraph, conditional-stops
  line, configuration JSON, configuration key table) plus a changelog entry the
  siblings predate. No site was missed. `maxParallelAgents` is correctly absent
  from the conditional-stops line — it is a fan-out cap, not a loop cap.
- No cap inventory is left stale: `SKILL.md`'s generic "every cap breach" and the
  red-flags row already cover J without edit, and the one enumerating sentence
  was updated to "C, F, J or M".

## Phase 8: I — deep review (2026-08-24, resumed session)

`pipeline:spec-review`, three lenses dispatched in ONE message on opus against
the uncommitted `pipeline/` diff plus `specs/005-verify-iters-cap/`. Each brief
carried the settled facts verbatim — T008's recorded insertion, the contract
pins, the frozen counts, the owner's record-not-spend ruling, and H.7's changelog
move — so no lens spent its round re-litigating a decision already made.

**Verdicts: contract COMPLIANT. Security no-critical, two Important. Tests PASS
with two Important. Four fixes applied, four items deferred with reasons.**

### The carried question, RULED

The H.7 hand-off asked the contract lens to rule, against FR-003a's actual text,
whether the duty sentence naming a STORE ("the state file") and not a FIELD is a
gap. **Ruled: NOT a gap — satisfied as written.** FR-003a's own words ask for the
store and get it near-verbatim. The premise behind the objection — "everywhere
else this product names the key it writes" — is empirically FALSE, and this was
verified in the file rather than taken on the lens's word: `SKILL.md` says
"record the answer in the state file" (missing tool), "record that in the state
file and move on" (`releaseCommand` unset) and "Write the failure into the state
file" (any phase failure), none naming a field. The G slice's named field is the
outlier precisely because it FORBIDS a write, a different speech act. `gates`
already fits by the standing rule "Record every gate's answer in the state file's
`gates` key", with `gates.constitution` as direct precedent for a CONDITIONAL
STOP — not a table gate — landing there.

The security lens rated the same mechanism Important on a resume trace. Both
readings are recorded; the contract lens was the authority the question was
carried to, it ruled with evidence the security lens did not have, and SC-005's
own words make the state file the SECONDARY carrier ("from the commit message and
the pull-request body alone, without reading the state file"). **DEFERRED to the
owner queue with its fix ready** — see the deferred list below.

### Fixes applied

- [X] T010 FIXED (security, Important) — **the redaction discipline did not reach
      the outbound path this run's own sentence opened.** Redaction is stated
      exactly once in the orchestrator and is bound to the handoff package, an
      artefact that stays on the machine or goes to one chosen implementer. The J
      duty carries raw `testCommand` failure output into a commit message and a
      pull-request body — text that LEAVES the machine — and under `--auto` K and
      L are collapsed, so no human reads that body before it is published. Test
      output routinely carries absolute paths with usernames, hostnames,
      environment values echoed in assertion diffs, and tokens inside HTTP error
      bodies. No lens rebutted this one.
      Fix shape: ADDITIVE — a third paragraph after the duty paragraph, extending
      the existing discipline BY NAME rather than inventing a second one. Both
      pinned sentences are byte-identical afterwards; FR-005 is not engaged
      because no existing sentence was made false. Amended on the record in
      `contracts/key-contract.md`, H.5-style, never quietly.
      Three constraints checked before writing and MEASURED after: no occurrence
      of `maxVerifyIters` (section 2 count still `2`), neither section 3 grep
      string reproduced (`1`, `1`, `1`, `0`), and no `^**` heading line added
      that would move a `prose.bats` slice. Prose + portability `1..32`, 32 ok,
      0 not ok, exit 0.

- [X] T011 FIXED (tests, Important) — **quickstart section 3 was location-blind.**
      It flattened the WHOLE of `SKILL.md` and grepped file-wide, so nothing
      bound the cap sentence or the duty sentence to phase J. A mutation
      relocated both into an appendix headed "notes, not instructions", leaving J
      with no loop bound, no cap and no termination statement at all — and the
      full `1..121` suite AND all eleven quickstart checks stayed green. That is
      the same relocation hole `prose.bats` already learned to slice for.
      Fix: section 3 now slices the J region with `awk` from the J heading to the
      K heading, flattens THAT, and greps it. The replaced-sentence check stays
      whole-file on purpose — a resurrection anywhere is a finding. Measured
      after: slice is 21 lines; `1`, `1`, `1`, `1`, and `0` for the replaced
      sentence.

- [X] T012 FIXED (tests, Important) — **two shipped sites had no check anywhere,
      and one was missing from R3's enumeration.** Reverting T007 (`C, F, J or M`
      back to `C, F or M`) and rewriting the changelog entry to announce an
      unbounded loop with a different default BOTH passed the full suite and
      every quickstart section.
      Fix: R3's enumeration goes SIX -> EIGHT (site seven the conditional-stops
      line, site eight the redaction paragraph T010 added), and a new quickstart
      section 6 covers the two manually. This is COMPLIANCE with the owner's
      ruling, not a re-argument of it: "RECORD, do not spend" makes the record's
      completeness the whole point, and R3 says in its own words that the sites
      are named "so a later phase can spend this without rediscovering them". No
      test was added and no count moved.
      **One correction to the lens that found it**, made rather than parroted:
      it reported the changelog entry as also absent from R3's enumeration. It
      was not — R3 already said "The changelog entry makes a sixth if you count
      it, and it should be counted". What was true, and is the real point, is
      that no COMMAND anywhere read the changelog; section 6 now does.

- [X] T013 FIXED (tests, Minor x2) — quickstart honesty. Section 2 was headed
      "Name-and-default identity" while its commands compared only the NAME token
      and mention counts; a mutation drifting the orchestrator row's default to
      `3` against the JSON block's `5` passed every command in it. Section 2 is
      retitled to what it measured AND gained two commands that actually read the
      two defaults and compare them (measured `5` and `5`). Section 3's prose
      overclaimed what its `0` proves — a PARAPHRASE inserted two lines from the
      cap sentence passes it — so section 3 now says so plainly and carries the
      cheap negative grep (measured `0`), while stating that the full paraphrase
      sweep was run by hand and no command here reproduces it. Section 3's
      comment claiming to pin "the four untouched J sentences" now says it pins
      the OPENER only, which is what the command does.

### Deferred, with reasons

- **The duty names a store, not a field** (security Important / contract Minor).
  RULED satisfied above; to the owner queue with the work already done so nothing
  is rediscovered. Exact sentence, ready to append after the duty paragraph:
  "The record lands under `gates.J`, beside the answer that waved it through —
  the same key every answered stop already writes." Three constraints bind any
  adopted wording: it must contain NO occurrence of `maxVerifyIters` (quickstart
  section 2 pins that count at `2`), it must reproduce neither section 3 grep
  string, and adopting it requires an H.5-style recorded amendment to the
  contract.
- **No stated domain for `maxVerifyIters`** (security Minor). `0` or a negative
  value breaches immediately — which fails SAFE, toward more human involvement,
  not less — but some conventions read `0` as "unlimited" and the prose states no
  domain. Deferred because the fix lands INSIDE contract-pinned strings (both the
  orchestrator row and the configuration key row are pinned sites), the spec
  already records the absence as a deliberate assumption, and all four sibling
  caps share the shape. Validation and probe-block disclosure are a reasonable
  deferral against that precedent — recorded here so it is not rediscovered.
- **"Waved through" collides with the red-flags heading** (security Minor, low
  confidence by its own author). The heading reads "findings are fixed or
  surfaced, never waved through", and the diff uses "waved through" three times
  as the SANCTIONED act. Different actors — the model silently skipping versus
  the owner deciding at a stop — and the heading's own "surfaced" arguably covers
  the J case, which is shown, asked, recorded and published. Deferred: the fix
  lands inside pinned strings, and the lens rated its own confidence low.
- **`measurements` is a dangling key** — named in the orchestrator's ground rules
  as a hand-written state key but present in no script, no state file and no
  test. PRE-EXISTING, outside this run's one-key scope, recorded for the queue.

### Evidence

Every quickstart section re-run VERBATIM after all four fixes, from the
repository root, measured and pasted — never predicted:

- Section 1: `1`, `1`, `1`
- Section 2: both files print exactly `` `maxVerifyIters` ``; counts `2` and `2`;
  defaults read out of each file and compared: `5` and `5`
- Section 3: J slice 21 lines; `1`, `1`, `1`, `1`; replaced sentence `0`
  whole-file; paraphrase sweep `0`
- Section 4: prose `1..11`, 11 ok, exit 0; `git status --porcelain -- handoff/`
  empty
- Section 5: `true`; headings `5:## [Unreleased]`, `55:## [1.0.1] - 2026-08-22`,
  `74:## [1.0.0] - 2026-08-20`
- Section 6: `1`, `1`

The contract lens independently re-measured the FULL house suite during its walk
and recorded `1..121`, 121 ok, 0 not ok, 0 non-TAP, exit 0. That measurement
PREDATES T010's redaction paragraph, so it does not discharge phase J — J runs
the full suite again over the final tree, which is the point of J.

Mutation testing (tests lens) ran on an isolated copy under the scratchpad, never
on the working tree, and the three changed files were verified byte-identical by
`sha256` afterwards. Thirteen mutations: the existing `prose.bats` pins bite on
inverted content after both the append and H.7's reorder, the JSON comma the diff
added is guarded twice over, and the H.7 changelog move is order-independent BY
CONSTRUCTION — the changelog pins are flattened `grep -qF` content checks with no
line anchors, and the one order-sensitive changelog consumer skips `[Unreleased]`
entirely. Three mutations passed everything and drove T011 and T012.
