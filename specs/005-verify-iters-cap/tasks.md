# Tasks: a cap for the J loop

**Input**: Design documents from `specs/005-verify-iters-cap/`
**Prerequisites**: plan.md, research.md, contracts/key-contract.md, quickstart.md

**Tests**: NO test changes this phase. The seed pins prose at `1..11` and the
house suite at `1..121`; growth of either count is a finding. The prose pins for
this phase's TWELVE new sites are RECORDED test debt, not spent — the owner ruled
on it explicitly at the end of phase D (research R3). This is a NEW debt item,
distinct from the one the previous phase paid in full. The enumeration was SIX
at phase D, eight after phase I's mutation testing, nine after M round 2 adopted
the `gates.J` sentence — and TWELVE once M round 3 stopped incrementing and
RE-ENUMERATED from the run's full diff. R3 carries the list; read the list, not
the number. All twelve have manual quickstart cover and none has an automated
pin, which is exactly the recorded debt.

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
  record what survived. **CORRECTED at M round 1 (2026-08-24)**: this deferral
  previously rested on "C, F and M all breach BEFORE a commit exists", which is
  FALSE — the phase order is K (commit), L (push and open the pull request),
  then M (review), so M breaches AFTER publication. Only C and F breach before a
  commit exists. The deferral STANDS, but on the ground that is actually true:
  editing phases C, F or M is outside this run's one-key scope. The premise is
  corrected rather than the conclusion, because the conclusion never needed the
  premise. And the correction raises a NEW owner-queue item in its own right:
  a waved-through M cap breach leaves unfixed REVIEW findings on an
  already-public pull request, and M carries no record-the-red duty at all. That
  is a real exposure this review discovered, recorded here and in research R4.
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

- **The duty names a store, not a field** — **PARTIALLY ADOPTED at M round 2;
  round 3 corrected this header, which had claimed the whole entry closed while
  consumer (b) and half of (c) were still open. See T029.** See the M round 2 record below for why the reversal is not a
  reversal of the FR-003a ruling. The analysis below stands as written and is
  kept, because it is what the adopted sentence had to satisfy.
  (security Important / contract Minor;
  pull-request review round 1 raised it three more times from three more angles).
  The FR-003a ruling STANDS — the requirement asks for a store and gets one, on
  three same-document counter-examples. But the queue entry is UPDATED here to
  carry the finding's full weight, because round 1 found consumers the phase I
  ruling never weighed:
  (a) **phase N** re-runs the suite and re-classifies, and without a findable
  record it re-owns failures the owner already accepted. **CLOSED**: T014 fixed
  the classification half in N's own paragraph, and T019's `gates.J` gave N the
  address it had to read from;
  (b) **a `--from K` or `--from L` re-entry** never reads J's paragraph at all,
  so neither phase is told to carry the record even if one exists. **STILL OPEN
  — reopened at round 3**, deferred on SC-004, which allows this cap exactly one
  documented addition and puts it in J's own paragraph;
  (c) **J's own iteration count and wave-through answer are not durable**, so a
  `--resume` into J restarts the loop at zero and re-asks a question the owner
  already answered — F logs each iteration in `analyze_changelog` and J logs
  nothing. **HALF CLOSED**: T024 removed the dangerous half, so a re-entry can no
  longer INHERIT an answer for failures nobody saw. The iteration log is **STILL
  OPEN — reopened at round 3**; what remains is wasted iterations, not a silent
  wave-through.
  The ready sentence addresses the whole family, because a recorded gate answer
  is also what suppresses a re-ask: "The record lands under `gates.J`, beside the
  answer that waved it through — the same key every answered stop already
  writes." Three constraints bind any adopted wording: it must contain NO
  occurrence of the key's name (quickstart section 2 pins that count at `2` — and
  see that section's own tripwire note, which says to update the number rather
  than contort the prose), it must reproduce neither section 3 grep string, and
  adopting it requires an H.5-style recorded amendment to the contract.
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

## Phase 9: M — pull-request review, round 1 of 3 (2026-08-24)

`/code-review 18 high` against PR #18. Fifteen findings. `gh` was again reported
ABSENT by `preflight.sh` and is again a FALSE NEGATIVE — the script runs under
bash, which cannot see the Scoop shim; PowerShell finds it, and M was NOT
skipped. Five fixes applied, one finding REJECTED on measured evidence, nine
deferred or already-deferred with reasons.

