# Quickstart: proving the orchestrator builds in pieces

Run everything from the repository root, in Git Bash on Windows or a shell on
Linux or macOS.

## 1. The full house suite

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > /tmp/suite.txt 2>&1; rc=$?
head -1 /tmp/suite.txt                      # the plan line: 1..<N>
grep -c '^ok ' /tmp/suite.txt               # must equal <N>
grep -c '^not ok ' /tmp/suite.txt           # must be 0
grep -vcE '^(ok |not ok |1\.\.|#)' /tmp/suite.txt   # non-TAP lines: must be 0
echo "rc=$rc"                               # must be 0
```

Expected: the baseline measured at F.5 (`1..226` at `b0b3f1b`) before; that
plus the new tests after; the plan line equal to the ok count.

## 2. The pins alone, while iterating

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/prose.bats
```

Iteration only. The verdict is step 1.

## 3. No sentence still claims the old floor (SC-004)

Write this to a file and run it (heredocs through the agent's shell tool are
not byte-safe):

```bash
RUN=.delivery-kit/runs/019-orchestrator-builds-in-pieces
C=specs/019-orchestrator-builds-in-pieces/contracts/orchestrator-prose.md
new="$(tr '\n' ' ' < pipeline/skills/pipeline/SKILL.md | tr -s ' ')"
old="$(tr '\n' ' ' < "$RUN/SKILL.md.orig" | tr -s ' ')"
# The strings come from the contract's Absent section, never a typed copy:
# a list written twice goes stale in one place (Principle V).
list="$(awk '/^## Absent/{f=1;next} /^## /{f=0} f && /^- `/' "$C" \
        | sed -E 's/^- `(.*)`( \(.*)?$/\1/')"
fail=0 n=0
while IFS= read -r s; do
  [ -n "$s" ] || continue
  n=$((n + 1))
  if grep -qF -- "$s" <<<"$new"; then in_new=1; else in_new=0; fi
  if grep -qF -- "$s" <<<"$old"; then in_old=1; else in_old=0; fi
  printf '%s | new=%s old=%s\n' "$s" "$in_new" "$in_old"
  [ "$in_new" = 0 ] && [ "$in_old" = 1 ] || fail=1
done <<<"$list"
[ "$n" -gt 0 ] || { echo "no strings read from the contract"; fail=1; }
echo "strings=$n fail=$fail"   # fail must be 0
```

## 4. The dry read (SC-003)

Point a scratch state file at `specs/017-guard-config-bounds/tasks.md` and ask
`piece-next` for each piece in turn, recording each with a fake
`commit-add` so the next call moves on. Save the ordered list, with which
pieces change only `tasks.md`, as
`specs/019-orchestrator-builds-in-pieces/dry-read-017.md`. The expected shape
is in [research.md](research.md) R11; the saved file is the measurement.

## 5. Scope (SC-005)

```bash
git diff --name-only main...HEAD
```

Expected: `pipeline/skills/pipeline/SKILL.md`, `pipeline/tests/prose.bats`,
`pipeline/CHANGELOG.md`, and paths under
`specs/019-orchestrator-builds-in-pieces/` — nothing else.

## 6. Shell analysis

```bash
git ls-files '*.sh' '*.bash' | grep -v '^\.specify/' | xargs shellcheck --norc -f gcc
```

Expected: clean. No shell file changes in this feature; this proves it.
