# Quickstart: validating the documentation says pieces

Run every block from the repository root, in Git Bash, in ONE shell (later
blocks read `$S` and `flat` from steps 1 and 2). Every check exits non-zero
on failure; extract the blocks to a script file and run it, never retype.

## 1. Derive the file set

```bash
S="$(mktemp -d)"
git ls-files -- '*.md' '*.json' \
  | grep -vE '^(specs/|main-plan\.md|\.specify/|docs/)' > "$S/files.txt"
[ -s "$S/files.txt" ] || { echo "no files derived"; exit 1; }
wc -l < "$S/files.txt"
```

## 2. Each claim: positive control, then the hit list, over FLATTENED files

A phrase wrapped across two lines is still one phrase, so each file is
flattened (newlines to spaces, runs of spaces squeezed) before it is searched.
A hit is reported by file, with the flattened context around it.

```bash
flat() { tr '\n' ' ' | tr -s ' '; }
claim() {  # claim <pattern> <control-rev> <control-file>
  git show "$2:$3" | flat | grep -qiF -- "$1" \
    || { echo "CONTROL FAILED: '$1' not found in $2:$3"; return 1; }
  echo "== $1 (control ok in $2:$3)"
  local f n=0
  while IFS= read -r f; do
    if flat < "$f" | grep -qiF -- "$1"; then
      flat < "$f" | grep -oiE ".{0,60}$(printf '%s' "$1" | sed 's/[][\.*^$/]/\\&/g').{0,40}" \
        | sed "s|^|$f: |"
      n=$((n + 1))
    fi
  done < "$S/files.txt"
  [ "$n" -gt 0 ] || echo "(no hits)"
}
claim 'five stops' db2875d README.md || exit 1
claim 'no gate stopping' db2875d pipeline/docs/configuration.md || exit 1
claim 'without a single gate' db2875d README.md || exit 1
claim 'K commits' HEAD pipeline/skills/pipeline/SKILL.md || exit 1
claim 'one commit' HEAD pipeline/skills/pipeline/SKILL.md || exit 1
claim 'pre-answers the implementer gate' db2875d README.md || exit 1
claim 'pre-answer the implementer gate' db2875d README.md || exit 1
claim 'pre-answers the gate' db2875d pipeline/docs/configuration.md || exit 1
claim 'pre-answers a gate' db2875d README.md || exit 1
# Asserted: no false pattern survives in the documents this feature owns.
left=0
for f in README.md pipeline/README.md pipeline/docs/*.md pipeline/skills/status/SKILL.md; do
  for p in 'five stops' 'no gate stopping' 'without a single gate' 'pre-answers the implementer gate' \
           'pre-answer the implementer gate' 'pre-answers the gate' 'pre-answers a gate' \
           'records the typed answer and does not stop' 'clarify only' 'whole of what the run asks you' \
           'only places it asks' 'an `implementer` already set' 'never stages anything outside the commit gate'; do
    flat < "$f" | grep -qiF -- "$p" && { echo "STILL FALSE in $f: $p"; left=1; }
  done
done
[ "$left" -eq 0 ] || exit 1
echo "no false pattern left in the owned documents"
```

Expected after the change: every control ok. Every remaining hit is judged in
the commit message: in the orchestrator and in `pipeline/CHANGELOG.md` it must
be true or history; `handoff/` and `scripts/` hits use "one commit" about git
history and are unrelated; `pipeline/skills/pipeline/SKILL.md`'s "A key that
pre-answers a gate changes the run's consent profile" is the one known
out-of-scope hit (contract S6). The last loop ASSERTS that no false pattern
remains in `README.md`, `pipeline/README.md` or `pipeline/docs/`; before the
change it fails, listing them.

## 3. History and scope

```bash
git diff --exit-code db2875d -- .claude-plugin pipeline/.claude-plugin pipeline/commands \
  || { echo "a manifest or the command changed"; exit 1; }
# The changelog only gains lines: numstat's second column counts removed lines.
# An empty numstat (a bad revision, a wrong path) must fail, not pass.
git diff --numstat db2875d -- pipeline/CHANGELOG.md \
  | awk '$2 > 0 { print "a changelog line was removed or edited"; bad = 1 } $1 > 0 { seen = 1 }
         END { if (!seen) { print "no changelog addition found"; bad = 1 } exit bad }' || exit 1
# Every added changelog line sits under `## [Unreleased]`: below that heading,
# above the first released one.
unreleased="$(grep -n '^## \[Unreleased\]' pipeline/CHANGELOG.md | cut -d: -f1)"
first_release="$(grep -n '^## \[[0-9]' pipeline/CHANGELOG.md | head -1 | cut -d: -f1)"
[ -n "$unreleased" ] && [ -n "$first_release" ] || { echo "changelog headings not found"; exit 1; }
git diff -U0 db2875d -- pipeline/CHANGELOG.md | grep -E '^@@' | sed -E 's/^@@ [^+]*\+([0-9]+).*/\1/' \
  | while read -r start; do [ "$start" -gt "$unreleased" ] && [ "$start" -lt "$first_release" ] || { echo "changelog edit at line $start is outside Unreleased"; exit 1; }; done || exit 1
# The orchestrator changes by exactly one line.
[ "$(git diff --numstat db2875d -- pipeline/skills/pipeline/SKILL.md)" = "$(printf '1\t1\tpipeline/skills/pipeline/SKILL.md')" ] \
  || { echo "the orchestrator did not change by exactly item 9's one line"; git diff --numstat db2875d -- pipeline/skills/pipeline/SKILL.md; exit 1; }
echo "history and scope ok"
```

Positive control for the changelog guard: in a scratch copy, change one
character of a released bullet and watch the numstat check print its message
(done 2026-10-01 with the reviewer's example: the old `grep` form passed an
edited bullet, rc=1; the numstat form catches it).

## 4. The house suite, count unchanged

```bash
out="$S/suite.txt"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$out" 2>&1
rc=$?
plan="$(head -1 "$out")"; ok="$(grep -c '^ok ' "$out")"; nok="$(grep -c '^not ok' "$out")"
nontap="$(grep -cvE '^(ok |not ok |1\.\.|#)' "$out")"
skip="$(grep -c '^ok .* # skip' "$out")"
echo "plan=$plan ok=$ok notok=$nok nontap=$nontap skip=$skip rc=$rc"
[ "$rc" -eq 0 ] && [ "$plan" = "1..240" ] && [ "$ok" -eq 240 ] && [ "$nok" -eq 0 ] && [ "$nontap" -eq 0 ] && [ "$skip" -eq 0 ] \
  || { echo "suite not as expected"; exit 1; }
```

Expected: `1..240`, 240 ok, 0 not ok, 0 non-TAP, exit 0 — the ok count is
compared to the plan line, because a test can be counted and never run. The
link checker and the vocabulary scans are in this suite.

## 5. The same-file anchors the link checker skips

Each file's `](#…)` links are checked against that file's own headings.

```bash
slug() { sed -E 's/^#+ +//' | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9 -]//g; s/ /-/g'; }
for f in README.md pipeline/README.md; do
  for a in $(grep -oE '\]\(#[^)]+\)' "$f" | sed -E 's/.*\(#//; s/\)$//' | sort -u); do
    grep -E '^#{1,6} ' "$f" | slug | grep -qxF -- "$a" \
      || { echo "BROKEN same-file anchor in $f: #$a"; exit 1; }
  done
done; echo "same-file anchors ok"
```

Positive control: run it once with a known-bad anchor added to a scratch copy
and watch it report BROKEN.
