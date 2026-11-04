#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load helper

# scripts/run-suite.sh runs each test file at the same time and prints one
# report. Serial bats shows a crashed file by itself; running files side by
# side must not hide one, so each failure below names the contract row it
# guards (specs/057-repeated-serial-work/contracts/run-suite.md).
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
  TC="$PIPELINE/scripts/progress.sh"
  W="$TEST_DIR/w"
  STUBS="$TEST_DIR/stub"
  mkdir -p "$W/a" "$W/b" "$STUBS"
  cat > "$TEST_DIR/stand-in" <<'STUB'
#!/usr/bin/env bash
# The last argument is the file. Log the arguments, then run the file.
[ -z "${RS_LOG:-}" ] || printf '%s\n' "$*" >> "$RS_LOG"
[ -z "${RS_TMP_LOG:-}" ] || printf '%s\n' "$TMPDIR" >> "$RS_TMP_LOG"
for last in "$@"; do :; done
exec bash "$last"
STUB
  export BATS_BIN="$TEST_DIR/stand-in"
  OUT="$TEST_DIR/out"
  ERR="$TEST_DIR/err"
  cd "$W"
}

# fixture <path> <line>... — a test file made of those bash lines.
fixture() {
  local f="$1"
  shift
  printf '%s\n' "$@" > "$f"
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

# Every call also checks that this exit left the temporary folder removed. The
# test owns TMPDIR, so anything there is the script's. That the folder exists at
# all, under TMPDIR, is shown by the TMPDIR test below.
suite() {
  rc=0
  bash "$RS_SCRIPT" "$@" > "$OUT" 2> "$ERR" < /dev/null || rc=$?
  [ -z "$(find "$TMPDIR" -mindepth 1 -maxdepth 1)" ] || { echo "the temporary folder was left behind, status $rc"; return 1; }
}

# refused <row> <status> <fragment> <args...>: the exact status, the fragment
# on stderr, and no absolute fixture path in any message. Status 1 is a judged
# run, so its report must be there, plan first.
refused() {
  local row="$1" want="$2" frag="$3"
  shift 3
  suite "$@" || return 1
  [ "$rc" -eq "$want" ] || { echo "$row: status $rc, wanted $want; stderr: $(cat "$ERR")"; return 1; }
  case "$(cat "$ERR")" in
    *"$frag"*) ;;
    *) echo "$row: stderr does not say '$frag': $(cat "$ERR")"; return 1 ;;
  esac
  case "$(cat "$ERR")" in
    *"$TEST_DIR"*) echo "$row: a message prints a machine path: $(cat "$ERR")"; return 1 ;;
  esac
  if [ "$want" -eq 1 ]; then
    [[ "$(head -n 1 "$OUT")" == 1..* ]] || { echo "$row: the report is gone:"; cat "$OUT"; return 1; }
  fi
}

# broken <row> <fragment>: refused with status 1, with b/1.bats's line still there.
broken() {
  refused "$1" 1 "$2" a b || return 1
  grep -qE '^ok [0-9]+ good$' "$OUT" || { echo "$1: the report lost another file's line:"; cat "$OUT"; return 1; }
}

@test "run-suite: one plan, renumbered, roots as given and each sorted, however the files end" {
  # a/1 ends last and b/1 ends first: the report's order must not follow them.
  fixture a/1.bats 'sleep 0.2' "printf '%s\\n' '1..2' 'ok 1 one' '# a comment holding ok 3' 'ok 2 two'"
  tap_fixture 'a/2 spaced.bats' '1..1' 'ok 1 three'
  tap_fixture b/1.bats '1..3' 'ok 1 four # bats comment' 'ok 2 five' 'ok 3'
  suite b a
  [ "$rc" -eq 0 ] || { echo "status $rc; stderr: $(cat "$ERR")"; false; }
  [ ! -s "$ERR" ] || { echo "a green run wrote to stderr: $(cat "$ERR")"; false; }
  want="$(printf '%s\n' '1..6' 'ok 1 four # bats comment' 'ok 2 five' 'ok 3' 'ok 4 one' '# a comment holding ok 3' 'ok 5 two' 'ok 6 three')"
  [ "$(cat "$OUT")" = "$want" ] || { echo "the report differs:"; cat "$OUT"; false; }
}

