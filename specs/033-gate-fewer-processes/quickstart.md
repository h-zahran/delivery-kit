# Quickstart: validate that the gate starts fewer processes, says the same, and runs its walk from its own file

Run from the repository root on the feature branch, in Git Bash or any
bash 5. The `bash` blocks below are ONE script: extract every `bash` block
in order into a file and run that file with `bash`. Never paste it into an
interactive shell, because a failure exits the shell. Each check prints
its ID and `ok`, or stops with `FAIL`. Block 2 and block 6 use scratch
worktrees; block 6 runs `tests/portability.bats` twice over a wrapper and
block 7 runs the house suite: run the file in the background or with a
long timeout.

`$BASE` is the branch's base, `2b38f74`. Research IDs: R1-R12 in
[research.md](research.md); the new messages in
[contracts/release-gate.md](contracts/release-gate.md).

## 1. Setup

```bash
set -u
BASE=2b38f74
fail() { echo "FAIL $*"; exit 1; }
CLEANUP=()
wt=""
trap '[ -n "$wt" ] && { git worktree remove --force "$wt" 2>/dev/null || { rm -rf -- "$wt"; git worktree prune; }; }; for p in "${CLEANUP[@]+"${CLEANUP[@]}"}"; do [ -n "$p" ] && rm -rf -- "$p"; done' EXIT
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || fail "base $BASE not found"
[ -f .claude-plugin/marketplace.json ] || fail "not at the repository root"
BATS="$HOME/bats/bin/bats"
[ -f "$BATS" ] || fail "bats not found at the path CONTRIBUTING.md gives"
GATE=$PWD/scripts/check-versions.sh
WALK=$PWD/scripts/check-versions-walk.awk
[ -f "$WALK" ] || fail "no walk file at scripts/check-versions-walk.awk"
tmp=$(mktemp -d) && [ -d "$tmp" ] || fail "mktemp -d"
CLEANUP+=("$tmp")
REALJQ=$(command -v jq) || fail "jq not on PATH"
# A jq that logs each start, then runs the real one.
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\nprintf x >> "%s"\nexec "%s" "$@"\n' "$tmp/jq.log" "$REALJQ" > "$tmp/bin/jq"
chmod +x "$tmp/bin/jq"
echo "setup ok"
```

## 2. The real tree: the same output, and 1 + N processes (SC-001)

```bash
git worktree add -q --detach "$tmp/base" "$BASE" || fail "SC-001 worktree"
wt=$tmp/base
plugins=$(ls -d */.claude-plugin/plugin.json | wc -l | tr -d ' ')
released=""
for form in "" "--released handoff" "--released pipeline"; do
  base_out=$(cd "$wt" && bash scripts/check-versions.sh $form 2>&1); base_rc=$?
  : > "$tmp/jq.log"
  now_out=$(PATH="$tmp/bin:$PATH" bash scripts/check-versions.sh $form 2>&1); now_rc=$?
  n=$(wc -c < "$tmp/jq.log" | tr -d ' ')
  [ "$now_rc" = "$base_rc" ] && [ "$now_out" = "$base_out" ] \
    || fail "SC-001 '${form:-default}' changed: rc $base_rc -> $now_rc; output: $now_out"
  # On the real tree every plugin is read before any refusal (a plugin
  # with unreleased work refuses after its own read), so the count is
  # 1 + N in every form; only the default form must exit 0.
  [ "$n" = $((plugins + 1)) ] || fail "SC-001 '${form:-default}': $n jq processes, expected $((plugins + 1))"
  if [ -z "$form" ]; then
    [ "$now_rc" = 0 ] || fail "SC-001 the default form refused the real tree: $now_out"
    released=$(printf '%s\n' "$now_out" | LC_ALL=C sed -n 's/^\([A-Za-z0-9_-]*\): plugin=.* state=released$/\1/p')
  fi
done
[ -n "$released" ] || fail "SC-001 no plugin of the real tree reads state=released"
: > "$tmp/jq.log"
(cd "$wt" && PATH="$tmp/bin:$PATH" bash scripts/check-versions.sh > /dev/null 2>&1)
old=$(wc -c < "$tmp/jq.log" | tr -d ' ')
git worktree remove --force "$wt" || fail "SC-001 worktree not removed"
wt=""
echo "SC-001 ok ($old jq processes at $BASE, $((plugins + 1)) now)"
```

