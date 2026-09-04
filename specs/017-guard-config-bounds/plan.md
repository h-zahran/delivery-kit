# Implementation Plan: The guard's own configuration cannot silence it

**Branch**: `017-guard-config-bounds` | **Date**: 2026-09-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/017-guard-config-bounds/spec.md`

## Summary

One character changes: `handoff/hooks/context-guard.sh:44`, `-le` becomes `-lt`
inside `is_valid_threshold`. Everything else in this plan exists because that
character is load-bearing in four places that do not move with it — a comment
that states the rule, an invariant that cites the old boundary, a test that
depends on the old boundary and stays green without it, and documentation that
describes the rule to users.

The second defect the seed raised — an unbounded window size — was **ruled a
non-change** at the clarify gate on 2026-09-04. It ships as a recorded decision
(FR-008, FR-010, SC-007, SC-008). Adding a ceiling or a notice is now a spec
violation, not an improvement.

The risk in this feature is not the edit. It is that **the suite goes green
whether or not the work was done properly**: one existing test keeps passing
after the fix for a reason its own comment no longer states, and no automated
check covers the documentation wording at all. Both are addressed by design
below, not by hoping the run notices.

## Technical Context

**Language/Version**: POSIX shell (`sh`-compatible), executed under `bash`. No
shell features beyond the existing file's vocabulary.

**Primary Dependencies**: `jq` (hard dependency of the hook, already present);
`bats-core` at the repository's pinned commit for tests; `shellcheck` for static
analysis.

**Storage**: N/A. The hook reads two JSON configuration files, four environment
variables, and a JSONL transcript. It writes only fire-once flag files under the
temporary directory. None of that changes here.

**Testing**: `bats-core`. The house suite runs from the repository ROOT:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`
— currently `1..167`. Behavioural equivalence is proven separately by
`scripts/context-guard/differential.sh`.

**Target Platform**: macOS, Ubuntu and Windows (Git Bash), all three exercised by
the project's automation.

**Project Type**: Plugin hook — a single executable shell script invoked by the
harness after each tool use.

**Performance Goals**: Unchanged, and that is a requirement rather than an
aspiration. Two prior features reduced this hook's process-spawn count; this
change adds no process, no subshell and no branch. `-le` to `-lt` is the same
`test` invocation.

**Constraints**: `handoff/hooks/` and `handoff/docs/` are STRICT-vocabulary
surfaces. Comments in this hook are the record of why things are safe and are
carried, never compressed. No behaviour may change except the one intended
configuration shape.

**Scale/Scope**: One function, one operator, four dependent sites, three new
tests, one corrected test, THREE documentation edits — the sweep found three
sites where the plan predicted one — and one recorded ruling.

## Constitution Check

*GATE: passed before Phase 0. Re-checked after Phase 1 — see the note at the end.*

**I. Silence is the failure that matters (NON-NEGOTIABLE)** — **PASS, and this
feature is an instance of the principle rather than merely compliant with it.**
The defect is a configuration value that switches a guard off without saying so.
Two consequences the plan must honour:

- The corrected test (FR-006) must not be allowed to pass vacuously. A test whose
  stated mechanism has evaporated is exactly "a check that quietly did not run" —
  and that is its defect: **the assertion stays true, only the explanation goes
  false**. Correcting the explanation is therefore the deliverable. Measured
  2026-09-04 (research.md §3, §7): reverting the value cannot turn that test red,
  because it falls back to a default that leaves the assertion true. Attempting
  such a proof would manufacture evidence, which is the same sin one step over.
  The change is proved instead by the first-refused-value test, which moves the
  guard from **silent to speaking**.
- **FR-005 currently has no gate at all.** The documentation wording is covered
  by nothing; a green suite says nothing about it. Leaving it as a one-time
  manual sweep leaves a claim with no check behind it. **Decision: add a prose
  pin** so the wording cannot drift back silently. See the Phase 1 note on how to
  pin it without violating Principle V.

**II. Measure; never assert** — **PASS.** FR-009 forbids the sentence "behaviour
is unchanged" without a differential that says so, and requires the one intended
divergence to be ASSERTED by the harness so that quietly repairing it goes red.
The baseline is passed as a commit id, never a branch, because this repository
rebase-merges.

