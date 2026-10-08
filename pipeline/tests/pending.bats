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

@test "pending prints every open question with its id and phase, and nothing when none is open" {
  runs pending "$F"
  [ ! -s "$OUT" ]
  q a 'First question?'; q b 'Second question?'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  runs ask-later "$F" I "$BATS_TEST_TMPDIR/b"
  runs pending "$F"
  [ "$(grep -c '^P[0-9]* (raised at ' "$OUT")" = 2 ]
  grep -q '^P1 (raised at F, ' "$OUT"
  grep -qx 'First question?' "$OUT"
  grep -q '^P2 (raised at I, ' "$OUT"
  grep -qx 'Second question?' "$OUT"
}

@test "answer records the answer and its time; the question is no longer pending" {
  q a 'First question?'; q b 'Second question?'; q yes 'Yes, record it.'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  runs ask-later "$F" I "$BATS_TEST_TMPDIR/b"
  runs answer "$F" P1 "$BATS_TEST_TMPDIR/yes"
  [ "$(cat "$OUT")" = P1 ]
  [ "$(jq -r '.gates.pending[0].answer' "$SF" | tr -d '\r')" = 'Yes, record it.' ]
  [[ "$(jq -r '.gates.pending[0].answeredAt' "$SF" | tr -d '\r')" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$ ]] || false
  runs pending "$F"
  if grep -q '^P1 ' "$OUT"; then echo "P1 is still pending after its answer"; false; fi
  grep -q '^P2 ' "$OUT"
}

@test "answer refuses a bad id, an unknown id, a second answer and an empty answer" {
  q a 'First question?'; q yes 'Yes.'; q no 'No.'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  refuses "usage: answer" answer "$F" P1
  refuses "is not a question id" answer "$F" 1 "$BATS_TEST_TMPDIR/yes"
  refuses "is not a question id" answer "$F" P0 "$BATS_TEST_TMPDIR/yes"
  refuses "no question P7 is queued" answer "$F" P7 "$BATS_TEST_TMPDIR/yes"
  printf '\n' > "$BATS_TEST_TMPDIR/blank"
  refuses "is empty" answer "$F" P1 "$BATS_TEST_TMPDIR/blank"
  runs answer "$F" P1 "$BATS_TEST_TMPDIR/yes"
  refuses "P1 is already answered" answer "$F" P1 "$BATS_TEST_TMPDIR/no"
  [ "$(jq -r '.gates.pending[0].answer' "$SF" | tr -d '\r')" = 'Yes.' ]
}

@test "an answered question queued again gets its id back and stays answered" {
  q a 'First question?'; q yes 'Yes.'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  runs answer "$F" P1 "$BATS_TEST_TMPDIR/yes"
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  [ "$(cat "$OUT")" = P1 ]
  [ "$(jq -r '.gates.pending | length' "$SF" | tr -d '\r')" = 1 ]
  [ "$(jq -r '.gates.pending[0].answer' "$SF" | tr -d '\r')" = 'Yes.' ]
}

# checks <rc> <args...> — the exact exit code, never just "non-zero".
checks() {
  local want="$1" rc=0; shift
  bash "$PROG" "$@" > "$OUT" 2> "$ERR" || rc=$?
  [ "$rc" -eq "$want" ] || { echo "exit $rc, expected $want: $(cat "$ERR")"; return 1; }
}

@test "pending-check passes with no queue and with every question answered, and fails naming the open ones" {
  checks 0 pending-check "$F"
  [ ! -s "$OUT" ]
  q a 'First?'; q b 'Second?'; q yes 'Yes.'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  runs ask-later "$F" I "$BATS_TEST_TMPDIR/b"
  checks 1 pending-check "$F"
  [[ "$(cat "$ERR")" == *"still open: P1 P2"* ]] || false
  runs answer "$F" P1 "$BATS_TEST_TMPDIR/yes"
  checks 1 pending-check "$F"
  [[ "$(cat "$ERR")" == *"still open: P2"* ]] || false
  runs answer "$F" P2 "$BATS_TEST_TMPDIR/yes"
  checks 0 pending-check "$F"
}

