#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for progress.sh i-measure, the gate in phase-done I, the guard in state-set,
# and the phaseI key of pipeline-run.json. A measure not taken must read as missing,
# and never as 0.

load ../../tests/helper

setup() {
  PROG="$ROOT/pipeline/scripts/progress.sh"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
  cd "$WORK"
  F=001-demo
  RD=".delivery-kit/runs/$F"
  SF="$RD/progress.json"
  MF="$RD/pipeline-run.json"
  OUT="$BATS_TEST_TMPDIR/out"
  ERR="$BATS_TEST_TMPDIR/err"
  # A clock the test sets: the script reads epoch seconds from this file.
  CLOCK="$BATS_TEST_TMPDIR/clock"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"
  local real
  real="$(command -v date)"
  cat > "$STUBS/date" <<STUB
#!/usr/bin/env bash
if [ "\${1:-}" = +%s ] && [ -f "$CLOCK" ]; then cat "$CLOCK"; exit 0; fi
exec "$real" "\$@"
STUB
  chmod +x "$STUBS/date"
  export PATH="$STUBS:$PATH"
  printf '1000\n' > "$CLOCK"
  bash "$PROG" init "$F" "$F" main other > /dev/null
}

at() { printf '%s\n' "$1" > "$CLOCK"; }

# im <args...> — i-measure, stdout to $OUT, stderr to $ERR, status in $IM.
im() {
  IM=0
  bash "$PROG" i-measure "$F" "$@" > "$OUT" 2> "$ERR" || IM=$?
}

ok() { im "$@"; [ "$IM" -eq 0 ] || { echo "exit $IM: $(cat "$ERR")"; return 1; }; }

# refused <part of the message> <args...> — status 1, the message, the state file's bytes unchanged.
refused() {
  local want="$1" before
  shift
  before="$(cksum < "$SF")"
  im "$@"
  [ "$IM" -eq 1 ] || { echo "exit $IM, expected 1: $*"; return 1; }
  [[ "$(cat "$ERR")" == *"$want"* ]] || { echo "stderr: $(cat "$ERR")"; return 1; }
  [ ! -s "$OUT" ] || { echo "stdout: $(cat "$OUT")"; return 1; }
  [ "$(cksum < "$SF")" = "$before" ] || { echo "the state file changed: $*"; return 1; }
}

said() { [ "$(cat "$OUT")" = "$1" ] || { echo "stdout: $(cat "$OUT")"; return 1; }; }

part() { jq -c --arg p "$1" '.measurements.i.parts[$p]' "$SF"; }

# all_recorded — every part has a record and the findings are read.
all_recorded() {
  ok dispatch
  local p
  at 1100
  for p in contract security tests bugs simplify; do ok done "$p"; done
  ok start fixes; at 1150; ok done fixes
  ok start recheck; at 1170; ok done recheck
  : > "$RD/findings-I.txt"
  ok findings
}

phase_done() {
  PD=0
  bash "$PROG" phase-done "$F" "$1" > "$OUT" 2> "$ERR" || PD=$?
}

# gate_refuses <part of the message> — phase-done I, refused, the state file's bytes unchanged.
gate_refuses() {
  local before
  before="$(cksum < "$SF")"
  phase_done I
  [ "$PD" -eq 1 ] || { echo "exit $PD, expected 1"; return 1; }
  [[ "$(cat "$ERR")" == *"$1"* ]] || { echo "stderr: $(cat "$ERR")"; return 1; }
  [ "$(cksum < "$SF")" = "$before" ] || { echo "the state file changed"; return 1; }
}

metrics() { bash "$PROG" metrics "$F" > /dev/null; }

# --- the commands -------------------------------------------------------------

@test "dispatch starts the five lenses, and not the fixes or the recheck" {
  ok dispatch
  said dispatched
  local p
  for p in contract security tests bugs simplify; do
    [ "$(part "$p")" = '{"status":"started","started":1000}' ] || { echo "$p: $(part "$p")"; false; }
  done
  [ "$(part fixes)" = null ]
  [ "$(part recheck)" = null ]
}

@test "start starts one part" {
  ok start fixes
  said 'fixes: started'
  [ "$(part fixes)" = '{"status":"started","started":1000}' ]
  [ "$(part contract)" = null ]
}

