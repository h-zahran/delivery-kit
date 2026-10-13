#!/usr/bin/env bash
# context-guard.sh — handoff PostToolUse hook.
#
# Computes current context usage from the session transcript and, once it
# crosses the configured threshold, emits a blocking instruction telling Claude
# to finish the current atomic step and invoke the handoff skill. Re-warns once
# per bucket thereafter: 5% of the window, or thresholdTokens when smaller.
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

# A threshold of 100 OR ABOVE could only be reached once context has already
# reached the window, which is far too late to be useful — so in practice the
# guard would never fire in time again, silently, which is the one thing
# configuration must not be able to do. Nothing downstream can catch it:
# the window-misconfiguration report runs only once the guard has already
# decided to fire.
#
# 100 is the value this rule exists for, and the reason the comparison is
# `-lt` rather than `-le`: "warn me at 100%" reads like a deliberate choice
# and disarms the guard just as completely as a typo. Pinned both ways by the
# boundary tests in handoff/tests/context-guard.bats: 100 refused, 99 accepted.
# Why: scripts/context-guard/README.md, "Threshold of 100, measured".
is_valid_threshold() {
  is_positive_int "$1" && [ "$1" -lt 100 ]
}

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
# call per field: this runs after EVERY tool call, and process spawn dominates
# on Windows under Git Bash, which is a supported platform.
# Why: scripts/context-guard/README.md, "Payload extraction, measured".
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
#
# THE DRAIN AFTER A FAILED CALL IS NOT BELT AND BRACES. jq reads to end of
# input only while the input keeps parsing: handed something malformed at its
# FIRST token it aborts at once, having read a buffer's worth and no more. The
# caller is then writing into a pipe nobody is reading, and dies of a broken
# pipe: exit 141, measured on a ~300KB payload. The branch runs only when jq
# exits non-zero, so the ordinary run pays nothing for it.
# Why: scripts/context-guard/README.md, "Payload extraction, measured".
#
# jq is a hard dependency: the hook parses the stdin payload and a JSONL
# transcript, and reimplementing that in POSIX shell would be fragile exactly
# where correctness matters. Without jq the guard cannot run — and a guard
# that silently never fires is the failure this project exists to prevent.
# Say so once, then stay out of the way. Detection runs jq rather than
# looking it up on PATH: a jq that cannot execute is no more use than none.
#
# THE PROBE RUNS ONLY AFTER THIS CALL FAILS. A jq that cannot run fails this
# call too, so asking `jq --version` only then reaches every jq the old probe
# reported, and a malformed payload pays one extra process where the ordinary
# run pays none. The test is `jq --version` failing and NOT a table of exit
# codes: a jq that dies on a missing library, or a shim that exits 1, is just
# as unable to run, and a rule that missed one would leave the guard silent
# with no hint.
# Why: scripts/context-guard/README.md, "Payload extraction, measured".
#
# stderr goes to /dev/null on this call now, and that is a change. With jq
# missing, bash prints "jq: command not found" from inside the substitution, so
# without the redirect every tool call would print it, where the probe it
# replaces said nothing and the hint says it once. The redirect also hides
# jq's own parse error on a malformed payload, which used to reach stderr.
# Nothing reads this hook's stderr, and the differential never compares it.
#
# CONSUME STDIN BEFORE LEAVING, AND THAT IS LOAD BEARING. A reader that exits
# without reading leaves the caller writing into a closed pipe: measured on a
# ~200KB payload, the writer dies at exit 141. A jq that cannot start reads
# nothing, so the `cat` below drains the payload BEFORE the hint and its
# `exit 0`, on the same branch that drains it for a payload jq could not
# parse. Do not move the hint above it because the guard is exiting anyway:
# what it protects is the caller, not this hook.
# Why: scripts/context-guard/README.md, "Payload extraction, measured".
#
# The configuration program: the four settings of ONE file, in a fixed order,
# joined by the separator. Written once and spent twice: by read_config below,
# and inside the payload call for the user-level file.
CONFIG_JQ='.contextGuard // {} | [.windowTokens, .thresholdPct, .thresholdTokens, .maxBytes] | map(. // "" | tostring) | join($US)'

