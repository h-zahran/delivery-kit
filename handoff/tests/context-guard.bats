#!/usr/bin/env bats

load ../../tests/helper

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
  echo "$output" | jq -e '.reason | test("handoff:handoff")'
  echo "$output" | jq -e '.reason | test("at 45% of")'
  echo "$output" | jq -e '.reason | test("200000-token")'
  echo "$output" | jq -e '.reason | test("threshold 45%")'
}

@test "one inflated entry among five does not fire the guard (2026-08-07 regression)" {
  # Four honest entries at 24% and one most-recent request that re-sent the
  # full raw history. Reading the last entry fires the guard at 450%; the
  # median — a 15-reading window since 1.0.2, here all five entries — must
  # leave it silent.
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
  # The tail is a budget in lines; the median needs its readings window — 15
  # wide since 1.0.2. Sidechain
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
  # timeout, which test "every shipped hook timeout leaves headroom over the
  # measured worst case" pins separately. A cap that changed the answer would
  # instead misreport context, which is the failure this whole file exists to
  # prevent.
  t="$(transcript_with 10000 20000 30000 40000 50000)"
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":100000,"thresholdPct":1}'

  # Uncapped the median of the five is 30000, so every cap must report 30%.
  for lines in 1 3 5; do
    # TWO STATEMENTS ON PURPOSE — do not collapse this back into
    # `export DELIVERY_KIT_MAX_BYTES="$(bytes_of ...)"`. Measured: `export
    # V="$(f)"` reports export's OWN status, so a failing substitution is
    # masked and the test carries on with an empty cap; a plain assignment
    # aborts under the errexit bats applies. Collapsing it re-disarms exactly
    # the failure bytes_of was rebuilt to produce.
    cap="$(bytes_of "$t" "$lines")"
    export DELIVERY_KIT_MAX_BYTES="$cap"
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
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":100000,"thresholdPct":1}'
  # Two statements on purpose; see the note at the first such site.
  cap="$(bytes_of "$t" 1)"
  export DELIVERY_KIT_MAX_BYTES="$cap"

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
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":100000,"thresholdPct":1}'
  # Two statements on purpose; see the note at the first such site.
  cap="$(bytes_of "$t" 8)"
  export DELIVERY_KIT_MAX_BYTES="$cap"

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
  write_config "$TEST_DIR/.delivery-kit.json" '{"thresholdPct":10}'
  t="$(transcript_with 30000 30000 30000 30000 30000)"   # 15% of 200000
  run_hook "$t"
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("threshold 10%")'
}

@test "reads windowTokens from .delivery-kit.json" {
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":1000000}'
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
  cap="$(bytes_of "$t" 1)"
  write_config "$TEST_DIR/.delivery-kit.json" "$(printf '{"windowTokens":100000,"thresholdPct":1,"maxBytes":%s}' "$cap")"

  run_hook "$t" cfgcap
  [ "$status" -eq 0 ]
  [[ "$output" == *"48% of the 100000-token window"* ]]
  [[ "$output" == *"threshold 1%"* ]]
  [[ "$output" != *"900%"* ]]
}

@test "an environment variable overrides the config file" {
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":1000000}'
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
  write_config "$HOME/.delivery-kit.json" '{"windowTokens":1000000}'
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
  write_config "$HOME/.delivery-kit.json" '{"windowTokens":1000000,"thresholdPct":20}'
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":300000}'
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
  write_config "$HOME/.delivery-kit.json" '{"windowTokens":1000000,"thresholdPct":20}'
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":500000}'
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
  write_config "$HOME/.delivery-kit.json" '{"windowTokens":0,"thresholdPct":20}'
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
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":"08"}'
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
  write_config "$TEST_DIR/.delivery-kit.json" '{"thresholdPct":1}'
  t="$(transcript_with 6000 6000 6000 6000 6000)"   # 3% of 200000 -> bucket 0
  run_hook "$t" low-threshold
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 3% of")'
}

@test "a threshold far above 100 is rejected rather than silencing the guard" {
  # 450 is a plausible typo for 45. It is valid JSON and a valid positive
  # integer, so nothing else rejects it — and a threshold that can never be
  # reached means the guard never fires again. Nothing downstream can catch
  # this: the window-misconfiguration report added in Task 6 runs only after
  # the guard has already decided to fire.
  write_config "$TEST_DIR/.delivery-kit.json" '{"thresholdPct":450}'
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.reason | test("threshold 45%")'
}

@test "a threshold of exactly 100 is rejected, the first refused value" {
  # The boundary itself, on the dangerous side. The test above exercises 450,
  # which is obviously wrong; 100 is the value that looks reasonable and is not.
  # A percentage only reaches 100 once context has already filled the window, so
  # a guard set to 100 cannot warn while there is still room to act on the
  # warning — the exact property the comment above is_valid_threshold forbids.
  # Nothing downstream catches it either: the window-misconfiguration report
  # rides an emission that, in this configuration, never happens.
  #
  # MEASURED 2026-09-04 against the hook as it stood BEFORE this rule: with this
  # exact configuration the guard emitted NOTHING AT ALL at half the window.
  # This test is the change-prover for that reason — it moves the guard from
  # silent to speaking — and it was run and seen RED before the comparison in
  # is_valid_threshold was changed. A green here on an unchanged hook would mean
  # the test is not exercising the defect.
  # THE USER-LEVEL THRESHOLD IS UNCONTESTED, AND THAT IS THE POINT — the same
  # reasoning as "the environment overrides both files" above. Assert only
  # `threshold 45%` and this test survives the deletion of the configuration
  # layer entirely, because 45 is also the shipped default. Measured 2026-09-04:
  # with both read_config calls commented out, the original form of this test
  # stayed GREEN at 250% of a default window, still printing "threshold 45%".
  #
  # 30 can only have come from the user file, and the 1000000-token window can
  # only have come from the repository file, so the two assertions together say
  # exactly what this test means: both layers WERE read, the repository's 100
  # was refused, and the previously resolved value stood. That last clause is
  # also the first coverage of a refusal falling back to a user-level value
  # rather than to the default.
  write_config "$HOME/.delivery-kit.json" '{"thresholdPct":30}'
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":1000000,"thresholdPct":100}'
  t="$(transcript_with 500000 500000 500000 500000 500000)"   # 50% of the window
  run_hook "$t" pct100
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("of the 1000000-token window")'
  echo "$output" | jq -e '.reason | test("threshold 30%")'
}

