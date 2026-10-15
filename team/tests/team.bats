#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for team/scripts/team.sh — the reader for the team block, the
# roster and the task file. Every test builds its own scratch repository,
# so nothing here depends on this checkout's own settings.

load ../../tests/helper

setup() {
  TEAM_SH="$ROOT/team/scripts/team.sh"
  # The developer's own git and gh must not reach these repositories: a
  # global signing or hooks setting changes what a commit does, and a real
  # gh signed in would answer for pull requests. Cut off as
  # pipeline/tests/progress-git.bats does.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export GIT_CONFIG_NOSYSTEM=1
  export XDG_CONFIG_HOME="$HOME/.config"
  export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GH_REPO GH_HOST GH_TOKEN GITHUB_TOKEN
  # A gh that fails, first on PATH for every test, so no real gh is asked.
  FAKE="$BATS_TEST_TMPDIR/fake"; mkdir -p "$FAKE"
  printf '#!/bin/sh\nexit 1\n' > "$FAKE/gh"; chmod +x "$FAKE/gh"
  export PATH="$FAKE:$PATH"
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
    # On stdin, never as an argument: Git Bash rewrites an argument that
    # starts with / before a native Windows jq sees it (/abs became
    # C:/Program Files/Git/abs on windows-2025).
    set_json .delivery-kit.json ".team.teams.alpha.tasks = $(printf '%s' "$bad" | jq -R .)"
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

# malformed_tasks <count> — runs each "filter|message" line of stdin on
# ann's task file, in a fresh setup, and requires the message. Two tests
# share it: one held all 14 cases and took 30.6 s on windows-2025, over the
# 30 s budget.
malformed_tasks() {
  local f='plan/alpha/ann/tasks.json' filter want n=0
  while IFS='|' read -r filter want <&4; do
    n=$((n + 1))
    setup
    set_json "$f" "$filter"
    team tasks alpha ann
    refused "$want" || { echo "case: $filter"; return 1; }
  done 4<&0
  [ "$n" -eq "$1" ] || { echo "ran $n of $1 cases"; return 1; }
}

@test "tasks: a task file without a field it needs is refused, naming the fault" {
  malformed_tasks 7 <<'CASES'
del(.tasks)|has no 'tasks' list
.tasks[0] = 3|task 0 is not an object
del(.tasks[0].id)|task 0 has no id
del(.tasks[0].branch)|task T-1 has no branch
.tasks[0].branch = " "|task T-1 has no branch
del(.tasks[0].specDir)|task T-1 has no specDir
del(.tasks[0].seed)|task T-1 has no seed
CASES
}

@test "tasks: a task file with a field of the wrong type or a repeated id is refused, naming the fault" {
  malformed_tasks 7 <<'CASES'
.tasks[0].title = 3|task T-1: title is not a string
.tasks[0].number = 1|task T-1: number is not a string
.tasks[0].trailers = "Plan-Item: T-1"|task T-1: trailers is not a list of strings
.tasks[0].flags = [1]|task T-1: flags is not a list of strings
.tasks[1].id = "T-1"|task id 'T-1' appears twice
.tasks[0].seed = "two\nlines"|task T-1: seed holds a line break
.tasks[0].blocked = true|task T-1: blocked is not a string
CASES
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
  [ "$(jq -c . <<<"$output")" = '{"members":{"alpha":"ann"},"stale":[]}' ]
}

@test "iam: a member not in the roster is refused" {
  repo_git 'ann@example.com'
  team iam alpha cy
  refused "no member 'cy' in team 'alpha'"
}

@test "whoami: no answer yet, or a file that holds no answers, points at team:start" {
  repo_git 'ann@example.com'
  team whoami
  refused "no member chosen yet" "team:start"
  mkdir -p "$R/.delivery-kit"
  for bad in '{"team":"alpha"}' '[]' '{"members":{"alpha":1}}' '{"members":["ann"]}'; do
    printf '%s\n' "$bad" > "$R/.delivery-kit/team.json"
    team whoami
    refused "is not a set of team answers" "team:start"
  done
}

# two_teams — a second team, beta, where ann has another id, a2.
two_teams() {
  set_json .delivery-kit.json '.team.teams.beta = {roster: "plan/beta/roster.json", tasks: "plan/beta/{member}/tasks.json"}'
  mkdir -p "$R/plan/beta/a2"
  printf '%s\n' '{ "members": [ { "id": "a2", "name": "Ann Example", "emails": ["ann@example.com"] } ] }' > "$R/plan/beta/roster.json"
  printf '%s\n' '{ "tasks": [ { "id": "B-1", "branch": "a2/B-1", "specDir": "specs/beta/a2/B-1", "seed": "Beta one." } ] }' > "$R/plan/beta/a2/tasks.json"
}

@test "iam: one answer per team, and a second team keeps the first" {
  repo_git 'ann@example.com'
  two_teams
  team iam alpha ann
  team iam beta a2
  [ "$status" -eq 0 ]
  [ "$(jq -c . "$R/.delivery-kit/team.json")" = '{"members":{"alpha":"ann","beta":"a2"}}' ]
  team iam alpha bo
  [ "$(jq -c . "$R/.delivery-kit/team.json")" = '{"members":{"alpha":"bo","beta":"a2"}}' ]
}

@test "iam: the first form of the file is read as one answer and rewritten" {
  repo_git 'ann@example.com'
  two_teams
  mkdir -p "$R/.delivery-kit"
  printf '{"team":"alpha","member":"ann"}\n' > "$R/.delivery-kit/team.json"
  team whoami
  [ "$(jq -c .members <<<"$output")" = '{"alpha":"ann"}' ]
  team iam beta a2
  [ "$(jq -c . "$R/.delivery-kit/team.json")" = '{"members":{"alpha":"ann","beta":"a2"}}' ]
}

@test "whoami: an answer the settings or the roster no longer hold is listed as stale, and the rest still read" {
  repo_git 'ann@example.com'
  two_teams
  mkdir -p "$R/.delivery-kit"
  printf '{"members":{"alpha":"cy","beta":"a2","gone":"x"}}\n' > "$R/.delivery-kit/team.json"
  team whoami
  [ "$status" -eq 0 ]
  [ "$(jq -c .members <<<"$output")" = '{"beta":"a2"}' ]
  [ "$(jq -c .stale <<<"$output")" = '[{"team":"alpha","member":"cy"},{"team":"gone","member":"x"}]' ]
}

@test "mine: each team gives its saved member and next task, or the ids the email suggests" {
  repo_git 'ann@example.com'
  two_teams
  git -C "$R" add -A && git -C "$R" commit -q -m init
  mkdir -p "$R/.delivery-kit"
  printf '{"members":{"beta":"a2"}}\n' > "$R/.delivery-kit/team.json"
  team mine
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.teams[] | [.team, .member, .suggested, .next.action, .next.task.id, .error]]' <<<"$output")" = \
    '[["alpha",null,["ann"],null,null,null],["beta","a2",[],"start","B-1",null]]' ]
  [ "$(jq -c '[.originRead, .prRead]' <<<"$output")" = '[false,false]' ]
}

