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
# shown <name> <value> sets the named variable to a copy safe to print:
# under the C locale, cut to 200 bytes then ` [cut]`, with every byte that
# is not printable ASCII shown as `?`. The same shape as shown() in
# scripts/check-versions.sh. printf -v sets the copy without a process, and
# the value is never the format. Every refusal below prints a value only
# through one of these copies, each named here once.
shown() {
  local LC_ALL=C s=$2 c=
  [ "${#s}" -le 200 ] || { s=${s:0:200}; c=" [cut]"; }
  s=${s//[![:print:]]/?}
  printf -v "$1" '%s' "$s$c"
}
arg_s='' sd_s='' seg_s='' dir_s='' br_s='' ov_s='' fb_s='' p_s='' run_s='' base_s='' hit_s='' scr_s='' ver_s=''

command -v jq >/dev/null 2>&1 || die "jq is required and was not found on PATH"

# A commit trailer goes onto every commit the run makes, and commits leave
# the machine, so each one is checked here, in the order given, and named
# when refused. The rule itself lives in trailer-check.sh, beside this
# script: progress.sh runs the same file before every commit, so the two
# can never disagree. A trailer may come from the commitTrailers key or the
# --trailer flag; this script cannot tell which, so its errors name neither.
here="${BASH_SOURCE[0]}"
case "$here" in */*) here="${here%/*}" ;; *) here=. ;; esac
here="$(cd -P -- "$here" && pwd -P)" || die "cannot find the folder that holds preflight.sh"
add_trailer() {
  local t="$1" ok
  ok="$("$BASH" "$here/trailer-check.sh" "$(jq -jn --arg t "$t" '$t | tojson')" 2>&1 >/dev/null)" \
    || die "$ok (a commit trailer)"
  trailers="$(jq -n --argjson a "$trailers" --arg t "$t" '$a + [$t]')"
}

dir="."; ptype_override=""; base_configured=""; base_override=""
feature_branch=""; spec_dir=""; trailers='[]'
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)          dir="${2:?--dir needs a path}"; shift 2 ;;
    --project-type) ptype_override="${2:?--project-type needs a value}"; shift 2 ;;
    --base-branch)  base_configured="${2:?--base-branch needs a name}"; shift 2 ;;
    --base-branch-override) base_override="${2:?--base-branch-override needs a name}"; shift 2 ;;
    --feature-branch) feature_branch="${2:?--feature-branch needs a name}"; shift 2 ;;
    --spec-dir)     spec_dir="${2:?--spec-dir needs a path}"; shift 2 ;;
    --trailer)      add_trailer "${2:?--trailer needs a value}"; shift 2 ;;
    *) shown arg_s "$1"; die "unknown argument '$arg_s' (legal: --dir --project-type --base-branch --base-branch-override --feature-branch --spec-dir --trailer)" ;;
  esac
done
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
    case "$seg" in
      -*) die "'$sd_s' has the segment '$seg_s', which starts with a dash (--spec-dir)" ;;
      *[!A-Za-z0-9._-]*) die "'$sd_s' has the segment '$seg_s'; a folder name holds letters, digits, dot, dash, underscore only (--spec-dir)" ;;
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
# like @{-1} is never read from the caller's. Without git the run stops at
# decision 11 anyway, and the names are reported unchecked.
have_git=false; command -v git >/dev/null 2>&1 && have_git=true
# branch_ok <name> <argument> — git decides what a legal branch name is, and
# it must print the name back unchanged: @{-1} expands to another name, and
# a name it expands is not the name that was typed. A lone @ passes both
# (measured, git 2.43.0), and git even creates the branch, but in a revision
# @ means HEAD, so <base>..HEAD would read nothing: it is refused by name.
branch_ok() {
  local out
  shown br_s "$1"
  [ "$1" != @ ] || die "'@' is not a legal branch name here: git reads it as HEAD ($2)"
  out="$(git check-ref-format --branch "$1" 2>/dev/null)" && [ "$out" = "$1" ] \
    || die "'$br_s' is not a legal branch name ($2)"
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
# The override is what a person typed, or a key somebody wrote, for this
# run, so it is checked rather than trusted: a legal name, and a LOCAL
# branch. B runs `git checkout -b <feature> <base>` and later phases read
# `<base>..HEAD`; both fail on a name that exists only as origin/<base>
# (measured, git 2.43.0: rc 128), which is a fresh clone's usual state, so
# that case names the one command that fixes it. A tag, a commit id,
# origin/main or refs/heads/main is not a branch's name.
if [ -n "$base_override" ] && [ "$have_git" = true ]; then
  branch_ok "$base_override" --base-branch-override
  shown ov_s "$base_override"
  if ! git show-ref --verify --quiet "refs/heads/$base_override"; then
    if git show-ref --verify --quiet "refs/remotes/origin/$base_override"; then
      die "'$ov_s' exists only on origin; create the local branch first: git branch --track $ov_s origin/$ov_s (--base-branch-override)"
    fi
    die "'$ov_s' is not a branch here or on origin (--base-branch-override)"
  fi
  # A name that is a branch and a tag too: `git checkout -b` fails as
  # ambiguous, and <base>..HEAD reads the tag.
  if git show-ref --verify --quiet "refs/tags/$base_override"; then
    die "'$ov_s' is a tag as well as a branch; git would read the tag (--base-branch-override)"
  fi
fi
# The feature branch B will cut: --feature-branch, else the spec folder's
# last segment, which B names the branch after. It must be a legal name;
# below, once the base is known, it must also differ from the base and be
# new: `git checkout -b` refuses a name that exists, and on a file system
# that ignores case, one that differs only in letter case.
fb=""; fb_arg=""
if [ -n "$feature_branch" ]; then fb="$feature_branch"; fb_arg="--feature-branch"
elif [ -n "$spec_dir" ]; then fb="${spec_dir##*/}"; fb_arg="--spec-dir"; fi
if [ -n "$fb" ] && [ "$have_git" = true ]; then
  branch_ok "$fb" "$fb_arg"
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
  # Both are computed the same way, from here: git's --show-toplevel
  # spells a path its own way (C:/Users/... where Git Bash says /tmp), so
  # the top is reached by git's relative path back to it instead.
  real="$(cd -P -- "$p" && pwd -P)" || die "cannot enter '$p_s' (--spec-dir)"
  top="$(pwd -P)"
  if [ "$have_git" = true ] && t="$(git rev-parse --show-cdup 2>/dev/null)"; then
    top="$(cd -P -- "./$t" && pwd -P)" || top="$(pwd -P)"
  fi
  case "$real/" in
    "$top"/*) ;;
    *) die "'$sd_s' leads outside the repository, to $real (--spec-dir)" ;;
  esac
  case "$real/" in
    "$top"/.[Gg][Ii][Tt]/*|"$top"/.[Dd][Ee][Ll][Ii][Vv][Ee][Rr][Yy]-[Kk][Ii][Tt]/*)
      die "'$sd_s' leads into $real, git's or the run's own directory (--spec-dir)" ;;
  esac
  spec_run=".delivery-kit/runs/${spec_dir##*/}/progress.json"
  shown run_s "${spec_dir##*/}"
  [ ! -e "$spec_run" ] \
    || die "run name '$run_s' already has a state file, .delivery-kit/runs/$run_s/progress.json (--spec-dir)"
