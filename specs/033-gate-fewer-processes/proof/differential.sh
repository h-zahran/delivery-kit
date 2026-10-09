#!/usr/bin/env bash
# differential.sh <base> — run the release gate at <base> and the gate in
# this working tree side by side, over every gate run the suite makes and
# over a set of extra trees, and compare what each prints and how it exits.
# specs/033-gate-fewer-processes/research.md R10 gives the method; tasks
# T001 to T003 give the rules. Run from the repository root. Prints
# DIFFERENTIAL OK and CONTROL OK, or stops with FAIL.
#
# It builds a scratch worktree of HEAD, copies over it the working tree's
# gate, walk file and gate tests, and puts at scripts/check-versions.sh a
# wrapper. Three passes run tests/portability.bats there:
#   plain    — the wrapper logs each gate start by test name, runs the new gate;
#   compare  — it runs the old gate and the new one, compares, logs, then
#              prints the new gate's output and exits with its status;
#   control  — as compare, with the new gate's report line changed by one
#              byte, over one test: it must log a difference.
set -u
base=${1:-}
[ -n "$base" ] || { echo "usage: differential.sh <base>"; exit 2; }
fail() { echo "FAIL $*"; exit 1; }
git rev-parse --verify -q "$base^{commit}" > /dev/null || fail "base $base not found"
[ -f .claude-plugin/marketplace.json ] || fail "run me from the repository root"
root=$PWD
bats="$HOME/bats/bin/bats"
[ -f "$bats" ] || fail "bats not found at $bats"
realjq=$(command -v jq) || fail "jq not on PATH"
cmpbin=$(command -v cmp) || fail "cmp not on PATH"
catbin=$(command -v cat) || fail "cat not on PATH"
case $(uname -s) in MINGW*|MSYS*|CYGWIN*) windows=1 ;; *) windows=0 ;; esac

tmp=$(mktemp -d) && [ -d "$tmp" ] || fail "mktemp -d"
wt=$tmp/wt
cleanup() {
  git -C "$root" worktree remove --force "$wt" > /dev/null 2>&1 || { rm -rf -- "$wt"; git -C "$root" worktree prune; }
  rm -rf -- "$tmp"
}
trap cleanup EXIT
git worktree add -q --detach "$wt" HEAD || fail "worktree"
mkdir -p "$tmp/old" "$tmp/log"
git show "$base:scripts/check-versions.sh" > "$tmp/old/check-versions.sh" || fail "old gate"
cp "$root/scripts/check-versions.sh" "$wt/scripts/check-versions.new.sh"
if [ -f "$root/scripts/check-versions-walk.awk" ]; then
  cp "$root/scripts/check-versions-walk.awk" "$wt/scripts/"
fi
cp "$root/tests/portability.bats" "$root/tests/helper.bash" "$wt/tests/"

# Each run is two gates, so the copies get doubled limits; each edit is
# counted, so an edit that matched nothing is not mistaken for one made.
n=$(grep -c '^BATS_TEST_TIMEOUT=60$' "$wt/tests/helper.bash")
[ "$n" = 1 ] || fail "helper: expected one BATS_TEST_TIMEOUT=60 line, found $n"
sed -i 's/^BATS_TEST_TIMEOUT=60$/BATS_TEST_TIMEOUT=120/' "$wt/tests/helper.bash"
before=$(grep -cE 'run timeout [0-9]+ ' "$wt/tests/portability.bats")
[ "$before" -ge 1 ] || fail "no 'run timeout N' line to double"
grep -oE 'run timeout [0-9]+ ' "$wt/tests/portability.bats" | awk '{ print 2 * $3 }' > "$tmp/t.want"
awk '{ while (match($0, /run timeout [0-9]+ /)) { n = substr($0, RSTART + 12, RLENGTH - 13) + 0; $0 = substr($0, 1, RSTART - 1) "run TIMEOUT " (2 * n) " " substr($0, RSTART + RLENGTH) } gsub(/run TIMEOUT /, "run timeout "); print }' \
  "$wt/tests/portability.bats" > "$tmp/p.bats" && mv "$tmp/p.bats" "$wt/tests/portability.bats"