### Rejected on evidence — not deferred, refuted

**"Phase N is an unbounded loop, so the cap is defeated one phase later and the
changelog's 'last unbounded loop' claim is false."** MEASURED and REJECTED — the
verdict stands, and the METHOD BEHIND IT WAS CORRECTED at round 2.

**CORRECTED at M round 2 (2026-08-24)**: this entry originally rested on
`grep -n 'Loop until\|loop until\|looped\|capped loop'`, reported its four hits,
and then asserted "the four loops are C, F, J and M" — but F is NOT among those
hits, because F's heading reads "analyze, **auto-fix loop**" and no alternative
in that pattern matches it. The entry therefore named a loop its own evidence had
missed: a method that cannot see F cannot distinguish N from F, so it proved
nothing about N. Round 2 caught it. This is the same defect class as T016 below,
shipped in the same round — stated plainly rather than tidied away.

The sound enumeration, run at round 2 and pasted verbatim. Every phase HEADING
containing "loop": C ("clarify, looped"), F ("analyze, auto-fix loop"), M ("PR
review, capped loop"). Every CAP STATEMENT: `maxClarifyPasses`, `maxAnalyzeIters`,
`maxVerifyIters`, `maxReviewRounds` — which adds J, whose heading does not carry
the word, and which is exactly why the heading grep alone was insufficient.
Union: **C, F, J, M — four loops, each capped.** N appears in NEITHER list: no
loop keyword, no cap statement, no iteration language. Its paragraph is a single
pass — run, classify, commit fixes, push. The changelog's claim is TRUE as
shipped, now on evidence that actually supports it.

The finding's SECOND half was real and IS fixed below — N re-classifies against
the baseline with no knowledge of a wave-through, so it would re-own failures the
owner accepted. That is a consumer problem, not a loop problem.

### Fixes applied

- [X] T014 FIXED — **phase N would re-own accepted failures.** A red the owner
      waved through at J is still new-against-baseline when N re-classifies, and
      N's "new failures are this run's to fix" made no exception. A literal
      executor would re-fix what a human had already ruled not-to-fix, which
      overrides the owner as surely as marking it resolved would. This is exactly
      FR-005's standard — the change made an existing sentence false in one cell,
      so it is fixed and the override recorded — and the T007 precedent.
      Checked before editing: N's paragraph is pinned by NOTHING. `prose.bats`
      and `portability.bats` carry no assertion on it, and the contract does not
      mention N. The added sentence deliberately says "J's cap" and not the key's
      name, so quickstart section 2's count stays at `2` (measured `2` after).

- [X] T015 FIXED — **the carry into a pull-request body is unsatisfiable on L's
      own degraded paths.** L names three: no remote (stop after K), a non-GitHub
      remote, and no `gh` (push and print a comparison URL). In all three there is
      no pull-request body, yet the duty stated the carry unconditionally, so an
      executor would block looking for a body that will never exist or invent
      one. Every other degradation in this document names its fallback; this one
      did not. Two sentences added: the commit message is then the sole outbound
      carrier and the duty is discharged there.
      The contract's verbatim quote of that paragraph was UPDATED in the same
      breath and carries an EXTENDED note, so the contract never holds a stale
      half. Proved rather than asserted: the contract quote and the shipped
      paragraph were extracted, flattened and compared — both 632 characters,
      byte-for-byte identical.

- [X] T016 FIXED — **a FALSE claim in this run's own records, in two copies.**
      Research R4 justified J's unique duty with "C, F and M all breach BEFORE
      the commit gate has anything to commit", and `tasks.md` repeated it as
      "C, F and M all breach BEFORE a commit exists". Both are FALSE. Verified
      independently rather than taken on the reviewer's word, with
      `grep -n '^\*\*[KLMN]'`: the ORDER is K (commit), L (push and open the pull
      request), M (review), N (re-verify) — so M breaches AFTER the commit exists
      AND after the branch and the pull request are public. Only C and F breach
      before a commit exists.
      **CORRECTED at M round 2**: this entry originally recorded the four LINE
      NUMBERS as 488 / 495 / 501 / 506. They were true when measured and false by
      the time the round's own commit was written — T015 inserted four lines above
      them in the same round, and round 2's edits moved them again. The claim that
      matters is the ORDER, which is stable and is what the finding turned on; the
      line numbers were incidental precision that decayed inside a single round,
      so they are stated as an order above instead. Recording a measurement that a
      same-round edit invalidates is the defect round 2 named, and it is corrected
      here rather than left to be trusted.
      Both copies corrected IN PLACE with dated CORRECTED notes, never silently.
      The owner's ruling is untouched; only the ground under it is narrowed: J's
      claim is not "the only breach after which code is public" but "the last
      FULL-SUITE check", where a surviving red is read as a green suite.
      This is the fourth appearance of this defect class in this project's
      records — a claim true of the case its author pictured and false in one
      they dropped. It was caught here by a reviewer, not by the author, which is
      what M is for.

- [X] T017 FIXED — **the generalise-the-duty deferral rested on the dead premise
      T016 killed.** The deferral STANDS, re-recorded on the ground that is
      actually true: editing phases C, F or M is outside this run's one-key
      scope. The conclusion never needed the false premise. And the correction
      raises a NEW owner-queue item in its own right, recorded in R4 and here: a
      waved-through **M** cap breach leaves unfixed REVIEW findings on an
      already-published pull request, and M carries no record-the-red duty at
      all. Real exposure, discovered by this review, out of scope to fix here.

- [X] T018 FIXED — **quickstart section 2's mention counts were a promise the
      document could not keep.** Pinning both files at exactly two mentions
      FORBIDS legitimate documentation: stating the value's domain, giving the
      key a narrative section the way `implementer` has one, or naming phase J in
      the configuration row would each add a third mention and fail the check.
      Phase I had already been forced to write its deferred fix sentences under
      the constraint "must contain NO occurrence of the key name" — the tripwire
      wagging the document. Both counts are now annotated as a TRIPWIRE, not a
      promise, with the instruction to UPDATE THE NUMBER rather than contort the
      prose, and a pointer to the checks that actually protect behaviour.

### Deferred at round 1, with reasons

- **The duty names a store, not a field** — the FR-003a ruling from phase I
  STANDS, but round 1 raised it three more times from three more angles and the
  queue entry above was UPDATED to carry them: phase N as a consumer, a
  `--from K`/`--from L` re-entry that never reads J's paragraph, and J's own
  iteration count and wave-through answer not being durable across a resume
  (F logs each iteration in `analyze_changelog`; J logs nothing). The ready
  `gates.J` sentence addresses the whole family, because a recorded gate answer
  is also what suppresses a re-ask.
- **K and L are never told to carry the record.** Deferred: SC-004 rules the
  duty belongs in J's own paragraph "rather than being a trap", so the silence is
  spec-sanctioned. Folded into the queue entry above as consumer (b).
- **The redaction paragraph's scope is ambiguous** — it binds the outbound carry,
  leaving the state-file record governed by nothing. Deferred: the state file is
  a LOCAL artefact, and the product already stores raw test output there by
  design (F.5 records `test_baseline` verbatim), so the outbound paths are
  precisely what the new rule needed to cover.
- **`maxVerifyIters` collides with `verifyCommand`** — the configuration page
  calls the key a "Verification fix-loop cap" while `verifyCommand` on the same
  page means the N.5 runtime check, so a reader can point it at the wrong phase.
  Real, and the siblings do not have the problem (`maxAnalyzeIters` pairs with
  `analyzeCommand`). Deferred: the key's NAME came from the seed and the row is
  contract-pinned site 3; disambiguating it moves a pinned string.
- **The configuration row names two carriers where the other two files name
  three** (it drops the state file). Weighed once already by the contract lens
  and dismissed — the key table is a summary, `SKILL.md` is normative — and the
  row is contract-pinned site 3.
- **No stated domain for the key**, **the "waved through" vocabulary collision**,
  **the status skill's parked-run blindness**, and **the unpinned sites** (eight
  at the time of this round; re-enumerated to twelve at round 3):
  all already deferred at H.7 or I, with reasons unchanged. Round 1 added no new
  argument to any of them; the status item now has J as a fourth case.

