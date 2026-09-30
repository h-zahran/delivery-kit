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
new="$(tr '\n' ' ' < pipeline/skills/pipeline/SKILL.md | tr -s ' ')"
old="$(tr '\n' ' ' < "$RUN/SKILL.md.orig" | tr -s ' ')"
fail=0
for s in 'a run CAN reach DONE without a single gate stopping it' \
         'a pre-answered `implementer` at G;' \
         'but no gate does' \
         'like G whenever `implementer` is unset or `ask`' \
         'Pre-answers the G gate' \
         "Phase K's message shape" \
         'G stops unless `implementer` pre-answered it'; do
  n_new=$(grep -cF -- "$s" <<<"$new" || true)
  n_old=$(grep -cF -- "$s" <<<"$old" || true)
  printf '%s | new=%s old=%s\n' "$s" "$n_new" "$n_old"
  [ "$n_new" = 0 ] && [ "$n_old" -ge 1 ] || fail=1
done
echo "fail=$fail"   # must be 0
```

`grep -c` on a flattened (one-line) text counts 1 for any number of
occurrences; that is enough for present/absent.

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
