# Quickstart: validate this feature

Run each block from the repository root, on the branch's final commit.

## 1. The script's own tests

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure tests/run-suite.bats
```

Expected: every test `ok`, none skipped.

## 2. The new report against the serial report

```bash
d="$(mktemp -d)"
bash scripts/run-suite.sh > "$d/new.tap" 2>&1
echo "new rc=$?"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests > "$d/old.tap" 2>&1
echo "old rc=$?"
bash pipeline/scripts/progress.sh tap-check "$d/new.tap"
echo "tap-check rc=$?"
names() { sed -n -e 's/^ok [0-9]* //p' -e 's/^not ok [0-9]* //p' "$1" | LC_ALL=C sort; }
names "$d/new.tap" > "$d/new.names"
names "$d/old.tap" > "$d/old.names"
cmp "$d/new.names" "$d/old.names"
echo "same names rc=$?"
wc -l < "$d/new.names"
rm -rf "$d"
```

Expected: every `rc=0`, and `tap-check` prints `suite ok`. The two sets of test names are the same.

## 3. Time, at least three passes

```bash
d="$(mktemp -d)"
for i in 1 2 3; do
  s="$(date +%s)"
  bash scripts/run-suite.sh > "$d/p$i.tap" 2>&1
  rc=$?
  echo "pass $i rc=$rc secs=$(( $(date +%s) - s )) ok=$(grep -c '^ok' "$d/p$i.tap") notok=$(grep -c '^not ok' "$d/p$i.tap") skip=$(grep -c '# skip' "$d/p$i.tap")"
done
rm -rf "$d"
```

Expected: `rc=0`, under 120 seconds, the same ok count each pass, `notok=0`, `skip=0`. Record the lines in `measurements.md`.

## 4. The harness rules are pinned

```bash
bash "$HOME/bats/bin/bats" --filter 'fault harness' --print-output-on-failure pipeline/tests/skills.bats
```

Expected: every test `ok`, and the plan line is not `1..0`.

## 5. Sizes and versions

```bash
wc -c < pipeline/skills/pipeline/SKILL.md
bash scripts/check-versions.sh
jq -r '.pipeline.testCommand' .delivery-kit.json
```

Expected: at most 65,415 bytes. `check-versions.sh` exits 0. The command printed is `bash scripts/run-suite.sh`.
