#!/usr/bin/env bash
# preflight.sh — detection and capability probe for the pipeline plugin.
#
# PURE JSON on stdout; every diagnostic on stderr — the contract
# progress.sh states in full. This script only REPORTS: taking the lock,
# offering the gitignore line and refusing a dirty tree are the skill's
# decisions, made from these facts. A missing capability degrades a named
# phase; it never crashes one.
set -euo pipefail

# A set CDPATH makes cd print the resolved path to STDOUT — poison for a
# pure-JSON contract. Unset it rather than trusting every future cd.
unset CDPATH
# A set GREP_OPTIONS silently rewrites every grep below on legacy greps
# (honored through 3.5) — same env-poisoning class, same cure.
unset GREP_OPTIONS
# Byte semantics for every [A-Z] and [[:space:]] below: under a UTF-8
# locale those classes drift (U+00A0 starts matching), and the
# constitution probe's documented edges depend on C-locale reads.
export LC_ALL=C

warn() { printf 'preflight: %s\n' "$*" >&2; }
die()  { printf 'preflight: %s\n' "$*" >&2; exit 1; }
# A value a refusal prints comes from the command line, a tracked key or
# git, so it may hold a terminal escape, a bidi character or a line break.
# Every refusal below prints a value only through a copy from shown(), in
# names.sh, each copy named here once.
arg_s='' vf_s='' pt_s='' sd_s='' seg_s='' dir_s='' br_s='' fb_s='' p_s='' run_s='' base_s='' hit_s='' scr_s='' ver_s=''

command -v jq >/dev/null 2>&1 || die "jq is required and was not found on PATH"