@test "done records whole wall seconds from the part's start, as a number" {
  ok dispatch
  at 1812
  ok done contract
  said 'contract: 812 s'
  [ "$(part contract)" = '{"status":"done","started":1000,"seconds":812}' ]
  [ "$(jq -r '.measurements.i.parts.contract.seconds | type' "$SF")" = number ]
  [ "$(jq -r '.measurements.i.parts.security.status' "$SF")" = started ]
}

@test "done --seconds records the duration the return states, as a number" {
  ok dispatch
  at 1812
  ok done contract --seconds 77
  said 'contract: 77 s'
  [ "$(part contract)" = '{"status":"done","started":1000,"seconds":77}' ]
  [ "$(jq -r '.measurements.i.parts.contract.seconds | type' "$SF")" = number ]
  refused 'whole number' done tests --seconds 1x
  refused 'whole number' done tests --seconds ''
  refused 'whole number' done tests --seconds -1
  refused 'at most 10 digits' done tests --seconds 12345678901
  refused 'usage: i-measure' done tests --nope 1
}

@test "done --seconds may not pass the time since the start, as a duration in ms would" {
  ok dispatch
  at 1090
  refused '--seconds 77000 is more than the 90 s since tests started' done tests --seconds 77000
  [ "$(jq -r '.measurements.i.parts.tests.status' "$SF")" = started ]
  ok done tests --seconds 90
  said 'tests: 90 s'
  ok done contract --seconds 007
  said 'contract: 7 s'
  [ "$(jq -c '.measurements.i.parts.contract.seconds' "$SF")" = 7 ]
}

@test "done --seconds still needs a start" {
  refused 'no start is recorded for fixes' done fixes --seconds 5
}

@test "a done with no start is refused, and names the two ways on" {
  refused 'no start is recorded for contract' done contract
  [[ "$(cat "$ERR")" == *start* && "$(cat "$ERR")" == *unmeasured* ]]
}

@test "a second done is refused, and the seconds stand" {
  ok dispatch
  at 1800
  ok done tests
  at 1900
  refused 'tests is already recorded: 800 s' done tests
  refused 'tests is already recorded: 800 s' done tests --seconds 1
  [ "$(jq -r '.measurements.i.parts.tests.seconds' "$SF")" = 800 ]
}

@test "a done after a skip or unmeasured is refused" {
  ok skip bugs no-code-review-skill
  refused 'no start is recorded for bugs' done bugs
  ok unmeasured tests
  refused 'no start is recorded for tests' done tests
}

@test "a clock that moved back records no number" {
  ok start fixes
  at 999
  refused 'the clock moved back since fixes started' done fixes
  [ "$(part fixes)" = '{"status":"started","started":1000}' ]
}

@test "skip records the reason and no seconds, for what a rule may leave out" {
  local p
  for p in bugs simplify fixes recheck; do
    ok skip "$p" a-reason-1
    said "$p: skipped, a-reason-1"
    [ "$(part "$p")" = '{"status":"skipped","reason":"a-reason-1"}' ] || { echo "$p: $(part "$p")"; false; }
  done
}

@test "the three lenses no rule leaves out cannot be skipped" {
  local p
  for p in contract security tests; do
    refused "$p is never skipped" skip "$p" a-reason
  done
}

@test "a reason takes a to z, digits and dash, 1 to 40 bytes" {
  refused 'a reason' skip bugs 'has spaces'
  refused 'a reason' skip bugs ''
  refused 'a reason' skip bugs 'x;rm'
  refused 'a reason' skip bugs 'CAPITALS'
  refused 'a reason' skip bugs 'under_score'
  refused 'a reason' skip bugs "$(printf 'x%.0s' $(seq 1 41))"
  ok skip bugs "$(printf 'x%.0s' $(seq 1 40))"
  ok skip bugs 'a-1'
}

@test "unmeasured records missing, and no seconds" {
  ok unmeasured fixes
  said 'fixes: missing'
  [ "$(part fixes)" = '{"status":"missing"}' ]
}

@test "an unknown part is refused on every verb, and the refusal lists the parts" {
  local bad list='contract security tests bugs simplify fixes recheck'
  for bad in nope contract, 'contract security' CONTRACT '' findings; do
    refused "$list" start "$bad"
    refused "$list" done "$bad"
    refused "$list" skip "$bad" a-reason
    [ "$bad" = findings ] || refused "$list" unmeasured "$bad"
  done
}