@test "run-suite: tap-check accepts a green report and refuses a not ok, a skip and a stray line" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  tap_fixture b/1.bats '1..1' 'ok 1 two'
  suite a b
  [ "$rc" -eq 0 ] || { echo "status $rc"; false; }
  run bash "$TC" tap-check "$OUT"
  [ "$status" -eq 0 ] || { echo "a green report was refused: $output"; false; }
  [[ $output == *"suite ok: 1..2, 2 ok"* ]] || { echo "tap-check said: $output"; false; }

  # A failing test: status 1 from the file, a not ok in the report.
  tap_fixture b/1.bats '1..1' 'not ok 1 two' '# its output'
  printf 'exit 1\n' >> b/1.bats
  suite a b
  [ "$rc" -eq 1 ] || { echo "not ok: status $rc"; false; }
  grep -qxF 'not ok 2 two' "$OUT" || { echo "not ok: renumbered line missing:"; cat "$OUT"; false; }
  grep -qxF '# its output' "$OUT" || { echo "the failing output left the report:"; cat "$OUT"; false; }
  run bash "$TC" tap-check "$OUT"
  [[ $status -ne 0 && $output == *'1 not ok'* ]] || { echo "tap-check said: $output"; false; }

  # The pipeline keeps stdout and stderr in one file. The plan must stay first,
  # or a plain failure reads as a crashed run.
  bash "$RS_SCRIPT" a b > "$OUT" 2>&1 < /dev/null || rc=$?
  [ "$(head -n 1 "$OUT")" = '1..2' ] || { echo "the merged report starts:"; head -n 2 "$OUT"; false; }
  run bash "$TC" tap-check "$OUT"
  [[ $status -ne 0 && $output == *'1 not ok'* ]] || { echo "merged: tap-check said: $output"; false; }

  # A skip and a stray line: the script does not judge them, tap-check does.
  tap_fixture b/1.bats '1..1' 'ok 1 two # skip not today'
  suite a b
  [ "$rc" -eq 0 ] || { echo "skip: status $rc"; false; }
  run bash "$TC" tap-check "$OUT"
  [[ $status -ne 0 && $output == *'skipped'* ]] || { echo "a skip passed tap-check: $output"; false; }

  tap_fixture b/1.bats '1..1' 'stray noise' 'ok 1 two'
  suite a b
  [ "$rc" -eq 0 ] || { echo "stray: status $rc"; false; }
  grep -qxF 'stray noise' "$OUT" || { echo "the stray line was dropped:"; cat "$OUT"; false; }
  run bash "$TC" tap-check "$OUT"
  [[ $status -ne 0 && $output == *'non-TAP'* ]] || { echo "a stray line passed tap-check: $output"; false; }

  # A file's stderr is part of its output, as in the serial command.
  fixture b/1.bats "printf 'boom-on-stderr\n' >&2" "printf '1..1\nok 1 two\n'"
  suite a b
  grep -qxF 'boom-on-stderr' "$OUT" || { echo "the file's stderr left the report:"; cat "$OUT"; false; }
}

