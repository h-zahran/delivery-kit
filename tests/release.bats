#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load helper

# scripts/release.sh makes the release edits for one plugin: its version in
# the marketplace and in its manifest, and its `## [Unreleased]` heading dated.
# Audit item R9 (2026-10-12): until it existed the owner made these edits by
# hand each release, from session notes.
#
# Every test runs the script on a COPY of the five release files in a fresh
# git repository under $TEST_DIR, never on this tree. The gate it runs,
# scripts/check-versions.sh, is the real one, found beside the real script.
# A refusal must change nothing: each one compares every copied file's bytes
# before and after, and checks no path of the fixture is printed.

REL_FILES=".gitattributes .claude-plugin/marketplace.json handoff/.claude-plugin/plugin.json handoff/CHANGELOG.md pipeline/.claude-plugin/plugin.json pipeline/CHANGELOG.md"

# The copy, not yet committed, so a test can change it first.
copy_tree() {
  R="$TEST_DIR/repo"
  local f
  for f in $REL_FILES; do
    mkdir -p "$R/${f%/*}"
    cp "$ROOT/$f" "$R/$f"
  done
}

commit_tree() {
  git -C "$R" init -q
  git -C "$R" config core.autocrlf false
  # shellcheck disable=SC2086 # the list is space-separated on purpose
  git -C "$R" add -- $REL_FILES
  git -C "$R" -c user.name=fixture -c user.email=fixture@example.invalid commit -q -m fixture
}

# edit <file> <awk program> [awk options]: rewrite a fixture file through awk,
# refusing a program that changed nothing (a fixture edit that silently missed
# would turn a refusal test into a test of something else).
edit() {
  awk "${@:3}" "$2" "$R/$1" > "$R/$1.new"
  if cmp -s "$R/$1.new" "$R/$1"; then echo "fixture edit changed nothing in $1"; rm -f "$R/$1.new"; return 1; fi
  mv "$R/$1.new" "$R/$1"
}

# open_unreleased <plugin> [body]: an `## [Unreleased]` heading above the
# first level-two heading, with an entry under it unless body says otherwise.
# body is an awk -v string, so \n in it is a line break.
open_unreleased() {
  edit "$1/CHANGELOG.md" \
    'd == 0 && /^## / { print "## [Unreleased]"; print ""; if (b != "") { print b; print "" }; d = 1 } { print }' \
    -v b="${2-### Fixed\n\n- **A fault.** It is fixed.}"
}

# set_version <plugin> <version>: the plugin's version in all three places.
set_version() {
  edit "$1/.claude-plugin/plugin.json" \
    '{ sub(/"version": "[0-9.]*"/, "\"version\": \"" v "\"") } { print }' -v v="$2"
  edit .claude-plugin/marketplace.json \
    'index($0, "\"name\": \"" p "\"") { f = 1 } f && /"version": / { sub(/"version": "[0-9.]*"/, "\"version\": \"" v "\""); f = 0 } { print }' \
    -v p="$1" -v v="$2"
  edit "$1/CHANGELOG.md" \
    'd == 0 && /^## \[[0-9]/ { sub(/\[[0-9.]*\]/, "[" v "]"); d = 1 } { print }' -v v="$2"
}

snap() {
  local f
  for f in $REL_FILES; do cksum < "$R/$f"; done
}

release() {
  run bash -c 'cd "$1" || exit 99; shift; bash "$@"' _ "$R" "$ROOT/scripts/release.sh" "$@"
}

# refuse <fragment> <args...>: the script refuses, says <fragment>, prints no
# fixture path, and leaves every copied file and the history as they were.
refuse() {
  local frag="$1" before head0
  shift
  before="$(snap)"
  head0="$(git -C "$R" rev-parse HEAD)"
  release "$@"
  [ "$status" -ne 0 ] || { echo "accepted '$*'; output: $output"; return 1; }
  case "$output" in
    *"$frag"*) ;;
    *) echo "refused '$*' without '$frag'; output: $output"; return 1 ;;
  esac
  case "$output" in
    *"$TEST_DIR"*) echo "the refusal prints the fixture's path; output: $output"; return 1 ;;
  esac
  [ "$(snap)" = "$before" ] || { echo "refusing '$*' changed the files"; return 1; }
  [ "$(git -C "$R" rev-parse HEAD)" = "$head0" ] || { echo "refusing '$*' moved HEAD"; return 1; }
}

