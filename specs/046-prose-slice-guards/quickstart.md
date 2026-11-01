# Quickstart: validating "every prose slice is guarded"

Run from the repository root.

## 1. The prose file alone

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/prose.bats > "$out" 2>&1; rc=$?
head -n 1 "$out"; grep -c '^ok ' "$out"; echo "rc=$rc"; echo "results: $out"
```

Expected: `rc=0`, and the plan line `1..N` equals the `ok` count.

## 2. No bare range or inline flatten remains

```bash
grep -nE "awk '/[^']*/,/" pipeline/tests/prose.bats
grep -n "tr '\\\\n' ' '" pipeline/tests/prose.bats
```

Expected: both print nothing (`prose_flat` itself is written
`tr -d '\r' | tr -s '\n' ' '`, which the second grep does not match).

These greps show only the canonical spellings. The real check is the
committed test "no bare awk range slice and no inline flatten outside the two
helpers" in `prose.bats`, which section 1 runs: it walks the whole file, and it
also catches spellings these greps miss, such as other quote styles, awk
options, `sed -n` ranges, and an inline flatten split across two lines.

## 3. A renamed boundary goes red (one example; the full sweep is in differential.md)

In a scratch worktree only. The worktree sits under a fresh `mktemp -d`
directory and is named by absolute path. Every step that touches it runs in
one chained subshell, so a failure at any step (the worktree not created, the
`cd` failing, the mutation not landing) stops before the next step runs, and
nothing is ever written to the main checkout. The `&&` links are what stop it:
keep every step joined by `&&`. bats exits 1 on the expected red, so its
status is captured with `|| rc=$?` and the chain goes on to the count.

```bash
d="$(mktemp -d)" && out="$(mktemp)" &&
git worktree add --detach "$d/wt" HEAD &&
( cd "$d/wt" &&
  sed -i 's/^\*\*H — implement\.\*\*/**H — implementation.**/' pipeline/skills/pipeline/SKILL.md &&
  grep -n '^\*\*H — implementation\.\*\*' pipeline/skills/pipeline/SKILL.md &&  # proves the mutation landed
  { rc=0; bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats > "$out" 2>&1 || rc=$?; } &&
  echo "rc=$rc" &&
  grep -c 'UNTERMINATED' "$out"
)
echo "chain rc=$?"
if [ -n "$d" ]; then [ ! -d "$d/wt" ] || git worktree remove --force "$d/wt"; rmdir "$d"; fi
git worktree list; echo "results: $out"
```

Expected: the `grep -n` line for the renamed heading, `rc=1`, a count of at
least one `UNTERMINATED` message, `chain rc=0`, and `git worktree list`
showing only the main checkout. A non-zero `chain rc` means a step stopped the
chain, and nothing after that step ran. `rmdir` removes only an empty
directory, so it fails safely if the worktree could not be removed.

## 4. The full suite

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests > "$out" 2>&1; rc=$?
head -n 1 "$out"; grep -c '^ok ' "$out"; echo "rc=$rc"; echo "results: $out"
```

Expected: `rc=0`; plan line equals `ok` count.