@test "pending-check never passes on a queue it cannot read" {
  jq '.gates.pending = "P1"' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  checks 1 pending-check "$F"
  [[ "$(cat "$ERR")" == *"is not a list of questions"* ]] || false
  jq '.gates.pending = [{"id": "P1", "phase": "F"}]' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  checks 1 pending-check "$F"
  [[ "$(cat "$ERR")" == *"is not a list of questions"* ]] || false
  jq '.gates.pending = [{"id": "P1", "phase": "F", "question": "Q?", "answer": true}]' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  checks 1 pending-check "$F"
  [[ "$(cat "$ERR")" == *"is not a list of questions"* ]] || false
  rm "$SF"
  checks 1 pending-check "$F"
}

@test "state-set never writes the queue: not as a sub-key, not through a whole-gates write" {
  q a 'First?'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  refuses "gates.pending is written only by ask-later and answer" state-set "$F" gates pending '[]'
  refuses "must keep gates.pending as it is" state-set "$F" gates '{"C": "done"}'
  local keep; keep="$(pending_json)"
  runs state-set "$F" gates "$(jq -c '.gates + {"C": "done"}' "$SF" | tr -d '\r')"
  [ "$(pending_json)" = "$keep" ]
  runs state-set "$F" gates C '"again"'
  [ "$(pending_json)" = "$keep" ]
}

@test "after L a question cannot wait: ask-later refuses M, N, N.5 and O" {
  q a 'A late question?'
  local p
  for p in M N N.5 O; do
    refuses "after L, a question cannot wait" ask-later "$F" "$p" "$BATS_TEST_TMPDIR/a"
  done
  runs ask-later "$F" L "$BATS_TEST_TMPDIR/a"
  [ "$(cat "$OUT")" = P1 ]
}

@test "ask-later refuses a phase that is two phases joined by a space" {
  q a 'A question?'
  refuses "unknown phase 'F F.5'" ask-later "$F" 'F F.5' "$BATS_TEST_TMPDIR/a"
}

@test "a queue that is present but not a list, or gates that is not an object, never reads as empty" {
  local v
  for v in false null '{}' '"P1"' 0; do
    jq --argjson v "$v" '.gates.pending = $v' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
    checks 1 pending-check "$F"
    [[ "$(cat "$ERR")" == *"is not a list of questions"* ]] || { echo "pending = $v: $(cat "$ERR")"; false; }
  done
  jq '.gates = "C"' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  checks 1 pending-check "$F"
  [[ "$(cat "$ERR")" == *"is not a list of questions"* ]] || false
}

@test "a whole-gates write cannot add a queue where there was none" {
  refuses "must keep gates.pending as it is" state-set "$F" gates '{"pending": false}'
  refuses "must keep gates.pending as it is" state-set "$F" gates '{"pending": []}'
  runs state-set "$F" gates '{"C": "done"}'
  [ "$(jq '.gates | has("pending")' "$SF" | tr -d '\r')" = false ]
}

@test "answer takes an id past P999" {
  local i
  jq '.gates.pending = [range(1; 1001) | {id: "P\(.)", phase: "F", question: "Q\(.)?"}]' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  q yes 'Yes.'
  runs answer "$F" P1000 "$BATS_TEST_TMPDIR/yes"
  [ "$(jq -r '.gates.pending[999].answer' "$SF" | tr -d '\r')" = Yes. ]
  refuses "is not a question id" answer "$F" P01 "$BATS_TEST_TMPDIR/yes"
  refuses "is not a question id" answer "$F" P1x "$BATS_TEST_TMPDIR/yes"
  refuses "is not a question id" answer "$F" P1a2 "$BATS_TEST_TMPDIR/yes"
}

@test "a hand-edited id or answer that hides an open question is refused, never read as closed" {
  local v
  for v in '[{"id": "", "phase": "F", "question": "Q?"}]' \
           '[{"id": "\n", "phase": "F", "question": "Q?"}]' \
           '[{"id": "P1", "phase": "F", "question": "Q?"}, {"id": "P1", "phase": "F", "question": "R?"}]' \
           '[{"id": "P01", "phase": "F", "question": "Q?"}]' \
           '[{"id": "P1", "phase": "F", "question": "Q?", "answer": ""}]' \
           '[{"id": "P1", "phase": "F", "question": "Q?", "answer": "  "}]'; do
    jq --argjson v "$v" '.gates.pending = $v' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
    checks 1 pending-check "$F"
    [[ "$(cat "$ERR")" == *"is not a list of questions"* ]] || { echo "pending = $v: $(cat "$ERR")"; false; }
  done
}