# accept <plugin> <version>: the script passes, the gate's line says released,
# exactly the plugin's three files changed by one line each, nothing was
# committed or tagged, and the changelog's first level-two heading is dated.
accept() {
  local p="$1" v="$2" head0 today0 today1 first
  head0="$(git -C "$R" rev-parse HEAD)"
  today0="$(date +%Y-%m-%d)"
  release "$p" "$v"
  today1="$(date +%Y-%m-%d)"
  [ "$status" -eq 0 ] || { echo "refused $p $v; output: $output"; return 1; }
  case "$output" in
    *"$p: plugin=$v marketplace=$v changelog=$v state=released"*) ;;
    *) echo "no released line for $p $v; output: $output"; return 1 ;;
  esac
  case "$output" in
    *"Nothing was committed"*"git tag $p-v$v origin/main"*"tag matches the manifest version"*) ;;
    *) echo "the next steps are missing; output: $output"; return 1 ;;
  esac
  [ "$(git -C "$R" rev-parse HEAD)" = "$head0" ] || { echo "the release moved HEAD"; return 1; }
  [ -z "$(git -C "$R" tag)" ] || { echo "the release made a tag"; return 1; }
  local want got
  want="$(printf '1\t1\t%s\n' .claude-plugin/marketplace.json "$p/.claude-plugin/plugin.json" "$p/CHANGELOG.md" | LC_ALL=C sort)"
  got="$(git -C "$R" diff --numstat | LC_ALL=C sort)"
  [ "$got" = "$want" ] || { echo "the changed lines differ:"; echo "$got"; return 1; }
  first="$(awk '/^## / { print; exit }' "$R/$p/CHANGELOG.md")"
  [ "$first" = "## [$v] - $today0" ] || [ "$first" = "## [$v] - $today1" ] \
    || { echo "first heading is '$first'"; return 1; }
  grep -qF -- "\"version\": \"$v\"" "$R/$p/.claude-plugin/plugin.json" \
    || { echo "$p's manifest does not carry $v"; return 1; }
}

@test "release.sh releases a plugin: three files, one line each, nothing committed" {
  copy_tree
  open_unreleased pipeline
  commit_tree
  accept pipeline 1.6.0
  # handoff's entry in the marketplace is untouched.
  [ "$(grep -c -- '"version": "2.3.1"' "$R/.claude-plugin/marketplace.json")" -eq 1 ]
}

@test "release.sh releases the first marketplace entry as well as the last" {
  copy_tree
  open_unreleased handoff
  commit_tree
  accept handoff 2.4.0
  [ "$(grep -c -- '"version": "1.5.0"' "$R/.claude-plugin/marketplace.json")" -eq 1 ]
}

@test "release.sh edits only the named plugin's entry when both share a version" {
  copy_tree
  set_version handoff 1.5.0
  open_unreleased pipeline
  commit_tree
  [ "$(grep -c -- '"version": "1.5.0"' "$R/.claude-plugin/marketplace.json")" -eq 2 ]
  accept pipeline 1.5.1
  # The handoff entry, first in the file, still reads 1.5.0.
  got="$(awk '/"name": "handoff"/ { f = 1 } f && /"version": / { print; exit }' "$R/.claude-plugin/marketplace.json")"
  [[ $got == *'"version": "1.5.0"'* ]] || { echo "handoff entry now reads: $got"; false; }
}

@test "release.sh compares versions as numbers, field by field" {
  copy_tree
  set_version pipeline 1.9.0
  open_unreleased pipeline
  commit_tree
  # As text, 1.10.0 sorts below 1.9.0.
  refuse 'is not higher than' pipeline 1.8.99
  refuse 'is not higher than' pipeline 1.9.0
  refuse 'is not higher than' pipeline 0.10.0
  accept pipeline 1.10.0
}

