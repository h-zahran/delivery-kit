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
  # A misspelt key would otherwise be silently ignored. `progress` was a
  # key in an unreleased draft; status is now read from git, never stored.
  set_json .delivery-kit.json '.team.teams.alpha.taks = "x"'
  team config
  refused "unknown key 'taks'"
  setup
  set_json .delivery-kit.json '.team.teams.alpha.progress = "plan/alpha/{member}/progress.json"'
  team config
  refused "unknown key 'progress'"
}

@test "config: each required path must be there and be a string" {
  local k
  for k in roster tasks; do
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
  for k in tasks progressView; do
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
  [ "$(jq -c '.[1] | [.number, .title, .trailers, .flags, .blocked]' <<<"$output")" = '["","",[],[],""]' ]
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
.tasks[0].seed = "two\nlines"|task T-1: seed holds a line break
.tasks[0].blocked = true|task T-1: blocked is not a string
CASES
  [ "$n" -eq 14 ] || { echo "ran $n of 14 cases"; false; }
}

# --- who is at the keyboard ---------------------------------------------------

# repo_git — makes the scratch repository a git repository that ignores
# .delivery-kit/, as a repository the pipeline has run in does.
repo_git() {
  git -C "$R" init -q -b work
  git -C "$R" config user.email "${1:-}"
  git -C "$R" config user.name tester
  printf '.delivery-kit/\n' > "$R/.gitignore"
}

@test "suggest: the git email is matched to the roster, ignoring letter case" {
  repo_git 'ANN@Example.com'
  team suggest alpha
  [ "$status" -eq 0 ]
  [ "$(jq -c '.matches' <<<"$output")" = '["ann"]' ]
  git -C "$R" config user.email 'nobody@example.com'
  team suggest alpha
  [ "$(jq -c '.matches' <<<"$output")" = '[]' ]
}

@test "iam: the answer is written only where git ignores it, and whoami reads it back" {
  repo_git 'ann@example.com'
  rm "$R/.gitignore"
  team iam alpha ann
  refused ".delivery-kit/team.json is not ignored by git"
  [ ! -e "$R/.delivery-kit/team.json" ]
  printf '.delivery-kit/\n' > "$R/.gitignore"
  team iam alpha ann
  [ "$status" -eq 0 ]
  team whoami
  [ "$status" -eq 0 ]
  [ "$(jq -c . <<<"$output")" = '{"team":"alpha","member":"ann"}' ]
}

@test "iam: a member not in the roster is refused" {
  repo_git 'ann@example.com'
  team iam alpha cy
  refused "no member 'cy' in team 'alpha'"
}

@test "whoami: no answer yet, or an answer the roster no longer holds, points at team:start" {
  repo_git 'ann@example.com'
  team whoami
  refused "no member chosen yet" "team:start"
  mkdir -p "$R/.delivery-kit"
  printf '{"team":"alpha","member":"cy"}\n' > "$R/.delivery-kit/team.json"
  team whoami
  refused "'cy', who is not in team 'alpha' now" "team:start"
  printf '{"team":"alpha"}\n' > "$R/.delivery-kit/team.json"
  team whoami
  refused "has no team or member"
}

# --- where each task stands --------------------------------------------------

# status_fixture — five tasks for ann, one per way a status is read, and an
# origin that holds one branch.
status_fixture() {
  repo_git 'ann@example.com'
  cat > "$R/plan/alpha/ann/tasks.json" <<'JSON'
{ "tasks": [
  { "id": "T-1", "number": "001", "title": "Has a run with a PR", "branch": "ann/T-1", "specDir": "specs/ann/001-T-1", "seed": "One." },
  { "id": "T-2", "number": "002", "title": "Has a local branch", "branch": "ann/T-2", "specDir": "specs/ann/002-T-2", "seed": "Two." },
  { "id": "T-3", "number": "003", "title": "Has an origin branch", "branch": "ann/T-3", "specDir": "specs/ann/003-T-3", "seed": "Three." },
  { "id": "T-4", "number": "004", "title": "Is blocked", "branch": "ann/T-4", "specDir": "specs/ann/004-T-4", "seed": "Four.", "blocked": "waits for | the API" },
  { "id": "T-5", "number": "005", "title": "Not started", "branch": "ann/T-5", "specDir": "specs/ann/005-T-5", "seed": "Five." }
] }
JSON
  git -C "$R" add -A && git -C "$R" commit -q -m init
  git -C "$R" branch ann/T-2
  git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
  git -C "$R" remote add origin "$BATS_TEST_TMPDIR/origin.git"
  git -C "$R" push -q origin work:ann/T-3
  mkdir -p "$R/.delivery-kit/runs/001-T-1"
  printf '{"current_phase":"M","pr_url":"https://example.com/pr/1"}\n' > "$R/.delivery-kit/runs/001-T-1/progress.json"
  # A gh that fails, so no real gh on this machine is asked anything.
  FAKE="$BATS_TEST_TMPDIR/fake"; mkdir -p "$FAKE"
  printf '#!/bin/sh\nexit 1\n' > "$FAKE/gh"; chmod +x "$FAKE/gh"
}

# fake_prs <json> — the fake gh prints this list of pull requests.
fake_prs() {
  printf '%s\n' "$1" > "$BATS_TEST_TMPDIR/prs.json"
  printf '#!/bin/sh\ncat "%s"\n' "$BATS_TEST_TMPDIR/prs.json" > "$FAKE/gh"
}