@test "a threshold of 99 is accepted, the last admissible value" {
  # The other side of the boundary, and a REGRESSION PIN rather than a proof of
  # the change: 99 was accepted before the rule moved and is accepted after, so
  # this test passes on both sides and CANNOT be shown red by the change itself.
  # Claiming otherwise would be fabricated evidence. Its control is a deliberate
  # mutation of the comparison to `-lt 99`, which must turn this red — run that
  # mutation, confirm it landed, and do not assume either half.
  #
  # The assertion names the exact threshold rather than merely checking that
  # something fired: were 99 refused, the value would fall back to the default
  # and the message would read "threshold 45%". So this discriminates on the
  # value, not on the firing.
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":1000000,"thresholdPct":99}'
  t="$(transcript_with 995000 995000 995000 995000 995000)"   # 99% by integer division
  run_hook "$t" pct99
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("threshold 99%")'
}

@test "fires on thresholdTokens with no valid window configured" {
  # The point of the absolute tripwire: it is decidable from the transcript
  # alone, so a windowTokens that is wrong — or, here, invalid and discarded —
  # cannot silence it.
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":0,"thresholdTokens":400000}'
  t="$(transcript_with 405000 405000 405000 405000 405000)"
  run_hook "$t" abswins
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("405000 tokens, past the 400000-token limit")'
}

@test "the absolute tripwire fires with the relative one unreachable" {
  # Proving the OR rather than assuming it: a threshold of 99% is not reachable
  # by this transcript, which sits at 40%, so only the absolute tripwire can be
  # responsible for the emission.
  #
  # THIS TEST USED TO SAY 100, AND THAT IS THE INTERESTING PART. When
  # is_valid_threshold began refusing 100, the value here became invalid and
  # fell back to the default 45 — and 40% is under 45% too, so the assertion
  # went on passing while the sentence above it had become false. A green test
  # explaining itself with a mechanism that no longer exists is precisely the
  # silence this hook is written to prevent, so the value is now 99: the
  # highest the validator admits, which makes "not reachable" true again and
  # keeps this test's meaning independent of what the default happens to be.
  #
  # Do not try to prove this comment load-bearing by putting 100 back. Measured
  # 2026-09-04: it cannot go red, for the reason just given. The change itself
  # is proved by the boundary tests above, which move the guard from silent to
  # speaking.
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":1000000,"thresholdPct":99,"thresholdTokens":400000}'
  t="$(transcript_with 405000 405000 405000 405000 405000)"
  run_hook "$t" absonly
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("past the 400000-token limit")'
}

@test "the relative tripwire fires with the absolute one unreachable" {
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":1000000,"thresholdPct":45,"thresholdTokens":900000}'
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
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":1000000,"thresholdPct":45,"thresholdTokens":400000}'
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
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":200000,"thresholdPct":45}'
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t" unsetabs
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 45% of the 200000-token window \\(threshold 45%\\)")'
}

@test "an invalid thresholdTokens leaves the guard armed on the relative rule" {
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":200000,"thresholdPct":45,"thresholdTokens":"08"}'
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
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":200000}'
  t="$(transcript_with 300000 300000 300000 300000 300000)"
  run_hook "$t" deferred
  [ "$status" -eq 0 ]
  reason="$(echo "$output" | jq -r '.reason')"
  handoff_at="$(awk '{print index($0, "print the resume prompt for the user, and stop.")}' <<< "$reason")"
  setup_at="$(awk '{print index($0, "After the handoff, run handoff:setup")}' <<< "$reason")"
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
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":200000}'
  t="$(transcript_with 300000 300000 300000 300000 300000)"
  run_hook "$t" hedge
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("systemMessage")'
  echo "$output" | jq -e '.systemMessage | test("handoff:setup")'
}

@test "systemMessage rides every firing, not only the misconfiguration note" {
  # Issue #2, and this test REPLACES one that asserted the opposite. That is a
  # deliberate contract change, so the reasoning is recorded rather than left in
  # a commit message.
  #
  # The old contract kept the common path shaped exactly as 1.0.x emitted it —
  # {decision, reason} and nothing more — on the grounds that `systemMessage`
  # was an unverified hedge that might render nowhere. That reasoning was sound
  # while it held. It no longer holds.
  #
  # MEASURED 2026-08-18, with the user watching their own terminal: a firing
  # carrying both fields rendered the reason as `PostToolUse:Bash hook returned
  # blocking error ...` AND the systemMessage as a separate `PostToolUse:Bash
  # says: handoff: ...` line. Both arrived. The documented channel works
  # even with a decision present.
  #
  # That matters because the ENTIRE payload otherwise travels `decision`, which
  # the hooks reference states PostToolUse does not have. If that path is ever
  # withdrawn the guard would emit into a void, silently — the exact failure
  # this project exists to prevent, sitting underneath the project itself. So
  # the warning now also goes out on the channel that is documented AND
  # observed, on every firing rather than only the rare misconfigured one.
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":200000}'
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t" nohedge
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("decision")'
  # PRESENT, and carrying the substance — not merely present. A field holding
  # an empty string would satisfy `has()` while telling the user nothing, and
  # asserting only `has()` is how a guard becomes decoration.
  echo "$output" | jq -e 'has("systemMessage")'
  # The label is the speaker. 1.3.0 shipped a message that introduced itself
  # as the old plugin, and nothing pinned the prefix then or after the rename —
  # the suite pinned the advice but not the voice. A second plugin printing
  # its own skill names reopens exactly this class.
  echo "$output" | jq -e '.systemMessage | test("^handoff: ")'
  echo "$output" | jq -e '.systemMessage | test("45%")'
  echo "$output" | jq -e '.systemMessage | test("handoff:handoff")'
  # The misconfiguration sentence must NOT be here: the window is fine. That
  # half still rides the once-per-session gate.
  echo "$output" | jq -e '.systemMessage | test("handoff:setup") | not'
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
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":200000}'
  t="$(transcript_with 300000 300000 300000 300000 300000)"   # 150% -> bucket 30
  run_hook "$t" hedge-once
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("systemMessage")'
  echo "$output" | jq -e '.reason | test("After the handoff, run handoff:setup")'

  t="$(transcript_with 320000 320000 320000 320000 320000)"   # 160% -> bucket 32
  run_hook "$t" hedge-once
  [ "$status" -eq 0 ]
  # It still fires — the guard has not gone quiet, it has stopped repeating
  # itself. That is the positive half of this test's subject, so it is asserted
  # rather than left to be inferred from the two negatives below. It is not
  # vacuity insurance: per the `jq -e` note above, those negatives exit 4 and
  # fail on their own against an empty emission.
  echo "$output" | jq -e '.decision == "block"'
  # systemMessage is now on EVERY firing (issue #2), so its mere presence no
  # longer distinguishes the first over-window emission from the repeats. What
  # still rides the once-per-session gate is the SETUP SENTENCE inside it — so
  # that is what this asserts, and it is the assertion that keeps this test
  # about its actual subject.
  echo "$output" | jq -e 'has("systemMessage")'
  echo "$output" | jq -e '.systemMessage | test("handoff:setup") | not'
  echo "$output" | jq -e '.reason | test("After the handoff, run handoff:setup") | not'
}