@test "a refused part cannot reach the terminal raw" {
  refused 'is not a part' start "$(printf 'x\033[2Jy')"
  [ -z "$(od -An -c "$ERR" | grep -F -- 033)" ] || { echo "a raw ESC reached stderr"; false; }
}

@test "a wrong number of arguments or an unknown verb is refused" {
  refused 'usage: i-measure'
  refused 'usage: i-measure' nope
  refused 'usage: i-measure' dispatch extra
  refused 'usage: i-measure' start
  refused 'usage: i-measure' start contract extra
  refused 'usage: i-measure' done
  refused 'usage: i-measure' done contract extra
  refused 'usage: i-measure' skip contract
  refused 'usage: i-measure' skip contract a extra
  refused 'usage: i-measure' unmeasured
  refused 'usage: i-measure' unmeasured contract extra
  refused 'usage: i-measure' findings extra
}

@test "a second start keeps the old record under earlier, and says so" {
  ok start contract
  at 1500
  ok done contract
  at 2000
  ok start contract
  [ "$(sed -n 1p "$OUT")" = 'contract: the earlier record is kept' ]
  [ "$(sed -n 2p "$OUT")" = 'contract: started' ]
  [ "$(part contract)" = '{"status":"started","started":2000}' ]
  [ "$(jq -c '.measurements.i.earlier' "$SF")" = '[{"part":"contract","status":"done","started":1000,"seconds":500}]' ]
}

@test "a second dispatch keeps each result, and no number is lost or doubled" {
  ok dispatch
  at 1100
  ok done contract
  ok done tests
  at 2000
  ok dispatch
  [ "$(grep -c 'the earlier record is kept' "$OUT")" = 2 ]
  [ "$(tail -n 1 "$OUT")" = dispatched ]
  [ "$(jq '.measurements.i.earlier | length' "$SF")" = 2 ]
  [ "$(jq '[.measurements.i.earlier[] | .seconds] | add' "$SF")" = 200 ]
  [ "$(jq -r '.measurements.i.parts.contract.status' "$SF")" = started ]
}

@test "a part only started holds no result, so nothing is kept for it" {
  ok dispatch
  ok skip bugs no-code-review-skill
  said 'bugs: skipped, no-code-review-skill'
  ok unmeasured tests
  said 'tests: missing'
  [ "$(jq -c '.measurements.i.earlier' "$SF")" = null ]
}

@test "a skip or unmeasured over a result keeps the old record too" {
  ok start fixes
  at 1050
  ok done fixes
  ok skip fixes no-findings
  [ "$(sed -n 1p "$OUT")" = 'fixes: the earlier record is kept' ]
  [ "$(jq -c '.measurements.i.earlier[0].seconds' "$SF")" = 50 ]
  [ "$(part fixes)" = '{"status":"skipped","reason":"no-findings"}' ]
  ok unmeasured fixes
  [ "$(sed -n 1p "$OUT")" = 'fixes: the earlier record is kept' ]
  [ "$(jq -c '.measurements.i.earlier[1].reason' "$SF")" = '"no-findings"' ]
  [ "$(part fixes)" = '{"status":"missing"}' ]
}

@test "a missing record holds no result, so nothing is kept for it" {
  ok unmeasured fixes
  ok unmeasured fixes
  said 'fixes: missing'
  ok skip fixes no-findings
  said 'fixes: skipped, no-findings'
  [ "$(jq -c '.measurements.i.earlier' "$SF")" = null ]
}

@test "findings counts each lens with a line, by severity and by outcome" {
  cat > "$RD/findings-I.txt" <<'LINES'
# the round's findings

HIGH | contract | specs/a.md:3 | MISSING FR-001 | fixed
LOW | contract | a.sh:9 | a word | declined
HIGH | security | a.sh:1 | a path | fixed
MEDIUM | tests | b.bats:4 | no red, for a reason | deferred
CRITICAL | bugs | a.sh:2 | a crash | fixed
LINES
  ok findings
  said 'findings: 5 lines read, 0 unreadable'
  [ "$(jq -c '.measurements.i.findings.byLens.contract' "$SF")" = '{"CRITICAL":0,"HIGH":1,"MEDIUM":0,"LOW":1,"fixed":1,"deferred":0,"declined":1}' ]
  [ "$(jq -c '.measurements.i.findings.byLens.tests' "$SF")" = '{"CRITICAL":0,"HIGH":0,"MEDIUM":1,"LOW":0,"fixed":0,"deferred":1,"declined":0}' ]
  [ "$(jq -c '.measurements.i.findings.byLens.bugs' "$SF")" = '{"CRITICAL":1,"HIGH":0,"MEDIUM":0,"LOW":0,"fixed":1,"deferred":0,"declined":0}' ]
  # The state file holds no zeros for a lens with no line: never 0 for a measure not taken.
  [ "$(jq -c '.measurements.i.findings.byLens.simplify' "$SF")" = null ]
  [ "$(jq -r '.measurements.i.findings.status' "$SF")" = read ]
  [ "$(jq -c '.measurements.i.findings.unreadable' "$SF")" = '[]' ]
  [ "$(jq -c '.measurements.i.findings.lines' "$SF")" = 5 ]
}