# team_fake <args...> — runs the script with the fake gh first on PATH.
team_fake() { run --separate-stderr env PATH="$FAKE:$PATH" bash "$TEAM_SH" --dir "$R" "$@"; }

@test "status: each task's status comes from the run, a branch, the task file, or nothing" {
  status_fixture
  team_fake status alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.tasks[] | [.id, .status, .source]]' <<<"$output")" = \
    '[["T-1","in review","run state"],["T-2","in progress","local branch"],["T-3","in progress","origin branch"],["T-4","blocked","task file"],["T-5","not started",""]]' ]
  [ "$(jq -c '[.originRead, .prRead]' <<<"$output")" = '[true,false]' ]
  [ "$(jq -r '.tasks[0].pr' <<<"$output")" = "https://example.com/pr/1" ]
}

@test "status: a pull request beats every other source, and a closed one is not done" {
  status_fixture
  fake_prs '[{"headRefName":"ann/T-1","state":"MERGED","url":"u1"},{"headRefName":"ann/T-2","state":"OPEN","url":"u2"},{"headRefName":"ann/T-3","state":"CLOSED","url":"u3"}]'
  team_fake status alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.tasks[0:3][] | [.status, .source, .pr]]' <<<"$output")" = \
    '[["done","pull request","u1"],["in review","pull request","u2"],["in progress","origin branch",""]]' ]
  [ "$(jq -c '[.prRead, .tasks[2].prClosed]' <<<"$output")" = '[true,true]' ]
}

@test "status: without origin, origin is reported as not read, never as empty" {
  status_fixture
  git -C "$R" remote remove origin
  team_fake status alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.originRead, .tasks[2].status]' <<<"$output")" = '[false,"not started"]' ]
}

@test "next: a run on this machine is resumed before anything new starts" {
  status_fixture
  rm "$R/.delivery-kit/runs/001-T-1/progress.json"
  mkdir -p "$R/.delivery-kit/runs/002-T-2"
  printf '{"current_phase":"H"}\n' > "$R/.delivery-kit/runs/002-T-2/progress.json"
  team_fake next alpha ann
  [ "$status" -eq 0 ]
  # T-1 now has nothing: not started. T-2 comes later in the file, but the
  # first task that is not started or in progress is T-1.
  [ "$(jq -c '[.action, .task.id]' <<<"$output")" = '["start","T-1"]' ]
  printf '{"current_phase":"M","pr_url":"p"}\n' > "$R/.delivery-kit/runs/001-T-1/progress.json"
  team_fake next alpha ann
  [ "$(jq -c '[.action, .task.id, .task.source]' <<<"$output")" = '["resume","T-2","run state"]' ]
}

@test "next: a task in progress with no run on this machine is reported, not started again" {
  status_fixture
  team_fake next alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.action, .task.id, .task.source]' <<<"$output")" = '["elsewhere","T-2","local branch"]' ]
}

@test "next: blocked, in review and done tasks are passed over, and none left says so" {
  status_fixture
  fake_prs '[{"headRefName":"ann/T-2","state":"MERGED","url":"u2"},{"headRefName":"ann/T-3","state":"OPEN","url":"u3"}]'
  team_fake next alpha ann
  [ "$(jq -c '[.action, .task.id]' <<<"$output")" = '["start","T-5"]' ]
  fake_prs '[{"headRefName":"ann/T-2","state":"MERGED","url":"u2"},{"headRefName":"ann/T-3","state":"OPEN","url":"u3"},{"headRefName":"ann/T-5","state":"MERGED","url":"u5"}]'
  team_fake next alpha ann
  [ "$(jq -c '[.action, .task]' <<<"$output")" = '["none",null]' ]
}

@test "command: the pipeline line carries the seed, the names, each trailer and the flags, quoted where needed" {
  set_json plan/alpha/ann/tasks.json '.tasks[0].seed = "Say \"hi\" to C:\\x." | .tasks[0].trailers += ["Reviewed-by: A B"]'
  team command alpha ann T-1
  [ "$status" -eq 0 ]
  [ "$output" = '/pipeline "Say \"hi\" to C:\\x." --branch ann/alpha/001-T-1-first --spec-dir specs/alpha/ann/001-T-1-first --trailer "Plan-Item: T-1" --trailer "Reviewed-by: A B" --implementer claude' ]
  team command alpha ann T-9
  refused "no task 'T-9'"
}

@test "render: the readable copy is written from the status, cells escaped" {
  status_fixture
  team_fake render alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -r '.written' <<<"$output")" = "plan/alpha/ann/progress.md" ]
  f="$R/plan/alpha/ann/progress.md"
  grep -qF '# Ann Example — progress' "$f"
  grep -qF 'Pull requests were not read' "$f"
  grep -qF '| 001 | `T-1` | Has a run with a PR | in review | `ann/T-1` | https://example.com/pr/1 |  |' "$f"
  grep -qF '| 004 | `T-4` | Is blocked | blocked | `ann/T-4` |  | waits for \| the API |' "$f"
  grep -qF '| 005 | `T-5` | Not started | not started |  |  |  |' "$f"
}

@test "render: a team with no progressView is refused, naming team:setup" {
  status_fixture
  set_json .delivery-kit.json 'del(.team.teams.alpha.progressView)'
  team_fake render alpha ann
  refused "no 'progressView'" "team:setup"
}

@test "an unknown command prints the usage" {
  team frobnicate
  refused "usage: team.sh"
}
