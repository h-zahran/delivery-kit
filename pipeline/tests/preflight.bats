#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for pipeline/scripts/preflight.sh — detection and probe. Fixture
# directories sit INSIDE this repository, so git facts read from them
# belong to the enclosing checkout — which is why no fixture test asserts
# baseBranch or remote, and why those assertions get their own scratch
# repositories below. The --base-branch flag on fixture runs is a
# formality: where the checkout publishes origin/HEAD, that wins by
# design.

load ../../tests/helper

setup() {
  FIX="$ROOT/pipeline/tests/fixtures"
  # PREFLIGHT_UNDER_TEST points the suite at another copy of the script, for
  # mutation runs: mutate a copy, point the suite at it, watch a test go red.
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

# seed — one empty commit in the current repository, so branches can exist.
# The identity is given on the command line: these repositories have none.
seed() {
  git -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
    commit -q --allow-empty -m seed
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
  [ "$(jq -r '.speckit.present' <<<"$output")" = "false" ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ]
}

@test "the web fixture reads version and sh flavour, resolving the bash scripts dir" {
  probe --dir "$FIX/web" --base-branch main
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
  mkdir -p "$T"; cd "$T"; git init -q .
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "none" ]
  git remote add origin https://github.com/example/thing.git
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "github" ]
  git remote set-url origin https://gitlab.example.com/x/y.git
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "other" ]
}

@test "base branch: origin/HEAD first, then the override, each with its source" {
  T="$BATS_TEST_TMPDIR/base"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
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
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  probe --dir "$T"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.featureBranch' <<<"$output")" = "" ]
  [ "$(jq -r '.specDir' <<<"$output")" = "" ]
}

@test "feature branch: a typed name is reported, slashes and all" {
  T="$BATS_TEST_TMPDIR/branch-named"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
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
  mkdir -p "$T"; cd "$T"; git init -q -b work .
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
    case "$bad" in
      @*) [[ "$stderr" == *"is not a legal branch name"* ]] || { echo "wrong reason: $bad: $stderr"; false; } ;;
    esac
  done
}

@test "base branch: an override that exists only on origin is refused, naming the command that fixes it" {
  # B's `git checkout -b <feature> <base>` and every later `<base>..HEAD`
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
  mkdir -p "$T"; cd "$T"; git init -q -b work .; seed
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

# speclink <target> <name>: a symbolic link, made as tests/portability.bats
# makes one. Under Git Bash, `ln -s` without nativestrict makes a COPY, so
# pre-flight would rightly accept the path and the test would go red for no
# fault (review 3, blocking 3). `|| true`: where ln cannot make a native
# link it exits non-zero, and under errexit that would end the test before
# the check below.
speclink() {
  MSYS=winsymlinks:nativestrict ln -s "$1" "$2" 2>/dev/null || true
  [ -L "$2" ]
}

@test "spec folder: a symbolic link out of the repository, into .git or the state directory, or dangling, is refused" {
  T="$BATS_TEST_TMPDIR/specdir-link"
  mkdir -p "$T/repo" "$T/outside"; cd "$T/repo"; git init -q -b work .; seed
  # The first link decides whether this system can make one at all.
  speclink "$T/outside" out || skip "this system cannot make a symbolic link"
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
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  probe --dir "$T"
  [ "$status" -eq 0 ]
  [ "$(jq -c '.commitTrailers' <<<"$output")" = '[]' ]
}

@test "trailers: each one is reported, in the order given" {
  # The orchestrator passes the key's trailers first, then the flags'. The
  # script keeps that order, so the probe line and the commits match it.
  T="$BATS_TEST_TMPDIR/trailers-named"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
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
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  probe --dir "$T" --trailer 'Plan-Item: a' --trailer 'Pieces: b' --trailer 'XPiece: c' --trailer 'Related: d'
  [ "$status" -eq 0 ]
  [ "$(jq -c '.commitTrailers' <<<"$output")" = '["Plan-Item: a","Pieces: b","XPiece: c","Related: d"]' ]
}

@test "trailers: a value holding a colon is reported whole" {
  # The token ends at the FIRST colon; taking it up to the last would cut
  # the URL.
  T="$BATS_TEST_TMPDIR/trailers-url"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
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
  [ "$(jq -r '.capabilities.jq' <<<"$output")" = "true" ]
  [[ "$(jq -r '.capabilities.gh' <<<"$output")" =~ ^(true|false)$ ]]
  [[ "$(jq -r '.capabilities.adb' <<<"$output")" =~ ^(true|false)$ ]]
}

@test "willSkip names phases L and M in a repository with no remote" {
  T="$BATS_TEST_TMPDIR/skips"
  mkdir -p "$T"; cd "$T"; git init -q .
  probe --dir "$T" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '[.willSkip[].phase] | index("L") != null' <<<"$output")" = "true" ]
  [ "$(jq -r '[.willSkip[].phase] | index("M") != null' <<<"$output")" = "true" ]
}

