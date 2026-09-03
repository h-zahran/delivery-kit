# Quickstart: release pipeline 1.2.0 and handoff 2.1.1

**Date**: 2026-09-03 | **Branch**: `016-release-two-plugins`

**Every block below is meant to be RUN, not read.** A block whose value is an
assertion carries `set -e`, because without it a refused assertion prints and the
block carries on to produce a confident, wrong answer — which has happened in
this repository, in the very section telling a reader to verify rather than
trust.

Run every block from the **repository root**. A suite can pass in a worktree and
fail at the root; the root is the verdict.

---

## 1. Preconditions — assert the targets before touching anything

A `sed` that matches nothing exits 0 and changes nothing. Success and total
failure print the same thing, so the counts are asserted first.

This block is **state-aware on purpose**. It passes both before the edits (each
target holds its old value exactly once) and after them (each holds its new value
exactly once), and names which state it found. An earlier version asserted only
the pre-edit state, so re-running the document after section 3 produced a red on
a correct tree — and a block that is permanently red on correct work teaches a
reader to skim past the one line that matters.

```bash
set -e
cd "$(git rev-parse --show-toplevel)"

# Exactly one of old/new must be present, exactly once. Neither, both, or a
# duplicate is a failure: a sed that matches nothing exits 0 and changes nothing.
expect_one() {  # file, old-literal, new-literal
  o=$(grep -cF -- "$2" "$1" || true)
  n=$(grep -cF -- "$3" "$1" || true)
  if   [ "$o" = "1" ] && [ "$n" = "0" ]; then echo "ok  PRE  $1 : $2"
  elif [ "$n" = "1" ] && [ "$o" = "0" ]; then echo "ok  POST $1 : $3"
  else echo "FAIL $1 : old=$o new=$n, expected exactly one of them to be 1"; exit 1; fi
}

expect_one pipeline/.claude-plugin/plugin.json '  "version": "1.1.0",'       '  "version": "1.2.0",'
expect_one handoff/.claude-plugin/plugin.json  '  "version": "2.1.0",'       '  "version": "2.1.1",'
expect_one .claude-plugin/marketplace.json     '      "version": "1.1.0",'   '      "version": "1.2.0",'
expect_one .claude-plugin/marketplace.json     '      "version": "2.1.0",'   '      "version": "2.1.1",'
expect_one pipeline/CHANGELOG.md               '## [Unreleased]'             '## [1.2.0] - 2026-09-03'
expect_one handoff/CHANGELOG.md                '## [Unreleased]'             '## [2.1.1] - 2026-09-03'
echo "PRECONDITIONS OK"
```

Note the indentation in the patterns: **two** spaces in a manifest, **six** in a
marketplace entry. They are not interchangeable.

Note the indentation in the patterns: **two** spaces in a manifest, **six** in a
marketplace entry. They are not interchangeable.

---

## 2. Record the pre-edit heading positions

Derived, not hardcoded — a line number written into a document stops being true
the moment anything is inserted above it.

Read from `$BASE`, not from the working tree, so the number is the same whether
this is run before or after section 3. The position is the thing section 5 needs,
and it is a property of the pre-edit file.

```bash
set -e
cd "$(git rev-parse --show-toplevel)"
BASE=c2259d5
for f in pipeline/CHANGELOG.md handoff/CHANGELOG.md; do
  n=$(git show "$BASE:$f" | grep -n '^## \[Unreleased\]$' | cut -d: -f1)
  [ -n "$n" ] || { echo "FAIL: $BASE:$f has no Unreleased heading"; exit 1; }
  echo "$f heading was at line $n in $BASE"
done
```

---

## 3. The six edits

`sed`, never `jq`. Measured: a `jq` round trip with no change rewrites all three
JSON files end to end, because the tracked files keep an array inline and `jq`
expands it. See research.md D1.

```bash
set -e
cd "$(git rev-parse --show-toplevel)"

sed -i 's/^  "version": "1\.1\.0",$/  "version": "1.2.0",/' pipeline/.claude-plugin/plugin.json
sed -i 's/^  "version": "2\.1\.0",$/  "version": "2.1.1",/' handoff/.claude-plugin/plugin.json
sed -i 's/^      "version": "1\.1\.0",$/      "version": "1.2.0",/' .claude-plugin/marketplace.json
sed -i 's/^      "version": "2\.1\.0",$/      "version": "2.1.1",/' .claude-plugin/marketplace.json
sed -i 's/^## \[Unreleased\]$/## [1.2.0] - 2026-09-03/' pipeline/CHANGELOG.md
sed -i 's/^## \[Unreleased\]$/## [2.1.1] - 2026-09-03/' handoff/CHANGELOG.md
echo "SIX EDITS APPLIED"
```