@test "findings: a bar in the finding's own text does no harm" {
  printf '%s\n' 'HIGH | contract | a.sh:1 | a | b | c | deferred' > "$RD/findings-I.txt"
  ok findings
  said 'findings: 1 lines read, 0 unreadable'
  [ "$(jq -r '.measurements.i.findings.byLens.contract.deferred' "$SF")" = 1 ]
}

@test "findings: space at the end of a line, and an indented comment or blank line, are no fault" {
  printf '%s\n' 'HIGH | tests | a.sh:1 | one | fixed ' $'LOW | tests | a.sh:2 | two | fixed\t' '   # a note' '   ' > "$RD/findings-I.txt"
  ok findings
  said 'findings: 2 lines read, 0 unreadable'
}

@test "findings: each line it cannot read is named by its number in the file" {
  cat > "$RD/findings-I.txt" <<'LINES'
# a comment, and a blank line, count as lines of the file

HIGH | contract | a.sh:1 | four fields, no outcome
HIGH | contract | a.sh:1 | good | fixed
high | contract | a.sh:1 | small severity | fixed
HIGH | nope | a.sh:1 | unknown lens | fixed
HIGH | contract | a.sh:1 | unknown outcome | maybe
a line of prose
HIGH | recheck | a.sh:1 | recheck is no lens: its findings are bugs | fixed
HIGH | contract | fixed
HIGH|tests|a.sh:1|no spaces|fixed
LINES
  ok findings
  [ "$(sed -n 1p "$OUT")" = 'findings: 1 lines read, 8 unreadable' ]
  [ "$(sed -n 2p "$OUT")" = 'unreadable line: 3' ]
  [ "$(sed -n 9p "$OUT")" = 'unreadable line: 11' ]
  [ "$(jq -c '.measurements.i.findings.unreadable' "$SF")" = '[3,5,6,7,8,9,10,11]' ]
  [ "$(jq -r '.measurements.i.findings.byLens.contract.HIGH' "$SF")" = 1 ]
  # The report ends in a line feed, so the next output starts on its own line.
  [ "$(tail -c 1 "$OUT" | od -An -c | tr -d ' ')" = '\n' ] || { echo "no line feed at the end"; false; }
}

@test "findings: past 100 bad lines it counts them all and names the first 100" {
  seq 1 150 | sed 's/^/prose /' > "$RD/findings-I.txt"
  ok findings
  [ "$(sed -n 1p "$OUT")" = 'findings: 0 lines read, 150 unreadable' ]
  [ "$(jq -c '.measurements.i.findings.unreadable | length' "$SF")" = 100 ]
  [ "$(jq -c '.measurements.i.findings.unreadableLines' "$SF")" = 150 ]
}

@test "findings prints no finding's text and no machine path, and leaves no file" {
  printf '%s\n' 'SECRET-WORD line' 'HIGH | tests | a.sh:1 | SECRET-WORD | fixed' > "$RD/findings-I.txt"
  ok findings
  if grep -qF 'SECRET-WORD' "$OUT" "$ERR" "$SF"; then echo "a finding's text was printed or stored"; false; fi
  if grep -qF "$WORK" "$OUT" "$ERR"; then echo "a machine path was printed"; false; fi
  [ -z "$(find "$RD" -name 'findings-I.txt.*')" ] || { find "$RD"; false; }
}