@test "mine: a member who left is asked again, and a team that cannot be read does not hide the others" {
  repo_git 'ann@example.com'
  two_teams
  git -C "$R" add -A && git -C "$R" commit -q -m init
  mkdir -p "$R/.delivery-kit"
  printf '{"members":{"alpha":"cy","beta":"a2"}}\n' > "$R/.delivery-kit/team.json"
  team mine
  [ "$status" -eq 0 ]
  [ "$(jq -c '.teams[0] | [.member, .left, .suggested]' <<<"$output")" = '[null,"cy",["ann"]]' ]
  printf 'not json\n' > "$R/plan/alpha/roster.json"
  team mine
  [ "$status" -eq 0 ]
  [ "$(jq -r '.teams[0].error' <<<"$output")" = "roster 'plan/alpha/roster.json' is not valid JSON" ]
  [ "$(jq -c '.teams[1] | [.member, .next.action]' <<<"$output")" = '["a2","start"]' ]
  printf '{"members":{"beta":"a2"}}\n' > "$R/.delivery-kit/team.json"
  rm "$R/plan/beta/a2/tasks.json"
  team mine
  [ "$(jq -c '.teams[1] | [.member, .next, .error]' <<<"$output")" = \
    '["a2",null,"task file '"'"'plan/beta/a2/tasks.json'"'"' does not exist"]' ]
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
}