after=$(grep -cE 'run timeout [0-9]+ ' "$wt/tests/portability.bats")
[ "$after" = "$before" ] || fail "doubling the timeouts changed $before lines into $after"
grep -oE 'run timeout [0-9]+ ' "$wt/tests/portability.bats" | awk '{ print $3 }' > "$tmp/t.got"
cmp -s "$tmp/t.want" "$tmp/t.got" || fail "a timeout was not doubled"

# The wrapper. Paths are fixed when it is written: a test may change PATH,
# TMPDIR or the locale, and the wrapper must not depend on any of them. It
# turns off the shell options the gate turns off before it does anything.
write_wrapper() { # write_wrapper <mode> <new gate>
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set +o xtrace +o verbose +o noglob +o keyword; shopt -u dotglob nocasematch 2> /dev/null'
    printf 'mode=%q log=%q old=%q new=%q jq=%q cmpbin=%q catbin=%q\n' \
      "$1" "$tmp/log" "$tmp/old/check-versions.sh" "$2" "$realjq" "$cmpbin" "$catbin"
    "$catbin" <<'WRAPPER'
key=${BATS_TEST_DESCRIPTION:-none}
id="$$.$RANDOM.$RANDOM"
printf 'START\t%s\t%s\t%s\n' "$mode" "$id" "$key" >> "$log/runs.log"
if [ "$mode" = plain ]; then
  "$BASH" "$new" "$@"; rc=$?
  printf 'DONE\t%s\t%s\t%s\n' "$mode" "$id" "$key" >> "$log/runs.log"
  exit "$rc"
fi
o1="$log/$id.o1" e1="$log/$id.e1" o2="$log/$id.o2" e2="$log/$id.e2"
"$BASH" "$old" "$@" > "$o1" 2> "$e1"; r1=$?
"$BASH" "$new" "$@" > "$o2" 2> "$e2"; r2=$?
# LF: a read the old gate took through $( ) on Windows could have held a
# CR inside it (research R5): a plugin.json name or version, or a
# marketplace entry's version or source, holds a line feed, or two entries
# share a name (their values were read one per line). Read now: the suite
# deletes the tree after.
class=PLAIN
for f in */.claude-plugin/plugin.json; do
  [ -f "$f" ] || continue
  if "$jq" -e '[.name, .version] | any(type == "string" and test("\n"))' < "$f" > /dev/null 2>&1; then class=LF; fi
done
if [ -f .claude-plugin/marketplace.json ] \
  && "$jq" -e '([.plugins[]? | .version, .source] | any(type == "string" and test("\n"))) or ([.plugins[]?.name] | length != (unique | length))' \
    < .claude-plugin/marketplace.json > /dev/null 2>&1; then
  class=LF
fi
# SHIM: the test put a jq of its own on PATH (the R4 test's hands the new
# gate a record no real read writes, which the old gate never asks for),
# so the two gates were not given the same thing to read. Such a run is
# compared and logged, and kept out of the verdict, which counts it.
[ "$(command -v jq)" = "$jq" ] || class=SHIM
same=1
[ "$r1" = "$r2" ] || same=0
"$cmpbin" -s "$o1" "$o2" || same=0
"$cmpbin" -s "$e1" "$e2" || same=0
if [ "$same" = 0 ]; then
  printf 'DIFF\t%s\t%s\t%s\t%s\t%s %s\n' "$mode" "$id" "$class" "$key" "$r1" "$r2" >> "$log/runs.log"
else
  rm -f "$o1" "$e1"
fi
printf 'DONE\t%s\t%s\t%s\t%s\n' "$mode" "$id" "$key" "$class" >> "$log/runs.log"
"$catbin" "$o2"
"$catbin" "$e2" >&2
exit "$r2"
WRAPPER
  } > "$wt/scripts/check-versions.sh"
}

