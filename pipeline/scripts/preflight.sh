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

dir="."; ptype_override=""; base_configured=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)          dir="${2:?--dir needs a path}"; shift 2 ;;
    --project-type) ptype_override="${2:?--project-type needs a value}"; shift 2 ;;
    --base-branch)  base_configured="${2:?--base-branch needs a name}"; shift 2 ;;
    *) die "unknown argument '$1' (legal: --dir --project-type --base-branch)" ;;
  esac
done
cd "$dir" 2>/dev/null || die "cannot enter '$dir'"

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
  case "$sk_version" in
    0.15.*|0.16.*) sk_in_range=true ;;
    "") warn "no version recorded in .specify/init-options.json" ;;
    *)  warn "version $sk_version is outside the tested range (0.15.x-0.16.x) — continuing; untested is not known-broken" ;;
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
    if grep -q '[^[:space:]]' <<<"$const_body" \
       && ! grep -qE "$const_tokens" <<<"$const_body"; then
      sk_const=true
    fi
  fi
fi

# --- git facts ---------------------------------------------------------------
base=""; base_source=""
if b="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"; then
  base="${b#origin/}"; base_source="origin/HEAD"
elif [ -n "$base_configured" ]; then
  base="$base_configured"; base_source="configured"
else
  base="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"; base_source="current branch"
fi

remote="none"
if url="$(git remote get-url origin 2>/dev/null)"; then
  case "$url" in *github.com*) remote="github" ;; *) remote="other" ;; esac
fi
# git sits beside gh and adb because the probe is the same, but its absence
# means something different in KIND. gh and adb each degrade one named phase.
# git degrades nothing, because phases B, K and L are git operations and the
# four git reads in this block quietly report an empty base branch and a clean
# tree without it — that silence is what this line exists to end. Reporting is
# still all this script does; the stop is the orchestrator's decision 11.
git_present=false; command -v git >/dev/null 2>&1 && git_present=true
gh_present=false; command -v gh >/dev/null 2>&1 && gh_present=true
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
elif [ "$remote" != "github" ] || [ "$gh_present" = false ]; then
  add_skip "M" "review needs a GitHub pull request and gh"
fi

jq -n \
  --arg  ptype "$ptype" --arg ptype_source "$ptype_source" \
  --argjson sk_present "$sk_present" --arg sk_version "$sk_version" \
  --argjson sk_in_range "$sk_in_range" --arg sk_script "$sk_script" \
  --arg  sk_scripts_dir "$sk_scripts_dir" --arg sk_form "$sk_form" \
  --argjson sk_const "$sk_const" \
  --arg  base "$base" --arg base_source "$base_source" \
  --arg  remote "$remote" --argjson gh "$gh_present" --argjson adb "$adb_present" \
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
  remote: { kind: $remote, ghPresent: $gh },
  capabilities: { jq: true, git: $git, gh: $gh, adb: $adb },
  willSkip: $skips,
  tree: { dirty: $dirty, runsLive: $runs_live }
}'