# fake_prs <json> — the fake gh prints this list of pull requests.
fake_prs() {
  printf '%s\n' "$1" > "$BATS_TEST_TMPDIR/prs.json"
  printf '#!/bin/sh\ncat "%s"\n' "$BATS_TEST_TMPDIR/prs.json" > "$FAKE/gh"
}

# git_stub <file> — a git first on PATH that answers ls-remote with <file>
# and logs the call, with its GIT_SSH_COMMAND, to $BATS_TEST_TMPDIR/git.log.
# Every other git command goes to the real git, found before the stub is
# written: call it once per test.
git_stub() {
  local real
  real="$(command -v git)"
  cat > "$FAKE/git" <<SH
#!/bin/sh
case " \$* " in
  *" ls-remote "*) printf '%s|%s\n' "\$*" "\${GIT_SSH_COMMAND:-}" >> "$BATS_TEST_TMPDIR/git.log"; cat "$1"; exit 0 ;;
esac
exec "$real" "\$@"
SH
  chmod +x "$FAKE/git"
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
  mkdir -p "$R/.delivery-kit/runs/003-T-3"
  printf '{"current_phase":"H"}\n' > "$R/.delivery-kit/runs/003-T-3/progress.json"
  team_fake next alpha ann
  [ "$status" -eq 0 ]
  # T-1 now has nothing: not started, and first in the file. T-2 is in
  # progress by its branch alone. T-3's run is on this machine, so it comes
  # first: a fresh start would meet the pipeline's resume prompt.
  [ "$(jq -c '[.action, .task.id, .task.source]' <<<"$output")" = '["resume","T-3","run state"]' ]
  rm "$R/.delivery-kit/runs/003-T-3/progress.json"
  team_fake next alpha ann
  [ "$(jq -c '[.action, .task.id]' <<<"$output")" = '["elsewhere","T-2"]' ]
}

@test "next: says what it could not read, so team:start can say it too" {
  status_fixture
  git -C "$R" remote remove origin
  team_fake next alpha ann
  [ "$(jq -c '[.originRead, .prRead]' <<<"$output")" = '[false,false]' ]
  fake_prs '[]'
  team_fake next alpha ann
  [ "$(jq -c '.prRead' <<<"$output")" = 'true' ]
}

@test "status: a closed pull request is not in review, even when the run recorded it" {
  status_fixture
  printf '{"current_phase":"M","pr_url":"https://example.com/pr/1"}\n' > "$R/.delivery-kit/runs/001-T-1/progress.json"
  fake_prs '[{"headRefName":"ann/T-1","state":"CLOSED","url":"https://example.com/pr/1"}]'
  team_fake status alpha ann
  [ "$(jq -c '.tasks[0] | [.status, .source, .prClosed]' <<<"$output")" = '["in progress","run state",true]' ]
  printf '{"current_phase":"DONE","pr_url":"https://example.com/pr/1"}\n' > "$R/.delivery-kit/runs/001-T-1/progress.json"
  team_fake status alpha ann
  [ "$(jq -c '.tasks[0] | [.status, .source]' <<<"$output")" = '["finished","run state"]' ]
  # An abandoned run that had opened a pull request is still abandoned.
  printf '{"current_phase":"M","pr_url":"https://example.com/pr/1","abandoned":{"at":"t","phase":"M"}}\n' > "$R/.delivery-kit/runs/001-T-1/progress.json"
  fake_prs '[]'
  team_fake status alpha ann
  [ "$(jq -c '.tasks[0] | [.status, .source]' <<<"$output")" = '["abandoned","run state"]' ]
}