# THE USER-LEVEL FILE IS READ BY THE PAYLOAD CALL, NOT BY A JQ OF ITS OWN. Its
# path needs only HOME, which is known before the payload is, so it rides that
# call with --rawfile and saves one process on every tool call where it
# exists. The repository file keeps its own read: its path needs the payload's
# cwd. Precedence is untouched: the payload call only CARRIES the user file's
# four values, and they are validated and applied below, in the same order as
# before — user, repository, environment.
# Why: scripts/context-guard/README.md, "Configuration reader, measured".
#
# THE CONFIGURATION HALF IS TOTAL, AND THAT IS LOAD BEARING. A failed payload
# call is how this hook detects a missing jq, so an error from the user file
# would silence the guard. Its text is parsed with `fromjson?`, never trusted;
# the four values come from CONFIG_JQ inside a `try` whose catch is the four
# empty values a failing read gave before. A file that is not exactly ONE JSON
# text (empty, `{not json`, two documents, trailing garbage, or holding a NUL
# byte, which some jq builds cut at) sets the first field, and the old reader
# reads it again below: jq's file parser keeps the documents before an error,
# which fromjson cannot reproduce. A missing, unreadable or directory path is
# never handed to jq at all. And if the file vanishes or locks between the
# test and jq's open, jq exits 2 before it reads stdin, so the call is made
# again without it and the file goes to the old reader.
#
# The user half comes LAST, five fields that never hold the separator: the
# re-read flag, then the four values split as the old reader split them, with
# a maxBytes that held the separator (invalid either way) emptied. They are
# taken off the END, so the payload half before them is the old string, byte
# for byte, and is split by the four lines it always was. The `lf` strips its
# trailing newlines, which $( ) stripped while it was last. maxBytes is last
# now, so $( ) strips it as it stripped the old reader's last field.
PAYLOAD_JQ='def lf: if endswith("\n") then rtrimstr("\n") | lf else . end;
([.agent_id // "", .transcript_path // "", .session_id // "unknown", .cwd // ""] | map(tostring) | join($US) | lf)
+ $US
+ ( if $ucfg == null then ["", "", "", "", ""]
    elif ($ucfg | index([0] | implode)) then ["1", "", "", "", ""]
    else [$ucfg | fromjson?]
      | if length == 0 then ["1", "", "", "", ""]
        else .[0] | try ('"$CONFIG_JQ"' | split($US) | ["", .[0], .[1], .[2], (if length > 4 then "" else .[3] end)])
                    catch ["", "", "", "", ""]
        end
    end
  | join($US) )'
user_config="$HOME/.delivery-kit.json"
if [ -f "$user_config" ] && [ -r "$user_config" ]; then
  user_args=(--rawfile ucfg "$user_config")
else
  user_args=(--argjson ucfg null)
fi
payload=$(jq -r --arg US "$US" "${user_args[@]}" "$PAYLOAD_JQ" 2>/dev/null)
rc=$?
user_lost=""
if [ "$rc" -eq 2 ] && [ "${user_args[0]}" = --rawfile ]; then
  user_lost=1
  payload=$(jq -r --arg US "$US" --argjson ucfg null "$PAYLOAD_JQ" 2>/dev/null)
  rc=$?
fi
if [ "$rc" -ne 0 ]; then
  cat > /dev/null 2>&1
  if ! jq --version >/dev/null 2>&1; then
    hint_flag="${TMPDIR:-${TEMP:-/tmp}}/dk-jq-hint"
    if [ ! -f "$hint_flag" ]; then
      : 2>/dev/null > "$hint_flag"
      printf '%s\n' '{"systemMessage":"handoff: the context guard is disabled because jq is not installed or cannot run. Install it (macOS: brew install jq | Debian/Ubuntu: sudo apt-get install jq | Windows: winget install jqlang.jq) and restart the session."}'
    fi
    exit 0
  fi
fi
user_max_bytes=${payload##*"$US"};  payload=${payload%"$US"*}
user_tokens=${payload##*"$US"};     payload=${payload%"$US"*}
user_threshold=${payload##*"$US"};  payload=${payload%"$US"*}
user_window=${payload##*"$US"};     payload=${payload%"$US"*}
user_reread=${payload##*"$US"};     payload=${payload%"$US"*}
[ -z "$user_lost" ] || user_reread=1
agent_id=${payload%%"$US"*};  rest=${payload#*"$US"}
transcript=${rest%%"$US"*};   rest=${rest#*"$US"}
session=${rest%%"$US"*}
cwd=${rest#*"$US"}

# Inside a subagent this hook is handed the PARENT's transcript_path and the
# PARENT's session_id, indistinguishable from the main-chain calls around
# them except for two fields, agent_id and agent_type; agent_id is read here.
# Why: scripts/context-guard/README.md, "Subagent payloads, measured".
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
  # Claude Code's cwd can be a subdirectory of the repository, so look at the
  # top of the work tree: the nearest folder above cwd holding a `.git` file
  # (a linked worktree or submodule) or `.git` folder. Only cwd and that top
  # are read, never a folder between them, as when this asked git.
  #
  # Walked in the shell, not `git rev-parse --show-toplevel`: that spawned
  # git on every tool call in the zero-config case. The string is walked with
  # ${walk%/*}, never `cd ..`, which in Git Bash alternates between / and //
  # forever. On Windows ($OSTYPE msys or cygwin), a cwd written with
  # backslashes (after a drive letter, or a \\host\share) is made forward
  # first, as git -C took both. Elsewhere a backslash is part of a folder's
  # name, git -C kept it, and so does the walk.
  #
  # What counts is what git counts. A `.git` file is a top only when it says
  # `gitdir: `; git refuses any other, and answers nothing. A `.git` folder
  # counts only when it is a git directory: objects and refs folders, and a
  # HEAD that reads `ref: refs/...` or an object id. An empty `.git` folder
  # does not, and git climbs past it. A folder that is itself a git directory
  # (a bare repository, or inside .git) has no work tree and the walk stops
  # with no top, as git did. One shape differs: in a submodule's git
  # directory (.git/modules/<name>) git names the submodule's work tree
  # through core.worktree, and the walk finds no top. Folders are followed as
  # written, never resolved: git follows a symbolic link to the real folder.
  # Claude Code's cwd is a real path, so the two agree there.
  toplevel="" walk=$cwd bs=\\
  case $OSTYPE in
    msys*|cygwin*) case $walk in [A-Za-z]:*|"$bs$bs"*) walk=${walk//"$bs"//} ;; esac ;;
  esac
  case $walk in /*|[A-Za-z]:*) ;; *) walk=$PWD/$walk ;; esac
  if [ -d "$walk" ]; then
    while [ "$walk" != "${walk%/}" ]; do walk=${walk%/}; done
    while :; do
      if [ -f "$walk/.git" ]; then
        gitline=""; IFS= read -r gitline 2>/dev/null < "$walk/.git"
        case $gitline in "gitdir: "*) toplevel=${walk:-/} ;; esac
        break
      fi
      gitstop=""
      for gitdir in "$walk/.git" "$walk"; do
        [ -f "$gitdir/HEAD" ] && [ -d "$gitdir/objects" ] && [ -d "$gitdir/refs" ] || continue
        gitline=""; IFS= read -r gitline 2>/dev/null < "$gitdir/HEAD"
        case $gitline in
          "ref: refs/"*) ;;
          ''|*[!0-9a-f]*) continue ;;
          *) [ "${#gitline}" -eq 40 ] || [ "${#gitline}" -eq 64 ] || continue ;;
        esac
        gitstop=$gitdir; break
      done
      if [ "$gitstop" = "$walk/.git" ]; then toplevel=${walk:-/}; break; fi
      [ -z "$gitstop" ] || break
      [ -n "$walk" ] && [ "${walk%/*}" != "$walk" ] || break
      walk=${walk%/*}
    done
  fi
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

# One validator for both files, so the two cannot drift into applying different
# validation — which would let an invalid value disable the guard from
# whichever file was checked less carefully. A missing file is not an error:
# both are optional and zero-config is the supported case.
#
# If HOME is unset the path becomes "/.delivery-kit.json", which will not
# exist, so the `-f` test skips it. Under Git Bash on Windows HOME is set to
# the user profile, which is the intended location; that shell is where this
# project has already been bitten once by a TEMP-versus-TMPDIR difference, so
# it is called out rather than assumed.
#
# apply_config <window> <threshold> <tokens> <max-bytes> — validates each value
# on its own and installs only the valid ones, so an invalid value in a later
# file never shadows a valid one from an earlier file.
apply_config() {
  is_positive_int "$1" && WINDOW=$1
  is_valid_threshold "$2" && THRESHOLD_PCT=$2
  # No upper bound, unlike the threshold above. That cap exists because a
  # percentage of 100 or above can only be reached once context has already filled
  # the window, so it is unreachable by construction; a token count has no such
  # ceiling — it is a number about the user's model, and any positive value is a
  # setting somebody could legitimately mean. The arithmetic ceiling documented
  # at is_positive_int still rejects an out-of-range value like any other
  # invalid input.
  is_positive_int "$3" && THRESHOLD_TOKENS=$3
  is_positive_int "$4" && MAX_BYTES=$4
  # Insurance, not a live fix, and no test covers it — stated plainly so the
  # next reader does not go looking for the bug it prevents. The last
  # conditional fails whenever maxBytes is absent, which is the ordinary case,
  # so without this the function would usually return 1. Nothing today notices:
  # the hook sets neither `set -e` nor `set -u`, and every call site below
  # ignores the status. Removing the line leaves the suite green. It earns its
  # place against the caller that does read $? — a `&&` chain, a `set -e` added
  # later — where a function returning 1 on its SUCCESS path is a trap. Keep it
  # last as keys are added above it.
  return 0
}

# read_config <file> — the repository file's reader, and the user file's when
# the payload call could not parse it as one JSON text.
read_config() {
  [ -f "$1" ] || return 0
  # ONE jq call for all four settings, not one per setting. Same reasoning as
  # the payload extraction above, and the same two traps: the separator must
  # not be IFS-whitespace, and the result must be one line.
  #
  # The trap is QUIETER here than it is up there, which makes it worse.
  # Every value below is a positive integer, so a value that lands in the
  # wrong slot PASSES validation and is installed: with thresholdPct absent,
  # a tab-split installs maxBytes as thresholdTokens, with no error.
  # Why: scripts/context-guard/README.md, "Configuration reader, measured".
  #
  # tostring after the empty default (in CONFIG_JQ, above): these are JSON
  # numbers. The local jq joins numbers without help, but CI runs a different
  # one, and this project has already been bitten by an analyser version gap of
  # exactly that shape. One token of jq buys out the question.
  #
  # Split with parameter expansion for the reason the payload block gives:
  # `read` stops at the first newline, and a JSON string value may contain
  # one.
  # Why: scripts/context-guard/README.md, "Configuration reader, measured".
  cfg=$(jq -r --arg US "$US" "$CONFIG_JQ" "$1" 2>/dev/null)
  cfg_window=${cfg%%"$US"*};      r=${cfg#*"$US"}
  cfg_threshold=${r%%"$US"*};     r=${r#*"$US"}
  cfg_tokens=${r%%"$US"*}
  cfg_max_bytes=${r#*"$US"}
  apply_config "$cfg_window" "$cfg_threshold" "$cfg_tokens" "$cfg_max_bytes"
}

# Applied in precedence order. Reading the same path twice, when a repository
# happens to sit at HOME, is idempotent and needs no guard.
if [ "$user_reread" = 1 ]; then
  read_config "$user_config"
else
  apply_config "$user_window" "$user_threshold" "$user_tokens" "$user_max_bytes"
fi
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
# early (the 2026-08-07 incident). 15 and not 5, because such a tool inflates
# four to six CONSECUTIVE entries, which fill a 5-wide window: 15 outvotes a
# run of 7.
# Why: scripts/context-guard/README.md, "The median window, measured".
#
# Ingestion is per-line with `fromjson?` rather than a slurp: Claude Code
# appends to this file while we read it, and `jq -s` aborts the entire parse
# on the first torn line, leaving ctx empty and the guard silently disabled.
# Per-line parsing skips the bad line and keeps the guard alive.
#
# The tail is a budget in LINES while the median needs fifteen READINGS: tool
# results, user turns and sidechain lines consume it without yielding one,
# and at 300 the window could clip every honest reading. 5000 leaves room for
# several subagent fan-outs between readings, and `.[-15:]` below takes the
# last fifteen MATCHING entries. A budget in lines does not bound WORK, and a
# hook killed by its timeout emits nothing: hence the byte cap below.
# Why: scripts/context-guard/README.md, "The median window, measured".
#
# Run once per read, up to three times on the starved path, so it is written
# once here rather than at each read, where the copies would drift and only one
# would be tested.
#
# READINGS_JQ IS THE PER-LINE RULE AND NOTHING ELSE.
#
# THE FINAL `select` IS NOT COSMETIC. jq's `+` concatenates STRINGS, so a
# usage record whose three token fields are ALL strings yields a string, and
# jq sorts every string AFTER every number: without this line that junk lands
# inside the fifteen-wide window and pushes the median onto a LARGER reading.
# Dropping it diverges from the pre-refactor hook; every divergence is a
# correction, and the differential asserts each.
# Why: scripts/context-guard/README.md, "Divergences in the per-line rule".
#
# handoff/skills/setup/SKILL.md carries the same program so it can
# claim to measure the way this guard measures, and the suite pins the two
# character for character. Collecting the readings into this variable would
# have broken that coupling: the two files wrap this rule DIFFERENTLY — the
# guard needs the count as well as the median, the skill needs only the
# median — so the rule is what they can share and the wrapper is not.
READINGS_JQ='fromjson?
  | select(.isSidechain != true)
  | select(.message.usage.input_tokens != null)
  | .message.usage
  | (.input_tokens + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))
  | select(type == "number")'

# MEDIAN_JQ IS ALSO WRITTEN TWICE, for the same reason and with the same pin.
# handoff/skills/setup/SKILL.md computes the number it proposes a window from,
# and it must be THIS median or its proposal describes a rule nothing enforces.
# It is a named variable in both files rather than an expression buried in a
# larger program, so the suite can compare the two character for character and
# a drift at either site goes red.
MEDIAN_JQ='.[-15:] | sort | .[(length/2|floor)] // 0'

# The count and the median come from ONE pass over the same list, composed
# here ONCE and spent at both call sites below.
#
# THE `?` AFTER THE PER-LINE PIPELINE IS LOAD BEARING. Streaming jq treats a
# runtime error as an error on THAT INPUT and carries on with the next line.
# Collect the same pipeline into an array and the error kills the whole
# program, so jq emits NOTHING: every reading lost, ctx empty, and the guard
# silent, which is the one direction this hook must never fail in.
# Why: scripts/context-guard/README.md, "The count rule, measured".
#
# NO REGEX, AND THAT IS DELIBERATE. This was `test("^[0-9]")` for one commit.
# `test` needs a jq built with its regular-expression library, this is the only
# regex in any program the hook ships, and the availability probe beside the
# payload call cannot detect a missing FEATURE — a compile error would yield an
# empty summary, a count of zero, a fallback, and a guard that says nothing.
# Every FINITE number's text form begins with a digit or a minus sign, so
# refusing the minus sign is the same test with no dependency.
#
# jq calls a NaN a number and renders it "null", so `startswith` counts it
# where the original grep did not. It is left standing: a NaN can only make
# the count LARGER, which can only skip the uncapped re-read, and that re-read
# returns the same last fifteen whenever the capped read holds fifteen at all.
# Changing the answer would need a NaN AND a starved cap, and a token count is
# a sum of integers with no route to a NaN.
#
# `select(. >= 0)` is NOT equivalent: -0.0 is >= 0, but its text form "-0"
# was never counted by the old `grep -c '^[0-9]'`.
#
# THE COUNT IS NOT `length`, AND THAT IS LOAD BEARING TOO. The `grep -c` it
# replaces counted lines BEGINNING WITH A DIGIT, so a negative reading is
# excluded from the count and included in the median. The cap may never
# change the answer, so this reproduces the rule rather than improving it.
# ONE PLACE WHERE THAT IS NOT QUITE TRUE: junk is not counted either, so where
# the old count cleared the floor on junk alone, this falls back. A divergence
# from the old rule, fail-safe, and the differential asserts it.
# Why: scripts/context-guard/README.md, "The count rule, measured".
#
# -R is raw INPUT and says nothing about output. Without -r the join comes back
# as a JSON string with the separator spelled as an escape, the split below
# finds no separator byte, and the whole string lands in the count. All three
# of -R, -r and -n are required.
SUMMARY_JQ="[ inputs | ( $READINGS_JQ )? ]
| [ (map(select(tostring | startswith(\"-\") | not)) | length)
  , ( $MEDIAN_JQ )
  ]
| map(tostring) | join(\$US)"

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
# That fallback is NOT free, and the timeout in hooks.json is 30 because of
# this path. A cap that also bounded the fallback would be faster and
# occasionally wrong.
#
# THE READ CLIMBS: 1MB FIRST, THEN maxBytes, THEN UNCAPPED, and it stops at
# the first rung holding fifteen readings. Every rung is a byte suffix of the
# same file, so a rung holding fifteen readings has the same last fifteen as
# the uncapped read, and the answer cannot depend on which rung gave it.
# Why: scripts/context-guard/README.md, "The read ladder, measured".
#
# The 1MB is a literal, not a setting. maxBytes keeps its meaning as the
# largest capped read; a maxBytes at or under 1MB is the only capped read, so
# `maxBytes: 1` still means what it always meant and no size is read twice.
FIRST_BYTES=1000000

# read_summary <bytes> — one rung: the last <bytes> of the transcript, then the
# 5000-line window, through SUMMARY_JQ. An empty <bytes> is the uncapped read.
# Sets summary and count.
#
# Split with parameter expansion, never `read`, for the reason spelled out at
# the payload extraction above: `read` stops at the first newline and would
# drop the field after it.
#
# A count that is not a run of digits means STARVED, never satisfied, and the
# direction is the whole point. The `grep -c` this replaces could not fail —
# it always printed a number. One field of a joined string can be empty or
# malformed, and an unusable value would make the comparison below error out
# and evaluate FALSE, skipping the uncapped re-read. Skipping it is precisely
# the 2026-08-07 failure the re-read was added to close, so a broken count must
# fall back rather than press on.
read_summary() {
  if [ -n "$1" ]; then
    summary=$(tail -c "$1" "$transcript" | tail -n 5000 | jq -Rrn --arg US "$US" "$SUMMARY_JQ" 2>/dev/null)
  else
    summary=$(tail -n 5000 "$transcript" | jq -Rrn --arg US "$US" "$SUMMARY_JQ" 2>/dev/null)
  fi
  count=${summary%%"$US"*}
  case $count in
    ''|*[!0-9]*) count=0 ;;
  esac
}

# A RUNG THAT HELD THE WHOLE FILE IS NOT READ AGAIN. One `wc -c` decides it,
# and it runs only after a rung has starved, so the ordinary call never pays
# for it.
#
# THE SIZE IS MEASURED AFTER THE READ IT VOUCHES FOR, and again after the next
# one. Claude Code appends while the hook runs, and the file only grows: a
# size taken AFTER a read is at least what that read saw, so "size <= cap"
# proves the read held the whole file. A size taken BEFORE a read proves
# nothing about it. A transcript truncated in place would defeat this; Claude
# Code has never been seen to do that.
# Why: scripts/context-guard/README.md, "The read ladder, measured".
#
# THE SIZE CAN ONLY STOP A CLIMB, NEVER START ONE, and an unknown size climbs.
# A size that is empty or holds no digits leaves `covered` false, so every rung
# is read as before — the direction this hook must fail in. The test is `-le`:
# `tail -c N` on a file of exactly N bytes returns all of it. One byte more and
# the first byte is cut, the first line no longer parses, and its reading is
# lost, which is why the differential pins the edge at N+1.
#
# wc pads its number with spaces on macOS; only the digits are kept.
measure_size() {
  size=$(wc -c < "$transcript" 2>/dev/null)
  size=${size//[!0-9]/}
}
covered() {
  [ -n "$size" ] && [ "$size" -le "$1" ]
}

first=$FIRST_BYTES
[ "$MAX_BYTES" -lt "$first" ] && first=$MAX_BYTES
read_summary "$first"
if [ "$count" -lt 15 ]; then
  measure_size
  if ! covered "$first"; then
    if [ "$MAX_BYTES" -gt "$first" ]; then
      read_summary "$MAX_BYTES"
      if [ "$count" -lt 15 ]; then
        measure_size
        covered "$MAX_BYTES" || read_summary ""
      fi
    else
      read_summary ""
    fi
  fi
fi

# Derived ONCE, after the fallback has had its say, rather than either side of
# the branch. Both derivations would have to be kept in step with the
# separator by hand, and the pre-fallback one would hold a value that is about
# to be thrown away on the starved path. An empty summary yields an empty ctx
# here exactly as it did there, and the emptiness test below still exits.
ctx=${summary#*"$US"}

[ -n "$ctx" ] && [ "$ctx" -gt 0 ] 2>/dev/null || exit 0

pct=$(( ctx * 100 / WINDOW ))

# Warn once per 5% bucket (45, 50, 55, ...) so Claude is re-nudged if it
# keeps working past the first warning, without one warning per tool call.
#
# THE BUCKET IS THE SMALLER OF 5% OF THE WINDOW AND thresholdTokens (audit
# H12). With a window far larger than the model's, 5% of it can be millions
# of tokens: at a 100M window and thresholdTokens 400000 the guard warned at
# 400000 and then stayed silent until 5000000. When thresholdTokens is under
# 5% of the window, the buckets are thresholdTokens wide instead: 400000,
# 800000, 1200000. Compared as WINDOW / 20, never thresholdTokens * 20, which
# could overflow. Otherwise the bucket is exactly pct / 5, as before, so a
# window that matches the model warns where it always did. Every rule below
# counts in buckets, so the drop rule and the jitter guard hold either way.
bucket=$(( pct / 5 ))
if [ -n "$THRESHOLD_TOKENS" ] && [ "$THRESHOLD_TOKENS" -lt $(( WINDOW / 20 )) ]; then
  bucket=$(( ctx / THRESHOLD_TOKENS ))
fi
flagdir="${TMPDIR:-${TEMP:-/tmp}}"
flag="$flagdir/ctx-warned-$session"
last_bucket=$(cat "$flag" 2>/dev/null)
# An unusable flag value means "never warned", not "stop warning". Without
# this, an empty or corrupt flag makes the comparison error out and the
# `|| exit 0` below silences the guard for the rest of the session.
#
# The sentinel is -1, not 0, because 0 is a real bucket: it covers everything
# below one bucket (5% of the window, or thresholdTokens when smaller). With
# 0 standing for "never warned", the gate below
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
# INVARIANT: ctx > WINDOW implies pct >= 100, which implies bucket >= 20 (with
# token buckets, bucket >= WINDOW / thresholdTokens, which is above 20). The
# threshold gate cannot block that, because is_valid_threshold admits no
# threshold of 100 or above — the highest it accepts is 99. So pct here does
# not merely MEET the highest admissible threshold, it strictly EXCEEDS it.
# The invariant held by equality while the cap was 100 and now holds with a
# margin; tightening the rule made this argument stronger, never weaker. So
# the note rides an emission rather than needing one of its own.
#
# One exception, and it is deliberate: a reading landing exactly on WINDOW
# records its bucket (20, or WINDOW / thresholdTokens with token buckets)
# without the note, because the test below is strict and
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
    # systemMessage IS honoured alongside a decision on PostToolUse: that
    # was measured, so this is no longer a hedge.
    # Why: scripts/context-guard/README.md, "systemMessage, measured".
    #
    # Both assignments sit INSIDE the wflag gate deliberately: they ride the
    # once-per-session note rather than every over-window firing. Keep them here
    # as further keys are added — @test "the hedge and the deferred hint ride the
    # once-per-session note" in handoff/tests/context-guard.bats pins the placement, and
    # moving either out of this gate turns that test red.
    sysmsg_setup=" Observed context (${ctx} tokens) exceeds the configured window (${WINDOW} tokens) — run /handoff:setup to correct it."
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
# `systemMessage` IS documented ("Warning message shown to the user"), so
# the warning travels both: the path observed to reach Claude, and the path
# documented to reach the user. One being withdrawn no longer produces
# silence.
# Why: scripts/context-guard/README.md, "systemMessage, measured".
#
# Deliberately shorter than `reason`. This one is read by a human mid-task, not
# parsed by a model, and the full instruction paragraph would be noise on a
# terminal line.
sysmsg="handoff: ${headline}. Finish the current step, then run /handoff:handoff.${sysmsg_setup}"

jq -n --arg reason "$reason" --arg sysmsg "$sysmsg" \
  '{decision:"block", reason:$reason, systemMessage:$sysmsg}'
exit 0
