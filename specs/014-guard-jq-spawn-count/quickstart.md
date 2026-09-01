# Quickstart: proving the guard stops counting jq

Every block is meant to be **run**, not read. Run them from the repository root.

## Prerequisites

```bash
cd "$(git rev-parse --show-toplevel)"
command -v jq && jq --version
ls "$HOME/bats/bin/bats"
ls handoff/hooks/context-guard.sh
```

## 1. Count the jq invocations, on all three configuration paths

This is the acceptance measurement. Run it **before** the change and again
after, and keep both.

The rig: a shim directory holding a fake `jq` that records one line per
invocation and then execs the real one, prepended to `PATH`; `HOME` and the
working directory controlled so the number of configuration files is exactly
what we say it is; and a small real transcript so the hook runs end to end
rather than bailing early.

```bash
cat > /tmp/count-jq.sh <<'EOF'
#!/usr/bin/env bash
set -u
HOOK="${1:?need the hook path}"
HOOK=$(cd "$(dirname "$HOOK")" && pwd)/$(basename "$HOOK")
root=/tmp/jqcount; rm -rf "$root"; mkdir -p "$root/shim"
REALJQ=$(command -v jq)
cat > "$root/shim/jq" <<SHIM
#!/bin/sh
echo x >> "\$JQ_COUNT_FILE"
exec "$REALJQ" "\$@"
SHIM
chmod +x "$root/shim/jq"
cfg='{"contextGuard":{"windowTokens":1000000,"thresholdPct":65,"thresholdTokens":650000}}'
run_path() {
  nfiles="$1"; d="$root/n$nfiles"; mkdir -p "$d/home" "$d/work"
  : > "$d/t.jsonl"
  for i in 1 2 3 4 5 6; do
    printf '{"message":{"usage":{"input_tokens":1000,"cache_read_input_tokens":2000,"output_tokens":10}}}\n' >> "$d/t.jsonl"
  done
  [ "$nfiles" -ge 1 ] && printf '%s\n' "$cfg" > "$d/home/.delivery-kit.json"
  [ "$nfiles" -ge 2 ] && printf '%s\n' "$cfg" > "$d/work/.delivery-kit.json"
  cf="$d/count"; : > "$cf"
  printf '{"transcript_path":"%s","session_id":"s1","cwd":"%s"}' "$d/t.jsonl" "$d/work" \
    | env PATH="$root/shim:$PATH" HOME="$d/home" JQ_COUNT_FILE="$cf" bash "$HOOK" >/dev/null 2>&1
  printf '  %s config file(s): %s jq invocations (whole run)\n' "$nfiles" "$(wc -l < "$cf" | tr -d ' ')"
}
run_path 0; run_path 1; run_path 2
rm -rf "$root"
EOF
bash /tmp/count-jq.sh handoff/hooks/context-guard.sh
```

**Expected before the change: 8, 12, 16. After: 5, 6, 7.**

Those are WHOLE-RUN numbers. The seed quotes 5 / 9 / 13 → 2 / 3 / 4, which is
the slice **before the transcript is read**; the constant difference of three is
the transcript reading itself, which this change does not touch. Both columns
are true and both are recorded — see [research.md](./research.md), Finding A2.

**The shim records one fixed token per invocation, deliberately.** An earlier
version logged each call's arguments and counted lines, and reported 16 and 24,
because two of the jq programs span several lines. A measurement that
double-counts is worth less than none. If you want to see *which* calls fire,
log the arguments as a separate diagnostic — never as the count.

## 2. Prove the split survives an empty leading field

This is the hazard that makes the seed's suggested spelling unusable. The
`agent_id` field is **absent in every main-session payload**, so this is the
ordinary path.

