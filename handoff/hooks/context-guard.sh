#!/usr/bin/env bash
# context-guard.sh — handoff PostToolUse hook.
#
# Computes current context usage from the session transcript and, once it
# crosses the configured threshold, emits a blocking instruction telling Claude
# to finish the current atomic step and invoke the handoff skill. Re-warns once
# per 5% bucket thereafter.
#
# Configuration — defaults, then ~/.delivery-kit.json, then
# <repo>/.delivery-kit.json, then the environment:
#   contextGuard.windowTokens    / DELIVERY_KIT_WINDOW_TOKENS     (default 200000)
#   contextGuard.thresholdPct    / DELIVERY_KIT_THRESHOLD_PCT     (default 45)
#   contextGuard.thresholdTokens / DELIVERY_KIT_THRESHOLD_TOKENS  (unset by default)
#   contextGuard.maxBytes        / DELIVERY_KIT_MAX_BYTES         (default 8000000)

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
    printf '%s\n' '{"systemMessage":"handoff: the context guard is disabled because jq is not installed or cannot run. Install it (macOS: brew install jq | Debian/Ubuntu: sudo apt-get install jq | Windows: winget install jqlang.jq) and restart the session."}'
  fi
  exit 0
fi

# The separator, defined ONCE and used everywhere: handed to jq with --arg and
# used again below to split. It was previously spelled two ways in four places —
# a jq \u escape inside the programs and $'\037' in the shell — which a merge or a
# careless edit could desynchronise, leaving jq joining on one byte and the shell
# splitting on another. One definition removes that class. It also keeps the
# escape out of the jq source, which matters more than it sounds: while this
# change was written, an editor, GNU sed (whose \u is a case operator) and
# GitHub each silently decoded that escape and left a raw control byte behind.
US=$'\037'

