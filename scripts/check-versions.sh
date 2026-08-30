#!/usr/bin/env bash
# check-versions.sh — every plugin's manifest, marketplace entry and changelog
# agree. ONE implementation, TWO callers: the suite gate in
# tests/portability.bats and the version job in .github/workflows/ci.yml.
#
# This file exists because those two callers used to hold two copies of this
# logic. They were kept in step by hand, they drifted once — an unanchored
# regex in one accepted a heading the other rejected — and the drift was
# invisible until a release. A comment asking maintainers to edit the pair
# together is exactly what was there when it drifted. One implementation is
# the only arrangement that cannot drift, and a test in the suite pins that
# both callers name this file, so a hand-written copy cannot quietly return.
#
# Run from the repository root. The script refuses to run anywhere else rather
# than guessing a root or walking upward looking for one: two callers start in
# two places, and a script that silently examines the wrong tree reports a
# clean result in the voice of a verdict. Resolution belongs to the caller
# that has the context — the suite resolves its root and cd's there, CI runs
# at the workspace root by construction — and the assertion belongs here,
# where the two meet. Writing a second root resolver in this file would hand-
# copy the one in tests/helper.bash, which is the defect this file exists to
# end, arriving by a different door.
#
# jq here may be a native Windows binary whose stdout is text mode, so every
# line it prints ends CRLF. Command substitution strips that trailing CR;
# `read` does not. The reverse walk below reads jq line by line and strips it
# explicitly — measured in this repository's suite, where without the strip
# every lookup returned empty and a clean tree failed on one platform only.
set -euo pipefail

# GREP_OPTIONS is honoured by older greps and would rewrite the three `grep -E`
# calls below out from under them. Unset for the same reason preflight.sh and
# progress.sh do: a gate whose behaviour depends on the caller's environment is
# not a gate. CDPATH needs no such guard here — this script never cd's.
unset GREP_OPTIONS

# One exit helper, prefixed with the script name, matching the house pattern in
# pipeline/scripts/preflight.sh and pipeline/scripts/progress.sh. There were
# briefly two — one prefixed for preconditions, one bare for check findings —
# and nothing in the file said which to use. Two ways to exit with no stated
# rule is how a maintainer picks the wrong one, and the bare messages were the
# ones that actually reach a CI log without naming what emitted them.
die() { printf 'check-versions.sh: %s\n' "$*" >&2; exit 1; }

# Both spellings a relative source can take resolve to the same directory, so
# normalise before comparing: what is asserted is WHICH directory is named, not
# how it was written. One function, called from both walks. Writing this rule
# out twice — in the file whose header explains why a hand-kept pair is the
# defect — would be the same mistake one level down.
norm_source() { local s="${1#./}"; printf '%s' "${s%/}"; }

# The working directory IS the contract. Assert it before reading anything, so
# a caller that starts somewhere unexpected gets a named refusal instead of a
# walk over zero plugins that passes having verified nothing.
# The path is NOT printed. This message can reach a public issue when a
# contributor pastes a failing local run, and an absolute checkout path
# carries a username. The source-level path scan cannot see a value built
# at run time, so the discipline has to live here.
[ -f .claude-plugin/marketplace.json ] \
  || die "run me from the repository root — the working directory holds no .claude-plugin/marketplace.json"

command -v jq >/dev/null 2>&1 || die "jq is required and was not found on PATH"

