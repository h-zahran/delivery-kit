# Quickstart: verifying the five pins

**Feature**: 011-pin-safety-prose
**Date**: 2026-08-29

Every block below is meant to be run, not read. Run them from the repository
root, in a bash shell. They were executed in this order during implementation.

---

## Prerequisites

The blocks below use `$REPO` rather than a literal path. The tracked tree is
scanned for absolute machine paths (`tests/portability.bats`), and while the
four shapes it catches are all about a machine's USER rather than its drive
layout, a hardcoded checkout path is unrunnable for the next reader either way.

```bash
REPO="$(git rev-parse --show-toplevel)"
cd "$REPO"
test -f pipeline/skills/pipeline/SKILL.md || { echo "wrong directory"; exit 1; }
test -f pipeline/tests/prose.bats        || { echo "wrong directory"; exit 1; }
test -x "$HOME/bats/bin/bats" || test -f "$HOME/bats/bin/bats" || { echo "bats not found at $HOME/bats/bin/bats"; exit 1; }
echo "prerequisites ok"
```

---

## 1. The baseline

The house total, before anything changes. Note the redirect: a pipe into
`tail` hands the block `tail`'s exit status, which is always 0, and cuts the
plan line bats prints first — such a block can never go red.

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$out" 2>&1
rc=$?
head -1 "$out"
grep -c '^ok ' "$out"
grep -c '^not ok ' "$out" || true
echo "exit status: $rc"
```

Expected before the change: plan line `1..154`, 154 ok, 0 not ok, status 0.
Expected after: `1..159`, 159 ok, 0 not ok, status 0.

---

## 2. The prose suite alone

This is the loop used while iterating. The full house above is the verdict and
runs twice in the whole feature — once here as the baseline, once at the end.

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/prose.bats > "$out" 2>&1
rc=$?
head -1 "$out"
grep '^not ok ' "$out" || echo "(no failures)"
echo "exit status: $rc"
```

---

## 3. The mutation cycle

Run once per anchor. Twenty-one times in total: thirteen clause anchors, seven
rows, one appending mutant.

`git checkout --` is not available for the restore — the orchestrator's own
never-bend table forbids it, along with `git reset --hard`, `git clean` and
`git stash`. The backup copy is the restore.

### 3a. Back up, and keep the backup outside the repository

```bash
SCRATCH="${TMPDIR:-/tmp}/prose-mutation"
mkdir -p "$SCRATCH"
cp pipeline/skills/pipeline/SKILL.md "$SCRATCH/SKILL.md.orig"
cmp pipeline/skills/pipeline/SKILL.md "$SCRATCH/SKILL.md.orig" && echo "backup verified identical"
```

### 3b. Invert one anchor, and prove the edit landed

Inverting means rewriting the clause to assert the opposite. Deleting it does
not count — a deletion is the easy case, and a pin that only catches deletions
is not what the spec asks for.

The `echo` is not decoration. A `sed` whose pattern does not match exits 0 and
changes nothing; the suite then passes honestly while the run records a
mutation that never happened.

```bash
O=pipeline/skills/pipeline/SKILL.md
before="$(grep -n 'ROLL NOTHING BACK' "$O")"
sed -i 's/ROLL NOTHING BACK\. Whether to continue/ROLL THE TREE BACK TO ITS LAST GOOD STATE. Whether to continue/' "$O"
after="$(grep -n 'ROLL THE TREE BACK' "$O")"
echo "BEFORE: $before"
echo "AFTER : $after"
[ -n "$after" ] || { echo "MUTATION DID NOT LAND — the sed matched nothing"; }
```

### 3c. Watch it go red

```bash
out="$(mktemp)"
bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/prose.bats > "$out" 2>&1
rc=$?
grep '^not ok ' "$out" || echo "STILL GREEN — the pin did not catch this mutation"
echo "exit status: $rc   (expected: non-zero)"
```

### 3d. Restore, and prove the restore

