#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for pipeline/scripts/preflight.sh — detection and probe. The fixture
# directories are copied, once per file, into a scratch repository on branch
# main with one commit, a GitHub origin and origin/HEAD naming main, and
# every fixture test probes that copy. Pre-flight checks that the base branch
# is a local branch with a commit, and a CI pull-request checkout is detached
# with no main at all, so a fixture probed where it sits, inside this
# checkout, would stop in CI alone (feature 052, research R6). The copy keeps
# the git facts the fixture tests were written against: a GitHub remote, and
# origin/HEAD resolving to a local main. No fixture test asserts baseBranch
# or remote; those assertions get their own scratch repositories below.

load ../../tests/helper

setup_file() {
  local copy="$BATS_FILE_TMPDIR/fixtures"
  cp -R "$ROOT/pipeline/tests/fixtures" "$copy"
  # add -f: a global excludes file must not leave a fixture file untracked.
  ( cd "$copy" && git init -q -b main && git add -f . && commit_staged fixtures \
    && git remote add origin https://github.com/example/thing.git \
    && git update-ref refs/remotes/origin/main HEAD \
    && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main )
  export FIX_REPO="$copy"
}

setup() {
  FIX="$FIX_REPO"
  # PREFLIGHT_UNDER_TEST points the suite at another copy of the script, for
  # mutation runs: mutate a copy, point the suite at it, watch a test go red.
  # The copy needs its siblings beside it: trailer-check.sh, and the
  # hidden-chars.sh it sources, or the trailer tests go red for that alone.
  PROBE="${PREFLIGHT_UNDER_TEST:-$PROBE}"
  [ -f "$PROBE" ] || { echo "no script at $PROBE"; return 1; }
}

# The six external commands the probe actually invokes, read out of the script
# rather than guessed. A search path holding exactly these lets the probe run
# normally while any OTHER tool reads as absent — which is the only way to reach
# the degradation branches.
PROBE_TOOLS="awk git grep head jq od"

# shimdir <dir> [tool...] — a directory of tiny shims, each execing the real
# tool. Hand it to `probe --path` to control precisely what the probe can find.
#
# The directory must be a path with no drive letter: under Git Bash a `C:/...`
# entry splits on its own colon into two broken entries and then EVERY tool
# reads as absent, including jq — so the probe would die for a reason no test
# named, and pass for the wrong cause. $BATS_TEST_TMPDIR is already POSIX-form.
shimdir() {
  local d="$1"; shift
  mkdir -p "$d"
  local t src
  for t in "$@"; do
    src="$(command -v "$t")" || continue
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$src" > "$d/$t"
    chmod +x "$d/$t"
  done
}

# commit_staged <message> [git commit arguments...] — commit what is staged in
# the current repository. The identity is given on the command line: these
# repositories have none.
commit_staged() {
  local m=$1; shift
  git -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
    commit -q -m "$m" "$@"
}

# seed — one empty commit in the current repository, so branches can exist.
seed() {
  commit_staged seed --allow-empty
}

# refused <message> <probe arguments...> — the probe stops: exit 1, no report,
# and exactly `preflight: <message>` on stderr.
refused() {
  local want="preflight: $1"; shift
  probe "$@"
  [ "$status" -eq 1 ] || { echo "exit $status for: $want"; false; }
  [ -z "$output" ] || { echo "a report was printed for: $want"; false; }
  [ "$stderr" = "$want" ] || { echo "want: $want"; echo "got:  $stderr"; false; }
}

# main_base — seed, and a local branch main beside the checked-out one, for a
# test that names main as its base only as a formality. Since feature 052
# pre-flight checks that a base is a local branch with a commit, so a base
# that names nothing stops the probe. main is made only where it is not the
# branch the commit landed on: `git init` without -b follows the caller's
# init.defaultBranch.
main_base() {
  seed
  git show-ref --verify --quiet refs/heads/main || git branch main
}

# stub <path> — a program that exists and does nothing. The probe asks only
# whether a capability can be FOUND, so presence is the whole behaviour.
stub() {
  printf '#!/bin/sh\nexit 0\n' > "$1"
  chmod +x "$1"
}

@test "the web fixture detects web, from the package.json toolchain" {
  probe --dir "$FIX/web" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "web" ]
  [ "$(jq -r '.projectTypeSource' <<<"$output")" = "package.json toolchain" ]
}

@test "the mobile-android fixture detects mobile-android" {
  probe --dir "$FIX/mobile-android" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "mobile-android" ]
}

@test "the other fixture detects other, by default" {
  probe --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "other" ]
  [ "$(jq -r '.projectTypeSource' <<<"$output")" = "default" ]
}

@test "--project-type overrides detection and says so" {
  probe --dir "$FIX/web" --base-branch main --project-type other
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "other" ]
  [ "$(jq -r '.projectTypeSource' <<<"$output")" = "override" ]
}

@test "the no-speckit fixture reports the tool absent, exit 0 -- reporting is not failing" {
  probe --dir "$FIX/no-speckit" --base-branch main
  [ "$status" -eq 0 ]
  # The type, never a pattern over jq -r's text: -r prints the string "false"
  # exactly as it prints the boolean, so the line below passed on both.
  jq -e '.speckit.present | type == "boolean"' <<<"$output" > /dev/null
  [ "$(jq -r '.speckit.present' <<<"$output")" = "false" ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ]
}

@test "the web fixture reads version and sh flavour, resolving the bash scripts dir" {
  probe --dir "$FIX/web" --base-branch main
  # The type, never a pattern over jq -r's text: -r prints the string "true"
  # exactly as it prints the boolean, so the versionInRange line below passed
  # on both.
  jq -e '.speckit.versionInRange | type == "boolean"' <<<"$output" > /dev/null
  [ "$(jq -r '.speckit.version' <<<"$output")" = "0.16.5" ]
  [ "$(jq -r '.speckit.script' <<<"$output")" = "sh" ]
  [ "$(jq -r '.speckit.scriptsDir' <<<"$output")" = ".specify/scripts/bash" ]
  [ "$(jq -r '.speckit.versionInRange' <<<"$output")" = "true" ]
}

@test "the mobile-android fixture's ps flavour resolves the powershell scripts dir" {
  probe --dir "$FIX/mobile-android" --base-branch main
  [ "$(jq -r '.speckit.script' <<<"$output")" = "ps" ]
  [ "$(jq -r '.speckit.scriptsDir' <<<"$output")" = ".specify/scripts/powershell" ]
}

@test "the py flavour is handled loudly: exit 0, empty scriptsDir, stderr names it" {
  probe --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.script' <<<"$output")" = "py" ]
  [ "$(jq -r '.speckit.scriptsDir' <<<"$output")" = "" ]
  [[ "$stderr" == *"'py'"* ]]
}

@test "an out-of-range version warns on stderr and continues" {
  probe --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.versionInRange' <<<"$output")" = "false" ]
  [[ "$stderr" == *"0.14.0"* ]]
}

@test "an illegal script flavour fails loudly, naming the value" {
  T="$BATS_TEST_TMPDIR/bad"
  mkdir -p "$T/.specify/templates" "$T/.specify/scripts"
  printf '{ "speckit_version": "0.16.5", "script": "bat" }\n' > "$T/.specify/init-options.json"
  probe --dir "$T" --base-branch main
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'bat'"* ]]
}

@test "a hyphen-skill install is recorded as hyphen-skills" {
  probe --dir "$FIX/web" --base-branch main
  [ "$(jq -r '.speckit.invocationForm' <<<"$output")" = "hyphen-skills" ]
}

@test "a dot-command install is recorded as dot-commands" {
  probe --dir "$FIX/mobile-android" --base-branch main
  [ "$(jq -r '.speckit.invocationForm' <<<"$output")" = "dot-commands" ]
}

@test "remote classification: none, github, other" {
  T="$BATS_TEST_TMPDIR/remote"
  mkdir -p "$T"; cd "$T"; git init -q .; main_base
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "none" ]
  not_read_is '[]'
  git remote add origin https://github.com/example/thing.git
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "github" ]
  not_read_is '[]'
  git remote set-url origin https://gitlab.example.com/x/y.git
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "other" ]
  not_read_is '[]'
}

@test "base branch: origin/HEAD first, then the override, each with its source" {
  T="$BATS_TEST_TMPDIR/base"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; main_base; git branch trunk
  probe --dir "$T" --base-branch trunk
  [ "$(jq -r '.baseBranch' <<<"$output")" = "trunk" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "configured" ]
  git remote add origin https://github.com/example/thing.git
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  probe --dir "$T" --base-branch trunk
  [ "$(jq -r '.baseBranch' <<<"$output")" = "main" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "origin/HEAD" ]
}

@test "base branch: an override beats origin/HEAD, and is reported as an override" {
  # The positive control for the override. origin/HEAD is published, so
  # without the override the answer is main — the test above pins that
  # direction — and only the override can make it integration.
  T="$BATS_TEST_TMPDIR/base-override"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  git remote add origin https://github.com/example/thing.git
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git branch integration
  probe --dir "$T" --base-branch trunk --base-branch-override integration
  [ "$(jq -r '.baseBranch' <<<"$output")" = "integration" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "override" ]
}

@test "base branch: the override beats the configured name where there is no remote" {
  T="$BATS_TEST_TMPDIR/base-override-local"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed; git branch integration
  probe --dir "$T" --base-branch trunk --base-branch-override integration
  [ "$(jq -r '.baseBranch' <<<"$output")" = "integration" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "override" ]
}

@test "base branch: a branch with no commit yet stops pre-flight, naming the fix" {
  # Feature 051. The old read, git rev-parse --abbrev-ref HEAD, printed HEAD
  # and exited 128 here, and the report kept HEAD as the base branch. Phase B
  # cannot branch from a branch with no commit, so pre-flight stops instead.
  # The whole message is compared: no git text, no other case's words.
  T="$BATS_TEST_TMPDIR/unborn"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  probe --dir "$T"
  [ "$status" -eq 1 ] || { echo "exit $status, want 1: $output"; false; }
  [ -z "$output" ] || { echo "a report was printed: $output"; false; }
  [ "$stderr" = "preflight: the current branch has no commit yet, so there is nothing to cut the feature branch from; make a first commit, or pass a base branch that has one (the run's --base-branch flag, or the baseBranch key)" ] \
    || { echo "wrong stop: $stderr"; false; }
  # The stop is for the current-checkout source only: a base from a flag
  # reads no checkout, so this stop does not fire for it. Until feature 052
  # the same repository then reported the configured name unchecked; now
  # the usable-base check refuses it, since a repository with no commit has
  # no branch at all, and it names the key, not the current checkout.
  refused "'main' is not a branch here or on origin (the baseBranch key)" --dir "$T" --base-branch main
}

@test "base branch: a detached HEAD stops pre-flight, naming the fix" {
  # Feature 051. The old read printed HEAD and exited 0 here, so no exit
  # check on it could see the case.
  T="$BATS_TEST_TMPDIR/detached"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; main_base
  git checkout -q --detach
  probe --dir "$T"
  [ "$status" -eq 1 ] || { echo "exit $status, want 1: $output"; false; }
  [ -z "$output" ] || { echo "a report was printed: $output"; false; }
  [ "$stderr" = "preflight: HEAD is detached, so the current checkout names no base branch; check out a branch, or pass a base branch (the run's --base-branch flag, or the baseBranch key)" ] \
    || { echo "wrong stop: $stderr"; false; }
  # The stop is for the current-checkout source only: still detached, a
  # base from a flag reports.
  probe --dir "$T" --base-branch main
  [ "$status" -eq 0 ] || { echo "a base flag on a detached HEAD: exit $status: $stderr"; false; }
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "configured" ]
  # The positive control: the same repository, back on its branch, reports.
  git checkout -q work
  probe --dir "$T"
  [ "$status" -eq 0 ] || { echo "exit $status: $stderr"; false; }
  [ "$(jq -r '.baseBranch' <<<"$output")" = "work" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "current branch" ]
  not_read_is '[]'
  # symbolic-ref exits 128, not 1, when HEAD names a branch git cannot read:
  # that is not a detached HEAD, and the stop says so.
  printf 'garbage\n' > .git/refs/heads/work
  probe --dir "$T"
  [ "$status" -eq 1 ] || { echo "a broken branch ref: exit $status: $output"; false; }
  [ "$stderr" = "preflight: HEAD names a branch git cannot read, so the current checkout names no base branch; run git status to see why" ] \
    || { echo "a broken branch ref: $stderr"; false; }
}

@test "base branch: a name from the repository gets the override's check, from every source" {
  # Feature 051, phase I. B types the base into commands, and git accepts
  # names the override is refused for, so a name read from the repository is
  # checked too: origin/HEAD (a cloned remote names its own default), the
  # baseBranch key, and the current branch. git branch refuses a leading
  # dash, so update-ref plants it. Each source is probed on its own.
  T="$BATS_TEST_TMPDIR/base-names"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; main_base
  git update-ref refs/heads/-dash HEAD
  git symbolic-ref HEAD refs/heads/-dash
  probe --dir "$T"
  [ "$status" -eq 1 ] || { echo "current branch -dash: exit $status: $output"; false; }
  [ "$stderr" = "preflight: '-dash' is not a legal branch name (the current branch; check out another branch, or pass a base branch)" ] \
    || { echo "current branch -dash: $stderr"; false; }
  git symbolic-ref HEAD refs/heads/work
  probe --dir "$T" --base-branch 'a$b'
  [ "$status" -eq 1 ] || { echo "configured a\$b: exit $status: $output"; false; }
  [ "$stderr" = "preflight: 'a\$b' holds a character other than a letter, a digit, '.', '_', '-' or '/' (the baseBranch key)" ] \
    || { echo "configured a\$b: $stderr"; false; }
  git update-ref refs/remotes/origin/-dash HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/-dash
  probe --dir "$T" --base-branch main
  [ "$status" -eq 1 ] || { echo "origin/HEAD -dash: exit $status: $output"; false; }
  [ "$stderr" = "preflight: '-dash' is not a legal branch name (origin/HEAD; pass a base branch with the run's --base-branch flag)" ] \
    || { echo "origin/HEAD -dash: $stderr"; false; }
  # The positive control: origin/HEAD naming a legal branch reports it.
  git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  probe --dir "$T" --base-branch main
  [ "$status" -eq 0 ] || { echo "origin/HEAD main: exit $status: $stderr"; false; }
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "origin/HEAD" ]
}

@test "base branch: an override git would not accept as a branch name is refused, naming it" {
  # git check-ref-format decides what is legal, so the rule is git's and is
  # not restated here. The message names the value and the argument both.
  T="$BATS_TEST_TMPDIR/base-override-bad"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  probe --dir "$T" --base-branch-override 'two..dots'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'two..dots' is not a legal branch name"* ]] || false
  [[ "$stderr" == *"--base-branch-override"* ]]
}

@test "feature branch and spec folder: without the arguments both are reported empty" {
  # The default path is unchanged: the spec tool names the feature, and the
  # branch and the folder follow that name. An empty value is that default.
  T="$BATS_TEST_TMPDIR/names-absent"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  probe --dir "$T"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.featureBranch' <<<"$output")" = "" ]
  [ "$(jq -r '.specDir' <<<"$output")" = "" ]
}

@test "feature branch: a typed name is reported, slashes and all" {
  T="$BATS_TEST_TMPDIR/branch-named"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  probe --dir "$T" --feature-branch 'team/one/003-thing'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.featureBranch' <<<"$output")" = "team/one/003-thing" ]
}

@test "feature branch: a name git would not accept as a branch name is refused, naming it" {
  T="$BATS_TEST_TMPDIR/branch-bad"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  probe --dir "$T" --feature-branch 'two..dots'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'two..dots'"* ]] || false
  [[ "$stderr" == *"--feature-branch"* ]]
}

@test "feature branch: the base branch's own name is refused, naming both" {
  # B cuts the feature branch FROM the base. The same name for both is a
  # run that commits straight onto its integration branch.
  T="$BATS_TEST_TMPDIR/branch-is-base"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed; git branch integration
  probe --dir "$T" --base-branch-override integration --feature-branch integration
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'integration'"* ]] || false
  [[ "$stderr" == *"--feature-branch"* ]] || false
  [[ "$stderr" == *"base branch"* ]]
}

@test "spec folder: a nested folder relative to the repository is reported" {
  T="$BATS_TEST_TMPDIR/specdir-named"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  probe --dir "$T" --spec-dir 'specs/team/one/003-thing'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.specDir' <<<"$output")" = "specs/team/one/003-thing" ]
}