@test "reports a broken or missing jq once, then stays quiet" {
  mkdir -p "$TEST_DIR/bin"
  printf '#!/usr/bin/env bash\nexit 127\n' > "$TEST_DIR/bin/jq"
  chmod +x "$TEST_DIR/bin/jq"

  t="$(transcript_with 90000 90000 90000 90000 90000)"
  payload="$(hook_input "$t")"     # built before jq is shadowed

  run bash -c 'PATH="$1:$PATH"; exec bash "$2"' _ "$TEST_DIR/bin" "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
  # Field-level, not substring-over-$output: `run` folds stderr into $output
  # and the hook's own path contains "handoff/", so the old substring checks
  # could be satisfied by noise plus exit 0. Parsing the emission means stray
  # stderr breaks the parse and reddens here — the tightening is the point.
  echo "$output" | jq -e '.systemMessage | test("^handoff: ")'
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
  # with handoff/skills/setup/SKILL.md deleted outright. Extracting makes the
  # shipped artifact the thing under test.
  #
  # Both halves verified by mutation rather than asserted. Delete that file and
  # this test alone goes red, at the emptiness check below; every other test in
  # the suite stays green — including `every SKILL.md has name and description
  # frontmatter`, which handoff/skills/handoff/SKILL.md satisfies on its own, so
  # it cannot notice this skill's absence. Change the skill's expression to the
  # naive `.[1]`, leaving the file otherwise intact, and this test fails on the
  # first assertion below while every portability test stays green — that
  # mutation is invisible to every scan in the suite, which is what makes this
  # test the only thing standing between the shipped skill and a config-eating
  # overwrite.
  #
  # ~/.delivery-kit.json may already hold handoff.docsDir, contextGuard.maxBytes
  # or keys added by a later version this skill knows nothing about. Writing a
  # fresh object would silently delete them — a data-loss defect in a file the
  # user is unlikely to be watching, caused by the component whose whole
  # purpose is to be helpful. The "unknown keys are ignored, never rejected"
  # promise in handoff/docs/configuration.md cuts both ways: the hook must tolerate
  # keys it does not know, and so must this.
  #
  # `jq -s ` is what distinguishes the merge from the skill's measurement
  # invocation, `jq -Rrn `, which this must not pick up. There were two of those
  # until the reading and the median came from one pass.
  # `|| true` is load-bearing, not defensive habit. bats runs tests under
  # `set -e`, so a grep that matches nothing aborts the assignment itself and
  # the check below never executes — verified by running it: the guard was
  # unreachable before this was added, which made it decoration. With it, a
  # missing file and a file carrying no merge expression both arrive at the
  # check and fail there, naming the skill and what was expected in it.
  found="$(grep -oE "jq -s '[^']*'" "$HANDOFF/skills/setup/SKILL.md" || true)"
  # An empty $merge reaching jq gives "Top-level program not given" at status 3
  # — a compile error naming neither this repository nor the skill. Fail here
  # instead, where the message can say which file was supposed to hold what.
  [ -n "$found" ] || { echo "no 'jq -s' merge expression in handoff/skills/setup/SKILL.md"; false; }
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

@test "the guard stays silent inside a subagent" {
  # Issue #5, and the mechanism is MEASURED rather than assumed. A PostToolUse
  # hook running inside a subagent is handed the PARENT's transcript_path and
  # the PARENT's session_id — captured live on 2026-08-18 by logging the hook's
  # stdin and driving one throwaway subagent. Both of its tool calls arrived
  # carrying the parent session's transcript, identical to the seven main-chain
  # calls around them.
  #
  # Two consequences, and the second is the serious one:
  #   1. The percentage reported inside a fresh subagent is the PARENT's. The
  #      subagent's own context is near zero and is never consulted.
  #   2. `session_id` is the parent's too, so the once-per-bucket flag is SHARED.
  #      A subagent's firing marks the bucket and can suppress a warning the
  #      parent was owed — a missing warning, which is this project's worst
  #      failure mode, not a cosmetic misreport.
  #
  # Silence is the fix rather than "measure the subagent instead", because the
  # payload does not carry the subagent's own transcript path — there is nothing
  # to measure. And the advice would be wrong anyway: a subagent cannot hand off.
  #
  # The discriminator is `agent_id`, present in the payload only inside a
  # subagent (also observed: `agent_type`). Keyed on its PRESENCE deliberately.
  # If a future Claude Code renames the field this check goes inert and the guard
  # returns to today's behaviour — noisy in subagents. The opposite polarity, a
  # field whose absence silenced the guard, would fail toward silence in the MAIN
  # session, and that is the one direction this project must never fail in.
  t="$(transcript_with 90000 90000 90000 90000 90000)"   # 45% of 200000
  payload="$(jq -nc --arg t "$t" --arg s "test-session" --arg c "$TEST_DIR" \
    '{transcript_path:$t, session_id:$s, cwd:$c,
      agent_id:"a7c685b676863456f", agent_type:"general-purpose"}')"
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the identical payload without agent_id still fires" {
  # The positive control for the test above, and it is what makes that test mean
  # anything. Same transcript, same session, same cwd — only `agent_id` removed.
  # Without this, a fixture broken in any way at all would produce the silence
  # that test asserts and pass for entirely the wrong reason.
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  payload="$(jq -nc --arg t "$t" --arg s "test-session" --arg c "$TEST_DIR" \
    '{transcript_path:$t, session_id:$s, cwd:$c}')"
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 45% of")'
}

