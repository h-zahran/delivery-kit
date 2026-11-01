# Quickstart: validating "every prose slice is guarded"

Run from the repository root.

## 1. The prose file alone

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/prose.bats > /tmp/prose.tap 2>&1; rc=$?
head -n 1 /tmp/prose.tap; grep -c '^ok ' /tmp/prose.tap; echo "rc=$rc"
```

Expected: `rc=0`, and the plan line `1..N` equals the `ok` count.

## 2. No bare range or inline flatten remains

```bash
grep -nE "awk '/[^']*/,/" pipeline/tests/prose.bats
grep -n "tr '\\\\n' ' '" pipeline/tests/prose.bats
```

Expected: the first prints nothing; the second prints only the line inside
`prose_flat`.

## 3. A renamed boundary goes red (one example; the full sweep is in differential.md)

In a scratch worktree only:

```bash
git worktree add ../dk-sweep HEAD
cd ../dk-sweep
sed -i 's/^\*\*H — implement\.\*\*/**H — implementation.**/' pipeline/skills/pipeline/SKILL.md
grep -n '^\*\*H — implementation\.\*\*' pipeline/skills/pipeline/SKILL.md   # proves the mutation landed
bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats > /tmp/sweep.tap 2>&1; echo "rc=$?"
grep -c 'UNTERMINATED' /tmp/sweep.tap
cd - && git worktree remove --force ../dk-sweep
```

Expected: `rc=1`, and at least one `UNTERMINATED` message.

## 4. The full suite

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests > /tmp/full.tap 2>&1; echo "rc=$?"
```

Expected: `rc=0`; plan line equals `ok` count.