@test "spec folder: a path outside the repository, or one with no legal run name, is refused, naming it" {
  # One case per check in the script. Each value passes every check but
  # its own, so skipping any one check turns exactly one case green.
  T="$BATS_TEST_TMPDIR/specdir-bad"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  local bad
  # Later checks catch several of these too, so each case checks its own
  # reason: a drive letter is also an odd character, for example.
  local want
  for bad in '/abs/003-thing' 'C:/specs/003-thing' 'specs/../003-thing' \
             './specs/003-thing' 'specs//003-thing' 'specs\team/003-thing' \
             '.delivery-kit/runs/003-thing' 'specs/003 thing'; do
    case "$bad" in
      /*|C:*)       want='is not relative to the repository root' ;;
      *..*)         want='climbs out with ..' ;;
      ./*|*//*)     want='has an empty or . segment' ;;
      *\\*)        want='holds a backslash' ;;
      .delivery-*)  want='is inside the state directory' ;;
      *)            want='a folder name holds letters, digits, dot, dash, underscore only' ;;
    esac
    probe --dir "$T" --spec-dir "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"'$bad'"* ]] || { echo "not named: $bad"; false; }
    [[ "$stderr" == *"--spec-dir"* ]] || { echo "argument not named: $bad"; false; }
    [[ "$stderr" == *"$want"* ]] || { echo "wrong reason: $bad: $stderr"; false; }
  done
}

@test "spec folder: a folder that is already there is refused, naming it" {
  # The spec tool writes spec.md into the folder it is given. An existing
  # folder is an existing feature, and its spec would be overwritten.
  T="$BATS_TEST_TMPDIR/specdir-exists"
  mkdir -p "$T/specs/003-thing"; cd "$T"; git init -q -b work .
  probe --dir "$T" --spec-dir 'specs/003-thing'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'specs/003-thing'"* ]] || false
  [[ "$stderr" == *"already exists"* ]]
}

@test "spec folder: a run name that already has a state file is refused, naming it" {
  # The folder's last segment is the run's name. progress.sh init finds an
  # existing state file and keeps it, so a fresh run under a used name
  # would silently continue another run.
  T="$BATS_TEST_TMPDIR/specdir-run-exists"
  mkdir -p "$T/.delivery-kit/runs/003-thing"; cd "$T"; git init -q -b work .
  printf '{}\n' > "$T/.delivery-kit/runs/003-thing/progress.json"
  probe --dir "$T" --spec-dir 'specs/other/003-thing'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'003-thing'"* ]] || false
  [[ "$stderr" == *".delivery-kit/runs/003-thing/progress.json"* ]]
}

@test "base branch: an override that is not an existing branch's plain name is refused" {
  # check-ref-format --branch checks syntax only, and expands @ and @{-1}.
  # Review 2, item 7: the name must come back unchanged, and must be a local
  # branch or a branch on origin. HEAD is refused by --branch itself; the
  # looser --allow-onelevel would let it through.
  T="$BATS_TEST_TMPDIR/base-override-kinds"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  git checkout -q -b other; git checkout -q work
  git tag v1
  git remote add origin https://github.com/example/thing.git
  git update-ref refs/remotes/origin/main HEAD
  local bad
  for bad in '@' '@{-1}' 'HEAD' 'v1' "$(git rev-parse HEAD)" 'origin/main' 'refs/heads/work' 'nosuch'; do
    probe --dir "$T" --base-branch-override "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"'$bad'"* ]] || { echo "not named: $bad"; false; }
    [[ "$stderr" == *"(--base-branch-override)"* ]] || { echo "argument not named: $bad"; false; }
    # git expands @ and @{-1} to another name: that is not the typed name.
    # HEAD fails git's own check. The rest are legal names that are no
    # local branch: a tag, a commit id, a remote's branch, a full ref name.
    case "$bad" in
      @|@*|HEAD) want='is not a legal branch name' ;;
      *)         want='is not a branch here or on origin' ;;
    esac
    [[ "$stderr" == *"'$bad' $want"* ]] || { echo "wrong reason: $bad: $stderr"; false; }
  done
}

# Review 3, item 5: a name that is a branch and a tag too. `git checkout -b`
# fails as ambiguous, and <base>..HEAD reads the tag.
@test "base branch: an override that is a tag as well as a branch is refused" {
  T="$BATS_TEST_TMPDIR/base-override-amb"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  git branch amb; git tag amb
  probe --dir "$T" --base-branch-override amb
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'amb' is a tag as well as a branch; git would read the tag (--base-branch-override)"* ]] \
    || { echo "wrong reason: $stderr"; false; }
  git tag -d amb >/dev/null
  probe --dir "$T" --base-branch-override amb
  [ "$status" -eq 0 ] || { echo "refused once the tag was gone: $stderr"; false; }
}

@test "base branch: an override that exists only on origin is refused, naming the command that fixes it" {
  # branch-cut's `git checkout -b <feature> <base>` and every later `<base>..HEAD`
  # fail on a name that is only origin/<base>: both are measured here, so
  # the refusal is shown to protect a real step. A fresh clone is in this
  # state for every branch but the default.
  T="$BATS_TEST_TMPDIR/base-override-origin-only"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  git remote add origin https://github.com/example/thing.git
  git update-ref refs/remotes/origin/develop HEAD
  run git checkout -q -b feat develop
  [ "$status" -ne 0 ]
  run git rev-list develop..HEAD
  [ "$status" -ne 0 ]
  probe --dir "$T" --base-branch-override develop
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'develop' exists only on origin"* ]] || false
  [[ "$stderr" == *"git branch --track develop origin/develop"* ]] || false
  # After that command the same override is accepted.
  git branch -q --track develop origin/develop
  probe --dir "$T" --base-branch-override develop
  [ "$status" -eq 0 ]
  [ "$(jq -r '.baseBranch' <<<"$output")" = "develop" ]
}

# Feature 052, items 1 and 5 of issue #107: the override's "a local branch
# with a commit, and not a tag too" check now holds for every source. Before
# it, a base from origin/HEAD, the baseBranch key or the current branch was
# checked by name only, and phase B's `git checkout -b <feature> <base>`, now branch-cut's,
# failed, or <base>..HEAD read a tag (spec Context, cases 1a to 1f and 5a).
@test "base branch: a usable base is checked from every source" {
  local key='the baseBranch key'
  local oh="origin/HEAD; pass a base branch with the run's --base-branch flag"
  local cur='the current branch; check out another branch, or pass a base branch'
  local B="$BATS_TEST_TMPDIR/usable"

  # 1a: no commit at all; the key names the unborn current branch.
  mkdir -p "$B/1a"; cd "$B/1a"; git init -q -b main .
  refused "'main' has no commit yet; make a first commit, or pass a base branch that has one ($key)" \
    --dir "$B/1a" --base-branch main

  # 1b: the key names a branch that is nowhere.
  mkdir -p "$B/1b"; cd "$B/1b"; git init -q -b work .; seed
  refused "'main' is not a branch here or on origin ($key)" --dir "$B/1b" --base-branch main

  # 1c: the key names a tag, and no branch.
  mkdir -p "$B/1c"; cd "$B/1c"; git init -q -b work .; seed; git tag main
  refused "'main' is not a branch here or on origin ($key)" --dir "$B/1c" --base-branch main

  # 1d: the key names a branch that is a tag too.
  mkdir -p "$B/1d"; cd "$B/1d"; git init -q -b work .; seed; git branch main; git tag main
  refused "'main' is a tag as well as a branch; git would read the tag ($key)" \
    --dir "$B/1d" --base-branch main
  # The positive control: with the tag gone the same base is reported.
  git tag -d main >/dev/null
  probe --dir "$B/1d" --base-branch main
  [ "$status" -eq 0 ] || { echo "1d without the tag: exit $status: $stderr"; false; }
  [ "$(jq -r '.baseBranch' <<<"$output")" = "main" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "configured" ]

  # 1e: origin/HEAD names main, and there is no local main.
  mkdir -p "$B/1e"; cd "$B/1e"; git init -q -b work .; seed
  git remote add origin https://github.com/example/thing.git
  git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  refused "'main' exists only on origin; create the local branch first: git branch --track main origin/main ($oh)" \
    --dir "$B/1e" --base-branch main
  # The positive control: after the command the message names, it reports.
  git branch -q --track main origin/main
  probe --dir "$B/1e" --base-branch main
  [ "$status" -eq 0 ] || { echo "1e after the fix: exit $status: $stderr"; false; }
  [ "$(jq -r '.baseBranch' <<<"$output")" = "main" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "origin/HEAD" ]

  # 1f: as 1e with the local main, which is a tag too.
  git tag main
  refused "'main' is a tag as well as a branch; git would read the tag ($oh)" \
    --dir "$B/1e" --base-branch main

  # 5a: the current branch is a tag too; no remote, no base flag.
  mkdir -p "$B/5a"; cd "$B/5a"; git init -q -b work .; seed; git tag work
  refused "'work' is a tag as well as a branch; git would read the tag ($cur)" --dir "$B/5a"

  # A branch ref that names no commit. `git update-ref` refuses to write a
  # tree to a branch, and a ref file written by hand does not (measured,
  # git 2.53.0); `git checkout -b` from it exits 128. Only the files backend
  # stores a branch as a file; under reftable .git/refs/heads is a file, and
  # the case cannot be built, which the else branch asserts.
  mkdir -p "$B/tree"; cd "$B/tree"; git init -q -b work .; seed; git branch main
  if [ -d .git/refs/heads ]; then
    git rev-parse 'HEAD^{tree}' > .git/refs/heads/main
    refused "'main' does not name a commit ($key)" --dir "$B/tree" --base-branch main
  else
    [ -f .git/refs/heads ] || { echo "refs/heads is neither a folder nor a file"; false; }
  fi

  # The override gets the same check, and the one message new for it: the
  # current branch before its first commit (spec FR-011).
  mkdir -p "$B/ov-unborn"; cd "$B/ov-unborn"; git init -q -b main .
  refused "'main' has no commit yet; make a first commit, or pass a base branch that has one (--base-branch-override)" \
    --dir "$B/ov-unborn" --base-branch-override main

  # A base only origin has, named by the key: origin fetched, no origin/HEAD.
  mkdir -p "$B/key-origin"; cd "$B/key-origin"; git init -q -b work .; seed
  git update-ref refs/remotes/origin/main HEAD
  refused "'main' exists only on origin; create the local branch first: git branch --track main origin/main ($key)" \
    --dir "$B/key-origin" --base-branch main

  # A refused name is printed through the masking copy: a 250-letter name
  # is cut at 200 bytes.
  local long
  long="$(printf 'a%.0s' $(seq 250))"
  refused "'${long:0:200} [cut]' is not a branch here or on origin ($key)" --dir "$B/key-origin" --base-branch "$long"

  # A name git reads as something other than the branch. Each makes
  # `git checkout -b` exit 128 (measured, git 2.53.0, files and reftable);
  # each is refused, then reported once the other ref is gone.
  local amb="is the name of another ref as well as a branch; git cannot tell them apart ($key)"
  mkdir -p "$B/amb"; cd "$B/amb"; git init -q -b work .; seed
  # base_reports <name> — the positive control: the same name now reports.
  base_reports() {
    probe --dir "$B/amb" --base-branch "$1"
    [ "$status" -eq 0 ] || { echo "$1 once the other ref is gone: exit $status: $stderr"; false; }
    [ "$(jq -r '.baseBranch' <<<"$output")" = "$1" ]
  }
  git branch x/y; git update-ref refs/x/y HEAD
  refused "'x/y' $amb" --dir "$B/amb" --base-branch x/y
  git update-ref -d refs/x/y; base_reports x/y
  git branch origin/main; git update-ref refs/remotes/origin/main HEAD
  refused "'origin/main' $amb" --dir "$B/amb" --base-branch origin/main
  git update-ref -d refs/remotes/origin/main; base_reports origin/main
  git branch up; git update-ref refs/remotes/up/main HEAD
  git symbolic-ref refs/remotes/up/HEAD refs/remotes/up/main
  refused "'up' $amb" --dir "$B/amb" --base-branch up
  git symbolic-ref --delete refs/remotes/up/HEAD; base_reports up
  # ORIG_HEAD through update-ref, so the ref is real in either ref format.
  git branch ORIG_HEAD; git update-ref ORIG_HEAD HEAD
  refused "'ORIG_HEAD' $amb" --dir "$B/amb" --base-branch ORIG_HEAD
  git update-ref -d ORIG_HEAD; base_reports ORIG_HEAD
  git branch main-worktree/HEAD
  refused "'main-worktree/HEAD' $amb" --dir "$B/amb" --base-branch main-worktree/HEAD
  # A branch named after a git file that is no ref reports: COMMIT_EDITMSG.
  git branch COMMIT_EDITMSG; echo message > .git/COMMIT_EDITMSG
  base_reports COMMIT_EDITMSG
  # A name spelled as a full commit id: checkout -b takes the branch, while
  # rev-parse and <base>..HEAD take the commit.
  local id
  id="$(git rev-parse HEAD)"
  git branch "$id"
  refused "'$id' is spelled as a full commit id; git would read the commit, not the branch ($key)" \
    --dir "$B/amb" --base-branch "$id"

  # origin/HEAD is read as a full ref: one that names another remote's branch
  # stops pre-flight, and one beside a branch named origin/main still gives
  # main (--short gave remotes/origin/main).
  mkdir -p "$B/oh"; cd "$B/oh"; git init -q -b work .; seed; git branch main
  git update-ref refs/remotes/upstream/dev HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/upstream/dev
  refused "origin/HEAD points to a ref that is not one of origin's branches, so the remote names no base branch; pass a base branch with the run's --base-branch flag" \
    --dir "$B/oh"
  git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git update-ref refs/heads/origin/main HEAD
  probe --dir "$B/oh"
  [ "$status" -eq 0 ] || { echo "origin/HEAD beside a branch origin/main: exit $status: $stderr"; false; }
  [ "$(jq -r '.baseBranch' <<<"$output")" = "main" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "origin/HEAD" ]
}

# Feature 052, item 4 of issue #107: the current checkout used to be read
# with `git symbolic-ref --short`, which names whatever HEAD points to, so a
# HEAD pointing at a tag or a remote's branch reported `v1` or `origin/main`
# as the base branch. The full ref is read now, and one outside refs/heads/
# stops pre-flight. The message names no ref: the ref comes from the
# repository.
@test "base branch: HEAD outside refs/heads/ stops pre-flight, naming the fix" {
  # The whole line is compared, and it names no ref: v1 and origin/main come
  # from the repository.
  local want="HEAD points to a ref that is not a local branch, so the current checkout names no base branch; check out a branch, or pass a base branch (the run's --base-branch flag, or the baseBranch key)"
  T="$BATS_TEST_TMPDIR/head-outside"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  git tag v1
  git update-ref refs/remotes/origin/main HEAD
  local ref
  for ref in refs/tags/v1 refs/remotes/origin/main; do
    git symbolic-ref HEAD "$ref"
    refused "$want" --dir "$T"
  done
  # The positive control: HEAD back on the branch reports it.
  git symbolic-ref HEAD refs/heads/work
  probe --dir "$T"
  [ "$status" -eq 0 ] || { echo "on work: exit $status: $stderr"; false; }
  [ "$(jq -r '.baseBranch' <<<"$output")" = "work" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "current branch" ]
}

@test "base branch: the override is checked in the repository, not in the caller's" {
  # The check once ran before the cd into --dir, so a branch that existed
  # only where the caller stood was accepted.
  T="$BATS_TEST_TMPDIR/base-override-where"
  mkdir -p "$T/caller" "$T/repo"
  cd "$T/repo"; git init -q -b work .; seed
  cd "$T/caller"; git init -q -b work .; seed; git branch only-here
  probe --dir "$T/repo" --base-branch-override only-here
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'only-here' is not a branch here or on origin"* ]]
}

@test "feature branch: HEAD, and a name git expands to another, are refused" {
  T="$BATS_TEST_TMPDIR/branch-head"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  git checkout -q -b other; git checkout -q work
  local bad
  for bad in 'HEAD' '@{-1}' '@'; do
    probe --dir "$T" --feature-branch "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"'$bad' is not a legal branch name"*"(--feature-branch)"* ]] || { echo "wrong reason: $bad: $stderr"; false; }
  done
}

@test "feature branch: the base from origin/HEAD is refused too, with no override" {
  # The only other test of the base's own name uses the override path.
  T="$BATS_TEST_TMPDIR/branch-is-origin-head"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; main_base
  git remote add origin https://github.com/example/thing.git
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  probe --dir "$T" --feature-branch main
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'main' is the base branch 'main'"* ]]
}

@test "feature branch: the base in another letter case or behind a prefix is refused" {
  T="$BATS_TEST_TMPDIR/branch-is-base-spelled"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed; git branch main
  local bad
  for bad in 'MAIN' 'Main' 'origin/main' 'heads/main' 'refs/heads/main' 'remotes/origin/main'; do
    probe --dir "$T" --base-branch-override main --feature-branch "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"'$bad' is the base branch 'main'"* ]] || { echo "wrong reason: $bad: $stderr"; false; }
  done
}

@test "feature branch: a name that exists here or on origin, in any letter case, or clashes as a folder, is refused" {
  T="$BATS_TEST_TMPDIR/branch-exists"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  git branch 003-local
  git remote add origin https://github.com/example/thing.git
  git update-ref refs/remotes/origin/003-remote HEAD
  local bad
  git branch team
  git branch deep/one
  for bad in '003-local' '003-LOCAL' '003-remote' '003-Remote' 'team/x' 'TEAM/x' 'deep'; do
    probe --dir "$T" --feature-branch "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"'$bad' already exists as the branch"* ]] || { echo "wrong reason: $bad: $stderr"; false; }
  done
}

@test "spec folder: without --feature-branch, its last segment gets the branch checks" {
  # Review 2, item 8. B names the branch after the folder's last segment, so
  # a segment git refuses as a branch name failed late, at git checkout -b,
  # and specs/master passed with base master.
  T="$BATS_TEST_TMPDIR/specdir-as-branch"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed; git branch master; git branch 004-taken
  local bad want
  for bad in 'specs/foo.lock' 'specs/a..b' 'specs/.hidden' 'specs/master' 'specs/004-taken'; do
    case "$bad" in
      */master) want="is the base branch 'master'" ;;
      */004-taken) want='already exists as the branch' ;;
      *) want='is not a legal branch name (--spec-dir)' ;;
    esac
    probe --dir "$T" --base-branch-override master --spec-dir "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"$want"* ]] || { echo "wrong reason: $bad: $stderr"; false; }
  done
  # With --feature-branch the folder's segment is not the branch's name.
  probe --dir "$T" --base-branch-override master --spec-dir 'specs/master' --feature-branch 005-ok
  [ "$status" -eq 0 ]
}