# Loop over plugin directories rather than naming one. A gate that knows a
# single plugin's name stops covering the repository the moment a second
# plugin lands, and does so silently.
checked=0
for dir in */; do
  p="${dir%/}"
  # The ./ prefix here, and the -- on the changelog grep below: a tracked
  # directory named like an option (-rf, say) would otherwise reach jq and
  # grep as an OPTION rather than as a path. Measured: today jq aborts the
  # script first under errexit, so the grep is unreachable — but it is
  # unreachable by an accident of statement order, and an accident is not a
  # guard. A fork pull request controls every tracked path name.
  [ -f "./$p/.claude-plugin/plugin.json" ] || continue
  checked=$((checked + 1))

  pn="$(jq -r '.name // empty' "./$p/.claude-plugin/plugin.json")"
  pv="$(jq -r '.version // empty' "./$p/.claude-plugin/plugin.json")"
  [ -n "$pn" ] || die "$p: plugin.json has no name"
  [ -n "$pv" ] || die "$p: plugin.json has no version"

  # The release-tag gate in ci.yml resolves a plugin FROM THE DIRECTORY NAME —
  # it strips the version suffix from the tag and reads
  # <plugin>/.claude-plugin/plugin.json — while this loop resolves the
  # marketplace entry from the manifest's .name. Nothing else holds those two
  # identities together: a manifest renamed without its directory left every
  # gate green while release tags silently stopped naming the plugin.
  [ "$pn" = "$p" ] || die "$p: plugin.json name '$pn' does not match its directory"

  # Select by name, never by position. A second plugin prepended to the array
  # would otherwise be compared against the wrong entry — and could agree with
  # it by accident.
  #
  # These three queries are deliberately NOT collapsed into one. They carry
  # three different diagnostics for three different defects — no entry, an
  # entry with no version, an entry with no source — each of which has a
  # separate fix and each of which has happened. One combined query would
  # recover which absence occurred by splitting sentinel fields, and the
  # comments below would then describe a mechanism the code no longer had.
  # The saving was measured at two process spawns per plugin. Clarity wins.
  #
  # Existence and the version key are two different absences with two different
  # fixes, so they get two different messages. Without `// empty`, jq prints the
  # literal string "null" for a present entry missing the key, which passes a
  # non-empty test and sends the maintainer diffing two version numbers when one
  # of them does not exist.
  jq -e --arg n "$pn" '.plugins[] | select(.name == $n)' .claude-plugin/marketplace.json > /dev/null \
    || die "$p: no marketplace entry named $pn"
  mv="$(jq -r --arg n "$pn" '.plugins[] | select(.name == $n) | .version // empty' .claude-plugin/marketplace.json)"
  [ -n "$mv" ] || die "$p: marketplace entry $pn has no version"

  # And the entry must point AT the directory this iteration just read. Nothing
  # else in the repository reads `source` — no other test, no workflow — and it
  # is the field the installer follows to find the manifest, so an entry naming
  # the wrong directory is a broken install that every other check here calls
  # agreement. That is not hypothetical: `source` said "./", a directory holding
  # no plugin manifest, from the commit that moved the plugin into its own
  # directory until the commit that renamed it, and the whole suite was green
  # for the duration.
  ms="$(jq -r --arg n "$pn" '.plugins[] | select(.name == $n) | .source // empty' .claude-plugin/marketplace.json)"
  [ -n "$ms" ] || die "$p: marketplace entry $pn has no source"
  src="$(norm_source "$ms")"
  [ "$src" = "$p" ] || die "$p: marketplace entry $pn has source '$ms', which does not resolve to $p"

  # The heading format is pinned precisely because this line parses it, so
  # assert the date half too rather than trusting it to stay. Be exact about
  # what that buys: -m1 takes the first heading that MATCHES, so when the newest
  # heading has drifted and the older ones have not, this reads an older
  # release's version and the drift surfaces as a version disagreement rather
  # than as a complaint about the format. Measured, not assumed.
  #
  # Anchored with a trailing $ deliberately: an unanchored match accepted a
  # heading carrying a trailing parenthetical in one of the two copies this file
  # replaces while the other refused it. That divergence is the drift this file
  # exists to end.
  #
  # The `|| true` is load bearing. This script runs under errexit, so a failing
  # command substitution in an assignment aborts AT THIS LINE and the named
  # diagnostic below never runs — a missing changelog would die with grep's own
  # "No such file or directory" and name no format, and a file whose only
  # heading has drifted would die with no output at all, which is exactly the
  # case the diagnostic exists for. It cannot mask a real failure: an empty head
  # is rejected on the next line.
  head="$(grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' -- "./$p/CHANGELOG.md" || true)"
  [ -n "$head" ] || die "$p: no changelog heading in the pinned '## [X.Y.Z] - YYYY-MM-DD' format"
  cv="$(printf '%s' "$head" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"

  # Print what was read before comparing it. In a workflow log this line is the
  # difference between a red that explains itself and a red that sends someone
  # to open three files.
  # Line breaks are stripped before printing. jq emits a value raw, a version
  # or a directory name may hold a newline, and this line lands in a public
  # workflow log where a forged extra line would misreport what the gate
  # found. The comparisons below read the UNSTRIPPED values, so the strip
  # cleans the report and hides nothing from the check.
  printf '%s: plugin=%s marketplace=%s changelog=%s\n' \
    "${p//[$'\n\r']/}" "${pv//[$'\n\r']/}" "${mv//[$'\n\r']/}" "${cv//[$'\n\r']/}"

  # Name the values on failure. A bare exit status tells you the versions
  # disagree but not which file is the odd one out — and not which plugin.
  [ "$pv" = "$mv" ] || die "$p: plugin=$pv marketplace=$mv"
  [ "$pv" = "$cv" ] || die "$p: plugin=$pv changelog=$cv"
done

# The loop above walks directory -> entry, so an entry whose directory is
# missing is never visited: a retired plugin's leftover entry, or an entry added
# ahead of its directory — the exact ordering hazard of landing a second plugin
# — advertises a broken install while every check above calls it agreement. Walk
# the other direction too, and pin the two counts to each other so the walks
# cannot quietly cover different sets.
#
# One jq for the whole walk, emitting name and source together. The earlier
# shape read the names, then re-queried this same file once per name to fetch
# the source of the entry it had just read — looking an entry up by a value
# taken from that entry. The CR the note at the top of this file describes
# lands on the LAST field of the line, so the strip moves with it.
entries=0
while IFS=$'\t' read -r en es; do
  es="${es%$'\r'}"
  entries=$((entries + 1))
  ed="$(norm_source "$es")"
  # Refuse an absolute or traversing source before it reaches the filesystem.
  # The forward walk constrains its own source by comparing it against the
  # directory being iterated; this walk has nothing to compare against, so it
  # states the rule instead of stat-ing outside the tree and reading the miss
  # as an answer.
  case "$ed" in
    /*|*..*) die "marketplace entry '$en': source '$es' leaves the repository" ;;
  esac
  [ -n "$ed" ] && [ -f "./$ed/.claude-plugin/plugin.json" ] \
    || die "marketplace entry '$en': source '$es' names no plugin directory"
done < <(jq -r '.plugins[] | [.name, (.source // "")] | @tsv' .claude-plugin/marketplace.json)

[ "$entries" -eq "$checked" ] || die "marketplace lists $entries plugins, the tree holds $checked"

# A loop over zero plugins passes vacuously, having verified nothing. That is
# the defect this repository keeps rediscovering, and it is why the count above
# is compared rather than trusted. Pin that this walk found work to do.
# The working directory is not printed here either, for the reason given at
# the refusal above.
[ "$checked" -ge 1 ] || die "no plugin directories found in the working directory"