## 3. The walk's text did not change (FR-005, R7)

```bash
git show "$BASE:scripts/check-versions.sh" | sed -n '545,728p' > "$tmp/old-body"
[ "$(head -1 "$tmp/old-body")" = '      function expand(s,   o, i, c, col) {' ] \
  || fail "FR-005 the old body does not start where research R7 says"
first=$(grep -n -m1 '^      function expand(s,   o, i, c, col) {$' "$WALK" | cut -d: -f1)
[ -n "$first" ] || fail "FR-005 the walk file has no body start"
last=$(wc -l < "$WALK" | tr -d ' ')
# The body, then exactly one rule: the end token (FR-006).
[ "$(tail -n 1 "$WALK")" = 'END { print "WALK-END" }' ] || fail "FR-005 the walk's last line is not its end-token rule"
sed -n "${first},$((last - 1))p" "$WALK" > "$tmp/new-body"
cmp -s "$tmp/old-body" "$tmp/new-body" || fail "FR-005 the walk's text changed: $(diff "$tmp/old-body" "$tmp/new-body" | head -5)"
head -n $((first - 1)) "$WALK" | grep -v '^#' | grep -q . && fail "FR-005 the header holds a line that is not a comment"
echo "FR-005 ok"
```

## 4. The walk runs on its own, and the gate adds only its prefix and suffix (FR-007)

```bash
dated_re=$(sed -n "s/^dated_re='\(.*\)'\$/\1/p" "$GATE")
[ -n "$dated_re" ] || fail "FR-007 dated_re not found in the gate"
# The walk's last line is its end token, taken off here as the gate takes
# it off; an output without it fails.
walk() {
  local o e=WALK-END
  o=$(DATED_RE="$dated_re" LINE_LIMIT=1000 QUOTE_CUT=200 LC_ALL=C awk -f "$WALK") || return 1
  case $o in
    "$e") o= ;;
    *$'\n'"$e") o=${o%$'\n'"$e"} ;;
    *) echo "no end token: $o"; return 1 ;;
  esac
  printf '%s' "$o"
}
# Only a changelog whose plugin reads state=released (block 2) is one the
# walk must accept; another holds an Unreleased heading the walk refuses.
for p in $released; do
  out=$(walk < "$p/CHANGELOG.md") || fail "FR-007 walk failed on $p"
  [ -z "$out" ] || fail "FR-007 walk refused the released $p changelog: $out"
done
printf '%s\n' '# Changelog' '' '## [1.0.0] - 2026-01-01' '' '## Notes ##[x' > "$tmp/bad.md"
w=$(walk < "$tmp/bad.md") || fail "FR-007 walk failed on the planted heading: $w"
[ -n "$w" ] || fail "FR-007 walk accepted an undated heading"
fx="$tmp/fx"; mkdir -p "$fx/.claude-plugin" "$fx/handoff/.claude-plugin"
cp handoff/.claude-plugin/plugin.json "$fx/handoff/.claude-plugin/"
jq '.plugins |= map(select(.name == "handoff"))' .claude-plugin/marketplace.json > "$fx/.claude-plugin/marketplace.json"
v=$(jq -r .version handoff/.claude-plugin/plugin.json)
printf '%s\n' '# Changelog' '' "## [$v] - 2026-01-01" '' '## Notes ##[x' > "$fx/handoff/CHANGELOG.md"
# Standard error only: the report line goes to standard output first.
g=$(cd "$fx" && bash "$GATE" --released handoff 2>&1 >/dev/null); rc=$?
[ "$rc" = 1 ] || fail "FR-007 gate exit $rc on the planted heading"
w=$(walk < "$fx/handoff/CHANGELOG.md") || fail "FR-007 walk failed on the fixture: $w"
hh='##[' hm='#?['
[ "$g" = "check-versions.sh: handoff: ${w//"$hh"/$hm} — this tree is NOT released" ] \
  || fail "FR-007 the gate's line is not prefix + walk text + suffix: $g"
echo "FR-007 ok"
```

## 5. A missing, wrong or failing walk file stops the gate (FR-006, SC-004)

