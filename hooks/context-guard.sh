#!/usr/bin/env bash
# context-guard.sh — delivery-kit PostToolUse hook.
#
# Computes current context usage from the session transcript and, once it
# crosses the configured threshold, emits a blocking instruction telling Claude
# to finish the current atomic step and invoke the handoff skill. Re-warns once
# per 5% bucket thereafter.
#
# Configuration — defaults, then .delivery-kit.json, then the environment:
#   contextGuard.windowTokens / DELIVERY_KIT_WINDOW_TOKENS  (default 200000)
#   contextGuard.thresholdPct / DELIVERY_KIT_THRESHOLD_PCT  (default 45)

DEFAULT_WINDOW=200000
DEFAULT_THRESHOLD=45
DEFAULT_MAX_BYTES=8000000

# A malformed or hostile value must never disable the guard, so anything that
# is not a positive integer leaves the current value in place.
#
# Leading zeros are rejected as well as non-digits. "08" is a perfectly good
# base-10 integer to `[ -gt ]`, but the arithmetic expansion that later
# computes the percentage parses it as octal, fails, and leaves the guard
# silent for the rest of the session — so it is rejected here instead.
# An overlarge value fails `-gt` with one line on stderr and is likewise
# rejected, which is the outcome we want: the arithmetic would otherwise die
# the same way.
is_positive_int() {
  case "$1" in
    ''|0*|*[!0-9]*) return 1 ;;
    *) [ "$1" -gt 0 ] ;;
  esac
}

# A threshold over 100 could only be reached once context has already
# exceeded the window, which is far too late to be useful — so in practice
# the guard would never fire again, silently, which is the one thing
# configuration must not be able to do. Nothing downstream can catch it:
# the window-misconfiguration report runs only once the guard has already
# decided to fire.
is_valid_threshold() {
  is_positive_int "$1" && [ "$1" -le 100 ]
}

input=$(cat)

# jq is a hard dependency: the hook parses the stdin payload and a JSONL
# transcript, and reimplementing that in POSIX shell would be fragile exactly
# where correctness matters. Without jq the guard cannot run — and a guard
# that silently never fires is the failure this project exists to prevent.
# Say so once, then stay out of the way. Detection runs jq rather than
# looking it up on PATH: a jq that cannot execute is no more use than none.
if ! jq --version >/dev/null 2>&1; then
  flagdir="${TMPDIR:-${TEMP:-/tmp}}"
  hint_flag="$flagdir/dk-jq-hint"
  if [ ! -f "$hint_flag" ]; then
    : 2>/dev/null > "$hint_flag"
    printf '%s\n' '{"systemMessage":"delivery-kit: the context guard is disabled because jq is not installed or cannot run. Install it (macOS: brew install jq | Debian/Ubuntu: sudo apt-get install jq | Windows: winget install jqlang.jq) and restart the session."}'
  fi
  exit 0
fi

transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
session=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')

