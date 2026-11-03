# Quickstart: 054 preflight boolean guard proof

Run from the repository root. The rig makes its own worktree and mutates
scratch copies only; it never edits a tracked file.

## 1. Base table (before any assertion is added)

```bash
bash specs/054-preflight-boolean-guard-proof/mutate.sh 86b1973888e053ce903b8d45b3114be73f30bf8d
```

Expected: a control line `CONTROL green`, then one row per derived mutant.
`sk_present` and `sk_in_range` read `HOLE`; the others read `CAUGHT`. Exit 0, because `HOLE` is
a finding on the base run.

## 2. Finished table

```bash
bash specs/054-preflight-boolean-guard-proof/mutate.sh --final HEAD
```

Expected: `CONTROL green`, every row `CAUGHT`, exit 0. Any other verdict
exits non-zero.

## 3. The tree is untouched

```bash
git status --porcelain   # same before and after each rig run
```

## 4. The suite

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests
```

Expected: green, one test more than the base commit.
