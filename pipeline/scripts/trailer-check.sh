#!/usr/bin/env bash
# trailer-check.sh — the one rule for a commit trailer the run may carry.
#
# Usage: trailer-check.sh <trailer as a JSON string>
#
# preflight.sh runs it on each --trailer before the run starts, and
# progress.sh runs it on each recorded trailer before every commit. Both
# invoke THIS file; neither keeps a copy of the rule (constitution,
# principle IV: two hand-kept copies had already drifted, one accepting a
# C1 control character the other refused).
#
# The argument is JSON so that every character reaches the checks: a shell
# argument cannot hold NUL, and the state file's reader strips CR.
#
# Exit 0 and print the trailer, raw, with no newline: it is acceptable.
# Exit 1 and print, on stderr, the trailer and the reason it is refused:
# the caller puts its own frame around that. A trailer holding a control
# character is shown as JSON, so the refusal never prints the character
# itself to a terminal: a control character, and every character in
# HIDDEN_CHARS (hidden-chars.sh), is printed as its \u escape. Exit 2: the
# call itself is wrong.
#
# The tools are jq alone, run once: preflight.sh's tests run this with a
# PATH that holds jq and grep only, and each process costs time on Windows
# (about 4.5 s per trailer when it took six).
set -euo pipefail
export LC_ALL=C

[ $# -eq 1 ] || { printf 'trailer-check.sh: usage: trailer-check.sh <trailer as a JSON string>\n' >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { printf 'trailer-check.sh: jq is required and was not found on PATH\n' >&2; exit 2; }
here="${BASH_SOURCE[0]}"
case "$here" in */*) here="${here%/*}" ;; *) here=. ;; esac
# HIDDEN_CHARS: the characters that can disguise text, the same list
# progress.sh refuses in a question.
# shellcheck source-path=SCRIPTDIR source=hidden-chars.sh
. "$here/hidden-chars.sh" || { printf 'trailer-check.sh: cannot read hidden-chars.sh beside this script\n' >&2; exit 2; }

# One jq call reads the argument and answers with one tab-separated line:
# `bad` when it is not one JSON string; `lb`, `cntrl` or `hidden` and the
# trailer shown as JSON when it holds a line break, a control character
# (C0, DEL and C1, by jq's Unicode classes) or a character from
# HIDDEN_CHARS; else `ok`, the trailer and its lower-case form. tojson
# escapes C0 and DEL; every C1 or HIDDEN_CHARS character is escaped here
# too, as \uXXXX (a surrogate pair above U+FFFF), so none reaches a
# terminal. An `ok` trailer holds no tab, so the line splits cleanly.
# shellcheck disable=SC2016 # a jq program: its $ names are jq's
out="$(jq -j -n --argjson s "$1" '
  def hex4: [(. / 4096 | floor) % 16, (. / 256 | floor) % 16, (. / 16 | floor) % 16, . % 16]
    | map("0123456789abcdef"[. : . + 1]) | join("");
  def esc: if . > 65535 then (. - 65536) as $v
      | [55296 + ($v / 1024 | floor), 56320 + ($v % 1024)] | map("\\u" + hex4) | join("")
    else "\\u" + hex4 end;
  def hidden: test("'"$HIDDEN_CHARS"'");
  if ($s | type) != "string" then "bad"
  else
    ($s | tojson | explode
      | map(if . >= 128 and (. < 160 or ([.] | implode | hidden)) then esc else [.] | implode end)
      | join("")) as $shown
    | if ($s | test("[\r\n]")) then "lb\t" + $shown
      elif ($s | test("[[:cntrl:]]")) then "cntrl\t" + $shown
      elif ($s | hidden) then "hidden\t" + $shown
      else "ok\t" + $s + "\t" + ($s | ascii_downcase) end
  end' 2>/dev/null)" || out=bad
kind="${out%%$'\t'*}"; rest="${out#*$'\t'}"
[ "$kind" != bad ] || { printf 'trailer-check.sh: the argument is not one JSON string\n' >&2; exit 2; }
shown="$rest"
no() { printf '%s %s\n' "$shown" "$*" >&2; exit 1; }

# A line break gets its own reason, because a trailer is one line.
case "$kind" in
  lb)     no "holds a line break; a trailer is one line" ;;
  cntrl)  no "holds a control character" ;;
  hidden) no "holds a character that can disguise text in a terminal (a bidi, invisible or zero-width character, a variation selector, a tag character, or a byte-order mark)" ;;
  ok)     ;;
  *)      printf 'trailer-check.sh: jq gave no verdict\n' >&2; exit 2 ;;
esac
t="${rest%$'\t'*}"; lc="${rest##*$'\t'}"
shown="'$t'"
case "$t" in *:*) ;; *) no "has no ':'; write <token>: <value>" ;; esac
token="${t%%:*}"
# The token starts with a letter, ends with a letter or a digit, and holds
# letters, digits and dash: git strips a token's trailing non-alphanumerics,
# so `---` or `Piece-` would be read as another token.
case "$token" in
  ""|*[!A-Za-z0-9-]*|[!A-Za-z]*|*[!A-Za-z0-9]|?)
    no "has the token '$token'; a token starts with a letter, ends with a letter or a digit, and holds letters, digits and dash only" ;;
esac
case "${t#*:}" in *[![:space:]]*) ;; *) no "has an empty value" ;; esac
# Piece, Late and Tasks are the run's own markers: its crash scans read
# those lines as records, and progress.sh writes them itself. The rest
# would act on GitHub or claim another person's work: skip-checks and the
# [skip ci] family hide the pull request's checks, Co-authored-by and
# Signed-off-by name someone who did not write the commit, On-behalf-of
# attributes it to an organisation, and a closing keyword closes an issue
# on merge.
case "${lc%%:*}" in
  piece|late|tasks) no "uses the token '$token', reserved for the run's own markers" ;;
  skip-checks|co-authored-by|signed-off-by|on-behalf-of|close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)
    no "uses the token '$token', which acts on GitHub or names another author" ;;
esac
case "$lc" in
  *'[skip ci]'*|*'[ci skip]'*|*'[no ci]'*|*'[skip actions]'*|*'[actions skip]'*)
    no "asks GitHub to skip the checks" ;;
esac
# A closing keyword anywhere in the trailer, the token included (Will-Fix,
# X-Closes), before an issue in any form GitHub reads: #1, owner/repo#1,
# GH-1 or the issue's URL, with or without a colon or a space between.
closes='(^|[^a-z0-9_])(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]*(([a-z0-9_.-]+/[a-z0-9_.-]+)?#[0-9]|gh-[0-9]|https?://[^[:space:]]*/issues/[0-9])'
if [[ $lc =~ $closes ]]; then
  no "would close an issue"
fi
printf '%s' "$t"