[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

# Configuration: defaults -> .delivery-kit.json -> environment. The file is
# what a repository commits; the environment is what overrides it for one
# session without editing a committed file.
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"
config="$cwd/.delivery-kit.json"
if [ ! -f "$config" ]; then
  # Claude Code's cwd can be a subdirectory of the repository.
  toplevel=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  [ -n "$toplevel" ] && [ -f "$toplevel/.delivery-kit.json" ] && config="$toplevel/.delivery-kit.json"
fi

WINDOW=$DEFAULT_WINDOW
THRESHOLD_PCT=$DEFAULT_THRESHOLD
MAX_BYTES=$DEFAULT_MAX_BYTES

if [ -f "$config" ]; then
  cfg_window=$(jq -r '.contextGuard.windowTokens // empty' "$config" 2>/dev/null)
  cfg_threshold=$(jq -r '.contextGuard.thresholdPct // empty' "$config" 2>/dev/null)
  cfg_max_bytes=$(jq -r '.contextGuard.maxBytes // empty' "$config" 2>/dev/null)
  is_positive_int "$cfg_window" && WINDOW=$cfg_window
  is_valid_threshold "$cfg_threshold" && THRESHOLD_PCT=$cfg_threshold
  is_positive_int "$cfg_max_bytes" && MAX_BYTES=$cfg_max_bytes
fi

is_positive_int "$DELIVERY_KIT_WINDOW_TOKENS" && WINDOW=$DELIVERY_KIT_WINDOW_TOKENS
is_valid_threshold "$DELIVERY_KIT_THRESHOLD_PCT" && THRESHOLD_PCT=$DELIVERY_KIT_THRESHOLD_PCT
is_positive_int "$DELIVERY_KIT_MAX_BYTES" && MAX_BYTES=$DELIVERY_KIT_MAX_BYTES

# Current context = input + cache_read + cache_creation per main-chain
# assistant message (the same arithmetic status-line tools use). MEDIAN of
# the last 15 entries, not the last one: a request that re-sends the full raw
# history (a review or advisory tool that forwards the transcript) inflates
# entries far above the live context, and a last-entry read fires the guard
# early — seen 2026-08-07, the hook reported 45% while the session was
# genuinely at 24%.
#
# 15 and not 5, because such a tool does not inflate ONE entry. The assistant
# messages that follow it read the same oversized cache, so the inflation
# persists for four to six CONSECUTIVE entries. Measured against the advisor
# tool on 2026-08-15: 122774 -> 252163, 160982 -> 328729, 183166 -> 371027 —
# each about 2x, each lasting four to six readings. A 5-wide window is FILLED
# by that run, so the median is not merely dragged toward the spike, it IS the
# spike: the hook reported 37% where Claude Code's own status line read 19%.
# Reading high is the fail-loud direction, so the cost was half a wasted
# session rather than a session lost — but a guard that is wrong by 2x teaches
# the user to ignore it, which ends in the same place. 15 outvotes a run of 7.
#
# Ingestion is per-line with `fromjson?` rather than a slurp: Claude Code
# appends to this file while we read it, and `jq -s` aborts the entire parse
# on the first torn line, leaving ctx empty and the guard silently disabled.
# Per-line parsing skips the bad line and keeps the guard alive.
#
# The tail is a budget in LINES while the median needs fifteen READINGS, and the
# two diverge badly. Tool results, user turns and sidechain lines all consume
# the budget without yielding a reading, and in a session that dispatches
# subagents the sidechain lines dominate. At 300 the boundary was reachable:
# with ~295 intervening lines the window clipped every honest reading, the
# median degenerated to whichever single entry survived, and an inflated one
# reported 450% where the session was at 24% — reintroducing the 2026-08-07
# incident this arithmetic exists to prevent, and then telling the user to
# raise windowTokens, which converts a loud failure into a silent one. 5000
# leaves room for several subagent fan-outs between readings, and `.[-15:]`
# below already takes the last fifteen MATCHING entries, so nothing downstream
# has to change.
#
# But a budget in lines does not bound WORK. 5000 lines of tool results
# measured 48MB, and reading it cost 7.2s against a hook that runs on every
# tool call — 1.4x under the old 10s timeout, and a hook killed by its timeout
# emits nothing, which is a guard that is silently off. Hence the byte cap
# below: 8MB brings the common path to 2.0s.
#
# Run twice on the starved path, so it is written once here rather than
# twice below, where the two copies would drift and only one would be tested.
READINGS_JQ='fromjson?
  | select(.isSidechain != true)
  | select(.message.usage.input_tokens != null)
  | .message.usage
  | (.input_tokens + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))'

readings=$(tail -c "$MAX_BYTES" "$transcript" | tail -n 5000 | jq -Rr "$READINGS_JQ" 2>/dev/null)

