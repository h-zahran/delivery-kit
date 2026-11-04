#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load helper

# scripts/run-suite.sh runs each test file at the same time and prints one
# report. Serial bats shows a crashed file by itself; running files side by
# side must not hide one, so each failure below names the contract row it
# guards (R1-R13 in specs/057-repeated-serial-work/contracts/run-suite.md).
#
# The real suite is never run here. BATS_BIN points at a stand-in that runs a
# fixture .bats file as a bash script, so a fixture prints exactly the TAP the
# test needs, on all three systems, in a fraction of a second.

setup() {
  # As helper.bash's setup does, and its teardown removes TEST_DIR: each test
  # has its own TMPDIR and HOME, so the default runner path holds nothing, and
  # a temporary folder left behind is this script's.
  TEST_DIR="$(mktemp -d)"
  export TMPDIR="$TEST_DIR/tmp" HOME="$TEST_DIR/home"
  mkdir -p "$TMPDIR" "$HOME"
  RS_SCRIPT="$ROOT/scripts/run-suite.sh"
  W="$TEST_DIR/w"
  mkdir -p "$W/a" "$W/b" "$TEST_DIR/stub"
  cat > "$TEST_DIR/stand-in" <<'STUB'
#!/usr/bin/env bash
# The last argument is the file. Log the arguments, then run the file.
[ -z "${RS_LOG:-}" ] || printf '%s\n' "$*" >> "$RS_LOG"
for last in "$@"; do :; done
exec bash "$last"
STUB
  export BATS_BIN="$TEST_DIR/stand-in"
  STUBS="$TEST_DIR/stub"
  OUT="$TEST_DIR/out"
  ERR="$TEST_DIR/err"
  cd "$W"
}

# fixture <path> <line>... — a test file that prints those lines.
fixture() {
  local f="$1"
  shift
  { printf '%s\n' '#!/usr/bin/env bash'; printf '%s\n' "$@"; } > "$f"
}

# tap_fixture <path> <tap line>... — a fixture that prints TAP and exits 0.
tap_fixture() {
  local f="$1" l
  shift
  : > "$f"
  for l in "$@"; do printf "printf '%%s\\\\n' '%s'\n" "$l" >> "$f"; done
}

# stub <name> <body> — a stand-in tool, found first on PATH by PATH="$STUBS:$PATH".
# Executable: a stub without the bit is passed over in silence, and the real
# tool answers, so the test proves nothing.
stub() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "$STUBS/$1"
  chmod +x "$STUBS/$1"
}

suite() {
  rc=0
  bash "$RS_SCRIPT" "$@" > "$OUT" 2> "$ERR" < /dev/null || rc=$?
}

# refused <row> <status> <fragment> <args...>: the exact status, the fragment
# on stderr, and no absolute fixture path in any message.
refused() {
  local row="$1" want="$2" frag="$3"
  shift 3
  suite "$@"
  [ "$rc" -eq "$want" ] || { echo "$row: status $rc, wanted $want; stderr: $(cat "$ERR")"; return 1; }
  case "$(cat "$ERR")" in
    *"$frag"*) ;;
    *) echo "$row: stderr does not say '$frag': $(cat "$ERR")"; return 1 ;;
  esac
  case "$(cat "$ERR")" in
    *"$TEST_DIR"*) echo "$row: a message prints a machine path: $(cat "$ERR")"; return 1 ;;
  esac
}

@test "run-suite R1: one plan, renumbered, in sorted order however the files end" {
  # a/1 ends last and b/2 ends first: the report's order must not follow them.
  tap_fixture a/1.bats '1..2' 'ok 1 one' '# a comment holding ok 3' 'ok 2 two'
  printf 'sleep 1\n' | cat - a/1.bats > a/1.tmp && mv a/1.tmp a/1.bats
  tap_fixture 'a/2 spaced.bats' '1..1' 'ok 1 three'
  tap_fixture b/1.bats '1..2' 'ok 1 four # bats comment' 'ok 2 five'
  suite a b
  [ "$rc" -eq 0 ] || { echo "R1: status $rc; stderr: $(cat "$ERR")"; false; }
  [ ! -s "$ERR" ] || { echo "R1: a green run wrote to stderr: $(cat "$ERR")"; false; }
  want="$(printf '%s\n' '1..5' 'ok 1 one' '# a comment holding ok 3' 'ok 2 two' 'ok 3 three' 'ok 4 four # bats comment' 'ok 5 five')"
  [ "$(cat "$OUT")" = "$want" ] || { echo "R1: the report differs:"; cat "$OUT"; false; }
}

