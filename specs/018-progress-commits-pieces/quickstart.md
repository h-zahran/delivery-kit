# Quickstart: validating commit-add and piece-next

Run everything from the repository root. The contract is in
[contracts/progress-commands.md](contracts/progress-commands.md); the entry
shapes are in [data-model.md](data-model.md).

## 1. The new tests, red first

The new tests must fail against the script as it was before this feature.
That run happens in a scratch tree, never in the checkout (tasks.md, rule 3):

```bash
S="$(mktemp -d)"
cp -r .claude-plugin tests pipeline "$S/"
cp .delivery-kit/runs/018-progress-commits-pieces/progress.sh.orig "$S/pipeline/scripts/progress.sh"
git -C "$S" init -q
bash "$HOME/bats/bin/bats" --print-output-on-failure "$S/pipeline/tests/progress.bats"
```

Expected there: every new test `not ok`, every existing test `ok` — except,
once T013 has edited it, the usage test at `progress.bats:311`. In the
checkout, after the change: every test `ok`, and the plan line equals the ok
count.

## 2. A scratch run, by hand

```bash
cd "$(mktemp -d)"
P="$OLDPWD/pipeline/scripts/progress.sh"
bash "$P" init 900-demo 900-demo main other
mkdir -p specs && cp "$OLDPWD/pipeline/tests/fixtures/tasks-pieces/tasks.md" specs/tasks.md
jq '.artifacts.tasks = "specs/tasks.md"' .delivery-kit/runs/900-demo/progress.json > t && mv t .delivery-kit/runs/900-demo/progress.json
bash "$P" piece-next 900-demo            # first piece: heading line, then ids
sha=$(printf '%040d' 0 | tr 0 a)
bash "$P" commit-add 900-demo piece "$sha" "$(bash "$P" piece-next 900-demo | head -1)" T001,T002 a.sh
bash "$P" piece-next 900-demo            # the second piece
jq '.commits' .delivery-kit/runs/900-demo/progress.json
```

Expected: the first `piece-next` prints the fixture's first piece; after the
`commit-add`, the second `piece-next` prints the next one; `.commits` holds
one object with `tasks` and `files` as arrays.

## 3. Old-style entries survive (SC-005)

Copy every real state file into a scratch directory and append one new entry
to each; each must still validate and keep its old entries. The script and
its output are saved under `.delivery-kit/runs/018-progress-commits-pieces/`
by the implementing task, never run against the originals.

## 4. The whole house

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
mapfile -d '' files < <(git ls-files -z -- '*.sh' '*.bash' ':(exclude).specify/')
shellcheck --norc -f gcc -- "${files[@]}"
```

Expected: `1..170+N`, 170+N ok, 0 not ok; shellcheck prints nothing.
