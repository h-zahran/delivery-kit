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
usage() { die "usage: team.sh [--dir <repo>] <config | roster <team> | tasks <team> <member> | suggest <team> | iam <team> <member> | whoami | status <team> <member> | next <team> <member> | command <team> <member> <id> | render <team> <member>>"; }

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

TEAM_KEYS=" roster tasks progressView "

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
    for k in roster tasks progressView; do
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
            elif ($t.seed | test("[\r\n]")) then "task \($id): seed holds a line break; the pipeline line is one line"
            elif ($t | has("blocked")) and (($t.blocked | type) != "string") then "task \($id): blocked is not a string"
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
                      trailers: (.trailers // []), flags: (.flags // []), blocked: (.blocked // "")}]' -- "$f"
}

# --- who is at the keyboard --------------------------------------------------
# The answer lives in .delivery-kit/team.json: per clone, never committed.
# It is asked once by team:start. git's email only SUGGESTS it: two people
# can share a machine, and one person can commit under several emails.
ME_FILE=".delivery-kit/team.json"

cmd_suggest() {
  local team="${1:-}" members email
  [ -n "$team" ] || usage
  members="$(cmd_roster "$team")"
  email="$(git config user.email 2>/dev/null || true)"
  jq -c --arg e "$email" '{email: $e, matches: (if $e == "" then [] else
      [.[] | select(.emails | map(ascii_downcase) | index($e | ascii_downcase)) | .id] end)}' <<<"$members"
}

cmd_iam() {
  local team="${1:-}" member="${2:-}" members rc=0
  [ -n "$team" ] && [ -n "$member" ] || usage
  members="$(cmd_roster "$team")"
  [ "$(jq -r --arg m "$member" 'any(.[]; .id == $m)' <<<"$members")" = "true" ] \
    || die "no member '$member' in team '$team'"
  # Written only where git ignores it: a tracked answer would be one
  # member's name in every clone, and a changed tree stops the pipeline.
  git check-ignore -q "$ME_FILE" 2>/dev/null || rc=$?
  case "$rc" in
    0) ;;
    1) die "$ME_FILE is not ignored by git; add .delivery-kit/ to .gitignore first" ;;
    *) die "cannot ask git whether $ME_FILE is ignored" ;;
  esac
  mkdir -p "${ME_FILE%/*}"
  jq -n --arg t "$team" --arg m "$member" '{team: $t, member: $m}' > "$ME_FILE"
  jq -c . -- "$ME_FILE"
}

cmd_whoami() {
  local me team member
  [ -f "$ME_FILE" ] || die "no member chosen yet in $ME_FILE; team:start asks once"
  me="$(read_json "identity file" "$ME_FILE")"
  team="$(jq -r '.team // empty | strings' <<<"$me")"
  member="$(jq -r '.member // empty | strings' <<<"$me")"
  [ -n "$team" ] && [ -n "$member" ] || die "identity file '$ME_FILE' has no team or member; delete it and run team:start"
  # Checked against today's roster: a member can leave a team.
  [ "$(cmd_roster "$team" | jq -r --arg m "$member" 'any(.[]; .id == $m)')" = "true" ] \
    || die "identity file '$ME_FILE' names '$member', who is not in team '$team' now; delete it and run team:start"
  jq -c '{team, member}' <<<"$me"
}

# --- where each task stands --------------------------------------------------
# Status is READ, never stored: the pull request, the run's state file, and
# the branch, on this machine and on origin. A stored status would drift
# from git, and git is what a reviewer checks. Each fact names its source,
# and a source that could not be read is reported as not read, never
# taken as "no".

remote_read=false; remote_heads=""; pr_read=false; prs='[]'; gh_cmd=""