# A commit trailer goes onto every commit the run makes, and commits leave
# the machine, so each one is checked here, in the order given, and named
# when refused. The rule itself lives in trailer-check.sh, beside this
# script: progress.sh runs the same file before every commit, so the two
# can never disagree. A trailer may come from the commitTrailers key or the
# --trailer flag; this script cannot tell which, so its errors name neither.
# The list is held as one JSON string per line and reaches the report on
# standard input, since a long list would not fit one argument. One trailer
# must fit one, twice over: to trailer-check.sh and from there to jq. A native
# jq on Windows takes about 32 KB of command line, and past about 128 KB on
# Linux bash itself fails and prints this script's absolute path, so the one
# limit below is read first, in bytes under this script's C locale.
here="${BASH_SOURCE[0]}"
case "$here" in */*) here="${here%/*}" ;; *) here=. ;; esac
here="$(cd -P -- "$here" && pwd -P)" || die "cannot find the folder that holds preflight.sh"
for f in hidden-chars.sh names.sh; do
  [ -r "$here/$f" ] || die "$f is missing beside preflight.sh"
  # shellcheck source=/dev/null # the two files beside this script
  . "$here/$f"
done
add_trailer_json() {
  local j="$1" ok
  [ "${#j}" -le 30000 ] \
    || die "a trailer is longer than 30000 bytes as JSON, the most the check can read on every system (a commit trailer)"
  ok="$("$BASH" "$here/trailer-check.sh" "$j" 2>&1 >/dev/null)" \
    || die "$ok (a commit trailer)"
  trailers="$trailers$j"$'\n'
}
add_trailer() { add_trailer_json "$(jq -jn --arg t "$1" '$t | tojson')"; }

dir="."; ptype_override=""; base_configured=""; base_override=""
feature_branch=""; spec_dir=""; trailers=""; values_file=""
ptype_label="--project-type"; override_label="--base-branch-override"; base_label="the baseBranch key"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)          dir="${2:?--dir needs a path}"; shift 2 ;;
    --project-type) ptype_override="${2:?--project-type needs a value}"; shift 2 ;;
    --base-branch)  base_configured="${2:?--base-branch needs a name}"; shift 2 ;;
    --base-branch-override) base_override="${2:?--base-branch-override needs a name}"; shift 2 ;;
    --feature-branch) feature_branch="${2:?--feature-branch needs a name}"; shift 2 ;;
    --spec-dir)     spec_dir="${2:?--spec-dir needs a path}"; shift 2 ;;
    --trailer)      add_trailer "${2:?--trailer needs a value}"; shift 2 ;;
    --values-file)  values_file="${2:?--values-file needs a path}"; shift 2 ;;
    *) shown arg_s "$1"; die "unknown argument '$arg_s' (legal: --dir --project-type --base-branch --base-branch-override --feature-branch --spec-dir --trailer --values-file)" ;;
  esac
done
# --values-file: the values a tracked file set reach this script with no shell
# reading them on the way. Each then takes the path a flag's value takes, with
# the same checks, and a refusal names the file. Read here, before --dir's cd,
# so a relative path is the caller's. The file's trailers go first and a typed
# flag wins, whatever the command line's order. jq reads the file by redirect
# each time, as a value of any size may be in it and one argument holds about
# 128 KB on Linux. One program judges the file and answers with the rule that
# broke; a file jq cannot parse has no answer. A trailer stays JSON to
# trailer-check.sh, as a value taken through $( ) would lose a trailing line
# feed. The other three must become shell values, so the program refuses a NUL,
# which bash would drop, and an empty one, which would read as a key not there,
# and the x keeps a trailing line feed for their checks to refuse.
# file_value <name> <key> sets the named variable to the key's value, or to
# nothing when the key is not there.
file_value() {
  local v
  v="$(jq -j --arg k "$2" '.[$k] // empty' < "$values_file" && printf x)" \
    || die "'$vf_s' could not be read (--values-file)"
  printf -v "$1" '%s' "${v%x}"
}
if [ -n "$values_file" ]; then
  shown vf_s "$values_file"
  { [ -f "$values_file" ] && [ -r "$values_file" ]; } || die "no readable file at '$vf_s' (--values-file)"
  rule="$(jq -j -s '
    def name($k): (has($k) | not)
      or (.[$k] | type == "string" and length > 0 and (explode | all(. != 0)));
    if length != 1 or (.[0] | type) != "object" then "object"
    else .[0]
      | if (keys - ["commitTrailers", "baseBranchOverride", "baseBranch", "projectType"]) != [] then "keys"
        elif ((has("commitTrailers") | not) or (.commitTrailers | type == "array" and all(type == "string")))
          and name("baseBranchOverride") and name("baseBranch") and name("projectType") then "ok"
        else "types" end
    end' < "$values_file" 2>/dev/null)" || rule=object
  case "$rule" in
    ok) ;;
    keys) die "'$vf_s' holds a key other than commitTrailers, baseBranchOverride, baseBranch and projectType (--values-file)" ;;
    types) die "'$vf_s' holds a value of the wrong type: commitTrailers is a list of strings; baseBranchOverride, baseBranch and projectType are each a string, not empty and with no NUL (--values-file)" ;;
    *) die "'$vf_s' does not hold one JSON object (--values-file)" ;;
  esac
  typed_trailers="$trailers"; trailers=""
  n="$(jq '.commitTrailers // [] | length' < "$values_file")"
  i=0
  while [ "$i" -lt "$n" ]; do
    add_trailer_json "$(jq -c --argjson i "$i" '.commitTrailers[$i]' < "$values_file")"
    i=$((i + 1))
  done
  trailers="$trailers$typed_trailers"
  # B records the list as one argument, so the whole list has the one limit.
  [ "${#trailers}" -le 31000 ] \
    || die "the commit trailers are longer than 31000 bytes as JSON together, the most the run can record on every system (a commit trailer)"
  if [ -z "$base_override" ]; then
    file_value base_override baseBranchOverride; override_label="the baseBranchOverride key"
  fi
  if [ -z "$base_configured" ]; then
    file_value base_configured baseBranch
  fi
  if [ -z "$ptype_override" ]; then
    file_value ptype_override projectType; ptype_label="the projectType key"
  fi
fi
# A project type is the owner's own name for the project: web and mobile-android
# pick a runtime strategy, and any other name uses the verify command. The run
# types the value into `progress.sh init`, so only what a shell or an option
# parser reads is refused, whichever way the value came.
case "$ptype_override" in
  -*|*[!A-Za-z0-9._-]*)
    shown pt_s "$ptype_override"
    die "'$pt_s' cannot be a project type: use letters, digits, '.', '_' and '-', and start with no dash ($ptype_label)" ;;
esac
# The spec folder is handed to the spec tool, which creates it and writes
# into it, and its last segment becomes the run's name under
# .delivery-kit/runs/ and, without --feature-branch, the branch's name. So
# it must be one relative spelling inside the repository, outside the state
# directory and outside .git, and every segment must be a plain folder name.
# These checks read the text only; the ones that need the repository run
# after the cd below. One check per way a path can break, each naming it.
if [ -n "$spec_dir" ]; then
  shown sd_s "$spec_dir"
  case "$spec_dir" in
    /*|[A-Za-z]:*) die "'$sd_s' is not relative to the repository root (--spec-dir)" ;;
    *\\*)          die "'$sd_s' holds a backslash; separate folders with / (--spec-dir)" ;;
  esac
  spec_dir="${spec_dir%/}"; shown sd_s "$spec_dir"
  case "/$spec_dir/" in
    */../*)        die "'$sd_s' climbs out with .. (--spec-dir)" ;;
    */./*|*//*)    die "'$sd_s' has an empty or . segment; write each path one way (--spec-dir)" ;;
  esac
  # Letter case is compared loosely: on a file system that ignores case,
  # .Delivery-Kit is the state directory and .GIT is git's own.
  rest="$spec_dir"; first=1
  while :; do
    seg="${rest%%/*}"; shown seg_s "$seg"
    [ "${seg#-}" != "$seg" ] || run_name_ok "$seg" \
      || die "'$sd_s' has the segment '$seg_s'; a folder name holds letters of any language, digits, dot, dash, underscore only (--spec-dir)"
    case "$seg" in
      -*) die "'$sd_s' has the segment '$seg_s', which starts with a dash (--spec-dir)" ;;
      .[Gg][Ii][Tt]) die "'$sd_s' is inside git's own directory .git (--spec-dir)" ;;
      # Win32 drops a trailing dot, so .git. is .git there, and it reads
      # a device name (nul, con, com1, nul.txt) as the device.
      *.) die "'$sd_s' has the segment '$seg_s', which ends with a dot; Windows drops it (--spec-dir)" ;;
    esac
    case "${seg%%.*}" in
      [Cc][Oo][Nn]|[Pp][Rr][Nn]|[Aa][Uu][Xx]|[Nn][Uu][Ll]|[Cc][Oo][Mm][0-9]|[Ll][Pp][Tt][0-9])
        die "'$sd_s' has the segment '$seg_s', a name Windows keeps for a device (--spec-dir)" ;;
    esac
    if [ "$first" = 1 ]; then
      case "$seg" in
        .[Dd][Ee][Ll][Ii][Vv][Ee][Rr][Yy]-[Kk][Ii][Tt]) die "'$sd_s' is inside the state directory .delivery-kit/ (--spec-dir)" ;;
      esac
    fi
    [ "$rest" != "$seg" ] || break
    rest="${rest#*/}"; first=0
  done
fi
cd "$dir" 2>/dev/null || { shown dir_s "$dir"; die "cannot enter '$dir_s'"; }
# Every check that asks git runs here, inside the repository, so a name
# like @{-1} is never read from the caller's.
#
# Is git USABLE here, not only found? Decided once, from exit codes alone.
# git's message text is never read: its wording changes between versions
# (this script runs under LC_ALL=C, so translation is not the reason). Each
# step runs only when the steps before it did not decide:
#   absent             git cannot be found on the search path
#   usable             `git rev-parse --git-dir` opens a repository here
#   broken             git is found, but `git --version` fails too
#   refused-ownership  it opens one only with git's ownership check lifted
#   no-repository      it opens none here, for any other cause
# rev-parse comes first so a working git costs one process. A refusal for a
# cause other than ownership reads no-repository, and so does every refusal
# on a git older than 2.38, which ignores safe.directory given with -c (its
# own documentation says so); that is why no-repository never claims there
# is no repository. The ownership check is lifted for that ONE command, on
# its own command line, and never written down. The check exists so an
# untrusted repository's configuration cannot make git run a program; the
# lifted `rev-parse --git-dir` does parse that configuration and its
# includes, but runs none of it — no hook, fsmonitor, pager, filter, alias
# or helper (measured on git 2.53.0 against 28 planted programs, none
# fired). An include pointing at a FIFO can stall it; there is no portable
# timeout to bound it with, and the stall runs nothing.
#
# git_present feeds capabilities.git ("found"); git_usable and git_reason
# feed gitUsable and gitReason. The name checks below run only when git_usable
# is true: with git found but not usable they would read a repository git
# refuses and die naming a wrong cause, so they skip and the names are
# reported unchecked, as without git. The run stops at decision 11 either
# way. git differs from gh and adb in KIND: they each degrade one named
# phase, git degrades none, because phases B, K and L are git operations
# and this script's own git reads — the base branch, the remote and the
# working tree — go quiet without a git that works here.
git_present=false; git_usable=false; git_reason=absent
if command -v git >/dev/null 2>&1; then
  git_present=true
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git_usable=true; git_reason=usable
  elif ! git --version >/dev/null 2>&1; then
    git_reason=broken
  elif git -c safe.directory='*' rev-parse --git-dir >/dev/null 2>&1; then
    git_reason=refused-ownership
  else
    git_reason=no-repository
  fi
