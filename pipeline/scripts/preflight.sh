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

command -v jq >/dev/null 2>&1 || die "jq is required and was not found on PATH"

# A commit trailer goes onto every commit the run makes, and commits leave
# the machine, so each one is checked here, in the order given, and named
# when refused. The shape is `<token>: <value>`, one line. Piece and Late
# are the run's own markers: its crash scans read those lines as records.
add_trailer() {
  local t="$1" token value
  case "$t" in *$'\n'*|*$'\r'*) die "'$t' holds a line break; a trailer is one line (--trailer)" ;; esac
  case "$t" in *:*) ;; *) die "'$t' has no ':'; write <token>: <value> (--trailer)" ;; esac
  token="${t%%:*}"; value="${t#*:}"
  case "$token" in ''|*[!A-Za-z0-9-]*) die "'$t' has the token '$token'; a token holds letters, digits and dash only (--trailer)" ;; esac
  case "$value" in *[![:space:]]*) ;; *) die "'$t' has an empty value (--trailer)" ;; esac
  case "$token" in
    [Pp][Ii][Ee][Cc][Ee]|[Ll][Aa][Tt][Ee]) die "'$t' uses the token '$token', reserved for the run's own markers (--trailer)" ;;
  esac
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
    *) die "unknown argument '$1' (legal: --dir --project-type --base-branch --base-branch-override --feature-branch --spec-dir --trailer)" ;;
  esac
done
# The override is what a person typed for this run, so it is checked here
# rather than trusted: git decides what a legal branch name is. Without git
# the run stops at decision 11 anyway, and the name is reported unchecked.
if [ -n "$base_override" ] && command -v git >/dev/null 2>&1 \
   && ! git check-ref-format --branch "$base_override" >/dev/null 2>&1; then
  die "'$base_override' is not a legal branch name (--base-branch-override)"
fi
# The feature branch's name, typed for this run, is checked the same way.
if [ -n "$feature_branch" ] && command -v git >/dev/null 2>&1 \
   && ! git check-ref-format --branch "$feature_branch" >/dev/null 2>&1; then
  die "'$feature_branch' is not a legal branch name (--feature-branch)"
fi
# The spec folder is handed to the spec tool, which creates it and writes
# into it, and its last segment becomes the run's name under
# .delivery-kit/runs/. So it must be one relative spelling inside the
# repository, outside the state directory, ending in a name progress.sh
# accepts. One check per way a path can break that, each naming the value.
if [ -n "$spec_dir" ]; then
  case "$spec_dir" in
    /*|[A-Za-z]:*) die "'$spec_dir' is not relative to the repository root (--spec-dir)" ;;
    *\\*)          die "'$spec_dir' holds a backslash; separate folders with / (--spec-dir)" ;;
  esac
  spec_dir="${spec_dir%/}"
  case "/$spec_dir/" in
    */../*)        die "'$spec_dir' climbs out with .. (--spec-dir)" ;;
    */./*|*//*)    die "'$spec_dir' has an empty or . segment; write each path one way (--spec-dir)" ;;
    /.delivery-kit/*) die "'$spec_dir' is inside the state directory .delivery-kit/ (--spec-dir)" ;;
  esac
  case "${spec_dir##*/}" in
    *[!A-Za-z0-9._-]*) die "'$spec_dir' ends in '${spec_dir##*/}'; a run name holds letters, digits, dot, dash, underscore only (--spec-dir)" ;;
  esac
fi
cd "$dir" 2>/dev/null || die "cannot enter '$dir'"
# Checked inside the repository. A fresh run's folder must not exist: the
# spec tool would write over that feature's spec. And its run name must
# not have a state file: progress.sh init keeps an existing one, so the
# new run would silently continue the old one.
if [ -n "$spec_dir" ]; then
  [ ! -e "$spec_dir" ] || die "'$spec_dir' already exists (--spec-dir)"
  spec_run=".delivery-kit/runs/${spec_dir##*/}/progress.json"
  [ ! -e "$spec_run" ] \
    || die "run name '${spec_dir##*/}' already has a state file, $spec_run (--spec-dir)"
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
    *)  warn "version $sk_version is outside the tested range (0.15.x through 0.16.x) — continuing; untested is not known-broken" ;;
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
    *)  die "illegal script flavour '$sk_script' in .specify/init-options.json (legal: sh|ps|py)" ;;
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
# own name is a run that commits straight onto its integration branch.
if [ -n "$feature_branch" ] && [ "$feature_branch" = "$base" ]; then
  die "'$feature_branch' is the base branch; the feature branch needs its own name (--feature-branch)"
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