---

## 4. Prove every edit LANDED, and landed exactly once

A mutation that did not land is a silent false green. `--numstat` prints
`<added> <removed> <path>`; one line changed reads `1 1`.

```bash
set -e
cd "$(git rev-parse --show-toplevel)"
git diff --numstat -- \
  pipeline/.claude-plugin/plugin.json \
  handoff/.claude-plugin/plugin.json \
  .claude-plugin/marketplace.json \
  pipeline/CHANGELOG.md \
  handoff/CHANGELOG.md
```

Expected, exactly:

```text
2       2       .claude-plugin/marketplace.json
1       1       handoff/.claude-plugin/plugin.json
1       1       handoff/CHANGELOG.md
1       1       pipeline/.claude-plugin/plugin.json
1       1       pipeline/CHANGELOG.md
```

The marketplace shows `2 2` because it carries two entries. Anything larger in
any row means a reformat happened and the edit must be undone and redone.

---

## 5. Prove the changelog CONTENT is untouched

FR-007. The heading line changes; nothing below it may. Compare the range below
the heading against the same range in `HEAD`, with the position derived from
`HEAD` rather than assumed.

**The baseline is pinned to a commit id, never to `HEAD`.** This repository
rebase-merges, and the moment the release commit lands, `HEAD:` carries no
`## [Unreleased]` heading at all — the block would then exit 1 on a correct tree
and the FR-007 evidence could never be reproduced. `BASE` is the merge base this
branch was cut from.

```bash
set -e
cd "$(git rev-parse --show-toplevel)"
BASE=c2259d5
for f in pipeline/CHANGELOG.md handoff/CHANGELOG.md; do
  n=$(git show "$BASE:$f" | grep -n '^## \[Unreleased\]$' | cut -d: -f1)
  [ -n "$n" ] || { echo "FAIL: $BASE:$f has no Unreleased heading"; exit 1; }
  after=$((n + 1))
  if git show "$BASE:$f" | tail -n "+$after" | diff -q - <(tail -n "+$after" "$f") > /dev/null; then
    echo "ok: $f is byte-identical below line $n"
  else
    echo "FAIL: $f changed below its heading"; exit 1
  fi
done
```

---

## 6. Run the agreement gate

```bash
set -e
cd "$(git rev-parse --show-toplevel)"
bash scripts/check-versions.sh
```

Expected, and **both halves matter**:

```text
handoff: plugin=2.1.1 marketplace=2.1.1 changelog=2.1.1
pipeline: plugin=1.2.0 marketplace=1.2.0 changelog=1.2.0
```

Exit 0 says the three records agree. The printed values say they agree on the
RIGHT number — a release that stamped the old version everywhere would satisfy
the first and fail the second.

---

## 7. Verify the fold DIRECTLY — the gate above cannot see it

This is the section that matters most, and section 6 is not a substitute for it.
`check-versions.sh` reads the changelog with `grep -m1` against a date-anchored
pattern. `## [Unreleased]` does not match, so it is **skipped**, not rejected,
and an older heading is read in its place. The gate passed on the broken tree.

One implementation, two callers — the check is a function so the positive
control in 7b runs the same code, not a copy of it.

Two rules are load-bearing in the function below, and both were found by review
after an earlier version shipped without them.

**It DERIVES the changelogs instead of naming them.** An enumerated pair goes
stale the day a third plugin lands, and the new one is silently unchecked.

**It refuses to walk nothing.** With the paths named and errors swallowed,
`no_unreleased /nonexistent-path` printed `ok` and returned 0 — "scanned
nothing" and "found nothing" are the same sentence. That is Principle I
violated inside the artefact that cites it.

```bash
set -e
cd "$(git rev-parse --show-toplevel)"

# Reports every dangling heading under $1. Exit 1 if any, or if it scanned nothing.
no_unreleased() {  # directory to check
  logs=$(find "$1" -mindepth 2 -maxdepth 2 -name CHANGELOG.md 2>/dev/null | sort)
  n=$(printf '%s' "$logs" | grep -c . || true)
  [ "$n" -ge 2 ] || { echo "FAIL: found $n plugin changelog(s) under $1, expected at least 2 — this walk verified nothing"; return 2; }
  echo "scanning $n changelog(s) under $1"
  found=$(printf '%s\n' "$logs" | xargs grep -l '^## \[Unreleased\]$' 2>/dev/null || true)
  if [ -n "$found" ]; then
    echo "DANGLING Unreleased heading in:"; echo "$found"; return 1
  fi
  echo "ok: no Unreleased heading in any plugin changelog"; return 0
}

no_unreleased .
```

### 7b. Positive control — prove section 7 can FAIL

