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

# GREP_OPTIONS is honoured by older greps and would rewrite every `grep` call
# below out from under it. Unset for the same reason preflight.sh and
# progress.sh do: a gate whose behaviour depends on the caller's environment is
# not a gate. CDPATH needs no such guard here — this script never cd's.
unset GREP_OPTIONS
# POSIXLY_CORRECT, for the same reason: in its environment bash runs in POSIX
# mode, where a failed redirect on `:` ends the script before its own message,
# and GNU grep reads the `--` after a pattern as a file name (measured: a
# grep error, and a raw path in the report line). Unsetting it turns bash's
# POSIX mode off and keeps it from every program run below; set +o posix
# covers a bash started in that mode another way.
unset POSIXLY_CORRECT
set +o posix

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
norm_source() {
  local s="$1"
  # Collapse doubled separators FIRST, then strip leading current-directory
  # prefixes, then trailing separators — in that order, and each repeatedly.
  # A single pass of each was not enough: ".//handoff" survived as "/handoff",
  # which then tripped the absolute-path guard in the reverse walk and was
  # reported as escaping the repository. Every spelling here names the same
  # directory, which is what this function exists to say.
  while [ "$s" != "${s//\/\//\/}" ]; do s="${s//\/\//\/}"; done
  while [ "$s" != "${s#./}" ]; do s="${s#./}"; done
  while [ "$s" != "${s%/}" ]; do s="${s%/}"; done
  printf '%s' "$s"
}

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

# A value the gate did not write, read from a tracked file or the command
# line, is printed only through shown, which stores a copy safe to print in
# the variable it is named: cut to quote_cut bytes, then ` [cut]`, with every
# byte that is not printable ASCII shown as `?`. A line feed is masked, not
# dropped, so no value can start a line of its own in a workflow log, which
# reads a line starting `::` as a command. Under the C locale, so a byte
# that is not valid text in any encoding is masked too: under a UTF-8 locale
# a lone 0x9b, a bare terminal control, passed a printable test unmasked.
# Cut first, then masked: under the C locale a byte masks to one byte, so
# the order changes nothing printed, and masking a long value whole cost
# time that grew with the square of its length. printf -v sets the copy
# without a process, and the value is never the format: it may hold `%`.
# The gate's own text never passes through shown, or its em dash would be
# masked too. Every copy is named here once, so a reader can see them all.
quote_cut=200
p_s='' pr_s='' pn_s='' pv_s='' mv_s='' cv_s='' ms_s='' head_s='' first_s='' en_s='' es_s='' rel_s='' arg_s=''
shown() {
  local LC_ALL=C s=$2 t=
  [ "${#s}" -le "$quote_cut" ] || { s=${s:0:$quote_cut}; t=" [cut]"; }
  printf -v "$1" '%s' "${s//[![:print:]]/?}$t"
}

# --released <plugin> additionally requires that plugin's changelog to carry NO
# heading above its version heading, and no line beginning `## ` anywhere in
# the file that is not a dated version heading. Default (no argument)
# behaviour is unchanged: every run REPORTS the state (the heading-above
# part only; the rest is judged under --released alone), no run FAILS on it.
# Unreleased work is the normal condition of this repository; only a release
# tag asserts otherwise, and only for the plugin being released — tagging
# pipeline says nothing about whether handoff has unreleased work.
RELEASED=""
while [ $# -gt 0 ]; do
  case "$1" in
    --released)
      [ $# -ge 2 ] || die "--released needs a plugin name"
      RELEASED="$2"; shift 2 ;;
    *) shown arg_s "$1"; die "unknown argument '$arg_s' (usage: check-versions.sh [--released <plugin>])" ;;
  esac
done
# A plugin name that matches nothing would make the enforcement below run zero
# times and the script exit 0 — the caller asking for a stricter check and
# getting a weaker one, silently. Refuse rather than pass vacuously.
released_seen=0

# The pinned changelog heading, written ONCE. Both readers below use it: the
# version read (grep) and the release form's whole-file rule (awk). Two copies
# of this pattern drifting apart is the defect this file was written to end,
# so neither reader carries its own. Bracket forms instead of backslashes and
# repetitions spelled out instead of {4}: the same text means the same thing
# to grep -E and to every awk, including one without interval expressions.
dated_re='^## [[][0-9]+[.][0-9]+[.][0-9]+[]] - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$'

