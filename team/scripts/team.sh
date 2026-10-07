#!/usr/bin/env bash
# team.sh — reads and checks the team plugin's three inputs: the `team`
# block in the repository's .delivery-kit.json, a team's roster file, and a
# member's task file.
#
# PURE JSON on stdout, every diagnostic on stderr: the contract the
# pipeline plugin's scripts state in full. This script only READS. Asking,
# writing the settings, and running the pipeline are the skills' work.
#
# It checks SHAPE only: that each value is there and has the right type.
# What a value MEANS is checked once, where it is used: the pipeline's
# pre-flight checks a branch name, a spec folder and a trailer. A second
# copy of those rules here would drift from the first.
#
# jq here may be a native Windows binary with text-mode stdout: this
# script reads jq only through command substitution and exit codes. A
# roster or a task file is read by its path, never through a herestring:
# Git Bash hangs a herestring of about 64 KB (recorded in the pipeline's
# preflight.sh), and a task file with many seeds can reach that size.
set -euo pipefail
unset CDPATH GREP_OPTIONS
export LC_ALL=C

die()  { printf 'team.sh: %s\n' "$*" >&2; exit 1; }
usage() { die "usage: team.sh [--dir <repo>] <config|roster <team>|tasks <team> <member>>"; }

command -v jq >/dev/null 2>&1 || die "jq is required and was not found on PATH"

dir="."
if [ "${1:-}" = "--dir" ]; then dir="${2:?--dir needs a path}"; shift 2; fi
cd "$dir" 2>/dev/null || die "cannot enter '$dir'"

# A team key and a member id become path segments, so they hold the same
# characters a run name may hold.
name_ok() { case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac; }

