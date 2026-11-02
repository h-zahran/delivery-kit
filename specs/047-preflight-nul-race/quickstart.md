# Quickstart: validating the NUL-check fix

Run from the repository root.

## 1. The regression test and the walk

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" -f 'NUL' pipeline/tests/preflight.bats > "$out" 2>&1; echo "preflight rc=$?"; cat "$out"
bash "$HOME/bats/bin/bats" tests/pipefail.bats > "$out" 2>&1; echo "pipefail rc=$?"; cat "$out"
```

Expected: both `rc=0`; no line says `# skip`.

## 2. Versions agree

```bash
bash scripts/check-versions.sh; echo "rc=$?"
```

Expected: `rc=0`, pipeline at `1.7.2`.

## 3. The full suite

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests > "$out" 2>&1; rc=$?
head -n 1 "$out"; grep -c '^ok ' "$out"; grep -c '# skip' "$out"; echo "rc=$rc"
```

Expected: `rc=0`, plan line equals the `ok` count, zero skips.