# Every field this hook needs from the payload, in ONE jq call rather than one
# call per field. This hook runs on PostToolUse after EVERY tool call, and
# process spawn dominates on Windows under Git Bash, which is a supported
# platform. Measured 2026-09-01, on the NON-FIRING path — the one that follows
# almost every tool call: this took the whole run from 8/12/16 jq processes to
# 5/6/7, for zero, one and two config files present. A firing run spends one
# more, on the emission at the bottom of this file, which is the output itself.
#
# THE SEPARATOR IS NOT A TAB, AND THAT IS LOAD BEARING. Tab is an IFS-whitespace
# character, so a split on it collapses runs and strips leading ones — an empty
# field does not survive. agent_id is EMPTY in every main-session payload, which
# is the ordinary case, so with a tab the fields shift left and agent_id reads
# as the transcript path. That is non-empty, so the check below would exit 0 and
# THE GUARD WOULD NEVER FIRE IN THE MAIN SESSION AGAIN, silently. Measured, both
# ways, before this was written.
#
# SPLIT WITH PARAMETER EXPANSION, NOT `read`, AND THAT IS LOAD BEARING TOO.
# `read` stops at the first newline, while the per-field $() it replaced captured
# all of them. A JSON string value may contain a newline, so `read` would keep a
# prefix and silently drop every field after it — measured: a config whose
# windowTokens is "5\n999999" lost its threshold, its token cap and its byte cap
# entirely, and on a platform where jq emits no carriage return the truncated
# "5" PASSES validation and installs a five-token window. Parameter expansion
# splits on the separator alone and leaves embedded newlines inside their field,
# which is exactly what the old code did.
#
# map(tostring) so one field of an unexpected type cannot abort the whole
# extraction. join() on a non-string errors, and an erroring jq yields an empty
# payload, an empty transcript, and a guard that exits silently — the one
# direction this hook must never fail in. Measured with a cwd that is an object.
#
# The defaults are the ones this hook has always applied, moved into the jq
# program unchanged — empty for three fields, "unknown" for the session.
payload=$(printf '%s' "$input" | jq -r --arg US "$US" '[.agent_id // "", .transcript_path // "", .session_id // "unknown", .cwd // ""] | map(tostring) | join($US)')
agent_id=${payload%%"$US"*};  rest=${payload#*"$US"}
transcript=${rest%%"$US"*};   rest=${rest#*"$US"}
session=${rest%%"$US"*}
cwd=${rest#*"$US"}

# Inside a subagent this hook is handed the PARENT's transcript_path and the
# PARENT's session_id — measured on 2026-08-18 by logging the hook's stdin and
# driving one throwaway subagent; both of its tool calls arrived carrying the
# parent session's transcript, indistinguishable from the main-chain calls
# around them except for the two fields read here.
#
# So without this exit the guard reports the PARENT's percentage inside a
# subagent whose own context is near zero, and — because session_id is the
# parent's too — marks the parent's once-per-bucket flag, which can swallow a
# warning the parent was owed. A missing warning is the failure this project
# exists to prevent, so that second effect, not the wrong number, is why this
# is here.
#
# Silence rather than "measure the subagent instead": the payload does not
# carry the subagent's own transcript path, so there is nothing to measure. The
# instruction would be wrong regardless — a subagent cannot hand off, and
# telling it to stop mid-task damages the parent's work for no benefit.
#
# Keyed on the PRESENCE of agent_id, and the polarity is deliberate. Should a
# future Claude Code rename the field, this check goes inert and the guard
# returns to today's behaviour: noisy in subagents, correct in the main session.
# A check that instead required some field to be present before arming would
# fail toward silence in the MAIN session, which is the one direction this hook
# must never fail in.
if [ -n "$agent_id" ]; then
  exit 0
fi

[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

# Configuration: defaults -> ~/.delivery-kit.json -> <repo>/.delivery-kit.json
# -> environment. The context window is a fact about a machine and a model, not
# about a repository: requiring it per repo guarantees most repositories run on
# defaults, which is the failure this layer exists to reduce. The repo file
# still wins, so a project can override for its own reasons, and the
# environment still wins over both for a one-session override.
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
# Unset by default, and "unset" is load-bearing — see the firing gate below.
# There is deliberately no DEFAULT_THRESHOLD_TOKENS: a default here would be a
# guess at a number only the user knows, and a wrong one is the silent failure
# this release exists to make harder.
THRESHOLD_TOKENS=""

# One reader for both files, so the two cannot drift into applying different
# validation — which would let an invalid value disable the guard from
# whichever file was checked less carefully. A missing file is not an error:
# both are optional and zero-config is the supported case.
#
# If HOME is unset the path becomes "/.delivery-kit.json", which will not
# exist, so the `-f` test skips it. Under Git Bash on Windows HOME is set to
# the user profile, which is the intended location; that shell is where this
# project has already been bitten once by a TEMP-versus-TMPDIR difference, so
# it is called out rather than assumed.
read_config() {
  [ -f "$1" ] || return 0
  # ONE jq call for all four settings, not one per setting. Same reasoning as
  # the payload extraction above, and the same two traps: the separator must
  # not be IFS-whitespace, and the result must be one line.
  #
  # The trap is QUIETER here than it is up there, which makes it worse. Every
  # value below is a positive integer, so a value that lands in the wrong slot
  # PASSES validation and is installed. Measured with thresholdPct absent — an
  # ordinary shape, since every key is optional — a tab-split installs maxBytes
  # as thresholdTokens: the guard would fire at ten thousand tokens instead of
  # six hundred and fifty thousand, with no error and no failing test.
  #
  # tostring after the empty default: these are JSON numbers. The local jq
  # joins numbers without help, but CI runs a different one, and this project
  # has already been bitten by an analyser version gap of exactly that shape.
  # One token of jq buys out the question.
  #
  # Split with parameter expansion for the reason the payload block gives at
  # length: `read` stops at the first newline, and a JSON string value may
  # contain one. Measured here, this was not theoretical — a windowTokens of
  # "5\n999999" truncated to "5" and took thresholdPct, thresholdTokens and
  # maxBytes with it, all three silently reverting to their defaults.
  cfg=$(jq -r --arg US "$US" '.contextGuard // {} | [.windowTokens, .thresholdPct, .thresholdTokens, .maxBytes] | map(. // "" | tostring) | join($US)' "$1" 2>/dev/null)
  cfg_window=${cfg%%"$US"*};      r=${cfg#*"$US"}
  cfg_threshold=${r%%"$US"*};     r=${r#*"$US"}
  cfg_tokens=${r%%"$US"*}
  cfg_max_bytes=${r#*"$US"}
  is_positive_int "$cfg_window" && WINDOW=$cfg_window
  is_valid_threshold "$cfg_threshold" && THRESHOLD_PCT=$cfg_threshold
  # No upper bound, unlike the threshold above. That cap exists because a
  # percentage over 100 can only be reached once context has already overflowed
  # the window, so it is unreachable by construction; a token count has no such
  # ceiling — it is a number about the user's model, and any positive value is a
  # setting somebody could legitimately mean. The arithmetic ceiling documented
  # at is_positive_int still rejects an out-of-range value like any other
  # invalid input.
  is_positive_int "$cfg_tokens" && THRESHOLD_TOKENS=$cfg_tokens
  is_positive_int "$cfg_max_bytes" && MAX_BYTES=$cfg_max_bytes
  # Insurance, not a live fix, and no test covers it — stated plainly so the
  # next reader does not go looking for the bug it prevents. The last
  # conditional fails whenever maxBytes is absent, which is the ordinary case,
  # so without this the function would usually return 1. Nothing today notices:
  # the hook sets neither `set -e` nor `set -u`, and both call sites below
  # ignore the status. Removing the line leaves the suite green. It earns its
  # place against the caller that does read $? — a `&&` chain, a `set -e` added
  # later — where a function returning 1 on its SUCCESS path is a trap. Keep it
  # last as keys are added above it.
  return 0
}

# Read in precedence order. Reading the same path twice, when a repository
# happens to sit at HOME, is idempotent and needs no guard.
read_config "$HOME/.delivery-kit.json"
read_config "$config"

is_positive_int "$DELIVERY_KIT_WINDOW_TOKENS" && WINDOW=$DELIVERY_KIT_WINDOW_TOKENS
is_valid_threshold "$DELIVERY_KIT_THRESHOLD_PCT" && THRESHOLD_PCT=$DELIVERY_KIT_THRESHOLD_PCT
is_positive_int "$DELIVERY_KIT_THRESHOLD_TOKENS" && THRESHOLD_TOKENS=$DELIVERY_KIT_THRESHOLD_TOKENS
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

# Two independent tripwires, OR semantics. The absolute one is decidable from
# the transcript alone, so it is immune to a wrong windowTokens; the relative
# one catches a thresholdTokens set too high. On its own either merely
# RELOCATES the silent failure — running both means it takes two wrong values
# to silence the guard where today it takes one. That is a safety gain, not an
# ergonomic one.
#
# THRESHOLD_TOKENS is unset by default, so an unguarded [ "$ctx" -ge "" ] would
# error. What that costs is OUTPUT POLLUTION, not a dead guard, and the
# distinction matters because the fix differs. Verified by mutation: the
# erroring `[` sits inside `if …; then abs_fired=1; fi`, so its status 2 is
# consumed by the `if`, abs_fired stays 0, and the relative rule below still
# emits decision:block correctly. What leaks is one "integer expected" line on
# stderr per tool call.
#
# Of the two things preventing that, the `-n` test is what does the work: `&&`
# short-circuits, so the erroring `[` never runs and the redirect never sees
# anything. The 2>/dev/null is the backstop that would swallow the noise if the
# `-n` were ever dropped — either alone suffices; only removing both pollutes.
#
# The last_bucket sentinel above guards a DIFFERENT and worse hazard, so do not
# read the two as the same. There the erroring comparison feeds `|| exit 0`,
# which really does silence the guard for the rest of the session. Contained by
# an `if`, an error is noise; feeding an `|| exit 0` chain, it is silence.
abs_fired=0
if [ -n "$THRESHOLD_TOKENS" ] && [ "$ctx" -ge "$THRESHOLD_TOKENS" ] 2>/dev/null; then
  abs_fired=1
fi
rel_fired=0
[ "$pct" -ge "$THRESHOLD_PCT" ] && rel_fired=1
[ "$abs_fired" -eq 1 ] || [ "$rel_fired" -eq 1 ] || exit 0
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
setup_hint=""
# Only the SETUP SENTENCE rides the once-per-session gate now. The systemMessage
# itself is built unconditionally below, on every firing — see issue #2 and the
# measurement recorded there.
sysmsg_setup=""
if [ "$ctx" -gt "$WINDOW" ]; then
  wflag="$flagdir/dk-window-warned-$session"
  if [ ! -f "$wflag" ]; then
    : 2>/dev/null > "$wflag"
    misconfig=" WINDOW MISCONFIGURED: observed context (${ctx} tokens) exceeds the configured window (${WINDOW} tokens). Your real window is therefore at least ${ctx} tokens — set contextGuard.windowTokens in .delivery-kit.json to match your model (commonly 200000 or 1000000) and the percentages above become meaningful."
    # DEFERRED, and the ordering is the whole design. This note only ever
    # rides an emission that is already telling Claude to finish the step and
    # hand off, so a bare "run setup" here would put two competing
    # instructions in front of Claude exactly when the user has least context
    # to spare. Phrasing it as what happens AFTER the handoff makes it one
    # sequence instead. It travels in `reason` because that is the channel
    # demonstrated to reach Claude.
    setup_hint=" After the handoff, run handoff:setup to correct this."
    # NO LONGER A HEDGE — it was measured. On 2026-08-18 a firing carrying both
    # fields was watched from the user's own terminal: the reason arrived as
    # `PostToolUse:Bash hook returned blocking error ...` and this string
    # arrived as a separate `PostToolUse:Bash says: handoff: ...` line.
    # systemMessage IS honoured alongside a decision on PostToolUse. Earlier
    # comments here called that unresolvable from inside a session, and they
    # were right — it took a human watching the screen.
    #
    # Both assignments sit INSIDE the wflag gate deliberately: they ride the
    # once-per-session note rather than every over-window firing. Keep them here
    # as further keys are added — @test "the hedge and the deferred hint ride the
    # once-per-session note" in handoff/tests/context-guard.bats pins the placement, and
    # moving either out of this gate turns that test red.
    sysmsg_setup=" Observed context (${ctx} tokens) exceeds the configured window (${WINDOW} tokens) — run handoff:setup to correct it."
  fi
fi

# Which is named when both are crossed: the absolute one. It is the more
# specific statement and it is the value the user set deliberately. Nothing is
# lost by the choice — the percentage rides in the same sentence — and a wrong
# window still surfaces independently through the misconfiguration note, which
# is unaffected by which tripwire fired.
if [ "$abs_fired" -eq 1 ]; then
  headline="session context is at ${ctx} tokens, past the ${THRESHOLD_TOKENS}-token limit (${pct}% of the ${WINDOW}-token window)"
else
  headline="session context is at ${pct}% of the ${WINDOW}-token window (threshold ${THRESHOLD_PCT}%)"
fi

# "record the work" rather than "commit and push the work": this instruction is
# emitted by a hook firing, so nothing here was asked for by the developer, and an
# instruction to write to git history or to a shared remote is not one an
# unprompted hook gets to give. The skill now records the uncommitted state in the
# document and prints the commands instead. Keep the word "handoff" in this string
# — tests pin it, and it is how Claude finds the skill.
reason="CONTEXT GUARD: ${headline}. Finish ONLY the current atomic step — do NOT start the next batch or task. Then invoke the handoff skill (handoff:handoff): record the work, write the handoff document, print the resume prompt for the user, and stop. Do NOT commit or push — the skill leaves git alone.${misconfig}${setup_hint}"

# REDUNDANCY ACROSS MECHANISMS, which is the whole point of issue #2. Everything
# above reaches Claude through `decision`, and the hooks reference states plainly
# that PostToolUse has no decision control — "This event has no decision control
# fields." It works anyway, verified repeatedly. But the plugin's entire payload
# riding a path the documentation says does not exist is fine until it isn't, and
# the failure mode if it is ever withdrawn is the worst one available here: the
# guard emits into a void, silently, and nobody learns that it stopped.
#
# `systemMessage` IS documented — "Warning message shown to the user" — and was
# measured arriving on 2026-08-18 as its own `PostToolUse:Bash says:` line while
# a decision was present in the same emission. So the warning now travels both:
# the path that is observed to reach Claude, and the path that is documented to
# reach the user. One being withdrawn no longer produces silence.
#
# Deliberately shorter than `reason`. This one is read by a human mid-task, not
# parsed by a model, and the full instruction paragraph would be noise on a
# terminal line.
sysmsg="handoff: ${headline}. Finish the current step, then run handoff:handoff.${sysmsg_setup}"

jq -n --arg reason "$reason" --arg sysmsg "$sysmsg" \
  '{decision:"block", reason:$reason, systemMessage:$sysmsg}'
exit 0