fi

# --- project type ----------------------------------------------------------
# pubspec.yaml + android/ is the mobile shape; a package.json whose
# dependencies or devDependencies name one of the four web toolchains is
# web; everything else is other. The override always wins, and the SOURCE
# is reported so a wrong guess is visible rather than silent.
ptype="other"; ptype_source="default"
if [ -f pubspec.yaml ] && [ -d android ]; then
  ptype="mobile-android"; ptype_source="pubspec.yaml + android/"
elif [ -f package.json ] && jq -e '
    ((.dependencies // {}) + (.devDependencies // {})) | keys
    | map(select(. == "next" or . == "vite" or . == "astro" or . == "react-scripts"))
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
  if head -c 4096 "$const_file" 2>/dev/null | od -An -tx1 | grep -q ' 00'; then
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
    # Fed through process substitution, never a herestring: Git Bash 5.3.9
    # hangs a herestring of 65,536 to about 65,700 bytes, and this body is
    # file-sized. printf's newline matches the one <<< appended. Its stderr
    # is dropped because grep -q may close the pipe early.
    if grep -q '[^[:space:]]' < <(printf '%s\n' "$const_body" 2>/dev/null) \
       && ! grep -qE "$const_tokens" < <(printf '%s\n' "$const_body" 2>/dev/null); then
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
if [ -n "$base_override" ]; then
  base="$base_override"; base_source="override"
elif b="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"; then
  base="${b#origin/}"; base_source="origin/HEAD"
elif [ -n "$base_configured" ]; then
  base="$base_configured"; base_source="configured"
else
  base="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"; base_source="current branch"
fi
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
if [ -n "$fb" ] && [ "$have_git" = true ]; then
  hit="$(branch_like "$fb")"
  shown fb_s "$fb"; shown hit_s "$hit"
  [ -z "$hit" ] || die "'$fb_s' already exists as the branch '$hit_s', or collides with it as a folder; the feature branch needs a new name ($fb_arg)"
fi

remote="none"
if url="$(git remote get-url origin 2>/dev/null)"; then
  case "$url" in *github.com*) remote="github" ;; *) remote="other" ;; esac
