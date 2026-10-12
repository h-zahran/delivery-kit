#!/usr/bin/env bash
# release.sh — the release edits for one plugin, made the same way every time.
#
#   bash scripts/release.sh <plugin> <version>
#
# Run from the repository root on a clean tree. It changes exactly three
# files, all for <plugin>:
#   - .claude-plugin/marketplace.json: that plugin's entry's "version";
#   - <plugin>/.claude-plugin/plugin.json: its "version";
#   - <plugin>/CHANGELOG.md: the `## [Unreleased]` heading becomes
#     `## [<version>] - <today>`.
# Then it runs scripts/check-versions.sh --released <plugin>, and keeps the
# edits only when that gate passes and reads the plugin as released. It never
# commits, tags or pushes: it prints those steps, and CONTRIBUTING.md gives
# the whole procedure.
#
# Every edit is made with awk, never jq: a jq round trip reformats
# marketplace.json (its one-line `tags` arrays become three lines each), and
# jq 1.6, which this repository supports, has no binary flag for Windows.
# Each edit refuses unless exactly one line changed, so a version written
# twice, or not at all, stops the release rather than half-making it. All
# three new files are prepared first and moved into place only when all three
# are right; a refusal after that copies the three originals back.
#
# Written for bash 3.2 as well as 5 (macOS may run the system bash), and for
# BSD as well as GNU awk: no mapfile, no gawk-only functions, no interval
# expressions. awk runs with BINMODE=3, which only gawk reads: Windows gawk
# otherwise drops a CR from every line it reads and writes. Messages name
# files relative to the root, never by an absolute path, which can carry a
# user name into a public log.
set -u
unset GREP_OPTIONS POSIXLY_CORRECT
set +o posix

die() { printf 'release.sh: %s\n' "$*" >&2; exit 1; }