# DIFF_FILTER, when set, limits the plain and compare passes to the tests
# it names (a bats -f pattern): for trying the harness, never for a verdict.
run_pass() { # run_pass <mode> <tap> [bats -f filter]
  if [ $# -lt 3 ] && [ -n "${DIFF_FILTER:-}" ]; then
    echo "NOTE: DIFF_FILTER is set; this run is not a verdict"
    set -- "$1" "$2" "$DIFF_FILTER"
  fi
  if [ $# -ge 3 ]; then
    (cd "$wt" && "$bats" -f "$3" tests/portability.bats) > "$2" 2>&1
  else
    (cd "$wt" && "$bats" tests/portability.bats) > "$2" 2>&1
  fi
}

# count_by <mode> <tag> — "<count>\t<test name>" lines for that mode and tag.
count_by() {
  awk -F'\t' -v m="$1" -v t="$2" '$1 == t && $2 == m { c[$4]++ } END { for (k in c) printf "%d\t%s\n", c[k], k }' "$tmp/log/runs.log" | LC_ALL=C sort -t"$(printf '\t')" -k2
}

# 1. Plain pass: how many gate runs each test makes.
write_wrapper plain "$wt/scripts/check-versions.new.sh"
: > "$tmp/log/runs.log"
run_pass plain "$tmp/plain.tap"
count_by plain START > "$tmp/plain.count"
[ -s "$tmp/plain.count" ] || fail "the plain pass logged no gate run"

# 2. Compare pass.
write_wrapper compare "$wt/scripts/check-versions.new.sh"
run_pass compare "$tmp/compare.tap"
count_by compare START > "$tmp/compare.start"
count_by compare DONE > "$tmp/compare.done"
cmp -s "$tmp/compare.start" "$tmp/compare.done" \
  || fail "a compared run started and never finished: $(diff "$tmp/compare.start" "$tmp/compare.done" | head -5)"

# The expected-red set, by a rule read from each test's body: it reads,
# copies or greps the gate's file (a line naming it that is not a run of
# it), counts jq starts, or sets the gate's shell options.
awk '
  /^@test "/ { name = $0; sub(/^@test "/, "", name); sub(/" \{$/, "", name); body = 1; hit = 0; next }
  body && /^}/ { if (hit) print name; body = 0; next }
  body && /^[ \t]*#/ { next }
  body && /check-versions/ && !/bash \\?"?(\$[A-Za-z0-9_{}]+\/)?scripts\/check-versions\.sh/ { hit = 1 }
  body && /SHELLOPTS|BASHOPTS|jq_starts|die_raw/ { hit = 1 }
' "$root/tests/portability.bats" | LC_ALL=C sort > "$tmp/expected-red"

# Only a test that runs the gate is part of the comparison: one that runs
# none (a scan of the tree, say, which now meets the wrapper's own paths)
# compares nothing, whatever its result. Every such test red over the
# wrapper must be in the expected-red set; every one green over it must
# have made as many compared runs as plain ones.
cut -f2 "$tmp/plain.count" | LC_ALL=C sort > "$tmp/gate-tests"
sed -n 's/^not ok [0-9]* //p' "$tmp/compare.tap" | LC_ALL=C sort > "$tmp/red-all"
LC_ALL=C comm -12 "$tmp/red-all" "$tmp/gate-tests" > "$tmp/red"
unexpected_red=$(LC_ALL=C comm -23 "$tmp/red" "$tmp/expected-red")
[ -z "$unexpected_red" ] || fail "red over the wrapper and not in the expected-red set: $unexpected_red"
sed -n 's/^ok [0-9]* //p' "$tmp/compare.tap" | sort > "$tmp/green"
short=0
while IFS="$(printf '\t')" read -r c name; do
  if grep -qxF -- "$name" "$tmp/green"; then
    d=$(awk -F'\t' -v k="$name" '$2 == k { print $1 }' "$tmp/compare.done")
    [ "${d:-0}" = "$c" ] || { echo "SHORT $name: $c plain runs, ${d:-0} compared"; short=1; }
  else
    d=$(awk -F'\t' -v k="$name" '$2 == k { print $1 }' "$tmp/compare.done")
    echo "EXPECTED-RED $name: $c plain runs, ${d:-0} compared"
  fi
done < "$tmp/plain.count"
[ "$short" = 0 ] || fail "a green test compared fewer runs than it makes"

# 3. Extra trees: the shapes the suite does not build (research R1, R10).
extra() { # extra <id> <plugin.json text> <marketplace text>
  local d="$tmp/x/$1"
  mkdir -p "$d/.claude-plugin" "$d/x/.claude-plugin"
  printf '%s' "$2" > "$d/x/.claude-plugin/plugin.json"
  printf '%s' "$3" > "$d/.claude-plugin/marketplace.json"
  printf '%s\n' '# Changelog' '' '## [1.0.0] - 2026-01-01' '' '- a change' > "$d/x/CHANGELOG.md"
  (cd "$d" && BATS_TEST_DESCRIPTION="extra:$1" bash "$wt/scripts/check-versions.sh" > /dev/null 2>&1)
  (cd "$d" && BATS_TEST_DESCRIPTION="extra:$1" bash "$wt/scripts/check-versions.sh" --released x > /dev/null 2>&1)
}
M='{"plugins":[{"name":"x","version":"1.0.0","source":"./x"}]}'
extra plain '{"name":"x","version":"1.0.0"}' "$M"
extra othername '{"name":"y","version":"1.0.0"}' "$M"
extra noversion '{"name":"x"}' "$M"
extra noname '{"version":"1.0.0"}' "$M"
extra nullfalse '{"name":null,"version":false}' "$M"
extra empty '{"name":"","version":""}' '{"plugins":[{"name":"","version":"","source":""}]}'
extra LF1 '{"name":"x\ny","version":"1.0.0"}' "$M"
extra lfversion '{"name":"x","version":"1.0.0\n"}' '{"plugins":[{"name":"x","version":"1.0.0\n","source":"./x\n"}]}'
extra crlf '{"name":"x","version":"1.0.0\r\n"}' "$M"
extra crsource '{"name":"x","version":"1.0.0"}' '{"plugins":[{"name":"x","version":"1.0.0","source":"./x\r"}]}'
extra innerlf '{"name":"x","version":"1.0.0"}' '{"plugins":[{"name":"x","version":"1\n\n0","source":"./x"}]}'
extra dup '{"name":"x","version":"1.0.0"}' '{"plugins":[{"name":"x","version":"1.0.0","source":"./x"},{"name":"x","version":"2.0.0","source":"b"},{"name":"x","source":"c"}]}'
extra emptyentry '{"name":"x","version":"1.0.0"}' '{"plugins":[{"name":"x","version":"","source":""}]}'
extra nullentry '{"name":"x","version":"1.0.0"}' '{"plugins":[{"name":"x","version":null,"source":false}]}'
extra marks '{"name":"x","version":"1.0.0 \t \\ ##[ ::"}' '{"plugins":[{"name":"x","version":"\u00e9\ud83d\ude00","source":"./x"}]}'
extra extrakeys '{"name":"x","version":"1.0.0","extra":[1,2]}' "$M"
extra array '[]' "$M"
extra number '{"name":1}' "$M"
extra notjson 'not json' "$M"
extra emptyfile '' "$M"
extra twodocs '{"name":"x"} {"name":"y"}' "$M"
extra nul '{"name":"x\u0000"}' "$M"
extra noentries '{"name":"x","version":"1.0.0"}' '{"plugins":[]}'
extra booltrue '{"name":"x","version":true}' "$M"
extra badutf8 "$(printf '{"name":"\377\376x","version":"1.0.0"}')" '{"plugins":[{"name":"\ufffd\ufffdx","version":"9","source":"q"}]}'

# A source ending in a CR is read whole, and the gate names it, on every
# system (research R4, R5): a check of the new gate's own line, which the
# comparison cannot give, since both gates refuse this tree.
crs=$(cd "$tmp/x/crsource" && bash "$wt/scripts/check-versions.new.sh" 2>&1); crs_rc=$?
[ "$crs_rc" = 1 ] && [[ $crs == *"x: marketplace entry x has source './x?', which does not resolve to x"* ]] \
  || fail "crsource: the new gate did not name the source ending in a CR (rc $crs_rc): $crs"

# The verdict.
diffs=$(awk -F'\t' '$1 == "DIFF" && $2 == "compare"' "$tmp/log/runs.log")
plain_diffs=$(printf '%s\n' "$diffs" | awk -F'\t' '$4 == "PLAIN"')
if [ -n "$plain_diffs" ]; then
  echo "$plain_diffs"
  fail "a run whose tree holds no line feed in a name, version or source differs"
fi
lf1=$(printf '%s\n' "$diffs" | awk -F'\t' '$5 == "extra:LF1"' | wc -l | tr -d ' ')
# A run is SHIM only in a test whose own text puts a jq on PATH: one in
# any other test would be a real difference kept out of the verdict.
awk '
  /^@test "/ { name = $0; sub(/^@test "/, "", name); sub(/" \{$/, "", name); body = 1; p = 0; j = 0; next }
  body && /^}/ { if (p && j) print name; body = 0; next }
  body && /PATH="/ { p = 1 }
  body && /\/jq"/ { j = 1 }