```bash
cat > /tmp/split-probe.sh <<'EOF'
#!/usr/bin/env bash
MAIN='{"transcript_path":"/t","session_id":"s","cwd":"/c"}'
SUB='{"agent_id":"a1","transcript_path":"/t","session_id":"s","cwd":"/c"}'
US=$'\037'
naive() { printf '%s' "$1" | jq -r '[.agent_id, .transcript_path, .session_id, .cwd] | @tsv'; }
# `cand` is the SHIPPED spelling: separator via --arg (no escape in the jq
# source), and the split done with parameter expansion, never `read`.
cand()  { printf '%s' "$1" | jq -r --arg US "$US" '[.agent_id // "", .transcript_path // "", .session_id // "unknown", .cwd // ""] | map(tostring) | join($US)'; }
verdict() { if [ -n "$1" ]; then echo "EXIT 0 (treated as subagent)"; else echo "continue (main session)"; fi; }
for label in MAIN SUB; do
  eval "J=\$$label"
  today=$(printf '%s' "$J" | jq -r '.agent_id // empty')
  IFS=$'\t' read -r na _ _ _ <<< "$(naive "$J")"
  ca=$(cand "$J"); ca=${ca%%"$US"*}
  echo "$label  today: $(verdict "$today")"
  echo "$label  naive: $(verdict "$na")"
  echo "$label  cand : $(verdict "$ca")"
done
EOF
bash /tmp/split-probe.sh
```

Expected: `today` and `cand` agree on both payloads. `naive` disagrees on
`MAIN` — it reports EXIT 0, meaning the guard would treat every main session as
a subagent and **never fire again, silently.**

## 3. Prove the configuration split does not shift values

The quieter half of the same bug: a shifted value here still passes validation,
so the guard installs the wrong setting with no error.

```bash
cat > /tmp/config-probe.sh <<'EOF'
#!/usr/bin/env bash
d=$(mktemp -d)
# thresholdPct absent — an ordinary, supported shape. Every key is optional.
printf '%s\n' '{"contextGuard":{"windowTokens":1000000,"thresholdTokens":650000,"maxBytes":9999}}' > "$d/gap.json"
US=$'\037'
echo "today:"
printf '  window=[%s] pct=[%s] tokens=[%s] maxBytes=[%s]\n' \
  "$(jq -r '.contextGuard.windowTokens // empty' "$d/gap.json")" \
  "$(jq -r '.contextGuard.thresholdPct // empty' "$d/gap.json")" \
  "$(jq -r '.contextGuard.thresholdTokens // empty' "$d/gap.json")" \
  "$(jq -r '.contextGuard.maxBytes // empty' "$d/gap.json")"
IFS=$'\t' read -r w p t m <<< "$(jq -r '.contextGuard // {} | [.windowTokens,.thresholdPct,.thresholdTokens,.maxBytes] | @tsv' "$d/gap.json")"
echo "naive:"; printf '  window=[%s] pct=[%s] tokens=[%s] maxBytes=[%s]\n' "$w" "$p" "$t" "$m"
# The SHIPPED spelling: the separator handed to jq with --arg, so no escape
# appears in the jq source, and the split done with parameter expansion, never
# `read`. See section 4 for why `read` is forbidden here.
c=$(jq -r --arg US "$US" '.contextGuard // {} | [.windowTokens,.thresholdPct,.thresholdTokens,.maxBytes] | map(. // "" | tostring) | join($US)' "$d/gap.json")
w=${c%%"$US"*}; r=${c#*"$US"}; p=${r%%"$US"*}; r=${r#*"$US"}; t=${r%%"$US"*}; m=${r#*"$US"}
echo "candidate:"; printf '  window=[%s] pct=[%s] tokens=[%s] maxBytes=[%s]\n' "$w" "$p" "$t" "$m"
rm -rf "$d"
EOF
bash /tmp/config-probe.sh
```

Expected: `today` and `candidate` match. `naive` shifts — the token threshold
picks up the byte cap's value, which is a positive integer and therefore
**passes validation and gets installed.**

## 4. Prove jq emits carriage returns, and what the capture actually strips

```bash
printf '{"transcript_path":"/t"}' | jq -r '.transcript_path' | cat -A
v=$(printf '{"transcript_path":"/t"}' | jq -r '.transcript_path'); printf '[%s]\n' "$v" | cat -A
```

