#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for team/scripts/team.sh — the reader for the team block, the
# roster and the task file. Every test builds its own scratch repository,
# so nothing here depends on this checkout's own settings.

load ../../tests/helper

setup() {
  TEAM_SH="$ROOT/team/scripts/team.sh"
  R="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$R/plan/alpha/ann" "$R/plan/alpha/bo"
  cat > "$R/.delivery-kit.json" <<'JSON'
{
  "pipeline": { "planFile": "plan.md" },
  "team": {
    "teams": {
      "alpha": {
        "roster": "plan/alpha/roster.json",
        "tasks": "plan/alpha/{member}/tasks.json",
        "progress": "plan/alpha/{member}/progress.json",
        "progressView": "plan/alpha/{member}/progress.md"
      }
    }
  }
}
JSON
  cat > "$R/plan/alpha/roster.json" <<'JSON'
{ "members": [
  { "id": "ann", "name": "Ann Example", "emails": ["ann@example.com"] },
  { "id": "bo", "name": "Bo Example" }
] }
JSON
  cat > "$R/plan/alpha/ann/tasks.json" <<'JSON'
{ "tasks": [
  { "id": "T-1", "number": "001", "title": "First", "branch": "ann/alpha/001-T-1-first",
    "specDir": "specs/alpha/ann/001-T-1-first", "seed": "Do the first thing.",
    "trailers": ["Plan-Item: T-1"], "flags": ["--implementer", "claude"] },
  { "id": "T-2", "branch": "ann/alpha/002-T-2-second",
    "specDir": "specs/alpha/ann/002-T-2-second", "seed": "Do the second thing." }
] }
JSON
}

# team <args...> — runs the script against the scratch repository.
team() { run --separate-stderr bash "$TEAM_SH" --dir "$R" "$@"; }

# set_json <file> <jq filter> — edits one scratch file in place.
set_json() { local t; t="$(jq "$2" "$R/$1")"; printf '%s\n' "$t" > "$R/$1"; }

# refused <text...> — the last run failed, and stderr holds every text.
refused() {
  [ "$status" -ne 0 ] || { echo "accepted; stdout: $output"; return 1; }
  local t
  for t in "$@"; do
    [[ "$stderr" == *"$t"* ]] || { echo "stderr lacks: $t"; echo "stderr: $stderr"; return 1; }
  done
}

@test "config: a good team block is printed as JSON, the pipeline block left out" {
  team config
  [ "$status" -eq 0 ]
  [ "$(jq -r '.teams.alpha.tasks' <<<"$output")" = "plan/alpha/{member}/tasks.json" ]
  [ "$(jq -r 'has("pipeline")' <<<"$output")" = "false" ]
}

@test "config: progressView may be left out" {
  set_json .delivery-kit.json 'del(.team.teams.alpha.progressView)'
  team config
  [ "$status" -eq 0 ]
}

@test "config: a missing or broken settings file is named" {
  printf '{ not json' > "$R/.delivery-kit.json"
  team config
  refused "'.delivery-kit.json' is not valid JSON"
  rm "$R/.delivery-kit.json"
  team config
  refused "'.delivery-kit.json' does not exist"
}

@test "config: no team block, or a block that names no team, points at team:setup or names the fault" {
  set_json .delivery-kit.json 'del(.team)'
  team config
  refused "no 'team' object" "team:setup"
  set_json .delivery-kit.json '.team = {teams: {}}'
  team config
  refused "names no team"
  set_json .delivery-kit.json '.team = {teams: []}'
  team config
  refused "team.teams" "is not an object"
}

@test "config: a team key that cannot be a path segment is refused, naming it" {
  set_json .delivery-kit.json '.team.teams["a b"] = .team.teams.alpha'
  team config
  refused "team key 'a b'"
}

@test "config: an unknown key in a team is refused, naming it" {
  # A misspelt key would otherwise be silently ignored.
  set_json .delivery-kit.json '.team.teams.alpha.taks = "x"'
  team config
  refused "unknown key 'taks'"
}

@test "config: each required path must be there and be a string" {
  local k
  for k in roster tasks progress; do
    setup
    set_json .delivery-kit.json "del(.team.teams.alpha.$k)"
    team config
    refused "team 'alpha' has no '$k'" || { echo "case: $k missing"; false; }
    setup
    set_json .delivery-kit.json ".team.teams.alpha.$k = 3"
    team config
    refused "'$k' is not a string" || { echo "case: $k not a string"; false; }
  done
}