@test "a fault deep in a read stops the command with one line, never an empty answer" {
  status_fixture
  printf 'not json\n' > "$R/plan/alpha/roster.json"
  team_fake status alpha ann
  refused "roster 'plan/alpha/roster.json' is not valid JSON"
  [ "$(printf '%s\n' "$stderr" | grep -c '^team.sh:')" -eq 1 ] || { echo "stderr: $stderr"; false; }
  [ -z "$output" ]
  team_fake next alpha ann
  refused "is not valid JSON"
  [ -z "$output" ]
}

@test "a broken identity file is refused by every reader, and iam leaves it as it was" {
  repo_git 'ann@example.com'
  mkdir -p "$R/.delivery-kit"
  for bad in '{ not json' ''; do
    printf '%s' "$bad" > "$R/.delivery-kit/team.json"
    for c in whoami mine "iam alpha ann"; do
      # shellcheck disable=SC2086 # the command and its words
      team $c
      refused "identity file '.delivery-kit/team.json'" "delete it and run team:start"
      [ -z "$output" ] || { echo "$c printed: $output"; false; }
    done
    [ "$(cat "$R/.delivery-kit/team.json")" = "$bad" ]
  done
}

@test "a member id or a team key that starts with a dot is refused, so no path climbs out" {
  for id in '..' '.' '.hidden'; do
    t="$(jq --arg id "$id" '.members[1].id = $id' "$R/plan/alpha/roster.json")"
    printf '%s\n' "$t" > "$R/plan/alpha/roster.json"
    team roster alpha
    refused "member id '$id'" "starting with a letter or digit"
  done
  set_json .delivery-kit.json '.team.teams[".x"] = .team.teams.alpha'
  team config
  refused "team key '.x'"
}

@test "render: a member not in the roster is refused before any path is built" {
  status_fixture
  team_fake render alpha ..
  refused "no member '..' in team 'alpha'"
  [ ! -e "$BATS_TEST_TMPDIR/progress.md" ] && [ ! -e "$R/plan/progress.md" ]
}

@test "render: a task file that cannot be read writes no page" {
  status_fixture
  rm "$R/plan/alpha/ann/tasks.json"
  team_fake render alpha ann
  refused "task file 'plan/alpha/ann/tasks.json' does not exist"
  [ "$(printf '%s\n' "$stderr" | grep -c '^team.sh:')" -eq 1 ] || { echo "stderr: $stderr"; false; }
  [ ! -e "$R/plan/alpha/ann/progress.md" ]
}

@test "mine: leaves no temporary file behind" {
  repo_git 'ann@example.com'
  git -C "$R" add -A && git -C "$R" commit -q -m init
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"; mkdir -p "$TMPDIR"
  team mine
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$TMPDIR")" ] || { ls -A "$TMPDIR"; false; }
}

@test "next: a task in progress with no run on this machine is reported, not started again" {
  status_fixture
  # T-1's live run would be resumed first; without it, T-1 is not started.
  rm "$R/.delivery-kit/runs/001-T-1/progress.json"
  team_fake next alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.action, .task.id, .task.source]' <<<"$output")" = '["elsewhere","T-2","local branch"]' ]
}