@test "spec folder: .git, the state directory in any case, a leading dash and odd characters are refused" {
  # Review 2, items 6 and 9: every segment is checked, not only the last.
  T="$BATS_TEST_TMPDIR/specdir-places"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  local bad want
  for bad in '.Delivery-Kit/runs/x' '.delivery-kit/003-thing' '.git/x' '.GIT/hooks/post-commit' 'specs/.git/x' \
             '-x' 'specs/-x/y' '~/x' 'specs/x:y/z' $'specs/a\tb/c' $'specs/a\eb/c'; do
    case "$bad" in
      .[Dd]elivery-[Kk]it/*) want='inside the state directory' ;;
      *.[Gg][Ii][Tt]/*)      want="inside git's own directory" ;;
      -*|*/-*)               want='starts with a dash' ;;
      *)                     want='a folder name holds letters, digits, dot, dash, underscore only' ;;
    esac
    probe --dir "$T" --spec-dir "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"$want"* ]] || { echo "wrong reason: $bad: $stderr"; false; }
  done
}

# speclink <target> <name>: a symbolic link, made as tests/gate.bats
# makes one. Under Git Bash, `ln -s` without nativestrict makes a COPY, so
# pre-flight would rightly accept the path and the test would go red for no
# fault (review 3, blocking 3). `|| true`: where ln cannot make a native
# link it exits non-zero, and under errexit that would end the test before
# the check below.
speclink() {
  MSYS=winsymlinks:nativestrict ln -s "$1" "$2" 2>/dev/null || true
  [ -L "$2" ]
}

# link_or_file <target> <name>: the shape of tests/gate.bats. Makes
# <name> a symbolic link and returns 0. Only on Windows, where a runner may
# not have the right to make a link, it may instead write what a checkout
# makes in a link's place, a file holding the target path, and return 1;
# the caller then asserts that file's own refusal (link_fallback_refused).
# Anywhere else a link that cannot be made returns 2, and the caller fails.
# Which way it went is printed on file descriptor 3, as a TAP comment, so a
# passing run shows it too: bats hides a passing test's output.
link_or_file() {
  if speclink "$1" "$2"; then echo "# links: made" >&3; return 0; fi
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) ;;
    *) echo "fixture: this system made no symbolic link"; return 2 ;;
  esac
  echo "# links: not available here" >&3
  [ ! -e "$2" ] || { echo "fixture: the failed link left $2 behind"; return 2; }
  printf '%s' "$1" > "$2"
  return 1
}

# link_fallback_refused <repo> <spec folder>: the folder runs through the
# file link_or_file wrote, which pre-flight refuses as no folder.
link_fallback_refused() {
  probe --dir "$1" --spec-dir "$2"
  [ "$status" -eq 1 ] || { echo "fallback: status $status: $stderr"; return 1; }
  [ "$stderr" = "preflight: '$2' runs through '${2%%/*}', which is not a folder (--spec-dir)" ] \
    || { echo "fallback: wrong reason: $stderr"; return 1; }
}

@test "spec folder: a symbolic link out of the repository, into .git or the state directory, or dangling, is refused" {
  T="$BATS_TEST_TMPDIR/specdir-link"
  mkdir -p "$T/repo" "$T/outside"; cd "$T/repo"; git init -q -b work .; seed
  # The first link decides which way this system goes, and the test never
  # skips: a link is made, or, on Windows only, where a runner may not make
  # one, the file a checkout makes in its place is refused as no folder.
  local rc=0
  link_or_file "$T/outside" out || rc=$?
  [ "$rc" -ne 2 ] || false
  if [ "$rc" -eq 1 ]; then link_fallback_refused "$T/repo" out/003-thing; return; fi
  speclink .git gitlink || { echo "fixture: the link gitlink was not made"; false; }
  probe --dir "$T/repo" --spec-dir 'out/003-thing'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"leads outside the repository"* ]] || false
  probe --dir "$T/repo" --spec-dir 'gitlink/003-thing'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"git's or the run's own directory"* ]] || false
  # A sibling folder whose name starts with the repository's is outside it.
  mkdir -p "$T/repo-evil"
  speclink "$T/repo-evil" sibling || { echo "fixture: the link sibling was not made"; false; }
  probe --dir "$T/repo" --spec-dir 'sibling/003-thing'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"leads outside the repository"* ]] || false
  # A link into the state directory.
  mkdir -p .delivery-kit/x
  speclink .delivery-kit/x statelink || { echo "fixture: the link statelink was not made"; false; }
  probe --dir "$T/repo" --spec-dir 'statelink/003-thing'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"git's or the run's own directory"* ]] || false
  # A link that points nowhere, in the folder's own place. nativestrict
  # refuses a link to a missing target, so the target is made, linked, and
  # then removed.
  mkdir -p specs "$T/gone"
  speclink "$T/gone" specs/004-dangling || { echo "fixture: the link 004-dangling was not made"; false; }
  rmdir "$T/gone"
  [ ! -e specs/004-dangling ] || { echo "fixture: the link 004-dangling still leads somewhere"; false; }
  probe --dir "$T/repo" --spec-dir 'specs/004-dangling'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'specs/004-dangling' already exists"* ]]
}

