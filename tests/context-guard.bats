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

@test "takes the median of the last five, not the smallest" {
  # Without this, a min-of-five implementation passes every other test in
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

@test "the byte cap bounds how much of the transcript is read" {
  # The line budget alone does not bound WORK: 5000 lines of tool results can
  # be tens of megabytes, and the hook runs against a 10-second timeout on
  # every tool call. The byte cap bounds it. Capping to exactly the last three
  # entries changes the median from 30000 to 40000, so a hook that ignores the
  # cap reports 30% here and fails.
  t="$(transcript_with 10000 20000 30000 40000 50000)"
  printf '{"contextGuard":{"windowTokens":100000,"thresholdPct":1}}\n' > "$TEST_DIR/.delivery-kit.json"
  export DELIVERY_KIT_MAX_BYTES="$(tail -n 3 "$t" | wc -c | tr -d ' ')"

  run_hook "$t" capped
  [ "$status" -eq 0 ]
  [[ "$output" == *"40% of the 100000-token window"* ]]
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

@test "reads maxBytes from .delivery-kit.json" {
  # The other two settings are readable from the config file, and a knob that
  # is reachable only through the environment is one a user cannot commit
  # alongside the repository it applies to.
  t="$(transcript_with 10000 20000 30000 40000 50000)"
  cap="$(tail -n 3 "$t" | wc -c | tr -d ' ')"
  printf '{"contextGuard":{"windowTokens":100000,"thresholdPct":1,"maxBytes":%s}}\n' "$cap" \
    > "$TEST_DIR/.delivery-kit.json"

  run_hook "$t" cfgcap
  [ "$status" -eq 0 ]
  [[ "$output" == *"40% of the 100000-token window"* ]]
}

@test "an environment variable overrides the config file" {
  printf '{"contextGuard":{"windowTokens":1000000}}\n' > "$TEST_DIR/.delivery-kit.json"
  export DELIVERY_KIT_WINDOW_TOKENS=200000
  t="$(transcript_with 90000 90000 90000 90000 90000)"
  run_hook "$t"
  echo "$output" | jq -e '.reason | test("200000-token")'
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