gather() {
  local out c
  if git remote get-url origin >/dev/null 2>&1 \
     && out="$(git ls-remote --heads origin 2>/dev/null)"; then
    remote_read=true
    remote_heads="$(printf '%s\n' "$out" | tr -d '\r' | sed -n 's#^[0-9a-f]*[[:space:]]*refs/heads/##p')"
  fi
  # Probed under three names, as the pipeline's pre-flight does.
  for c in gh gh.exe gh.cmd; do
    if command -v "$c" >/dev/null 2>&1; then gh_cmd="$c"; break; fi
  done
  if [ -n "$gh_cmd" ] \
     && out="$("$gh_cmd" pr list --state all --limit 1000 --json headRefName,state,url 2>/dev/null)" \
     && out="$(printf '%s' "$out" | tr -d '\r' | jq -c 'if type == "array" then . else error end' 2>/dev/null)"; then
    pr_read=true; prs="$out"
  fi
}

cmd_status() {
  local team="${1:-}" member="${2:-}" tasks n i t branch spec run_file run phase run_pr lb rb pr rows
  [ -n "$team" ] && [ -n "$member" ] || usage
  tasks="$(cmd_tasks "$team" "$member")"
  gather
  rows='[]'
  n="$(jq -r 'length' <<<"$tasks")"; i=0
  while [ "$i" -lt "$n" ]; do
    t="$(jq -c --argjson i "$i" '.[$i]' <<<"$tasks")"; i=$((i + 1))
    branch="$(jq -r '.branch' <<<"$t")"; spec="$(jq -r '.specDir' <<<"$t")"
    run_file=".delivery-kit/runs/${spec##*/}/progress.json"
    run=false; phase=""; run_pr=""
    if [ -f "$run_file" ]; then
      run=true
      phase="$(jq -r '.current_phase // "" | strings' -- "$run_file" 2>/dev/null || true)"
      run_pr="$(jq -r '.pr_url // "" | strings' -- "$run_file" 2>/dev/null || true)"
    fi
    lb=false; git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null && lb=true
    rb=false; [ "$remote_read" = true ] && printf '%s\n' "$remote_heads" | grep -Fxq -- "$branch" && rb=true
    pr="$(jq -c --arg b "$branch" '[.[] | select(.headRefName == $b)] | first // null' <<<"$prs")"
    rows="$(jq -c --argjson t "$t" --argjson run "$run" --arg phase "$phase" --arg runpr "$run_pr" \
      --argjson lb "$lb" --argjson rb "$rb" --argjson pr "$pr" '
      . + [ $t + (
        if $pr != null and $pr.state == "MERGED" then {status: "done", source: "pull request", pr: $pr.url}
        elif $pr != null and $pr.state == "OPEN" then {status: "in review", source: "pull request", pr: $pr.url}
        elif $runpr != "" then {status: "in review", source: "run state", pr: $runpr}
        elif $t.blocked != "" then {status: "blocked", source: "task file", pr: ""}
        elif $run then {status: "in progress", source: "run state", pr: ""}
        elif $lb then {status: "in progress", source: "local branch", pr: ""}
        elif $rb then {status: "in progress", source: "origin branch", pr: ""}
        else {status: "not started", source: "", pr: ""} end
        + {run: $run, phase: $phase, localBranch: $lb, originBranch: $rb,
           prClosed: ($pr != null and $pr.state == "CLOSED")}) ]' <<<"$rows")"
  done
  jq -c --arg team "$team" --arg m "$member" --argjson rr "$remote_read" --argjson pr "$pr_read" \
    '{team: $team, member: $m, originRead: $rr, prRead: $pr, tasks: .}' <<<"$rows"
}

# The next task, in file order. A task in progress comes before a new one:
# resumed when this machine holds its run, reported when only a branch
# shows it, because a fresh start would fight the work already there.
cmd_next() {
  local team="${1:-}" member="${2:-}"
  [ -n "$team" ] && [ -n "$member" ] || usage
  cmd_status "$team" "$member" | jq -c '
    [.tasks[] | select(.status == "in progress" or .status == "not started")] | first as $t
    | if $t == null then {action: "none", task: null}
      elif $t.status == "not started" then {action: "start", task: $t}
      elif $t.run then {action: "resume", task: $t}
      else {action: "elsewhere", task: $t} end'
}