fi
# Everything below reads from the repository's top, so every answer is the
# same from any folder inside it: the project files, .specify, the state
# directory and --spec-dir, which is relative to the top. git's relative
# path back to the top is used, as below, since --show-toplevel spells a path
# its own way (C:/Users/...). It fails inside .git, where the folder stays.
if [ "$git_usable" = true ] && t="$(git rev-parse --show-cdup 2>/dev/null)"; then
  cd -- "./$t" 2>/dev/null || die "cannot enter the repository's top folder"
fi
# branch_ok <name> <argument> — git decides what a legal branch name is, and
# it must print the name back unchanged: @{-1} expands to another name, and
# a name it expands is not the name that was typed. A lone @ passes both
# (measured, git 2.43.0), and git even creates the branch, but in a revision
# @ means HEAD, so <base>..HEAD would read nothing: it is refused by name.
# Then the name must hold only the safe characters below. The order keeps
# each refusal's reason: @{-1} and HEAD are git's to refuse first.
branch_ok() {
  local out
  shown br_s "$1"
  [ "$1" != @ ] || die "'@' is not a legal branch name here: git reads it as HEAD ($2)"
  out="$(git check-ref-format --branch "$1" 2>/dev/null)" && [ "$out" = "$1" ] \
    || die "'$br_s' is not a legal branch name ($2)"
  # git accepts $ ( ) ; & | < > a quote, a backtick and any byte past 0x7f
  # in a name (measured, review 4), and a branch's name is printed in
  # refusals and typed into commands: the one that fixes an origin-only
  # override ran a name like x$(touch${IFS}PWNED). names.sh holds the rule, one
  # for this script and progress.sh, and a name in any language passes it.
  local problem
  problem="$(name_problem "$1")"
  [ -z "$problem" ] || die "'$br_s' $problem ($2)"
}
# branch_like <name> — the local or origin branch that <name> collides
# with, or nothing: one equal to it in any letter case (a file system that
# ignores case stores refs/heads/Main and refs/heads/main in one file), or
# one that is a folder of it or has it as a folder, since git cannot hold
# refs/heads/team beside refs/heads/team/x.
branch_like() {
  git for-each-ref --format='%(refname)' refs/heads refs/remotes/origin 2>/dev/null \
    | awk -v n="$1" 'BEGIN { n = tolower(n) }
        { r = $0; sub(/^refs\/heads\//, "", r); sub(/^refs\/remotes\/origin\//, "", r)
          l = tolower(r)
          if (r != "HEAD" && (l == n || index(l, n "/") == 1 || index(n, l "/") == 1)) { print r; exit } }'
}
# base_usable <name> <label> — B runs `progress.sh branch-cut`, which runs
# `git checkout -b <feature> refs/heads/<base>`, and later phases read `<base>..HEAD`, so the base must be a legal name
# (branch_ok, first, so a name it refuses is never looked up), a LOCAL
# branch that names a commit, and a name git reads as that branch and as
# nothing else. One function serves every source (Principle IV): the
# override, where it is parsed, and origin/HEAD, the baseBranch key and the
# current branch once the base is resolved; each refusal names the source by
# its label. Each case below makes `git checkout -b` exit 128 (measured, git
# 2.53.0): a name that is nowhere, or only a tag; a name only origin has,
# a fresh clone's usual state, so that refusal names the one command that
# fixes it; the current branch before its first commit, which has no ref
# yet; a ref file written by hand to hold a tree (`update-ref` refuses to
# write one, a written file is read as one); and a name git reads as
# something other than the branch. A tag of the same name has its own
# message, since every later <base>..HEAD would read the tag. Every other
# such name, refs/<name>, a remote's branch, a remote's HEAD, ORIG_HEAD,
# main-worktree/<ref>, in either ref format, is found by asking git how it
# reads the name: `rev-parse --symbolic-full-name` prints refs/heads/<name>
# only when the name means that branch and nothing else, and it agreed with
# `git checkout -b` on every case measured (git 2.53.0, files and reftable),
# where a hand-made list of git's rules missed some and refused a branch
# named after a git file that is no ref. A remote can supply such a name
# through origin/HEAD. A name spelled as a full commit id is refused apart:
# `checkout -b` takes the branch, while rev-parse and <base>..HEAD take the
# commit. Exit statuses and that one ref name alone decide; git's text is
# never read.
base_usable() {
  branch_ok "$1" "$2"
  shown base_s "$1"
  if ! git show-ref --verify --quiet "refs/heads/$1"; then
    if git show-ref --verify --quiet "refs/remotes/origin/$1"; then
      die "'$base_s' exists only on origin; create the local branch first: git branch --track $base_s origin/$base_s ($2)"
    fi
    if [ "$(git symbolic-ref --quiet HEAD 2>/dev/null)" = "refs/heads/$1" ]; then
      die "'$base_s' has no commit yet; make a first commit, or pass a base branch that has one ($2)"
    fi
    die "'$base_s' is not a branch here or on origin ($2)"
  fi
  git rev-parse --verify --quiet "refs/heads/$1^{commit}" >/dev/null 2>&1 \
    || die "'$base_s' does not name a commit ($2)"
  if git show-ref --verify --quiet "refs/tags/$1"; then
    die "'$base_s' is a tag as well as a branch; git would read the tag ($2)"
  fi
  local full
  full="$(git rev-parse --symbolic-full-name "$1" 2>/dev/null)" || full=""
  [ "$full" = "refs/heads/$1" ] \
    || die "'$base_s' is the name of another ref as well as a branch; git cannot tell them apart ($2)"
  case "${#1}:$1" in
    40:*[!0-9a-f]*|64:*[!0-9a-f]*) ;;
    40:*|64:*) die "'$base_s' is spelled as a full commit id; git would read the commit, not the branch ($2)" ;;
  esac
}
# The override is what a person typed, or a key somebody wrote, for this
# run, so it is checked rather than trusted, here where it is parsed. A tag,
# a commit id, origin/main or refs/heads/main is not a branch's name.
if [ -n "$base_override" ] && [ "$git_usable" = true ]; then
  base_usable "$base_override" "$override_label"