@test "run-suite: a broken file exits 1, names the file, and keeps every other file's report" {
  tap_fixture b/1.bats '1..1' 'ok 1 good'

  # Every test ok, and the process still failed.
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  printf 'exit 7\n' >> a/1.bats
  broken exit-status 'a/1.bats: exit status 7'

  # No plan line, and an empty output.
  tap_fixture a/1.bats 'ok 1 one'
  broken no-plan 'a/1.bats: no plan line'
  : > a/1.bats
  broken empty 'a/1.bats: no plan line'

  # Two plan lines: only the first is dropped, so tap-check sees the second too.
  tap_fixture a/1.bats '1..1' 'ok 1 one' '1..1'
  broken two-plans 'a/1.bats: 2 plan lines'
  run bash "$TC" tap-check "$OUT"
  [[ $status -ne 0 && $output == *'second plan line'* ]] || { echo "two plans: tap-check said: $output"; false; }

  # Fewer and more test lines than the plan.
  tap_fixture a/1.bats '1..2' 'ok 1 one'
  broken short 'a/1.bats: 1 test line(s), plan says 2'
  run bash "$TC" tap-check "$OUT"
  [ "$status" -ne 0 ] || { echo "a short file passed tap-check as well"; false; }
  tap_fixture a/1.bats '1..1' 'ok 1 one' 'ok 2 two'
  broken long 'a/1.bats: 2 test line(s), plan says 1'
  tap_fixture a/1.bats '1..1' 'not ok 1 one' 'not ok 2 two'
  broken long-not-ok 'a/1.bats: 2 test line(s), plan says 1'

  # A test line with no number, on either kind of line.
  tap_fixture a/1.bats '1..1' 'ok one'
  broken no-number 'a/1.bats: a test line has no number'
  tap_fixture a/1.bats '1..1' 'not ok one'
  broken no-number-not-ok 'a/1.bats: a test line has no number'

  # A repeated number and one outside the plan: renumbering would hide both.
  tap_fixture a/1.bats '1..2' 'ok 1 one' 'ok 1 one'
  broken repeated 'a/1.bats: a test number repeated or outside its plan'
  tap_fixture a/1.bats '1..1' 'ok 9 one'
  broken outside 'a/1.bats: a test number repeated or outside its plan'

  # A plan after a test line: dropping it would hide that from tap-check.
  tap_fixture a/1.bats 'ok 1 one' '1..1'
  broken late 'a/1.bats: the plan line is not first'

  # A file with no plan is only that: no second, misleading message.
  tap_fixture a/1.bats 'ok 1 one'
  broken no-plan-alone 'a/1.bats: no plan line'
  case "$(cat "$ERR")" in *'repeated or outside'*) echo "a false second fault: $(cat "$ERR")"; false ;; esac

  # A plan too large for the shell's arithmetic must not wrap.
  tap_fixture a/1.bats '1..9223372036854775807' 'ok 1 one'
  broken huge 'a/1.bats: the plan line is too large'
}

@test "run-suite: two broken files are both named, and the plan still adds up" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  printf 'exit 3\n' >> a/1.bats
  tap_fixture b/1.bats '1..1' 'ok 1 two'
  printf 'exit 4\n' >> b/1.bats
  refused both 1 'a/1.bats: exit status 3' a b
  grep -qF 'b/1.bats: exit status 4' "$ERR" || { echo "b/1.bats is not named: $(cat "$ERR")"; false; }
  [ "$(head -n 1 "$OUT")" = '1..2' ] || { echo "the plan is: $(head -n 1 "$OUT")"; false; }
}

@test "run-suite: a file that left no status is a fault of its own" {
  # xargs runs the first file only, and says it went well. Only the status file
  # can show the second one: nothing else here is wrong.
  local real
  real="$(command -v xargs)"
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  tap_fixture a/2.bats '1..1' 'not ok 1 two'
  stub xargs "head -n 1 | '$real' \"\$@\"; exit 0"
  PATH="$STUBS:$PATH" refused no-status 1 'a/2.bats: left no exit status' a
  [ "$(head -n 1 "$OUT")" = '1..1' ] || { echo "the plan is: $(head -n 1 "$OUT")"; false; }
}

@test "run-suite: a carriage return is stripped, as tap-check strips it" {
  fixture a/1.bats "printf '1..1\r\nok 1 one\r\n'"
  suite a
  [ "$rc" -eq 0 ] || { echo "status $rc: $(cat "$ERR")"; false; }
  [ "$(cat "$OUT")" = "$(printf '%s\n' '1..1' 'ok 1 one')" ] || { echo "the report:"; od -c "$OUT" | head; false; }
}

@test "run-suite: a read-only folder a test leaves does not turn a green run red" {
  fixture a/1.bats 'mkdir -p "$TMPDIR/ro/x"; chmod 555 "$TMPDIR/ro"' "printf '1..1\nok 1 one\n'"
  suite a
  [ "$rc" -eq 0 ] || { echo "status $rc: $(cat "$ERR")"; false; }
  [ ! -s "$ERR" ] || { echo "stderr: $(cat "$ERR")"; false; }
}

