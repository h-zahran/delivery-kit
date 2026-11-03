# Quickstart: validate the base suite run

Run from the repository root. `P` is the working copy's script.

```bash
P="bash pipeline/scripts/progress.sh"
```

## 1. The new tests

```bash
bash "$HOME/bats/bin/bats" pipeline/tests/base-suite.bats
bash "$HOME/bats/bin/bats" pipeline/tests/suite-cache.bats
```

Expected: every test `ok`; the plan line equals the ok count.

## 2. The full suite and the analyzer

Use `testCommand` and `analyzeCommand` from `.delivery-kit.json`; both exit 0.

## 3. A faithful checkout on this repository (measured, Principle II)

On a scratch detached worktree of the base commit `065ab80`, with a throwaway
run whose `testCommand` is the real one:

```bash
W="$SCRATCH/q-wt"
C="$(jq -c .config.testCommand .delivery-kit/runs/053-f5-cites-main-suite/progress.json)"
S="$PWD/pipeline/scripts/progress.sh"
git worktree add -q --detach "$W" 065ab80
cd "$W" && mkdir -p specs/999-q && printf 'x\n' > specs/999-q/spec.md \
  && bash "$S" init 999-q 999-q main other >/dev/null \
  && bash "$S" state-set 999-q artifacts spec '"specs/999-q/spec.md"' \
  && bash "$S" state-set 999-q config testCommand "$C"
```

Then, still in `$W`, `bash "$S" suite-base 999-q start`, loop `wait` while it exits 2, and `suite-lookup 999-q --base`:
expected `ended: green`, lookup exit 0, the summary names `065ab80` and the
command. Compare the background TAP's plan line and ok count with this run's
own F.5 TAP (`.delivery-kit/runs/053-f5-cites-main-suite/suite-f5.tap`):
equal counts mean the checkout ran the same suite. Remove the scratch
worktree with `git worktree remove --force "$W"` afterwards.

## 4. Nothing in the main tree moved

Before and after section 3: `git rev-parse HEAD`, `git status --porcelain`,
`git branch --list` and `git worktree list` are identical (the scratch
worktree aside).
