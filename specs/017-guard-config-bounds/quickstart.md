# Quickstart — validating feature 017

Every command runs from the **repository root**. A suite can pass in a worktree
and fail at the root; every count in this feature is a root measurement.

## Prerequisites

- `jq`, `shellcheck`, and `bats-core` at the repository's pinned commit
- A clean working tree, or one whose changes are this feature's

## 0. Record the baseline BEFORE touching anything

This is not optional and it cannot be done later. After the edit, a green suite
is ambiguous.

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

Expected today: `1..167`, 167 ok, 0 not ok, exit 0. Keep the output.

Note the commit id you are starting from — the differential needs it as an id,
never as a branch name, because this repository rebase-merges and a branch name
compares an empty range once the work lands.

```bash
git rev-parse HEAD
```

## 1. Prove the defect before fixing it

The new boundary test must fail against the unchanged hook, or it is testing
nothing (Principle III). Add the 100-rejected test, then run only that file:

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure handoff/tests/context-guard.bats
```

Expected: the new test **fails**. Measured 2026-09-04 against the unchanged
hook: with the threshold at 100 and readings at half the window, the guard emits
nothing at all. That silence is the defect, and the test's job is to name it.

## 2. After the change — the boundary in both directions

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure handoff/tests/context-guard.bats
```

Expected: green, including

- 100 refused: the guard now **speaks** where it was silent, naming `threshold 45%`
- 99 accepted: the emission names `threshold 99%` — not `45%`, which is what
  a refusal would produce, so the assertion discriminates on the exact value
- 101 refused: unchanged, already covered

## 3. The 99 test's positive control is a mutation, not the feature

99 is accepted before and after this change, so that test passes on both sides.
It is a regression pin, and the only way to show it can go red is to break the
boundary on purpose:

1. Change the comparison so 99 is refused as well.
2. **Confirm the mutation landed** — print the changed line. A mutation that did
   not land is a silent false green.
3. Run the file. The 99 test must fail.
4. Restore, and confirm the restore with a byte comparison.

## 4. Prove the rewritten test was actually repaired

One existing test sets the threshold to 100 on purpose. **Reverting its value
alone will not turn it red** — that was measured, and the reason is in
`research.md` §3. So do not attempt that proof; it cannot succeed.

What to check instead: read the test's comment and confirm it describes what the
test now does. The defect there was a false explanation, not a false assertion.

## 5. Behavioural differential

```bash
bash scripts/context-guard/differential.sh <baseline-commit-id>
```

Read `scripts/context-guard/README.md` first. Two traps it records:

- `HOME`, `TMPDIR`, `TEMP` and `TMP` must **all** be isolated per side per shape,
  or the old hook's fire-once flag silences the new one and the harness reports
  false differences on a correct hook.
- Run the `NEWHOOK` positive control before believing any zero. A harness that
  has only ever printed zero differences has proven nothing.

Expected: **0 unexpected**, and **exactly one shape asserted to differ** — the
threshold-100 shape. The 99 and 101 shapes must be asserted the same, which is
how the change is shown to be bounded rather than merely present.

**A run reporting no differences at all is a FAILED run here, not a clean one.**

## 6. Documentation agrees with the code

Do this by derivation, not against a list of two files — a hand list is how the
wording drifted out of step originally.

```bash
grep -rn "above 100" handoff/ README.md
```

Expected: no hit that states the rule. The rule reads "100 or above" everywhere
it appears. The canonical sentence lives in
[contracts/threshold-validation.md](./contracts/threshold-validation.md).

## 7. Static analysis, the way the automation runs it

```bash
shellcheck --norc -f gcc handoff/hooks/context-guard.sh
```

Expected: clean. Note the automation's analyser is **older** than a typical local
one and reports **more**, so a local pass does not predict it.

## 8. Full suite, from the root

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

Expected: the baseline count **plus the tests this feature adds**, 0 not ok, 0
non-TAP, exit 0. A count that has not moved is itself a finding — this feature
adds tests by design.

## 9. The ruling is recorded

Confirm the window-size ruling is written beside the deferral that raised it, at
task T045 in `specs/015-guard-jq-spawn-two/tasks.md`. A reader arriving there
must reach the reasoning without leaving the repository.

## What "done" means

| Check | Pass condition |
|---|---|
| Full suite, from root | baseline + N, 0 not ok, exit 0 |
| Boundary, both directions | 100 refused, 99 accepted, each asserted on the exact value |
| Change proven | the 100 test failed before the edit and passes after |
| 99 pin proven | shown red by a landed mutation, then restored |
| Differential | 0 unexpected, exactly 1 asserted to differ |
| Documentation | derived sweep finds no surviving statement of the old rule |
| Static analysis | clean |
| Window size | provably unchanged at every layer |
| Ruling | recorded at T045 |