' "$root/tests/portability.bats" | LC_ALL=C sort > "$tmp/own-jq"
awk -F'\t' '$1 == "DONE" && $2 == "compare" && $5 == "SHIM" { print $4 }' "$tmp/log/runs.log" | LC_ALL=C sort -u > "$tmp/shim-tests"
stray=$(LC_ALL=C comm -23 "$tmp/shim-tests" "$tmp/own-jq")
[ -z "$stray" ] || fail "a run read a jq that is not the real one, in a test that puts none on PATH: $stray"
shimdiff=$(printf '%s\n' "$diffs" | awk -F'\t' '$4 == "SHIM"' | wc -l | tr -d ' ')
diffs=$(printf '%s\n' "$diffs" | awk -F'\t' '$4 != "SHIM"')
ndiff=$(printf '%s\n' "$diffs" | grep -c . || true)
# The divergence is the new reads' (research R5). When the gate under test
# IS the old one, byte for byte (the harness proving itself, task T004), no
# run may differ anywhere.
if cmp -s "$tmp/old/check-versions.sh" "$wt/scripts/check-versions.new.sh"; then
  [ "$ndiff" = 0 ] || fail "the gate is unchanged, yet a run differs: $diffs"
elif [ "$windows" = 1 ]; then
  [ "$lf1" -ge 1 ] || fail "LF1 did not differ on Windows: the asserted divergence is gone (research R5)"