fi
# The feature branch B will cut: --feature-branch, else the spec folder's
# last segment, which B names the branch after. It must be a legal name;
# below, once the base is known, it must also differ from the base and be
# new: `git checkout -b` refuses a name that exists, and on a file system
# that ignores case, one that differs only in letter case.
fb=""; fb_arg=""
if [ -n "$feature_branch" ]; then fb="$feature_branch"; fb_arg="--feature-branch"
elif [ -n "$spec_dir" ]; then fb="${spec_dir##*/}"; fb_arg="--spec-dir"; fi
if [ -n "$fb" ] && [ "$git_usable" = true ]; then
  branch_ok "$fb" "$fb_arg"
  # A name that is a tag too, refused as the override is: B's
  # `git checkout -b` makes the branch beside the tag, and every later
  # <name>..HEAD reads the tag.
  if git show-ref --verify --quiet "refs/tags/$fb"; then
    shown fb_s "$fb"
    die "'$fb_s' is a tag as well as the feature branch's name; git would read the tag ($fb_arg)"
  fi
fi
# A fresh run's folder must not exist: the spec tool would write over that
# feature's spec. Its parent, followed through any symbolic link, must stay
# inside the repository and out of .git and the state directory. And its
# run name must not have a state file: progress.sh init keeps an existing
# one, so the new run would silently continue the old one.
if [ -n "$spec_dir" ]; then
  [ ! -e "$spec_dir" ] && [ ! -L "$spec_dir" ] || die "'$sd_s' already exists (--spec-dir)"
  p="$spec_dir"
  while [ "$p" != . ] && [ ! -e "$p" ]; do
    case "$p" in */*) p="${p%/*}" ;; *) p=. ;; esac
  done
  shown p_s "$p"
  [ -d "$p" ] || die "'$sd_s' runs through '$p_s', which is not a folder (--spec-dir)"
  # The top is reached by git's relative path back to it: git's
  # --show-toplevel spells a path its own way (C:/Users/...).
  real="$(cd -P -- "$p" && pwd -P)" || die "cannot enter '$p_s' (--spec-dir)"
  top="$(pwd -P)"
  if [ "$git_usable" = true ] && t="$(git rev-parse --show-cdup 2>/dev/null)"; then
    top="$(cd -P -- "./$t" && pwd -P)" || top="$(pwd -P)"
  fi
  # Inside or outside is decided by identity, never by spelling. Git Bash
  # spells one folder /tmp/... and /c/.../Temp/..., and cd -P through
  # an absolute link gives the /tmp one while a repository entered as
  # /c/... keeps its own (measured, review 4), so comparing the text
  # refused a folder inside. The resolved folder's ancestors are walked by
  # cutting the last segment, never by cd .., and each is compared with the
  # top by -ef, the same device and inode (measured on Git Bash for
  # directories under both spellings). `under` ends as the name of the
  # folder just below the top on the way, empty when the folder is the top.
  # Each pass cuts one segment, and a value with no / left ends the walk.
  d="$real"; under=""; inside=false
  while :; do
    if [ "${d:-/}" -ef "$top" ]; then inside=true; break; fi
    case "$d" in */*) ;; *) break ;; esac
    under="${d##*/}"; d="${d%/*}"
  done
  # Neither refusal prints the resolved path: it is absolute, it holds the
  # user's name, and a refusal's text may leave the machine.
  [ "$inside" = true ] || die "'$sd_s' leads outside the repository (--spec-dir)"
  case "$under" in
    .[Gg][Ii][Tt]|.[Dd][Ee][Ll][Ii][Vv][Ee][Rr][Yy]-[Kk][Ii][Tt])
      die "'$sd_s' leads into git's or the run's own directory (--spec-dir)" ;;
  esac
  spec_run=".delivery-kit/runs/${spec_dir##*/}/progress.json"
  shown run_s "${spec_dir##*/}"
  [ ! -e "$spec_run" ] \
    || die "run name '$run_s' already has a state file, .delivery-kit/runs/$run_s/progress.json (--spec-dir)"
fi

# --- project type ----------------------------------------------------------
# Three shapes are mobile-android: Flutter (pubspec.yaml + android/), a
# native Gradle build (settings.gradle or settings.gradle.kts, with
# app/src/main/AndroidManifest.xml or android/), and React Native or Expo (a
# package.json whose dependencies or devDependencies name react-native or
# expo, + android/). They are read before web, as such a package.json may
# name a web toolchain too. A package.json whose dependencies or
# devDependencies name one of the web toolchains listed below is web;
# everything else is other. The override always wins, and the SOURCE is reported so a
# wrong guess is visible rather than silent.
ptype="other"; ptype_source="default"
gradle=""
for f in settings.gradle settings.gradle.kts; do
  if [ -f "$f" ]; then gradle="$f"; break; fi
done
if [ -f pubspec.yaml ] && [ -d android ]; then
  ptype="mobile-android"; ptype_source="pubspec.yaml + android/"
elif [ -n "$gradle" ] && [ -f app/src/main/AndroidManifest.xml ]; then
  ptype="mobile-android"; ptype_source="$gradle + AndroidManifest.xml"
elif [ -n "$gradle" ] && [ -d android ]; then
  ptype="mobile-android"; ptype_source="$gradle + android/"