@test "next: blocked, in review and done tasks are passed over, and none left says so" {
  status_fixture
  # In review by its pull request alone: a live run would be resumed.
  rm "$R/.delivery-kit/runs/001-T-1/progress.json"
  fake_prs '[{"headRefName":"ann/T-1","state":"OPEN","url":"u1"},{"headRefName":"ann/T-2","state":"MERGED","url":"u2"},{"headRefName":"ann/T-3","state":"OPEN","url":"u3"}]'
  team_fake next alpha ann
  [ "$(jq -c '[.action, .task.id]' <<<"$output")" = '["start","T-5"]' ]
  fake_prs '[{"headRefName":"ann/T-1","state":"OPEN","url":"u1"},{"headRefName":"ann/T-2","state":"MERGED","url":"u2"},{"headRefName":"ann/T-3","state":"OPEN","url":"u3"},{"headRefName":"ann/T-5","state":"MERGED","url":"u5"}]'
  team_fake next alpha ann
  [ "$(jq -c '[.action, .task]' <<<"$output")" = '["none",null]' ]
}

@test "next: a run still live after its pull request opened is resumed, never passed over for a new start" {
  # Phases M to O run after the pull request opens. Read as in review and
  # passed over, the next task was offered as a start, and pre-flight then
  # met the live run and its lock.
  status_fixture
  printf '{"current_phase":"M","pr_url":"https://github.com/o/r/pull/7"}\n' > "$R/.delivery-kit/runs/001-T-1/progress.json"
  team_fake next alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.action, .task.id, .task.status, .task.source, .task.runEnd]' <<<"$output")" = '["resume","T-1","in review","run state","live"]' ]
  fake_prs '[{"headRefName":"ann/T-1","state":"OPEN","url":"https://github.com/o/r/pull/7"}]'
  team_fake next alpha ann
  [ "$(jq -c '[.action, .task.id, .task.status, .task.source]' <<<"$output")" = '["resume","T-1","in review","pull request"]' ]
}

@test "status: an abandoned run and a finished run without a pull request are ended, and next passes over both" {
  status_fixture
  printf '{"current_phase":"H","abandoned":{"at":"t","phase":"H"}}\n' > "$R/.delivery-kit/runs/001-T-1/progress.json"
  mkdir -p "$R/.delivery-kit/runs/002-T-2"
  printf '{"current_phase":"DONE","pr_url":""}\n' > "$R/.delivery-kit/runs/002-T-2/progress.json"
  team_fake status alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.tasks[0:2][] | [.status, .source, .runEnd]]' <<<"$output")" = \
    '[["abandoned","run state","abandoned"],["finished","run state","done"]]' ]
  team_fake next alpha ann
  [ "$(jq -c '[.action, .task.id]' <<<"$output")" = '["elsewhere","T-3"]' ]
  # A pull request still wins: the run's end is read only when no pull
  # request answers.
  fake_prs '[{"headRefName":"ann/T-2","state":"MERGED","url":"u2"}]'
  team_fake status alpha ann
  [ "$(jq -c '.tasks[1] | [.status, .source]' <<<"$output")" = '["done","pull request"]' ]
}

@test "status: how a run ended agrees with the pipeline's own progress.sh" {
  # The rule is copied from progress.sh. This runs the pipeline's script in
  # this repository on three real runs, live, abandoned and DONE, and checks
  # that team.sh reads each the way the pipeline does.
  status_fixture
  P="$ROOT/pipeline/scripts/progress.sh"
  rule="$(sed -n "s/^RUN_END_JQ='\(.*\)'\$/\1/p" "$P")"
  [ -n "$rule" ] || { echo "progress.sh no longer defines RUN_END_JQ on one line"; false; }
  rm -rf "$R/.delivery-kit/runs"
  ( cd "$R" && for f in 001-T-1 002-T-2 003-T-3; do bash "$P" init "$f" "b-$f" work feature >/dev/null; done \
      && bash "$P" abandon 002-T-2 && bash "$P" phase-start 003-T-3 DONE )
  team_fake status alpha ann
  [ "$status" -eq 0 ]
  for i in 0 1 2; do
    f="$(jq -r --argjson i "$i" '.tasks[$i].specDir | split("/") | last' <<<"$output")"
    want="$(cd "$R" && bash "$P" get "$f" "$rule")"
    got="$(jq -r --argjson i "$i" '.tasks[$i].runEnd' <<<"$output")"
    [ "$got" = "$want" ] || { echo "$f: team.sh read '$got', progress.sh '$want'"; false; }
  done
  [ "$(jq -c '[.tasks[0:3][] | .runEnd]' <<<"$output")" = '["live","abandoned","done"]' ]
}