fi
# git sits beside gh and adb because the probe is the same, but its absence
# means something different in KIND. gh and adb each degrade one named phase.
# git degrades nothing, because phases B, K and L are git operations and this
# block's git reads — three above this line, and the working-tree read below it
# — quietly report an empty base branch and a clean tree without it. That
# silence is what this line exists to end. Reporting is still all this script
# does; the stop is the orchestrator's decision 11.
git_present=false; command -v git >/dev/null 2>&1 && git_present=true
# gh is probed under three names, first found wins, and the name is reported:
# a Windows package manager can install it as gh.cmd alone, which a bare `gh`
# lookup never finds, so probing one name read a working gh as absent.
gh_present=false; gh_command=""
for c in gh gh.exe gh.cmd; do
  if command -v "$c" >/dev/null 2>&1; then gh_present=true; gh_command="$c"; break; fi
done
adb_present=false; command -v adb >/dev/null 2>&1 && adb_present=true

dirty=false
[ -n "$(git status --porcelain 2>/dev/null || true)" ] && dirty=true
runs_live=false
for s in .delivery-kit/runs/*/progress.json; do
  [ -f "$s" ] || continue
  if [ "$(jq -r '.current_phase // empty' "$s" 2>/dev/null || true)" != "DONE" ]; then
    runs_live=true; break
  fi
done

# --- degradations, named before any work starts ------------------------------
skips='[]'
add_skip() {
  skips="$(jq -n --argjson s "$skips" --arg p "$1" --arg r "$2" '$s + [{phase: $p, reason: $r}]')"
}
if [ "$ptype" = "mobile-android" ] && [ "$adb_present" = false ]; then
  add_skip "N.5" "no adb on PATH — the device strategy cannot run"
fi
if [ "$remote" = "none" ]; then
  add_skip "L" "no git remote — the run stops after the commit gate and says so"
  add_skip "M" "no pull request without a remote"
elif [ "$remote" != "github" ]; then
  add_skip "M" "the remote is not GitHub — review needs a GitHub pull request"
elif [ "$gh_present" = false ]; then
  add_skip "M" "gh is absent — none of gh, gh.exe, gh.cmd is on PATH"
fi

jq -n \
  --arg  ptype "$ptype" --arg ptype_source "$ptype_source" \
  --argjson sk_present "$sk_present" --arg sk_version "$sk_version" \
  --argjson sk_in_range "$sk_in_range" --arg sk_script "$sk_script" \
  --arg  sk_scripts_dir "$sk_scripts_dir" --arg sk_form "$sk_form" \
  --argjson sk_const "$sk_const" \
  --arg  base "$base" --arg base_source "$base_source" \
  --arg  feature_branch "$feature_branch" --arg spec_dir "$spec_dir" \
  --argjson trailers "$trailers" \
  --arg  remote "$remote" --argjson gh "$gh_present" --arg gh_command "$gh_command" \
  --argjson adb "$adb_present" \
  --argjson git "$git_present" \
  --argjson dirty "$dirty" --argjson runs_live "$runs_live" \
  --argjson skips "$skips" '{
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
  capabilities: { jq: true, git: $git, gh: $gh, adb: $adb },
  willSkip: $skips,
  tree: { dirty: $dirty, runsLive: $runs_live }
}'