@test "findings: an empty file is a read with nothing found" {
  : > "$RD/findings-I.txt"
  ok findings
  said 'findings: 0 lines read, 0 unreadable'
  [ "$(jq -r '.measurements.i.findings.status' "$SF")" = read ]
  [ "$(jq -c '.measurements.i.findings.byLens' "$SF")" = '{}' ]
}

@test "findings: an absent file, a folder or a link is refused, with no path" {
  refused 'findings-I.txt is not a readable file in the run directory' findings
  if grep -qF "$WORK" "$ERR"; then echo "a machine path was printed"; false; fi
  [ "$(jq -c '.measurements.i.findings' "$SF")" = null ]
  mkdir "$RD/findings-I.txt"
  refused 'findings-I.txt is not a readable file' findings
  rmdir "$RD/findings-I.txt"
  printf '%s\n' 'HIGH | tests | a.sh:1 | one | fixed' > "$BATS_TEST_TMPDIR/real"
  ln -s "$BATS_TEST_TMPDIR/real" "$RD/findings-I.txt" 2> /dev/null || true
  if [ -L "$RD/findings-I.txt" ]; then refused 'findings-I.txt is not a readable file' findings; fi
}

@test "findings: a file past the limit is refused" {
  head -c 262144 /dev/zero | tr '\0' '#' > "$RD/findings-I.txt"
  ok findings
  head -c 262145 /dev/zero | tr '\0' '#' > "$RD/findings-I.txt"
  refused 'findings-I.txt is over 262144 bytes' findings
}

@test "findings: an awk that fails records nothing" {
  : > "$RD/findings-I.txt"
  printf '#!/bin/sh\nexit 2\n' > "$STUBS/awk"
  chmod +x "$STUBS/awk"
  refused 'findings-I.txt could not be read' findings
  [ "$(jq -c '.measurements.i.findings' "$SF")" = null ]
}

@test "a second read of the findings keeps the old counts, and says so" {
  printf '%s\n' 'HIGH | tests | a.sh:1 | one | deferred' > "$RD/findings-I.txt"
  ok findings
  printf '%s\n' 'HIGH | tests | a.sh:1 | one | fixed' > "$RD/findings-I.txt"
  ok findings
  [ "$(sed -n 1p "$OUT")" = 'findings: the earlier record is kept' ]
  [ "$(jq -c '.measurements.i.findings.byLens.tests | [.HIGH,.fixed,.deferred]' "$SF")" = '[1,1,0]' ]
  [ "$(jq -c '.measurements.i.earlier[0] | [.part,.byLens.tests.deferred]' "$SF")" = '["findings",1]' ]
}

@test "findings reads a CR line ending as the same line" {
  printf 'HIGH | tests | a.sh:1 | one | fixed\r\n' > "$RD/findings-I.txt"
  ok findings
  said 'findings: 1 lines read, 0 unreadable'
}

@test "unmeasured findings records missing, and a read it replaces is kept" {
  ok unmeasured findings
  said 'findings: missing'
  [ "$(jq -c '.measurements.i.findings' "$SF")" = '{"status":"missing"}' ]
  : > "$RD/findings-I.txt"
  ok findings
  ok unmeasured findings
  [ "$(sed -n 1p "$OUT")" = 'findings: the earlier record is kept' ]
  [ "$(jq -c '.measurements.i.findings' "$SF")" = '{"status":"missing"}' ]
  [ "$(jq -r '.measurements.i.earlier | map(.part) | join(" ")' "$SF")" = 'findings' ]
}

@test "a second dispatch asks for the findings again, and keeps the first read" {
  printf '%s\n' 'HIGH | tests | a.sh:1 | one | fixed' > "$RD/findings-I.txt"
  ok findings
  ok dispatch
  grep -qxF 'findings: the earlier record is kept' "$OUT"
  [ "$(jq -c '.measurements.i.findings' "$SF")" = null ]
  [ "$(jq -c '.measurements.i.earlier[0].byLens.tests.HIGH' "$SF")" = 1 ]
}

@test "a second dispatch asks for the fixes and the recheck again, and keeps their numbers" {
  all_recorded
  at 3000
  ok dispatch
  [ "$(part fixes)" = null ]
  [ "$(part recheck)" = null ]
  [ "$(jq -r '[.measurements.i.earlier[] | .part] | join(" ")' "$SF")" = 'contract security tests bugs simplify fixes recheck findings' ]
  [ "$(jq -c '[.measurements.i.earlier[] | select(.part == "fixes") | .seconds]' "$SF")" = '[50]' ]
}