@test "status: a branch on origin is found among thousands, the task's first, and only by its whole name" {
  # The reviewer's case: 3,000 branches on origin, the task's first. A grep
  # that stops at its first match broke the pipe that fed it, and pipefail
  # read the branch as absent. The names fill more than one pipe buffer.
  status_fixture
  local sha=0123456789abcdef0123456789abcdef01234567
  { printf '%s\trefs/heads/ann/T-3\n%s\trefs/heads/ann/T-55\n' "$sha" "$sha"
    awk -v s="$sha" 'BEGIN { for (i = 0; i < 3000; i++) printf "%s\trefs/heads/zz/a-branch-name-long-enough-to-fill-a-pipe-%04d\n", s, i }'
  } > "$BATS_TEST_TMPDIR/heads.txt"
  [ "$(wc -c < "$BATS_TEST_TMPDIR/heads.txt")" -gt 150000 ]
  git_stub "$BATS_TEST_TMPDIR/heads.txt"
  team_fake status alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -c '.tasks[2] | [.status, .source, .originBranch, .runFile]' <<<"$output")" = '["in progress","origin branch",true,""]' ]
  # ann/T-55 is not ann/T-5.
  [ "$(jq -c '.tasks[4] | [.status, .originBranch]' <<<"$output")" = '["not started",false]' ]
}

# big_fixture — a git repository with one local branch, ann/T-2, and no
# origin: the least a large status needs, so the large tests stay quick.
big_fixture() {
  repo_git 'ann@example.com'
  git -C "$R" add -A && git -C "$R" commit -q -m init
  git -C "$R" branch ann/T-2
}

@test "status finishes on a task list of the size where a Git Bash herestring hangs" {
  # Git Bash hangs a herestring of 65,536 to about 65,700 bytes. Status
  # read its task list through one; 152 tasks reached the window and it
  # never returned, and next, mine and render with it. The list here is
  # made exactly 65,600 bytes: each task holds every field team.sh fills,
  # in its order, so the list team.sh prints is the file's own list. Each
  # answer goes to a file, never through `run`: bats reads `run`'s output
  # through a herestring of its own.
  big_fixture
  local f="$R/plan/alpha/ann/tasks.json" o="$BATS_TEST_TMPDIR/out" n
  set_json plan/alpha/ann/tasks.json '.tasks = [range(150) as $i | {id: "T-\($i)", number: "", title: "", branch: "ann/T-\($i)",
    specDir: "specs/ann/T-\($i)", seed: ("s" * 300), trailers: [], flags: [], blocked: ""}]'
  n="$(jq -cj .tasks "$f" | wc -c)"
  [ "$n" -lt 65600 ] || { echo "the list is already $n bytes"; false; }
  set_json plan/alpha/ann/tasks.json ".tasks[0].seed += (\"x\" * $((65600 - n)))"
  n="$(jq -cj .tasks "$f" | wc -c)"
  [ "$n" -eq 65600 ] || { echo "the list is $n bytes"; false; }
  bash "$TEAM_SH" --dir "$R" status alpha ann > "$o"
  [ "$(jq -cj '[.tasks[] | del(.status, .source, .pr, .run, .phase, .runEnd, .runFile, .localBranch, .originBranch, .prClosed)]' "$o" | wc -c)" -eq 65600 ]
  [ "$(jq -c '[.tasks[2].status, (.tasks | length)]' "$o")" = '["in progress",150]' ]
}