elif [ -d android ] && [ -f package.json ] && jq -e '
    ((.dependencies // {}) + (.devDependencies // {})) | has("react-native") or has("expo")' \
    package.json >/dev/null 2>&1; then
  ptype="mobile-android"; ptype_source="package.json react-native or expo + android/"
elif [ -f package.json ] && jq -e '
    ((.dependencies // {}) + (.devDependencies // {})) | keys
    | map(select(. as $k | ["next", "vite", "astro", "react-scripts", "@angular/core", "nuxt",
        "gatsby", "@vue/cli-service", "@remix-run/dev", "webpack-dev-server"] | any(. == $k)))
    | length > 0' package.json >/dev/null 2>&1; then
  ptype="web"; ptype_source="package.json toolchain"
fi
if [ -n "$ptype_override" ]; then ptype="$ptype_override"; ptype_source="override"; fi

# --- spec tool -------------------------------------------------------------
sk_present=false; sk_version=""; sk_in_range=false; sk_script=""; sk_scripts_dir=""; sk_form="none"
if [ -d .specify/templates ] && [ -d .specify/scripts ]; then
  sk_present=true
  if [ -f .specify/init-options.json ]; then
    sk_version="$(jq -r '.speckit_version // empty' .specify/init-options.json 2>/dev/null || true)"
    sk_script="$(jq -r '.script // empty' .specify/init-options.json 2>/dev/null || true)"
  fi
  # THE PATTERN AND THE PROSE MUST MOVE TOGETHER. This case is the
  # authoritative definition of the tested range; the warning below spells the
  # same range in words, and four documents spell it again — the two READMEs,
  # pipeline/docs/configuration.md and the orchestrator skill. Widening the
  # pattern here without rewording all five leaves the tool accepting a version
  # every document still calls untested, which is the quieter direction of the
  # two. Find them with: git grep -n '0\.15\.x through 0\.16\.x'
  case "$sk_version" in
    0.15.*|0.16.*) sk_in_range=true ;;
    "") warn "no version recorded in .specify/init-options.json" ;;
    *)  shown ver_s "$sk_version"; warn "version $ver_s is outside the tested range (0.15.x through 0.16.x) — continuing; untested is not known-broken" ;;
  esac
  # `script` has exactly three legal values upstream: sh, ps, py. py is
  # legal for the tool and unusable by this pipeline, so it is reported
  # loudly with an empty scriptsDir; an illegal value dies by name —
  # silently defaulting is forbidden.
  case "$sk_script" in
    sh) sk_scripts_dir=".specify/scripts/bash" ;;
    ps) sk_scripts_dir=".specify/scripts/powershell" ;;
    py) sk_scripts_dir=""
        warn "script flavour 'py' is legal for the spec tool but this pipeline cannot drive it; script-dependent steps will be named and skipped" ;;
    "") warn "no script flavour recorded in .specify/init-options.json" ;;
    *)  shown scr_s "$sk_script"; die "illegal script flavour '$scr_s' in .specify/init-options.json (legal: sh|ps|py)" ;;
  esac
  # Invocation form: a Claude install scaffolds hyphen-named skills; the
  # dot-named command files belong to other integrations. Whichever exists
  # is recorded — skills win when both do — and a foreign agent's skills
  # root is evidence, not something to adopt.
  if compgen -G '.claude/commands/speckit.*.md' > /dev/null 2>&1; then sk_form="dot-commands"; fi
  if compgen -G '.claude/skills/speckit-*' > /dev/null 2>&1; then sk_form="hyphen-skills"; fi
  if [ "$sk_form" = "none" ] && compgen -G '.agents/skills/speckit-*' > /dev/null 2>&1; then
    warn "found .agents/skills/speckit-* — this repository was initialised for a different agent; not adopting it"
  fi
fi

# --- constitution ------------------------------------------------------------
# The observable is the 1.1.0 contract: absent, or still the placeholder
# template a fresh init writes, or empty of real content -> false;
# written principles -> true. "Placeholder template" means the shipped
# template's OWN tokens surviving outside comments — an arbitrary
# bracketed token ([RFC2119], a checked [X] box) is a written
# constitution's prose, not template residue. HTML comments are
# stripped (multi-line included; an unclosed comment is kept as text)
# because the constitution command's own Sync Impact Report is a
# comment carrying bracketed tokens. A file with NUL bytes in its head
# (any UTF-16/32 save) reads false WITH a warning — unparseable bytes
# fail toward offering, never toward "set". The named residual edges
# live in the feature's research file. Computed and emitted
# unconditionally: the value derives from the constitution file alone,
# so it is defined whether or not the spec tool is installed.
sk_const=false
const_file=".specify/memory/constitution.md"
const_tokens='\[(PROJECT_NAME|PRINCIPLE_[0-9]+_(NAME|DESCRIPTION)|SECTION_[0-9]+_(NAME|CONTENT)|GOVERNANCE_RULES|GUIDANCE_FILE|CONSTITUTION_VERSION|RATIFICATION_DATE|LAST_AMENDED_DATE)\]'
if [ -f "$const_file" ]; then
  # od's output is captured whole, then matched. Under pipefail a reader
  # that leaves early (grep -q) can kill od with SIGPIPE and fail the
  # pipeline; tests/pipefail.bats refuses that shape. `|| true` keeps what
  # was captured, and keeps an unreadable file on the parse below. od writes
  # every byte as a space-led pair, so a NUL is always " 00".
  hex="$(head -c 4096 "$const_file" 2>/dev/null | od -An -tx1)" || true
  if [[ $hex == *' 00'* ]]; then
    warn "constitution carries NUL bytes (a UTF-16/32 save?) — read as not set"
  else
    if ! const_body="$(awk '
      NR == 1 && substr($0, 1, 3) == "\357\273\277" { $0 = substr($0, 4) }
      {
        raw[NR] = $0
        out = ""; rest = $0
        while (length(rest) > 0) {
          if (inc) {
            p = index(rest, "-->")
            if (p == 0) { rest = "" } else { rest = substr(rest, p + 3); inc = 0 }
          } else {
            p = index(rest, "<!--")
            if (p == 0) { out = out rest; rest = "" }
            else {
              out = out substr(rest, 1, p - 1)
              open_nr = NR; open_keep = out; open_rest = substr(rest, p)
              rest = substr(rest, p + 4); inc = 1
            }
          }
        }
        line[NR] = out
      }
      END {
        if (inc) {
          for (i = 1; i < open_nr; i++) print line[i]
          print open_keep open_rest
          for (i = open_nr + 1; i <= NR; i++) print raw[i]
        } else {
          for (i = 1; i <= NR; i++) print line[i]
        }
      }' "$const_file" 2>/dev/null)"; then
      const_body=""
      warn "constitution unreadable — read as not set"
    fi
    # Matched in the shell, never by grep: Git Bash 5.3.9 hangs a herestring
    # of 65,536 to about 65,700 bytes, and grep reading `< <(printf ...)`
    # reported a token that is not there in 43 of 1,800 calls under load.
    # The token pattern has no anchor, no dot and no negated class, so no
    # match can span a newline: matching the whole body equals matching it
    # line by line. Unquoted on the right of =~, which bash 3.2 needs.
    if [[ $const_body == *[![:space:]]* ]] \
       && ! [[ $const_body =~ $const_tokens ]]; then
      sk_const=true
    fi
  fi