# The release form judges no line longer than line_limit bytes. It is written
# once and reaches awk through the environment, as the pattern and quote_cut
# do, so the two places that quote a line, shown() above and the walk's
# show(), cut at the same length. A long line is refused rather than read:
# the walk's cost grows much faster than the line, and every refusal lands
# in a public CI log.
line_limit=1000

# The release form reads the whole changelog of the plugin it releases, line
# by line, and that cost grows with the file, so it refuses a changelog
# larger than changelog_limit bytes before reading any of it. Written once.
# The default form only searches the file and never refuses for its size.
changelog_limit=262144

# Loop over plugin directories rather than naming one. A gate that knows a
# single plugin's name stops covering the repository the moment a second
# plugin lands, and does so silently.
checked=0
for dir in */; do
  p="${dir%/}"
  # The ./ prefix here, and the -- on the changelog greps below: a tracked
  # directory named like an option (-rf, say) would otherwise reach grep as
  # an OPTION rather than as a path, and one named like name=value would
  # reach awk as an assignment. A fork pull request controls every tracked
  # path name.
  [ -f "./$p/.claude-plugin/plugin.json" ] || continue
  checked=$((checked + 1))
  shown p_s "$p"

  # plugin.json reaches jq on standard input, never as a path: jq prints a
  # path it cannot open in its own error, raw, and native Windows jq cannot
  # open a path whose directory name holds `:` or a control byte at all.
  # The shell opens it instead, and a shell that cannot prints the path raw
  # too, so it is opened once first with that error discarded. Safe only
  # because the -f test above has refused anything that is not a regular
  # file: opening a pipe would wait for ever.
  { : < "./$p/.claude-plugin/plugin.json"; } 2>/dev/null \
    || die "$p_s: plugin.json could not be read"
  pn="$(jq -r '.name // empty' < "./$p/.claude-plugin/plugin.json")"
  pv="$(jq -r '.version // empty' < "./$p/.claude-plugin/plugin.json")"
  shown pn_s "$pn"
  shown pv_s "$pv"
  [ -n "$pn" ] || die "$p_s: plugin.json has no name"
  [ -n "$pv" ] || die "$p_s: plugin.json has no version"

  # The release-tag gate in ci.yml resolves a plugin FROM THE DIRECTORY NAME —
  # it strips the version suffix from the tag and reads
  # <plugin>/.claude-plugin/plugin.json — while this loop resolves the
  # marketplace entry from the manifest's .name. Nothing else holds those two
  # identities together: a manifest renamed without its directory left every
  # gate green while release tags silently stopped naming the plugin.
  [ "$pn" = "$p" ] || die "$p_s: plugin.json name '$pn_s' does not match its directory"

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
    || die "$p_s: no marketplace entry named $pn_s"
  mv="$(jq -r --arg n "$pn" '.plugins[] | select(.name == $n) | .version // empty' .claude-plugin/marketplace.json)"
  shown mv_s "$mv"
  [ -n "$mv" ] || die "$p_s: marketplace entry $pn_s has no version"

  # And the entry must point AT the directory this iteration just read. Nothing
  # else in the repository reads `source` — no other test, no workflow — and it
  # is the field the installer follows to find the manifest, so an entry naming
  # the wrong directory is a broken install that every other check here calls
  # agreement. That is not hypothetical: `source` said "./", a directory holding
  # no plugin manifest, from the commit that moved the plugin into its own
  # directory until the commit that renamed it, and the whole suite was green
  # for the duration.
  ms="$(jq -r --arg n "$pn" '.plugins[] | select(.name == $n) | .source // empty' .claude-plugin/marketplace.json)"
  shown ms_s "$ms"
  [ -n "$ms" ] || die "$p_s: marketplace entry $pn_s has no source"
  src="$(norm_source "$ms")"
  [ "$src" = "$p" ] || die "$p_s: marketplace entry $pn_s has source '$ms_s', which does not resolve to $p_s"

  # A NUL byte makes grep call the changelog binary: the version read below
  # then finds no version, and errexit ends the run with no message at all.
  # Name it instead, in both forms. Counted with tr, before any grep or awk
  # reads the file, because what an awk does with a NUL differs between the
  # awks CI runs; tr under the C locale, because macOS tr under a UTF-8
  # locale stops at a byte that is not valid text ("Illegal byte
  # sequence"), and the gate died with no message of its own. Not with
  # bash `read -d ''`, which starts no process but
  # reads one byte at a time: measured, 1.9 s on an 800 KB changelog against
  # 0.1 s for tr at any size. A missing changelog is left to the diagnostic
  # below.
  #
  # Only the plugin being released is said to leave the tree not released:
  # the default form asked no such question, and another plugin is not the
  # one being released. Set before the first refusal that reads it, so each
  # reads this plugin's suffix and never the one before.
  unreleased=""
  [ "$p" != "$RELEASED" ] || unreleased=" — this tree is NOT released"

  # Nothing reads the changelog unless it is a regular file of its own. A
  # test with -f follows a symbolic link, so a link to a device skipped the
  # NUL check and the search tools read the device: a link to /dev/urandom
  # ran until it was killed, naming nothing. Every link is refused, wherever
  # it points and a broken one too: judging a target is more code, and the
  # target can change after the check. A wrong refusal fails closed.
  [ ! -L "./$p/CHANGELOG.md" ] \
    || die "$p_s: CHANGELOG.md is a symbolic link, which the gate does not follow$unreleased"
  if [ -f "./$p/CHANGELOG.md" ]; then
    # The size before any read of the content, and only here: outside this
    # block a missing changelog would end the run on the shell's own error
    # under errexit, not on the diagnostic below. wc takes a regular file's
    # size from the file system (measured on Windows; the link check above
    # and this test send it nothing else). Arithmetic drops the spaces BSD
    # wc pads with. Opened once first, its error discarded: a shell that
    # cannot open the file prints the path raw. Safe only because the link
    # check and the -f test have refused a pipe, which would never open.
    { : < "./$p/CHANGELOG.md"; } 2>/dev/null \
      || die "$p_s: CHANGELOG.md could not be read$unreleased"
    if [ "$p" = "$RELEASED" ]; then
      size="$(LC_ALL=C wc -c < "./$p/CHANGELOG.md")" \
        || die "$p_s: CHANGELOG.md could not be read$unreleased"
      [ "$((size))" -le "$changelog_limit" ] \
        || die "$p_s: CHANGELOG.md is $((size)) bytes, more than the release form reads ($changelog_limit)$unreleased"
    fi
    nul="$(LC_ALL=C tr -cd '\000' < "./$p/CHANGELOG.md" | wc -c)" \
      || die "$p_s: CHANGELOG.md could not be read$unreleased"
    [ "$((nul))" -eq 0 ] \
      || die "$p_s: CHANGELOG.md holds a NUL byte, which the gate cannot read$unreleased"
  elif [ -e "./$p/CHANGELOG.md" ]; then
    die "$p_s: CHANGELOG.md is not a regular file$unreleased"
  fi

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
  # diagnostic below never runs — a missing changelog would die naming no
  # format, and a file whose only heading has drifted would die with no output
  # at all, which is exactly the case the diagnostic exists for. It cannot mask
  # a real failure: an empty head is rejected on the next line. grep's own
  # error is discarded for the same reason: the gate's line follows and says
  # what failed, and grep's would print the path raw, before it, in a public
  # log.
  #
  # Under the C locale, as every read of the file here: a byte that is not
  # valid text must never make a tool stop or call the file binary.
  head="$(LC_ALL=C grep -m1 -E -e "$dated_re" -- "./$p/CHANGELOG.md" 2>/dev/null || true)"
  [ -n "$head" ] || die "$p_s: no changelog heading in the pinned '## [X.Y.Z] - YYYY-MM-DD' format"
  cv="$(printf '%s' "$head" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  shown head_s "$head"
  shown cv_s "$cv"

  # Print what was read before comparing it. In a workflow log this line is the
  # difference between a red that explains itself and a red that sends someone
  # to open three files.
  # Every value is printed through its masked copy. jq emits a value raw, a
  # version or a directory name may hold a line feed, and this line lands in
  # a public workflow log where a forged extra line would misreport what the
  # gate found. The comparisons below read the raw values, so the masking
  # cleans the report and hides nothing from the check.
  # Is the version heading the FIRST heading, or does something sit above it?
  # The three comparisons in this loop are satisfied by ANY matching heading, so
  # an `## [Unreleased]` heading above the newest release is invisible to them —
  # `grep -m1` skips it rather than rejecting it, and reads the release below.
  # That blindness let both plugins carry an open heading through an entire
  # release cycle while this gate printed agreement. Reported on every run;
  # enforced only for the plugin named by --released, because unreleased work is
  # normal and correct everywhere else.
  #
  # Under the C locale: under a UTF-8 locale grep calls a line holding a byte
  # that is not valid text binary, and prints "Binary file ... matches" in
  # place of the heading it found.
  first="$(LC_ALL=C grep -m1 '^## ' -- "./$p/CHANGELOG.md" || true)"
  shown first_s "$first"
  if [ "$first" = "$head" ]; then
    released_state="released"
  else
    released_state="UNRELEASED-ABOVE:$first_s"
  fi
  # This is the one line that starts with a value, so its first field also
  # shows its leading spaces, and a `:` directly after them, as `?`: a
  # workflow log reads a command in a line that starts `::`, after any white
  # space. Every other line starts with the script's own name.
  pr_s=${p_s%%[! ]*}
  rest=${p_s#"$pr_s"}
  case $rest in :*) rest="?${rest#:}" ;; esac
  pr_s=${pr_s// /?}$rest
  printf '%s: plugin=%s marketplace=%s changelog=%s state=%s\n' \
    "$pr_s" "$pv_s" "$mv_s" "$cv_s" "$released_state"

  # Name the values on failure. A bare exit status tells you the versions
  # disagree but not which file is the odd one out — and not which plugin.
  [ "$pv" = "$mv" ] || die "$p_s: plugin=$pv_s marketplace=$mv_s"
  [ "$pv" = "$cv" ] || die "$p_s: plugin=$pv_s changelog=$cv_s"

  if [ "$p" = "$RELEASED" ]; then
    released_seen=1
    [ "$released_state" = "released" ] \
      || die "$p_s: '$first_s' sits above the released heading '$head_s' — this tree is NOT released"

    # The comparison above reads only the FIRST level-2 heading, so a heading
    # left lower in the file was invisible to it. A released changelog holds
    # dated version headings and nothing else at level two, so the whole file
    # is read, line by line, the way Markdown reads it, far enough to know
    # every level-2 heading: `##` after a tab, an indent or nothing at all;
    # a text line underlined with `-`; either one inside a quote or a list
    # item, or deep in a list item's continuation. A fence that never closes,
    # or whose end depends on a container, could hide one, so it is refused
    # too.
    #
    # The walk keeps, from line to line, an open fence (with the
    # text before its fence characters, which every line inside must carry),
    # whether a list item can be open, and the previous line. It does not
    # follow Markdown's every rule. Each place it cuts a corner, it cuts toward
    # refusing: a wrong refusal fails closed and the changelog is fixed, while
    # a wrong pass would ship an open heading in a release. So while any list
    # item can be open every deep `##` is judged, a `-` under any line that is
    # not blank is an underline, only a line of spaces is blank, and a fence
    # is followed only while its shape is clean.
    # specs/024-gate-every-heading-form/research.md R2 gives the steps.
    #
    # awk, not a `grep -v` pipeline: under pipefail a `grep -v` that selects
    # nothing exits 1, and the assignment would abort this script with no
    # message on exactly the input that is correct. awk exits 0 either way.
    # The pattern reaches awk through the environment, not -v, which would
    # process escapes in it. A quoted line comes from a tracked file and lands
    # in a public CI log, so every character that is not printable — a tab,
    # an escape sequence, a stray CR — is shown as `?`, and the walk runs
    # under the C locale for the reason shown() gives above. No interval
    # expressions: indents are counted, not matched.
    refusal="$(DATED_RE="$dated_re" LINE_LIMIT="$line_limit" QUOTE_CUT="$quote_cut" LC_ALL=C awk '
      function expand(s,   o, i, c, col) {
        if (index(s, "\t") == 0) return s
        o = ""; col = 0
        for (i = 1; i <= length(s); i++) {
          c = substr(s, i, 1)
          if (c == "\t") { do { o = o " "; col++ } while (col % 4 != 0) }
          else { o = o c; col++ }
        }
        return o
      }
      function lead(s,   i) { i = 1; while (substr(s, i, 1) == " ") i++; return i - 1 }
      function run(s, ch,   i) { i = 1; while (substr(s, i, 1) == ch) i++; return i - 1 }
      function rtrim(s) { sub(/ +$/, "", s); return s }
      function show(s,   t) {
        t = ""
        if (length(s) > cut) { s = substr(s, 1, cut); t = " [cut]" }
        gsub(/[^[:print:]]/, "?", s)
        return s t
      }
      function cont(s,   o, i) {
        o = ""
        for (i = 1; i <= length(s); i++) o = o (substr(s, i, 1) == ">" ? ">" : " ")
        return o
      }
      function atx(s,   k) { k = run(s, "#"); return k >= 1 && k <= 6 && (length(s) == k || substr(s, k + 1, 1) == " ") }
      function closer(s,   k) { k = run(s, fch); return k >= flen && substr(s, k + 1) ~ /^ *$/ }
      # One definition of a fence opener for every rule that asks: a
      # backtick opener holding a further backtick is text, not a fence.
      function opener(s,   c, k) {
        c = substr(s, 1, 1)
        if (c != "`" && c != "~") return 0
        k = run(s, c)
        return k >= 3 && !(c == "`" && index(substr(s, k + 1), "`"))
      }
      # One quote marker off the front: any indent, `>`, one optional space.
      function unquote(s) { s = substr(s, lead(s) + 2); if (substr(s, 1, 1) == " ") s = substr(s, 2); return s }
      function refuse(msg) { print msg; refused = 1; exit }
      # The digits a list marker starts with, counted, not matched.
      function digits(s,   i) { i = 1; while (substr(s, i, 1) ~ /[0-9]/) i++; return i - 1 }
      # An HTML block that only its own end marker closes: a comment, a
      # processing instruction, a declaration, CDATA, or script, pre, style
      # or textarea. Every other kind ends at a blank line.
      function hardhtml(s,   l) {
        l = tolower(s)
        return l ~ /^<[!?]/ || l ~ /^<(script|pre|style|textarea)/
      }
      BEGIN {
        prev = "blank"; LM = "^([-*+]|[0-9]+[.)])( |$)"
        limit = ENVIRON["LINE_LIMIT"] + 0; cut = ENVIRON["QUOTE_CUT"] + 0
      }
      {
        # A line too long to judge is refused before anything reads it, and
        # a CR is refused rather than split: Markdown reads a CR as a line
        # end, and a split line could be a heading or close a fence. Both
        # come before the fence rules, so a fence hides neither.
        if (length($0) > limit)
          refuse("line " NR " is " length($0) " bytes long, longer than the release form judges: \047" show($0) "\047")
        if (index($0, "\r"))
          refuse("line " NR " holds a carriage return, which Markdown reads as a line end: \047" show($0) "\047")

        # The ordered item on the line before, if the walk accepted it.
        pok = cok; pdel = cdel; ppre = cpre; cok = 0

        line = expand($0)
        # Only a line of spaces is blank. A line of `>` markers alone is
        # not: deep in a list item it is text, and calling it blank would
        # end the item and hide a deep heading below it.
        blank = (line ~ /^ *$/)

        # An open fence: every line inside must carry the opener prefix.
        # closer() needs a run of at least the opener length, so it also
        # proves the line starts with the fence character.
        if (fenced) {
          inpre = (substr(line, 1, length(fpre)) == fpre)
          body = substr(line, length(fpre) + 1)
          if (inpre && closer(body)) { fenced = 0; prev = "text"; praw = $0; pnr = NR; next }
          if (line ~ /^[ >]*$/) {
            if (rtrim(line) == rtrim(fpre)) next
          } else if (inpre && !closer(substr(body, lead(body) + 1))) next
          refuse("the code fence opened at line " fnr " may already have ended at line " NR ", which holds \047" show($0) "\047")
        }

        # Quote markers, then what is left of the line.
        t = line; depth = 0
        while (substr(t, lead(t) + 1, 1) == ">") { t = unquote(t); depth++ }
        ind = lead(t)
        text = substr(t, ind + 1)
        under = (text ~ /^-+ *$/)

        # An unindented line ends every list item: after a blank line, or
        # when it starts a heading or a fence. Straight after item text, a
        # plain line is a lazy continuation and does not.
        if (depth == 0 && ind == 0 && !blank && text !~ LM)
          if (prev == "blank" || atx(text) || opener(text)) listed = 0

        # A setext underline: the previous text line is a heading. Checked
        # before list markers come off: a bare `-` here is an underline.
        if (under && prev == "text")
          refuse("line " pnr " holds \047" show(praw) "\047, underlined at line " NR)

        # List markers and quote markers, in any order. After a text line
        # an ordered marker other than 1 does not start a list, so a fence
        # on it would not be a fence: such a marker sets odd, and odd
        # refuses the fence. One shape is let through (N1): the FIRST marker
        # on the line, of one to nine digits, after a blank line, or continuing
        # the ordered item on the line before (same text before the marker,
        # same delimiter). CommonMark takes at most nine digits.
        rest = text; marked = 0; odd = 0; first = ""
        while (1) {
          r = substr(rest, lead(rest) + 1)
          if (match(r, LM)) {
            m = substr(r, 1, RLENGTH)
            if (!marked && m ~ /^[0-9]/) {
              first = m; fdel = substr(m, digits(m) + 1, 1)
              fpfx = substr(line, 1, length(line) - length(r))
            }
            if (m ~ /^[0-9]/ && m !~ /^1[.)]/) {
              if (marked || digits(m) > 9) odd = 1
              else if (prev != "blank" && !(pok && pdel == fdel && ppre == fpfx)) odd = 1
            }
            rest = substr(r, RLENGTH + 1); marked = 1; continue
          }
          if (substr(r, 1, 1) == ">") { rest = unquote(r); continue }
          rest = r
          break
        }
        if (marked) listed = 1
        # This line is an accepted ordered item for the next line: its first
        # marker ordered, one to nine digits, the item not empty, not odd.
        if (first != "" && digits(first) <= 9 && rest !~ /^ *$/ && !odd) {
          cok = 1; cdel = fdel; cpre = fpfx
        }

        # A line that starts with `<` may open an HTML block, and a fence
        # line inside one is not a fence: it would hide what follows it.
        # Every `<` line is classified, whatever came before: a block that
        # only its own end marker closes (hard) refuses every fence opener
        # from here on; any other kind (soft) ends at a line of spaces (N2).
        if (blank) soft = 0
        if (substr(rest, 1, 1) == "<") {
          if (hardhtml(rest)) { hard = 1; hnr = NR } else { soft = 1; snr = NR }
        }

        # A fence opener, at any indent, unless Markdown might not open it.
        if (opener(rest) && odd)
          refuse("line " NR " opens a code fence on an ordered list marker other than 1, which may not start a list: \047" show($0) "\047")
        if (opener(rest) && (hard || soft))
          refuse("line " NR " opens a code fence that the HTML at line " (hard ? hnr : snr) " may hold: \047" show($0) "\047")
        if (opener(rest)) {
          fc = substr(rest, 1, 1)
          fenced = 1; fch = fc; flen = run(rest, fc)
          fpre = cont(substr(line, 1, length(line) - length(rest)))
          fnr = NR; ftext = $0; next
        }

        # Indented code, when no list item can be open to claim the line.
        if (ind >= 4 && !marked && !listed) { prev = "text"; praw = $0; pnr = NR; next }

        # An ATX level-2 heading, in any container.
        if (rest ~ /^##( |$)/ && $0 !~ ENVIRON["DATED_RE"])
          refuse("line " NR " holds \047" show($0) "\047, which is not a dated version heading")

        # Every line that is not blank counts as text for the underline
        # test, a fence closer and an underline included: a `-` run under
        # any of them is refused rather than read as a break. Two kinds are
        # let through. An ATX heading with no container and at most three
        # columns of indent, while no list item can be open, is a heading
        # wherever it stands (N3). A line of `>` marks starting at column
        # zero, with at most one space between two marks, is a blank line
        # inside a quote, which ends any paragraph (N4). A wider gap is not:
        # after five spaces a `>` is text that continues the paragraph, and
        # the run below it is an underline. Found at pull request review;
        # tabs are expanded before this test. Neither counts as blank for
        # any other rule.
        if (blank) prev = "blank"
        else if (depth == 0 && !marked && ind <= 3 && !listed && atx(text)) prev = "heading"
        else if (line ~ /^>( ?>)* *$/) prev = "qblank"
        else prev = "text"
        praw = $0; pnr = NR
      }
      END {
        if (fenced && !refused)
          print "line " fnr " opens a code fence that is never closed: \047" show(ftext) "\047"
      }
    ' "./$p/CHANGELOG.md")"
    [ -z "$refusal" ] \
      || die "$p_s: $refusal — this tree is NOT released"
  fi
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
#
# jq runs in its OWN statement, never in a process substitution feeding the
# loop. A process substitution's exit status is invisible to `set -e`: the shell
# waits for the loop, not for the producer. Measured, on a marketplace whose
# SECOND entry has an object where a name should be — jq emits the first line,
# errors on the second, and exits non-zero; the old shape read the one good line,
# set entries=1, matched checked=1, and exited 0 having never validated the bad
# entry's `source`, which pointed at a directory that did not exist. A leading
# malformed entry died correctly, so only trailing ones escaped. Assigning first
# puts the failure where errexit can see it. The loop is then fed by printf
# over the assigned text, which cannot fail, and not by a herestring: Git
# Bash hung, naming nothing, on a herestring of 65,536 to about 65,700 bytes
# (measured), a size a fork controls through one entry's name.
entries_tsv="$(jq -r '.plugins[] | [.name, (.source // "")] | @tsv' .claude-plugin/marketplace.json)"
# An empty result would make the loop below run zero times and pass vacuously.
# The count comparison further down would not catch it either when the tree
# holds no plugin directory — two zeroes agree.
[ -n "$entries_tsv" ] || die "the marketplace manifest lists no plugin entries at all"
entries=0
while IFS=$'\t' read -r en es; do
  es="${es%$'\r'}"
  entries=$((entries + 1))
  ed="$(norm_source "$es")"
  shown en_s "$en"
  shown es_s "$es"
  # Refuse an absolute or traversing source before it reaches the filesystem.
  # The forward walk constrains its own source by comparing it against the
  # directory being iterated; this walk has nothing to compare against, so it
  # states the rule instead of stat-ing outside the tree and reading the miss
  # as an answer.
  case "$ed" in
    /*) die "marketplace entry '$en_s': source '$es_s' is an absolute path" ;;
  esac
  # `..` as a PATH COMPONENT, not as a substring. `*..*` also matched a
  # directory legitimately named "my..plugin" and refused it while naming a
  # traversal that was not there — a wrong diagnostic is its own defect, even
  # when it fails in the safe direction.
  case "/$ed/" in
    */../*) die "marketplace entry '$en_s': source '$es_s' leaves the repository" ;;
  esac
  # Written as an `if`, not `A && B || C`. The chained form means the same
  # thing here, but it is the shape that silently does the wrong thing when B
  # can fail for a second reason, and CI's analyser reports it. WHICH analyser
  # matters, and this is measured rather than assumed: the runner image ships
  # 0.9.0, which reports this, while 0.11.0 does not. A contributor with a
  # newer local copy therefore sees FEWER findings than the gate does.
  if [ -z "$ed" ] || [ ! -f "./$ed/.claude-plugin/plugin.json" ]; then
    die "marketplace entry '$en_s': source '$es_s' names no plugin directory"
  fi
done < <(printf '%s\n' "$entries_tsv")

[ "$entries" -eq "$checked" ] || die "marketplace lists $entries plugins, the tree holds $checked"

# A loop over zero plugins passes vacuously, having verified nothing. That is
# the defect this repository keeps rediscovering, and it is why the count above
# is compared rather than trusted. Pin that this walk found work to do.
# The working directory is not printed here either, for the reason given at
# the refusal above.
[ "$checked" -ge 1 ] || die "no plugin directories found in the working directory"

# The stricter check must have actually run. Without this, `--released ghost`
# walks every plugin, matches none, enforces nothing and exits 0 — a caller
# asking for MORE checking and receiving LESS, which is the exact shape the
# refusal above and the count comparison before it both exist to prevent.
if [ -n "$RELEASED" ] && [ "$released_seen" -ne 1 ]; then
  shown rel_s "$RELEASED"
  die "--released named '$rel_s', which is not a plugin in this tree; nothing was enforced"
fi