@test "a new id is one past the highest, so an id is never minted twice" {
  jq '.gates.pending = [{"id": "P2", "phase": "F", "question": "Q?"}]' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  q a 'Another?'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  [ "$(cat "$OUT")" = P3 ]
}

@test "text that can disguise itself in a terminal, or is too long, is refused" {
  local c
  for c in '\xe2\x80\xae' '\xe2\x80\x8b' '\xc2\x9b' '\xef\xbb\xbf'; do
    printf "approve $c this?\n" > "$BATS_TEST_TMPDIR/u"
    refuses "a character that can disguise text" ask-later "$F" F "$BATS_TEST_TMPDIR/u"
  done
  head -c 20000 /dev/zero | tr '\0' 'a' > "$BATS_TEST_TMPDIR/long"
  refuses "is longer than 16384 bytes" ask-later "$F" F "$BATS_TEST_TMPDIR/long"
  printf 'Café, 中文 and 😀 are fine?\n' > "$BATS_TEST_TMPDIR/ok"
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/ok"
}

@test "questions queued at the same moment are all kept, each with its own id" {
  local i round ids pids
  # Two rounds of five: each progress.sh call costs about a second on
  # Windows, and the lock makes them take turns. The held-lock tests below
  # prove each writer's lock without timing; this one proves the whole.
  for round in 1 2; do
    pids=()
    bash "$PROG" init "r$round" "r$round" main other > /dev/null
    for i in 1 2 3 4 5; do
      q "p$round-$i" "Question $round.$i?"
      bash "$PROG" ask-later "r$round" F "$BATS_TEST_TMPDIR/p$round-$i" > "$BATS_TEST_TMPDIR/o$round-$i" 2>&1 &
      pids+=("$!")
    done
    # Only these PIDs: a bare wait would also wait for bats' own timeout watcher.
    wait "${pids[@]}" || true
    ids="$(jq -r '[.gates.pending[].id] | sort | join(" ")' ".delivery-kit/runs/r$round/progress.json" | tr -d '\r')"
    [ "$ids" = "P1 P2 P3 P4 P5" ] || { echo "round $round stored: $ids"; cat "$BATS_TEST_TMPDIR"/o"$round"-*; false; }
    [ "$(jq -r '[.gates.pending[].question] | sort | join(" ")' ".delivery-kit/runs/r$round/progress.json" | tr -d '\r')" \
      = "$(printf 'Question %s.%s? ' "$round" 1 "$round" 2 "$round" 3 "$round" 4 "$round" 5 | sed 's/ $//')" ] \
      || { echo "round $round lost or changed a question's text"; false; }
  done
}

@test "writers running at the same moment never empty the state file or drop the queue" {
  local round i pids
  q a 'Kept?'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  for round in 1 2; do
    pids=()
    for i in 1 2; do
      bash "$PROG" phase-start "$F" C > /dev/null 2>&1 &
      pids+=("$!")
      bash "$PROG" phase-done "$F" C > /dev/null 2>&1 &
      pids+=("$!")
      bash "$PROG" state-set "$F" gates C "\"r$round-$i\"" > /dev/null 2>&1 &
      pids+=("$!")
    done
    wait "${pids[@]}" || true
    [ -s "$SF" ] || { echo "round $round: the state file is empty"; false; }
    jq -e . "$SF" > /dev/null || { echo "round $round: the state file is not JSON"; false; }
    [ "$(jq -r '.gates.pending[0].question' "$SF" | tr -d '\r')" = 'Kept?' ] || { echo "round $round: the queue was dropped"; false; }
    # Every writer's change survives: a write that read the file before
    # another's write and replaced it after would drop one of these.
    [ "$(jq -r '[(.completed_phases | index("C") != null), (.timestamps.C.started | type), (.timestamps.C.done | type), (.gates.C | type)] | join(" ")' "$SF" | tr -d '\r')" \
      = 'true string string string' ] || { echo "round $round lost a writer's change: $(jq -c '{completed_phases, t: .timestamps.C, c: .gates.C}' "$SF")"; false; }
  done
}