```bash
cp "$SCRATCH/SKILL.md.orig" pipeline/skills/pipeline/SKILL.md
cmp pipeline/skills/pipeline/SKILL.md "$SCRATCH/SKILL.md.orig" && echo "restored byte-identical"
git status --short pipeline/skills/pipeline/SKILL.md
echo "(the line above must print nothing)"
```

---

## 4. The appending mutant

This one is separate because the seven row rewrites cannot expose it. Every
rewrite fails a substring match as well as a whole-line match, so a pin built
with the wrong flag looks fully proven. This mutant leaves the row untouched
and adds a cell after it.

```bash
O=pipeline/skills/pipeline/SKILL.md
row='| "The gate will obviously be answered yes" | Gates exist because the answer is not yours. Show the content, wait. |'
python - "$O" <<'PY'
import sys
p = sys.argv[1]
row = '| "The gate will obviously be answered yes" | Gates exist because the answer is not yours. Show the content, wait. |'
add = ' Except under `--auto`, where you may answer it yourself. |'
s = open(p, encoding='utf-8').read()
assert row in s, "MUTATION DID NOT LAND — row not found"
open(p, 'w', encoding='utf-8').write(s.replace(row, row + add, 1))
PY
grep -n 'Except under `--auto`, where you may answer it yourself' "$O"
echo "(the line above must print the mutated row — if it prints nothing, the mutation did not land)"
```

Then run section 2. The pin must go red. Then restore with section 3d.

Python is used here rather than `sed` because the row contains `|`, `"` and a
backtick; escaping all three into a `sed` expression is how a mutation quietly
becomes a no-op.

---

## 5. Boundary checks

Proves the slice helper's own guards fire. Rename a closing boundary and the
slice runs to end of file — the pin must complain about the boundary, not
about the prose.

```bash
O=pipeline/skills/pipeline/SKILL.md
sed -i 's/^## Resume$/## Resuming a run/' "$O"
grep -n '^## Resuming a run$' "$O"
echo "(must print the renamed heading)"
```

Run section 2: the roll-nothing-back pin must fail naming its closing
boundary, not naming the prose. Restore with section 3d.

---

## 6. The reflow check

Proves the four multi-line pins tolerate a rewrap. The red-flag rows are
excluded by construction: a row is one line and has no width to change.

```bash
O=pipeline/skills/pipeline/SKILL.md
python - "$O" <<'PY'
import sys, textwrap
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
start = s.index('**N — re-verify and update the PR.**')
end   = s.index('**N.5 — runtime check.**')
block = s[start:end]
rewrapped = textwrap.fill(' '.join(block.split()), width=58) + '\n\n'
assert rewrapped != block, "REWRAP DID NOT CHANGE ANYTHING"
open(p, 'w', encoding='utf-8').write(s[:start] + rewrapped + s[end:])
PY
sed -n "$(grep -n 'N — re-verify' "$O" | cut -d: -f1),+3p" "$O"
echo "(must show the N block at a different line width)"
```

Run section 2: all five new pins must stay GREEN. Restore with section 3d.

---

## 7. The completeness check

Proves a new row cannot be added without being pinned.

```bash
O=pipeline/skills/pipeline/SKILL.md
python - "$O" <<'PY'
import sys
p = sys.argv[1]
anchor = '| "Re-running this phase might duplicate work" |'
s = open(p, encoding='utf-8').read()
i = s.index(anchor)
j = s.index('\n', i) + 1
new = '| "Nobody will read this row anyway" | They will. |\n'
open(p, 'w', encoding='utf-8').write(s[:j] + new + s[j:])
PY
grep -n 'Nobody will read this row anyway' "$O"
echo "(must print the added row)"
```

Run section 2: the red-flag pin must go red, naming the unpinned row. Restore
with section 3d.

---

## 8. The final verdict

Run section 1 again from the repository root. `1..159`, 159 ok, 0 not ok,
status 0.

Then prove the orchestrator survived everything above:

```bash
cmp pipeline/skills/pipeline/SKILL.md "${TMPDIR:-/tmp}/prose-mutation/SKILL.md.orig" && echo "orchestrator byte-identical"
git status --short
echo "(pipeline/skills/pipeline/SKILL.md must not appear above)"
```
