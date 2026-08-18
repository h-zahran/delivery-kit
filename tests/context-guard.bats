#!/usr/bin/env bats

load helper

@test "stays silent below the threshold" {
  t="$(transcript_with 10000 10000 10000 10000 10000)"   # 5% of 200000
  run_hook "$t"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "blocks at the threshold, naming the skill, the percentage and the window" {
  t="$(transcript_with 90000 90000 90000 90000 90000)"   # exactly 45% of 200000
  run_hook "$t"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("handoff")'
  echo "$output" | jq -e '.reason | test("at 45% of")'
  echo "$output" | jq -e '.reason | test("200000-token")'
  echo "$output" | jq -e '.reason | test("threshold 45%")'
}

@test "one inflated entry among five does not fire the guard (2026-08-07 regression)" {
  # Four honest entries at 24% and one most-recent request that re-sent the
  # full raw history. Reading the last entry fires the guard at 450%; the
  # median of the last five must leave it silent.
  t="$(transcript_with 48000 48000 48000 48000 900000)"
  run_hook "$t"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a run of inflated entries longer than the median window does not fire the guard (2026-08-15 regression)" {
  # The single-entry case above is the easy one. A tool that forwards the whole
  # conversation does not inflate ONE reading: the advisor tool inflates four to
  # six consecutive ones, because the following assistant messages read the same
  # oversized cache. A window of five is then filled by the spike and the median
  # IS the spike — seen 2026-08-15, the hook reported 37% where Claude Code's own
  # status line read 19%. Nine honest entries at 24% then six inflated ones: a
  # five-wide window sees nothing but spikes and fires at 450%.
  t="$(transcript_with 48000 48000 48000 48000 48000 48000 48000 48000 48000 \
                       900000 900000 900000 900000 900000 900000)"
  run_hook "$t"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "counts cache reads and cache creation toward context" {
  # 30000 live + 60000 cached = 90000 = 45%. Counting input_tokens alone
  # would read 15% and stay silent.
  t="$TEST_DIR/transcript.jsonl"
  : > "$t"
  for _ in 1 2 3 4 5; do
    printf '{"isSidechain":false,"message":{"usage":{"input_tokens":30000,"cache_read_input_tokens":50000,"cache_creation_input_tokens":10000}}}\n' >> "$t"
  done
  run_hook "$t"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 45% of")'
}

@test "takes the median of the window, not the smallest" {
  # Without this, a min-of-window implementation passes every other test in
  # this file — and reading low is the fail-silent direction, the one the
  # guard must never drift toward. Median of the sorted five is 100000
  # (50%); the minimum is 48000 (24%, silent), and the mean is 79200
  # (39%, silent).
  t="$(transcript_with 48000 48000 100000 100000 100000)"
  run_hook "$t"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 50% of")'
}

@test "ignores sidechain (subagent) entries" {
  # A subagent burning 900000 tokens says nothing about the main session's
  # context, and its entries are the most recent ones in the transcript.
  t="$(transcript_with 20000 20000 20000 20000 20000)"   # 10%
  for _ in 1 2 3 4 5; do append_entry "$t" 900000 true; done
  run_hook "$t"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skips a malformed transcript line instead of disabling the guard" {
  # Claude Code appends to the transcript while the hook reads it, so a
  # torn final line is normal. Slurping the whole file aborts the parse on
  # the first bad line and leaves the guard silently switched off.
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  printf 'this line is not JSON {{{\n' >> "$t"
  run_hook "$t"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 45% of")'
}

@test "exits silently when the payload carries no transcript_path" {
  run bash "$HOOK" <<< '{"session_id":"no-transcript"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits silently when the transcript file does not exist" {
  payload="$(jq -nc --arg t "$TEST_DIR/absent.jsonl" '{transcript_path:$t, session_id:"x"}')"
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sidechain volume does not starve the median" {
  # The tail is a budget in lines; the median needs five readings. Sidechain
  # lines from subagents consume the budget without yielding one, so a large
  # enough fan-out can clip every honest reading and leave the median resting
  # on whichever single entry survives. That is the 2026-08-07 last-entry
  # failure reached by a different route, and every other fixture in this file
  # is a handful of lines long, so nothing else here can see it.
  t="$TEST_DIR/starve.jsonl"
  : > "$t"
  for _ in 1 2 3 4; do
    printf '{"isSidechain":false,"message":{"usage":{"input_tokens":48000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' >> "$t"
  done
  for _ in $(seq 1 400); do
    printf '{"isSidechain":true,"message":{"usage":{"input_tokens":5000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' >> "$t"
  done
  printf '{"isSidechain":false,"message":{"usage":{"input_tokens":900000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' >> "$t"

  run_hook "$t" starve
  [ "$status" -eq 0 ]
  # 48000 of 200000 is 24%, below the 45% default, so the guard stays silent.
  # Under a starved tail the median becomes 900000 and it fires at 450%.
  [ -z "$output" ]
}

@test "no byte cap, at any size, changes the answer" {
  # This test used to assert the opposite, and was right to: with a five-wide
  # median, capping to the last three entries moved the median from 30000 to
  # 40000, and asserting the 40000 proved the cap was applied. A fifteen-wide
  # median removes that observation by construction. `.[-15:]` of a suffix
  # still holding fifteen readings IS the last fifteen of the whole file, and a
  # suffix holding fewer trips the fallback and is thrown away — so no cap size
  # has an observable effect, and the property left to pin is the one the cap
  # must never break.
  #
  # This deliberately does NOT prove the cap is applied; nothing observable can
  # now. That is an acceptable loss and not a silent one: a cap that has been
  # removed or ignored costs latency, and latency is bounded by the hook
  # timeout, which test "the hook timeout leaves headroom over the measured
  # worst case" pins separately. A cap that changed the answer would instead
  # misreport context, which is the failure this whole file exists to prevent.
  t="$(transcript_with 10000 20000 30000 40000 50000)"
  printf '{"contextGuard":{"windowTokens":100000,"thresholdPct":1}}\n' > "$TEST_DIR/.delivery-kit.json"

  # Uncapped the median of the five is 30000, so every cap must report 30%.
  for lines in 1 3 5; do
    export DELIVERY_KIT_MAX_BYTES="$(tail -n "$lines" "$t" | wc -c | tr -d ' ')"
    run_hook "$t" "capped$lines"
    [ "$status" -eq 0 ]
    [[ "$output" == *"30% of the 100000-token window"* ]]
  done
}

@test "a byte cap too small to hold the readings does not starve the median" {
  # The byte cap is a second budget that does not measure readings either, so
  # it can reach the 2026-08-07 incident by the same route `tail -n 300` did:
  # clip every honest reading, leave the median resting on one inflated entry.
  # Four honest readings then one inflated one, with the cap holding only the
  # last line. Uncapped the median is 48000 (48%); starved it is 900000, and
  # the guard reports 900% and tells the user to raise windowTokens — turning
  # a loud failure into a silent one. The cap must never be able to do that.
  t="$(transcript_with 48000 48000 48000 48000 900000)"
  printf '{"contextGuard":{"windowTokens":100000,"thresholdPct":1}}\n' > "$TEST_DIR/.delivery-kit.json"
  export DELIVERY_KIT_MAX_BYTES="$(tail -n 1 "$t" | wc -c | tr -d ' ')"

  run_hook "$t" starvecap
  [ "$status" -eq 0 ]
  [[ "$output" == *"48% of the 100000-token window"* ]]
  [[ "$output" != *"900%"* ]]
}

@test "a byte cap leaving fewer readings than the median window does not starve it" {
  # Sibling of the test above, for the widened window. The floor below which the
  # capped read is discarded has to track the window: a cap can hold eight
  # readings — clear of any smaller floor, so no fallback runs — and if six of
  # those eight are inflated the median IS an inflated entry. Nine honest
  # readings then six inflated ones, capped to the last eight: uncapped the
  # median is 48000 (48%), starved it is 900000 and the guard reports 900%.
  t="$(transcript_with 48000 48000 48000 48000 48000 48000 48000 48000 48000 \
                       900000 900000 900000 900000 900000 900000)"
  printf '{"contextGuard":{"windowTokens":100000,"thresholdPct":1}}\n' > "$TEST_DIR/.delivery-kit.json"
  export DELIVERY_KIT_MAX_BYTES="$(tail -n 8 "$t" | wc -c | tr -d ' ')"

  run_hook "$t" starvewide
  [ "$status" -eq 0 ]
  [[ "$output" == *"48% of the 100000-token window"* ]]
  [[ "$output" != *"900%"* ]]
}

@test "fires once per 5% bucket" {
  # The corrupt flag is part of this test rather than its own: a file left
  # empty by a crash between truncate and write, or written by another tool
  # using the same path, must not wedge the guard shut for the session.
  printf 'garbage\n' > "$TMPDIR/ctx-warned-bucket-session"
  t="$(transcript_with 90000 90000 90000 90000 90000)"   # 45% -> bucket 9
  run_hook "$t" bucket-session
  echo "$output" | jq -e '.decision == "block"'
  run_hook "$t" bucket-session
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fires again in the next 5% bucket" {
  t="$(transcript_with 90000 90000 90000 90000 90000)"   # 45% -> bucket 9
  run_hook "$t" growing-session
  echo "$output" | jq -e '.reason | test("at 45% of")'
  t="$(transcript_with 100000 100000 100000 100000 100000)"   # 50% -> bucket 10
  run_hook "$t" growing-session
  echo "$output" | jq -e '.reason | test("at 50% of")'
}

@test "re-arms after a compaction drops the context" {
  # A compaction halves context while the session id persists. A mark that
  # only ever rose would stay silent from here all the way back to 90% —
  # precisely the band the guard exists to cover. Note the middle reading
  # is below the threshold, which is where a compaction usually lands, so
  # the reset cannot live behind the threshold gate.
  t="$(transcript_with 180000 180000 180000 180000 180000)"   # 90% -> bucket 18
  run_hook "$t" compacted
  echo "$output" | jq -e '.reason | test("at 90% of")'
  t="$(transcript_with 60000 60000 60000 60000 60000)"        # 30%, below threshold
  run_hook "$t" compacted
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  t="$(transcript_with 96000 96000 96000 96000 96000)"        # 48% -> bucket 9
  run_hook "$t" compacted
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 48% of")'
}

@test "one-bucket jitter does not re-arm the guard" {
  # The drop-reset must not undo the thing this task is for. A reading
  # oscillating across a single bucket boundary — 50, 45, 50 — would
  # re-warn on nearly every tool call if any drop reset the mark.
  t="$(transcript_with 100000 100000 100000 100000 100000)"   # 50% -> bucket 10
  run_hook "$t" jitter
  echo "$output" | jq -e '.reason | test("at 50% of")'
  t="$(transcript_with 90000 90000 90000 90000 90000)"        # 45% -> bucket 9
  run_hook "$t" jitter
  [ -z "$output" ]
  t="$(transcript_with 100000 100000 100000 100000 100000)"   # 50% again
  run_hook "$t" jitter
  [ -z "$output" ]
}

@test "reads thresholdPct from .delivery-kit.json" {
  printf '{"contextGuard":{"thresholdPct":10}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 30000 30000 30000 30000 30000)"   # 15% of 200000
  run_hook "$t"
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("threshold 10%")'
}

@test "reads windowTokens from .delivery-kit.json" {
  printf '{"contextGuard":{"windowTokens":1000000}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 90000 90000 90000 90000 90000)"   # 45% of 200000, 9% of 1000000
  run_hook "$t"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a maxBytes committed to .delivery-kit.json cannot make the guard misreport" {
  # Companion to "no byte cap, at any size, changes the answer", for the config
  # path rather than the environment one. Like that test it can no longer prove
  # the key is READ — under a fifteen-wide median no maxBytes value is
  # observable — so it pins the half that still matters: maxBytes is the one
  # setting a user tunes for speed rather than for behaviour, and committing a
  # too-small value to a repository must not silently turn the guard into a
  # liar for everyone who clones it.
  #
  # The sibling keys in the same object still are observable, and are asserted
  # here too, so a parse that dropped the whole contextGuard object on the
  # unfamiliar maxBytes key could not pass.
  t="$(transcript_with 48000 48000 48000 48000 900000)"
  cap="$(tail -n 1 "$t" | wc -c | tr -d ' ')"
  printf '{"contextGuard":{"windowTokens":100000,"thresholdPct":1,"maxBytes":%s}}\n' "$cap" \
    > "$TEST_DIR/.delivery-kit.json"

  run_hook "$t" cfgcap
  [ "$status" -eq 0 ]
  [[ "$output" == *"48% of the 100000-token window"* ]]
  [[ "$output" == *"threshold 1%"* ]]
  [[ "$output" != *"900%"* ]]
}

@test "an environment variable overrides the config file" {
  printf '{"contextGuard":{"windowTokens":1000000}}\n' > "$TEST_DIR/.delivery-kit.json"
  export DELIVERY_KIT_WINDOW_TOKENS=200000
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t"
  echo "$output" | jq -e '.reason | test("200000-token")'
}

@test "reads a user-level .delivery-kit.json" {
  # The window is a fact about a machine and a model, not about a repository.
  # Without this layer a user answers the same question in every repo, which is
  # how most repositories end up on defaults.
  #
  # $HOME here is the harness's, not the developer's: setup() isolates it for
  # the same reason it isolates TMPDIR, so these four tests write a user-level
  # file without touching the real one — and without the real one reaching any
  # other test in this file.
  printf '{"contextGuard":{"windowTokens":1000000}}\n' > "$HOME/.delivery-kit.json"
  t="$(transcript_with 450000 450000 450000 450000 450000)"
  run_hook "$t" userlevel
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.reason | test("1000000-token")'
  echo "$output" | jq -e '.reason | test("at 45% of")'
}

@test "the repo file overrides the user file" {
  # D2 keeps the repo file winning so a project can override for its own
  # reasons. A user-level value that could not be overridden would be a worse
  # version of the default it replaces.
  #
  # An override test cannot prove the losing layer was read, because "the user
  # file lost" and "the user file was never read" produce identical output —
  # the winner's value either way. That is not fixed by choosing a distinctive
  # window: 300000 comes from the repo file whether or not the user file was
  # ever opened, and deleting the user-level read leaves such a test green.
  # Verified, not assumed: that deletion is exactly how this weakness was found.
  #
  # So the user file carries a second, UNCONTESTED key. The repo file overrides
  # windowTokens and says nothing about thresholdPct, so the threshold in the
  # reason can only have come from the user file — and the window can only have
  # come from the repo file. One test, both halves observable.
  printf '{"contextGuard":{"windowTokens":1000000,"thresholdPct":20}}\n' > "$HOME/.delivery-kit.json"
  printf '{"contextGuard":{"windowTokens":300000}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 150000 150000 150000 150000 150000)"
  run_hook "$t" repowins
  [ "$status" -eq 0 ]
  # The repo file won the key both files set. Under the user's 1000000 this
  # reading is 15% and the guard stays silent; under the 200000 default it is
  # 75%. Neither can produce the line below.
  echo "$output" | jq -e '.reason | test("300000-token")'
  echo "$output" | jq -e '.reason | test("at 50% of")'
  # And the user file was genuinely read while losing that key. Without the
  # user-level read this is the 45% default.
  echo "$output" | jq -e '.reason | test("threshold 20%")'
}

@test "the environment overrides both files" {
  # Three distinct windows, none of them the default, so the reason names the
  # layer that won rather than a number two layers could have produced. And, as
  # in the test above, an uncontested thresholdPct in the user file — otherwise
  # the environment winning is indistinguishable from the files never being
  # read at all, and this test would survive the deletion of the very line it
  # exists to cover.
  printf '{"contextGuard":{"windowTokens":1000000,"thresholdPct":20}}\n' > "$HOME/.delivery-kit.json"
  printf '{"contextGuard":{"windowTokens":500000}}\n' > "$TEST_DIR/.delivery-kit.json"
  export DELIVERY_KIT_WINDOW_TOKENS=250000
  t="$(transcript_with 125000 125000 125000 125000 125000)"
  run_hook "$t" envwins
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.reason | test("250000-token")'
  echo "$output" | jq -e '.reason | test("at 50% of")'
  echo "$output" | jq -e '.reason | test("threshold 20%")'
}

@test "an invalid user-level value leaves the guard armed" {
  # Same validation on both files, so no invalid value from either can disable
  # the guard. A zero window would make the percentage arithmetic divide by
  # zero, which is the shape that silences it.
  #
  # The user file carries a VALID sibling key alongside the invalid one, and
  # that is what makes this test able to detect the user layer being missing at
  # all. Asserting only that an invalid value changed nothing cannot: a layer
  # that is never read also changes nothing, so the two outcomes are identical
  # and the test passes either way.
  #
  # There is deliberately NO repo file. An earlier version of this test gave one
  # a valid window and asserted that, which quietly destroyed it: the repo file
  # is read AFTER the user file, so its window overwrites the invalid 0 whether
  # that 0 was rejected or taken. The test then passed with the 0 deleted from
  # the fixture, and passed again with the window validation removed from
  # read_config — it had stopped testing its own name. Do not reintroduce a repo
  # file here; the layer that wins is precisely what hides the thing under test.
  #
  # Asserting the 200000 DEFAULT is safe here even though it was not safe three
  # tests above, and the reason is that it no longer stands alone. Two
  # independent signals ride one fixture: the invalid window falls back to the
  # default, while the VALID thresholdPct in the same file proves the file was
  # read at all. Drop the user-level read and the threshold assertion fails;
  # accept the zero and the window assertion fails, because 60000 of a zero
  # window is a division by zero that leaves pct empty and the guard silent.
  printf '{"contextGuard":{"windowTokens":0,"thresholdPct":20}}\n' > "$HOME/.delivery-kit.json"
  t="$(transcript_with 60000 60000 60000 60000 60000)"
  run_hook "$t" badusercfg
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.reason | test("200000-token")'
  echo "$output" | jq -e '.reason | test("threshold 20%")'
  echo "$output" | jq -e '.reason | test("at 30% of")'
}

@test "a malformed config file falls back to defaults rather than disabling the guard" {
  printf 'this is not json\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t"
  echo "$output" | jq -e '.reason | test("200000-token")'
  echo "$output" | jq -e '.reason | test("threshold 45%")'
}

@test "unknown config keys are ignored" {
  printf '{"profile":{"testCommand":"make test"},"contextGuard":{"thresholdPct":10}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 30000 30000 30000 30000 30000)"
  run_hook "$t"
  echo "$output" | jq -e '.reason | test("threshold 10%")'
}

@test "a leading-zero window is rejected rather than silencing the guard" {
  # `is_positive_int` parses base 10 and would accept "08", but the later
  # $(( ctx * 100 / WINDOW )) parses base 8, dies, leaves pct empty, and the
  # threshold comparison then errors into `|| exit 0` — the guard gone for
  # the session. Only reachable as a quoted string, since bare 08 is not
  # valid JSON, but that is exactly how a human writes a padded number.
  printf '{"contextGuard":{"windowTokens":"08"}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.reason | test("at 45% of")'
  echo "$output" | jq -e '.reason | test("200000-token")'
}

@test "fires below 5% when the threshold is set that low" {
  # Bucket 0 covers everything under 5% of the window, so a never-warned
  # sentinel of 0 would make the gate unable to fire there at all — and a low
  # threshold is the first thing a new user tries when checking the install.
  # The same floor bites a 1M-token window at any threshold, where 5% is
  # 50,000 tokens.
  printf '{"contextGuard":{"thresholdPct":1}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 6000 6000 6000 6000 6000)"   # 3% of 200000 -> bucket 0
  run_hook "$t" low-threshold
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 3% of")'
}

@test "a threshold above 100 is rejected rather than silencing the guard" {
  # 450 is a plausible typo for 45. It is valid JSON and a valid positive
  # integer, so nothing else rejects it — and a threshold that can never be
  # reached means the guard never fires again. Nothing downstream can catch
  # this: the window-misconfiguration report added in Task 6 runs only after
  # the guard has already decided to fire.
  printf '{"contextGuard":{"thresholdPct":450}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.reason | test("threshold 45%")'
}

@test "fires on thresholdTokens with no valid window configured" {
  # The point of the absolute tripwire: it is decidable from the transcript
  # alone, so a windowTokens that is wrong — or, here, invalid and discarded —
  # cannot silence it.
  printf '{"contextGuard":{"windowTokens":0,"thresholdTokens":400000}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 405000 405000 405000 405000 405000)"
  run_hook "$t" abswins
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("405000 tokens, past the 400000-token limit")'
}

@test "the absolute tripwire fires with the relative one unreachable" {
  # Proving the OR rather than assuming it: threshold 100% is not reachable
  # here, so only the absolute one can be responsible for the emission.
  printf '{"contextGuard":{"windowTokens":1000000,"thresholdPct":100,"thresholdTokens":400000}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 405000 405000 405000 405000 405000)"
  run_hook "$t" absonly
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("past the 400000-token limit")'
}

@test "the relative tripwire fires with the absolute one unreachable" {
  printf '{"contextGuard":{"windowTokens":1000000,"thresholdPct":45,"thresholdTokens":900000}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 450000 450000 450000 450000 450000)"
  run_hook "$t" relonly
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 45% of the 1000000-token window \\(threshold 45%\\)")'
  echo "$output" | jq -e '.reason | test("limit") | not'
}

@test "when both tripwires are crossed the absolute wording is used and the percentage survives" {
  # Without this the naming rule is unpinned: either branch would satisfy the
  # two tests above. The absolute one is named because it is the more specific
  # statement and the value the user set deliberately — and the percentage is
  # carried in the same sentence, so nothing is lost by the choice.
  printf '{"contextGuard":{"windowTokens":1000000,"thresholdPct":45,"thresholdTokens":400000}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 500000 500000 500000 500000 500000)"
  run_hook "$t" bothcrossed
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.reason | test("500000 tokens, past the 400000-token limit")'
  echo "$output" | jq -e '.reason | test("50% of the 1000000-token window")'
}

@test "thresholdTokens unset behaves exactly as 1.0.x" {
  # The regression test for the guarded comparison. An unguarded
  # [ "$ctx" -ge "" ] errors — but be precise about what that costs, because an
  # earlier version of this comment claimed it silences the guard and that is
  # false. Disproved by mutation, twice: the erroring test sits inside
  # `if …; then abs_fired=1; fi`, so the `if` consumes its status 2, abs_fired
  # stays 0, and the relative rule still emits decision:block. The real cost is
  # one "integer expected" line on stderr per tool call — output pollution, not
  # silence. Of the two things preventing it the `-n` test does the work, since
  # && short-circuits before the redirect is ever reached; the 2>/dev/null is
  # the backstop that would swallow the noise if the `-n` were dropped.
  #
  # Not the same hazard as the last_bucket sentinel, and this comment used to
  # say it was. That sentinel guards an erroring comparison feeding `|| exit 0`,
  # which genuinely does silence the guard for the session. Contained by an
  # `if`, an error is noise; feeding an `|| exit 0` chain, it is silence.
  #
  # This must be explicit rather than relying on other tests happening to leave
  # the value unset.
  printf '{"contextGuard":{"windowTokens":200000,"thresholdPct":45}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t" unsetabs
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 45% of the 200000-token window \\(threshold 45%\\)")'
}

@test "an invalid thresholdTokens leaves the guard armed on the relative rule" {
  printf '{"contextGuard":{"windowTokens":200000,"thresholdPct":45,"thresholdTokens":"08"}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t" badabs
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.reason | test("at 45% of the 200000-token window")'
}

@test "says so when observed context exceeds the configured window" {
  t="$(transcript_with 250000 250000 250000 250000 250000)"   # 125% of 200000
  run_hook "$t" over-window
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("WINDOW MISCONFIGURED")'
  echo "$output" | jq -e '.reason | test("250000")'
  # The setting name is the part a user acts on. Asserting the configured
  # window instead would be vacuous — "200000" already appears in the
  # unconditional part of the reason, so it would match either way.
  echo "$output" | jq -e '.reason | test("contextGuard.windowTokens")'
}

@test "the misconfiguration note names the real window, rather than setting homework" {
  # The guard already holds the answer it was asking for. A reading that
  # exceeds the configured window IS a lower bound on the real window, so
  # "raise it" hands back a task the hook could have finished itself.
  # Issue #1. The default stays 200000 — this replaces the confusing first
  # impression, not the conservative default that makes the failure loud.
  t="$(transcript_with 250000 250000 250000 250000 250000)"
  run_hook "$t" lower-bound
  [ "$status" -eq 0 ]
  # The observed reading, stated as the bound it actually is.
  echo "$output" | jq -e '.reason | test("at least 250000")'
  # And the two values a user is realistically choosing between, so they do
  # not have to go and look up what their model's window is.
  echo "$output" | jq -e '.reason | test("1000000")'
}

@test "says it only once per session" {
  t="$(transcript_with 250000 250000 250000 250000 250000)"   # 125% -> bucket 25
  run_hook "$t" once-only
  [[ "$output" == *"WINDOW MISCONFIGURED"* ]]
  t="$(transcript_with 260000 260000 260000 260000 260000)"   # 130% -> bucket 26
  run_hook "$t" once-only
  echo "$output" | jq -e '.decision == "block"'
  [[ "$output" != *"WINDOW MISCONFIGURED"* ]]
}

@test "the deferred setup suggestion follows the handoff instruction in the reason" {
  # ORDER is the assertion, not presence. The whole point of D5 is that the
  # suggestion must not read as a competing instruction at the moment the user
  # has least context to spare — so a test that only checked the text was
  # present would pass with it placed first, which is the failure.
  printf '{"contextGuard":{"windowTokens":200000}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 300000 300000 300000 300000 300000)"
  run_hook "$t" deferred
  [ "$status" -eq 0 ]
  reason="$(echo "$output" | jq -r '.reason')"
  handoff_at="$(awk '{print index($0, "print the resume prompt for the user, and stop.")}' <<< "$reason")"
  setup_at="$(awk '{print index($0, "After the handoff, run delivery-kit:setup")}' <<< "$reason")"
  [ "$handoff_at" -gt 0 ]
  [ "$setup_at" -gt 0 ]
  [ "$setup_at" -gt "$handoff_at" ]
}

@test "systemMessage is present in the emitted JSON when the window is provably wrong" {
  # This pins that the hedge is EMITTED, which is all that can be tested here.
  # Whether it is DISPLAYED is not observable from a test or from inside an
  # agent session — it was probed live and the probe token never reached the
  # model's context, which is consistent with the field rendering to the
  # terminal and is not evidence either way. Nothing in this design depends on
  # it being delivered, and no test may claim it is.
  printf '{"contextGuard":{"windowTokens":200000}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 300000 300000 300000 300000 300000)"
  run_hook "$t" hedge
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("systemMessage")'
  echo "$output" | jq -e '.systemMessage | test("delivery-kit:setup")'
}

@test "no systemMessage when the window is not provably wrong" {
  # The hedge rides the misconfiguration note. An ordinary firing must stay the
  # shape 1.0.x emitted, so a consumer that only knows {decision, reason} sees
  # nothing new on the common path.
  printf '{"contextGuard":{"windowTokens":200000}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t" nohedge
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("systemMessage") | not'
  echo "$output" | jq -e 'has("decision")'
}

@test "the hedge and the deferred hint ride the once-per-session note" {
  # Both are assigned INSIDE the wflag gate, and nothing else here can see that.
  # Move them out and they attach to EVERY over-window firing rather than the
  # first: systemMessage on every emission and the deferred hint repeated in
  # every reason, with the whole suite still green. The neighbouring test "says
  # it only once per session" does not cover it — that one watches the WINDOW
  # MISCONFIGURED text, which stays inside the gate under exactly that mistake.
  # A property that is load-bearing, one line away from breaking and invisible
  # to the suite earns a test of its own even while it is correct.
  #
  # The second firing MUST land in a different bucket, and that is the whole
  # reason for the second fixture. 300000 of 200000 is 150% -> bucket 30; 320000
  # is 160% -> bucket 32. Re-running the FIRST fixture would be suppressed by
  # the bucket gate before the wflag path was ever reached, so the test would
  # fail spuriously with its subject never having run. The higher bucket is what
  # lets the test EXERCISE the thing it is about. Climbing context is also the
  # honest scenario: a session over its configured window keeps growing.
  #
  # It is NOT there to stop a silent pass, and an earlier version of this comment
  # claimed it was — that the assertions below would "pass against an empty
  # emission". False, and disproved by running it: with the same bucket the test
  # FAILS, at status 4. The mechanism is `jq -e`, which exits 0 when the last
  # output is neither false nor null, 1 when it is false or null, and 4 when no
  # value is produced at all. Empty input yields no value, so every assertion
  # below — the negatives included — already fails against silence. Stated here
  # so the next reader does not re-derive it: a negated `jq -e` is not vacuous
  # on empty input, because 4 is not 0.
  printf '{"contextGuard":{"windowTokens":200000}}\n' > "$TEST_DIR/.delivery-kit.json"
  t="$(transcript_with 300000 300000 300000 300000 300000)"   # 150% -> bucket 30
  run_hook "$t" hedge-once
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("systemMessage")'
  echo "$output" | jq -e '.reason | test("After the handoff, run delivery-kit:setup")'

  t="$(transcript_with 320000 320000 320000 320000 320000)"   # 160% -> bucket 32
  run_hook "$t" hedge-once
  [ "$status" -eq 0 ]
  # It still fires — the guard has not gone quiet, it has stopped repeating
  # itself. That is the positive half of this test's subject, so it is asserted
  # rather than left to be inferred from the two negatives below. It is not
  # vacuity insurance: per the `jq -e` note above, those negatives exit 4 and
  # fail on their own against an empty emission.
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e 'has("systemMessage") | not'
  echo "$output" | jq -e '.reason | test("After the handoff, run delivery-kit:setup") | not'
}

@test "reports a broken or missing jq once, then stays quiet" {
  mkdir -p "$TEST_DIR/bin"
  printf '#!/usr/bin/env bash\nexit 127\n' > "$TEST_DIR/bin/jq"
  chmod +x "$TEST_DIR/bin/jq"

  t="$(transcript_with 90000 90000 90000 90000 90000)"
  payload="$(hook_input "$t")"     # built before jq is shadowed

  run bash -c 'PATH="$1:$PATH"; exec bash "$2"' _ "$TEST_DIR/bin" "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
  [[ "$output" == *"jq"* ]]
  [[ "$output" == *"delivery-kit"* ]]
  echo "$output" | jq -e '.systemMessage | test("jq")'
  # Pin where the flag lives. Without this, a rename or a move to a different
  # directory would still pass — both calls would simply agree — and the
  # global-not-per-session contract is the whole reason this flag is shaped
  # the way it is.
  [ -f "$TMPDIR/dk-jq-hint" ]

  run bash -c 'PATH="$1:$PATH"; exec bash "$2"' _ "$TEST_DIR/bin" "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the setup skill's merge expression preserves keys it does not know" {
  # The expression is EXTRACTED FROM THE SHIPPED SKILL, never copied into this
  # file. A copy would pin a property of jq's `*` operator — true on any machine
  # with jq installed, with or without this repository — and would stay green
  # with skills/setup/SKILL.md deleted outright. Extracting makes the shipped
  # artifact the thing under test.
  #
  # Both halves verified by mutation rather than asserted. Delete that file and
  # this test alone goes red, at the emptiness check below; the other 58 stay
  # green — including `every SKILL.md has name and description frontmatter`,
  # which skills/handoff/SKILL.md satisfies on its own, so it cannot notice this
  # skill's absence. Change the skill's expression to the naive `.[1]`, leaving
  # the file otherwise intact, and this test fails on the first assertion below
  # while all thirteen portability tests stay green — that mutation is invisible
  # to every scan in the suite, which is what makes this test the only thing
  # standing between the shipped skill and a config-eating overwrite.
  #
  # ~/.delivery-kit.json may already hold handoff.docsDir, contextGuard.maxBytes
  # or keys added by a later version this skill knows nothing about. Writing a
  # fresh object would silently delete them — a data-loss defect in a file the
  # user is unlikely to be watching, caused by the component whose whole
  # purpose is to be helpful. The "unknown keys are ignored, never rejected"
  # promise in docs/configuration.md cuts both ways: the hook must tolerate
  # keys it does not know, and so must this.
  #
  # `jq -s ` is what distinguishes the merge from the skill's two measurement
  # invocations, `jq -Rr ` and `jq -rs `, which this must not pick up.
  # `|| true` is load-bearing, not defensive habit. bats runs tests under
  # `set -e`, so a grep that matches nothing aborts the assignment itself and
  # the check below never executes — verified by running it: the guard was
  # unreachable before this was added, which made it decoration. With it, a
  # missing file and a file carrying no merge expression both arrive at the
  # check and fail there, naming the skill and what was expected in it.
  found="$(grep -oE "jq -s '[^']*'" "$REPO/skills/setup/SKILL.md" || true)"
  # An empty $merge reaching jq gives "Top-level program not given" at status 3
  # — a compile error naming neither this repository nor the skill. Fail here
  # instead, where the message can say which file was supposed to hold what.
  [ -n "$found" ] || { echo "no 'jq -s' merge expression in skills/setup/SKILL.md"; false; }
  # Exactly one. A second `jq -s` added to the skill later would otherwise leave
  # this test pinning whichever happened to come first in the file.
  n="$(printf '%s\n' "$found" | grep -c .)"
  [ "$n" -eq 1 ] || { echo "expected one merge expression, found $n:"; echo "$found"; false; }
  # The delimiters go through variables rather than being written inline with a
  # backslash-escaped quote. `macos-latest` is in the CI matrix and runs bash
  # 3.2, which nothing here can exercise locally, so the extraction is kept to
  # the plainest POSIX form available — a quoted variable in the expansion,
  # where there is no escaping left to be read differently by an older shell.
  prefix="jq -s '"
  suffix="'"
  merge="${found#"$prefix"}"
  merge="${merge%"$suffix"}"

  printf '{"handoff":{"docsDir":"docs/ho"},"contextGuard":{"maxBytes":4000000},"futureKey":{"a":1}}\n' \
    > "$TEST_DIR/existing.json"
  printf '{"contextGuard":{"windowTokens":1000000,"thresholdTokens":400000}}\n' \
    > "$TEST_DIR/patch.json"

  run jq -s "$merge" "$TEST_DIR/existing.json" "$TEST_DIR/patch.json"
  [ "$status" -eq 0 ]

  echo "$output" | jq -e '.handoff.docsDir == "docs/ho"'
  echo "$output" | jq -e '.contextGuard.maxBytes == 4000000'
  echo "$output" | jq -e '.futureKey.a == 1'
  echo "$output" | jq -e '.contextGuard.windowTokens == 1000000'
  echo "$output" | jq -e '.contextGuard.thresholdTokens == 400000'
}

@test "the setup skill's shadow check names every environment variable that overrides it" {
  # EXTRACTED FROM THE SHIPPED SKILL, never copied into this file — the same
  # discipline the merge test above sets out. A copy would pin a property of
  # `printenv`, true on any machine with a shell, and would stay green with the
  # check deleted from skills/setup/SKILL.md outright.
  #
  # Issue #6. `DELIVERY_KIT_*` overrides BOTH configuration files
  # (hooks/context-guard.sh:138-141), but the skill's shadow check read only the
  # repository file. So setup wrote ~/.delivery-kit.json, reported success, and
  # the exported variable went on winning — the identical "reported success,
  # nothing changed" outcome that the repository-file branch of the very same
  # check already exists to prevent.
  snippet="$TEST_DIR/envcheck.sh"
  sed -n '/^for v in DELIVERY_KIT_/,/^done$/p' "$REPO/skills/setup/SKILL.md" > "$snippet"
  [ -s "$snippet" ] || { echo "no DELIVERY_KIT_ environment check in skills/setup/SKILL.md"; false; }
  # Exactly one. A second loop added to the skill later would otherwise leave
  # this test pinning whichever of them came first in the file.
  n="$(grep -c '^for v in DELIVERY_KIT_' "$snippet")"
  [ "$n" -eq 1 ] || { echo "expected one environment check, found $n"; false; }

  # Every variable the hook actually honours, exported ONE AT A TIME. Exporting
  # all four together would pass even if the loop covered only the first, which
  # is the exact shape of partial coverage this issue was filed about.
  for v in DELIVERY_KIT_WINDOW_TOKENS DELIVERY_KIT_THRESHOLD_PCT \
           DELIVERY_KIT_THRESHOLD_TOKENS DELIVERY_KIT_MAX_BYTES; do
    run env "$v=987654" bash "$snippet"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "$v" || { echo "$v is not reported by the shadow check"; false; }
    # The VALUE, not merely the name. "Something is set" sends the user hunting
    # for it; the repository-file branch of this check gives the value it is
    # imposing, and this half has no reason to give less.
    echo "$output" | grep -q '987654' || { echo "$v reported without its value"; false; }
  done
}

@test "the setup skill's shadow check stays quiet when no environment variable is set" {
  # The other direction, and it is what makes the test above mean anything. A
  # check that printed all four names unconditionally would satisfy every
  # assertion up there while telling the user nothing true — the inert-guard
  # shape this project has now caught in itself repeatedly.
  snippet="$TEST_DIR/envcheck.sh"
  sed -n '/^for v in DELIVERY_KIT_/,/^done$/p' "$REPO/skills/setup/SKILL.md" > "$snippet"
  [ -s "$snippet" ] || { echo "no DELIVERY_KIT_ environment check in skills/setup/SKILL.md"; false; }
  # helper.bash unsets all four in setup(), so this is the clean case.
  run bash "$snippet"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the hook and the setup skill measure context by one identical rule" {
  # Issue #7. The measurement is written TWICE — hooks/context-guard.sh holds it
  # as READINGS_JQ, skills/setup/SKILL.md holds it inline — and nothing coupled
  # them. Editing either one left all 62 other tests green. That matters because
  # the skill's whole claim is that it measures "the same way the guard does":
  # the window it recommends is only meaningful while that stays true, and when
  # it stops being true nothing anywhere says so.
  #
  # Three quantities are pinned, because all three are duplicated: the jq
  # program, the `tail -n` line budget, and the median program. Each is verified
  # by MUTATION, not asserted — edit any one of the six sites alone and this
  # test alone goes red.
  SKILL="$REPO/skills/setup/SKILL.md"
  q="'"

  # --- 1. the reading program.
  # The sed range ends at the next line carrying a quote, which is the closing
  # delimiter: the four interior lines of the program contain no apostrophe.
  # Delimiters are then stripped with parameter expansion rather than another
  # sed script, so that no quote has to be escaped through a second layer —
  # macos-latest runs bash 3.2 and nothing here can exercise it locally.
  hook_block="$(sed -n "/^READINGS_JQ=/,/$q/p" "$HOOK" || true)"
  skill_block="$(sed -n "/jq -Rr ${q}fromjson?/,/$q/p" "$SKILL" || true)"
  [ -n "$hook_block" ] || { echo "no READINGS_JQ in hooks/context-guard.sh"; false; }
  [ -n "$skill_block" ] || { echo "no 'jq -Rr' reading program in skills/setup/SKILL.md"; false; }

  hook_prog="${hook_block#*$q}";   hook_prog="${hook_prog%$q*}"
  skill_prog="${skill_block#*$q}"; skill_prog="${skill_prog%$q*}"

  # Two empty strings compare equal. Without this, a mis-aimed extraction — a
  # renamed variable, a reflowed fence — would report agreement about nothing at
  # all, which is the fail-silent shape this suite has now caught in itself four
  # times. Anchor on a token that must survive any honest edit.
  case "$hook_prog" in *isSidechain*) ;; *) echo "extraction missed the hook's program:"; echo "$hook_prog"; false ;; esac
  case "$skill_prog" in *isSidechain*) ;; *) echo "extraction missed the skill's program:"; echo "$skill_prog"; false ;; esac

  if [ "$hook_prog" != "$skill_prog" ]; then
    echo "the reading program has drifted between the hook and the setup skill"
    echo "--- hooks/context-guard.sh"; echo "$hook_prog"
    echo "--- skills/setup/SKILL.md";  echo "$skill_prog"
    false
  fi

  # --- 2. the line budget. The hook spends it at TWO sites (the common path and
  # the starved path) and the skill at one, so this also catches the hook's own
  # two copies drifting apart — which no test covered either.
  # The trailing `[|"]` is load-bearing: it requires a real invocation, where
  # the next token is either a pipe or the quoted path being read. Without it
  # this also matched `tail -n 300` inside the hook's comment explaining the
  # 2026-08-07 incident, and the test reported a drift between a live budget and
  # a historical one named in prose. Caught by running it, not by reading it.
  budgets="$(grep -ohE 'tail -n [0-9]+ [|"]' "$HOOK" "$SKILL" | awk '{print $3}' || true)"
  count="$(printf '%s\n' "$budgets" | grep -c . || true)"
  [ "$count" -ge 3 ] || { echo "expected at least 3 'tail -n' sites, found $count"; false; }
  distinct="$(printf '%s\n' "$budgets" | sort -u | grep -c . || true)"
  [ "$distinct" -eq 1 ] || {
    echo "the line budget disagrees across $count sites:"; printf '%s\n' "$budgets" | sort -u; false; }

  # --- 3. the median program. Same line in both files, and the one that decides
  # which reading is believed; 1.0.2 already had to widen it once.
  medians="$(grep -ohE "jq -rs ${q}[^${q}]*${q}" "$HOOK" "$SKILL" || true)"
  count="$(printf '%s\n' "$medians" | grep -c . || true)"
  [ "$count" -ge 2 ] || { echo "expected the median program in both files, found $count"; false; }
  distinct="$(printf '%s\n' "$medians" | sort -u | grep -c . || true)"
  [ "$distinct" -eq 1 ] || {
    echo "the median program disagrees:"; printf '%s\n' "$medians" | sort -u; false; }
}