@test "a lock left by a dead writer is broken after a minute; a live one makes a write wait, then refuse" {
  q a 'After a crash?'
  mkdir "$SF.lock"
  touch -d "@$(( $(date +%s) - 120 ))" "$SF.lock"
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  [[ "$(cat "$ERR")" == *"broke a stale lock"* ]] || false
  [ ! -e "$SF.lock" ]
  mkdir "$SF.lock"
  q b 'While locked?'
  PROGRESS_LOCK_TRIES=3 refuses "is locked by another write" ask-later "$F" F "$BATS_TEST_TMPDIR/b"
  rmdir "$SF.lock"
}

@test "every state write waits for a held lock, then refuses and changes nothing" {
  mkdir "$SF.lock"
  PROGRESS_LOCK_TRIES=3 refuses "is locked by another write" phase-start "$F" C
  PROGRESS_LOCK_TRIES=3 refuses "is locked by another write" phase-done "$F" C
  PROGRESS_LOCK_TRIES=3 refuses "is locked by another write" commit-add "$F" tests 0123456789abcdef0123456789abcdef01234567 "" ""
  PROGRESS_LOCK_TRIES=3 refuses "is locked by another write" state-set "$F" gates C '"x"'
  rmdir "$SF.lock"
}

# A held lock, a write started behind it, and the holder's own change made
# before it lets go: the waiting write must judge the file AFTER that change.
@test "a whole-gates write judges the queue under the lock, not before it" {
  mkdir "$SF.lock"
  local pid rc=0
  PROGRESS_LOCK_TRIES=400 bash "$PROG" state-set "$F" gates '{"C": "done"}' > "$OUT" 2> "$ERR" &
  pid=$!
  sleep 4
  jq '.gates.pending = [{"id": "P1", "phase": "F", "question": "Q?"}]' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  rmdir "$SF.lock"
  wait "$pid" || rc=$?
  [ "$rc" -eq 1 ] || { echo "exit $rc: $(cat "$ERR")"; false; }
  [[ "$(cat "$ERR")" == *"must keep gates.pending as it is"* ]] || false
  [ "$(jq -r '.gates.pending[0].question' "$SF" | tr -d '\r')" = 'Q?' ]
}

@test "answer judges the question open under the lock: a second answer never replaces the first" {
  q a 'First?'; q yes 'Yes.'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  mkdir "$SF.lock"
  local pid rc=0
  PROGRESS_LOCK_TRIES=400 bash "$PROG" answer "$F" P1 "$BATS_TEST_TMPDIR/yes" > "$OUT" 2> "$ERR" &
  pid=$!
  sleep 4
  jq '.gates.pending[0].answer = "No."' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  rmdir "$SF.lock"
  wait "$pid" || rc=$?
  [ "$rc" -eq 1 ] || { echo "exit $rc: $(cat "$ERR")"; false; }
  [[ "$(cat "$ERR")" == *"P1 is already answered"* ]] || false
  [ "$(jq -r '.gates.pending[0].answer' "$SF" | tr -d '\r')" = 'No.' ]
}

@test "ask-later mints its id under the lock" {
  q b 'Second?'
  mkdir "$SF.lock"
  local pid rc=0
  PROGRESS_LOCK_TRIES=400 bash "$PROG" ask-later "$F" F "$BATS_TEST_TMPDIR/b" > "$OUT" 2> "$ERR" &
  pid=$!
  sleep 4
  jq '.gates.pending = [{"id": "P1", "phase": "F", "question": "First?"}]' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  rmdir "$SF.lock"
  wait "$pid" || rc=$?
  [ "$rc" -eq 0 ] || { echo "exit $rc: $(cat "$ERR")"; false; }
  [ "$(cat "$OUT")" = P2 ]
  [ "$(jq -c '[.gates.pending[].id]' "$SF" | tr -d '\r')" = '["P1","P2"]' ]
}

@test "the text file is read once: a swap after the check never reaches the queue" {
  local shim="$BATS_TEST_TMPDIR/shim"
  mkdir "$shim"
  local real; real="$(command -v cat)"
  printf '%s\n' '#!/bin/bash' \
    "'$real' \"\$@\"; rc=\$?" \
    'for a in "$@"; do if [ "$a" = "$SWAP_FILE" ]; then printf "Swapped \033[31mred\033[0m?\n" > "$a"; fi; done' \
    'exit $rc' > "$shim/cat"
  chmod +x "$shim/cat"
  q a 'Clean?'
  SWAP_FILE="$BATS_TEST_TMPDIR/a" PATH="$shim:$PATH" runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  grep -q Swapped "$BATS_TEST_TMPDIR/a" || { echo "the shim never swapped the file: the test proves nothing"; false; }
  [ "$(jq -r '.gates.pending[0].question' "$SF" | tr -d '\r')" = 'Clean?' ]
}