@test "release.sh accepts a higher major with lower minor and patch" {
  copy_tree
  open_unreleased pipeline
  commit_tree
  accept pipeline 2.0.0
}

@test "release.sh accepts a patch release" {
  copy_tree
  open_unreleased pipeline
  commit_tree
  accept pipeline 1.5.1
}

@test "release.sh refuses a version that is not higher" {
  copy_tree
  open_unreleased pipeline
  commit_tree
  refuse 'is not higher than pipeline' pipeline 1.5.0
  refuse 'is not higher than' pipeline 1.4.9
  refuse 'is not higher than' pipeline 1.4.10
  refuse 'is not higher than' pipeline 0.99.99
}

@test "release.sh refuses a version that is not MAJOR.MINOR.PATCH" {
  copy_tree
  open_unreleased pipeline
  commit_tree
  for v in 1.6 1.6.0.1 v1.6.0 01.6.0 1.06.0 1.6.00 1.6.0-rc1 '1.6.0 ' ' 1.6.0' 1.6.x '' 1234567890.0.0; do
    case $v in
      1234567890.0.0) refuse 'longer than nine digits' pipeline "$v" ;;
      *) refuse 'is not MAJOR.MINOR.PATCH' pipeline "$v" ;;
    esac
  done
}

@test "release.sh refuses a plugin it does not know" {
  copy_tree
  open_unreleased pipeline
  mkdir -p "$R/extra/.claude-plugin"
  printf '{\n  "name": "extra",\n  "version": "1.5.0"\n}\n' > "$R/extra/.claude-plugin/plugin.json"
  cp "$R/pipeline/CHANGELOG.md" "$R/extra/CHANGELOG.md"
  commit_tree
  git -C "$R" add -- extra
  git -C "$R" -c user.name=fixture -c user.email=fixture@example.invalid commit -q -m extra
  refuse 'is not a plugin in this tree' ghost 1.6.0
  refuse 'is not a plugin name' Pipeline 1.6.0
  refuse 'is not a plugin name' ../pipeline 1.6.0
  refuse 'is not a plugin name' '' 1.6.0
  # A plugin directory the marketplace does not list.
  refuse 'expected to change 1 version line' extra 1.6.0
}

@test "release.sh refuses the wrong number of arguments" {
  copy_tree
  open_unreleased pipeline
  commit_tree
  refuse 'usage: release.sh <plugin> <version>'
  refuse 'usage: release.sh <plugin> <version>' pipeline
  refuse 'usage: release.sh <plugin> <version>' pipeline 1.6.0 extra
}

@test "release.sh refuses a tree that is not clean" {
  copy_tree
  open_unreleased pipeline
  commit_tree
  : > "$R/untracked.txt"
  refuse 'the tree is not clean' pipeline 1.6.0
  rm "$R/untracked.txt"
  printf '\n' >> "$R/handoff/CHANGELOG.md"
  refuse 'the tree is not clean' pipeline 1.6.0
  git -C "$R" add -- handoff/CHANGELOG.md
  refuse 'the tree is not clean' pipeline 1.6.0
}

@test "release.sh refuses to run anywhere but the repository root" {
  copy_tree
  open_unreleased pipeline
  commit_tree
  run bash -c 'cd "$1" || exit 99; shift; bash "$@"' _ "$R/pipeline" "$ROOT/scripts/release.sh" pipeline 1.6.0
  [ "$status" -ne 0 ] && [[ $output == *'run from the repository root'* ]] || { echo "output: $output"; false; }
  # A subdirectory that holds a marketplace file of its own is still not the top.
  mkdir -p "$R/sub/.claude-plugin"
  cp "$R/.claude-plugin/marketplace.json" "$R/sub/.claude-plugin/"
  git -C "$R" add -- sub
  git -C "$R" -c user.name=fixture -c user.email=fixture@example.invalid commit -q -m sub
  run bash -c 'cd "$1" || exit 99; shift; bash "$@"' _ "$R/sub" "$ROOT/scripts/release.sh" pipeline 1.6.0
  [ "$status" -ne 0 ] && [[ $output == *'run from the top of the repository'* ]] || { echo "output: $output"; false; }
}