# The /pipeline line for one task: the seed first, then the task's names,
# its trailers, and its own flags as written. A value with anything but
# plain characters is double-quoted, with " and \ escaped.
cmd_command() {
  local team="${1:-}" member="${2:-}" id="${3:-}" t
  [ -n "$team" ] && [ -n "$member" ] && [ -n "$id" ] || usage
  t="$(cmd_tasks "$team" "$member" | jq -c --arg id "$id" '[.[] | select(.id == $id)] | first // empty')"
  [ -n "$t" ] || die "no task '$id' for member '$member' in team '$team'"
  jq -r '
    def q: if test("^[A-Za-z0-9._/:@=+,-]+$") then . else "\"" + gsub("(?<c>[\"\\\\])"; "\\\(.c)") + "\"" end;
    "/pipeline " + ("\"" + (.seed | gsub("(?<c>[\"\\\\])"; "\\\(.c)")) + "\"")
    + " --branch " + (.branch | q) + " --spec-dir " + (.specDir | q)
    + ([.trailers[] | " --trailer " + q] | join(""))
    + ([.flags[] | " " + q] | join(""))' <<<"$t"
}

# The readable copy: a markdown table written from the status, never
# edited by hand. It is written only when asked, into the path the team
# block names, for the person who asked to commit.
cmd_render() {
  local team="${1:-}" member="${2:-}" cfg entry f st name
  [ -n "$team" ] && [ -n "$member" ] || usage
  cfg="$(cmd_config)"
  entry="$(team_entry "$cfg" "$team")"
  f="$(jq -r '.progressView // empty' <<<"$entry")"
  [ -n "$f" ] || die "team '$team' has no 'progressView'; add it with team:setup"
  f="${f//\{member\}/$member}"
  st="$(cmd_status "$team" "$member")"
  name="$(cmd_roster "$team" | jq -r --arg m "$member" '.[] | select(.id == $m) | .name')"
  mkdir -p "$(dirname -- "$f")"
  jq -r --arg name "$name" --arg day "$(date -u +%Y-%m-%d)" '
    def cell: tostring | gsub("[\r\n]+"; " ") | gsub("\\|"; "\\|");
    def code: if . == "" then "" else "`" + cell + "`" end;
    "# \($name) — progress",
    "",
    "> Written by `team:status` from git\(if .prRead then " and the pull requests" else "" end) on \($day). Do not edit by hand: run `team:status` again.",
    (if .originRead then empty else "> origin was not read: a branch pushed from another machine is not shown." end),
    (if .prRead then empty else "> Pull requests were not read: a merged task shows as in progress or in review." end),
    "",
    "| No. | Task | Title | Status | Branch | PR | Note |",
    "|---|---|---|---|---|---|---|",
    (.tasks[] | "| \(.number | cell) | \(.id | code) | \(.title | cell) | \(.status) | \(if .status == "not started" then "" else (.branch | code) end) | \(.pr | cell) | \(.blocked | cell) |")
  ' <<<"$st" > "$f"
  jq -nc --arg f "$f" '{written: $f}'
}

case "${1:-}" in
  config) cmd_config ;;
  roster) cmd_roster "${2:-}" ;;
  tasks)  cmd_tasks "${2:-}" "${3:-}" ;;
  suggest) cmd_suggest "${2:-}" ;;
  iam)    cmd_iam "${2:-}" "${3:-}" ;;
  whoami) cmd_whoami ;;
  status) cmd_status "${2:-}" "${3:-}" ;;
  next)   cmd_next "${2:-}" "${3:-}" ;;
  command) cmd_command "${2:-}" "${3:-}" "${4:-}" ;;
  render) cmd_render "${2:-}" "${3:-}" ;;
  *) usage ;;
esac