@test "run-suite: a total of zero tests is a fault" {
  tap_fixture a/1.bats '1..0'
  refused zero 1 'no test ran' a
}

@test "run-suite: xargs failing is a fault, names its status, and stops what it left running" {
  local real p n=0
  real="$(command -v xargs)"
  # Every file ran and passed: only xargs' own status can make this red.
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  stub xargs "'$real' \"\$@\"; exit 3"
  PATH="$STUBS:$PATH" refused status 1 'xargs exit status 3' a
  case "$(cat "$ERR")" in
    *'no test ran'* | *'no exit status'*) echo "another fault gave the status: $(cat "$ERR")"; false ;;
  esac

  # bash adds its own line when xargs dies by a signal: the plan must stay first.
  stub xargs 'kill -9 $$'
  rc=0
  PATH="$STUBS:$PATH" bash "$RS_SCRIPT" a > "$OUT" 2>&1 < /dev/null || rc=$?
  [ "$rc" -eq 1 ] || { echo "killed xargs: status $rc"; false; }
  [[ "$(head -n 1 "$OUT")" == 1..* ]] || { echo "killed xargs: the merged report starts:"; head -n 2 "$OUT"; false; }
  grep -qF 'xargs exit status 137' "$OUT" || { echo "killed xargs:"; cat "$OUT"; false; }

  # An xargs that leaves at once must not leave its workers running, even one that
  # ignores TERM.
  export RS_PIDS="$TEST_DIR/pids"
  fixture a/1.bats 'trap "" TERM; sleep 60 & p=$!; printf "%s\n" "$p" >> "$RS_PIDS"; wait "$p"'
  stub xargs "'$real' \"\$@\" <&0 & n=0; while [ ! -s \"\$RS_PIDS\" ] && [ \"\$n\" -lt 100 ]; do sleep 0.1; n=\$((n + 1)); done; exit 3"
  PATH="$STUBS:$PATH" suite a
  [ "$rc" -eq 1 ] || { echo "status $rc: $(cat "$ERR")"; false; }
  p="$(cat "$RS_PIDS")"
  while kill -0 "$p" 2> /dev/null; do
    n=$((n + 1))
    [ "$n" -lt 50 ] || { kill -9 "$p"; echo "a worker outlived the failed xargs"; false; }
    sleep 0.1
  done
}

@test "run-suite: what stops a run before it starts exits 2" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'

  # BATS_BIN names nothing, is empty, and the default path holds nothing either.
  BATS_BIN="$TEST_DIR/nothing" refused runner-set 2 'set BATS_BIN' a
  BATS_BIN='' refused runner-empty 2 'set BATS_BIN' a
  unset BATS_BIN
  refused runner-default 2 'set BATS_BIN' a
  # HOME unset: set -u must not answer before the contract does.
  rc=0
  env -u HOME bash "$RS_SCRIPT" a > "$OUT" 2> "$ERR" < /dev/null || rc=$?
  [ "$rc" -eq 2 ] || { echo "HOME unset: status $rc: $(cat "$ERR")"; false; }
  grep -qF 'set BATS_BIN' "$ERR" || { echo "HOME unset: $(cat "$ERR")"; false; }
  export BATS_BIN="$TEST_DIR/stand-in"

  # A root that does not exist, that is a file, that holds no test file, or that
  # would reach find as an action.
  refused root-missing 2 'c: not a folder' a c
  refused root-file 2 'a/1.bats: not a folder' a/1.bats
  mkdir c
  refused root-empty 2 'c: holds no .bats file' a c
  mkdir ./-delete
  refused root-dash 2 'a root must not read as a find expression' -delete
  [ -f a/1.bats ] || { echo "the -delete root deleted a file"; false; }
  mkdir './!'
  refused root-bang 2 'a root must not read as a find expression' '!'
  # The worker's own spelling, without its arguments, is only a bad root.
  refused root-worker 2 'a root must not read as a find expression' --run-one

  # find failing: fewer files must not read as green.
  stub find 'exit 1'
  PATH="$STUBS:$PATH" refused find-fails 2 'a: could not be read' a

  # mktemp failing. A stub, because BSD mktemp ignores a missing TMPDIR.
  stub mktemp 'exit 1'
  PATH="$STUBS:$PATH" refused temp 2 'could not make a temporary folder' a
}