@test "release.sh refuses a tree that is not a git repository" {
  copy_tree
  open_unreleased pipeline
  before="$(snap)"
  release pipeline 1.6.0
  [ "$status" -ne 0 ] && [[ $output == *'not inside a git repository'* ]] || { echo "output: $output"; false; }
  [ "$(snap)" = "$before" ]
}

@test "release.sh refuses a changelog with no Unreleased heading" {
  copy_tree
  commit_tree
  # As released: no heading at all.
  refuse 'no `## [Unreleased]` heading' pipeline 1.6.0
}

@test "release.sh refuses an Unreleased heading with nothing under it" {
  copy_tree
  open_unreleased pipeline ''
  commit_tree
  refuse 'nothing under `## [Unreleased]`' pipeline 1.6.0
}

@test "release.sh refuses an Unreleased heading with only a group heading under it" {
  copy_tree
  open_unreleased pipeline '### Fixed'
  commit_tree
  refuse 'nothing under `## [Unreleased]`' pipeline 1.6.0
}

@test "release.sh refuses two Unreleased headings" {
  copy_tree
  open_unreleased pipeline
  edit pipeline/CHANGELOG.md '/^## \[1\.4\.0\]/ { print "## [Unreleased]"; print ""; print "- **Old.** Entry."; print "" } { print }'
  commit_tree
  refuse '2 `## [Unreleased]` headings, not 1' pipeline 1.6.0
}

@test "release.sh refuses an Unreleased heading below a release" {
  copy_tree
  edit pipeline/CHANGELOG.md '/^## \[1\.4\.0\]/ { print "## [Unreleased]"; print ""; print "- **Late.** Entry."; print "" } { print }'
  commit_tree
  refuse 'is not the first level-two heading' pipeline 1.6.0
}

@test "release.sh refuses an Unreleased heading that carries more text" {
  copy_tree
  open_unreleased pipeline
  edit pipeline/CHANGELOG.md '$0 == "## [Unreleased]" { $0 = "## [Unreleased] - soon" } { print }'
  commit_tree
  refuse 'carries more text' pipeline 1.6.0
}

@test "release.sh refuses a manifest without exactly one version line" {
  copy_tree
  open_unreleased pipeline
  edit pipeline/.claude-plugin/plugin.json '{ print } /"version": / { print "  \"version\": \"1.5.0\"," }'
  commit_tree
  refuse 'does not hold exactly one "version" line' pipeline 1.6.0
}

@test "release.sh refuses a marketplace entry that disagrees with the manifest" {
  copy_tree
  open_unreleased pipeline
  edit .claude-plugin/marketplace.json '/"name": "pipeline"/ { f = 1 } f && /"version": / { sub(/1\.5\.0/, "1.4.0"); f = 0 } { print }'
  commit_tree
  refuse 'expected to change 1 version line' pipeline 1.6.0
}

@test "release.sh refuses a marketplace entry that carries its version line twice" {
  copy_tree
  open_unreleased pipeline
  edit .claude-plugin/marketplace.json '{ print } /"name": "pipeline"/ { f = 1 } f && /"version": / { print; f = 0 }'
  commit_tree
  refuse 'expected to change 1 version line for '"'"'pipeline'"'"' at 1.5.0, changed 2' pipeline 1.6.0
}

@test "release.sh refuses a marketplace entry without a version line, never taking the next entry's" {
  copy_tree
  open_unreleased handoff
  # handoff's entry, first in the file, loses its version line, and the
  # pipeline entry after it carries handoff's version.
  edit .claude-plugin/marketplace.json '/"name": "handoff"/ { f = 1 } f && /"version": / { f = 0; next } { print }'
  edit .claude-plugin/marketplace.json '/"name": "pipeline"/ { f = 1 } f && /"version": / { sub(/1\.5\.0/, "2.3.1"); f = 0 } { print }'
  commit_tree
  refuse 'expected to change 1 version line for '"'"'handoff'"'"' at 2.3.1, changed 0' handoff 2.4.0
}