# The byte cap is a THIRD budget that does not measure readings either, so on
# its own it reaches the 2026-08-07 incident by exactly the route `tail -n 300`
# did. The floor is therefore the WINDOW, and must stay equal to it if the
# window changes again. A suffix that still holds fifteen readings yields the
# same last fifteen as the whole file, so the capped answer is identical and
# the cap is free; a suffix holding fewer can differ, and every way it can
# differ is a way of resting the median on an inflated run. A smaller floor
# reads as harmless and is not: three was correct while the window was five,
# and against fifteen it is no floor at all — a cap yielding eight readings
# clears it without a fallback, and six inflated entries among those eight ARE
# the median, which is the 2026-08-07 failure arrived at for the third time.
#
# So the cap is an OPTIMISATION THAT MAY NEVER CHANGE THE ANSWER: when it
# starves, fall back to the uncapped read, which is byte-for-byte the
# behaviour that shipped before the cap existed. A cap that could answer from
# a starved window would buy latency with the one failure this arithmetic
# exists to prevent.
#
# That fallback reads the file twice, so it is NOT free and this comment will
# not pretend otherwise: measured 8.2s where the uncapped code was 7.2s, on a
# 48MB transcript whose readings sit inside the line window but outside the
# byte cap. The timeout in hooks.json is 30 because of this path, not because
# of the 2.0s common one. Trading ~1s in a case that needs megabytes between
# readings for 3.6x in every ordinary session is the right trade; a cap that
# also bounded the fallback would be faster and occasionally wrong.
#
# Raising the floor from three to fifteen widened the door to that path, and
# the honest way to state it is as a rate: the fallback now runs whenever the
# capped 8MB holds fewer than fifteen readings, which needs upwards of half a
# megabyte between consecutive readings. An ordinary session is nowhere near
# that; a session whose tool results are that large pays ~1s and gets the right
# answer, which is the trade already made above rather than a new one.
if [ "$(printf '%s\n' "$readings" | grep -c '^[0-9]')" -lt 15 ]; then
  readings=$(tail -n 5000 "$transcript" | jq -Rr "$READINGS_JQ" 2>/dev/null)
fi

ctx=$(printf '%s\n' "$readings" | jq -rs '.[-15:] | sort | .[(length/2|floor)] // 0' 2>/dev/null)

[ -n "$ctx" ] && [ "$ctx" -gt 0 ] 2>/dev/null || exit 0

pct=$(( ctx * 100 / WINDOW ))

# Warn once per 5% bucket (45, 50, 55, ...) so Claude is re-nudged if it
# keeps working past the first warning, without one warning per tool call.
bucket=$(( pct / 5 ))
flagdir="${TMPDIR:-${TEMP:-/tmp}}"
flag="$flagdir/ctx-warned-$session"
last_bucket=$(cat "$flag" 2>/dev/null)
# An unusable flag value means "never warned", not "stop warning". Without
# this, an empty or corrupt flag makes the comparison error out and the
# `|| exit 0` below silences the guard for the rest of the session.
#
# The sentinel is -1, not 0, because 0 is a real bucket: it covers everything
# below 5% of the window. With 0 standing for "never warned", the gate below
# could never fire in that band at all, so a low threshold — or a window large
# enough that 5% is tens of thousands of tokens — would produce silence and
# read as a broken install. That is the first thing a new user tests.
case "$last_bucket" in ''|*[!0-9]*) last_bucket=-1 ;; esac

# Context falls as well as rises: a compaction can halve it, and a brief
# inflated reading can overstate it. A mark that only ever rose would keep
# the guard silent all the way back up to the old peak — exactly the band
# it exists to cover. Follow a real drop (2+ buckets, 10 points) down, and
# ignore 1-bucket jitter so a reading oscillating across a boundary cannot
# re-warn on every tool call. This runs before the threshold gate because
# the drop that matters most, a compaction, lands below the threshold.
# Note that a session which has never warned has last_bucket -1, so the
# comparison is against -3 and no flag is ever created here.
if [ "$bucket" -le $(( last_bucket - 2 )) ]; then
  echo "$bucket" > "$flag"
  last_bucket=$bucket
fi