@test "run-suite: tap-check accepts a green report and refuses a not ok, a skip and a stray line" {
  local tc="$ROOT/pipeline/scripts/progress.sh"
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  tap_fixture b/1.bats '1..1' 'ok 1 two'
  suite a b
  [ "$rc" -eq 0 ] || { echo "status $rc"; false; }
  run bash "$tc" tap-check "$OUT"
  [ "$status" -eq 0 ] || { echo "a green report was refused: $output"; false; }
  [[ $output == *"suite ok: 1..2, 2 ok"* ]] || { echo "tap-check said: $output"; false; }

  # A failing test: status 1 from the file, a not ok in the report.
  tap_fixture b/1.bats '1..1' 'not ok 1 two' '# its output'
  printf 'exit 1\n' >> b/1.bats
  suite a b
  [ "$rc" -eq 1 ] || { echo "not ok: status $rc"; false; }
  grep -qxF 'not ok 2 two' "$OUT" || { echo "not ok: renumbered line missing:"; cat "$OUT"; false; }
  grep -qxF '# its output' "$OUT" || { echo "the failing output left the report:"; cat "$OUT"; false; }
  run bash "$tc" tap-check "$OUT"
  [ "$status" -ne 0 ] || { echo "a not ok passed tap-check"; false; }

  # A skip and a stray line: the script does not judge them, tap-check does.
  tap_fixture b/1.bats '1..1' 'ok 1 two # skip not today'
  suite a b
  [ "$rc" -eq 0 ] || { echo "skip: status $rc"; false; }
  run bash "$tc" tap-check "$OUT"
  [[ $status -ne 0 && $output == *'skipped'* ]] || { echo "a skip passed tap-check: $output"; false; }

  tap_fixture b/1.bats '1..1' 'stray noise' 'ok 1 two'
  suite a b
  grep -qxF 'stray noise' "$OUT" || { echo "the stray line was dropped:"; cat "$OUT"; false; }
  run bash "$tc" tap-check "$OUT"
  [[ $status -ne 0 && $output == *'non-TAP'* ]] || { echo "a stray line passed tap-check: $output"; false; }
}

@test "run-suite R2-R6: a broken file exits 1, names the file, and still prints the report" {
  tap_fixture b/1.bats '1..1' 'ok 1 good'

  # R2: every test ok, and the process still failed.
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  printf 'exit 7\n' >> a/1.bats
  refused R2 1 'a/1.bats: exit status 7' a b
  grep -qxF 'ok 2 good' "$OUT" || { echo "R2: the report is gone:"; cat "$OUT"; false; }

  # R3: no plan line, and an empty output.
  tap_fixture a/1.bats 'ok 1 one'
  refused R3 1 'a/1.bats: no plan line' a b
  : > a/1.bats
  refused R3-empty 1 'a/1.bats: no plan line' a b

  # R4: two plan lines.
  tap_fixture a/1.bats '1..1' 'ok 1 one' '1..1'
  refused R4 1 'a/1.bats: 2 plan lines' a b

  # R5: fewer and more test lines than the plan.
  tap_fixture a/1.bats '1..2' 'ok 1 one'
  refused R5-short 1 'a/1.bats: 1 test line(s), plan says 2' a b
  run bash "$ROOT/pipeline/scripts/progress.sh" tap-check "$OUT"
  [ "$status" -ne 0 ] || { echo "R5: a short file passed tap-check as well"; false; }
  tap_fixture a/1.bats '1..1' 'ok 1 one' 'ok 2 two'
  refused R5-long 1 'a/1.bats: 2 test line(s), plan says 1' a b

  # R6: a test line with no number.
  tap_fixture a/1.bats '1..1' 'ok one'
  refused R6 1 'a/1.bats: a test line has no number' a b
}

@test "run-suite R7: a worker that dies leaves no status, and that is a fault" {
  fixture a/1.bats 'kill -9 "$PPID"' 'sleep 1'
  suite a
  [ "$rc" -eq 1 ] || { echo "R7: status $rc; stderr: $(cat "$ERR")"; false; }
  grep -qF 'a/1.bats: left no exit status' "$ERR" || { echo "R7: stderr: $(cat "$ERR")"; false; }
}