```bash
mk() { # mk <dir>: a copy of the gate and walk, and a fixture whose release form reaches the walk
  mkdir -p "$1/scripts"; cp "$GATE" "$WALK" "$1/scripts/"
  mkdir -p "$1/t"; cp -r "$fx/.claude-plugin" "$fx/handoff" "$1/t/"
  printf '%s\n' '# Changelog' '' "## [$v] - 2026-01-01" '' '- a change' > "$1/t/handoff/CHANGELOG.md"
}
mk "$tmp/c0"
(cd "$tmp/c0/t" && bash ../scripts/check-versions.sh --released handoff > /dev/null 2>&1) \
  || fail "SC-004 control: the copied gate refused a released fixture"
mk "$tmp/c1"; rm "$tmp/c1/scripts/check-versions-walk.awk"
o=$(cd "$tmp/c1/t" && bash ../scripts/check-versions.sh --released handoff 2>&1); rc=$?
[ "$rc" = 1 ] && [[ $o == *"the heading walk check-versions-walk.awk beside the gate could not be read — this tree is NOT released"* ]] \
  || fail "FR-006 missing walk: rc $rc: $o"
mk "$tmp/c2"; rm "$tmp/c2/scripts/check-versions-walk.awk"; mkdir "$tmp/c2/scripts/check-versions-walk.awk"
o=$(cd "$tmp/c2/t" && bash ../scripts/check-versions.sh --released handoff 2>&1); rc=$?
[ "$rc" = 1 ] && [[ $o == *"could not be read"* ]] || fail "FR-006 directory walk: rc $rc: $o"
mk "$tmp/c3"; printf 'BEGIN { exit 3 }\n' > "$tmp/c3/scripts/check-versions-walk.awk"
o=$(cd "$tmp/c3/t" && bash ../scripts/check-versions.sh --released handoff 2>&1); rc=$?
[ "$rc" = 1 ] && [[ $o == *"the heading walk did not run to the end — this tree is NOT released"* ]] \
  || fail "FR-006 failing walk: rc $rc: $o"
mk "$tmp/c5"; : > "$tmp/c5/scripts/check-versions-walk.awk"
o=$(cd "$tmp/c5/t" && bash ../scripts/check-versions.sh --released handoff 2>&1); rc=$?
[ "$rc" = 1 ] && [[ $o == *"the heading walk did not run to the end — this tree is NOT released"* ]] \
  || fail "FR-006 empty walk: rc $rc: $o"
mk "$tmp/c4"
{ printf '%s\n' "# a comment that isn't a problem"; cat "$tmp/c4/scripts/check-versions-walk.awk"; } > "$tmp/c4/walk.new" \
  && mv "$tmp/c4/walk.new" "$tmp/c4/scripts/check-versions-walk.awk"
grep -q "isn't" "$tmp/c4/scripts/check-versions-walk.awk" || fail "SC-004 the apostrophe plant did not land"
(cd "$tmp/c4/t" && bash ../scripts/check-versions.sh --released handoff > /dev/null 2>&1) \
  || fail "SC-004 an apostrophe in a walk comment broke the gate"
echo "FR-006 ok"
```

## 6. The differential over every fixture the suite builds (FR-003, R10)

```bash
bash specs/033-gate-fewer-processes/proof/differential.sh "$BASE" > "$tmp/diff.out" 2>&1; rc=$?
tail -5 "$tmp/diff.out"
[ "$rc" = 0 ] || fail "FR-003 the differential reported a difference it does not expect"
grep -q '^DIFFERENTIAL OK' "$tmp/diff.out" || fail "FR-003 no verdict line"
grep -q '^CONTROL OK' "$tmp/diff.out" || fail "FR-003 the one-byte mutant was not caught"
echo "FR-003 ok"
```

## 7. The house suite (SC-006)

```bash
"$BATS" -r --print-output-on-failure tests handoff/tests pipeline/tests > "$tmp/suite.tap" 2>&1
bash scripts/check-suite.sh 436 "$tmp/suite.tap" || fail "SC-006 suite: $(grep '^not ok' "$tmp/suite.tap" | head -5)"
echo "SC-006 ok"
echo "ALL OK"
```