@test "config: a path outside the repository or under .delivery-kit/ is refused, naming it" {
  # One case per check. Each value passes every check but its own.
  local bad
  for bad in '/abs/{member}/t.json' 'C:/x/{member}/t.json' 'x\y/{member}/t.json' \
             'x/../{member}/t.json' './x/{member}/t.json' 'x//{member}/t.json' \
             '.delivery-kit/{member}/t.json'; do
    setup
    set_json .delivery-kit.json ".team.teams.alpha.tasks = $(jq -Rn --arg b "$bad" '$b')"
    team config
    refused "'$bad'" || { echo "case: $bad"; false; }
  done
}

@test "config: the roster holds no {member}, and the member files each hold one" {
  set_json .delivery-kit.json '.team.teams.alpha.roster = "plan/{member}/roster.json"'
  team config
  refused "'roster'" "must not hold {member}"
  local k
  for k in tasks progress progressView; do
    setup
    set_json .delivery-kit.json ".team.teams.alpha.$k = \"plan/alpha/shared.json\""
    team config
    refused "'$k'" "must hold {member}" || { echo "case: $k"; false; }
  done
}

@test "roster: the members are printed, emails defaulting to an empty list" {
  team roster alpha
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.[].id]' <<<"$output")" = '["ann","bo"]' ]
  [ "$(jq -c '.[1].emails' <<<"$output")" = '[]' ]
}

@test "roster: an unknown team is refused, naming the teams there are" {
  team roster beta
  refused "no team 'beta'" "alpha"
}

@test "roster: a malformed roster is refused, naming the fault" {
  local f='plan/alpha/roster.json' filter want n=0
  while IFS='|' read -r filter want <&4; do
    n=$((n + 1))
    setup
    set_json "$f" "$filter"
    team roster alpha
    refused "$want" || { echo "case: $filter"; false; }
  done 4<<'CASES'
del(.members)|has no 'members' list
.members = []|lists no member
.members[0] = 3|member 0 is not an object
del(.members[0].id)|member 0 has no string id
del(.members[1].name)|member 1 (bo) has no name
.members[1].name = "  "|member 1 (bo) has no name
.members[0].emails = "a@b"|member 0 (ann): emails is not a list of strings
.members[0].emails = [3]|member 0 (ann): emails is not a list of strings
.members[0].id = "a/b"|member id 'a/b'
.members[1].id = "ann"|member id 'ann' appears twice
CASES
  [ "$n" -eq 10 ] || { echo "ran $n of 10 cases"; false; }
}

@test "tasks: a member's tasks are printed in file order, with defaults filled" {
  team tasks alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.[].id]' <<<"$output")" = '["T-1","T-2"]' ]
  [ "$(jq -c '.[0].trailers' <<<"$output")" = '["Plan-Item: T-1"]' ]
  [ "$(jq -c '.[0].flags' <<<"$output")" = '["--implementer","claude"]' ]
  [ "$(jq -c '.[1] | [.number, .title, .trailers, .flags]' <<<"$output")" = '["","",[],[]]' ]
}

@test "tasks: {member} is replaced with the member's id" {
  # bo has no task file. The message names the path the member's id made.
  team tasks alpha bo
  refused "'plan/alpha/bo/tasks.json' does not exist"
}

@test "tasks: a member not in the roster is refused" {
  team tasks alpha cy
  refused "no member 'cy' in team 'alpha'"
}

@test "tasks: a malformed task file is refused, naming the fault" {
  local f='plan/alpha/ann/tasks.json' filter want n=0
  while IFS='|' read -r filter want <&4; do
    n=$((n + 1))
    setup
    set_json "$f" "$filter"
    team tasks alpha ann
    refused "$want" || { echo "case: $filter"; false; }
  done 4<<'CASES'
del(.tasks)|has no 'tasks' list
.tasks[0] = 3|task 0 is not an object
del(.tasks[0].id)|task 0 has no id
del(.tasks[0].branch)|task T-1 has no branch
.tasks[0].branch = " "|task T-1 has no branch
del(.tasks[0].specDir)|task T-1 has no specDir
del(.tasks[0].seed)|task T-1 has no seed
.tasks[0].title = 3|task T-1: title is not a string
.tasks[0].number = 1|task T-1: number is not a string
.tasks[0].trailers = "Plan-Item: T-1"|task T-1: trailers is not a list of strings
.tasks[0].flags = [1]|task T-1: flags is not a list of strings
.tasks[1].id = "T-1"|task id 'T-1' appears twice
CASES
  [ "$n" -eq 12 ] || { echo "ran $n of 12 cases"; false; }
}

@test "an unknown command prints the usage" {
  team frobnicate
  refused "usage: team.sh"
}