@test "the setup skill's shadow check names every environment variable that overrides it" {
  # EXTRACTED FROM THE SHIPPED SKILL, never copied into this file — the same
  # discipline the merge test above sets out. A copy would pin a property of
  # `printenv`, true on any machine with a shell, and would stay green with the
  # check deleted from handoff/skills/setup/SKILL.md outright.
  #
  # Issue #6. `DELIVERY_KIT_*` overrides BOTH configuration files — the four
  # `DELIVERY_KIT_*` assignments in handoff/hooks/context-guard.sh run after
  # both `read_config` calls, so they win over whichever file set the value —
  # but the skill's shadow check read only the repository file. So setup wrote
  # ~/.delivery-kit.json, reported success, and the exported variable went on
  # winning — the identical "reported success, nothing changed" outcome that the
  # repository-file branch of the very same check already exists to prevent.
  snippet="$TEST_DIR/envcheck.sh"
  sed -n '/^for v in DELIVERY_KIT_/,/^done$/p' "$HANDOFF/skills/setup/SKILL.md" > "$snippet"
  [ -s "$snippet" ] || { echo "no DELIVERY_KIT_ environment check in handoff/skills/setup/SKILL.md"; false; }
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
  sed -n '/^for v in DELIVERY_KIT_/,/^done$/p' "$HANDOFF/skills/setup/SKILL.md" > "$snippet"
  [ -s "$snippet" ] || { echo "no DELIVERY_KIT_ environment check in handoff/skills/setup/SKILL.md"; false; }
  # helper.bash unsets all four in setup(), so this is the clean case.
  run bash "$snippet"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the hook and the setup skill measure context by one identical rule" {
  # Issue #7. The measurement is written TWICE — handoff/hooks/context-guard.sh
  # and handoff/skills/setup/SKILL.md each hold it as READINGS_JQ, and each
  # hold the median as MEDIAN_JQ — and nothing coupled them. The skill held
  # both inline until the guard stopped spending a separate process on the
  # median; naming them was what let one anchor find them in both files. Editing either one left every other test in the suite
  # green. That matters because the skill's whole claim is that it measures "the
  # same way the guard does": the window it recommends is only meaningful while
  # that stays true, and when it stops being true nothing anywhere says so.
  #
  # Three quantities are pinned, because all three are duplicated: the jq
  # program, the `tail -n` line budget, and the median program. Each is verified
  # by MUTATION, not asserted — edit any one of the SEVEN sites alone and this
  # test alone goes red. Seven, counted rather than remembered: two READINGS_JQ,
  # three `tail -n`, two MEDIAN_JQ. The number said six for as long as it was
  # wrong, which is the argument for counting it in the rig instead of here.
  # A fourth part below pins the skill's USE of the two it declares.
  #
  # Two of the three are matched through a named variable that exists in both
  # files for this test's benefit as much as for the code's. That is deliberate:
  # an anchor written against a call site pins the caller's shape as well as the
  # program, and this test has already once forbidden a change to the caller
  # that left both programs identical.
  SKILL="$HANDOFF/skills/setup/SKILL.md"
  q="'"

  # --- 1. the reading program.
  # The sed range ends at the next line carrying a quote, which is the closing
  # delimiter: the four interior lines of the program contain no apostrophe.
  # Delimiters are then stripped with parameter expansion rather than another
  # sed script, so that no quote has to be escaped through a second layer —
  # macos-latest runs bash 3.2 and nothing here can exercise it locally.
  #
  # ONE ANCHOR SERVES BOTH FILES NOW, and that is the point of the change that
  # brought it about. The skill's anchor used to be the literal text
  # `jq -Rr 'fromjson?`, which pinned the program's SPELLING AT ITS CALL SITE
  # rather than the program: the day the hook stopped piping one number per
  # line into a second jq, no edit to the skill could satisfy both this
  # extraction and the comparison below it. The rule is a named variable in
  # both files now, so the same anchor finds it in both and a rename in either
  # reddens the emptiness guard rather than passing quietly.
  hook_block="$(sed -n "/^READINGS_JQ=/,/$q/p" "$HOOK" || true)"
  skill_block="$(sed -n "/^READINGS_JQ=/,/$q/p" "$SKILL" || true)"
  [ -n "$hook_block" ] || { echo "no READINGS_JQ in handoff/hooks/context-guard.sh"; false; }
  [ -n "$skill_block" ] || { echo "no READINGS_JQ in handoff/skills/setup/SKILL.md"; false; }

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
    echo "--- handoff/hooks/context-guard.sh"; echo "$hook_prog"
    echo "--- handoff/skills/setup/SKILL.md";  echo "$skill_prog"
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
  #
  # It is matched as a NAMED VARIABLE, not as a `jq -rs` invocation. The older
  # pattern required the median to be spent as its own process in both files,
  # which is a fact about how many processes the hook starts and not about
  # which reading it believes. When the hook stopped spending that process —
  # the count and the median now come from one pass — the site count fell to
  # one and this part failed while the two files still agreed perfectly on the
  # rule. Measured: the differential reported every shape as expected on the
  # run that reddened this line. The coupling is unchanged and still pinned by
  # mutation; what moved is that the pin no longer also dictates the shape of
  # the caller.
  #
  # The `.*` after the assignment is load bearing in the same way the quoted
  # class was: it captures the program itself, so a drift INSIDE either
  # variable makes the two matches differ. A pattern matching only the
  # variable name would find two identical strings on any two files that
  # happened to declare it, and say nothing about what either one holds.
  medians="$(grep -ohE '^MEDIAN_JQ=.*' "$HOOK" "$SKILL" || true)"
  count="$(printf '%s\n' "$medians" | grep -c . || true)"
  [ "$count" -ge 2 ] || { echo "expected the median program in both files, found $count"; false; }
  distinct="$(printf '%s\n' "$medians" | sort -u | grep -c . || true)"
  [ "$distinct" -eq 1 ] || {
    echo "the median program disagrees:"; printf '%s\n' "$medians" | sort -u; false; }

  # --- 4. the skill USES the two programs it declares.
  #
  # Parts 1 and 3 above compare DECLARATIONS. That is a weaker thing than it
  # looks, and the weakness arrived with them: the skill's anchors used to BE
  # its call sites, so there was no declaration to drift from a use. Once both
  # anchors moved to `^NAME=`, a skill whose two declarations match the hook
  # byte for byte could invoke something else entirely and every part above
  # would pass.
  #
  # Measured, not reasoned: a SKILL.md with both declarations untouched and
  # the `jq -Rrn` line rewritten to inline a first-fifteen median with no
  # sidechain filter passed parts 1, 2 and 3 GREEN. Under the old call-site
  # anchor the same edit was RED. This part is what puts that back.
  #
  # The `?` is inside the match on purpose. It is load bearing in the skill
  # for the same reason it is load bearing in the hook: collecting the
  # readings into an array makes one unparseable line abort the whole program
  # and return nothing, where the streaming form it replaced reported that
  # line and carried on.
  use="$(grep -cF 'jq -Rrn "[ inputs | ( $READINGS_JQ )? ] | $MEDIAN_JQ"' "$SKILL" || true)"
  [ "$use" -eq 1 ] || {
    echo "handoff/skills/setup/SKILL.md must SPEND the two programs it declares,"
    echo "as: jq -Rrn \"[ inputs | ( \$READINGS_JQ )? ] | \$MEDIAN_JQ\""
    echo "found $use such invocations. A declaration the skill does not use"
    echo "makes parts 1 and 3 of this test compare two decorations."
    grep -n 'jq -Rrn' "$SKILL" || true
    false; }
}

