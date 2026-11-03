# Quickstart: validate 052

Run from the repository root. Every block is bash.

## The full suite and the analyser

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests
mapfile -d '' files < <(git ls-files -z -- '*.sh' '*.bash' ':(exclude).specify/'); shellcheck --norc -f gcc -- "${files[@]}"
```

Expected: every test passes; shellcheck prints nothing.

## The new tests alone

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure -f 'usable base is checked|HEAD outside refs/heads/|configuration hides|skip-worktree file' pipeline/tests/preflight.bats
bash "$HOME/bats/bin/bats" --print-output-on-failure -f 'notRead list is documented|Base branch section says' pipeline/tests/prose.bats
```

## By hand: one base case and one tree case

```bash
W="$(mktemp -d)"; cd "$W"
git init -q -b work . && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
bash /path/to/pipeline/scripts/preflight.sh --base-branch main; echo "rc=$?"
# expected: rc=1, stderr: 'main' is not a branch here or on origin (the baseBranch key)
git branch main
git config status.showUntrackedFiles no; echo new > u
bash /path/to/pipeline/scripts/preflight.sh --base-branch main | jq .tree.dirty
# expected: true
```

Replace `/path/to` with the repository's path.

## Mutants

Each new rule is removed in a worktree, one at a time, and the suite is
shown to go red; `measurements.md` records each mutant, the test that
went red, and the date.