[ "$pct" -ge "$THRESHOLD_PCT" ] || exit 0
[ "$bucket" -gt "$last_bucket" ] 2>/dev/null || exit 0
echo "$bucket" > "$flag"

# One flag file per session would otherwise accumulate in the temp directory
# forever. Cleaning here, on the rare path that just wrote a flag, keeps the
# cost off every tool call. `-type f` so a stray directory of the same name
# is never removed.
#
# dk-jq-hint is swept too, and it is the only one that has to be: it is
# global rather than per-session, so nothing else would ever remove it, and
# a user who fixes jq and later loses it again would get a silently dead
# guard and no second hint. Including it is safe in both directions —
# `-mtime +7` cannot touch a fresh flag, and this line sits past the jq
# gate, so it cannot run during the outage it cleans up after. The
# once-only contract within an outage is untouched; the hint only re-arms
# after jq recovers and the flag ages out.
find "$flagdir" -maxdepth 1 -type f \( -name 'ctx-warned-*' -o -name 'dk-window-warned-*' -o -name 'dk-jq-hint' \) -mtime +7 -delete 2>/dev/null

# A window configured larger than the model's real one never fires the guard.
# If observed context exceeds the configured window, the configuration is
# provably wrong, so say so — once per session.
#
# The note gives the NUMBER rather than telling the user to go and find it,
# because this reading is not merely evidence that the window is wrong: it is
# a LOWER BOUND on the right one. Context reached ${ctx}, so the real window is
# at least that. Saying "raise it" hands back a task the hook has already done.
#
# This is also why the default stays at 200000 rather than being raised to
# match large-context models, which looks like the obvious fix and is the
# dangerous one. The two ways of being wrong are not symmetric. Too small
# fires early: annoying, immediately visible, and self-diagnosing through
# exactly this note. Too large never fires at all — silent, total, and
# discovered when a session dies mid-task. Nothing here can detect that case;
# the only comparison against WINDOW is the one below, and it trips in one
# direction. Detecting the window from the transcript does not work either:
# a 1M-context session records `.message.model` as the base model id with no
# variant marker, and no other field carries the window, so a lookup table
# would return 200000 for a 1M session, confidently and with no signal that it
# had guessed. Verified against a live 1M transcript. See issue #1.
#
# INVARIANT: ctx > WINDOW implies pct >= 100, which implies bucket >= 20. The
# threshold gate cannot block that, because is_valid_threshold caps
# THRESHOLD_PCT at 100. So the note rides an emission rather than needing one
# of its own.
#
# One exception, and it is deliberate: a reading landing exactly on WINDOW
# records bucket 20 without the note, because the test below is strict and
# ctx == WINDOW is not provably a misconfiguration. An over-window reading
# still inside that bucket is then suppressed by the bucket gate, and the note
# defers to the next bucket. Deferred, never dropped — on the misconfiguration
# this exists to report, a window set far too small, context clears the next
# bucket within a call or two. Preserve that distinction if the bucket rule
# ever changes.
misconfig=""
if [ "$ctx" -gt "$WINDOW" ]; then
  wflag="$flagdir/dk-window-warned-$session"
  if [ ! -f "$wflag" ]; then
    : 2>/dev/null > "$wflag"
    misconfig=" WINDOW MISCONFIGURED: observed context (${ctx} tokens) exceeds the configured window (${WINDOW} tokens). Your real window is therefore at least ${ctx} tokens — set contextGuard.windowTokens in .delivery-kit.json to match your model (commonly 200000 or 1000000) and the percentages above become meaningful."
  fi
fi

reason="CONTEXT GUARD: session context is at ${pct}% of the ${WINDOW}-token window (threshold ${THRESHOLD_PCT}%). Finish ONLY the current atomic step — do NOT start the next batch or task. Then invoke the handoff skill (delivery-kit:handoff): commit and push the work, write the handoff document, print the resume prompt for the user, and stop.${misconfig}"

jq -n --arg reason "$reason" '{decision:"block", reason:$reason}'
exit 0
