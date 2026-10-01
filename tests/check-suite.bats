#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load helper

# scripts/check-suite.sh gives the one verdict a feature quickstart needs on a
# saved run of the house suite. Before it existed, each quickstart wrote its own
# copy of this check, and the copies drifted: only some counted skipped tests.
#
# Every failure below names the contract row it guards (K1-K11 in
# specs/023-gate-reads-whole-changelog/contracts/check-suite.md), so a red says
# which rule broke. The quickstart removes one rule at a time and requires this
# test to go red naming that rule, so every row here must stay reachable.

@test "check-suite.sh passes one clean run and refuses every broken shape for its own reason" {
  cs="$ROOT/scripts/check-suite.sh"
  [ -f "$cs" ] || { echo "K1: scripts/check-suite.sh does not exist"; false; }
  t="$TEST_DIR/run.tap"

  # refuse <id> <fragment> <args...>: the script must exit non-zero, say
  # <fragment>, and never print the fixture's path (a caller's temp path can
  # carry a user name, and this output can reach a public log).
  refuse() {
    id="$1"; frag="$2"; shift 2
    run bash "$cs" "$@"
    [ "$status" -ne 0 ] || { echo "$id: accepted; output: $output"; return 1; }
    case "$output" in
      *"$frag"*) ;;
      *) echo "$id: refused, but without '$frag'; output: $output"; return 1 ;;
    esac
    case "$output" in
      *"$TEST_DIR"*) echo "$id: the refusal prints the file's path; output: $output"; return 1 ;;
    esac
  }

  # K1: a clean run, with a comment and a blank line, passes and says so.
  printf '1..2\nok 1 a\n# a comment\n\nok 2 b\n' > "$t"
  run bash "$cs" 2 "$t"
  [ "$status" -eq 0 ] || { echo "K1: a clean run was refused; output: $output"; false; }
  case "$output" in
    *"suite ok: 1..2, 2 ok, 0 skipped, 0 not ok, 0 non-TAP"*) ;;
    *) echo "K1: a clean run passed without the summary line; output: $output"; false ;;
  esac

  # K1: a leading blank line is not a line; the plan is the first non-blank.
  printf '\n1..1\nok 1 a\n' > "$t"
  run bash "$cs" 1 "$t"
  [ "$status" -eq 0 ] || { echo "K1: a leading blank line made a clean run fail; output: $output"; false; }

  # K1: the NAMED file is judged, even one whose name awk would read as a
  # variable assignment, and never whatever arrives on stdin.
  mkdir -p "$TEST_DIR/named"
  printf '1..2\nok 1 a\nok 2 b\n' > "$TEST_DIR/named/e=2"
  run bash -c 'cd "$1" && printf "1..9\n" | bash "$2" 2 e=2' _ "$TEST_DIR/named" "$cs"
  [ "$status" -eq 0 ] || { echo "K1: a file named e=2 was not the file judged; output: $output"; false; }

  # K2: not exactly two arguments, or a count that is not a positive integer.
  refuse K2 usage
  refuse K2 usage 2
  refuse K2 usage abc "$t"
  refuse K2 usage 0 "$t"
  refuse K2 usage 2 "$t" extra
  refuse K2 usage 2x "$t"

  # K3: a file that does not exist.
  refuse K3 "does not exist" 2 "$TEST_DIR/no-such.tap"

  # K3: when awk fails, the run is refused — never a silent pass — and
  # nothing awk prints to stderr reaches the output. A stand-in awk fails
  # instead of a real one on an unreadable file, because file permissions
  # cannot be taken away on every system the suite runs on. A real awk reads
  # the file on stdin and could not name it; the stand-in's path is kept as
  # a leak canary, so a change that lets awk's stderr through goes red here.
  # This is also the only test of the script's untagged last line: delete it
  # and the script exits 0 with no output, which the status check catches.
  mkdir -p "$TEST_DIR/fakebin"
  printf '#!/bin/sh\necho "awk: fatal: cannot open /secret/path/run.tap" >&2\nexit 2\n' > "$TEST_DIR/fakebin/awk"
  chmod +x "$TEST_DIR/fakebin/awk"
  printf '1..1\nok 1 a\n' > "$t"
  run env PATH="$TEST_DIR/fakebin:$PATH" bash "$cs" 1 "$t"
  [ "$status" -ne 0 ] || { echo "K3: an awk that could not read the file still gave a pass; output: $output"; false; }
  case "$output" in
    *"cannot be read"*) ;;
    *) echo "K3: an unreadable file was refused without saying so; output: $output"; false ;;
  esac
  case "$output" in
    *"/secret/path"*) echo "K3: awk's own error, with its path, reached the output; output: $output"; false ;;
  esac

  # K4: an empty file, and one holding only blank lines.
  : > "$t"
  refuse K4 empty 2 "$t"
  printf '\n\n' > "$t"
  refuse K4 empty 2 "$t"

  # K5: the first line is not the plan line for the expected count.
  printf '1..3\nok 1 a\nok 2 b\n' > "$t"
  refuse K5 "plan line" 2 "$t"

  # K6: a second plan line, as a crashed or concatenated run leaves.
  printf '1..2\nok 1 a\nok 2 b\n1..2\n' > "$t"
  refuse K6 "plan line" 2 "$t"

  # K7: one ok short of the plan.
  printf '1..2\nok 1 a\n' > "$t"
  refuse K7 "ok count" 2 "$t"
  # ... and one ok too many.
  printf '1..1\nok 1 a\nok 2 b\n' > "$t"
  refuse K7 "ok count" 1 "$t"

  # K8: a skipped test counts as ok to bats, and must not count here.
  printf '1..2\nok 1 a\nok 2 b # skip not today\n' > "$t"
  refuse K8 skipped 2 "$t"
  printf '1..2\nok 1 a\nok 2 b # SKIP not today\n' > "$t"
  refuse K8 skipped 2 "$t"

  # K9: a failure is named as a failure, not as the short count it causes.
  printf '1..2\nok 1 a\nnot ok 2 b\n' > "$t"
  refuse K9 "not ok" 2 "$t"
  # A failure is named before a skip in the same run.
  printf '1..3\nok 1 a\nnot ok 2 b\nok 3 c # skip not today\n' > "$t"
  refuse K9 "not ok" 3 "$t"

  # K10: a line that is neither TAP nor a comment.
  printf '1..2\nok 1 a\nok 2 b\nstray text\n' > "$t"
  refuse K10 non-TAP 2 "$t"
  # Lines that only look like TAP: each is stray, not an ok, a plan or a
  # failure.
  printf '1..2\nok 1 a\nokay 2 b\n' > "$t"
  refuse K10 non-TAP 2 "$t"
  printf '1..2\nok 1 a\nok 2 b\n1..2 trailing\n' > "$t"
  refuse K10 non-TAP 2 "$t"
  printf '1..2\nok 1 a\nok 2 b\nnot okay\n' > "$t"
  refuse K10 non-TAP 2 "$t"

  # K11: CRLF line ends give the same verdicts as LF.
  printf '1..2\r\nok 1 a\r\nok 2 b\r\n' > "$t"
  run bash "$cs" 2 "$t"
  [ "$status" -eq 0 ] || { echo "K11: a clean CRLF run was refused; output: $output"; false; }
  printf '1..2\r\nok 1 a\r\nok 2 b # skip not today\r\n' > "$t"
  refuse K11 skipped 2 "$t"
}
