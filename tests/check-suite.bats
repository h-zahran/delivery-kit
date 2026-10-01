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

  # K2: not exactly two arguments, or a count that is not a positive integer.
  refuse K2 usage
  refuse K2 usage 2
  refuse K2 usage abc "$t"
  refuse K2 usage 0 "$t"
  refuse K2 usage 2 "$t" extra

  # K3: a file that does not exist.
  refuse K3 "does not exist" 2 "$TEST_DIR/no-such.tap"

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

  # K8: a skipped test counts as ok to bats, and must not count here.
  printf '1..2\nok 1 a\nok 2 b # skip not today\n' > "$t"
  refuse K8 skipped 2 "$t"
  printf '1..2\nok 1 a\nok 2 b # SKIP not today\n' > "$t"
  refuse K8 skipped 2 "$t"

  # K9: a failure is named as a failure, not as the short count it causes.
  printf '1..2\nok 1 a\nnot ok 2 b\n' > "$t"
  refuse K9 "not ok" 2 "$t"

  # K10: a line that is neither TAP nor a comment.
  printf '1..2\nok 1 a\nok 2 b\nstray text\n' > "$t"
  refuse K10 non-TAP 2 "$t"

  # K11: CRLF line ends give the same verdicts as LF.
  printf '1..2\r\nok 1 a\r\nok 2 b\r\n' > "$t"
  run bash "$cs" 2 "$t"
  [ "$status" -eq 0 ] || { echo "K11: a clean CRLF run was refused; output: $output"; false; }
  printf '1..2\r\nok 1 a\r\nok 2 b # skip not today\r\n' > "$t"
  refuse K11 skipped 2 "$t"
}