@test "dispatch refuses a link at the findings file, before anything is written to it" {
  printf 'x\n' > "$BATS_TEST_TMPDIR/real"
  ln -s "$BATS_TEST_TMPDIR/real" "$RD/findings-I.txt" 2> /dev/null || true
  if [ -L "$RD/findings-I.txt" ]; then
    refused 'findings-I.txt is a link' dispatch
    if grep -qF "$WORK" "$ERR"; then echo "a machine path was printed"; false; fi
  fi
}

# --- only i-measure writes it ---------------------------------------------------

@test "state-set refuses measurements.i, and a whole write that changes it" {
  ok start fixes
  local before
  before="$(cksum < "$SF")"
  run bash "$PROG" state-set "$F" measurements i '{"parts":{}}'
  [ "$status" -eq 1 ]
  [[ "$output" == *'measurements.i is written only by i-measure'* ]]
  run bash "$PROG" state-set "$F" measurements '{}'
  [ "$status" -eq 1 ]
  [[ "$output" == *'must keep measurements.i'* ]]
  run bash "$PROG" state-set "$F" measurements '{"i":{"parts":{}}}'
  [ "$status" -eq 1 ]
  [ "$(cksum < "$SF")" = "$before" ]
}

@test "state-set still writes the other measurements, keeping measurements.i" {
  ok start fixes
  bash "$PROG" state-set "$F" measurements other '{"a":1}'
  [ "$(jq -c '.measurements.other' "$SF")" = '{"a":1}' ]
  local whole
  whole="$(jq -c '.measurements + {more: 2}' "$SF")"
  bash "$PROG" state-set "$F" measurements "$whole"
  [ "$(jq -c '.measurements.more' "$SF")" = 2 ]
  [ "$(part fixes)" = '{"status":"started","started":1000}' ]
}

# --- the gate -----------------------------------------------------------------

@test "phase-done I refuses a part with no record, names it, and changes nothing" {
  bash "$PROG" phase-start "$F" I > /dev/null
  gate_refuses 'contract security tests bugs simplify fixes recheck'
  [[ "$(cat "$ERR")" == *findings* && "$(cat "$ERR")" == *i-measure* ]] || { echo "stderr: $(cat "$ERR")"; false; }
  [ "$(jq -c '.completed_phases | index("I")' "$SF")" = null ]
}

@test "phase-done I refuses each absent or started part alone" {
  all_recorded
  bash "$PROG" phase-start "$F" I > /dev/null
  local p sf_ok="$BATS_TEST_TMPDIR/sf-ok"
  cp "$SF" "$sf_ok"
  for p in contract security tests bugs simplify fixes recheck; do
    jq --arg p "$p" 'del(.measurements.i.parts[$p])' "$sf_ok" > "$SF"
    gate_refuses "record for: $p;"
    jq --arg p "$p" '.measurements.i.parts[$p].status = "started"' "$sf_ok" > "$SF"
    gate_refuses "record for: $p;"
  done
  jq 'del(.measurements.i.findings)' "$sf_ok" > "$SF"
  gate_refuses 'the findings are not read'
  cp "$sf_ok" "$SF"
  phase_done I
  [ "$PD" -eq 0 ] || { echo "whole: exit $PD: $(cat "$ERR")"; false; }
}

@test "phase-done I refuses a findings file with a line that does not read" {
  all_recorded
  bash "$PROG" phase-start "$F" I > /dev/null
  printf '%s\n' 'prose' 'HIGH | tests | a.sh:1 | one' > "$RD/findings-I.txt"
  ok findings
  gate_refuses '2 lines of findings-I.txt do not read'
  printf '%s\n' 'HIGH | tests | a.sh:1 | one | fixed' > "$RD/findings-I.txt"
  ok findings
  phase_done I
  [ "$PD" -eq 0 ] || { echo "exit $PD: $(cat "$ERR")"; false; }
}

@test "phase-done I passes with done, skipped and missing together, and findings missing" {
  ok start contract; ok done contract
  ok skip bugs no-code-review-skill
  ok skip simplify no-code-roots
  ok unmeasured security
  ok unmeasured tests
  ok skip fixes no-findings
  ok skip recheck no-fix-changed-a-file
  ok unmeasured findings
  bash "$PROG" phase-start "$F" I > /dev/null
  phase_done I
  [ "$PD" -eq 0 ] || { echo "exit $PD: $(cat "$ERR")"; false; }
  [ "$(jq -c '.completed_phases | index("I") != null' "$SF")" = true ]
}

