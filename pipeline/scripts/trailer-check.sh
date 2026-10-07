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
# itself to a terminal. Exit 2: the call itself is wrong.
#
# The tools are jq and grep only: preflight.sh's tests run it with a PATH
# that holds nothing else.
set -euo pipefail
export LC_ALL=C

[ $# -eq 1 ] || { printf 'trailer-check.sh: usage: trailer-check.sh <trailer as a JSON string>\n' >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { printf 'trailer-check.sh: jq is required and was not found on PATH\n' >&2; exit 2; }
jq -e -n --argjson s "$1" '$s | type == "string"' >/dev/null 2>&1 \
  || { printf 'trailer-check.sh: the argument is not one JSON string\n' >&2; exit 2; }

# tojson escapes C0 and DEL but leaves the C1 range raw; those are escaped
# here too, so no control character reaches a terminal.
shown="$(jq -j -n --argjson s "$1" '
  def hex4: [(. / 4096 | floor) % 16, (. / 256 | floor) % 16, (. / 16 | floor) % 16, . % 16]
    | map("0123456789abcdef"[. : . + 1]) | join("");
  $s | tojson | explode
  | map(if . >= 128 and . < 160 then "\\u" + hex4 else [.] | implode end) | join("")')"
no() { printf '%s %s\n' "$shown" "$*" >&2; exit 1; }

# Control characters, read by jq, whose classes are Unicode: CR, LF, NUL,
# ESC, TAB and the C1 range (U+0080-U+009F, NEL among them) alike. A line
# break gets its own reason, because a trailer is one line.
jq -e -n --argjson s "$1" '$s | test("[\r\n]") | not' >/dev/null \
  || no "holds a line break; a trailer is one line"
jq -e -n --argjson s "$1" '$s | test("[[:cntrl:]]") | not' >/dev/null \
  || no "holds a control character"

t="$(jq -j -n --argjson s "$1" '$s')"
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
lc="$(jq -j -n --arg t "$t" '$t | ascii_downcase')"
# Piece, Late and Tasks are the run's own markers: its crash scans read
# those lines as records, and progress.sh writes them itself. The rest
# would act on GitHub or claim another person's work: skip-checks and the
# [skip ci] family hide the pull request's checks, Co-authored-by and
# Signed-off-by name someone who did not write the commit, and a closing
# keyword closes an issue on merge.
case "${lc%%:*}" in
  piece|late|tasks) no "uses the token '$token', reserved for the run's own markers" ;;
  skip-checks|co-authored-by|signed-off-by|close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)
    no "uses the token '$token', which acts on GitHub or names another author" ;;
esac
case "$lc" in
  *'[skip ci]'*|*'[ci skip]'*|*'[no ci]'*|*'[skip actions]'*|*'[actions skip]'*)
    no "asks GitHub to skip the checks" ;;
esac
if printf '%s\n' "${lc#*:}" | grep -Eq '(^|[^a-z0-9_])(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]+([a-z0-9_.-]+/[a-z0-9_.-]+)?#[0-9]'; then
  no "would close an issue"
fi
printf '%s' "$t"