@test "run-suite: the default runner path is the serial command's, and BATS_BIN overrides it" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  mkdir -p "$HOME/bats/bin"
  cp "$TEST_DIR/stand-in" "$HOME/bats/bin/bats"
  unset BATS_BIN
  suite a
  [ "$rc" -eq 0 ] || { echo "default path: status $rc: $(cat "$ERR")"; false; }
  # An empty BATS_BIN is as good as none.
  BATS_BIN='' suite a
  [ "$rc" -eq 0 ] || { echo "empty BATS_BIN: status $rc: $(cat "$ERR")"; false; }
  rm "$HOME/bats/bin/bats"
  export BATS_BIN="$TEST_DIR/stand-in"
  suite a
  [ "$rc" -eq 0 ] || { echo "BATS_BIN: status $rc: $(cat "$ERR")"; false; }
}

@test "run-suite: with no argument it reads the same roots as CI's matrix" {
  local ci have r n=0
  ci="$(sed -n 's/^ *suite: *\[\(.*\)\] *$/\1/p' "$ROOT/.github/workflows/ci.yml" | tr -d ' ' | tr ',' '\n' | LC_ALL=C sort)"
  [ -n "$ci" ] || { echo "no suite matrix found in ci.yml"; false; }
  have="$(sed -n "s/^roots='\(.*\)'\$/\1/p" "$RS_SCRIPT" | tr ' ' '\n' | LC_ALL=C sort)"
  [ "$have" = "$ci" ] || { printf 'the script holds:\n%s\nCI holds:\n%s\n' "$have" "$ci"; false; }
  # The line the test reads is the line the script uses.
  mkdir "$TEST_DIR/r"
  cd "$TEST_DIR/r"
  for r in $have; do
    mkdir -p "$r"
    n=$((n + 1))
    tap_fixture "$r/1.bats" '1..1' "ok 1 $r"
  done
  suite
  [ "$rc" -eq 0 ] || { echo "no-argument run: status $rc: $(cat "$ERR")"; false; }
  [ "$(head -n 1 "$OUT")" = "1..$n" ] || { echo "no-argument run:"; cat "$OUT"; false; }
}

@test "run-suite: each file gets its own process and TMPDIR, with --print-output-on-failure" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  tap_fixture a/sub.bats '1..1' 'ok 1 two'
  mkdir a/deep a/folder.bats
  tap_fixture a/deep/x.bats '1..1' 'ok 1 three'
  printf 'not a test file\n' > a/deep/notes.txt
  # As bats -r does, a link to a folder is followed. Git Bash copies, which reads the same.
  tap_fixture b/1.bats '1..1' 'ok 1 four'
  ln -s ../b a/link
  export RS_LOG="$TEST_DIR/log" RS_TMP_LOG="$TEST_DIR/tmplog"
  suite a
  [ "$rc" -eq 0 ] || { echo "status $rc: $(cat "$ERR")"; false; }
  [ "$(LC_ALL=C sort "$RS_LOG")" = "$(printf '%s\n' '--print-output-on-failure a/1.bats' '--print-output-on-failure a/deep/x.bats' '--print-output-on-failure a/link/1.bats' '--print-output-on-failure a/sub.bats')" ] \
    || { echo "the runner was called as:"; cat "$RS_LOG"; false; }
  # Four TMPDIRs, all different, all inside the folder the script made under TMPDIR.
  [ "$(LC_ALL=C sort -u "$RS_TMP_LOG" | wc -l | tr -d ' ')" -eq 4 ] || { echo "TMPDIRs:"; cat "$RS_TMP_LOG"; false; }
  [ "$(grep -cF "$TMPDIR/dk-run-suite." "$RS_TMP_LOG")" -eq 4 ] || { echo "TMPDIRs:"; cat "$RS_TMP_LOG"; false; }
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
    'sleep 0.2' \
    'rmdir "$d/$$"' \
    "printf '1..1\\nok 1 one\\n'"
}