@test "falls back to its own working directory when the payload carries none" {
  # FR-001. Claude Code always supplies cwd, so no test in this file has ever
  # reached the fallback — and the fallback is the line that runs on a real
  # machine the day that field is renamed, dropped, or arrives empty. It is
  # covered here for the same reason the subagent exit is: a path that only
  # real users take is the one a suite must not leave to inspection.
  #
  # The payload omits cwd and keeps a VALID transcript. That pairing is
  # load-bearing. Every payload in this file that omits cwd today also omits a
  # usable transcript, so it dies two steps earlier at the transcript gate and
  # never reaches the fallback at all — it would pass this test for the wrong
  # reason, which is the failure this test exists to close.
  #
  # FR-003, and why there is no separate assertion for it: a payload that died
  # at the gate exits silently. A warning therefore cannot be produced without
  # having passed the gate, read the working directory, resolved the fallback
  # and read the file beside it. The warning IS the proof that the
  # configuration step was reached. An extra assertion would not be stricter,
  # only redundant, and this paragraph is here to stop a later reader adding
  # one.
  #
  # The guard reads $PWD, which belongs to the PROCESS, so the runs below move
  # a CHILD shell into the directory under test. That rule now lives in
  # run_hook_from rather than in a comment at each call site — it was written
  # here once and copied to the repository-root test without it, and a third
  # copy would have carried neither.
  #
  # The rig is 30000 against a configured 50000 — 60%, which fires — while the
  # 200000-token DEFAULT reads the same transcript as 15% and stays silent.
  # That gap is what makes the control below mean anything: a reading that
  # fires on the defaults would warn from a directory holding nothing, and the
  # pair would prove only that the guard runs.
  t="$(transcript_with 30000 30000 30000 30000 30000)"

  mkdir -p "$TEST_DIR/beside"
  write_config "$TEST_DIR/beside/.delivery-kit.json" '{"windowTokens":50000}'
  run_hook_from "$TEST_DIR/beside" --no-cwd "$t" wdfallback
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  # Naming the configured window, not merely blocking: the number can only have
  # come from the file beside the process's own directory.
  echo "$output" | jq -e '.reason | test("at 60% of the 50000-token window")'

  # THE CONTROL. Same payload shape, same transcript, a directory holding no
  # configuration. Without it, "warned" above is satisfied by the guard finding
  # configuration anywhere at all. The status assertion is not decoration: a
  # failed `cd` in the child would also produce empty output, and silence for
  # that reason would fake this pass.
  mkdir -p "$TEST_DIR/bare"
  run_hook_from "$TEST_DIR/bare" --no-cwd "$t" wdcontrol
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "finds configuration at the repository root when the working directory is below it" {
  # FR-002. Claude Code's working directory is often a subdirectory of the
  # repository, so the guard asks git for the root when nothing sits beside the
  # working directory. Like the fallback above, this is a line every real user
  # exercises and no test in this file has ever run.
  #
  # TWO levels below the root, not one. One level is explainable by a plain
  # walk up to the parent, so a one-level test would stay green against an
  # implementation that never asked git at all. Two levels is the cheapest
  # depth that only a root query can answer.
  #
  # FR-003, and why there is no separate assertion for it: as in the test
  # above, a payload that died at the transcript gate exits silently. A warning
  # cannot be produced without having passed that gate and reached the
  # configuration step, so the warning IS that proof. Nothing further is needed
  # and a later reader should not add it.
  #
  # Same rig, same reason: 30000 reads as 60% under the configured 50000-token
  # window and 15% under the 200000-token default. A reading that fired on the
  # defaults would warn from anywhere and the control below would prove nothing.
  t="$(transcript_with 30000 30000 30000 30000 30000)"

  mkdir -p "$TEST_DIR/repo/sub/deeper"
  git -C "$TEST_DIR/repo" init -q
  write_config "$TEST_DIR/repo/.delivery-kit.json" '{"windowTokens":50000}'
  run_hook --cwd "$TEST_DIR/repo/sub/deeper" "$t" rootdisc
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  # The configured window in the message is the observable. Nothing beside the
  # working directory could have supplied it: the only copy is at the root.
  echo "$output" | jq -e '.reason | test("at 60% of the 50000-token window")'

  # THE CONTROL. The same shape two levels deep, with no repository anywhere
  # above it — the harness's own directory is a plain temporary tree, not a
  # checkout, so git has nothing to answer with. This is what shows the root
  # query did the work rather than some broader search: remove the repository
  # and the warning goes away.
  mkdir -p "$TEST_DIR/plain/sub/deeper"
  write_config "$TEST_DIR/plain/.delivery-kit.json" '{"windowTokens":50000}'
  # THE PRECONDITION IS ASSERTED, not assumed. This control means nothing if
  # the harness directory happens to sit inside a checkout, and it can: the
  # directory comes from mktemp against the ambient temp path, which a
  # developer may legitimately point at a repo-local scratch directory. Then
  # git DOES answer, the root query DOES run, and the silence below would come
  # from that root's configuration carrying no guard key rather than from the
  # query finding nothing — the control passing while proving the opposite.
  ! git -C "$TEST_DIR/plain" rev-parse --show-toplevel >/dev/null 2>&1
  run_hook --cwd "$TEST_DIR/plain/sub/deeper" "$t" norepo
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sweeps flag files older than seven days and keeps the fresh ones" {
  # FR-004. One flag file per session accumulates in the temp directory
  # forever, so the guard sweeps the old ones — and it does that on the rare
  # path that has just written a flag, which keeps the cost off every tool
  # call.
  #
  # THAT POSITION IS WHY THIS TEST DRIVES THE GUARD TO WARN. The sweep sits
  # AFTER the firing decision, not on every invocation. A test that aged a flag
  # and then ran the guard below every threshold would observe nothing, and
  # would then have to assert that nothing happened — passing for the wrong
  # reason, against a sweep that had never run at all.
  #
  # THE FIXTURE PINS THE BOUNDARY, and getting there took three attempts, each
  # corrected by measurement rather than argument:
  #
  #   one ancient + one fresh  — +0, +7 and +365 are indistinguishable.
  #   three days + eight days  — +3, +4, +5 and +6 all match +7, because a
  #                              three-day file survives every one of them.
  #   SEVEN-ish + EIGHT-ish    — only +7 keeps the first and takes the second.
  #
  # AND THE STAMPS ARE COMPUTED FROM EPOCH SECONDS, NOT WALL CLOCK. `date -d '8
  # days ago'` returns a local wall-clock stamp, so across a spring-forward the
  # file it stamps is 191 real hours old rather than 192 — and find floors 191h
  # to seven periods, while `-mtime +7` needs strictly more than seven. The file
  # would SURVIVE, and the assertion that it is gone would go red, for the eight
  # days after each transition on any machine whose zone observes DST. CI runs
  # in UTC and would never show it. Measured, not feared: a file stamped 191
  # hours back is not deleted by `-mtime +7`.
  #
  # Mid-band is the fix: 7.5 days (648000s) and 8.5 days (734400s). Measured to
  # discriminate identically — +6 takes both, +7 takes only the outer one, +8
  # takes neither — with twelve hours of slack against a one-hour shift either
  # way. Both dialects are covered: GNU takes -d @EPOCH, BSD takes -r EPOCH.
  now_s="$(date +%s)"
  inside="$(date -d "@$(( now_s - 648000 ))" +%Y%m%d%H%M 2>/dev/null || date -r "$(( now_s - 648000 ))" +%Y%m%d%H%M)"
  outside="$(date -d "@$(( now_s - 734400 ))" +%Y%m%d%H%M 2>/dev/null || date -r "$(( now_s - 734400 ))" +%Y%m%d%H%M)"
  now="$(date +%Y%m%d%H%M)"
  # ORDER, not length. A length check catches neither failure it would claim: a
  # stamp that came back empty aborts at the assignment under errexit before any
  # guard runs, and a date that ignored its offset returns twelve characters and
  # passes. These cannot both hold unless the offsets were applied.
  [ "$outside" \< "$inside" ]
  [ "$inside" \< "$now" ]

  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":100000}'

  # ALL THREE SWEPT NAME PATTERNS, on BOTH sides. The hook sweeps ctx-warned-*,
  # dk-window-warned-* and dk-jq-hint, and its own comment argues dk-jq-hint is
  # the one that HAS to be swept: it is global rather than per-session, so
  # nothing else would ever remove it, and a user who fixes jq and later loses
  # it again would get a silently dead guard and no second hint. Planting only
  # ctx-warned-* left the suite green with either of the other clauses deleted.
  printf '9\n' > "$TMPDIR/ctx-warned-ancient"
  printf '9\n' > "$TMPDIR/ctx-warned-just-outside"
  printf '9\n' > "$TMPDIR/ctx-warned-just-inside"
  printf '9\n' > "$TMPDIR/ctx-warned-recent"
  printf '9\n' > "$TMPDIR/dk-window-warned-ancient"
  printf '9\n' > "$TMPDIR/dk-window-warned-fresh"
  : > "$TMPDIR/dk-jq-hint"
  # An aged file no pattern names, and an aged DIRECTORY that one does: the
  # first shows the sweep is bounded by name rather than clearing whatever is
  # old, the second pins the -type f the hook comments on.
  printf '9\n' > "$TMPDIR/unrelated-ancient"
  mkdir -p "$TMPDIR/ctx-warned-adirectory"
  # And an aged flag one level DOWN, which pins -maxdepth 1. Without it the
  # sweep would walk into per-session subdirectories under the temp directory
  # and delete flags it was never meant to reach.
  mkdir -p "$TMPDIR/sub"
  printf '9\n' > "$TMPDIR/sub/ctx-warned-nested"
  touch -t 202001010000 "$TMPDIR/ctx-warned-ancient" "$TMPDIR/dk-window-warned-ancient" \
                        "$TMPDIR/dk-jq-hint" "$TMPDIR/unrelated-ancient" \
                        "$TMPDIR/ctx-warned-adirectory" "$TMPDIR/sub/ctx-warned-nested"
  touch -t "$outside" "$TMPDIR/ctx-warned-just-outside"
  touch -t "$inside" "$TMPDIR/ctx-warned-just-inside"

  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t" sweeper
  [ "$status" -eq 0 ]
  # Asserted before the files, so a failure says which half broke. Without the
  # emission the sweep never runs and every file assertion below would be
  # reporting on a guard that exited early.
  echo "$output" | jq -e '.decision == "block"'

  # Past the threshold: gone. All three name patterns.
  [ ! -f "$TMPDIR/ctx-warned-ancient" ]
  [ ! -f "$TMPDIR/ctx-warned-just-outside" ]
  [ ! -f "$TMPDIR/dk-window-warned-ancient" ]
  [ ! -f "$TMPDIR/dk-jq-hint" ]

  # Inside the threshold, or out of the sweep's reach: kept. Removal alone is
  # equally satisfied by anything that cleared the directory, so these are what
  # show the age filter, the name filter, the file-type filter and the depth
  # limit are the things that acted. The just-inside file is the one that pins
  # the number: -mtime +6 would take it.
  [ -f "$TMPDIR/ctx-warned-just-inside" ]
  [ -f "$TMPDIR/ctx-warned-recent" ]
  [ -f "$TMPDIR/dk-window-warned-fresh" ]
  [ -f "$TMPDIR/unrelated-ancient" ]
  [ -d "$TMPDIR/ctx-warned-adirectory" ]
  [ -f "$TMPDIR/sub/ctx-warned-nested" ]

  # THE GLOBAL HINT'S KEPT SIDE NEEDS A SECOND RUN, because dk-jq-hint is one
  # fixed filename: a single run can show it aged-and-removed or fresh-and-kept,
  # never both. Without this, moving it out of the -mtime group and deleting it
  # unconditionally would leave the suite green — and that would silently break
  # the once-per-outage contract the hook's comment describes.
  #
  # A HIGHER BUCKET is what makes the guard fire again: the once-per-bucket rule
  # suppresses a second warning at the same 5% step, and a run that does not
  # warn does not sweep. 90% is bucket 18; 99% is bucket 19.
  : > "$TMPDIR/dk-jq-hint"
  t2="$(transcript_with 99000 99000 99000 99000 99000)"
  run_hook "$t2" sweeper
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  [ -f "$TMPDIR/dk-jq-hint" ]
}

@test "a transcript that exists but yields no readings leaves the guard silent" {
  # FR-005. The transcript gate two steps earlier catches a missing or empty
  # path. This is the other shape: a file that EXISTS, is readable, and parses
  # to nothing the median can use — a plain-text line, and a message carrying no
  # usage block. Claude Code writes lines of both kinds, so an ingestion change
  # that started counting them would be reported by this test and by nothing
  # else in this file.
  #
  # THIS IS A SILENT SUCCESS, so exit status proves nothing on its own: the
  # guard exits 0 on almost every path it takes. The assertion that carries the
  # test is the EMPTY OUTPUT, and it only means something against a rig that
  # would otherwise have warned — which is why the contrast run below is part
  # of the test rather than a separate one.
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":100000}'

  t="$TEST_DIR/no-readings.jsonl"
  printf 'not JSON at all, just a line of text\n' > "$t"
  printf '{"message":{"role":"assistant","content":"no usage block here"}}\n' >> "$t"
  # THE PREMISE, ASSERTED. The `[ -f "$t" ]` this replaces could not fail: the
  # two redirections above create the file, and a failed redirection aborts
  # under errexit before any check runs. It read as a guard while guarding
  # nothing. What actually matters is that the file is NON-EMPTY and carries
  # no usable reading — which is what makes the silence below meaningful, and
  # which a fixture edit could genuinely break.
  [ -s "$t" ]
  ! grep -q 'input_tokens' "$t"
  run_hook "$t" noreadings
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  # THE CONTRAST. The same configuration, the same directory, the same helper —
  # only the transcript differs. It warns. So the silence above is the absence
  # of usable readings and not a rig that could never have fired.
  t2="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t2" wouldhavewarned
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
}

@test "a payload with no session identifier warns and files its flag under the placeholder" {
  # FR-006. The guard substitutes the literal placeholder when the payload
  # carries no session identifier. Nothing in this file has ever sent such a
  # payload, and the substitution is what keeps the once-per-bucket rule
  # working at all — without it the flag path would collapse to a bare prefix.
  #
  # THE FILENAME IS THE ASSERTION, and that choice is the whole point of this
  # test. Asserting only that the guard warned, or that it did not crash, is
  # nearly unfalsifiable: the guard warns on this rig whatever it puts in the
  # path. The flag file's NAME is the only externally visible proof that the
  # substitution happened, so it is what this test reads.
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":100000}'
  t="$(transcript_with 90000 90000 90000 90000 90000)"

  # --no-session, rather than a hand-rolled payload. The shared builder could
  # not express this shape when the test was written, which is why it was
  # hand-rolled; it can now, and the payload shape stays written down once.
  run_hook --no-session "$t"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  [ -f "$TMPDIR/ctx-warned-unknown" ]
}

@test "the proportional threshold setting decides whether the guard fires, and words itself as a percentage" {
  # FR-007, behaviourally. This file already has a test that reads a
  # documentation snippet and counts the environment variable names it
  # mentions. That test proves the documentation lists four names. It runs the
  # guard not at all, so it is not evidence about this setting — see FR-009.
  #
  # The rig is 90000 against a 100000-token window, so context sits at 90%.
  # That is comfortably above one setting below and comfortably below the
  # other, so the outcome of each run is decided by the setting under test and
  # by nothing else.
  #
  # THE WORDING IS ASSERTED, not merely the firing. The guard has two
  # tripwires, and "something warned" does not say which one. The proportional
  # path words itself as a percentage OF THE WINDOW and never mentions a limit;
  # the absolute path is the other way round. Reading that difference is what
  # makes this a test of this setting.
  t="$(transcript_with 90000 90000 90000 90000 90000)"

  # Above the reading: silent.
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":100000,"thresholdPct":99}'
  run_hook "$t" pctsilent
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  # Below the reading: fires, and says so as a percentage of the window.
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":100000,"thresholdPct":1}'
  run_hook "$t" pctfires
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 90% of the 100000-token window \\(threshold 1%\\)")'
  echo "$output" | jq -e '.reason | test("-token limit") | not'
}

@test "the absolute threshold setting decides whether the guard fires, and words itself as a token count" {
  # FR-008, behaviourally, and the same rig as the test above: 90000 against a
  # 100000-token window, so context sits at 90%.
  #
  # THE PROPORTIONAL THRESHOLD IS PINNED AT 99 IN BOTH RUNS, and that pin is
  # what makes this a test of the absolute setting. Left at its default of 45
  # the proportional tripwire fires first at 90%, and both runs below would
  # warn — the firing one for the wrong reason, and the test would stay green
  # with the absolute setting doing nothing whatsoever.
  #
  # THE WORDING IS ASSERTED. The absolute path names a token count past a token
  # limit and carries the percentage in the same sentence; the proportional
  # path names only the percentage. Reading that difference is what proves
  # which tripwire fired.
  t="$(transcript_with 90000 90000 90000 90000 90000)"

  # Above the reading: silent. Neither tripwire is reachable.
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":100000,"thresholdPct":99,"thresholdTokens":999999}'
  run_hook "$t" abssilent
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  # Below the reading: fires, and says so as a token count past a token limit.
  write_config "$TEST_DIR/.delivery-kit.json" '{"windowTokens":100000,"thresholdPct":99,"thresholdTokens":50000}'
  run_hook "$t" absfires
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "block"'
  echo "$output" | jq -e '.reason | test("at 90000 tokens, past the 50000-token limit")'
  echo "$output" | jq -e '.reason | test("90% of the 100000-token window")'
}

@test "the threshold rule reads the same everywhere it is stated" {
  # There was no check behind the WORDING of this rule, and that absence is how
  # the code and the prose drifted apart. The hook enforced one rule while three
  # separate places described another: they said a threshold "above 100" is
  # refused, which reads as though 100 itself were allowed. That is precisely
  # the inference the defect came from, so the wording is now pinned.
  #
  # THE SURFACE IS TWO DIRECTORIES, AND THAT IS A LIMIT, NOT A BOAST. It is
  # derived WITHIN handoff/docs and handoff/hooks — a new file in either is
  # covered on the day it lands — but the directories themselves are named here,
  # so handoff/README.md, handoff/CHANGELOG.md and handoff/skills/**/SKILL.md
  # are NOT scanned. handoff/skills/setup/SKILL.md already mentions thresholdPct
  # and is the likeliest fourth site. Widening is not free: handoff/CHANGELOG.md
  # quotes the superseded wording ON PURPOSE, as the history of this very
  # change, and would need naming as an exemption before it could join.
  #
  # THE BAN WENT THROUGH TWO WRONG SHAPES BEFORE THIS ONE, and both are worth
  # recording because both looked right.
  #
  #   1. Requiring the word "threshold" within 40 characters of "above 100" on
  #      the SAME line. It missed one of the three sites this change repaired —
  #      the hook comment whose "threshold" sits on the PREVIOUS line, where a
  #      line-scoped grep can never reach it. Measured: restoring the pre-fix
  #      wording there left the pin GREEN.
  #   2. Matching "(above|over) 100([^0-9%]|$)". The character class was added
  #      to spare the legitimate prose about an OBSERVED percentage — and it
  #      spared "a thresholdPct above 100% is refused" too, which is the single
  #      most natural way to reintroduce the defect. Measured: NO MATCH. It also
  #      missed every synonym: "greater than", "exceeds", "more than".
  #
  # What works is banning the phrase BROADLY — all the synonyms, with or without
  # a percent sign, in any case — and EXEMPTING the three legitimate
  # constructions by name. Those three describe an observed percentage, which is
  # what the misconfiguration note reports and the install guide explains; they
  # are not statements of this rule. The exemption is load-bearing: remove it and
  # the check false-reds on correct documentation.
  local -a docs hooks surface
  # nullglob so an empty directory yields an empty array rather than the literal
  # pattern — without it the guards below could never run, because the
  # assignment itself aborts under bats' errexit first. Saved and restored
  # rather than forced off, so this test cannot change the option for whatever
  # runs after it.
  # `shopt -p` EXITS 1 when the option is unset — it reports state through its
  # status as well as its output — so under bats' errexit this assignment aborts
  # the whole test without a guard. Measured: it did, on the first attempt here.
  local nullglob_was; nullglob_was="$(shopt -p nullglob || true)"
  shopt -s nullglob
  docs=( "$HANDOFF"/docs/*.md )
  hooks=( "$HANDOFF"/hooks/*.sh )
  eval "$nullglob_was"
  # EACH HALF IS ASSERTED SEPARATELY. Testing only the combined array lets one
  # directory go silently unscanned while the other keeps the count above zero —
  # "scanned nothing" and "found nothing" printing the same green, which is the
  # failure every error string in this test is written against.
  [ "${#docs[@]}" -gt 0 ]  || { echo "handoff/docs matched no .md file — half the rule surface went unscanned"; false; }
  [ "${#hooks[@]}" -gt 0 ] || { echo "handoff/hooks matched no .sh file — half the rule surface went unscanned"; false; }
  surface=( "${docs[@]}" "${hooks[@]}" )

  # grep's rc is captured rather than swallowed. 0 is matches, 1 is no match,
  # and 2 is an ERROR — an unreadable file, or a path that word-split because it
  # contained a space. Folding 2 into "no match" is exactly how a scan that read
  # nothing reports clean, so 2 fails here instead.
  local rc=0 stale=""
  grep -inE '(above|over|greater than|more than|exceeds|past) 100' "${surface[@]}" \
    > "$TEST_DIR/rulehits.txt" 2>/dev/null || rc=$?
  [ "$rc" -le 1 ] || {
    echo "the ban scan ERRORED with rc $rc — it did not read the surface, so its silence means nothing"
    false
  }
  stale="$(grep -viE 'reports a percentage|at or above 100%|percentage of 100 or above' \
           "$TEST_DIR/rulehits.txt" || true)"
  [ -z "$stale" ] || {
    echo "the superseded threshold wording survives — the rule is 100 OR ABOVE:"
    echo "$stale"
    false
  }

  # And the canonical wording must be PRESENT somewhere on the surface, or the
  # ban above passes on a surface that has stopped describing the rule at all.
  # Case-insensitive: the hook states it in capitals. This guards against the
  # rule vanishing wholesale, not against any single file dropping it — one
  # remaining statement satisfies it.
  local canonical
  canonical="$(grep -inE '100 or above' "${surface[@]}" || true)"
  [ -n "$canonical" ] || {
    echo "no statement of the threshold rule was found anywhere on the surface;"
    echo "the ban above would then pass having proven nothing"
    false
  }
}