else
  [ "$ndiff" = 0 ] || fail "a run differs on a system that is not Windows: $diffs"
fi
runs=$(awk -F'\t' '$1 == "DONE" && $2 == "compare"' "$tmp/log/runs.log" | wc -l | tr -d ' ')
lfruns=$(awk -F'\t' '$1 == "DONE" && $2 == "compare" && $5 == "LF"' "$tmp/log/runs.log" | wc -l | tr -d ' ')
[ "$runs" -gt 0 ] || fail "no run was compared"
shimruns=$(awk -F'\t' '$1 == "DONE" && $2 == "compare" && $5 == "SHIM"' "$tmp/log/runs.log" | wc -l | tr -d ' ')
echo "DIFFERENTIAL OK ($runs runs, $lfruns LF runs, $ndiff differing; $shimruns under a test's own jq, $shimdiff of them differing, not judged)"

# 4. Control: the new gate's report line changed by one byte must be seen.
cp "$wt/scripts/check-versions.new.sh" "$tmp/mutant.sh"
n=$(grep -c "state=%s" "$tmp/mutant.sh")
[ "$n" = 1 ] || fail "control: expected one 'state=%s', found $n"
sed -i 's/state=%s/stat=%s/' "$tmp/mutant.sh"
[ "$(grep -c "stat=%s" "$tmp/mutant.sh")" = 1 ] && [ "$(grep -c "state=%s" "$tmp/mutant.sh")" = 0 ] \
  || fail "control: the mutation did not land"
mv "$tmp/mutant.sh" "$wt/scripts/check-versions.mutant.sh"
write_wrapper control "$wt/scripts/check-versions.mutant.sh"
run_pass control "$tmp/control.tap" 'manifest, marketplace entry and changelog agree'
cdiff=$(awk -F'\t' '$1 == "DIFF" && $2 == "control" && $4 == "PLAIN"' "$tmp/log/runs.log" | wc -l | tr -d ' ')
cstart=$(awk -F'\t' '$1 == "START" && $2 == "control"' "$tmp/log/runs.log" | wc -l | tr -d ' ')
cdone=$(awk -F'\t' '$1 == "DONE" && $2 == "control"' "$tmp/log/runs.log" | wc -l | tr -d ' ')
[ "$cstart" -gt 0 ] && [ "$cstart" = "$cdone" ] || fail "control: $cstart runs started, $cdone finished"
[ "$cdiff" -ge 1 ] || fail "control: the one-byte mutant was not seen"
echo "CONTROL OK ($cdiff of $cdone runs differ)"