@test "release.sh restores the three files when the gate refuses the release" {
  copy_tree
  open_unreleased pipeline
  # A stray level-two heading lower in the file: release.sh's own checks pass
  # it, and check-versions.sh --released refuses it after the edits are made.
  edit pipeline/CHANGELOG.md '/^## \[1\.4\.0\]/ { print "## Notes"; print ""; print "A stray heading."; print "" } { print }'
  commit_tree
  refuse 'scripts/check-versions.sh refused the release; the three files are restored' pipeline 1.6.0
  [ -z "$(git -C "$R" status --porcelain)" ] || { git -C "$R" status --porcelain; false; }
}

@test "release.sh keeps nothing unless the gate prints the plugin as released" {
  copy_tree
  open_unreleased pipeline
  commit_tree
  # A copy of the script beside a stand-in gate that exits 0. One prints
  # nothing; one prints the plugin as not released.
  bin="$TEST_DIR/bin"
  mkdir -p "$bin"
  cp "$ROOT/scripts/release.sh" "$bin/release.sh"
  for body in 'exit 0' 'echo "pipeline: plugin=1.6.0 marketplace=1.6.0 changelog=1.6.0 state=UNRELEASED-ABOVE:x"; exit 0'; do
    printf '%s\n' "$body" > "$bin/check-versions.sh"
    before="$(snap)"
    run bash -c 'cd "$1" || exit 99; shift; bash "$@"' _ "$R" "$bin/release.sh" pipeline 1.6.0
    [ "$status" -ne 0 ] && [[ $output == *'did not print'*'the three files are restored'* ]] \
      || { echo "stand-in gate '$body' accepted; output: $output"; false; }
    [ "$(snap)" = "$before" ] || { echo "stand-in gate '$body' left the files changed"; false; }
  done
}

@test "release.sh is never run by CI and never runs jq" {
  cd "$ROOT"
  if grep -nF -- 'release.sh' .github/workflows/ci.yml; then echo "ci.yml names release.sh"; false; fi
  # A jq round trip reformats marketplace.json, and jq 1.6 has no -b.
  if awk '!/^[[:space:]]*#/ && /(^|[^A-Za-z_])jq([^A-Za-z_]|$)/ { print FILENAME ":" FNR ": " $0; f = 1 } END { exit !f }' scripts/release.sh; then
    echo "release.sh runs jq"; false
  fi
}

@test "CONTRIBUTING gives the release order, and the tag step it names is CI's" {
  cd "$ROOT"
  local c run commit merge tag step
  c="$(tr -d '\r' < CONTRIBUTING.md | tr '\n' ' ' | tr -s ' ')"
  pos() { local b="${c%%"$1"*}"; [ "$b" != "$c" ] || { echo "CONTRIBUTING lacks: $1" >&2; return 1; }; printf '%s' "${#b}"; }
  run="$(pos 'run `bash scripts/release.sh <plugin> <version>` from the repository root')"
  commit="$(pos 'then commit the three files the script names')"
  merge="$(pos 'open a pull request, and merge it once CI is green')"
  tag="$(pos '`git tag <plugin>-v<version> origin/main`')"
  step="$(pos '"tag matches the manifest version". It must say success.')"
  [ "$run" -lt "$commit" ] && [ "$commit" -lt "$merge" ] && [ "$merge" -lt "$tag" ] && [ "$tag" -lt "$step" ] \
    || { echo "order is run=$run commit=$commit merge=$merge tag=$tag step=$step"; false; }
  grep -qxF -- '      - name: tag matches the manifest version' .github/workflows/ci.yml \
    || { echo "ci.yml has no step named 'tag matches the manifest version'"; false; }
  grep -qxF -- '    name: version agreement' .github/workflows/ci.yml \
    || { echo "ci.yml has no job named 'version agreement'"; false; }
  [[ $c == *'open the `version agreement` job'* ]] || { echo "CONTRIBUTING does not name the job"; false; }
}
