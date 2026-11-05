#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for progress.sh i-measure, the gate in phase-done I, and the phaseI key of
# pipeline-run.json. The prose asked for these numbers for many runs and no run
# recorded them, so a gate holds them now. A measure not taken must read as
# missing, and never as 0.

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
  printf '1000\n' > "$CLOCK"
  bash "$PROG" init "$F" "$F" main other > /dev/null
}

at() { printf '%s\n' "$1" > "$CLOCK"; }

# im <args...> — i-measure, stdout to $OUT, stderr to $ERR, status in $IM.
im() {
  IM=0
  PATH="$STUBS:$PATH" bash "$PROG" i-measure "$F" "$@" > "$OUT" 2> "$ERR" || IM=$?
}

ok() { im "$@"; [ "$IM" -eq 0 ] || { echo "exit $IM: $(cat "$ERR")"; return 1; }; }

# refused <part of the message> <args...> — status 1, the message, the state file's bytes unchanged.
refused() {
  local want="$1" before
  shift
  before="$(cksum < "$SF")"
  im "$@"
  [ "$IM" -eq 1 ] || { echo "exit $IM, expected 1"; return 1; }
  [[ "$(cat "$ERR")" == *"$want"* ]] || { echo "stderr: $(cat "$ERR")"; return 1; }
  [ ! -s "$OUT" ] || { echo "stdout: $(cat "$OUT")"; return 1; }
  [ "$(cksum < "$SF")" = "$before" ] || { echo "the state file changed"; return 1; }
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
  PATH="$STUBS:$PATH" bash "$PROG" phase-done "$F" "$1" > "$OUT" 2> "$ERR" || PD=$?
}

metrics() { PATH="$STUBS:$PATH" bash "$PROG" metrics "$F" > /dev/null; }

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
  [ "$(jq -r '.measurements.i.parts.tests.seconds' "$SF")" = 800 ]
}

@test "a done after a skip is refused" {
  ok skip bugs no-code-review-skill
  refused 'no start is recorded for bugs' done bugs
}

@test "skip records the reason and no seconds" {
  ok skip bugs no-code-review-skill
  said 'bugs: skipped, no-code-review-skill'
  [ "$(part bugs)" = '{"status":"skipped","reason":"no-code-review-skill"}' ]
}

@test "a bad reason is refused" {
  refused 'a reason' skip bugs 'Has Spaces'
  refused 'a reason' skip bugs ''
  refused 'a reason' skip bugs 'x;rm'
  refused 'a reason' skip bugs "$(printf 'x%.0s' $(seq 1 41))"
}

@test "unmeasured records missing, and no seconds" {
  ok unmeasured fixes
  said 'fixes: missing'
  [ "$(part fixes)" = '{"status":"missing"}' ]
}

@test "an unknown part is refused, and the refusal lists the parts" {
  for bad in nope contract, 'contract security' CONTRACT ''; do
    refused 'contract security tests bugs simplify fixes recheck' start "$bad"
    refused 'contract security tests bugs simplify fixes recheck' done "$bad"
  done
}