fi

# --- git facts ---------------------------------------------------------------
# An override wins over everything, origin/HEAD included: it is the one way
# to branch from an integration branch in a repository whose remote
# publishes a different default. It reaches this script from the
# baseBranchOverride key or the --base-branch flag; this script cannot tell
# which, so it reports `override` and the orchestrator names the layer.
base=""; base_source=""
# origin/HEAD is trusted only while the branch it names exists: when the
# remote renames its default (master to main), `git fetch --prune` deletes
# origin/master and leaves origin/HEAD naming it, and a stale local master
# would become the base. Such an origin/HEAD is passed over, with a warning
# naming the fix, and the next source decides. One that names another
# remote's ref is not passed over: the refusal below names it.
oh=""
if [ -z "$base_override" ] && b="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)"; then
  case "$b" in
    refs/remotes/origin/?*) git show-ref --verify --quiet "$b" \
      || { warn "origin/HEAD points to a branch origin no longer has, so it is not read as the base; fix it with: git remote set-head origin -a"; b=""; } ;;
  esac
  oh="$b"
fi
if [ -n "$base_override" ]; then
  base="$base_override"; base_source="override"
elif [ -n "$oh" ]; then
  b="$oh"
  # The full ref, as for HEAD below: --short makes git choose an unambiguous
  # spelling, so with a ref named origin/main beside origin's own it printed
  # remotes/origin/main, and the old strip of `origin/` kept that as the
  # base; and it accepted an origin/HEAD pointing at another remote's branch
  # (measured, git 2.53.0). The message names no ref: the ref comes from the
  # repository.
  case "$b" in
    refs/remotes/origin/?*) base="${b#refs/remotes/origin/}" ;;
    *) die "origin/HEAD points to a ref that is not one of origin's branches, so the remote names no base branch; pass a base branch with the run's --base-branch flag" ;;
  esac
  base_source="origin/HEAD"
elif [ -n "$base_configured" ]; then
  base="$base_configured"; base_source="configured"
else
  base_source="current branch"
  # The base is the current checkout, and it must name a branch with a
  # commit, or B has nothing to cut the feature branch from. Exit statuses
  # alone decide, so git's own text is never read or printed: symbolic-ref
  # names the branch, with or without a commit, exits 1 when HEAD is
  # detached, and exits 128 when HEAD names a branch git cannot read;
  # `rev-parse --verify` exits 1 when HEAD has no commit. (`rev-parse
  # --abbrev-ref HEAD` prints HEAD in both states, and exits 0 when
  # detached.) With git not usable no read runs here: the base stays empty
  # and notRead names it.
  #
  # The FULL ref is read, never --short (feature 052, measured on git
  # 2.53.0): --short names whatever HEAD points to, so a HEAD pointing at
  # refs/tags/v1 or refs/remotes/origin/main gave `v1` or `origin/main` as
  # the base, and a branch with a tag of its name gave `heads/main`, git's
  # unambiguous spelling, which is no branch's name. A ref outside
  # refs/heads/ stops here, and the message names no ref: the ref comes
  # from the repository.
  if [ "$git_usable" = true ]; then
    rc=0; ref="$(git symbolic-ref --quiet HEAD 2>/dev/null)" || rc=$?
    case "$rc" in
      0) ;;
      1) die "HEAD is detached, so the current checkout names no base branch; check out a branch, or pass a base branch (the run's --base-branch flag, or the baseBranch key)" ;;
      *) die "HEAD names a branch git cannot read, so the current checkout names no base branch; run git status to see why" ;;
    esac
    case "$ref" in
      refs/heads/?*) base="${ref#refs/heads/}" ;;
      *) die "HEAD points to a ref that is not a local branch, so the current checkout names no base branch; check out a branch, or pass a base branch (the run's --base-branch flag, or the baseBranch key)" ;;
    esac
    git rev-parse --verify --quiet HEAD >/dev/null 2>&1 \
      || die "the current branch has no commit yet, so there is nothing to cut the feature branch from; make a first commit, or pass a base branch that has one (the run's --base-branch flag, or the baseBranch key)"
  fi
fi
# A base the run did not type comes from the repository, and a cloned
# remote names its own default branch, so it gets the override's name
# check: B types the name into commands. An override is checked where it
# is parsed; without a usable git nothing is checked, as for an override.
# Every source but the override is checked, a later one included, and the
# base must be usable as well as legal (base_usable).
if [ "$git_usable" = true ] && [ "$base_source" != override ]; then
  case "$base_source" in
    origin/HEAD) base_usable "$base" "origin/HEAD; pass a base branch with the run's --base-branch flag" ;;
    configured) base_usable "$base" "$base_label" ;;
    *) base_usable "$base" "the $base_source; check out another branch, or pass a base branch" ;;
  esac
fi
# notRead names each field of this report that holds a placeholder, not a
# fact, because git is not usable here: its git read did not run, or ran and
# failed (docs/configuration.md, "Fields the report did not read"). Each
# field marks itself where it is produced, so no second list of field names
# exists to drift from the fields (Principles IV and V). The guard lives in
# mark_not_read alone, so with a usable git the list is [] by construction.
# Names are fixed words without spaces, kept as one space-separated string:
# the final jq splits it, and no name costs a process.
not_read=''
mark_not_read() {
  [ "$git_usable" = true ] || not_read="$not_read $1"
}
# Only an override outranks origin/HEAD. A configured base is the fallback
# for a repository that publishes no origin/HEAD, and without git nobody
# looked, so it is a placeholder too; so is any base source added later.
case "$base_source" in
  override) ;;
  *) mark_not_read baseBranch; mark_not_read baseBranchSource ;;