[ $# -eq 2 ] || die "usage: release.sh <plugin> <version>, for example: release.sh pipeline 1.6.0"
plugin=$1
version=$2

# Where this script is, so the gate beside it is found from any copy of the
# tree the script is run on.
here="${BASH_SOURCE[0]}"
case "$here" in */*) here="${here%/*}" ;; *) here=. ;; esac
gate="$here/check-versions.sh"
[ -f "$gate" ] || die "scripts/check-versions.sh is not beside this script"

# --- refusals that change nothing -----------------------------------------

[ -f .claude-plugin/marketplace.json ] \
  || die "run from the repository root: no .claude-plugin/marketplace.json here"
cdup="$(git rev-parse --show-cdup 2>/dev/null)" || die "not inside a git repository"
[ -z "$cdup" ] || die "run from the top of the repository, not a subdirectory"
porcelain="$(git status --porcelain 2>/dev/null)" || die "git status failed"
[ -z "$porcelain" ] || die "the tree is not clean: commit or stash first (git status lists it)"

name_re='^[a-z][a-z0-9-]*$'
[[ $plugin =~ $name_re ]] || die "'$plugin' is not a plugin name"
manifest="$plugin/.claude-plugin/plugin.json"
changelog="$plugin/CHANGELOG.md"
market=.claude-plugin/marketplace.json
[ -f "$manifest" ] && [ -f "$changelog" ] || die "'$plugin' is not a plugin in this tree"

ver_re='^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$'
[[ $version =~ $ver_re ]] \
  || die "'$version' is not MAJOR.MINOR.PATCH (digits only, no leading zeros)"
new_major=${BASH_REMATCH[1]} new_minor=${BASH_REMATCH[2]} new_patch=${BASH_REMATCH[3]}
# Nine digits keep every field inside bash's arithmetic on every platform.
for f in "$new_major" "$new_minor" "$new_patch"; do
  [ "${#f}" -le 9 ] || die "'$version' has a field longer than nine digits"
done

# The current version: the one "version" line of the plugin's manifest.
# Compared as text after trimming, so no part of a version or a name is ever
# read as a pattern.
current="$(awk -v BINMODE=3 '
  { line = $0; sub(/\r$/, "", line); sub(/^[ \t]+/, "", line) }
  substr(line, 1, 12) == "\"version\": \"" { n++; v = substr(line, 13); sub(/",?$/, "", v) }
  END { if (n == 1) print v; else exit 1 }' "$manifest")" \
  || die "$manifest does not hold exactly one \"version\" line"
[[ $current =~ $ver_re ]] || die "$manifest's version '$current' is not MAJOR.MINOR.PATCH"
cur_major=${BASH_REMATCH[1]} cur_minor=${BASH_REMATCH[2]} cur_patch=${BASH_REMATCH[3]}
for f in "$cur_major" "$cur_minor" "$cur_patch"; do
  [ "${#f}" -le 9 ] || die "$manifest's version '$current' has a field longer than nine digits"
done

# Higher, field by field and as numbers: as text, 1.10.0 sorts below 1.9.0.
higher=0
if [ "$new_major" -gt "$cur_major" ]; then higher=1
elif [ "$new_major" -eq "$cur_major" ]; then
  if [ "$new_minor" -gt "$cur_minor" ]; then higher=1
  elif [ "$new_minor" -eq "$cur_minor" ] && [ "$new_patch" -gt "$cur_patch" ]; then higher=1
  fi
fi
[ "$higher" -eq 1 ] || die "$version is not higher than $plugin's current version $current"

today="$(date +%Y-%m-%d)" || die "date failed"
date_re='^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$'
[[ $today =~ $date_re ]] || die "date printed '$today', not YYYY-MM-DD"

# --- prepare the three files, touching none of them ------------------------

tmpdir="$(mktemp -d 2>/dev/null)" || die "mktemp failed"
[ -n "$tmpdir" ] && [ -d "$tmpdir" ] || die "mktemp failed"
cleanup() { rm -rf -- "$tmpdir"; }
trap cleanup EXIT

# Each awk below writes the new file to $out and prints how many lines it
# changed; the caller refuses unless that is exactly 1. A line keeps its CR,
# if it had one, so the edit changes the version and nothing else.

# The marketplace: the "version" line inside the entry whose "name" is this
# plugin, and only while that entry is open (up to its closing brace). The
# whole entry is read, so a version line written twice in it counts 2 and is
# refused; an entry with none ends at its brace, so the next entry's line is
# never taken for it.
n="$(awk -v BINMODE=3 -v p="$plugin" -v cur="$current" -v new="$version" -v out="$tmpdir/market" '
  {
    raw = $0; cr = ""
    if (sub(/\r$/, "", raw)) cr = "\r"
    line = raw; sub(/^[ \t]+/, "", line)
    if (line == "\"name\": \"" p "\"," || line == "\"name\": \"" p "\"") inside = 1
    else if (inside && substr(line, 1, 1) == "}") inside = 0
    else if (inside && (line == "\"version\": \"" cur "\"," || line == "\"version\": \"" cur "\"")) {
      i = index(raw, cur)
      raw = substr(raw, 1, i - 1) new substr(raw, i + length(cur))
      n++
    }
    print raw cr > out
  }
  END { print n + 0 }' "$market")" || die "awk failed on $market"
[ "$n" = 1 ] || die "$market: expected to change 1 version line for '$plugin' at $current, changed $n"

n="$(awk -v BINMODE=3 -v cur="$current" -v new="$version" -v out="$tmpdir/manifest" '
  {
    raw = $0; cr = ""
    if (sub(/\r$/, "", raw)) cr = "\r"
    line = raw; sub(/^[ \t]+/, "", line)
    if (line == "\"version\": \"" cur "\"," || line == "\"version\": \"" cur "\"") {
      i = index(raw, cur)
      raw = substr(raw, 1, i - 1) new substr(raw, i + length(cur))
      n++
    }
    print raw cr > out
  }
  END { print n + 0 }' "$manifest")" || die "awk failed on $manifest"
[ "$n" = 1 ] || die "$manifest: expected to change 1 version line, changed $n"

# The changelog: exactly one `## [Unreleased]` heading, the first level-two
# heading in the file, with at least one line under it, before the next
# level-two heading, that is neither blank nor a `### ` group heading. Anything else is refused with its own reason.
n="$(awk -v BINMODE=3 -v head="## [$version] - $today" -v out="$tmpdir/changelog" '
  {
    raw = $0; cr = ""
    if (sub(/\r$/, "", raw)) cr = "\r"
    if (substr(raw, 1, 15) == "## [Unreleased]") {
      u++
      if (raw != "## [Unreleased]") bad = "an `## [Unreleased]` heading carries more text"
      else if (h2 > 0) bad = "`## [Unreleased]` is not the first level-two heading"
      else { raw = head; open = 1 }
      h2++
    } else if (substr(raw, 1, 3) == "## ") { h2++; open = 0 }
    else if (open && raw ~ /[^ \t]/ && substr(raw, 1, 4) != "### ") entries++
    print raw cr > out
  }
  END {
    if (u == 0) { print "no `## [Unreleased]` heading"; exit }
    if (u > 1) { print u " `## [Unreleased]` headings, not 1"; exit }
    if (bad != "") { print bad; exit }
    if (entries == 0) { print "nothing under `## [Unreleased]`"; exit }
    print 1
  }' "$changelog")" || die "awk failed on $changelog"
[ "$n" = 1 ] || die "$changelog: $n"

# --- write, gate, and restore on refusal -----------------------------------

# The originals are copied aside first and copied back on a refusal, byte for
# byte. Not `git checkout`: that writes the file as checkout would, which
# under core.autocrlf or a missing .gitattributes is not the file that was
# there.
if ! { cp -- "$market" "$tmpdir/market.orig" \
    && cp -- "$manifest" "$tmpdir/manifest.orig" \
    && cp -- "$changelog" "$tmpdir/changelog.orig"; }; then
  die "could not copy the three files aside; nothing was changed"
fi
restore() {
  if ! { cp -- "$tmpdir/market.orig" "$market" \
      && cp -- "$tmpdir/manifest.orig" "$manifest" \
      && cp -- "$tmpdir/changelog.orig" "$changelog"; }; then
    trap - EXIT
    printf 'release.sh: could not restore the files; their originals are kept in the directory mktemp made; or run: git checkout -- %s %s %s\n' \
      "$market" "$manifest" "$changelog" >&2
  fi
}

if ! { cp -- "$tmpdir/market" "$market" \
    && cp -- "$tmpdir/manifest" "$manifest" \
    && cp -- "$tmpdir/changelog" "$changelog"; }; then
  restore
  die "could not write the edited files; restored"
fi

# Only an explicit pass keeps the edits: the gate exits 0 AND prints this
# plugin's line with all three versions equal to the new one and the state
# released. An exit 0 without that line is a gate that judged nothing.
want="$plugin: plugin=$version marketplace=$version changelog=$version state=released"
if ! report="$("${BASH:-bash}" "$gate" --released "$plugin" 2>&1)"; then
  restore
  printf '%s\n' "$report" >&2
  die "scripts/check-versions.sh refused the release; the three files are restored"
fi
case $'\n'"$report"$'\n' in
  *$'\n'"$want"$'\n'*) ;;
  *)
    restore
    printf '%s\n' "$report" >&2
    die "scripts/check-versions.sh did not print '$want'; the three files are restored"
    ;;
esac

printf '%s\n' "$report"
cat <<EOF
release.sh: $plugin $current -> $version, dated $today. Nothing was committed,
tagged or pushed. Next:
  1. Read the change: git diff
  2. git add -- $market $manifest $changelog
     git commit -m "release: $plugin $version"
  3. Push a branch, open a pull request, wait for CI, merge it.
  4. git fetch origin, confirm origin/main is the release commit, then:
     git tag $plugin-v$version origin/main && git push origin $plugin-v$version
  5. In the tag's CI run, read the step "tag matches the manifest version"
     inside the version job: it must say success, not skipped.
EOF