@test "the size limit is exactly 16384 bytes" {
  head -c 16384 /dev/zero | tr '\0' a > "$BATS_TEST_TMPDIR/at"
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/at"
  head -c 16385 /dev/zero | tr '\0' b > "$BATS_TEST_TMPDIR/over"
  refuses "is longer than 16384 bytes (16385)" ask-later "$F" F "$BATS_TEST_TMPDIR/over"
}

@test "every edge of every refused range is refused, and the characters beside them are not" {
  local c i=0
  for c in '\xc2\x80' '\xc2\x9f' '\xe2\x80\x8b' '\xe2\x80\x8f' '\xe2\x80\xaa' '\xe2\x80\xae' '\xe2\x81\xa0' '\xe2\x81\xa9' '\xef\xbb\xbf'; do
    printf "approve $c this?\n" > "$BATS_TEST_TMPDIR/u"
    refuses "a character that can disguise text" ask-later "$F" F "$BATS_TEST_TMPDIR/u"
  done
  for c in '\xc2\xa0' '\xe2\x80\x90' '\xe2\x80\xaf'; do
    i=$((i + 1))
    printf "fine $i $c this?\n" > "$BATS_TEST_TMPDIR/ok$i"
    runs ask-later "$F" F "$BATS_TEST_TMPDIR/ok$i"
  done
}

@test "answer with no queue at all names the id as not queued" {
  q yes 'Yes.'
  refuses "no question P1 is queued" answer "$F" P1 "$BATS_TEST_TMPDIR/yes"
}

@test "pending prints each open entry, a blank line between, and says when no time was recorded" {
  jq '.gates.pending = [{"id": "P1", "phase": "F", "question": "First?", "askedAt": "2026-01-01T00:00:00Z"}, {"id": "P2", "phase": "I", "question": "Second?"}, {"id": "P3", "phase": "I", "question": "Third?", "answer": "x"}]' "$SF" > "$BATS_TEST_TMPDIR/t.json" && mv "$BATS_TEST_TMPDIR/t.json" "$SF"
  runs pending "$F"
  [ "$(tr -d '\r' < "$OUT")" = "$(printf 'P1 (raised at F, 2026-01-01T00:00:00Z):\nFirst?\n\nP2 (raised at I, time not recorded):\nSecond?')" ]
}

@test "a refusal made while holding the lock leaves no lock behind" {
  q a 'First?'; q yes 'Yes.'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  refuses "gates.pending is written only by ask-later and answer" state-set "$F" gates pending '[]'
  [ ! -e "$SF.lock" ] || { echo "state-set's refusal left the lock"; false; }
  runs answer "$F" P1 "$BATS_TEST_TMPDIR/yes"
  refuses "P1 is already answered" answer "$F" P1 "$BATS_TEST_TMPDIR/yes"
  [ ! -e "$SF.lock" ] || { echo "answer's refusal left the lock"; false; }
}

# The old fixed name, <state file>.tmp, made a directory: a write through it
# fails, a write through a temporary file of its own does not.
@test "no state write goes through the shared name <state file>.tmp" {
  q a 'First?'
  mkdir "$SF.tmp"
  runs phase-start "$F" C
  runs phase-done "$F" C
  runs commit-add "$F" tests 0123456789abcdef0123456789abcdef01234567 "" ""
  runs state-set "$F" gates C '"x"'
  runs ask-later "$F" F "$BATS_TEST_TMPDIR/a"
  rmdir "$SF.tmp"
}

@test "the text's checked copy is a temporary file of its own" {
  q a 'First?'
  : > "$BATS_TEST_TMPDIR/notadir"
  TMPDIR="$BATS_TEST_TMPDIR/notadir" refuses "could not make a temporary file to read the question file" ask-later "$F" F "$BATS_TEST_TMPDIR/a"
}