esac
# B cuts the feature branch FROM the base. A feature branch with the base's
# own name is a run that commits straight onto its integration branch, and
# so is one that names it in another letter case, or as origin/<base>,
# heads/<base> or refs/heads/<base>.
if [ -n "$fb" ] && [ -n "$base" ]; then
  if awk -v f="$fb" -v b="$base" 'BEGIN {
        f = tolower(f); b = tolower(b)
        sub(/^refs\//, "", f); sub(/^(heads|remotes)\//, "", f); sub(/^origin\//, "", f)
        exit !(f == b) }'; then
    shown fb_s "$fb"; shown base_s "$base"
    die "'$fb_s' is the base branch '$base_s'; the feature branch needs its own name ($fb_arg)"
  fi
fi
if [ -n "$fb" ] && [ "$git_usable" = true ]; then
  hit="$(branch_like "$fb")"
  shown fb_s "$fb"; shown hit_s "$hit"
  [ -z "$hit" ] || die "'$fb_s' already exists as the branch '$hit_s', or collides with it as a folder; the feature branch needs a new name ($fb_arg)"
fi

# gh is probed under three names, first found wins, and the name is reported:
# a Windows package manager can install it as gh.cmd alone, which a bare `gh`
# lookup never finds, so probing one name read a working gh as absent.
gh_present=false; gh_command=""
for c in gh gh.exe gh.cmd; do
  if command -v "$c" >/dev/null 2>&1; then gh_present=true; gh_command="$c"; break; fi
done
# url_host <url> — sets rh to the URL's host in lowercase, or to nothing for
# a local path or a host that is not plain letters, digits, dots, dashes and
# underscores (an ssh alias may hold one), and rh_ssh to true when git reaches it over ssh. Three forms are read:
# scheme://[user@]host[:port]/path, and the scp-like [user@]host:path, which
# git takes when a colon comes before any slash. A one-letter host is a
# Windows drive (C:/repo). The plain-name rule keeps the host safe to hand
# to ssh and gh, and none starts with a dash, so neither reads an option.
url_host() {
  local h
  rh=""; rh_ssh=false
  case "$1" in
    ssh://*|git+ssh://*|ssh+git://*) rh_ssh=true; h="${1#*://}" ;;
    *://*) h="${1#*://}" ;;
    *:*) h="${1%%:*}"; rh_ssh=true
         case "$h" in */*) return 0 ;; esac ;;
    *) return 0 ;;
  esac
  h="${h%%/*}"; h="${h##*@}"; h="${h%%:*}"
  case "$h" in ?|-*|*[!A-Za-z0-9._-]*) return 0 ;; esac
  rh="$(printf '%s' "$h" | awk '{ print tolower($0) }')"
}
# The remote is GitHub when its host is github.com (ssh.github.com is its
# ssh-over-443 host), compared whole: a substring read a gitlab path holding
# github.com as GitHub, and GitHub.com as not. An ssh host may be an alias
# from the user's ssh configuration (git@gh-work:o/r for a second account):
# `ssh -G` prints what it resolves to, reading the configuration only, with
# canonicalization off so no name is looked up. Pre-flight runs no gh: a
# GitHub Enterprise host reads other, as before, and gh's own stored login
# was not used to tell it apart, since reading it can open a keychain prompt
# (macOS, not measured) and the README says pre-flight only looks gh up.
# No call here reaches the network.
remote="none"
if url="$(git remote get-url origin 2>/dev/null)"; then
  remote="other"
  url_host "$url"
  if [ -n "$rh" ] && [ "$rh_ssh" = true ] && command -v ssh >/dev/null 2>&1; then
    a="$(ssh -G -o CanonicalizeHostname=no -- "$rh" 2>/dev/null \
      | awk '$1 == "hostname" && !n { print tolower($2); n = 1 }')" || a=""
    case "$a" in ""|?|-*|*[!a-z0-9.-]*) ;; *) rh="$a" ;; esac
  fi
  case "$rh" in
    github.com|ssh.github.com) remote="github" ;;
  esac
fi
mark_not_read remote.kind
adb_present=false; command -v adb >/dev/null 2>&1 && adb_present=true

# A status read that fails is no answer about the tree: with a usable git
# it stops pre-flight, rather than read as clean. With git not usable the
# read cannot succeed, so it does not run, and notRead names the field.
#
# git status exits 0 and prints nothing for work the repository's own
# configuration hides (measured, git 2.53.0), so two flags on the command
# line, which beat the configuration, close two cases:
# --untracked-files=normal against status.showUntrackedFiles=no, and
# --ignore-submodules=none against submodule.<name>.ignore and
# diff.ignoreSubmodules. When the status is clean, a second read lists the
# index with `ls-files -v`, whose tag is a lowercase letter for a file
# marked assume-unchanged (-f, not -v, is the fsmonitor flag): git does not
# look at such a file, so nobody can say it is clean, and it counts as a
# change. Under core.ignoreStat git marks every file it writes so, and that
# repository always reads dirty: git cannot see a change there either. A
# warning says why, since git status shows nothing. The `:/` pathspec makes
# the listing cover the whole tree from any folder, as git status does;
# without it a run from a subfolder lists only that subfolder, and
# --no-literal-pathspecs keeps GIT_LITERAL_PATHSPECS in the environment from
# reading `:/` as a file name, which listed nothing. A file name holding a
# line feed is quoted, so every line starts with its tag. awk reads every
# line, so no reader that leaves early can kill git under pipefail
# (tests/pipefail.bats). Two cases stay unseen, documented as limits: a
# skip-worktree file (a sparse checkout marks clean files so) and a folder
# git cannot open (git only warns on stderr, which is never read).
# The run's own state directory at the top is never dirt: a user who declines
# the .gitignore offer keeps it untracked, and reading it as dirt stopped
# every later fresh run at decision 5. Only that one folder is left out, by
# the same `:/` and --no-literal-pathspecs reasons as the listing below;
# `.delivery-kit-notes` or a sub/.delivery-kit/ still count.
dirty=false
if [ "$git_usable" = true ]; then
  st="$(git --no-literal-pathspecs status --porcelain --untracked-files=normal --ignore-submodules=none -- ':/' ':(top,exclude).delivery-kit' 2>/dev/null)" \
    || die "the working tree's status could not be read: git status failed, so pre-flight cannot tell whether the tree is clean; run git status to see why"
  [ -z "$st" ] || dirty=true
  if [ "$dirty" = false ]; then
    au="$(git --no-literal-pathspecs ls-files -v -- ':/' 2>/dev/null | awk '/^[a-z] / { n++ } END { print n + 0 }')" \
      || die "the index could not be read: git ls-files failed, so pre-flight cannot tell whether the tree is clean; run git ls-files -v to see why"
    if [ "$au" != 0 ]; then
      dirty=true
      warn "tracked files marked assume-unchanged: $au; git does not look at them, so the tree is read as dirty (git ls-files -v shows each with a lowercase tag; core.ignoreStat marks every file so)"
    fi
  fi
fi
mark_not_read tree.dirty
# A run is live unless its phase is DONE or `progress.sh abandon` marked it
# (an abandoned value other than null or false): the rule progress.sh's
# RUN_END_JQ states, copied below because this script cannot source that
# one. Every live run is named, in liveRuns. A state file that is not one
# JSON object with a string current_phase — unreadable, empty, garbage —
# used to read as a live run, silently, for good: abandon cannot mark a
# file it cannot read. It is named in unreadableRuns, warned about, and not
# counted as live; resuming it fails at validate, which names the fault.
# The rule's text is the same line in both scripts, and a test holds the two
# copies equal. The answer is one word through command substitution, which
# drops jq's trailing CR, so no -b: jq 1.6 refuses -b off Windows. A run
# whose name starts with a dot is a run too, so the two dot globs read it.
RUN_END_JQ='if (.abandoned // false) != false then "abandoned" elif .current_phase == "DONE" then "done" else "live" end'
runs_live=false; live_runs='[]'; unreadable_runs='[]'
for s in .delivery-kit/runs/*/progress.json .delivery-kit/runs/.[!.]*/progress.json .delivery-kit/runs/..?*/progress.json; do
  [ -e "$s" ] || continue
  r="${s%/progress.json}"; r="${r##*/}"
  st="$(jq -r -s 'if length == 1 and (.[0] | type) == "object" and (.[0].current_phase | type) == "string"
    then .[0] | '"$RUN_END_JQ"'
    else "unreadable" end' "$s" 2>/dev/null)" || st=unreadable
  case "$st" in
    done|abandoned) ;;
    live) runs_live=true; live_runs="$(jq -n --argjson a "$live_runs" --arg r "$r" '$a + [$r]')" ;;
    *) shown run_s "$r"
       warn "the state file of run '$run_s' is not one JSON object with a current_phase — not counted as live; repair or remove .delivery-kit/runs/$run_s/progress.json"
       unreadable_runs="$(jq -n --argjson a "$unreadable_runs" --arg r "$r" '$a + [$r]')" ;;
  esac