# A path in the team block is relative to the repository root, written one
# way, and outside the pipeline's state directory. $1 names it in messages.
path_ok() {
  local what="$1" p="$2"
  case "$p" in
    '') die "$what is empty" ;;
    /*|[A-Za-z]:*) die "$what '$p' is not relative to the repository root" ;;
    *\\*) die "$what '$p' holds a backslash; separate folders with /" ;;
  esac
  case "/$p/" in
    */../*) die "$what '$p' climbs out with .." ;;
    */./*|*//*) die "$what '$p' has an empty or . segment" ;;
    /.delivery-kit/*) die "$what '$p' is inside the state directory .delivery-kit/" ;;
  esac
}

# Reads one JSON file. A missing file and a file that is not JSON are two
# different faults, and each is named.
read_json() {
  local what="$1" f="$2" out
  [ -f "$f" ] || die "$what '$f' does not exist"
  out="$(jq -c . -- "$f" 2>/dev/null)" || die "$what '$f' is not valid JSON"
  printf '%s' "$out"
}

TEAM_KEYS=" roster tasks progress progressView "

cmd_config() {
  local cfg team keys k entry v
  cfg="$(read_json "settings file" ".delivery-kit.json")"
  [ "$(jq -r '.team | type' <<<"$cfg")" = "object" ] \
    || die "settings file '.delivery-kit.json' has no 'team' object; run team:setup"
  [ "$(jq -r '.team.teams | type' <<<"$cfg")" = "object" ] \
    || die "team.teams in '.delivery-kit.json' is not an object"
  [ "$(jq -r '.team.teams | length' <<<"$cfg")" -gt 0 ] \
    || die "team.teams in '.delivery-kit.json' names no team"
  # Walked by index, never by word-splitting a list: a key may hold a space.
  local i=0 n
  n="$(jq -r '.team.teams | length' <<<"$cfg")"
  while [ "$i" -lt "$n" ]; do
    team="$(jq -r --argjson i "$i" '.team.teams | keys[$i]' <<<"$cfg")"
    i=$((i + 1))
    name_ok "$team" || die "team key '$team' — letters, digits, dot, dash, underscore only"
    entry="$(jq -c --arg t "$team" '.team.teams[$t]' <<<"$cfg")"
    [ "$(jq -r 'type' <<<"$entry")" = "object" ] || die "team '$team' is not an object"
    k="$(jq -r --arg legal "$TEAM_KEYS" '[keys[] | select(. as $k | $legal | split(" ") | map(select(. != "")) | index($k) | not)] | first // empty' <<<"$entry")"
    [ -z "$k" ] || die "team '$team' has an unknown key '$k' (legal:${TEAM_KEYS% })"
    for k in roster tasks progress progressView; do
      [ "$(jq -r --arg k "$k" 'has($k)' <<<"$entry")" = "true" ] || {
        [ "$k" = "progressView" ] && continue
        die "team '$team' has no '$k'"
      }
      [ "$(jq -r --arg k "$k" '.[$k] | type' <<<"$entry")" = "string" ] \
        || die "team '$team': '$k' is not a string"
      v="$(jq -r --arg k "$k" '.[$k]' <<<"$entry")"
      path_ok "team '$team': '$k'" "$v"
      case "$k:$v" in
        roster:*'{member}'*) die "team '$team': 'roster' '$v' must not hold {member}; one roster serves the whole team" ;;
        roster:*) ;;
        *:*'{member}'*) ;;
        *) die "team '$team': '$k' '$v' must hold {member}; each member has their own file" ;;
      esac
    done
  done
  jq -c '{teams: .team.teams}' <<<"$cfg"
}

# The team's entry from the checked block.
team_entry() {
  local cfg="$1" team="$2"
  [ "$(jq -r --arg t "$team" '.teams | has($t)' <<<"$cfg")" = "true" ] \
    || die "no team '$team' in '.delivery-kit.json' (teams: $(jq -r '.teams | keys | join(", ")' <<<"$cfg"))"
  jq -c --arg t "$team" '.teams[$t]' <<<"$cfg"
}

cmd_roster() {
  local team="${1:-}" cfg entry f bad
  [ -n "$team" ] || usage
  cfg="$(cmd_config)"
  entry="$(team_entry "$cfg" "$team")"
  f="$(jq -r '.roster' <<<"$entry")"
  read_json "roster" "$f" >/dev/null
  [ "$(jq -r '.members | type' -- "$f")" = "array" ] || die "roster '$f' has no 'members' list"
  [ "$(jq -r '.members | length' -- "$f")" -gt 0 ] || die "roster '$f' lists no member"
  # The first fault, in file order, named by its position and field.
  bad="$(jq -r '
    [ .members | to_entries[] | .key as $i | .value as $m
      | if ($m | type) != "object" then "member \($i) is not an object"
        elif ($m.id | type) != "string" then "member \($i) has no string id"
        elif ($m.name | type) != "string" or ($m.name | test("\\S") | not) then "member \($i) (\($m.id)) has no name"
        elif ($m | has("emails")) and (($m.emails | type) != "array" or ([$m.emails[] | type] - ["string"] | length) > 0)
          then "member \($i) (\($m.id)): emails is not a list of strings"
        else empty end
    ] | first // empty' -- "$f")"
  [ -z "$bad" ] || die "roster '$f': $bad"
  bad="$(jq -r '[.members[].id | select(test("^[A-Za-z0-9._-]+$") | not)] | first // empty' -- "$f")"
  [ -z "$bad" ] || die "roster '$f': member id '$bad' — letters, digits, dot, dash, underscore only"
  bad="$(jq -r '[.members[].id] | group_by(.) | map(select(length > 1) | .[0]) | first // empty' -- "$f")"
  [ -z "$bad" ] || die "roster '$f': member id '$bad' appears twice"
  jq -c '[.members[] | {id, name, emails: (.emails // [])}]' -- "$f"
}

cmd_tasks() {
  local team="${1:-}" member="${2:-}" cfg entry members f bad
  [ -n "$team" ] && [ -n "$member" ] || usage
  members="$(cmd_roster "$team")"
  [ "$(jq -r --arg m "$member" 'any(.[]; .id == $m)' <<<"$members")" = "true" ] \
    || die "no member '$member' in team '$team'"
  cfg="$(cmd_config)"
  entry="$(team_entry "$cfg" "$team")"
  f="$(jq -r '.tasks' <<<"$entry")"
  f="${f//\{member\}/$member}"
  read_json "task file" "$f" >/dev/null
  [ "$(jq -r '.tasks | type' -- "$f")" = "array" ] || die "task file '$f' has no 'tasks' list"
  bad="$(jq -r '
    def str($k): (.[$k] | type) == "string" and (.[$k] | test("\\S"));
    def strs($k): (has($k) | not) or ((.[$k] | type) == "array" and ([.[$k][] | type] - ["string"] | length) == 0);
    [ .tasks | to_entries[] | .key as $i | .value as $t
      | if ($t | type) != "object" then "task \($i) is not an object"
        elif ($t | str("id") | not) then "task \($i) has no id"
        else ($t.id) as $id
          | if ($t | str("branch") | not) then "task \($id) has no branch"
            elif ($t | str("specDir") | not) then "task \($id) has no specDir"
            elif ($t | str("seed") | not) then "task \($id) has no seed"
            elif ($t | has("title")) and (($t.title | type) != "string") then "task \($id): title is not a string"
            elif ($t | has("number")) and (($t.number | type) != "string") then "task \($id): number is not a string"
            elif ($t | strs("trailers") | not) then "task \($id): trailers is not a list of strings"
            elif ($t | strs("flags") | not) then "task \($id): flags is not a list of strings"
            else empty end
        end
    ] | first // empty' -- "$f")"
  [ -z "$bad" ] || die "task file '$f': $bad"
  bad="$(jq -r '[.tasks[].id] | group_by(.) | map(select(length > 1) | .[0]) | first // empty' -- "$f")"
  [ -z "$bad" ] || die "task file '$f': task id '$bad' appears twice"
  jq -c '[.tasks[] | {id, number: (.number // ""), title: (.title // ""), branch, specDir, seed,
                      trailers: (.trailers // []), flags: (.flags // [])}]' -- "$f"
}

case "${1:-}" in
  config) cmd_config ;;
  roster) cmd_roster "${2:-}" ;;
  tasks)  cmd_tasks "${2:-}" "${3:-}" ;;
  *) usage ;;
esac