## Phase 9b: M — pull-request review, round 2 of 3 (2026-08-24)

`/code-review high` against the fixed working tree (HEAD equals the pushed
branch, so the round-1 fixes were the whole diff). Five findings, ALL REAL, and
three of them are defects in round 1's own records. Five fixes applied, zero
deferred, zero rejected.

Round 2 independently re-verified what round 1 claimed: the contract quote and
the shipped redaction paragraph byte-identical at 632 characters, the key's
mention count still `2` in both files, every quickstart pin at its documented
count, prose + portability `1..32`, T014's "N's paragraph is pinned by NOTHING",
and the phase order that T016 turned on.

### The reversal, stated plainly

- [X] T019 **ADOPTED — `gates.J` names the record's address.** Phase I DEFERRED
      this, and that deferral was correct on the evidence it had. What changed is
      not repetition: **round 1 shipped a READER.** T014 added a sentence to phase
      N ordering it to treat a failure the owner accepted at J's cap breach as
      inherited rather than re-owned — and nothing findable told N which failures
      those are. A reader pointed at an address that does not exist is a NEW
      defect introduced by that fix, not the old debt resurfacing, and the right
      response to a defect you introduced this round is to fix it this round.
      **This does NOT overturn the contract lens's FR-003a ruling, and the record
      must not be read that way.** That ruling stands: FR-003a asks for a STORE
      and the shipped sentence gives it one, and the orchestrator names a store
      without a field in three other places. The sentence is adopted for the
      consumer, not for the requirement.
      The contract lens's own ready sentence was used verbatim, as the duty
      paragraph's new final sentence. `gates` needed no other change — it is
      already in the ground rules' list of hand-written state keys, and
      `gates.constitution` is direct precedent for a CONDITIONAL STOP, not a table
      gate, recording its answer there. One sentence closes the whole family
      round 1 raised: N has an address to read, a `--from K` re-entry has one to
      carry, and a recorded gate answer is also what suppresses a re-ask, which is
      the resume-into-J question.
      Constraints measured after: key mention count `2`; every section 3 grep at
      its documented value; a NEW section 3 grep added for the sentence itself,
      because a shipped sentence with no check is the relocation hole phase I
      already found once.