Verification that has only ever passed has not been shown able to fail. Run the
same function against a copy that still carries the heading. **It must report a
finding**; if it says "ok", section 7 proves nothing and the release must stop.

**The first line is the most important one in this document.** Without it, this
block run on its own printed `CONTROL OK` while `no_unreleased` did not exist —
measured: `no_unreleased: command not found`, then `CONTROL OK`, exit 0. `set -e`
is inert inside an `if` condition, and a missing command returns 127, which is
falsy, so control flow took the success branch. A control that announces success
when the thing it tests is absent is worse than no control at all.

```bash
set -e
cd "$(git rev-parse --show-toplevel)"
BASE=c2259d5

# The function under test MUST exist. Run section 7 first, in this same shell.
type no_unreleased >/dev/null 2>&1 \
  || { echo "FAIL: no_unreleased is not defined — run section 7 in this shell first"; exit 1; }

ctl=$(mktemp -d)
mkdir -p "$ctl/pipeline" "$ctl/handoff"
git show "$BASE:pipeline/CHANGELOG.md" > "$ctl/pipeline/CHANGELOG.md"
git show "$BASE:handoff/CHANGELOG.md"  > "$ctl/handoff/CHANGELOG.md"

# Confirm the control input really is the pre-fold state — BOTH files, not one.
for f in "$ctl/pipeline/CHANGELOG.md" "$ctl/handoff/CHANGELOG.md"; do
  grep -q '^## \[Unreleased\]$' "$f" \
    || { echo "FAIL: control input $f has no Unreleased heading; it proves nothing"; rm -rf "$ctl"; exit 1; }
done

set +e; no_unreleased "$ctl"; rc=$?; set -e
if [ "$rc" = "1" ]; then
  echo "CONTROL OK: the check reported the dangling heading when one was present"
elif [ "$rc" = "0" ]; then
  echo "FAIL: the check PASSED a tree that does carry the heading — it cannot go red"; rm -rf "$ctl"; exit 1
else
  echo "FAIL: the check returned $rc — it refused to scan, so it proved nothing"; rm -rf "$ctl"; exit 1
fi
rm -rf "$ctl"
```

The exit status is tested for the exact value `1`, not merely for "non-zero".
The function returns `2` when it refuses to scan, and treating that as a caught
finding would be the vacuous pass this control exists to prevent.

Section 7b needs `no_unreleased` from section 7 in the same shell — and now says
so by refusing rather than by asking. It is deliberately NOT a pasted copy of
the function: one implementation, two callers.

---

## 8. Prove EXACTLY five files changed

FR-010 and SC-004. Derived by counting the diff, not by reading the list back.

**The pathspec is part of the check, not a convenience.** Without it this block
counts six and exits 1 — measured — because the constitution written earlier in
this run lives under `.specify/` and rides this branch. The boundary is encoded
here and in SC-004 rather than narrated, so the check is true in every state
instead of in one narrow window.

```bash
set -e
cd "$(git rev-parse --show-toplevel)"
BASE=c2259d5
n=$(git diff --name-only "$BASE" -- . ':(exclude).specify' | wc -l | tr -d ' ')
echo "feature files changed against $BASE: $n"
git diff --name-only "$BASE" -- . ':(exclude).specify'
[ "$n" = "5" ] || { echo "FAIL: expected 5 changed files, found $n"; exit 1; }
echo "FILE COUNT OK"
echo "--- and what the exclusion is hiding, named rather than hidden: ---"
git diff --name-only "$BASE" -- .specify || true
```

The second command is not decoration. An exclusion nobody prints is an exclusion
nobody audits, so the block names what it left out.

The diff is taken against `$BASE`, not the working tree, so this block keeps
working after the release is committed. `git diff --name-only` alone reports
zero once the commit lands, which would fail on a correct tree.

---

## 9. The full house suite

Named paths, from the root. Passing only `tests` runs the repository's own suite,
silently skips both plugins' suites, and reports green.

```bash
set -e
cd "$(git rev-parse --show-toplevel)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

Expected: `1..163`, 163 ok, 0 not ok, exit 0.

Do not pipe this into `tail` or `head`. A pipe hands the block the exit status of
the LAST command, which is always 0, and cuts the plan line bats prints first —
so the block can never go red. Redirect to a file and test the status separately
if the output needs trimming.

---

## 10. What none of this can tell you

- **That the release is on the right commit.** These checks read the working
  tree. Whether that tree is on top of the intended base is a git question.
- **That CI agrees.** The runner's toolchain is not this machine's — it ships an
  older shell analyser that reports MORE findings — so a local green does not
  predict CI. All three operating systems must pass.
- **That a future release will not dangle a heading again.** Nothing checks that.
  Section 7 is a manual gate for THIS release only. See
  `contracts/version-agreement.md` C4.