@test "tree reports dirty and runsLive from the facts on disk" {
  T="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$T"; cd "$T"; git init -q .
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.tree.dirty' <<<"$output")" = "false" ]
  [ "$(jq -r '.tree.runsLive' <<<"$output")" = "false" ]
  printf 'x' > dirt.txt
  mkdir -p .delivery-kit/runs/001-x
  printf '{"current_phase":"B"}' > .delivery-kit/runs/001-x/progress.json
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.tree.dirty' <<<"$output")" = "true" ]
  [ "$(jq -r '.tree.runsLive' <<<"$output")" = "true" ]
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
  # trailer-check.sh says it needs jq and grep only, because these tests give
  # the probe nothing else. This proves it: an accepted trailer and a
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
  # because the fixture sits inside this checkout and inherits its remote while
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
  ( cd "$ra" && git init -q . && git remote add origin https://gitlab.example.com/x/y.git )
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
  ( cd "$rb" && git init -q . && git remote add origin https://github.com/example/thing.git )
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
  ( cd "$r" && git init -q . && git remote add origin https://github.com/example/thing.git )
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

  # The report is COMPLETE, not truncated. Absence sets a field to false; it
  # never drops a key, and no consumer should have to read a short document as
  # the signal for a missing tool.
  [ "$(jq -r '.projectType' <<<"$output")" = "other" ]
  [ "$(jq -r '.baseBranch' <<<"$output")" = "main" ]
  # THE TRIPWIRE for the exception declared above, and it is the SOURCE, not
  # the value. Measured: this checkout publishes origin/HEAD -> origin/main, so
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
}

# --- a constitution at the size a herestring hangs on -------------------------

@test "a constitution of 65,600 bytes is judged, not hung on" {
  # Git Bash 5.3.9 hangs a herestring of 65,536 to about 65,700 bytes, and the
  # constitution body used to reach grep through one. Measured against that
  # script: this test timed out (status 124) here, and 65,600 sits inside the
  # band. The size IS the property, so it is asserted before the probe runs —
  # a fixture that drifted out of the band would pass for the wrong reason.
  T="$BATS_TEST_TMPDIR/big-constitution"
  mkdir -p "$T/.specify/memory"
  ( cd "$T" && git init -q . )
  # 820 lines of 79 characters plus a newline: 65,600 bytes, no template token.
  awk 'BEGIN { l = sprintf("%79s", ""); gsub(/ /, "x", l); for (i = 0; i < 820; i++) print l }' \
    > "$T/.specify/memory/constitution.md"
  [ "$(wc -c < "$T/.specify/memory/constitution.md" | tr -d ' ')" -eq 65600 ]

  # timeout is GNU coreutils and macOS does not ship it. Where it is missing,
  # bats' own per-test limit (helper.bash) still bounds a hang and names it.
  # Probed with --version, not command -v: on Windows a System32 timeout.exe
  # can come first on PATH, takes no command, and exits 1 on --version
  # (measured), so it falls to the fallback instead of failing for no reason.
  if timeout --version > /dev/null 2>&1; then
    run --separate-stderr timeout 30 "$BASH_ABS" "$PROBE" --dir "$T" --base-branch main
  else
    probe --dir "$T" --base-branch main
  fi
  [ "$status" -eq 0 ] || { echo "pre-flight did not finish: status $status"; false; }
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "true" ]
}