@test "no other phase is held by the gate" {
  local p phases
  phases="$(sed -n "s/^PHASES=[\"']\\(.*\\)[\"']\$/\\1/p" "$PROG")"
  [ -n "$phases" ] || { echo "the script's list of phases was not found"; false; }
  [[ " $phases " == *' I '* ]] || { echo "the list has no I: $phases"; false; }
  for p in $phases; do
    [ "$p" != I ] || continue
    bash "$PROG" phase-start "$F" "$p" > /dev/null
    phase_done "$p"
    [ "$PD" -eq 0 ] || { echo "$p: exit $PD: $(cat "$ERR")"; false; }
  done
}

@test "a phase I an older pipeline completed, with no measure, is past the gate" {
  bash "$PROG" phase-start "$F" I > /dev/null
  jq '.completed_phases += ["I"]' "$SF" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  phase_done I
  [ "$PD" -eq 0 ] || { echo "exit $PD: $(cat "$ERR")"; false; }
}

@test "a phase I re-entered after it completed is gated again" {
  all_recorded
  bash "$PROG" phase-start "$F" I > /dev/null
  phase_done I
  [ "$PD" -eq 0 ] || { echo "the first: exit $PD: $(cat "$ERR")"; false; }
  bash "$PROG" phase-start "$F" I > /dev/null
  ok dispatch
  gate_refuses 'record for: contract security tests bugs simplify fixes recheck;'
}

# --- pipeline-run.json --------------------------------------------------------

@test "a run with no measure reads as missing, and the file stays valid" {
  metrics
  [ "$(jq -c '.phaseI' "$MF")" = '{"status":"missing"}' ]
  jq '.measurements.i = 5' "$SF" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  metrics
  [ "$(jq -c '.phaseI' "$MF")" = '{"status":"missing"}' ]
}

@test "every part appears, and one with no record reads missing with null seconds, never 0" {
  ok start contract
  metrics
  [ "$(jq -c '.phaseI.status' "$MF")" = '"measured"' ]
  [ "$(jq -c '.phaseI.parts | keys_unsorted' "$MF")" = '["contract","security","tests","bugs","simplify","fixes","recheck"]' ]
  [ "$(jq -c '.phaseI.parts.fixes' "$MF")" = '{"status":"missing","seconds":null}' ]
  [ "$(jq -c '.phaseI.parts.contract' "$MF")" = '{"status":"started","seconds":null}' ]
  [ "$(jq -c '.phaseI.findings' "$MF")" = '{"status":"missing"}' ]
  [ "$(jq -c '.phaseI.accountedSeconds' "$MF")" = null ]
  [ "$(jq -c '.phaseI.earlier' "$MF")" = '[]' ]
}

@test "accountedSeconds is the longest lens, plus the fixes, plus the recheck" {
  ok dispatch
  at 1100; ok done contract
  at 1300; ok done security
  at 1200; ok done tests
  ok skip bugs no-code-review-skill
  ok skip simplify no-code-roots
  at 2000; ok start fixes; at 7000; ok done fixes
  at 8000; ok start recheck; at 8007; ok done recheck
  metrics
  [ "$(jq -c '.phaseI.parts.security' "$MF")" = '{"status":"done","seconds":300}' ]
  [ "$(jq -c '.phaseI.parts.bugs' "$MF")" = '{"status":"skipped","reason":"no-code-review-skill","seconds":null}' ]
  # The fixes are longer than any lens: the longest is taken over the lenses alone.
  [ "$(jq -c '.phaseI.accountedSeconds' "$MF")" = 5307 ]
  [ "$(jq -r '.phaseI.accountedSeconds | type' "$MF")" = number ]
}

@test "accountedSeconds is null when any part is missing, and a skipped part adds nothing" {
  all_recorded
  metrics
  [ "$(jq -c '.phaseI.accountedSeconds' "$MF")" = $((100 + 50 + 20)) ]
  ok unmeasured fixes
  metrics
  [ "$(jq -c '.phaseI.accountedSeconds' "$MF")" = null ]
  ok skip fixes no-findings
  metrics
  [ "$(jq -c '.phaseI.accountedSeconds' "$MF")" = $((100 + 20)) ]
}