**III. A gate must be shown able to go red** — **PASS**, but the three boundary
values carry THREE DIFFERENT burdens and conflating them would fabricate
evidence. Only the first-refused value can be shown failing against the
unchanged hook. The last-accepted value passes on BOTH sides — it must, since
it stays valid — so its control is a deliberate mutation of the operator. And
the corrected test cannot be shown red at all: measured 2026-09-04, reverting
its value leaves the assertion true, because the value falls back to a default
that is also unreachable for that transcript. Its defect was a false comment,
and a comment is repaired, not proved red. A mutation must be verified to have landed
before its result is believed.

**IV. One implementation, many callers** — **PASS, and reinforced.**
`is_valid_threshold` is the single implementation; all three configuration layers
call it. This is why the fix is one character rather than three. **No inline copy
of the rule may be introduced** at any call site as part of this work — doing so
would convert a compliant structure into the exact drift the principle forbids.

**V. Derive coverage; never enumerate it** — **PASS, with a live hazard.** The
documentation sweep must be derived — search for every occurrence of the rule's
wording — not satisfied against a hand-written list of two files. A hand list is
how the wording drifted out of step in the first place. The new pin from
Principle I must be written so that it cannot become a stale enumeration; see
Phase 1.

**No violations. Complexity Tracking is empty and stays empty.**

## Project Structure

### Documentation (this feature)

```text
specs/017-guard-config-bounds/
├── spec.md              # Feature specification (Phase B, clarified Phase C)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── threshold-validation.md   # Phase 1 output
├── checklists/
│   └── requirements.md  # Spec quality checklist, 16/16
└── tasks.md             # Phase E output, NOT created here
```

### Source Code (repository root)

```text
handoff/
├── hooks/
│   └── context-guard.sh          # THE change: :44. Plus comments at :37-42 and :620-623
├── tests/
│   └── context-guard.bats        # Rewrite :484-493; add boundary tests near :459
├── docs/
│   └── configuration.md          # The rule's wording, :46-53
└── CHANGELOG.md                  # ### Fixed under the existing ## [Unreleased]

scripts/context-guard/
├── differential.sh               # Add thresholdPct shapes 99 / 100 / 101
└── README.md                     # Its dated record of runs

specs/015-guard-jq-spawn-two/
└── tasks.md                      # T045 at :220-226 — where the FR-008 ruling is recorded
```

**Structure Decision**: No new files under `handoff/`. This is an edit to one
existing function plus the four sites that describe or depend on it. The only new
artefacts are tests inside the existing `.bats` file, new shapes inside the
existing differential harness, and this feature's own specification directory.
Introducing a new module for a one-character rule change would violate Principle
IV by giving the rule a second home.

## Sequencing, and why this order

1. **Record the baseline first.** Run the house suite and the differential
   against the unchanged tree, and keep both outputs. Every later claim is
   measured against these, not against memory.
2. **Write the TWO boundary tests BEFORE the edit**, and run them. The
   first-refused-value test MUST fail; the last-accepted-value test will PASS,
   and that is correct, not a gate failure. Treating its green as something to
   fix is how the run would manufacture the evidence SC-002 forbids. A third
   test for the next value up is not written: that value already behaves
   correctly and is already covered.
3. **Make the edit.** One character.
4. **Repair the four dependants**: the rule comment, the invariant comment, the
   rewritten test, the documentation.
5. **Prove the boundary pin can fail** by a landed mutation of the operator — NOT
   by reverting the corrected test, which cannot go red (research.md §3).
6. **Run the differential with the new shapes** and confirm exactly one differs.
7. **Sweep the documentation by derivation**, then add the pin.
8. **Record the FR-008 ruling** beside T045.

Steps 1 and 2 before step 3 is the whole discipline: after the edit, a green
suite is ambiguous, and there is no way back to an honest "this test could fail".

## Complexity Tracking

> No Constitution Check violations. This table is intentionally empty.

## Post-Design Constitution Re-Check

Re-evaluated after Phase 1 artefacts were written. Still passing on all five, and
one thing tightened during design: the prose pin required by Principle I was at
risk of becoming the enumeration Principle V forbids. `contracts/threshold-validation.md`
resolves the tension — the pin asserts the CONTRACT's wording is present and the
superseded wording is absent, and the contract names the rule once, so the pin
has a single source rather than a list of files to keep in step.