done

# --- degradations, named before any work starts ------------------------------
skips='[]'
add_skip() {
  skips="$(jq -n --argjson s "$skips" --arg p "$1" --arg r "$2" '$s + [{phase: $p, reason: $r}]')"
}
# add_git_skip — a skip that follows from remote.kind, a git read: when that
# read is a placeholder, so is the skip's reason. Every skip of the remote
# branch takes it, the gh one included, since that branch is reached only
# through remote.kind.
add_git_skip() {
  add_skip "$1" "$2"
  mark_not_read "willSkip.$1"
}
if [ "$ptype" = "mobile-android" ] && [ "$adb_present" = false ]; then
  add_skip "N.5" "no adb on PATH — the device strategy cannot run"
fi
if [ "$remote" = "none" ]; then
  add_git_skip "L" "no git remote — the run stops after the commit gate and says so"
  add_git_skip "M" "no pull request without a remote"
elif [ "$remote" != "github" ]; then
  add_git_skip "M" "the remote is not GitHub — review needs a GitHub pull request"
elif [ "$gh_present" = false ]; then
  add_git_skip "M" "gh is absent — none of gh, gh.exe, gh.cmd is on PATH"
fi

printf '%s' "$trailers" | jq -s \
  --arg  ptype "$ptype" --arg ptype_source "$ptype_source" \
  --argjson sk_present "$sk_present" --arg sk_version "$sk_version" \
  --argjson sk_in_range "$sk_in_range" --arg sk_script "$sk_script" \
  --arg  sk_scripts_dir "$sk_scripts_dir" --arg sk_form "$sk_form" \
  --argjson sk_const "$sk_const" \
  --arg  base "$base" --arg base_source "$base_source" \
  --arg  feature_branch "$feature_branch" --arg spec_dir "$spec_dir" \
  --arg  remote "$remote" --argjson gh "$gh_present" --arg gh_command "$gh_command" \
  --argjson adb "$adb_present" \
  --argjson git "$git_present" --argjson git_usable "$git_usable" \
  --arg git_reason "$git_reason" --arg not_read "$not_read" \
  --argjson dirty "$dirty" --argjson runs_live "$runs_live" \
  --argjson live_runs "$live_runs" --argjson unreadable_runs "$unreadable_runs" \
  --argjson skips "$skips" '. as $trailers | {
  projectType: $ptype, projectTypeSource: $ptype_source,
  speckit: {
    present: $sk_present, version: $sk_version, versionInRange: $sk_in_range,
    script: $sk_script, scriptsDir: $sk_scripts_dir, invocationForm: $sk_form,
    constitutionSet: $sk_const
  },
  baseBranch: $base, baseBranchSource: $base_source,
  featureBranch: $feature_branch, specDir: $spec_dir,
  commitTrailers: $trailers,
  remote: { kind: $remote, ghPresent: $gh, ghCommand: $gh_command },
  capabilities: { jq: true, git: $git, gitUsable: $git_usable, gh: $gh, adb: $adb },
  gitReason: $git_reason,
  notRead: ($not_read | split(" ") | map(select(length > 0))),
  willSkip: $skips,
  tree: { dirty: $dirty, runsLive: $runs_live, liveRuns: $live_runs, unreadableRuns: $unreadable_runs }
}'
