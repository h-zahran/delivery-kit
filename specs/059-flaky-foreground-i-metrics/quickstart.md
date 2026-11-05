# Quickstart: prove 059

Run these from the repository root, on the feature branch, after the build.

## 1. The stop test, both signal states

```bash
"$HOME/bats/bin/bats" -f 'TERM, INT and HUP' tests/run-suite.bats
s="$(mktemp)"
printf '%s\n' '"$@" > "$OUTF" 2>&1 &' 'wait $!' > "$s"
OUTF="$(mktemp)"; export OUTF
bash "$s" "$HOME/bats/bin/bats" -f 'TERM, INT and HUP' tests/run-suite.bats
cat "$OUTF"
```

Expected: both print `ok 1`. The second takes seconds, not 60, and shows a `#` line that says `INT` is ignored at entry.

## 2. 500 passes under load

```bash
n=$(nproc)
for w in $(seq 1 "$n"); do ( while :; do :; done ) & done
loaders=$(jobs -p)
red=0
for i in $(seq 1 500); do
  "$HOME/bats/bin/bats" -f 'TERM, INT and HUP' tests/run-suite.bats > /dev/null 2>&1 || red=$((red + 1))
done
kill $loaders
echo "reds: $red of 500"
```

A foreground command stops at 600 s, so split the passes across calls. Expected: `reds: 0 of 500`. Record the counts, the load and the time in `research.md`, section R8.

## 3. A real base suite on the fixed code

Use `suite-base` from the working copy against a throwaway run in a temporary clone, with the fixed code committed there. Read the `outcome` file in a later Bash call, so that the runner has outlived the call that started it.

Expected: the runner is alive in the second call, the `outcome` is `green`, and the stop test is `ok` in `suite.tap`.

## 4. The measure

```bash
"$HOME/bats/bin/bats" pipeline/tests/i-measure.bats
```

Expected: all ok. Then read the `phaseI` key in a fixture's `pipeline-run.json`, as the tests do, and check a missing part reads `missing` and not 0.

## 5. The whole suite and the analyzer

```bash
bash scripts/run-suite.sh > "$(mktemp)"
```

Expected: the plan line equals the ok count, 0 not ok, 0 skipped. Then run the `analyzeCommand` from `.delivery-kit.json`: 0 lines.