@test "the counts say the difference between ran and found nothing, and did not run" {
  ok dispatch
  at 1100; ok done contract
  ok done security; ok done tests
  ok skip bugs no-code-review-skill
  ok unmeasured simplify
  printf '%s\n' 'HIGH | security | a.sh:1 | one | fixed' > "$RD/findings-I.txt"
  ok findings
  metrics
  # Ran and found nothing: zeros.
  [ "$(jq -c '.phaseI.findings.byLens.contract' "$MF")" = '{"CRITICAL":0,"HIGH":0,"MEDIUM":0,"LOW":0,"fixed":0,"deferred":0,"declined":0}' ]
  [ "$(jq -c '.phaseI.findings.byLens.security.HIGH' "$MF")" = 1 ]
  # Did not run, or nobody knows: null, never zeros.
  [ "$(jq -c '.phaseI.findings.byLens.bugs' "$MF")" = null ]
  [ "$(jq -c '.phaseI.findings.byLens.simplify' "$MF")" = null ]
  [ "$(jq -c '.phaseI.findings.status' "$MF")" = '"read"' ]
}

@test "a lens still started has null counts, never zeros" {
  ok dispatch
  : > "$RD/findings-I.txt"
  ok findings
  metrics
  [ "$(jq -c '.phaseI.findings.byLens.tests' "$MF")" = null ]
}

@test "a lens with no clock keeps the findings it did report" {
  ok unmeasured tests
  printf '%s\n' 'LOW | tests | a.sh:1 | one | declined' > "$RD/findings-I.txt"
  ok findings
  metrics
  [ "$(jq -c '.phaseI.findings.byLens.tests.LOW' "$MF")" = 1 ]
  [ "$(jq -c '.phaseI.parts.tests.seconds' "$MF")" = null ]
}

@test "unreadable lines and earlier records reach the metrics file" {
  ok start fixes; at 1010; ok done fixes; ok start fixes
  printf '%s\n' 'prose' > "$RD/findings-I.txt"
  ok findings
  metrics
  [ "$(jq -c '.phaseI.findings.unreadable' "$MF")" = '[1]' ]
  [ "$(jq -c '.phaseI.findings.unreadableLines' "$MF")" = 1 ]
  [ "$(jq -c '.phaseI.earlier[0].seconds' "$MF")" = 10 ]
}

@test "a second metrics run writes the same bytes, and added keys stay" {
  all_recorded
  metrics
  jq '. + {handAdded: 7}' "$MF" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$MF"
  metrics
  local one
  one="$(cksum < "$MF")"
  metrics
  [ "$(cksum < "$MF")" = "$one" ]
  [ "$(jq -c '.handAdded' "$MF")" = 7 ]
  [ "$(jq -c '.phaseI.accountedSeconds' "$MF")" = 170 ]
}

# --- the doc ------------------------------------------------------------------

@test "the doc's lists are the script's" {
  local want have doc
  doc="$(tr -d '\r' < "$ROOT/pipeline/docs/phases.md")"
  want="$(sed -n "s/^I_PARTS='\\(.*\\)'\$/\\1/p" "$PROG")"
  [ -n "$want" ] || { echo "the script's list was not found"; false; }
  have="$(printf '%s\n' "$doc" | sed -n 's/^The parts, in order: \(.*\)\.$/\1/p' | tr -d '`,')"
  [ "$have" = "$want" ] || { echo "doc: $have; script: $want"; false; }
  # Each part a rule may not skip is named as such, derived from the two lists.
  want="$(sed -n "s/^I_SKIPPABLE='\\(.*\\)'\$/\\1/p" "$PROG")"
  [ -n "$want" ] || { echo "the skippable list was not found"; false; }
  local p line
  line="$(printf '%s\n' "$doc" | sed -n '/^`contract`, `security` and `tests` are never skipped/p')"
  for p in $(sed -n "s/^I_PARTS='\\(.*\\)'\$/\\1/p" "$PROG"); do
    case " $want " in
      *" $p "*) [[ "$line" != *"\`$p\`"* ]] || { echo "$p is skippable, and the doc says never"; false; } ;;
      *) [[ "$line" == *"\`$p\`"* ]] || { echo "$p is never skipped, and the doc does not say so"; false; } ;;
    esac
  done
}