# Review 3, item 4: Win32 drops a segment's trailing dot, so .git. is .git
# and .delivery-kit. is the state directory there; and it reads a device
# name, with or without an extension, as the device. Names that only start
# like one are ordinary.
@test "spec folder: a segment ending in a dot, or a Windows device name, is refused" {
  T="$BATS_TEST_TMPDIR/specdir-win32"; mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  local bad want
  for bad in '.git./x' '.delivery-kit./x' 'specs/x./y' 'specs/003-thing.' 'specs/nul' 'specs/CON' \
             'specs/nul.txt' 'specs/com1' 'specs/Lpt9/x' 'aux/003-thing' 'specs/prn'; do
    case "$bad" in
      *./*|*.) want='which ends with a dot; Windows drops it' ;;
      *)       want='a name Windows keeps for a device' ;;
    esac
    probe --dir "$T" --spec-dir "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"$want"* ]] || { echo "wrong reason: $bad: $stderr"; false; }
  done
  probe --dir "$T" --spec-dir 'specs/console/nullable'
  [ "$status" -eq 0 ] || { echo "refused an ordinary name: $stderr"; false; }
}

@test "spec folder: a trailing slash is dropped; a file in its place is refused" {
  T="$BATS_TEST_TMPDIR/specdir-shapes"
  mkdir -p "$T/specs"; cd "$T"; git init -q -b work .; seed
  probe --dir "$T" --spec-dir 'specs/003-thing/'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.specDir' <<<"$output")" = "specs/003-thing" ]
  printf 'x\n' > specs/004-file
  probe --dir "$T" --spec-dir 'specs/004-file'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'specs/004-file' already exists"* ]] || false
  printf 'x\n' > specs/notdir
  probe --dir "$T" --spec-dir 'specs/notdir/005-thing'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"which is not a folder"* ]]
}

@test "trailers: without the argument the list is reported empty" {
  T="$BATS_TEST_TMPDIR/trailers-absent"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  probe --dir "$T"
  [ "$status" -eq 0 ]
  [ "$(jq -c '.commitTrailers' <<<"$output")" = '[]' ]
}

@test "trailers: each one is reported, in the order given" {
  # The orchestrator passes the key's trailers first, then the flags'. The
  # script keeps that order, so the probe line and the commits match it.
  T="$BATS_TEST_TMPDIR/trailers-named"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  probe --dir "$T" --trailer 'Team: one' --trailer 'Task: T-12 (second part)'
  [ "$status" -eq 0 ]
  [ "$(jq -c '.commitTrailers' <<<"$output")" = '["Team: one","Task: T-12 (second part)"]' ]
}

@test "trailers: a malformed trailer is refused, naming it, one case per check" {
  # One case per check in the script. Each value passes every check but
  # its own, so skipping any one check turns exactly one case green. The
  # error names no flag: the value may have come from the key.
  T="$BATS_TEST_TMPDIR/trailers-bad"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  local bad
  for bad in 'Noseparator' 'Bad token: x' 'Bad_token: x' ': no token' '9x: y' 'Piece-: x' 'A: x' \
             'Empty:' 'Empty:   ' $'Two: lines\nhere' $'Return: here\rthere' $'Tab: a\tb' $'Esc: a\e[31mb' \
             $'Nel: a\xc2\x85b'; do
    probe --dir "$T" --trailer "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    # A control character is named as JSON, never printed raw.
    case "$bad" in
      *[[:cntrl:]]*|Nel*)
        [[ "$stderr" == *"\"${bad%%:*}:"* ]] || { echo "not named as JSON: $bad"; false; }
        ! printf '%s' "$stderr" | LC_ALL=C grep -q $'[\x01-\x08\x0b-\x1f\x7f]\|\xc2[\x80-\x9f]' \
          || { echo "a control character reached stderr raw: $bad"; false; } ;;
      *) [[ "$stderr" == *"'$bad'"* ]] || { echo "not named: $bad"; false; } ;;
    esac
    [[ "$stderr" == *"(a commit trailer)"* ]] || { echo "source not named: $bad"; false; }
    # A line break is also a control character; its own reason must win.
    case "$bad" in
      *$'\n'*|*$'\r'*) [[ "$stderr" == *"holds a line break"* ]] || { echo "line break not named: $bad"; false; } ;;
    esac
  done
}

@test "trailers: dashed tokens and tokens holding a marker's letters are accepted, in order" {
  # A reserved-token match by prefix or substring would refuse these, and no
  # other test passes a dashed token.
  T="$BATS_TEST_TMPDIR/trailers-dashed"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  probe --dir "$T" --trailer 'Plan-Item: a' --trailer 'Pieces: b' --trailer 'XPiece: c' --trailer 'Related: d'
  [ "$status" -eq 0 ]
  [ "$(jq -c '.commitTrailers' <<<"$output")" = '["Plan-Item: a","Pieces: b","XPiece: c","Related: d"]' ]
}

@test "trailers: a value holding a colon is reported whole" {
  # The token ends at the FIRST colon; taking it up to the last would cut
  # the URL.
  T="$BATS_TEST_TMPDIR/trailers-url"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  probe --dir "$T" --trailer 'Ref: https://example.invalid/a'
  [ "$status" -eq 0 ]
  [ "$(jq -c '.commitTrailers' <<<"$output")" = '["Ref: https://example.invalid/a"]' ]
}

@test "trailers: one that skips GitHub's checks, names another author or closes an issue is refused" {
  T="$BATS_TEST_TMPDIR/trailers-github"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  local bad want
  for bad in 'skip-checks: true' 'Note: [skip ci]' 'Note: a [CI Skip] b' 'Note: [no ci]' \
             'Note: [Skip Actions]' 'Note: [actions skip]' 'Co-authored-by: A <a@example.invalid>' \
             'signed-off-by: A <a@example.invalid>' 'Fixes: #1' 'Closes: owner/repo#1' 'Note: this fixes #12' \
             'Note: fixes: #1' 'Note: closes o/r#1'; do
    case "$bad" in
      skip-checks*|Co-*|signed-*|Fixes*|Closes*) want='which acts on GitHub or names another author' ;;
      *'#12'|*'#1') want='would close an issue' ;;
      *) want='asks GitHub to skip the checks' ;;
    esac
    probe --dir "$T" --trailer "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"'$bad'"* ]] || { echo "not named: $bad"; false; }
    [[ "$stderr" == *"$want"* ]] || { echo "reason not named: $bad: $stderr"; false; }
  done
}

@test "trailers: one that credits an AI, Assisted-by or Generated-by, is refused at pre-flight" {
  # The owner never wants AI attribution on a commit: a commitTrailers entry
  # crediting one is refused from every layer, as Co-authored-by is.
  T="$BATS_TEST_TMPDIR/trailers-ai"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  local bad
  for bad in 'Assisted-by: Claude' 'Generated-by: Claude Code'; do
    probe --dir "$T" --trailer "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"'$bad' uses the token '${bad%%:*}', which acts on GitHub or names another author"* ]] \
      || { echo "reason not named: $bad: $stderr"; false; }
  done
  # In any letter case, as every refused token is.
  local tc="$ROOT/pipeline/scripts/trailer-check.sh" err rc
  for bad in 'ASSISTED-BY: x' 'generated-BY: y'; do
    rc=0; err="$(bash "$tc" "\"$bad\"" 2>&1 >/dev/null)" || rc=$?
    [ "$rc" -eq 1 ] || { echo "accepted: $bad"; false; }
    [[ "$err" == *"uses the token '${bad%%:*}', which acts on GitHub"* ]] || { echo "wrong reason: $bad: $err"; false; }
  done
}

# Review 3, blocking 1: the trailer rule refuses every character in
# HIDDEN_CHARS, the list progress.sh refuses in a question, and prints each
# one as its \u escape, never raw. The lists below are each range's two
# edges (as pending.bats pins them) and every other character the review
# found accepted; the characters beside the ranges, ordinary Arabic text
# and an emoji with a skin tone are accepted. trailer-check.sh is run
# directly, and the lists are split over three tests: each check costs
# about a second on Windows, and a test has 60.
# hidden_refused <\uXXXX as JSON>... — each, inside a trailer, is refused,
# shown escaped, for the right reason.
hidden_refused() {
  local tc="$ROOT/pipeline/scripts/trailer-check.sh" c err rc
  for c in "$@"; do
    rc=0; err="$(bash "$tc" "\"Note: a${c}b\"" 2>&1 >/dev/null)" || rc=$?
    [ "$rc" -eq 1 ] || { echo "accepted: Note: a${c}b (rc $rc)"; return 1; }
    [[ "$err" == "\"Note: a${c}b\" holds a"* ]] || { echo "not shown escaped: ${c}: $err"; return 1; }
    case "$c" in
      '\u0080'|'\u009f') [[ "$err" == *"holds a control character"* ]] || { echo "wrong reason: ${c}: $err"; return 1; } ;;
      *) [[ "$err" == *"holds a character that can disguise text in a terminal"* ]] || { echo "wrong reason: ${c}: $err"; return 1; } ;;
    esac
  done
}

@test "trailers: the hidden-character ranges' lower edges are refused and shown escaped" {
  hidden_refused \
    '\u0080' '\u00ad' '\u034f' '\u115f' '\u17b4' '\u180b' '\u200b' '\u2028' '\u202e' '\u206f' '\ufe00' \
    '\ufeff' '\ufff0' '\ud82f\udca0' '\ud834\udd73' '\udb40\udc00'
}

@test "trailers: the hidden-character ranges' upper edges are refused and shown escaped" {
  hidden_refused \
    '\u009f' '\u061c' '\u1160' '\u17b5' '\u180f' '\u200f' '\u2029' '\u2060' '\u3164' '\ufe0f' \
    '\uffa0' '\ufffb' '\ud82f\udca3' '\ud834\udd7a' '\udb43\udfff'
}

@test "trailers: the review's hidden characters are refused, and the characters beside the ranges are not" {
  hidden_refused \
    '\u2066' '\u200c' '\u200d' '\u200e' '\u180e' '\udb40\udc01' '\udb40\udc41' \
    '\udb40\udc80' '\udb40\udcff' '\udb40\uddf0'
  local tc="$ROOT/pipeline/scripts/trailer-check.sh" c err rc
  for c in \
    '\u00a0' '\u00ac' '\u00ae' '\u2010' '\u202f' '\u2027' '\u2070' '\ufe10' '\u180a' '\u1810' '\uffef' '\ufffc' \
    'مرحبا' '👍🏽'; do
    rc=0; err="$(bash "$tc" "\"Note: a${c}b\"" 2>&1 >/dev/null)" || rc=$?
    [ "$rc" -eq 0 ] || { echo "refused: ${c}: $err"; false; }
  done
}

# Review 3, blocking 2: a closing keyword counts anywhere in the trailer,
# its token included, before an issue in every form GitHub reads; and
# On-behalf-of, which GitHub reads as the commit's organisation, is refused
# as Co-authored-by is. A keyword without an issue, an issue without a
# keyword, and a keyword inside a word are accepted.
@test "trailers: every form that closes an issue, and On-behalf-of, is refused" {
  local tc="$ROOT/pipeline/scripts/trailer-check.sh" v err rc
  for v in 'Will-Fix: #1' 'X-Closes: o/r#2' 'Auto-Resolves: #3' 'Ref: fixes https://github.com/o/r/issues/1' \
           'Ref: closes GH-1' 'Ref: fixes:#1' 'Ref: Resolved http://example.invalid/o/r/issues/7'; do
    rc=0; err="$(bash "$tc" "\"$v\"" 2>&1 >/dev/null)" || rc=$?
    [ "$rc" -eq 1 ] || { echo "accepted: $v"; false; }
    [ "$err" = "'$v' would close an issue" ] || { echo "wrong reason: $v: $err"; false; }
  done
  for v in 'On-behalf-of: org' 'ON-BEHALF-OF: org'; do
    rc=0; err="$(bash "$tc" "\"$v\"" 2>&1 >/dev/null)" || rc=$?
    [ "$rc" -eq 1 ] || { echo "accepted: $v"; false; }
    [[ "$err" == *"uses the token '${v%%:*}', which acts on GitHub"* ]] || { echo "wrong reason: $v: $err"; false; }
  done
  for v in 'Prefix: #1' 'Ref: https://github.com/o/r/issues/1' 'Ref: fixes nothing' 'Note: gh-1' 'Note: suffix #1'; do
    rc=0; err="$(bash "$tc" "\"$v\"" 2>&1 >/dev/null)" || rc=$?
    [ "$rc" -eq 0 ] || { echo "refused: $v: $err"; false; }
  done
}

@test "trailers: the run's own markers Piece, Late and Tasks are refused, in any letter case" {
  # The crash scans read Piece:, Late: and Tasks: lines as the run's own
  # records, and progress.sh writes them. A trailer with one of these tokens
  # would be read as one.
  T="$BATS_TEST_TMPDIR/trailers-reserved"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  local bad
  for bad in 'Piece: x' 'late: J' 'PIECE: y' 'Tasks: T001' 'tAsKs: T002'; do
    probe --dir "$T" --trailer "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"'$bad'"* ]] || { echo "not named: $bad"; false; }
    [[ "$stderr" == *"reserved"* ]] || { echo "reason not named: $bad"; false; }
  done
}

@test "stdout is pure JSON even when stderr is talking" {
  probe --dir "$FIX/other" --base-branch main
  jq -e . <<<"$output" > /dev/null
  [ -n "$stderr" ]
}

@test "capabilities reports jq true and booleans for gh and adb" {
  probe --dir "$FIX/web" --base-branch main
  jq -e '.capabilities.jq == true' <<<"$output" > /dev/null
  # The type, never a pattern over jq -r's text: -r prints the string "true"
  # exactly as it prints the boolean, so a pattern passed on both.
  jq -e '.capabilities.gh | type == "boolean"' <<<"$output" > /dev/null
  jq -e '.capabilities.adb | type == "boolean"' <<<"$output" > /dev/null
}

# Feature 054. A walk over the whole report, naming no field: every boolean
# the script passes in with --argjson is in every report, whatever its value,
# so one fixture reaches them all, and one passed with --arg instead arrives
# as the string "true" or "false". A boolean added to the report later is
# covered the day it lands, with no list to update. It checks how the report
# is built, not what a caller supplies: a branch named "true" would be a
# legitimate string, and this fixture supplies no such value.
@test "no report field is the string \"true\" or \"false\"" {
  probe --dir "$FIX/web" --base-branch main
  [ "$status" -eq 0 ]
  # paths() never yields the root, so a report that IS the string "true"
  # would pass the walk: the root's type is checked first.
  jq -e 'type == "object"' <<<"$output" > /dev/null
  # Only a string can equal "true" or "false", so one call both tests and
  # names them. Output that is not JSON leaves $bad empty, never "[]".
  bad="$(jq -c '[paths(. == "true" or . == "false")]' <<<"$output")"
  [ "$bad" = "[]" ] || { echo "string booleans at: $bad"; false; }
}

@test "willSkip names phases L and M in a repository with no remote" {
  T="$BATS_TEST_TMPDIR/skips"
  mkdir -p "$T"; cd "$T"; git init -q .; main_base
  probe --dir "$T" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '[.willSkip[].phase] | index("L") != null' <<<"$output")" = "true" ]
  [ "$(jq -r '[.willSkip[].phase] | index("M") != null' <<<"$output")" = "true" ]
}

@test "tree reports dirty and runsLive from the facts on disk" {
  T="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$T"; cd "$T"; git init -q .; main_base
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.tree.dirty' <<<"$output")" = "false" ]
  [ "$(jq -r '.tree.runsLive' <<<"$output")" = "false" ]
  printf 'x' > dirt.txt
  mkdir -p .delivery-kit/runs/001-x
  printf '{"current_phase":"B"}' > .delivery-kit/runs/001-x/progress.json
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.tree.dirty' <<<"$output")" = "true" ]
  [ "$(jq -r '.tree.runsLive' <<<"$output")" = "true" ]
  not_read_is '[]'
}

@test "a working tree whose status cannot be read stops pre-flight" {
  # Feature 051. With .git/index overwritten, git status --porcelain exits
  # 128 and prints nothing, which the old script read as a clean tree.
  T="$BATS_TEST_TMPDIR/badindex"
  mkdir -p "$T"; cd "$T"; git init -q -b work .; main_base
  printf 'garbage' > .git/index
  # The precondition: git still opens the repository, so gitUsable is true
  # and this is a read that fails under a usable git.
  git rev-parse --git-dir > /dev/null || { echo "precondition: git no longer opens the repository"; false; }
  probe --dir "$T" --base-branch main
  [ "$status" -eq 1 ] || { echo "exit $status, want 1: $output"; false; }
  [ -z "$output" ] || { echo "a report was printed: $output"; false; }
  # The whole message is compared, so none of git's own text rides along.
  [ "$stderr" = "preflight: the working tree's status could not be read: git status failed, so pre-flight cannot tell whether the tree is clean; run git status to see why" ] \
    || { echo "wrong stop: $stderr"; false; }
}

# Feature 052, item 2 of issue #107: `git status --porcelain` exits 0 and
# prints nothing for work the repository's own configuration hides, so the
# report said the tree was clean (spec Context, 2b and 2d). The status read
# now passes --untracked-files=normal and --ignore-submodules=none, which
# beat the configuration, and a file marked assume-unchanged counts as a
# change: git does not look at it, so nobody can say it is clean.
# dirty_is <want> <repo> [probe args...] — the probe reports, and tree.dirty
# is <want>.
dirty_is() {
  local want=$1 dir=$2; shift 2
  probe --dir "$dir" --base-branch main "$@"
  [ "$status" -eq 0 ] || { echo "$dir: exit $status: $stderr"; false; }
  jq -e --argjson w "$want" '.tree.dirty == $w' <<<"$output" >/dev/null \
    || { echo "$dir: tree.dirty is $(jq -c '.tree.dirty' <<<"$output"), want $want"; false; }
}

@test "tree: work the repository's configuration hides from git status is dirty" {
  local B="$BATS_TEST_TMPDIR/hidden-work"

  # 2b: status.showUntrackedFiles=no hides an untracked file.
  mkdir -p "$B/2b"; cd "$B/2b"; git init -q -b main .
  echo x > f; git add f; commit_staged f
  git config status.showUntrackedFiles no
  dirty_is false "$B/2b"
  echo new > u
  dirty_is true "$B/2b"

  # 2d: an assume-unchanged file, not even changed, counts as a change.
  mkdir -p "$B/2d"; cd "$B/2d"; git init -q -b main .
  echo x > f; git add f; commit_staged f
  dirty_is false "$B/2d"
  git update-index --assume-unchanged f
  dirty_is true "$B/2d"
  # git status shows nothing here, so pre-flight says why on stderr.
  [ "$stderr" = "preflight: tracked files marked assume-unchanged: 1; git does not look at them, so the tree is read as dirty (git ls-files -v shows each with a lowercase tag; core.ignoreStat marks every file so)" ] \
    || { echo "no reason given: $stderr"; false; }
  # From a subfolder too: the listing covers the whole tree, as the status
  # read does, so an assume-unchanged file above the folder still counts.
  mkdir sub; echo y > sub/g; git add sub/g; commit_staged g
  dirty_is true "$B/2d/sub"
  # GIT_LITERAL_PATHSPECS in the environment reads `:/` as a file name, which
  # listed nothing; the listing turns it off for itself.
  export GIT_LITERAL_PATHSPECS=1
  dirty_is true "$B/2d/sub"
  unset GIT_LITERAL_PATHSPECS
  git update-index --no-assume-unchanged f
  dirty_is false "$B/2d/sub"

  # A submodule with a new commit checked out, hidden by either setting.
  mkdir -p "$B/sub-src"; cd "$B/sub-src"; git init -q -b main .
  echo a > a; git add a; commit_staged a
  mkdir -p "$B/super"; cd "$B/super"; git init -q -b main .
  echo x > f; git add f; commit_staged f
  git -c protocol.file.allow=always submodule add -q "$B/sub-src" s
  commit_staged sub
  dirty_is false "$B/super"
  # A change inside the submodule, not committed: --ignore-submodules=dirty
  # or =untracked would still hide it; only =none reports it. The file's own
  # bytes are kept and put back: under core.autocrlf=true (the Windows
  # runner's) the checkout wrote CRLF, and an `echo` back wrote LF, which
  # git then reads as a change (measured with autocrlf=true on Linux).
  cp s/a "$B/a.kept"
  echo changed > s/a
  git config submodule.s.ignore all
  dirty_is true "$B/super"
  cp "$B/a.kept" s/a
  git config --unset submodule.s.ignore
  dirty_is false "$B/super"
  ( cd s && echo b > b && git add b && commit_staged b )
  git config submodule.s.ignore all
  dirty_is true "$B/super"
  git config --unset submodule.s.ignore
  git config diff.ignoreSubmodules all
  dirty_is true "$B/super"
}

# The limits the owner chose to document rather than detect (spec FR-006):
# a sparse checkout marks every file outside its cone skip-worktree on a
# clean tree, so skip-worktree cannot mean hidden work. And a listing that
# fails stops pre-flight, as a failed status read does.
@test "tree: a skip-worktree file and a clean sparse checkout are not dirty" {
  local B="$BATS_TEST_TMPDIR/not-hidden"

  # 2c: a skip-worktree file, changed, is not seen (a documented limit).
  mkdir -p "$B/2c"; cd "$B/2c"; git init -q -b main .
  echo x > f; git add f; commit_staged f
  git update-index --skip-worktree f
  echo changed > f
  dirty_is false "$B/2c"

  # A clean sparse checkout.
  mkdir -p "$B/sparse/a" "$B/sparse/b"; cd "$B/sparse"; git init -q -b main .
  echo 1 > a/1; echo 2 > b/2; git add a b; commit_staged ab
  git sparse-checkout set a
  [ ! -e b/2 ] || { echo "the sparse checkout did not apply"; false; }
  dirty_is false "$B/sparse"

  # The listing fails while git status works: a git that refuses ls-files.
  local d="$BATS_TEST_TMPDIR/no-ls-files" real
  real="$(command -v git)"
  shimdir "$d" awk grep head jq od
  printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = ls-files ] && exit 1; done\nexec "%s" "$@"\n' "$real" > "$d/git"
  chmod +x "$d/git"
  refused "the index could not be read: git ls-files failed, so pre-flight cannot tell whether the tree is clean; run git ls-files -v to see why" \
    --path "$d" --dir "$B/2c" --base-branch main
  # The listing runs only on a clean status: with an untracked file the tree
  # is already dirty, and the same refusing git is never asked.
  echo new > "$B/2c/u"
  probe --path "$d" --dir "$B/2c" --base-branch main
  [ "$status" -eq 0 ] || { echo "a dirty status still listed the index: exit $status: $stderr"; false; }
  jq -e '.tree.dirty == true' <<<"$output" >/dev/null || { echo "not dirty: $output"; false; }
  rm "$B/2c/u"
  # The positive control: the same search path with a git that answers
  # ls-files reports.
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$real" > "$d/git"
  probe --path "$d" --dir "$B/2c" --base-branch main
  [ "$status" -eq 0 ] || { echo "the plain shim: exit $status: $stderr"; false; }
}

# A DONE run and an abandoned one are not live. Both are made by the real
# progress.sh, so the marker pre-flight reads is the one abandon writes. A
# mutant that compared current_phase with anything but DONE passed this
# suite before this test (measured: 35 of 35).
@test "a DONE run and an abandoned run are not live; each live run is named" {
  local P="$PIPELINE/scripts/progress.sh"
  T="$BATS_TEST_TMPDIR/ended"
  mkdir -p "$T"; cd "$T"; git init -q .; main_base
  bash "$P" init 001-done b main web > /dev/null
  bash "$P" phase-start 001-done DONE
  probe --dir "$T" --base-branch main
  [ "$status" -eq 0 ]
  jq -e '.tree.runsLive == false and .tree.liveRuns == [] and .tree.unreadableRuns == []' <<<"$output" > /dev/null \
    || { echo "a DONE run read as live: $(jq -c .tree <<<"$output")"; false; }
  bash "$P" init 002-gone b main web > /dev/null
  bash "$P" phase-start 002-gone F
  probe --dir "$T" --base-branch main
  jq -e '.tree.runsLive == true and .tree.liveRuns == ["002-gone"]' <<<"$output" > /dev/null \
    || { echo "a live run was not named: $(jq -c .tree <<<"$output")"; false; }
  bash "$P" abandon 002-gone
  probe --dir "$T" --base-branch main
  # Ended, not unreadable: a judge that missed the marker and fell through
  # to "unreadable" would also leave runsLive false (measured, mutation).
  jq -e '.tree.runsLive == false and .tree.liveRuns == [] and .tree.unreadableRuns == []' <<<"$output" > /dev/null \
    || { echo "an abandoned run read as live or unreadable: $(jq -c .tree <<<"$output")"; false; }
  [[ "$stderr" != *"is not one JSON object"* ]] || { echo "an abandoned run was warned about: $stderr"; false; }
  bash "$P" init 003-live b main web > /dev/null
  bash "$P" init 004-live b main web > /dev/null
  probe --dir "$T" --base-branch main
  jq -e '.tree.runsLive == true and .tree.liveRuns == ["003-live", "004-live"]' <<<"$output" > /dev/null \
    || { echo "the live runs were not both named: $(jq -c .tree <<<"$output")"; false; }
  jq -e '.tree.runsLive | type == "boolean"' <<<"$output" > /dev/null
}

# A state file pre-flight cannot read as a run used to count as live,
# silently and for good: abandon cannot mark a file it cannot read. It is
# warned about, named, and not counted; the report stays pure JSON.
@test "an unreadable state file is warned about and named, never counted as live" {
  local f
  T="$BATS_TEST_TMPDIR/garbage"
  mkdir -p "$T"; cd "$T"; git init -q .; main_base
  for f in 001-garbage 002-empty 003-array 004-twice 005-nophase; do mkdir -p ".delivery-kit/runs/$f"; done
  printf 'garbage' > .delivery-kit/runs/001-garbage/progress.json
  : > .delivery-kit/runs/002-empty/progress.json
  printf '[1]' > .delivery-kit/runs/003-array/progress.json
  printf '{"current_phase":"B"}{"current_phase":"B"}' > .delivery-kit/runs/004-twice/progress.json
  printf '{"current_phase":7}' > .delivery-kit/runs/005-nophase/progress.json
  probe --dir "$T" --base-branch main
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
  jq -e '.tree.runsLive == false and .tree.liveRuns == []
    and .tree.unreadableRuns == ["001-garbage", "002-empty", "003-array", "004-twice", "005-nophase"]' <<<"$output" > /dev/null \
    || { echo "unreadable state files were misjudged: $(jq -c .tree <<<"$output")"; false; }
  for f in 001-garbage 002-empty 003-array 004-twice 005-nophase; do
    [[ "$stderr" == *"the state file of run '$f' is not one JSON object with a current_phase"* ]] \
      || { echo "no warning named $f: $stderr"; false; }
  done
}

@test "constitutionSet is false on a fresh-init-shaped constitution" {
  probe --dir "$FIX/constitution-unset" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ]
}

@test "constitutionSet is true once the constitution carries real principles" {
  probe --dir "$FIX/constitution-set" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "true" ]
}

# --- refusals -----------------------------------------------------------------
# Each of these exits non-zero, so a test could "pass" on the status alone while
# the message said nothing, or named the wrong thing. The naming IS the property
# — it is what a person reads at the moment nothing works yet — so every one of
# these asserts on the message and not merely on the status.

@test "an unrecognised argument is refused, naming it and listing the legal ones" {
  probe --nope
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'--nope'"* ]]
  [[ "$stderr" == *"--dir --project-type --base-branch"* ]]
}

@test "a flag supplied without its value is refused, naming what the flag needed" {
  probe --dir
  [ "$status" -ne 0 ]
  # Assert on the phrase the script chose, and on nothing else in this line.
  # It is emitted by the shell's own ${2:?...} expansion rather than by the
  # script's die(), so it also carries the script's path and a LINE NUMBER —
  # and that number moves every time the script is edited. A test that pinned
  # it would go red on an unrelated change and teach people to loosen it.
  [[ "$stderr" == *"--dir needs a path"* ]]
}

@test "a directory that cannot be entered is refused, naming the directory" {
  gone="$BATS_TEST_TMPDIR/no-such-directory"
  probe --dir "$gone" --base-branch main
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"cannot enter '$gone'"* ]]
}

@test "a required tool absent is refused BY NAME, not merely non-zero" {
  # An empty search path breaks the probe several ways at once, so a test
  # asserting only a non-zero exit would pass for any of them — including for
  # the interpreter never starting. Name the tool, and reach it through an
  # absolute interpreter, because stripping PATH removes bash too.
  empty="$BATS_TEST_TMPDIR/empty-path"
  mkdir -p "$empty"
  probe --path "$empty" --dir "$FIX/web" --base-branch main
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"jq is required and was not found on PATH"* ]]
}

# --- warnings that do not stop the run ----------------------------------------
# The probe exits ZERO in every one of these, so the status carries no
# information and asserting on it would prove nothing. Each asserts on the
# diagnostic stream's CONTENT, and each also confirms the data stream still
# parses whole — a warning leaking into the data stream is the regression these
# exist to catch, and it would be invisible to a stderr-only assertion.
#
# Each fixture is shaped to fire exactly ONE warning. A fixture missing its
# whole init-options file fires two at once, and a test built on that could
# attribute neither.

@test "an empty recorded version warns, succeeds, and leaves the data stream whole" {
  probe --dir "$FIX/speckit-no-version" --base-branch main
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"no version recorded"* ]]
  jq -e . <<<"$output" > /dev/null
  [ "$(jq -r '.speckit.version' <<<"$output")" = "" ]
}

@test "an empty recorded script flavour warns, succeeds, and leaves the data stream whole" {
  probe --dir "$FIX/speckit-no-flavour" --base-branch main
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"no script flavour recorded"* ]]
  jq -e . <<<"$output" > /dev/null
  [ "$(jq -r '.speckit.script' <<<"$output")" = "" ]
}

@test "a foreign agent's skills give the warning and an invocationForm of none, together" {
  # Both halves, in ONE run — that pairing is the requirement. The fixture
  # carries no .claude/skills/speckit-* and no .claude/commands/speckit.*.md:
  # either one holds the form away from none and silences the warning outright,
  # which is the measured negative control behind this test.
  probe --dir "$FIX/foreign-agent" --base-branch main
  [ "$status" -eq 0 ]
  [[ "$stderr" == *".agents/skills/"* ]]
  [[ "$stderr" == *"not adopting it"* ]]
  jq -e . <<<"$output" > /dev/null
  [ "$(jq -r '.speckit.invocationForm' <<<"$output")" = "none" ]
}

@test "a constitution saved in an unreadable encoding warns and reads as not set" {
  probe --dir "$FIX/constitution-nul" --base-branch main
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"NUL bytes"* ]]
  jq -e . <<<"$output" > /dev/null
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ]
}

@test "a NUL in the constitution is found even when the reader stops at its first match" {
  # The check once piped od into `grep -q` under pipefail. grep -q leaves at
  # its first match, od can then die of SIGPIPE writing into the closed pipe,
  # and the failed pipeline sent the check down the "no NUL" branch: the
  # constitution read as SET. That needed a loaded machine to show. This fake
  # od removes the luck: a NUL line, then about 200 KB more, far past what a
  # pipe holds after its reader has gone. Its last command is `yes | head`,
  # so a write into a closed pipe fails the stub: head dies of SIGPIPE, and
  # GNU head also exits non-zero on EPIPE where SIGPIPE is ignored. A head
  # that does not check its writes could let this test pass on the old line
  # there; the late-failure test below pins the same rule on every system.
  local d="$BATS_TEST_TMPDIR/od-stub"
  mkdir -p "$d"
  printf '%s\n' '#!/usr/bin/env bash' \
    'cat > /dev/null' \
    "printf ' ff fe 23 00\\n'" \
    "yes ' 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41' | head -n 4000" \
    > "$d/od"
  chmod +x "$d/od"
  PATH="$d:$PATH" probe --dir "$FIX/constitution-nul" --base-branch main
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
  [[ "$stderr" == *"NUL bytes"* ]] || { echo "no NUL warning: $stderr"; false; }
  jq -e '.speckit.constitutionSet == false' <<<"$output" > /dev/null \
    || { echo "read as: $(jq -c '.speckit.constitutionSet' <<<"$output")"; false; }
}

@test "a NUL captured before the reading pipeline fails still reads as not set" {
  # A late failure: od has written the NUL line, then exits non-zero. The
  # check must keep what it captured, not throw it away and fail toward
  # set. Whatever awk would make of the UTF-16 bytes, only the NUL branch
  # gives the warning, so the warning is the deterministic observable.
  local d="$BATS_TEST_TMPDIR/od-late-fail"
  mkdir -p "$d"
  printf '%s\n' '#!/usr/bin/env bash' \
    'cat > /dev/null' \
    "printf ' ff fe 23 00\\n'" \
    'exit 1' \
    > "$d/od"
  chmod +x "$d/od"
  PATH="$d:$PATH" probe --dir "$FIX/constitution-nul" --base-branch main
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [[ "$stderr" == *"NUL bytes"* ]] || { echo "no NUL warning: $stderr"; false; }
  jq -e '.speckit.constitutionSet == false' <<<"$output" > /dev/null \
    || { echo "read as: $(jq -c '.speckit.constitutionSet' <<<"$output")"; false; }
}

@test "a failed read of the constitution's head still reaches the parse and exits 0" {
  # The NUL check captures `head -c 4096 | od`; when that pipeline fails, the
  # check must keep what it captured and fall through to the parse, not abort
  # pre-flight under errexit. This fake head fails with no output. The
  # fixture is the placeholder template: the parse finds its tokens, so not
  # set is defined by the token rule alone. (On the NUL fixture the UTF-16
  # bytes would reach awk, whose answer is not defined.) The probe calls
  # head nowhere else, so the stub can fail unconditionally; the marker file
  # proves it ran.
  local d="$BATS_TEST_TMPDIR/head-stub"
  mkdir -p "$d"
  printf '%s\n' '#!/usr/bin/env bash' \
    ": > \"$d/called\"" \
    'exit 1' \
    > "$d/head"
  chmod +x "$d/head"
  PATH="$d:$PATH" probe --dir "$FIX/constitution-unset" --base-branch main
  [ -f "$d/called" ] || { echo "the fake head never ran"; false; }
  [ "$status" -eq 0 ] || { echo "status $status: $stderr"; false; }
  [[ "$stderr" != *"NUL bytes"* ]] || { echo "NUL warning on no NUL: $stderr"; false; }
  jq -e '.speckit.constitutionSet == false' <<<"$output" > /dev/null \
    || { echo "read as: $(jq -c '.speckit.constitutionSet' <<<"$output")"; false; }
}

# --- the governance parser's remaining edges ----------------------------------

@test "a byte-order mark is stripped before the constitution is judged" {
  # The fixture is a mark followed by NOTHING BUT WHITESPACE, and it has to be.
  # A mark followed by real prose reads as set with or without the stripping,
  # because the mark merely rides in front of text that already counts — that
  # fixture is vacuous, measured twice. Here the mark is the only candidate for
  # content, so stripping it is the whole difference.
  probe --dir "$FIX/constitution-bom" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ]
}

@test "a comment opened and never closed does not swallow the rest of the file" {
  # The fixture OPENS with the comment, on its very first byte. Any real text
  # before it would make the file read as set whether or not the text after the
  # comment survived — vacuous for the same reason as the mark above.
  probe --dir "$FIX/constitution-unclosed" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "true" ]
}

# --- announced degradations, per cause ----------------------------------------
# The ambient environment cannot be trusted here and these tests do not read it.
# On the development machine the command-line client is a shim this shell cannot
# see; on every CI runner it is present. The device tool is the reverse. A test
# that relied on either would pass on one platform and fail on the other — or,
# worse, pass on both for different reasons. Each builds its own search path.

@test "trailers are checked with only the probe's own tools on the search path" {
  # trailer-check.sh says it needs jq alone, and these tests give the probe
  # nothing but its own tools. This proves it: an accepted trailer and a
  # refused one, with exactly PROBE_TOOLS findable.
  d="$BATS_TEST_TMPDIR/trailer-tools"
  shimdir "$d" $PROBE_TOOLS
  probe --path "$d" --dir "$FIX/web" --base-branch main --trailer 'Plan-Item: a'
  [ "$status" -eq 0 ] || { echo "refused with only PROBE_TOOLS: $stderr"; false; }
  [ "$(jq -c '.commitTrailers' <<<"$output")" = '["Plan-Item: a"]' ]
  probe --path "$d" --dir "$FIX/web" --base-branch main --trailer 'Note: [skip ci]'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"asks GitHub to skip the checks"* ]]
}

@test "the runtime-check phase is announced skipped when a mobile project has no device tool" {
  d="$BATS_TEST_TMPDIR/no-device"
  shimdir "$d" $PROBE_TOOLS
  probe --path "$d" --dir "$FIX/mobile-android" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.capabilities.adb' <<<"$output")" = "false" ]
  # Select by PHASE, never by index. This run also announces a review skip,
  # because the fixture repository has a GitHub remote while
  # the client is off the shim path — so reading willSkip[0] would pass or fail
  # on ordering rather than on the property.
  [ "$(jq -r '[.willSkip[] | select(.phase=="N.5")] | length' <<<"$output")" = "1" ]
  [[ "$(jq -r '[.willSkip[] | select(.phase=="N.5")] | .[0].reason' <<<"$output")" == *"adb"* ]]
}

@test "the review phase is announced skipped for both of its causes" {
  # ONE test for the two routes to the M skip. They were one branch with one
  # reason; they are now two branches with two reasons, each pinned below.
  # The already-covered no-remote cause is deliberately not repeated here.

  # Route (a): the client IS findable, but the remote is not the expected host.
  # The stub is what makes this route provable. Without it the client reads
  # absent on this machine, the skip fires for route (b)'s reason, and the
  # assertion below would pass while proving nothing.
  a="$BATS_TEST_TMPDIR/with-client"
  shimdir "$a" $PROBE_TOOLS
  stub "$a/gh"
  ra="$BATS_TEST_TMPDIR/repo-elsewhere"
  mkdir -p "$ra"
  ( cd "$ra" && git init -q . && main_base && git remote add origin https://gitlab.example.com/x/y.git )
  probe --path "$a" --dir "$ra" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.capabilities.gh' <<<"$output")" = "true" ]
  [ "$(jq -r '.remote.ghCommand' <<<"$output")" = "gh" ]
  [ "$(jq -r '.remote.kind' <<<"$output")" = "other" ]
  [ "$(jq -r '[.willSkip[] | select(.phase=="M")] | length' <<<"$output")" = "1" ]
  # The two routes carry DIFFERENT reasons, and each is pinned: one shared
  # message named both causes, so an operator could not tell which to fix.
  [ "$(jq -r '[.willSkip[] | select(.phase=="M")] | .[0].reason' <<<"$output")" \
      = "the remote is not GitHub — review needs a GitHub pull request" ]

  # Route (b): the remote IS the expected host, but the client cannot be found.
  b="$BATS_TEST_TMPDIR/without-client"
  shimdir "$b" $PROBE_TOOLS
  rb="$BATS_TEST_TMPDIR/repo-expected-host"
  mkdir -p "$rb"
  ( cd "$rb" && git init -q . && main_base && git remote add origin https://github.com/example/thing.git )
  probe --path "$b" --dir "$rb" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.capabilities.gh' <<<"$output")" = "false" ]
  [ "$(jq -r '.remote.ghPresent' <<<"$output")" = "false" ]
  # Absent is the EMPTY STRING, still a string — the key is never dropped.
  jq -e '.remote.ghCommand == ""' <<<"$output" > /dev/null
  [ "$(jq -r '.remote.kind' <<<"$output")" = "github" ]
  [ "$(jq -r '[.willSkip[] | select(.phase=="M")] | length' <<<"$output")" = "1" ]
  [ "$(jq -r '[.willSkip[] | select(.phase=="M")] | .[0].reason' <<<"$output")" \
      = "gh is absent — none of gh, gh.exe, gh.cmd is on PATH" ]

  # Negative control. Neither cause holds, so the phase must NOT be announced.
  # Without this the two assertions above cannot be shown to go red when they
  # should — they would pass against a script that skipped M unconditionally.
  stub "$b/gh"
  probe --path "$b" --dir "$rb" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '[.willSkip[] | select(.phase=="M")] | length' <<<"$output")" = "0" ]
}

@test "gh installed only as gh.cmd is found, named, and keeps the review phase" {
  # A Windows package manager can install gh as gh.cmd alone. A bare `gh`
  # lookup does not find that file on any platform, so a probe of one name
  # reported a working client absent and announced M skipped. The stub
  # directory holds gh.cmd and NO gh — that absence is the whole test.
  d="$BATS_TEST_TMPDIR/cmd-only"
  shimdir "$d" $PROBE_TOOLS
  stub "$d/gh.cmd"
  [ ! -e "$d/gh" ]
  r="$BATS_TEST_TMPDIR/repo-cmd-only"
  mkdir -p "$r"
  ( cd "$r" && git init -q . && main_base && git remote add origin https://github.com/example/thing.git )
  probe --path "$d" --dir "$r" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.remote.kind' <<<"$output")" = "github" ]
  jq -e '.remote.ghPresent == true' <<<"$output" > /dev/null
  jq -e '.capabilities.gh == true' <<<"$output" > /dev/null
  [ "$(jq -r '.remote.ghCommand' <<<"$output")" = "gh.cmd" ]
  [ "$(jq -r '[.willSkip[] | select(.phase=="M")] | length' <<<"$output")" = "0" ]

  # Order: with both names present the bare name wins, so a platform where
  # `gh` works is reported exactly as it was before gh.cmd was probed.
  stub "$d/gh"
  probe --path "$d" --dir "$r" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.remote.ghCommand' <<<"$output")" = "gh" ]
}

# --- the last unpinned base-branch route --------------------------------------

@test "with no published default and no override, the base branch falls back to the current branch" {
  T="$BATS_TEST_TMPDIR/fallback"
  mkdir -p "$T"
  # The commit is load-bearing, not tidiness. On an UNBORN branch the command
  # this fallback uses exits 128 and prints the literal word HEAD on stdout,
  # which the script adopts as a branch name — so without a commit the source
  # assertion below still passes while the branch name means nothing.
  ( cd "$T" \
      && git init -q -b feature-x . \
      && git -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init )
  # The base-branch flag is OMITTED. This route needs BOTH earlier routes to be
  # unavailable, and every other call site in this suite supplies an override —
  # which is why no existing test could reach it.
  probe --dir "$T"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.baseBranch' <<<"$output")" = "feature-x" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "current branch" ]
}

# --- the git capability -------------------------------------------------------
# git is the one probed tool the run cannot proceed without: phases B, K and L
# are git operations, and four of this script's own reads are git commands. It
# is reported here like any other capability, and NOTHING here asserts on a
# stop, because a report is the only thing this script produces. The stop is
# the orchestrator's pre-flight decision 11, made from what is asserted below.

@test "the capability report names git present when git is findable" {
  d="$BATS_TEST_TMPDIR/with-git"
  shimdir "$d" $PROBE_TOOLS
  probe --path "$d" --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.capabilities.git' <<<"$output")" = "true" ]
  # The TYPE, not only the value, and it needs its own assertion. `jq -r`
  # prints the JSON string "true" as a bare true, so a value comparison alone
  # cannot tell a boolean from a string. Measured 2026-08-30: changing
  # --argjson to --arg in the script made the emitted type "string" and NOT ONE
  # test in this suite went red. A consumer writing `.capabilities.git | not`
  # then gets the wrong answer, because the string "false" is truthy.
  jq -e '.capabilities.git | type == "boolean"' <<<"$output" > /dev/null
  # Feature 049: found AND usable, here, since the probed folder is inside
  # this checkout.
  git_report_is true usable
}

@test "the capability report names git absent, and the report survives it" {
  # This test asserts baseBranch, and a willSkip set that is wholly a function
  # of the remote — both of which the header at the top of this file says no
  # fixture test does. The exception is deliberate and it is safe for ONE
  # reason: git is off the search path built below, so the enclosing
  # checkout's origin/HEAD cannot be read and the fixture's git facts come
  # from this call's flags and the script's defaults instead of from this
  # repository. Put git back on that path and the exception collapses.
  #
  # What catches that, measured rather than asserted. Restoring git to the list
  # below turns this test red at its FIRST assertion, the capability itself,
  # which is where bats stops. The baseBranchSource and willSkip assertions are
  # corroborating, not the tripwire: they prove the git facts below came from
  # this call's flags and the script's defaults rather than from the enclosing
  # checkout. And note which assertion does NOT catch it — the baseBranch VALUE
  # stays "main" either way, because origin/HEAD here points at main, so it
  # would pass for a route this test does not intend. That is why the SOURCE is
  # asserted beside it.
  d="$BATS_TEST_TMPDIR/without-git"
  # DERIVED from PROBE_TOOLS by removing one name, never hand-listed. A hand
  # list goes stale the day a tool is added to that variable, and it goes stale
  # in the direction that hurts: the shim directory would then be missing TWO
  # tools, and this test would pass for a cause it does not name.
  tools=""
  for t in $PROBE_TOOLS; do [ "$t" = git ] || tools="$tools $t"; done
  shimdir "$d" $tools
  probe --path "$d" --dir "$FIX/other" --base-branch main

  # Reporting is not failing. The script still exits 0 and still emits one
  # well-formed document with git absent — which is exactly why the stop lives
  # in the orchestrator and not here. A script that died would leave this test
  # nothing to read, and the capability could only be inferred from an exit
  # code.
  [ "$status" -eq 0 ]
  jq -e . <<<"$output" > /dev/null
  [ "$(jq -r '.capabilities.git' <<<"$output")" = "false" ]
  # Type, for the same reason the present-git test asserts it: `jq -r` cannot
  # tell the boolean false from the string "false", and a consumer writing
  # `.capabilities.git | not` reads the string as truthy.
  jq -e '.capabilities.git | type == "boolean"' <<<"$output" > /dev/null
  # Feature 049: absent is also unusable, with its own reason.
  git_report_is false absent
  not_read_is "$NOT_READ_ALL"

  # The report is COMPLETE, not truncated. Absence sets a field to false; it
  # never drops a key, and no consumer should have to read a short document as
  # the signal for a missing tool.
  [ "$(jq -r '.projectType' <<<"$output")" = "other" ]
  [ "$(jq -r '.baseBranch' <<<"$output")" = "main" ]
  # THE TRIPWIRE for the exception declared above, and it is the SOURCE, not
  # the value. The fixture repository publishes origin/HEAD -> origin/main
  # (setup_file), as this checkout did when the test was written, so
  # with git restored to the search path baseBranch resolves to "main" from
  # origin/HEAD — the same string the line above asserts, arriving by a route
  # this test does not intend. The value alone therefore proves nothing. The
  # source does: it reads "configured" only while git cannot be found, and
  # flips to "origin/HEAD" the moment it can.
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "configured" ]

  # No skip is announced on git's OWN account. The two that are announced belong
  # to the pre-existing no-remote branch: without git the remote cannot be read,
  # so it reads "none", and that branch names L and M. A degradation names a
  # phase the run can do without, and for git there is no such phase — hence a
  # stop, not a skip.
  #
  # The phase set AND both reasons are pinned, and the reasons are the half that
  # does the work. A phase-only assertion cannot see the failure it was written
  # to prevent: rewriting add_skip "L" to a git-flavoured reason leaves the set
  # exactly ["L","M"] and stays green, while the report now announces git as a
  # degradation. Pinning the strings makes that change go red and be argued for.
  # The suite's other skip tests assert reasons for the same reason.
  [ "$(jq -c '[.willSkip[].phase] | sort' <<<"$output")" = '["L","M"]' ]
  [ "$(jq -r '[.willSkip[] | select(.phase=="L")] | .[0].reason' <<<"$output")" \
      = "no git remote — the run stops after the commit gate and says so" ]
  [ "$(jq -r '[.willSkip[] | select(.phase=="M")] | .[0].reason' <<<"$output")" \
      = "no pull request without a remote" ]

  # Feature 050: with no base flag either, the base falls through to
  # "current branch", which nothing read, and notRead names it.
  probe --path "$d" --dir "$FIX/other"
  [ "$status" -eq 0 ]
  git_report_is false absent
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "current branch" ]
  not_read_is "$NOT_READ_ALL"
}

# --- a git that is found but will not work here ------------------------------
# Feature 049. capabilities.git still says only "found". gitUsable and
# gitReason say whether git opens a repository at the probed folder, and if
# not, why. Each reason gets a fixture that produces it FOR REAL, and each
# fixture first proves its own precondition with plain git: a git that
# ignored the fixture's trigger would otherwise give a green for nothing.

# git_report_is <found> <reason> — the three git keys of the report in
# $output, in one check: capabilities.git is <found>, gitReason is <reason>,
# and gitUsable is the BOOLEAN true exactly when <reason> is usable. The type
# matters: `jq -r` prints the string "false" and the boolean false alike, and
# `.capabilities.gitUsable | not` reads the string as truthy.
git_report_is() {
  jq -e --argjson f "$1" --arg r "$2" '
      .capabilities.git == $f and .gitReason == $r
      and (.capabilities.gitUsable | type) == "boolean"
      and .capabilities.gitUsable == ($r == "usable")' <<<"$output" > /dev/null \
    || { echo "want git=$1 gitReason=$2; got $(jq -c '{git: .capabilities.git, gitUsable: .capabilities.gitUsable, gitReason}' <<<"$output")"; false; }
}

# Feature 050. notRead names each field of the report whose git read did not
# run, or ran and failed. The two lists a test expects are written ONCE,
# here: NOT_READ_OVERRIDE when the base branch came from an override, the one
# source that outranks origin/HEAD and so is established without git;
# NOT_READ_ALL for every other source, configuration included: a configured
# base is the fallback for a repository with no origin/HEAD, and without git
# nobody looked (specs/050-preflight-unread-git-fields/data-model.md).
NOT_READ_ALL='["baseBranch","baseBranchSource","remote.kind","tree.dirty","willSkip.L","willSkip.M"]'
NOT_READ_OVERRIDE='["remote.kind","tree.dirty","willSkip.L","willSkip.M"]'

# not_read_is <json-list> — .notRead of the report in $output equals
# <json-list>, order included. A string or a null fails the equality too.
# On failure it names what is missing and what is extra, not only the lists.
not_read_is() {
  jq -e --argjson want "$1" '.notRead == $want' <<<"$output" > /dev/null \
    || { echo "want notRead=$1; got $(jq -c '.notRead' <<<"$output"); $(jq -rc --argjson want "$1" \
           'if (.notRead | type) == "array" then "missing \($want - .notRead), extra \(.notRead - $want)" else "not a list" end' <<<"$output")"; false; }
}

# git_isolate — no system git configuration, and a global one that is an
# empty FILE (never /dev/null, which is not a path to git on Windows). HOME
# is already fresh per test (tests/helper.bash), which covers ~/.gitconfig;
# what this adds is GIT_CONFIG_NOSYSTEM, a global that XDG_CONFIG_HOME cannot
# redirect, and a file the ownership test reads afterwards to prove the
# probe wrote no configuration.
git_isolate() {
  : > "$BATS_TEST_TMPDIR/gitconfig"
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig" GIT_CONFIG_NOSYSTEM=1
}

# refuse_for_ownership <repo> — make git refuse <repo> for ownership from
# here on, and prove it does. GIT_TEST_ASSUME_DIFFERENT_OWNER is git's own
# test switch, read in its common setup code, so it acts the same on every
# runner. Call it AFTER building the repository: seeding needs a git that
# opens it. If this git ignores the switch, the test fails here, by name.
refuse_for_ownership() {
  export GIT_TEST_ASSUME_DIFFERENT_OWNER=1
  if git -C "$1" rev-parse --git-dir > /dev/null 2>&1; then
    echo "precondition: git opened the repository despite GIT_TEST_ASSUME_DIFFERENT_OWNER"; return 1
  fi
  git -C "$1" -c safe.directory='*' rev-parse --git-dir > /dev/null 2>&1 \
    || { echo "precondition: git did not open the repository with the ownership check lifted"; return 1; }
}

@test "the capability report names a git that refuses the repository for ownership" {
  local r="$BATS_TEST_TMPDIR/owned" m="$BATS_TEST_TMPDIR/ran"
  git_isolate
  mkdir -p "$r"; ( cd "$r" && git init -q . )
  # The repository's owner is the party the check guards against, so its
  # configuration names a program that leaves a mark if it ever runs. The
  # lifted call must parse this configuration and run none of it (FR-005).
  # One plant, the fsmonitor, because the control below can prove it live:
  # a hook or a pager planted here could never fire under bats (no commit,
  # no terminal), and its absence would prove nothing. The wider sweep (28
  # planted programs, none fired) was a one-off measurement at review,
  # recorded in specs/049-preflight-git-usable/measurements.md, not this test.
  printf '#!/bin/sh\necho "$0" >> "%s"\n' "$m" > "$r/.git/mark"
  chmod +x "$r/.git/mark"
  git -C "$r" config core.fsmonitor "$r/.git/mark"
  cp "$r/.git/config" "$BATS_TEST_TMPDIR/config.before"
  refuse_for_ownership "$r"
  # A positive control for the marks: with the check lifted, a command that
  # reads the index does run the planted fsmonitor. Without this, "no mark"
  # could mean the plant was broken, not that the probe ran nothing.
  git -C "$r" -c safe.directory='*' status --porcelain > /dev/null 2>&1 || true
  [ -s "$m" ] || { echo "control: the planted fsmonitor never ran, so its absence below would prove nothing"; false; }
  rm -f "$m"

  probe --dir "$r" --base-branch main
  [ "$status" -eq 0 ]
  jq -e . <<<"$output" > /dev/null
  git_report_is true refused-ownership
  not_read_is "$NOT_READ_ALL"
  [ ! -e "$m" ] || { echo "the probe ran a program the refused repository names: $(cat "$m")"; false; }
  # Nothing was configured: the check was lifted for one command, never
  # written down.
  [ ! -s "$BATS_TEST_TMPDIR/gitconfig" ] || { echo "the probe wrote global git configuration"; false; }
  cmp -s "$r/.git/config" "$BATS_TEST_TMPDIR/config.before" \
    || { echo "the probe changed the repository's git configuration"; false; }
}

@test "the ownership refusal is found from exit codes, with git's messages gone" {
  # FR-004. A shim that runs the real git with its stderr thrown away: a
  # classifier that matched git's message ("dubious ownership") would find
  # nothing to match and misfile the refusal. Exit codes are all that is left.
  local r="$BATS_TEST_TMPDIR/owned" d="$BATS_TEST_TMPDIR/quiet-git" real
  git_isolate
  mkdir -p "$r"; ( cd "$r" && git init -q . )
  refuse_for_ownership "$r"
  real="$(command -v git)"
  shimdir "$d" $PROBE_TOOLS
  printf '#!/bin/sh\nexec "%s" "$@" 2>/dev/null\n' "$real" > "$d/git"
  chmod +x "$d/git"
  [ -z "$(PATH="$d" git -C "$r" rev-parse --git-dir 2>&1)" ] \
    || { echo "precondition: the shim still lets git's message through"; false; }

  probe --path "$d" --dir "$r" --base-branch main
  [ "$status" -eq 0 ]
  git_report_is true refused-ownership
  not_read_is "$NOT_READ_ALL"
}

@test "an unusable git reports names unchecked, as an absent one does" {
  # With the old probe, a found git ran the name checks against a repository
  # it could not read, and died naming a wrong cause.
  local r="$BATS_TEST_TMPDIR/owned"
  git_isolate
  mkdir -p "$r"; ( cd "$r" && git init -q . && seed && git branch integration )
  refuse_for_ownership "$r"

  # The override check, which runs first.
  probe --dir "$r" --base-branch-override integration --feature-branch new-work
  [ "$status" -eq 0 ] || { echo "exit $status: $stderr"; false; }
  git_report_is true refused-ownership
  [[ "$stderr" != *"is not a branch here or on origin"* ]] \
    || { echo "the override was checked against a repository git refused: $stderr"; false; }
  # Reported, unchecked: the names arrive as typed.
  [ "$(jq -r '.baseBranch' <<<"$output")" = "integration" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "override" ]
  [ "$(jq -r '.featureBranch' <<<"$output")" = "new-work" ]
  # Feature 050: the override is the one base source notRead never names.
  not_read_is "$NOT_READ_OVERRIDE"

  # The feature-branch checks, on their own: @{-1} is a name git must READ
  # the repository to refuse, so a feature-branch check that still ran on a
  # found git dies here with "not a legal branch name".
  probe --dir "$r" --base-branch main --feature-branch '@{-1}'
  [ "$status" -eq 0 ] || { echo "exit $status: $stderr"; false; }
  git_report_is true refused-ownership
  [ "$(jq -r '.featureBranch' <<<"$output")" = '@{-1}' ]
}

@test "the capability report names a git that opens no repository here" {
  local d="$BATS_TEST_TMPDIR/plain"
  mkdir -p "$d"
  git_isolate
  # git climbs no higher than the temp folder, so the checkout that may
  # hold it is never found.
  export GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR"
  if git -C "$d" rev-parse --git-dir > /dev/null 2>&1 \
     || git -C "$d" -c safe.directory='*' rev-parse --git-dir > /dev/null 2>&1; then
    echo "precondition: git found a repository at $d"; false
  fi

  probe --dir "$d" --base-branch main
  [ "$status" -eq 0 ]
  jq -e . <<<"$output" > /dev/null
  git_report_is true no-repository
  not_read_is "$NOT_READ_ALL"
}

@test "the capability report names a git that is found but cannot run" {
  local d="$BATS_TEST_TMPDIR/broken-git"
  # Every probe tool, then a git that fails every command written over the
  # git shim.
  shimdir "$d" $PROBE_TOOLS
  printf '#!/bin/sh\nexit 1\n' > "$d/git"
  chmod +x "$d/git"
  if PATH="$d" git --version > /dev/null 2>&1; then
    echo "precondition: the broken git ran"; false
  fi

  probe --path "$d" --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  jq -e . <<<"$output" > /dev/null
  git_report_is true broken
  not_read_is "$NOT_READ_ALL"
}

@test "an unusable git with no base flag names the base fields, and never a device skip" {
  # No base flag, so baseBranchSource says "current branch" for a checkout
  # nobody consulted. The four reason tests above reach the base rule
  # through --base-branch; this one reaches it through the other source.
  local r="$BATS_TEST_TMPDIR/owned" d="$BATS_TEST_TMPDIR/no-device"
  git_isolate
  mkdir -p "$r"; ( cd "$r" && git init -q . )
  refuse_for_ownership "$r"
  probe --dir "$r"
  [ "$status" -eq 0 ]
  git_report_is true refused-ownership
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "current branch" ]
  [ "$(jq -r '.baseBranch' <<<"$output")" = "" ]
  not_read_is "$NOT_READ_ALL"

  # The N.5 skip comes from looking for adb, not from git: it is announced
  # and never named, while the git-derived skips beside it are.
  shimdir "$d" $PROBE_TOOLS
  probe --path "$d" --dir "$r" --project-type mobile-android
  [ "$status" -eq 0 ]
  git_report_is true refused-ownership
  jq -e '[.willSkip[].phase] | index("N.5") != null' <<<"$output" > /dev/null \
    || { echo "precondition: no N.5 skip in $(jq -c .willSkip <<<"$output")"; false; }
  not_read_is "$NOT_READ_ALL"
}

@test "a usable git names nothing, even with no remote" {
  # The other direction. With git usable and no remote, the L and M skips ARE
  # announced, and they are true: a remote was looked for. The list must stay
  # empty, or it would mark a read that ran as one that did not.
  # One commit, so every read succeeds: on an unborn branch the base read
  # fails under a usable git, which is outside what notRead covers.
  local r="$BATS_TEST_TMPDIR/noremote"
  git_isolate
  mkdir -p "$r"; ( cd "$r" && git init -q . && main_base )
  probe --dir "$r"
  [ "$status" -eq 0 ]
  git_report_is true usable
  # Precondition: the no-remote skips are there, so an empty list is not
  # empty for want of them.
  jq -e '[.willSkip[].phase] | index("L") != null' <<<"$output" > /dev/null \
    || { echo "precondition: no L skip in $(jq -c .willSkip <<<"$output")"; false; }
  not_read_is '[]'
  probe --dir "$r" --base-branch main
  [ "$status" -eq 0 ]
  not_read_is '[]'
}

@test "the git reasons the script assigns are the ones the git stop instructs" {
  # Both sides derived, never listed: the reasons the script can assign, and
  # the reasons "The git stop" gives an instruction for, as list items that
  # open with the reason in backticks. A reason added to one side alone has
  # no instruction, or an instruction for a state that never happens.
  local script page
  script="$(grep -oE 'git_reason=[a-z-]+' "$PROBE" | sed 's/^git_reason=//' | grep -vx usable | sort -u)"
  page="$(tr -d '\r' < "$ROOT/pipeline/docs/rare-paths.md" \
    | awk '/^## / { on = ($0 == "## The git stop") ; next } on' \
    | sed -nE 's/^- `([a-z-]+)`.*$/\1/p' | sort -u)"
  [ -n "$script" ] || { echo "the script assigns no git reason"; false; }
  [ -n "$page" ] || { echo "\"The git stop\" names no git reason"; false; }
  [ "$script" = "$page" ] || { printf 'script assigns:\n%s\nthe git stop names:\n%s\n' "$script" "$page"; false; }
}

@test "the script probes git for its presence in one place" {
  # Two probes answered "found" in two places, and one of them gated the
  # name checks: one classifier now feeds both. A second copy would drift.
  # The common spellings of a presence probe count, not only the one in use:
  # command -v, type -p or -P, hash and which. Not every spelling: a probe
  # written another way would pass, and this is a structural guard only;
  # the behaviour itself is held by the per-reason tests above.
  local n
  n="$(grep -v '^[[:space:]]*#' "$PROBE" \
    | grep -cE '(command -v|type -[pP]|hash|which)[[:space:]]+["'"'"']?git(["'"'"'[:space:]>;|&)]|$)' || true)"
  [ "$n" = 1 ] || { echo "a presence probe for git appears $n times outside comments"; false; }
}

# --- a constitution at the size a herestring hangs on -------------------------

# Git Bash 5.3.9 hangs a herestring of 65,536 to about 65,700 bytes, and the
# constitution body once reached grep through one: measured against that
# script, a 65,600-byte body timed out (status 124). The body is now matched
# in the shell. The sizes straddle the band on both sides, and the size IS
# the property, so it is asserted before the probe runs — a fixture that
# drifted out of the band would pass for the wrong reason.
BIG_CONST_SIZES="65530 65540 65600 65650 65700"

# big_const <dir> <bytes> <plain|token|blank> — a scratch repository whose
# constitution is exactly <bytes> bytes of 80-byte lines. `token` ends the
# last full line with a template token, deep past the 64 KB mark; `blank`
# is spaces and newlines only.
big_const() {
  local d="$1" n="$2" mode="$3"
  mkdir -p "$d/.specify/memory"
  ( cd "$d" && git init -q . && main_base )
  awk -v n="$n" -v mode="$mode" 'BEGIN {
    c = (mode == "blank") ? " " : "x"
    l = sprintf("%79s", ""); gsub(/ /, c, l)
    full = int(n / 80); rem = n % 80
    for (i = 1; i <= full; i++) {
      if (mode == "token" && i == full) print substr(l, 1, 65) "[PROJECT_NAME]"
      else print l
    }
    if (rem > 0) print substr(l, 1, rem - 1)
  }' > "$d/.specify/memory/constitution.md"
  [ "$(wc -c < "$d/.specify/memory/constitution.md" | tr -d ' ')" -eq "$n" ] \
    || { echo "fixture: the constitution is not $n bytes"; return 1; }
}

# judge_big <dir> — pre-flight on it, bounded. timeout is GNU coreutils and
# macOS does not ship it; where it is missing, bats' own per-test limit
# (helper.bash) still bounds a hang and names it. Probed with --version, not
# command -v: on Windows a System32 timeout.exe can come first on PATH, takes
# no command, and exits 1 on --version (measured).
judge_big() {
  if timeout --version > /dev/null 2>&1; then
    run --separate-stderr timeout 30 "$BASH_ABS" "$PROBE" --dir "$1" --base-branch main
  else
    probe --dir "$1" --base-branch main
  fi
}

@test "a constitution of 65,530 to 65,700 bytes with real prose is judged set" {
  local n
  for n in $BIG_CONST_SIZES; do
    big_const "$BATS_TEST_TMPDIR/plain-$n" "$n" plain
    judge_big "$BATS_TEST_TMPDIR/plain-$n"
    [ "$status" -eq 0 ] || { echo "$n bytes: pre-flight exited $status (124 is the timeout)"; false; }
    [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "true" ] \
      || { echo "$n bytes of prose: not judged set"; false; }
    [[ $stderr != *constitution* ]] || { echo "$n bytes: a constitution warning: $stderr"; false; }
  done
}

@test "a constitution of 65,530 to 65,700 bytes with a template token past 64 KB is judged unset" {
  local n
  for n in $BIG_CONST_SIZES; do
    big_const "$BATS_TEST_TMPDIR/token-$n" "$n" token
    judge_big "$BATS_TEST_TMPDIR/token-$n"
    [ "$status" -eq 0 ] || { echo "$n bytes: pre-flight exited $status (124 is the timeout)"; false; }
    [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ] \
      || { echo "$n bytes ending in [PROJECT_NAME]: judged set"; false; }
    [[ $stderr != *constitution* ]] || { echo "$n bytes: a constitution warning: $stderr"; false; }
  done
}

# No size test can catch the other fault: on Git Bash, grep reading
# `< <(printf ...)` reported a token that is not there in 43 of 1,800 calls
# under load, and never in a quiet run. So the shape itself is refused, with
# any spacing inside `< <( printf`, and on a line that holds a `#` before it
# (`${x#y}`, a quoted '#'). Only a whole-line comment is skipped.
@test "pre-flight feeds no grep from a process substitution" {
  local hits
  hits="$(awk '/^[[:space:]]*#/ { next }
    /grep.*<[[:space:]]*<\([[:space:]]*printf/ { print FNR ": " $0 }' "$PROBE")"
  [ -z "$hits" ] || { echo "grep fed by < <(printf ...): $hits"; false; }
}

@test "a constitution of 65,600 bytes of whitespace is judged unset" {
  big_const "$BATS_TEST_TMPDIR/blank" 65600 blank
  judge_big "$BATS_TEST_TMPDIR/blank"
  [ "$status" -eq 0 ] || { echo "pre-flight exited $status (124 is the timeout)"; false; }
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ] \
    || { echo "a whitespace-only constitution was judged set"; false; }
}

# --- review 3 of PR #68 -------------------------------------------------------
# Each test below kills a mutant the review measured surviving on 92ca321.

@test "trailers: every closing keyword is refused as the token" {
  T="$BATS_TEST_TMPDIR/close-tokens"; mkdir -p "$T"; cd "$T"; git init -q -b work .
  local k
  for k in Close Closes Closed Fix Fixes Fixed Resolve Resolves Resolved; do
    probe --dir "$T" --trailer "$k: x"
    [ "$status" -ne 0 ] || { echo "accepted: $k: x"; false; }
    [[ "$stderr" == *"'$k: x' uses the token '$k', which acts on GitHub"* ]] || { echo "wrong reason: $k: $stderr"; false; }
  done
}

@test "trailers: every closing keyword before an issue number is refused, in any letter case" {
  T="$BATS_TEST_TMPDIR/close-values"; mkdir -p "$T"; cd "$T"; git init -q -b work .
  local v
  for v in 'Note: Close #1' 'Note: closed #1' 'Note: FIX #1' 'Note: fixed #1' 'Note: Resolve #1' 'Note: resolves #1' 'Note: RESOLVED #1'; do
    probe --dir "$T" --trailer "$v"
    [ "$status" -ne 0 ] || { echo "accepted: $v"; false; }
    [[ "$stderr" == *"'$v' would close an issue"* ]] || { echo "wrong reason: $v: $stderr"; false; }
  done
}

@test "trailers: DEL is refused as a control character, and never printed raw" {
  T="$BATS_TEST_TMPDIR/del"; mkdir -p "$T"; cd "$T"; git init -q -b work .
  probe --dir "$T" --trailer $'Note: a\x7fb'
  [ "$status" -ne 0 ]
  [[ "$stderr" == *'"Note: a\u007fb" holds a control character'* ]] || { echo "wrong reason: $stderr"; false; }
  ! printf '%s' "$stderr" | LC_ALL=C grep -q $'\x7f'
}

@test "without git, the override and the feature branch are reported unchecked" {
  d="$BATS_TEST_TMPDIR/nogit"
  shimdir "$d" awk grep head jq od
  probe --path "$d" --dir "$FIX/web" --base-branch main --base-branch-override integration --feature-branch 003-x
  [ "$status" -eq 0 ] || { echo "refused without git: $stderr"; false; }
  [ "$(jq -r '.baseBranch' <<<"$output")" = integration ]
  [ "$(jq -r '.featureBranch' <<<"$output")" = 003-x ]
  # The boolean false, not the string: `jq -r` prints both as false.
  jq -e '.capabilities.git | type == "boolean" and . == false' <<<"$output" > /dev/null \
    || { echo "git is not the boolean false: $(jq -c '.capabilities.git' <<<"$output")"; false; }
}

@test "feature branch and spec folder are checked in the repository, not in the caller's" {
  T="$BATS_TEST_TMPDIR/where"
  mkdir -p "$T/caller" "$T/repo"
  cd "$T/repo"; git init -q -b work .; seed; git branch taken; mkdir -p specs/004-there
  cd "$T/caller"; git init -q -b work .; seed; git branch only-here; mkdir -p specs/003-here
  # What exists only where the caller stands is free in the repository.
  probe --dir "$T/repo" --feature-branch only-here --spec-dir specs/003-here
  [ "$status" -eq 0 ] || { echo "refused for the caller's state: $stderr"; false; }
  # What exists in the repository is refused, though the caller has none.
  probe --dir "$T/repo" --feature-branch taken
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'taken' already exists as the branch 'taken'"* ]] || false
  probe --dir "$T/repo" --feature-branch 005-new --spec-dir specs/004-there
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'specs/004-there' already exists"* ]]
}

@test "feature branch: an existing branch with capitals is matched in any letter case" {
  T="$BATS_TEST_TMPDIR/caps"; mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  git branch Feature-X
  probe --dir "$T" --feature-branch feature-x
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'feature-x' already exists as the branch 'Feature-X'"* ]]
}

@test "spec folder: .delivery-kit below the top level is an ordinary folder" {
  T="$BATS_TEST_TMPDIR/nested-state"; mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  probe --dir "$T" --spec-dir 'specs/.delivery-kit/003-thing'
  [ "$status" -eq 0 ] || { echo "refused: $stderr"; false; }
  [ "$(jq -r '.specDir' <<<"$output")" = "specs/.delivery-kit/003-thing" ]
}

# --- review 4 of PR #68 -------------------------------------------------------
# Each test below states one rule review 4 added, its refusal text whole.

@test "refusals show a refused value masked and cut, never its raw bytes" {
  # Review 4, non-blocking 3: a value pre-flight refused, typed or read from
  # a tracked key, was printed raw, so it could put a terminal escape or a
  # bidi character on the operator's first screen. Every value a refusal
  # prints is shown under the C locale, cut to 200 bytes then ` [cut]`, and
  # each byte that is not printable ASCII as `?`.
  T="$BATS_TEST_TMPDIR/shown"; mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  local long
  probe --dir "$T" $'--x\e[2J'
  [ "$status" -eq 1 ] || { echo "unknown argument: status $status"; false; }
  [[ "$stderr" == "preflight: unknown argument '--x?[2J' (legal: "* ]] || { echo "unknown argument: $stderr"; false; }
  printf -v long '%0300d' 0
  probe --dir "$T" "--$long"
  [ "$status" -eq 1 ] || { echo "long argument: status $status"; false; }
  [[ "$stderr" == "preflight: unknown argument '--${long:0:198} [cut]' (legal: "* ]] || { echo "not cut: $stderr"; false; }
  probe --dir $'no\e[2Jdir'
  [ "$status" -eq 1 ] || { echo "--dir: status $status"; false; }
  [ "$stderr" = "preflight: cannot enter 'no?[2Jdir'" ] || { echo "--dir: $stderr"; false; }
  probe --dir "$T" --base-branch-override $'in\e]0;pwn\a'
  [ "$status" -eq 1 ] || { echo "override: status $status"; false; }
  [ "$stderr" = "preflight: 'in?]0;pwn?' is not a legal branch name (--base-branch-override)" ] || { echo "override: $stderr"; false; }
  probe --dir "$T" --spec-dir $'/x\e]0;pwned\a'
  [ "$status" -eq 1 ] || { echo "absolute: status $status"; false; }
  [ "$stderr" = "preflight: '/x?]0;pwned?' is not relative to the repository root (--spec-dir)" ] || { echo "absolute: $stderr"; false; }
  probe --dir "$T" --spec-dir $'specs/a\xe2\x80\xaeb'
  [ "$status" -eq 1 ] || { echo "segment: status $status"; false; }
  [ "$stderr" = "preflight: 'specs/a???b' has the segment 'a???b'; a folder name holds letters, digits, dot, dash, underscore only (--spec-dir)" ] \
    || { echo "segment: $stderr"; false; }
}

@test "branch names: a character other than a letter, a digit, dot, underscore, dash or slash is refused" {
  # Review 4, blocking 1 and non-blocking 4: git accepts $ ( ) ; & | < > a
  # quote, a backtick and any byte past 0x7f in a branch name, and the name
  # is printed in refusals and typed into commands. Only the safe set passes.
  T="$BATS_TEST_TMPDIR/branch-charset"; mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  local bad want
  for bad in 'y$(id)' 'a;b' 'a`b`' "a'b" 'a"b' 'a&b' 'a|b' 'a<b>' 'a{b}' 'a+b' $'feat\xe2\x80\xaegnp'; do
    want="${bad//$'\xe2\x80\xae'/???}"
    probe --dir "$T" --feature-branch "$bad"
    [ "$status" -eq 1 ] || { echo "status $status: $bad"; false; }
    [ "$stderr" = "preflight: '$want' holds a character other than a letter, a digit, '.', '_', '-' or '/' (--feature-branch)" ] \
      || { echo "wrong reason: $bad: $stderr"; false; }
  done
  probe --dir "$T" --base-branch-override 'x;y'
  [ "$status" -eq 1 ] || { echo "override: status $status"; false; }
  [ "$stderr" = "preflight: 'x;y' holds a character other than a letter, a digit, '.', '_', '-' or '/' (--base-branch-override)" ] \
    || { echo "override: $stderr"; false; }
  probe --dir "$T" --feature-branch 'Team_1/a.b-C9'
  [ "$status" -eq 0 ] || { echo "refused a safe name: $stderr"; false; }
}

@test "branch names: an override that would run a command, published only on origin, is refused and runs nothing" {
  # Review 4, blocking 1, measured: a tracked baseBranchOverride naming a
  # branch only origin has got a refusal holding the command that fixes it,
  # git branch --track <name> origin/<name>, and with this name that command
  # ran touch. Whatever command a refusal offers is run here, as an operator
  # following it would, and no file PWNED may appear.
  T="$BATS_TEST_TMPDIR/override-pwn"; mkdir -p "$T/repo"
  git init -q --bare "$T/origin.git"
  cd "$T/repo"; git init -q -b work .; seed
  local name='x$(touch${IFS}PWNED)' cmd
  git remote add origin "$T/origin.git"
  git push -q origin "HEAD:refs/heads/$name" 2>/dev/null
  git fetch -q origin
  git show-ref --verify --quiet "refs/remotes/origin/$name" || { echo "fixture: origin has no such branch"; false; }
  ! git show-ref --verify --quiet "refs/heads/$name" || { echo "fixture: the branch is local too"; false; }
  probe --dir "$T/repo" --base-branch-override "$name"
  [ "$status" -eq 1 ] || { echo "status $status"; false; }
  case "$stderr" in
    *"create the local branch first: "*)
      cmd="${stderr#*create the local branch first: }"; cmd="${cmd% (--base-branch-override)}"
      (cd "$T/repo" && bash -c "$cmd") >/dev/null 2>&1 || true ;;
  esac
  [ ! -e "$T/repo/PWNED" ] && [ ! -e "$T/PWNED" ] || { echo "the refusal's command ran the name: $stderr"; false; }
  [ "$stderr" = "preflight: '$name' holds a character other than a letter, a digit, '.', '_', '-' or '/' (--base-branch-override)" ] \
    || { echo "wrong reason: $stderr"; false; }
}

@test "feature branch: a name that is a tag as well is refused, as the override is" {
  # Review 4: B's git checkout -b makes a branch beside the tag, and every
  # later <name>..HEAD or push reads the tag. The override was refused for
  # this; the feature branch, typed or taken from the spec folder, was not.
  T="$BATS_TEST_TMPDIR/feature-tag"; mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  git tag t1
  probe --dir "$T" --feature-branch t1
  [ "$status" -eq 1 ] || { echo "status $status: $stderr"; false; }
  [ "$stderr" = "preflight: 't1' is a tag as well as the feature branch's name; git would read the tag (--feature-branch)" ] \
    || { echo "wrong reason: $stderr"; false; }
  probe --dir "$T" --spec-dir specs/t1
  [ "$status" -eq 1 ] || { echo "spec folder: status $status: $stderr"; false; }
  [ "$stderr" = "preflight: 't1' is a tag as well as the feature branch's name; git would read the tag (--spec-dir)" ] \
    || { echo "spec folder: wrong reason: $stderr"; false; }
  git tag -d t1 >/dev/null
  probe --dir "$T" --feature-branch t1
  [ "$status" -eq 0 ] || { echo "refused once the tag was gone: $stderr"; false; }
}

@test "spec folder: a link out of the repository or into .git is refused without printing where it leads" {
  # Review 4, non-blocking 2: these two refusals printed the resolved
  # absolute path, which holds the user's name, and a refusal's text may
  # leave the machine. They name the spec folder as given, and nothing else.
  T="$BATS_TEST_TMPDIR/specdir-nopath"
  mkdir -p "$T/repo" "$T/outside"; cd "$T/repo"; git init -q -b work .; seed
  local rc=0
  link_or_file "$T/outside" out || rc=$?
  [ "$rc" -ne 2 ] || false
  if [ "$rc" -eq 1 ]; then link_fallback_refused "$T/repo" out/003-thing; return; fi
  speclink .git gitlink || { echo "fixture: the link gitlink was not made"; false; }
  probe --dir "$T/repo" --spec-dir out/003-thing
  [ "$status" -eq 1 ] || { echo "outside: status $status"; false; }
  [ "$stderr" = "preflight: 'out/003-thing' leads outside the repository (--spec-dir)" ] \
    || { echo "outside: $stderr"; false; }
  probe --dir "$T/repo" --spec-dir gitlink/003-thing
  [ "$status" -eq 1 ] || { echo "into .git: status $status"; false; }
  [ "$stderr" = "preflight: 'gitlink/003-thing' leads into git's or the run's own directory (--spec-dir)" ] \
    || { echo "into .git: $stderr"; false; }
}

@test "spec folder: an absolute link to a folder inside, with the repository entered by another spelling, is inside" {
  # Review 4, non-blocking 1 (review 3, item 6): Git Bash spells one folder
  # /tmp/... and /c/.../Temp/..., and cd -P through an absolute link
  # gives the /tmp one while the repository, entered as /c/..., keeps
  # its own. Compared by spelling, a folder inside was refused as outside,
  # and a link into .git got that reason too. Where cygpath is absent a
  # folder has one spelling, and the same check runs on that one.
  T="$BATS_TEST_TMPDIR/link-spelling"; mkdir -p "$T/inside"; cd "$T"; git init -q -b work .; seed
  local m alt="$T" rc=0
  if command -v cygpath >/dev/null 2>&1; then
    m="$(cygpath -m "$T")"
    alt="/$(printf '%s' "${m%%:*}" | tr 'A-Z' 'a-z')${m#*:}"
  fi
  link_or_file "$alt/inside" in || rc=$?
  [ "$rc" -ne 2 ] || false
  if [ "$rc" -eq 1 ]; then link_fallback_refused "$alt" in/003-thing; return; fi
  speclink "$alt/.git" gl || { echo "fixture: the link gl was not made"; false; }
  probe --dir "$alt" --spec-dir in/003-thing
  [ "$status" -eq 0 ] || { echo "a good path refused: $stderr"; false; }
  [ "$(jq -r '.specDir' <<<"$output")" = in/003-thing ]
  probe --dir "$alt" --spec-dir gl/003-thing
  [ "$status" -eq 1 ] || { echo "into .git: status $status"; false; }
  [ "$stderr" = "preflight: 'gl/003-thing' leads into git's or the run's own directory (--spec-dir)" ] \
    || { echo "into .git: $stderr"; false; }
}

@test "trailers: a quote, a dollar sign or a backtick is refused, since a trailer is typed into a shell command" {
  # Review 4, non-blocking 6: the orchestrator types each trailer into
  # preflight.sh --trailer and records the list with state-set inside single
  # quotes, so the shell read Ref: x'$(id)' before any check ran, and an
  # honest O'Brien broke the command. A double quote stays accepted.
  T="$BATS_TEST_TMPDIR/trailers-shell"; mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  local bad
  for bad in "Reviewed-by: O'Brien <o@example.invalid>" "Ref: x'\$(id)'" 'Note: $HOME' 'Note: `id`'; do
    probe --dir "$T" --trailer "$bad"
    [ "$status" -eq 1 ] || { echo "status $status: $bad"; false; }
    [ "$stderr" = "preflight: '$bad' holds a quote ('), a dollar sign or a backtick; a trailer is typed into a shell command (a commit trailer)" ] \
      || { echo "wrong reason: $bad: $stderr"; false; }
  done
  probe --dir "$T" --trailer 'Note: say "hi"'
  [ "$status" -eq 0 ] || { echo "refused a double quote: $stderr"; false; }
  [ "$(jq -r '.commitTrailers[0]' <<<"$output")" = 'Note: say "hi"' ]
}

@test "trailers: ##[ anywhere is refused, since a workflow log reads it as a command" {
  # Review 4, minor 1: a workflow that prints commit messages may act on
  # ##[ anywhere in a line. Only that exact sequence is refused.
  T="$BATS_TEST_TMPDIR/trailers-log"; mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  local bad
  for bad in 'Note: ##[error]injected' 'Ref: a##[add-mask]b'; do
    probe --dir "$T" --trailer "$bad"
    [ "$status" -eq 1 ] || { echo "status $status: $bad"; false; }
    [ "$stderr" = "preflight: '$bad' holds '##[', which a workflow log reads as a command (a commit trailer)" ] \
      || { echo "wrong reason: $bad: $stderr"; false; }
  done
  probe --dir "$T" --trailer 'Note: #[x]' --trailer 'Note: ## [x]' --trailer 'Note: ##x['
  [ "$status" -eq 0 ] || { echo "refused a near miss: $stderr"; false; }
  [ "$(jq -c '.commitTrailers' <<<"$output")" = '["Note: #[x]","Note: ## [x]","Note: ##x["]' ]
}

# Review 4 measured these mutants surviving on 3fec620; each test below kills
# its own: device names in any letter case (T1), a second spelling of the
# repository's path (T3), the astral ranges' neighbours (T2), and trailer-check.sh
# needing jq alone, run once (T4).

@test "spec folder: a device name is refused in any letter case, COM0 and LPT0 included" {
  # Windows reads CON, PRN, AUX, NUL, COM0-9 and LPT0-9 as devices in any
  # letter case and with any extension. The trailing-dot and device test names
  # most of them in one case only, so a rule that matched lower case alone, or COM1-9 only,
  # stayed green.
  T="$BATS_TEST_TMPDIR/specdir-devices"; mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  local bad
  for bad in 'specs/Prn' 'specs/AUX' 'specs/Nul.md' 'specs/COM1' 'specs/com0' 'specs/LPT0'; do
    probe --dir "$T" --spec-dir "$bad"
    [ "$status" -ne 0 ] || { echo "accepted: $bad"; false; }
    [[ "$stderr" == *"has the segment '${bad#specs/}', a name Windows keeps for a device"* ]] \
      || { echo "wrong reason: $bad: $stderr"; false; }
  done
}

@test "spec folder: a repository reached through a second spelling of its path is not outside itself" {
  # Git Bash mounts the Windows temp folder at /tmp as well, so one folder has
  # two spellings, /tmp/... and /c/.../Temp/...; git prints a third,
  # C:/Users/..., which cd -P turns into the /tmp one. The folder and the
  # repository's top must be spelled one way (review 3, item 6). Where a
  # folder has one spelling (no cygpath), the same check runs on that one.
  T="$BATS_TEST_TMPDIR/two-spellings"; mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
  local m alt="$T"
  if command -v cygpath >/dev/null 2>&1; then
    m="$(cygpath -m "$T")"
    alt="/$(printf '%s' "${m%%:*}" | tr 'A-Z' 'a-z')${m#*:}"
  fi
  probe --dir "$alt" --spec-dir specs/003-thing
  [ "$status" -eq 0 ] || { echo "a good path refused: $stderr"; false; }
  [ "$(jq -r '.specDir' <<<"$output")" = specs/003-thing ]
}

@test "trailers: the characters just past the astral ranges are accepted" {
  # The ranges U+1BCA0-1BCA3, U+1D173-1D17A and U+E0000-E0FFF are pinned at
  # their edges as refused; their outside neighbours are pinned here as
  # accepted, so a list widened past an edge goes red. U+E0080, U+E00FF and
  # U+E01F0, the neighbours of the two narrower tag ranges before the
  # whole block U+E0000-E0FFF was listed, are now refused (the test above).
  local tc="$ROOT/pipeline/scripts/trailer-check.sh" c err rc
  for c in '\ud82f\udc9f' '\ud82f\udca4' '\ud834\udd72' '\ud834\udd7b' '\udb3f\udfff' '\udb44\udc00'; do
    rc=0; err="$(bash "$tc" "\"Note: a${c}b\"" 2>&1 >/dev/null)" || rc=$?
    [ "$rc" -eq 0 ] || { echo "refused: ${c}: $err"; false; }
  done
}

@test "trailers: trailer-check.sh runs jq once, and needs nothing else on the search path" {
  # trailer-check.sh says it runs jq alone, once (each process costs time on
  # Windows). The probe's tests give it awk, git, grep, head and od as well,
  # so a grep or a second jq brought back stayed green. A search path holding
  # only a jq that counts its calls proves both, for an accepted trailer, a
  # closing form and a hidden character.
  local d="$BATS_TEST_TMPDIR/jq-only" tc="$ROOT/pipeline/scripts/trailer-check.sh" real out rc v
  real="$(command -v jq)"
  mkdir -p "$d"
  printf '#!/bin/sh\nprintf x >> "%s"\nexec "%s" "$@"\n' "$d/count" "$real" > "$d/jq"
  chmod +x "$d/jq"
  for v in 'Plan-Item: X' 'Ref: fixes #1' 'Note: a\u202eb'; do
    : > "$d/count"
    rc=0; out="$(PATH="$d" "$BASH" "$tc" "\"$v\"" 2>&1)" || rc=$?
    case "$v" in
      Plan-Item*) [ "$rc" -eq 0 ] && [ "$out" = 'Plan-Item: X' ] || { echo "accepted trailer: rc $rc: $out"; false; } ;;
      Ref*)       [ "$rc" -eq 1 ] && [ "$out" = "'Ref: fixes #1' would close an issue" ] || { echo "closing form: rc $rc: $out"; false; } ;;
      *)          [ "$rc" -eq 1 ] && [[ $out == '"Note: a\u202eb" holds a character that can disguise text'* ]] || { echo "hidden: rc $rc: $out"; false; } ;;
    esac
    [ "$(cat "$d/count")" = x ] || { echo "jq ran $(wc -c < "$d/count") times for $v"; false; }
  done
}

# The run-end rule's edges, as pre-flight reads them: abandoned false or
# null is a live run, abandoned true is not. A run whose name starts with a
# dot is read too, by each of the two dot globs (.hidden and ..b). And a jq
# that refuses -b, as jq 1.6 does off Windows, changes nothing: pre-flight
# reads each run without -b.
@test "pre-flight: abandoned false or null is live, a dot-named run is read, and a jq without -b reads them all" {
  local P="$PIPELINE/scripts/progress.sh" real d
  T="$BATS_TEST_TMPDIR/edges"
  mkdir -p "$T"; cd "$T"; git init -q .; main_base
  for r in 001-false 002-null 003-true .hidden ..b; do bash "$P" init "$r" b main web > /dev/null; done
  for r in false:001-false null:002-null true:003-true; do
    jq --argjson v "${r%%:*}" '.abandoned = $v' ".delivery-kit/runs/${r#*:}/progress.json" > t.json
    mv t.json ".delivery-kit/runs/${r#*:}/progress.json"
  done
  probe --dir "$T" --base-branch main
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
  jq -e '.tree.liveRuns == ["001-false", "002-null", ".hidden", "..b"] and .tree.unreadableRuns == []' <<<"$output" > /dev/null \
    || { echo "misjudged: $(jq -c .tree <<<"$output")"; false; }
  real="$(command -v jq)"; d="$BATS_TEST_TMPDIR/nob"
  mkdir -p "$d"
  printf '%s\n' '#!/usr/bin/env bash' \
    'for a in "$@"; do case "$a" in -b|--binary) echo "jq: Unknown option: $a" >&2; exit 2 ;; esac; done' \
    "exec \"$real\" \"\$@\"" > "$d/jq"
  chmod +x "$d/jq"
  PATH="$d:$PATH" probe --dir "$T" --base-branch main
  [ "$status" -eq 0 ] || { echo "$stderr"; false; }
  jq -e '.tree.liveRuns == ["001-false", "002-null", ".hidden", "..b"] and .tree.unreadableRuns == []' <<<"$output" > /dev/null \
    || { echo "a jq without -b misjudged: $(jq -c .tree <<<"$output")"; false; }
}