# at_once <files> <want>: with the stubs in place, exactly <want> files run at
# once, out of <files>.
at_once() {
  local files="$1" want="$2" i=0 most
  export RS_LIVE="$TEST_DIR/live" RS_SEEN="$TEST_DIR/seen"
  rm -rf "$RS_LIVE" "$RS_LIVE.reached" "$RS_SEEN" a/*.bats
  mkdir "$RS_LIVE"
  while [ "$i" -lt "$files" ]; do
    i=$((i + 1))
    holding_fixture "a/$i.bats" "$want"
  done
  PATH="$STUBS:$PATH" suite a || return 1
  [ "$rc" -eq 0 ] || { echo "status $rc: $(cat "$ERR")"; return 1; }
  most="$(LC_ALL=C sort -n "$RS_SEEN" | tail -n 1 | tr -d ' ')"
  [ "$most" -eq "$want" ] || { echo "wanted $want at once, saw $most"; return 1; }
}

@test "run-suite: half the CPUs run at once, at least 2 and at most 8" {
  stub nproc 'printf "1\n"'
  at_once 3 2
  stub nproc 'printf "6\n"'
  at_once 4 3
  stub nproc 'printf "32\n"'
  at_once 9 8
}

@test "run-suite: nproc goes first, then getconf, then a last resort" {
  # nproc wins over getconf: it respects CPU affinity.
  stub nproc 'printf "6\n"'
  stub getconf 'printf "16\n"'
  at_once 4 3
  # nproc fails or answers nonsense: getconf's answer serves.
  stub nproc 'exit 1'
  stub getconf 'printf "8\n"'
  at_once 5 4
  stub nproc 'printf "many\n"'
  at_once 5 4
  # Neither serves: two at once, and no message.
  stub nproc 'exit 1'
  stub getconf 'printf "undefined\n"'
  at_once 3 2
  [ ! -s "$ERR" ] || { echo "stderr: $(cat "$ERR")"; false; }
}

# stop_run <signal> <holders>: start the script on a/, wait for that many holding
# fixtures, signal it, and require status 143 with no process left. The script runs
# with fd 3 closed, or a stand-in that outlived the stop would hold bats open. Its
# job control is on, because a background job without it ignores INT on entry.
stop_run() {
  local signal="$1" holders="$2" p script i=0 rc_stop=0
  export RS_PIDS="$TEST_DIR/pids"
  rm -f "$RS_PIDS"
  set -m
  bash "$RS_SCRIPT" a > "$OUT" 2> "$ERR" < /dev/null 3>&- &
  script=$!
  set +m
  while :; do
    if [ -f "$RS_PIDS" ] && [ "$(wc -l < "$RS_PIDS")" -ge "$holders" ]; then break; fi
    i=$((i + 1))
    [ "$i" -lt 100 ] || { kill "$script"; echo "the stand-ins never started"; return 1; }
    sleep 0.1
  done
  SECONDS=0
  kill "-$signal" "$script"
  wait "$script" || rc_stop=$?
  # base_stop sends KILL at 10 s: the report must be out by then.
  [ "$SECONDS" -lt 8 ] || { echo "$signal: the stop took $SECONDS s"; return 1; }
  i=0
  for p in $(cat "$RS_PIDS"); do
    while kill -0 "$p" 2> /dev/null; do
      i=$((i + 1))
      if [ "$i" -ge 50 ]; then
        # shellcheck disable=SC2046 # one pid per word
        kill -9 $(cat "$RS_PIDS") 2> /dev/null
        echo "$signal: process $p outlived the stop"
        return 1
      fi
      sleep 0.1
    done
  done
  [ "$rc_stop" -eq 143 ] || { echo "$signal: status $rc_stop; stderr: $(cat "$ERR")"; return 1; }
  grep -qF 'stopped' "$ERR" || { echo "$signal: stderr: $(cat "$ERR")"; return 1; }
  case "$(cat "$ERR")" in
    *"$TEST_DIR"*) echo "$signal: a message prints a machine path: $(cat "$ERR")"; return 1 ;;
  esac
  [ -z "$(find "$TMPDIR" -mindepth 1 -maxdepth 1)" ] || { echo "$signal: the temporary folder is still there"; return 1; }
}

@test "run-suite: TERM, INT and HUP end the test processes and remove the temporary folder" {
  fixture a/1.bats 'sleep 60 & p=$!; printf "%s %s\n" "$$" "$p" >> "$RS_PIDS"; wait "$p"'
  fixture a/2.bats 'sleep 60 & p=$!; printf "%s %s\n" "$$" "$p" >> "$RS_PIDS"; wait "$p"'
  stop_run TERM 2
  stop_run INT 2
  stop_run HUP 2
}

@test "run-suite: a stop keeps what ran, and KILLs what ignores TERM" {
  # A finished file with a failure, and a file that ignores TERM. The stop still
  # ends in time for base_stop, and shows the failure a serial run had streamed.
  tap_fixture a/0.bats '1..1' 'not ok 1 quick'
  fixture a/1.bats 'trap "" TERM; sleep 60 & p=$!; printf "%s %s\n" "$$" "$p" >> "$RS_PIDS"; wait "$p"'
  stop_run TERM 1
  grep -qxF 'not ok 1 quick' "$OUT" || { echo "the finished file left the report:"; cat "$OUT"; false; }
}

@test "run-suite: a stop during the report does not print it twice" {
  local real script i=0 rc_stop=0
  real="$(command -v awk)"
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  # The report's own awk holds, so the signal lands while it runs.
  stub awk "case \"\$*\" in *dropped*) : > \"$TEST_DIR/in-report\"; sleep 1 ;; esac; exec '$real' \"\$@\""
  PATH="$STUBS:$PATH" bash "$RS_SCRIPT" a > "$OUT" 2> "$ERR" < /dev/null 3>&- &
  script=$!
  while [ ! -e "$TEST_DIR/in-report" ]; do
    i=$((i + 1))
    [ "$i" -lt 100 ] || { kill "$script"; echo "the report never started"; false; }
    sleep 0.1
  done
  kill -TERM "$script"
  wait "$script" || rc_stop=$?
  [ "$rc_stop" -eq 143 ] || { echo "status $rc_stop: $(cat "$ERR")"; false; }
  [ "$(grep -c '^1[.][.]' "$OUT")" -eq 1 ] || { echo "the report:"; cat "$OUT"; false; }
}

@test "run-suite: a report that cannot be written is a fault" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  rc=0
  bash "$RS_SCRIPT" a >&- 2> "$ERR" < /dev/null || rc=$?
  [ "$rc" -eq 1 ] || { echo "status $rc: $(cat "$ERR")"; false; }
  grep -qF 'the report could not be written' "$ERR" || { echo "stderr: $(cat "$ERR")"; false; }
}

@test "run-suite: a removed temporary folder is a fault, and its path stays out of the messages" {
  fixture a/1.bats 'rm -rf "${TMPDIR%/*}"' 'exit 0'
  refused removed 1 'left no exit status' a
}

@test "run-suite: the script never changes a file under the current folder" {
  tap_fixture a/1.bats '1..1' 'ok 1 one'
  tap_fixture a/2.bats '1..1' 'not ok 1 two'
  find . -type f -exec cksum {} + | LC_ALL=C sort > "$TEST_DIR/before"
  suite a
  find . -type f -exec cksum {} + | LC_ALL=C sort > "$TEST_DIR/after"
  cmp "$TEST_DIR/before" "$TEST_DIR/after" || { echo "files changed:"; diff "$TEST_DIR/before" "$TEST_DIR/after"; false; }
}

@test "run-suite: this repository's testCommand calls it, and the serial command stays documented" {
  local f
  grep -qF '"testCommand": "bash scripts/run-suite.sh"' "$ROOT/.delivery-kit.json" \
    || { echo "testCommand is not the script"; false; }
  for f in CONTRIBUTING.md README.md; do
    grep -qF 'bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests' "$ROOT/$f" \
      || { echo "$f lost the serial command"; false; }
  done
  grep -qF 'bash scripts/run-suite.sh' "$ROOT/CONTRIBUTING.md" \
    || { echo "CONTRIBUTING.md does not name the faster command"; false; }
}