@test "run-suite R8: a total of zero tests is a fault" {
  tap_fixture a/1.bats '1..0'
  refused R8 1 'no test ran' a
}

@test "run-suite R9: xargs failing is a fault, and names its status" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  stub xargs 'exit 3'
  PATH="$STUBS:$PATH" refused R9 1 'xargs exit status 3' a
}

@test "run-suite R10-R12: what stops a run before it starts exits 2" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'

  # R10: BATS_BIN names nothing, and the default path holds nothing either.
  BATS_BIN="$TEST_DIR/nothing" refused R10-set 2 'set BATS_BIN' a
  unset BATS_BIN
  refused R10-default 2 'set BATS_BIN' a
  export BATS_BIN="$TEST_DIR/stand-in"

  # R11: a root that does not exist, and a root with no test file.
  refused R11-missing 2 'c: not a folder' a c
  mkdir c
  refused R11-empty 2 'c: holds no .bats file' a c

  # R12: mktemp fails. A stub, because BSD mktemp ignores a missing TMPDIR.
  stub mktemp 'exit 1'
  PATH="$STUBS:$PATH" refused R12 2 'could not make a temporary folder' a
}

@test "run-suite: with no argument it reads the same roots as CI's matrix" {
  local line ci have q="'"
  line="$(grep -E '^ *suite: *\[' "$ROOT/.github/workflows/ci.yml")"
  ci="${line#*[}"; ci="${ci%]*}"; ci="$(printf '%s' "$ci" | tr -d ' ' | tr ',' '\n' | LC_ALL=C sort)"
  [ -n "$ci" ] || { echo "no suite matrix found in ci.yml"; false; }
  line="$(grep -E "^roots='" "$RS_SCRIPT")"
  have="${line#*$q}"; have="${have%$q*}"; have="$(printf '%s' "$have" | tr ' ' '\n' | LC_ALL=C sort)"
  [ "$have" = "$ci" ] || { printf 'the script holds:\n%s\nCI holds:\n%s\n' "$have" "$ci"; false; }
  # The line the test reads is the line the script uses.
  mkdir -p "$TEST_DIR/r/tests" "$TEST_DIR/r/handoff/tests" "$TEST_DIR/r/pipeline/tests" "$TEST_DIR/r/team/tests"
  cd "$TEST_DIR/r"
  tap_fixture tests/1.bats '1..1' 'ok 1 one'
  tap_fixture handoff/tests/1.bats '1..1' 'ok 1 two'
  tap_fixture pipeline/tests/1.bats '1..1' 'ok 1 three'
  tap_fixture team/tests/1.bats '1..1' 'ok 1 four'
  suite
  [ "$rc" -eq 0 ] || { echo "no-argument run: status $rc: $(cat "$ERR")"; false; }
  [ "$(head -n 1 "$OUT")" = '1..4' ] || { echo "no-argument run:"; cat "$OUT"; false; }
}

@test "run-suite: each file gets its own process, with --print-output-on-failure, through BATS_BIN" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  tap_fixture a/sub.bats '1..1' 'ok 1 two'
  mkdir a/deep
  tap_fixture a/deep/x.bats '1..1' 'ok 1 three'
  printf 'not a test file\n' > a/deep/notes.txt
  export RS_LOG="$TEST_DIR/log"
  suite a
  [ "$rc" -eq 0 ] || { echo "status $rc: $(cat "$ERR")"; false; }
  [ "$(LC_ALL=C sort "$RS_LOG")" = "$(printf '%s\n' '--print-output-on-failure a/1.bats' '--print-output-on-failure a/deep/x.bats' '--print-output-on-failure a/sub.bats')" ] \
    || { echo "the runner was called as:"; cat "$RS_LOG"; false; }
}

# holding_fixture <path> <count> — it holds until <count> stand-ins run at once,
# then records how many it saw. A run that cannot reach <count> times out and
# records fewer. Once <count> was reached, a later file does not wait for it.
holding_fixture() {
  local f="$1" count="$2"
  fixture "$f" \
    'd="$RS_LIVE"; mkdir "$d/$$"' \
    "n=0; while [ \"\$n\" -lt 150 ]; do [ -e \"\$d.reached\" ] && break; if [ \"\$(ls \"\$d\" | wc -l)\" -ge $count ]; then : > \"\$d.reached\"; break; fi; sleep 0.1; n=\$((n + 1)); done" \
    'ls "$d" | wc -l >> "$RS_SEEN"' \
    'sleep 1' \
    'rmdir "$d/$$"' \
    "printf '1..1\\nok 1 one\\n'"
}

