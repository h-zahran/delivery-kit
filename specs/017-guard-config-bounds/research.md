# Phase 0 — Research

**Date**: 2026-09-04 · **Baseline**: `main` at `2658b62`, house suite `1..167`

Four questions had to be answered before tasks could be written. Two were
straightforward. The third overturned a requirement's stated method. The fourth
resolved a tension between two constitution principles.

---

## 1. Which operator, and does one edit really cover all three configuration layers?

**Decision**: `[ "$1" -le 100 ]` → `[ "$1" -lt 100 ]` at `handoff/hooks/context-guard.sh:44`.
One edit, all three layers.

**Rationale**: `is_valid_threshold` is the sole validator. The repository and
user-level files reach it at `:237`; the environment reaches it at `:265`. There
is no fourth caller and no inline copy. This is Principle IV working as intended
— and it is the reason the fix is one character rather than three.

**Alternatives considered**: adding a separate bound at each call site (rejected:
creates exactly the duplicated rule Principle IV forbids, and the three copies
would drift); a new `is_valid_threshold_strict` alongside the old one (rejected:
two implementations of one rule, same objection, plus a dead branch).

---

## 2. Does the invariant at `:620-623` survive the change?

**Decision**: It survives and **strengthens**. The comment must be updated to say
so; the code beneath it does not move.

**Rationale**: The invariant reads *"observed context exceeding the window implies
the percentage is at least 100, which implies the bucket is at least 20. The
threshold gate cannot block that, because `is_valid_threshold` caps
`THRESHOLD_PCT` at 100."* Today the argument rests on equality — a percentage of
100 exactly meets a threshold of 100. After the change the maximum admissible
threshold is 99, so a percentage of at least 100 strictly **exceeds** every
admissible threshold. The conclusion holds by a wider margin than before.

**Consequence**: the comment is now wrong about the number and understated about
the strength. `handoff/hooks/` is a STRICT surface where the reasoning is the
record, so this is a required edit, not a tidy-up.

---

## 3. FR-006 says "reverting the rewrite alone must turn the test red." It cannot. Here is what to do instead.

**This overturns the method FR-006 names, not its intent.** Recorded in full
because a plan that quietly dropped it would be the exact failure this feature
is about.

**What was checked.** The test at `handoff/tests/context-guard.bats:484-493`
configures window 1000000, `thresholdPct` 100, `thresholdTokens` 400000, and a
transcript of 405000. It asserts the emission names the absolute limit.

- Before the change: 100 is accepted, the percentage is 40, 40 < 100, the
  relative tripwire is silent, the absolute one fires.
- After the change with the value left at 100: 100 is refused, the threshold
  falls back to the default 45, the percentage is still 40, 40 < 45 — the
  relative tripwire is **still** silent and the absolute one still fires.
- After the change with the value rewritten to 99: 40 < 99, same outcome again.

**All three pass.** Reverting 99 to 100 therefore does *not* turn this test red,
and no choice of value for this test makes it do so — because when both tripwires
cross, the message names the absolute one anyway, so the output cannot distinguish
"only the absolute fired" from "both fired".