Expected: the piped form shows `^M` (a carriage return). The `$()` form does
not — command substitution strips it. That is why the fields are joined into
**one** value captured with `$()`, rather than emitted as four lines read one
at a time, which would leave a stray `^M` on three of the four.

**Read that result narrowly.** What `$()` strips is jq's own *trailing* line
ending, and nothing more. It is not a guarantee that no carriage return reaches
a variable: a value that itself contains a newline arrives with `\r\n` in the
middle of its own field, and did so before this change too. "The output is one
line" is a property of ordinary data, not of the program — which is why the
split is parameter expansion and never `read`. Prove that with the block below.

```bash
US=$'\037'
p=$(printf '%s' '{"a":"p\nq","b":"z"}' | jq -r --arg US "$US" '[.a,.b] | map(tostring) | join($US)')
printf '%s' "${p%%"$US"*}" | od -c   # field 1: p \r \n q  — the newline stays inside it
printf '%s' "${p#*"$US"}"  | od -c   # field 2: z          — NOT lost
```

Expected: field 1 keeps its embedded newline and field 2 survives. Swap the
split for `IFS="$US" read -r f1 f2` and field 1 truncates to `p\r` while field 2
vanishes — that is the regression this quickstart now pins.

## 5. The hook's own suite, unedited

```bash
bash "$HOME/bats/bin/bats" --print-output-on-failure handoff/tests/context-guard.bats
echo "--- was it edited? ---"
git diff --stat 45e6b12 -- handoff/tests/context-guard.bats
```

Expected: green, and an **empty** diff. A test that needed changing is proof the
behaviour changed; the answer is to stop, not to change the test.

## 6. The full house suite, from the repository root

```bash
cd "$(git rev-parse --show-toplevel)"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests > /tmp/house.tap
echo "exit: $?"
head -1 /tmp/house.tap
grep -c '^ok ' /tmp/house.tap
grep -c '^not ok ' /tmp/house.tap
```

Expected: the same plan line as before the change, `not ok` count `0`, exit `0`.
Do not pipe the suite into `head` or `tail` — a pipe hands the block the last
command's status, always `0`, and cuts the plan line bats prints first.

## 7. The comments survived

```bash
# PIN the baseline to a commit id. `git diff` with no argument compares the
# WORKING TREE, so the moment this work is committed the diff is empty and the
# check reports a comfortable zero having scanned nothing. Measured: after
# commit, the unpinned diff is 0 lines long and the count is 0; against 45e6b12
# the diff is 120 lines and the count is still 0, which is the real answer. A
# branch name is no better than the working tree here — once this merges, `main`
# is where the change ARRIVED and the diff empties again.
BASE=45e6b12   # the last commit before this change
git diff "$BASE" -- handoff/hooks/context-guard.sh | grep -cE '^-[[:space:]]*#'
```

Note both details of that pattern, each of which a simpler one gets wrong:

- `[[:space:]]*` — several comments in this file are **indented** (inside
  `read_config`, and inside the `if` blocks). A pattern anchored as `^-#` misses
  every one of them and reports a comfortable zero.
- `[[:space:]]` rather than `\s` — `\s` is a GNU extension. CI runs macOS, whose
  `grep` does not have it, and a pattern that silently matches nothing there
  would make this check pass by scanning nothing.

Expected: this counts **removed comment lines**. A non-zero result needs
justifying line by line — comments may move, but the record must not shrink.
Measured at `640e99d`: the diff is 120 lines and the count is **0**.

Read the exit code correctly: `grep -c` exits **1** when it matches nothing, so
a clean run prints `0` and exits `1`. That is the SUCCESS case here. Never wrap
it as `n=$(grep -c … || echo 0)` — that yields the two-line string `0\n0` and
every comparison against `0` then fails.

Read the lines rather than trusting the number:

```bash
BASE=45e6b12   # the pre-change commit; see the note above
git diff "$BASE" -- handoff/hooks/context-guard.sh | grep -E '^-[[:space:]]*#'
```