@test "a wrong number of arguments or an unknown verb is refused" {
  refused 'usage: i-measure'
  refused 'usage: i-measure' nope
  refused 'usage: i-measure' dispatch extra
  refused 'usage: i-measure' start
  refused 'usage: i-measure' start contract extra
  refused 'usage: i-measure' skip contract
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

@test "a second dispatch keeps each old record, and no number is lost or doubled" {
  ok dispatch
  at 1100
  ok done contract
  ok done tests
  at 2000
  ok dispatch
  [ "$(grep -c 'the earlier record is kept' "$OUT")" = 5 ]
  [ "$(tail -n 1 "$OUT")" = dispatched ]
  [ "$(jq '.measurements.i.earlier | length' "$SF")" = 5 ]
  [ "$(jq '[.measurements.i.earlier[] | select(.status == "done") | .seconds] | add' "$SF")" = 200 ]
  [ "$(jq -r '.measurements.i.parts.contract.status' "$SF")" = started ]
}

@test "a skip or unmeasured over a record keeps the old record too" {
  ok start fixes
  at 1050
  ok done fixes
  ok unmeasured fixes
  [ "$(jq -c '.measurements.i.earlier[0].seconds' "$SF")" = 50 ]
  [ "$(part fixes)" = '{"status":"missing"}' ]
}

@test "findings counts each lens by severity and by outcome" {
  cat > "$RD/findings-I.txt" <<'LINES'
# the round's findings

HIGH | contract | specs/a.md:3 | MISSING FR-001 | fixed
LOW | contract | a.sh:9 | a word | declined
HIGH | security | a.sh:1 | a path | fixed
MEDIUM | tests | b.bats:4 | no red | deferred
CRITICAL | bugs | a.sh:2 | a crash | fixed
LINES
  ok findings
  said 'findings: 5 lines read, 0 unreadable'
  [ "$(jq -c '.measurements.i.findings.byLens.contract' "$SF")" = '{"CRITICAL":0,"HIGH":1,"MEDIUM":0,"LOW":1,"fixed":1,"deferred":0,"declined":1}' ]
  [ "$(jq -c '.measurements.i.findings.byLens.bugs' "$SF")" = '{"CRITICAL":1,"HIGH":0,"MEDIUM":0,"LOW":0,"fixed":1,"deferred":0,"declined":0}' ]
  [ "$(jq -c '.measurements.i.findings.byLens.simplify' "$SF")" = '{"CRITICAL":0,"HIGH":0,"MEDIUM":0,"LOW":0,"fixed":0,"deferred":0,"declined":0}' ]
  [ "$(jq -r '.measurements.i.findings.status' "$SF")" = read ]
  [ "$(jq -c '.measurements.i.findings.unreadable' "$SF")" = '[]' ]
}

@test "findings: a bar in the finding's own text does no harm" {
  printf '%s\n' 'HIGH | contract | a.sh:1 | a | b | c | deferred' > "$RD/findings-I.txt"
  ok findings
  said 'findings: 1 lines read, 0 unreadable'
  [ "$(jq -r '.measurements.i.findings.byLens.contract.deferred' "$SF")" = 1 ]
}

@test "findings: each line it cannot read is named by number, and counted as nothing else" {
  cat > "$RD/findings-I.txt" <<'LINES'
HIGH | contract | a.sh:1 | four fields, no outcome
HIGH | contract | a.sh:1 | good | fixed
high | contract | a.sh:1 | small severity | fixed
HIGH | nope | a.sh:1 | unknown lens | fixed
HIGH | contract | a.sh:1 | unknown outcome | maybe
a line of prose
HIGH | recheck | a.sh:1 | recheck is no lens: its findings are bugs | fixed
LINES
  ok findings
  [ "$(sed -n 1p "$OUT")" = 'findings: 1 lines read, 6 unreadable' ]
  [ "$(sed -n 2p "$OUT")" = 'unreadable line: 1' ]
  [ "$(sed -n 7p "$OUT")" = 'unreadable line: 7' ]
  [ "$(jq -c '.measurements.i.findings.unreadable' "$SF")" = '[1,3,4,5,6,7]' ]
  [ "$(jq -r '.measurements.i.findings.byLens.contract.HIGH' "$SF")" = 1 ]
}

@test "findings prints no finding's text and no machine path" {
  printf '%s\n' 'SECRET-WORD line' 'HIGH | tests | a.sh:1 | SECRET-WORD | fixed' > "$RD/findings-I.txt"
  ok findings
  if grep -qF 'SECRET-WORD' "$OUT" "$ERR" "$SF"; then echo "a finding's text was printed or stored"; false; fi
  if grep -qF "$WORK" "$OUT" "$ERR"; then echo "a machine path was printed"; false; fi
}

@test "findings: an empty file is a real zero" {
  : > "$RD/findings-I.txt"
  ok findings
  said 'findings: 0 lines read, 0 unreadable'
  [ "$(jq -r '.measurements.i.findings.status' "$SF")" = read ]
  [ "$(jq -r '.measurements.i.findings.byLens.tests.HIGH' "$SF")" = 0 ]
}

@test "findings: an absent file is refused, with no path" {
  refused 'findings-I.txt is not in the run directory' findings
  if grep -qF "$WORK" "$ERR"; then echo "a machine path was printed"; false; fi
  [ "$(jq -c '.measurements.i.findings' "$SF")" = null ]
}

@test "findings can run again, and the last read stands" {
  printf '%s\n' 'HIGH | tests | a.sh:1 | one | deferred' > "$RD/findings-I.txt"
  ok findings
  printf '%s\n' 'HIGH | tests | a.sh:1 | one | fixed' > "$RD/findings-I.txt"
  ok findings
  [ "$(jq -c '.measurements.i.findings.byLens.tests | [.HIGH,.fixed,.deferred]' "$SF")" = '[1,1,0]' ]
}

@test "findings reads a CR line ending as the same line" {
  printf 'HIGH | tests | a.sh:1 | one | fixed\r\n' > "$RD/findings-I.txt"
  ok findings
  said 'findings: 1 lines read, 0 unreadable'
}

# --- the gate -----------------------------------------------------------------

@test "phase-done I refuses a part with no record, names it, and changes nothing" {
  bash "$PROG" phase-start "$F" I > /dev/null
  local before
  before="$(cksum < "$SF")"
  phase_done I
  [ "$PD" -eq 1 ] || { echo "exit $PD"; false; }
  [[ "$(cat "$ERR")" == *'contract security tests bugs simplify fixes recheck'* ]] || { echo "stderr: $(cat "$ERR")"; false; }
  [[ "$(cat "$ERR")" == *findings* && "$(cat "$ERR")" == *i-measure* ]] || { echo "stderr: $(cat "$ERR")"; false; }
  [ "$(cksum < "$SF")" = "$before" ]
  [ "$(jq -c '.completed_phases | index("I")' "$SF")" = null ]
}

@test "phase-done I refuses each absent or started part alone" {
  all_recorded
  bash "$PROG" phase-start "$F" I > /dev/null
  local p sf_ok="$BATS_TEST_TMPDIR/sf-ok"
  cp "$SF" "$sf_ok"
  for p in contract security tests bugs simplify fixes recheck; do
    cp "$sf_ok" "$SF"
    jq --arg p "$p" 'del(.measurements.i.parts[$p])' "$sf_ok" > "$SF"
    phase_done I
    [ "$PD" -eq 1 ] || { echo "$p absent: exit $PD"; false; }
    [[ "$(cat "$ERR")" == *"record for: $p;"* || "$(cat "$ERR")" == *"record for: $p "* ]] || { echo "$p: $(cat "$ERR")"; false; }
    jq --arg p "$p" '.measurements.i.parts[$p].status = "started"' "$sf_ok" > "$SF"
    phase_done I
    [ "$PD" -eq 1 ] || { echo "$p started: exit $PD"; false; }
  done
  jq 'del(.measurements.i.findings)' "$sf_ok" > "$SF"
  phase_done I
  [ "$PD" -eq 1 ] || { echo "findings absent: exit $PD"; false; }
  [[ "$(cat "$ERR")" == *findings* ]]
  cp "$sf_ok" "$SF"
  phase_done I
  [ "$PD" -eq 0 ] || { echo "whole: exit $PD: $(cat "$ERR")"; false; }
}

@test "phase-done I passes with done, skipped and missing together" {
  ok start contract; ok done contract
  ok skip bugs no-code-review-skill
  ok skip simplify no-code-roots
  ok unmeasured security
  ok unmeasured tests
  ok skip fixes no-findings
  ok skip recheck no-fix-changed-a-file
  : > "$RD/findings-I.txt"; ok findings
  bash "$PROG" phase-start "$F" I > /dev/null
  phase_done I
  [ "$PD" -eq 0 ] || { echo "exit $PD: $(cat "$ERR")"; false; }
  [ "$(jq -c '.completed_phases | index("I") != null' "$SF")" = true ]
}

@test "no other phase is held by the gate" {
  local p
  for p in H H.5 H.7 J K L; do
    bash "$PROG" phase-start "$F" "$p" > /dev/null
    phase_done "$p"
    [ "$PD" -eq 0 ] || { echo "$p: exit $PD: $(cat "$ERR")"; false; }
  done
}

@test "a phase I already completed is past the gate" {
  # The record of an older pipeline's run, resumed on this one.
  bash "$PROG" phase-start "$F" I > /dev/null
  jq '.completed_phases += ["I"]' "$SF" > "$BATS_TEST_TMPDIR/t.json"
  mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  phase_done I
  [ "$PD" -eq 0 ] || { echo "exit $PD: $(cat "$ERR")"; false; }
}

# --- pipeline-run.json --------------------------------------------------------

@test "a run with no measure reads as missing, and the file stays valid" {
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
}

@test "accountedSeconds is the longest lens, plus the fixes, plus the recheck" {
  ok dispatch
  at 1100; ok done contract
  at 1300; ok done security
  at 1200; ok done tests
  ok skip bugs no-code-review-skill
  ok skip simplify no-code-roots
  at 2000; ok start fixes; at 2050; ok done fixes
  at 3000; ok start recheck; at 3007; ok done recheck
  metrics
  [ "$(jq -c '.phaseI.parts.security' "$MF")" = '{"status":"done","seconds":300}' ]
  [ "$(jq -c '.phaseI.parts.bugs' "$MF")" = '{"status":"skipped","reason":"no-code-review-skill","seconds":null}' ]
  [ "$(jq -c '.phaseI.accountedSeconds' "$MF")" = 357 ]
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
  [ "$(jq -c '.phaseI.findings.byLens.contract.HIGH' "$MF")" = 0 ]
  [ "$(jq -c '.phaseI.findings.byLens.security.HIGH' "$MF")" = 1 ]
  # Did not run, or nobody knows: null, never zeros.
  [ "$(jq -c '.phaseI.findings.byLens.bugs' "$MF")" = null ]
  [ "$(jq -c '.phaseI.findings.byLens.simplify' "$MF")" = null ]
  [ "$(jq -c '.phaseI.findings.status' "$MF")" = '"read"' ]
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

@test "the doc's list of parts is the script's list" {
  local want have
  want="$(sed -n "s/^I_PARTS='\\(.*\\)'\$/\\1/p" "$PROG")"
  [ -n "$want" ] || { echo "the script's list was not found"; false; }
  have="$(tr -d '\r' < "$ROOT/pipeline/docs/phases.md" | sed -n 's/^The parts, in order: \(.*\)\.$/\1/p' | tr -d '`,')"
  [ "$have" = "$want" ] || { echo "doc: $have; script: $want"; false; }
}