### The other four

- [X] T020 FIXED — **round 1 filed its carve-out under the wrong topic
      sentence.** The unconditional instruction lives in the DUTY paragraph;
      round 1 appended the exception to the REDACTION paragraph, whose opener
      scopes it to credential handling. An executor reading the duty never
      reaches the exception, so the fix did not sit where the defect was. The two
      sentences were MOVED into the duty paragraph and the redaction paragraph is
      restored to its phase-I form — which also makes the phase-I amendment's
      verbatim quote true again. Nothing forced the original placement; both
      quickstart-pinned strings are byte-identical either way.
      Round 2 also caught an OVERSTATEMENT in the moved wording: on L's
      no-remote path the commit never leaves the machine at all, so calling the
      commit message "the sole OUTBOUND carrier" was false. It now reads "the
      commit message carries it alone."
      Both contract quotes were re-extracted, flattened and byte-compared against
      the shipped prose after the move: redaction paragraph 341 = 341, duty
      paragraph 745 = 745. Neither amendment holds a stale half.

- [X] T021 FIXED — **T015 fixed two of three copies and the record did not say
      so.** `pipeline/CHANGELOG.md` still carried the carry into "the commit
      message and the pull request" UNCONDITIONALLY — the precise defect T015 was
      raised for. The "contract-pinned" reason used for the configuration row does
      NOT apply here: quickstart section 6 pins only the entry's OPENING string,
      so the carry sentence was freely editable and was simply missed. A minimal
      qualifier was added. STRICT surface, so portability was run immediately
      after: `1..21`, 21 ok, 0 not ok, exit 0.

- [X] T022 FIXED — **round 1's rejection reached the right verdict by an unsound
      method.** Its grep pattern could not match F's heading ("analyze, auto-fix
      loop"), so the entry named four loops while its own evidence showed three,
      and a method blind to F cannot distinguish N from F. Corrected in place with
      a dated note and a SOUND enumeration: phase headings containing "loop" give
      C, F and M; cap statements give C, F, J and M — the union is four, each
      capped, and J is the one whose heading does not carry the word, which is
      exactly why the heading grep alone was insufficient. N is in neither list.
      The verdict is unchanged and now rests on evidence that supports it.