@test "run-suite: on one CPU, two files still run at once" {
  export RS_LIVE="$TEST_DIR/live" RS_SEEN="$TEST_DIR/seen"
  mkdir "$RS_LIVE"
  stub getconf 'printf "1\n"'
  holding_fixture a/1.bats 2
  holding_fixture a/2.bats 2
  PATH="$STUBS:$PATH" suite a
  [ "$rc" -eq 0 ] || { echo "status $rc: $(cat "$ERR")"; false; }
  [ "$(LC_ALL=C sort -n "$RS_SEEN" | tail -n 1 | tr -d ' ')" -eq 2 ] || { echo "seen at once:"; cat "$RS_SEEN"; false; }
}

@test "run-suite: on many CPUs, exactly eight files run at once" {
  export RS_LIVE="$TEST_DIR/live" RS_SEEN="$TEST_DIR/seen"
  mkdir "$RS_LIVE"
  stub getconf 'printf "32\n"'
  local i
  for i in 1 2 3 4 5 6 7 8 9; do holding_fixture "a/$i.bats" 8; done
  PATH="$STUBS:$PATH" suite a
  [ "$rc" -eq 0 ] || { echo "status $rc: $(cat "$ERR")"; false; }
  [ "$(LC_ALL=C sort -n "$RS_SEEN" | tail -n 1 | tr -d ' ')" -eq 8 ] || { echo "seen at once:"; cat "$RS_SEEN"; false; }
}

@test "run-suite R13: a stop ends the test processes and removes the temporary folder" {
  local p pid_file="$TEST_DIR/pids" i rc_stop=0
  export RS_PIDS="$pid_file"
  fixture a/1.bats 'sleep 300 & p=$!; printf "%s %s\n" "$$" "$p" >> "$RS_PIDS"; wait "$p"'
  fixture a/2.bats 'sleep 300 & p=$!; printf "%s %s\n" "$$" "$p" >> "$RS_PIDS"; wait "$p"'
  bash "$RS_SCRIPT" a > "$OUT" 2> "$ERR" < /dev/null &
  local script=$!
  i=0
  while :; do
    if [ -f "$pid_file" ] && [ "$(wc -l < "$pid_file")" -ge 2 ]; then break; fi
    i=$((i + 1))
    [ "$i" -lt 100 ] || { kill "$script"; echo "the stand-ins never started"; false; }
    sleep 0.1
  done
  kill -TERM "$script"
  wait "$script" || rc_stop=$?
  [ "$rc_stop" -eq 143 ] || { echo "R13: status $rc_stop; stderr: $(cat "$ERR")"; false; }
  grep -qF 'stopped' "$ERR" || { echo "R13: stderr: $(cat "$ERR")"; false; }
  i=0
  for p in $(cat "$pid_file"); do
    while kill -0 "$p" 2>/dev/null; do
      i=$((i + 1))
      [ "$i" -lt 50 ] || { kill -9 "$p"; echo "R13: process $p outlived the stop"; false; }
      sleep 0.1
    done
  done
  [ -z "$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -name 'dk-run-suite.*')" ] \
    || { echo "R13: the temporary folder is still there"; false; }
}

@test "run-suite: every exit removes the temporary folder" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  suite a
  [ "$rc" -eq 0 ] || { echo "status $rc"; false; }
  [ -z "$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -name 'dk-run-suite.*')" ] || { echo "left behind after a green run"; false; }
  tap_fixture a/1.bats '1..2' 'ok 1 one'
  suite a
  [ "$rc" -eq 1 ] || { echo "status $rc"; false; }
  [ -z "$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -name 'dk-run-suite.*')" ] || { echo "left behind after a red run"; false; }
}

@test "run-suite: the script never changes a file under the current folder" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  find . -type f | LC_ALL=C sort > "$TEST_DIR/before"
  suite a
  find . -type f | LC_ALL=C sort > "$TEST_DIR/after"
  cmp "$TEST_DIR/before" "$TEST_DIR/after" || { echo "files changed:"; diff "$TEST_DIR/before" "$TEST_DIR/after"; false; }
}
