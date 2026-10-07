#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for progress.sh's waiting questions: ask-later, pending, answer and
# pending-check keep gates.pending. A question whose answer changes nothing
# before the run's next stop waits there and is asked at the next stop, at
# the latest before L pushes. Every test builds its own throwaway state
# under $BATS_TEST_TMPDIR.
#
# PROGRESS_SH_UNDER_TEST points the suite at another copy of the script, for
# mutation runs: mutate a copy, point the suite at it, watch a test go red.

load ../../tests/helper

setup() {
  PROG="${PROGRESS_SH_UNDER_TEST:-$ROOT/pipeline/scripts/progress.sh}"
  [ -f "$PROG" ] || { echo "no script at $PROG"; return 1; }
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
  cd "$WORK"
  F=001-demo
  SF=".delivery-kit/runs/$F/progress.json"
  OUT="$BATS_TEST_TMPDIR/out.txt"
  ERR="$BATS_TEST_TMPDIR/err.txt"
  bash "$PROG" init "$F" "$F" main other > /dev/null
}

# runs <args...> — the script, stdout to $OUT, stderr to $ERR; exit 0.
runs() {
  local rc=0
  bash "$PROG" "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 0 ] || { echo "exit $rc, expected 0: $(cat "$ERR")"; return 1; }
}

# refuses <fragment> <args...> — exit 1, the fragment on stderr, nothing on
# stdout, and the state file byte-identical to before.
refuses() {
  local frag="$1" rc=0 before; shift
  before="$(cat "$SF")"
  bash "$PROG" "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq 1 ] || { echo "exit $rc, expected 1 naming: $frag"; cat "$ERR"; return 1; }
  [[ "$(cat "$ERR")" == *"$frag"* ]] || { echo "stderr lacks '$frag': $(cat "$ERR")"; return 1; }
  [ ! -s "$OUT" ] || { echo "a refusal printed on stdout: $(cat "$OUT")"; return 1; }
  [ "$(cat "$SF")" = "$before" ] || { echo "a refusal changed the state file"; return 1; }
}

# q <name> <text> — a question or answer file under $BATS_TEST_TMPDIR.
q() { printf '%s\n' "$2" > "$BATS_TEST_TMPDIR/$1"; }

pending_json() { jq -c '.gates.pending' "$SF" | tr -d '\r'; }

@test "ask-later queues a question and prints its id, in order" {
  q a 'Record noexec as a known limit?'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  [ "$(cat "$OUT")" = P1 ]
  q b 'Say the slow test in the PR body?'
  runs ask-later "$F" I "$BATS_TEST_TMPDIR/b"
  [ "$(cat "$OUT")" = P2 ]
  [ "$(jq -c '[.gates.pending[] | [.id, .phase, .question]]' "$SF" | tr -d '\r')" \
    = '[["P1","F","Record noexec as a known limit?"],["P2","I","Say the slow test in the PR body?"]]' ]
  [[ "$(jq -r '.gates.pending[0].askedAt' "$SF" | tr -d '\r')" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$ ]] || false
  [ "$(jq -r '.gates.pending[0] | has("answer")' "$SF" | tr -d '\r')" = false ]
}

@test "the same question from the same phase is queued once; from another phase it is new" {
  q a 'Record noexec as a known limit?'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  [ "$(cat "$OUT")" = P1 ]
  [[ "$(cat "$ERR")" == *"already queued as P1"* ]] || false
  [ "$(jq '.gates.pending | length' "$SF" | tr -d '\r')" = 1 ]
  runs ask-later "$F" I "$BATS_TEST_TMPDIR/a"
  [ "$(cat "$OUT")" = P2 ]
}

@test "ask-later refuses a bad phase, a bad file and bad text, and changes nothing" {
  q a 'A question?'
  refuses "usage: ask-later" ask-later "$F" F
  refuses "unknown phase 'Z'" ask-later "$F" Z "$BATS_TEST_TMPDIR/a"
  refuses "unknown phase 'DONE'" ask-later "$F" DONE "$BATS_TEST_TMPDIR/a"
  refuses "does not exist or cannot be read" ask-later "$F" F "$BATS_TEST_TMPDIR/none"
  printf ' \n\t\n' > "$BATS_TEST_TMPDIR/blank"
  refuses "is empty" ask-later "$F" F "$BATS_TEST_TMPDIR/blank"
  printf 'A question?\r\n' > "$BATS_TEST_TMPDIR/cr"
  refuses "control character" ask-later "$F" F "$BATS_TEST_TMPDIR/cr"
  printf 'A \033[31mred\033[0m question?\n' > "$BATS_TEST_TMPDIR/esc"
  refuses "control character" ask-later "$F" F "$BATS_TEST_TMPDIR/esc"
  printf 'A \001 question?\n' > "$BATS_TEST_TMPDIR/soh"
  refuses "control character" ask-later "$F" F "$BATS_TEST_TMPDIR/soh"
  printf 'A \177 question?\n' > "$BATS_TEST_TMPDIR/del"
  refuses "control character" ask-later "$F" F "$BATS_TEST_TMPDIR/del"
}

@test "a question is stored verbatim: quotes, a command substitution, a tab and UTF-8" {
  printf '%s\n' 'Keep "$(id)" and `id` as text? It'"'"'s fine.	café' > "$BATS_TEST_TMPDIR/meta"
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/meta"
  [ "$(jq -r '.gates.pending[0].question' "$SF" | tr -d '\r')" = "$(cat "$BATS_TEST_TMPDIR/meta")" ]
}