@test "render finishes on a status of the size where a Git Bash herestring hangs" {
  # render read the status through a herestring. Here the status itself is
  # made exactly 65,600 bytes: one seed is padded by what it lacks, and the
  # seed appears once in the status, so the status grows by the same count.
  big_fixture
  local o="$BATS_TEST_TMPDIR/out" n
  set_json plan/alpha/ann/tasks.json '.tasks = [range(100) as $i | {id: "T-\($i)", branch: "ann/T-\($i)", specDir: "specs/ann/T-\($i)", seed: ("s" * 300)}]'
  bash "$TEAM_SH" --dir "$R" status alpha ann > "$o"
  n="$(jq -cj . "$o" | wc -c)"
  [ "$n" -lt 65600 ] || { echo "the status is already $n bytes"; false; }
  set_json plan/alpha/ann/tasks.json ".tasks[0].seed += (\"x\" * $((65600 - n)))"
  bash "$TEAM_SH" --dir "$R" render alpha ann > "$o"
  [ "$(grep -c '^| ' "$R/plan/alpha/ann/progress.md")" -eq 101 ]
}

@test "status: a run state file that cannot be read is unreadable, never a live run" {
  # Each is a file the pipeline's pre-flight names unreadable: empty, not
  # JSON, a list, a phase that is not a string, and two documents.
  status_fixture
  local d="$R/.delivery-kit/runs" n
  for n in 002-T-2 003-T-3 004-T-4 005-T-5; do mkdir -p "$d/$n"; done
  : > "$d/001-T-1/progress.json"
  printf '{ not json' > "$d/002-T-2/progress.json"
  printf '[]\n' > "$d/003-T-3/progress.json"
  printf '{"current_phase":5}\n' > "$d/004-T-4/progress.json"
  printf '{"current_phase":"H"}\n{"current_phase":"H"}\n' > "$d/005-T-5/progress.json"
  team_fake status alpha ann
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.tasks[] | [.id, .status, .source, .runEnd]]' <<<"$output")" = \
    '[["T-1","unreadable","run state","unreadable"],["T-2","unreadable","run state","unreadable"],["T-3","unreadable","run state","unreadable"],["T-4","unreadable","run state","unreadable"],["T-5","unreadable","run state","unreadable"]]' ]
  [ "$(jq -r '.tasks[1].runFile' <<<"$output")" = ".delivery-kit/runs/002-T-2/progress.json" ]
  # Never resumed, and before T-2's local branch would be reported.
  team_fake next alpha ann
  [ "$(jq -c '[.action, .task.id, .task.runFile]' <<<"$output")" = '["unreadable","T-1",".delivery-kit/runs/001-T-1/progress.json"]' ]
}

@test "status: a pull request still wins over an unreadable run, and next reports the first task it leaves" {
  status_fixture
  mkdir -p "$R/.delivery-kit/runs/002-T-2" "$R/.delivery-kit/runs/003-T-3"
  printf '{ not json' > "$R/.delivery-kit/runs/001-T-1/progress.json"
  printf '{ not json' > "$R/.delivery-kit/runs/002-T-2/progress.json"
  printf '[]\n' > "$R/.delivery-kit/runs/003-T-3/progress.json"
  fake_prs '[{"headRefName":"ann/T-1","state":"MERGED","url":"u1"},{"headRefName":"ann/T-2","state":"OPEN","url":"u2"}]'
  team_fake status alpha ann
  [ "$(jq -c '[.tasks[0:3][] | [.status, .source, .runEnd]]' <<<"$output")" = \
    '[["done","pull request","unreadable"],["in review","pull request","unreadable"],["unreadable","run state","unreadable"]]' ]
  team_fake next alpha ann
  [ "$(jq -c '[.action, .task.id]' <<<"$output")" = '["unreadable","T-3"]' ]
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