- [X] T023 FIXED — **round 1 recorded line numbers that its own round invalidated.**
      T016 pasted K 488 / L 495 / M 501 / N 506 as measured evidence; T015 had
      inserted four lines above them in the same round, and round 2 moved them
      again. This is not dated-log drift — the record and the edit that broke it
      landed together, and the quickstart's own standard is that documented
      outputs are measured, not predicted. Corrected in place with a dated note,
      and the evidence re-anchored on the ORDER (K, L, M, N) rather than on line
      numbers, because the order is what the finding turned on and it does not
      decay.

### Bookkeeping this round

The unpinned surface is now **NINE** sites, not eight — the `gates.J` sentence is
site nine. Every LIVE copy of the count was updated (research R3's enumeration
and its two later references, the tasks header); the dated records of what earlier
rounds did were left alone, because a dated log is not stale. The eight MATRIX
CELLS are a different eight and were correctly not touched — checked explicitly,
since this is the count-slip class this project keeps meeting.

**One more instance of T023's class, caught proactively rather than by a
reviewer.** T021's changelog qualifier added one line, so the changelog heading
line numbers moved from `5 / 55 / 74` to `5 / 56 / 75`. Three earlier evidence
blocks in this file paste the old triple — phase H's T005 note, phase I's T006
note and phase I's evidence list. Those are NOT corrected: they are dated
measurements that were accurate when taken, and a dated log must not be
rewritten. What matters is that the CHECK does not depend on them, and it does
not: quickstart section 5 greps the headings and documents their ORDER, never
their line numbers. This is the distinction T023 turned on — a record invalidated
by an edit in its OWN round is a defect; a record superseded by a later round is
history.

## Phase 9c: M — pull-request review, round 3 of 3 (2026-08-24)

`/code-review high` against the round-2 tree. Six findings, all real. Five fixed,
one partially fixed and the remainder honestly reopened. **This is the last round
the cap allows, and it is NOT a cap breach**: the cap bounds review ROUNDS and
exactly three were run. A breach would be findings left demanding a fourth round;
there are none. Round 3's own fixes are verified by re-measuring every quickstart
section here, and again by phase N's full re-run, which is what N is for.

- [X] T024 FIXED — **round 2's own fix created a safety regression, and round 3
      caught it.** `gates.J` combined with the ground rule "a re-entered gate
      whose answer is already recorded in `gates` never re-asks" would AUTO-WAVE
      a DIFFERENT set of failures. The recorded answer was about one specific set
      of surviving reds, but the suppression is keyed to the GATE, not to the set
      the answer covered. Concretely: J breaches, the owner waves it through,
      `gates.J` is written; the run is later resumed into J after new commits and
      breaches on entirely different reds; the executor finds `gates.J` populated,
      treats the conditional stop as answered, and ships failures no human ever
      saw. That is the exact outcome the duty exists to prevent, arriving through
      the fix meant to serve it.
      Three sentences added scoping the answer to the failures it names: a later
      breach on a different set is a new stop, asked afresh, and the never-re-ask
      rule suppresses a repeat of the same question, never a first sight of a new
      one. The contract's duty-paragraph quote was re-extracted and byte-compared
      after the edit: 1099 = 1099, identical. Key mention count still `2`.

- [X] T025 FIXED — **three shipped sentences had no cover at all**, which is the
      relocation hole phase I made a first-class defect and which round 2 had
      applied to `gates.J` while skipping its own siblings. Deleting any of them
      passed the full `1..121` suite and every quickstart section. Cover added:
      the answer-scoping sentence and the three-destinations sentence joined
      quickstart section 3's sliced J greps (both measured `1`); phase N's
      inherited-classification paragraph could NOT join section 3, because
      section 3 slices J only — it got a new **section 7** that slices N from its
      own heading to N.5's (slice measured 15 lines, both greps `1`).
      A defect in that new section was caught by running it rather than reading
      it: the `tr` command had been written with a real newline instead of the
      two characters `\n`, so the documented command was broken. Repaired, then
      every `tr` line in the file was checked and the whole document was executed
      verbatim. Reading a command is not running it.