**Decision**: rewrite the value to 99 **and correct the comment**, which is the
actual defect — the comment claims a mechanism ("threshold 100% is not reachable
here") that the fix removes. Do **not** claim the rewrite is load-bearing. The
load-bearing proof moves to the new boundary tests below, which carry it properly.

**Rationale**: the honest statement is that this test's assertion is correct
before and after; only its explanation was false. Fixing an explanation is the
work. Manufacturing a red that the test's structure cannot produce would be
fabrication.

**Alternatives considered**: restructuring the test so both tripwires' firing is
separately observable (rejected: the message deliberately names only the absolute
one when both cross, and that naming rule is itself pinned by a neighbouring
test — changing it to make this test provable would break a documented contract
to serve a proof); deleting the test (rejected: its assertion is sound).

---

## 4. How do the new boundary tests prove themselves, given #3?

**Decision**: the two boundary tests carry different burdens, and only one of
them can be red-before-green. Say which is which rather than implying both.

**The 100-rejected test is the change-prover, and it is a strong one.**
Configure window 1000000 and `thresholdPct` 100, with **no** `thresholdTokens`,
and a transcript at 500000 — half the window.

- Before the change: 100 is accepted, 50 < 100, and there is no absolute
  tripwire. **The guard emits nothing at all.**
- After the change: 100 is refused, the threshold falls back to 45, 50 ≥ 45, and
  the guard fires, naming `threshold 45%`.

Silent to speaking. That is the defect and its repair in one test, it satisfies
Principle III without contrivance, and it is a direct measurement of SC-001.

**The 99-accepted test is a regression pin, not a change-prover.** 99 is accepted
before and after, so this test passes on both sides — correctly, since FR-003
requires exactly that continuity. Its positive control is therefore a **mutation,
not the feature**: change the operator to `-lt 99` and the test must go red.
Principle III requires the control be *run*, not merely written, and requires the
mutation be verified to have landed first.

Shape: window 1000000, `thresholdPct` 99, transcript at 995000 — the percentage
is 99 (integer division of 99.5), the threshold is met exactly, and the emission
names `threshold 99%`. If 99 were refused the message would say `threshold 45%`,
so the assertion discriminates on the exact value rather than merely on firing.

**101 needs no new test.** It is already covered at `:459` and its behaviour does
not change. Adding one would enumerate what is already derived.

---

## 5. How to pin the documentation wording without creating the enumeration Principle V forbids

**The tension**: Principle I says FR-005 must not rest on a check that does not
exist. Principle V says a hand-written list of files goes stale in the direction
that hurts.

**Decision**: pin the **rule**, not the file list. `contracts/threshold-validation.md`
states the rule in one canonical sentence. The pin asserts that sentence's
operative wording is present in the documentation and that the superseded wording
is absent — one source, checked by derivation over the documentation surface
rather than over a list of two paths.

**Rationale**: a pin naming `configuration.md` and the hook by path is a list of
two that will be a list of two forever, including on the day somebody adds a
third site. A pin that searches the surface finds the third site.

**Alternatives considered**: no pin, sweep manually once (rejected: Principle I —
it leaves a claim with no check); pinning each known site by path (rejected:
Principle V, and it is how the wording drifted out of step originally).

---

## 6. Differential shapes

**Decision**: add `thresholdPct` 99, 100 and 101 as shapes. Assert **100 differs**;
assert 99 and 101 are **the same**.

**Rationale**: 100 is the entire behaviour change, so it must be asserted to
differ — Principle II requires the divergence be asserted so that quietly
repairing it goes red. 99 and 101 assert the change is *bounded*: one value moved
and its neighbours did not. A run reporting zero differences is a failed run here,
not a clean one (FR-009).

**Traps carried forward from the harness's own record** (`scripts/context-guard/README.md`):
`HOME`, `TMPDIR`, `TEMP` and `TMP` must all be isolated per side per shape, or the
old hook's fire-once flag silences the new one and the harness reports false
differences on a correct hook. The baseline is passed as a **commit id**, never a
branch — this repository rebase-merges, so a branch name compares an empty range
once the work lands. Run the `NEWHOOK` positive control before believing any zero.

---

---

## 7. The measurement behind sections 3 and 4

Principle II forbids a claim about behaviour that was not produced by running
something. Sections 3 and 4 make four such claims, so all four were run against
the **unchanged** hook at `2658b62` on **2026-09-04**, as a throwaway `bats` file
that was deleted immediately afterwards and whose absence was verified.

| Probe | Shape | Expected | Result |
|---|---|---|---|
| P1 | window 1000000, `thresholdPct` 100, no absolute limit, readings at 500000 (50%) | **silent** | `ok` — the guard emits nothing |
| P2 | window 1000000, `thresholdPct` **45**, absolute 400000, readings at 405000 | fires, names the absolute limit | `ok` |
| P3 | window 1000000, `thresholdPct` 99, readings at 995000 | fires, message contains `threshold 99%` | `ok` |
| P4 | window 1000000, `thresholdPct` **99**, absolute 400000, readings at 405000 | fires, names the absolute limit | `ok` |

`1..4`, 4 ok, 0 not ok, exit 0.

**What each one settles:**

- **P1 is the defect, demonstrated rather than described.** At half the window the
  guard says nothing, because the threshold it was given can only be met once the
  window is already full. This is why the 100-rejected test is a real
  change-prover: it goes from silent to speaking.
- **P2 settles section 3.** The trap test's shape still reports absolute-only when
  the threshold is the default 45 — which is exactly what it falls back to once
  100 is refused. So that test **stays green after the fix**, and no revert of its
  value can turn it red. The claim in FR-006 is overturned on evidence.
- **P3** confirms the emission names the exact accepted threshold, so the
  99-accepted test discriminates on the value rather than merely on firing.
- **P4** confirms the rewrite to 99 leaves the trap test's assertion true, so the
  rewrite corrects the comment without weakening the test.

## Summary of what changed in the plan because of this research

| Item | Before research | After |
|---|---|---|
| FR-006 proof method | "revert the rewrite, watch it go red" | Not achievable; the rewrite fixes a false comment, and the proof burden moves to the 100-rejected test |
| Boundary tests | Two tests, both assumed red-before-green | 100-rejected is the change-prover; 99-accepted is a regression pin proved by mutation |
| 101 | Implied a third test | Already covered at `:459`; adding one would duplicate |
| Documentation pin | Not planned | Required by Principle I, shaped by Principle V |