- [X] T026 FIXED — **the site count was RE-ENUMERATED FROM SCRATCH, not
      incremented.** Round 3 found the count wrong again — the fourth trip
      through this project's dominant defect class. Rather than patch nine to
      eleven, R3's enumeration was read off the run's full diff against `main`:
      **TWELVE** distinct shipped prose units, listed individually. Six at phase
      D, eight at phase I, nine at M round 2 were each correct for the prose that
      existed when written; what was wrong was reaching for arithmetic while the
      prose was still moving. R3 now says plainly that the LIST is the thing to
      re-read, not the number. Every live copy of the count was updated; dated
      records of what earlier rounds did were left alone.
      All twelve now carry MANUAL quickstart cover and none carries an automated
      pin — which is precisely the debt the owner ruled recorded-not-spent, now
      stated at its true size.

- [X] T027 FIXED — **quickstart section 6 and research R3 disagreed about which
      site was which.** Section 6 called the changelog entry "site 8"; R3 has the
      changelog as site SIX and the conditional-stops line as SEVEN. R3 is the
      authoritative enumeration and section 6 now follows it, saying so. The
      disagreement was introduced by this run's own edits and is reconciled here.

- [X] T028 FIXED — **the changelog qualifier round 2 wrote mis-described one of
      the three paths it covered.** It read "where a degraded push leaves no pull
      request", but L's no-remote degradation stops after K — there is no push at
      all. Round 2 caught the analogous overstatement in `SKILL.md` and did not
      re-check the changelog wording it had edited in the same breath. It now
      reads "where no pull request exists", and the sentence was restructured so
      the commit-message fallback clearly degrades only the PULL-REQUEST leg: the
      state-file record is stated as kept either way, which the previous phrasing
      could be read as dropping. STRICT surface, so portability ran immediately
      after: `1..21`, 21 ok, 0 not ok, exit 0.

- [X] T029 PARTIALLY FIXED, and the rest REOPENED honestly — **round 2 closed a
      queue entry while part of it was still open.** The entry was headed
      "ADOPTED, no longer deferred", but its consumer (b) reads "a `--from K` or
      `--from L` re-entry never reads J's paragraph at all" — and an address
      written INSIDE J's paragraph cannot serve a consumer whose defining property
      is that it never reads that paragraph. Round 1's separate deferral, "K and L
      are never told to carry the record", had been FOLDED INTO that entry, so
      closing it silently closed an open item too. Half of consumer (c) is in the
      same position: J's iteration count is still logged nowhere, so a `--resume`
      into J restarts the loop at zero.
      The entry is now marked **PARTIALLY ADOPTED**: consumer (a) — phase N — is
      genuinely closed by `gates.J`, and its stale round-1 text saying "N would
      still have nothing to READ" was corrected. Consumers (b) and the
      iteration-log half of (c) are REOPENED as their own deferred items below.
      Marking something resolved that is not is the fabrication this pipeline's
      own red-flags table names, and it is corrected rather than tidied.

### Round 3 deferrals, with reasons

- **A `--from K` or `--from L` re-entry is never told to carry the record**
  (consumer (b), reopened from T029). Deferred on a real constraint, not a dodge:
  **SC-004** rules that J's cap carries EXACTLY ONE documented addition and that
  it is "stated in J's own paragraph rather than being a trap". A clause in K or
  L would give this cap a second documented site, which the spec the owner
  approved forbids. Closing it properly means revisiting SC-004, which is an
  owner decision and not a review fix.
- **J logs no iteration count** (half of consumer (c), reopened from T029). F
  logs each iteration in `analyze_changelog`; J logs nothing, so a `--resume`
  into J spends the cap again from zero. Deferred: adding a per-iteration log is
  a new state-file key and a new J instruction, beyond a cap for the J loop.
  Note that T024 removes the DANGEROUS half of this — a re-entry can no longer
  inherit an answer for failures nobody saw; what remains is wasted iterations,
  not a silent wave-through.
- **`configuration.md`'s key row still states the carry unconditionally.**
  Enumerated rather than counted: `grep -rn 'commit message and the pull'` over
  the shipped files returns THREE copies of the claim — `SKILL.md` (qualified at
  T015/T020), `CHANGELOG.md` (qualified at T021) and `configuration.md` (not
  qualified). T021's "two of three copies" named the right ratio while missing
  that the third was the configuration row, and that framing is corrected here.
  Deferred because the row is contract-pinned SITE 3: qualifying it moves a
  pinned string, which is an owner call, and the round-1 deferral already queued
  the same row for a different defect (it names two carriers where the other two
  files name three). Both defects now sit on the queue against the same row.
