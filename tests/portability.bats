#!/usr/bin/env bats

# Guards against this project's most likely failure: leaking the codebase it
# was extracted from into the surface a stranger installs.

load helper

# Vocabulary from the originating project's stack, and tools that are not
# dependencies of this one. Extend this list rather than weakening a test.
#
# The originating project's own NAME is deliberately absent. Writing it here
# would publish, in the file whose whole purpose is to prevent that leak,
# exactly the string it exists to catch — a denylist that names its target
# defeats itself the moment the repository goes public. It lives instead in an
# optional git-ignored `.leakwords`, one term per line, which this scan folds
# in when present. Anyone with a private term to guard gets full coverage
# locally and in their own CI; the published list carries the stack and tooling
# names, which are the shapes a leak most often takes anyway.
BANNED_WORDS='flutter|dart|pubspec|supabase|gradle|graphify|speckit|superpowers'
if [ -f "$ROOT/.leakwords" ]; then
  # Blank lines are stripped before joining. An empty alternation branch would
  # match at every position, turning the scan into something that fires on
  # everything — loudly, since the tests assert "no match", but for a reason
  # that has nothing to do with a leak.
  extra="$(grep -v '^[[:space:]]*$' "$ROOT/.leakwords" | paste -sd'|' -)"
  [ -n "$extra" ] && BANNED_WORDS="$BANNED_WORDS|$extra"
fi
BANNED_PATHS='D:\\|/c/Users/|C:\\Users\\|~/\.claude/projects/[A-Za-z0-9-]'

# The real scan and the positive control at the bottom of this file must run
# one identical expression: a control that tests a different expression proves
# nothing about the scan. Keeping them in step by convention is a comment
# nobody diffs, so the alternation is assembled once, here, and both grep calls
# take it from this variable.
VOCAB_RE="($BANNED_WORDS)"

# Everything a stranger installs or reads, named file by file rather than by
# directory. Naming files costs something — a document added later and never
# registered here goes unscanned — and buys something better: a directory
# pattern silently widens to cover whatever is dropped into it, including
# working notes that were never meant to ship, and a scan that quietly grows
# new subjects is one nobody can reason about. The scans assert `-eq 1`, so a
# rename of something listed fails loudly rather than switching the scan off.
#
# Two lists rather than one, because the surface now spans two trees. R2 adds
# a third list with a shorter vocabulary for pipeline/skills and
# pipeline/scripts; see the design document, section 20. That list must arrive
# WITH the directories it describes and never ahead of them, because an empty
# one does not fail: `grep -r` given no path operand does not error, it
# defaults to the working directory. So an empty third list would not exit 2
# and redden — it would silently rescan the whole repository under the relaxed
# vocabulary that list exists to carry, and whatever it reported would say
# nothing about the surface it was meant to cover. Only a path that is named
# and MISSING exits 2, which is the case the `-eq 1` assertions below are
# written to catch.
#
# Registration follows the file, not the filename. The root `CHANGELOG.md` and
# `handoff/CHANGELOG.md` are two different documents on two different lists —
# the first an index, the second the plugin's release history — and the second
# is on this list because a file that moves between trees has to move between
# lists or the move silently narrows the scan. It moved out of the root in the
# same change that split it, and 16KB of release history — the largest block of
# prose these scans cover — would have left the scanned surface without a single
# test going red.
SHIPPED_ROOT="README.md CONTRIBUTING.md CHANGELOG.md CODE_OF_CONDUCT.md LICENSE .claude-plugin .gitignore .gitattributes .github"
SHIPPED_HANDOFF="handoff/hooks handoff/skills handoff/README.md handoff/CHANGELOG.md handoff/docs handoff/.claude-plugin"
SHIPPED="$SHIPPED_ROOT $SHIPPED_HANDOFF"

# Neither tests directory is registered above, and they are left out for
# different reasons — worth spelling out separately, because a single reason
# covering both is true of one of them and false of the other.
#
# This file cannot be registered, by construction. It holds the denylist and
# the fixtures the scanners are fired at, so every banned term appears here by
# design and a scan covering it would fail on its own contents.
#
# handoff/tests is not that case. It scans clean today, and registering it
# would pass. It is left out by policy rather than by necessity: it is
# published, but it is a suite, not a surface a reader is directed to, and
# these scans exist to protect what a stranger installs and reads. Do not
# "fix" either omission by registering it.
#
# Be exact about what these two lists therefore cover, because "everything
# that ships" is not it. They cover the surface a stranger INSTALLS OR READS:
# the plugin tree, and the root documents and metadata. Other tracked files
# sit outside them on purpose. `docs/specs` and `docs/handoffs` are the
# working record of how this was built — nearly every file under them matches
# the vocabulary above, by design, because a design document has to name the
# stack it was extracted from to say anything — and the release curation is
# what keeps them off the published branch, not these lists. Registering them
# would redden the scan on contents that are correct, and the only way back to
# green would be to weaken the vocabulary — which is the wrong trade in the
# wrong direction. So the property to hold is narrower and checkable: no file in
# the installed-and-read surface is missing from these two lists —
# `.gitignore` sat outside them through two reviews while naming a denylisted
# tool.

# Exit status is the whole assertion here, so read it exactly: grep returns 0
# for a match, 1 for no match, and 2 for an error — an absent or renamed path,
# an unreadable file, a regex this platform's grep rejects. Only 1 means the
# surface was scanned and was clean. `-ne 0` would accept 2 as well, so a
# rename of `handoff/hooks/` or `handoff/skills/` would silently switch the
# scan off and the test would go on passing. Fail safe, never fail silent
# applies to the guard that protects the guard.
# Word boundaries come from `-w`, not `\b`. `\b` is a GNU extension and is not
# in POSIX ERE, and CI runs macos-latest with BSD grep, where it either errors
# out or is read as a literal `b` — the first exits 2, the second matches
# nothing, and under the old `-ne 0` both looked like a clean repository. `-w`
# is POSIX, behaves identically on GNU for an alternation of plain words, and
# takes the question off the table rather than leaving it to be discovered at
# the release gate.
@test "no originating-project vocabulary in the shipped surface" {
  cd "$ROOT"
  run grep -rniwE "$VOCAB_RE" $SHIPPED
  [ "$status" -eq 1 ]
}

@test "no absolute local paths in the shipped surface" {
  cd "$ROOT"
  run grep -rnE "$BANNED_PATHS" $SHIPPED
  [ "$status" -eq 1 ]
}

@test "every SKILL.md has name and description frontmatter" {
  # An empty `find` leaves the loop body unexecuted and the test passing
  # without having read anything, so pin that there is something to check.
  # The search is repository-wide rather than one plugin's directory, so a
  # second plugin's skills are covered the day it lands rather than the day
  # someone remembers to add it here.
  skills="$(find "$ROOT" -path "$ROOT/.git" -prune -o -name SKILL.md -print)"
  [ -n "$skills" ]
  while IFS= read -r skill; do
    [ "$(head -1 "$skill")" = "---" ]
    fm="$(awk 'NR>1 && /^---$/{exit} NR>1{print}' "$skill")"
    grep -qE '^name:' <<< "$fm"
    grep -qE '^description:' <<< "$fm"
  done <<< "$skills"
}

@test "the manifests parse" {
  jq -e . "$ROOT/handoff/.claude-plugin/plugin.json" > /dev/null
  jq -e . "$ROOT/.claude-plugin/marketplace.json" > /dev/null
  jq -e . "$ROOT/handoff/hooks/hooks.json" > /dev/null
}

@test "the hook is registered with a plugin-root-relative path" {
  cmd="$(jq -r '.hooks.PostToolUse[0].hooks[0].command' "$ROOT/handoff/hooks/hooks.json")"
  [[ "$cmd" == *'${CLAUDE_PLUGIN_ROOT}'* ]]
  [[ "$cmd" == *'context-guard.sh'* ]]
}

@test "the hook timeout leaves headroom over the measured worst case" {
  # A hook killed by its own timeout emits nothing, and a guard that emits
  # nothing is a guard that is silently off — the exact failure this project
  # exists to prevent. So the declared timeout must clear the slowest path the
  # design admits, not the typical one.
  #
  # Measured on a 48MB transcript whose readings fall inside the 5000-line
  # window but outside the 8MB byte cap, so the starvation fallback fires and
  # the file is read twice: 8.2s. The common capped path is 2.0s and the old
  # uncapped code was 7.2s. 30 leaves ~3.6x over the worst case; 10 left 1.2x.
  timeout="$(jq -r '.hooks.PostToolUse[0].hooks[0].timeout' "$ROOT/handoff/hooks/hooks.json")"
  [ "$timeout" -ge 30 ]
}

@test "every plugin's manifest, marketplace entry and changelog agree" {
  cd "$ROOT"
  # Loop over plugin directories rather than naming one. A gate that knows a
  # single plugin's name stops covering the repository the moment a second
  # plugin lands, and does so silently.
  checked=0
  for dir in */; do
    p="${dir%/}"
    [ -f "$p/.claude-plugin/plugin.json" ] || continue
    checked=$((checked + 1))

    pn="$(jq -r '.name // empty' "$p/.claude-plugin/plugin.json")"
    pv="$(jq -r '.version // empty' "$p/.claude-plugin/plugin.json")"
    [ -n "$pn" ] || { echo "$p: plugin.json has no name"; false; }
    [ -n "$pv" ] || { echo "$p: plugin.json has no version"; false; }

    # Select by name, never by position. A second plugin prepended to the array
    # would otherwise be compared against the wrong entry — and could agree
    # with it by accident.
    mv="$(jq -r --arg n "$pn" '.plugins[] | select(.name == $n) | .version' .claude-plugin/marketplace.json)"
    [ -n "$mv" ] || { echo "$p: no marketplace entry named $pn"; false; }

    # And the entry must point AT the directory this iteration just read.
    # Nothing else in the repository reads `source` — no other test, no
    # workflow, no script — and it is the field the installer follows to find
    # the manifest, so an entry naming the wrong directory is a broken install
    # that every gate here calls agreement. That is not hypothetical: `source`
    # said `"./"`, a directory holding no plugin manifest, from the commit that
    # moved the plugin into handoff/ until the commit that renamed it, and the
    # whole suite was green for the duration.
    #
    # Checked inside this loop rather than in a test of its own because the
    # loop has already found the directory the entry has to name and looked the
    # entry up by name; a separate test would duplicate both, and would need
    # its own guard against passing over zero plugins.
    ms="$(jq -r --arg n "$pn" '.plugins[] | select(.name == $n) | .source // empty' .claude-plugin/marketplace.json)"
    [ -n "$ms" ] || { echo "$p: marketplace entry $pn has no source"; false; }
    # Both spellings a relative source can take resolve to the same directory,
    # so normalise before comparing: what is being asserted is which directory
    # is named, not how it was written.
    src="${ms#./}"; src="${src%/}"
    [ "$src" = "$p" ] || { echo "$p: marketplace entry $pn has source '$ms', which does not resolve to $p"; false; }

    # The heading format is pinned precisely because this line parses it, so
    # assert the date half too rather than trusting it to stay. Be exact about
    # what that buys: `-m1` takes the first heading that MATCHES, so when the
    # newest heading has drifted and the older ones have not, this reads an
    # older release's version and the drift surfaces as a version disagreement
    # rather than as a complaint about the format. Measured, not assumed.
    #
    # The `|| true` is load bearing, for the same reason ci.yml's version job
    # carries one: bats runs each test under errexit, and a failing command
    # substitution in an assignment aborts the test AT THIS LINE, so the
    # diagnostic below never runs. Also measured — without it, a missing
    # CHANGELOG.md fails with grep's "No such file or directory" and names no
    # format, and a file whose ONLY heading has drifted fails with no output at
    # all, which is exactly the case the diagnostic exists for. It cannot mask a
    # real failure: an empty head is rejected on the next line.
    head="$(grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$p/CHANGELOG.md" || true)"
    [ -n "$head" ] || { echo "$p: no changelog heading in the pinned '## [X.Y.Z] - YYYY-MM-DD' format"; false; }
    cv="$(printf '%s' "$head" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"

    # Name the values on failure. A bare line number tells you the versions
    # disagree but not which file is the odd one out — and now, not which
    # plugin.
    [ "$pv" = "$mv" ] || { echo "$p: plugin=$pv marketplace=$mv"; false; }
    [ "$pv" = "$cv" ] || { echo "$p: plugin=$pv changelog=$cv"; false; }
  done

  # A loop over zero plugins passes vacuously, having verified nothing. That is
  # the defect this repository keeps rediscovering: the SKILL.md search above
  # needs a non-empty pin for it, the link test below counts what it resolved
  # because it once reported PASS having resolved none, and an empty SHIPPED
  # list would aim `grep -r` at the working directory rather than erroring. So
  # pin that this loop found work to do.
  [ "$checked" -ge 1 ] || { echo "no plugin directories found under $ROOT"; false; }
}

# A denylist that has silently stopped working is indistinguishable from a
# clean repository: both produce no matches. Every other run of these scans
# exercises only the absence of a hit, so nothing else here would notice a
# pattern that had stopped matching anything at all — a regex construct this
# platform's grep does not support, a mangled alternation. That is precisely
# what this control catches: an expression that has stopped matching ENTIRELY.
# What it cannot catch is a typo confined to one branch. The fixture exercises
# `dart` and `flutter`; misspell `speckit` in the list above and this control,
# and every other test in this repository, stays green. Nothing automated
# closes that gap — the human read-through before release is what it is for.
#
# The fixture is `dartboard aside, flutter here` rather than a bare word on a
# line. It puts a candidate that FAILS the word test — `dart` inside
# `dartboard` — ahead of one that passes, so a grep whose `-w` abandons a line
# after the leftmost candidate fails returns no match here and trips the
# assertion below. That divergence is the unsafe one: it is a false negative on
# a real leak, and it would survive a first green run on macos-latest. A bare
# `flutter` matches under `-w`, under `\b` and under no word handling at all,
# so it could not tell any of those apart.
#
# This fixture lives outside SHIPPED, so it can never trip the real scans, and
# it proves on every run on every platform that both scanners still fire. The
# vocabulary expression comes from `$VOCAB_RE`, the variable the real scan
# uses, so the two cannot drift.
@test "the leak scanners actually fire on a known-bad fixture" {
  printf 'dartboard aside, flutter here\n' > "$TEST_DIR/vocab.txt"
  printf 'D:\\Users\\someone\n' > "$TEST_DIR/paths.txt"
  run grep -rniwE "$VOCAB_RE" "$TEST_DIR/vocab.txt"
  [ "$status" -eq 0 ]
  run grep -rnE "$BANNED_PATHS" "$TEST_DIR/paths.txt"
  [ "$status" -eq 0 ]
}

@test "a bare reference to the projects directory is not a leak" {
  # The setup skill must name this directory to do its job (design D4), and a
  # prose reference to it carries no identity. The pattern exists to catch a
  # PERSONAL path — the same prefix followed by an encoded project directory,
  # which Claude Code writes one of per project with the absolute path
  # flattened into the name. Requiring a path character after the slash
  # separates the two. The fixture ends the reference with a backtick, which is
  # how the reference is actually written in markdown; this is also why the
  # character class must not be widened to `[^ ]`, which matches a backtick and
  # re-creates the false positive.
  printf 'Find the newest transcript under `~/.claude/projects/`.\n' > "$TEST_DIR/prose.txt"
  run grep -rnE "$BANNED_PATHS" "$TEST_DIR/prose.txt"
  [ "$status" -eq 1 ]
}

@test "an encoded project directory is still caught after the narrowing" {
  # The positive control for the narrowing, and it is not optional: every other
  # run of this scan asserts only the ABSENCE of a hit, so a pattern that had
  # stopped matching entirely would be indistinguishable from a clean tree.
  # Without this test, narrowing the pattern and deleting it look the same.
  # The fixture is synthetic — a real local path has no business in a committed
  # file, and a fabricated one demonstrates the point identically.
  printf 'see ~/.claude/projects/D--Acme-Widget/memory/MEMORY.md\n' > "$TEST_DIR/encoded.txt"
  run grep -rnE "$BANNED_PATHS" "$TEST_DIR/encoded.txt"
  [ "$status" -eq 0 ]
}

@test "a POSIX-encoded project directory is caught too" {
  # The encoding flattens every path separator to a hyphen, so a POSIX path —
  # which starts at the root separator — encodes with a LEADING hyphen:
  # `/Users/jane/code/widget` becomes `-Users-jane-code-widget`. That is why
  # the character class carries a hyphen, written LAST so it is a literal and
  # not a range. Without it the class matches only the drive-letter shape
  # Windows produces, and every macOS and Linux leak walks straight through.
  #
  # This test exists because that gap cannot be seen from a green suite. The
  # real scan asserts only the ABSENCE of a hit, so a pattern that has stopped
  # catching a whole platform's paths reads exactly like a clean tree — the
  # neighbouring control catches an expression that matches NOTHING, not one
  # that has quietly lost a branch. The fixture is synthetic, like the others.
  printf 'see ~/.claude/projects/-Users-jane-code-widget/memory/MEMORY.md\n' > "$TEST_DIR/posix.txt"
  run grep -rnE "$BANNED_PATHS" "$TEST_DIR/posix.txt"
  [ "$status" -eq 0 ]
}

@test "a local .leakwords file extends the vocabulary" {
  # The private half of the denylist is the half that cannot be published, so
  # nothing in CI exercises it and it would rot unnoticed. This builds the
  # alternation the same way the suite does, against a fixture .leakwords, and
  # checks three things that have each been a real failure mode here: the extra
  # term is matched; a blank line does not produce an empty alternation branch
  # that matches everything; and the shipped terms still work alongside it.
  printf 'acmecorp\n\n  \n' > "$TEST_DIR/.leakwords"
  extra="$(grep -v '^[[:space:]]*$' "$TEST_DIR/.leakwords" | paste -sd'|' -)"
  [ "$extra" = "acmecorp" ]
  re="($BANNED_WORDS|$extra)"

  printf 'we use acmecorp internally\n' > "$TEST_DIR/private.txt"
  run grep -rniwE "$re" "$TEST_DIR/private.txt"
  [ "$status" -eq 0 ]

  printf 'nothing to see here\n' > "$TEST_DIR/clean.txt"
  run grep -rniwE "$re" "$TEST_DIR/clean.txt"
  [ "$status" -eq 1 ]

  printf 'a flutter reference\n' > "$TEST_DIR/stack.txt"
  run grep -rniwE "$re" "$TEST_DIR/stack.txt"
  [ "$status" -eq 0 ]
}

@test "every relative link in the shipped documentation resolves" {
  cd "$ROOT"
  broken=""
  # Count the links actually resolved, and refuse to pass on zero. Every file
  # here is guarded by `[ -f "$f" ] || continue` and one of the entries is a
  # glob, so a list that has gone stale — a file moved, a directory renamed
  # out from under the glob — leaves the loop body unexecuted, `broken` empty,
  # and this test green having examined nothing at all.
  #
  # That is not hypothetical. Midway through the move that created handoff/,
  # this list still named the pre-move paths; every one of them was skipped,
  # and this test reported PASS while resolving zero links. It was the only
  # test in the suite that stayed green for a reason that had nothing to do
  # with the property it names. A guard that cannot distinguish "nothing is
  # broken" from "nothing was checked" is not a guard.
  #
  # The root `CHANGELOG.md` is on this list because it is the one shipped
  # document whose ENTIRE payload is a relative link — it is an index pointing
  # at each plugin's own changelog, and nothing else. A link that does not
  # resolve there is not a blemish in a document, it is the document being
  # empty. While that file carried only `http` links its absence here cost
  # nothing, which is exactly why the omission survived the split that made it
  # an index.
  checked=0
  for f in README.md CONTRIBUTING.md CHANGELOG.md handoff/README.md handoff/docs/*.md; do
    [ -f "$f" ] || continue
    while IFS= read -r link; do
      case "$link" in http*|https*|mailto:*|'#'*) continue ;; esac
      target="${link%%#*}"
      [ -n "$target" ] || continue
      # Counted here rather than per file, so a file that ships with only
      # external links cannot stand in for one whose relative links vanished.
      checked=$((checked + 1))
      [ -e "$(dirname "$f")/$target" ] || broken="$broken $f->$link"
    done < <(grep -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//')
  done
  [ "$checked" -gt 0 ] || { echo "no relative links were examined; the file list above has gone stale"; false; }
  [ -z "$broken" ] || { echo "broken links:$broken"; false; }
}

# The handoff skill promised in 1.2.0 that it writes nothing to git. That promise
# lives entirely in prose, so nothing stopped a later edit from quietly restoring
# the instruction a user complained about — the skill's behaviour is instructions
# to Claude and the suite cannot execute it.
#
# BE HONEST ABOUT WHAT THIS CATCHES. It is a regression guard, not a proof. It
# pins that the three explicit prohibitions are still present and that the exact
# instructions 1.2.0 removed have not come back. It CANNOT detect a newly worded
# instruction to commit — "save your progress to the repository" would sail past
# it. The alternative considered and rejected was stripping fenced code blocks
# and requiring every remaining mention of commit/push to carry a negation; that
# fires on "last commit SHA", "with commit SHAs and PR numbers" and "someone else
# committed", all of which are legitimate, so it would have been a test that
# reddens on correct text.
#
# The `git add`/`git commit`/`git push` lines inside the skill's fenced block are
# deliberate: they are printed FOR the developer to run, which is the whole
# remedy. So this test must not simply grep for those strings.
@test "the handoff skill still refuses to write to git" {
  skill="$ROOT/handoff/skills/handoff/SKILL.md"
  [ -f "$skill" ]

  # The prohibitions 1.2.0 added. Deleting any one of them reddens this test.
  grep -qF 'Do not commit. Do not push. Do not stage anything.' "$skill"
  grep -qF 'This skill never writes to git.' "$skill"
  grep -qF 'Do not commit it and do not push it.' "$skill"

  # The instructions 1.2.0 removed. Restoring any of them reddens this test.
  #
  # These are written as `run` plus a status check, NOT as `! grep …`, and that is
  # load-bearing rather than stylistic. POSIX exempts a `!`-negated command from
  # errexit, so `! grep -q pattern file` does NOT fail a bats test when the
  # pattern IS found — the assertion is inert and the test passes on a tree that
  # violates it. Written the obvious way first, three of the negative assertions
  # below could never fire; the mutation run is what exposed it, and the
  # positive `grep -qF` assertions above were reddening all along, which is
  # exactly what made the inert ones look like they worked.
  run grep -qE 'Commit everything on the working branch' "$skill"
  [ "$status" -ne 0 ]
  run grep -qE 'Then commit it, and push if there is a remote' "$skill"
  [ "$status" -ne 0 ]
  run grep -qE 'commits left unpushed where a remote exists' "$skill"
  [ "$status" -ne 0 ]

  # And the hook must not order it either. Anchored on `^reason=` so the
  # explanatory comment above that line — which quotes the old wording in order
  # to explain why it changed — is not what this matches. The emitted string is.
  run grep -qE '^reason=.*commit and push the work' "$ROOT/handoff/hooks/context-guard.sh"
  [ "$status" -ne 0 ]
  grep -qE '^reason=.*Do NOT commit or push' "$ROOT/handoff/hooks/context-guard.sh"
}

@test "CI runs every suite in the repository" {
  cd "$ROOT"
  # `-r` recurses beneath the paths it is given, so it covers a subdirectory
  # of tests/ but not a sibling suite in another plugin. Before this test,
  # adding pipeline/tests/ later without touching ci.yml would have shipped a
  # suite nobody runs while CI stayed green — the failure mode this repository
  # keeps finding, in a new place. This test is what converts that silence into
  # a red build: ci.yml still would not RUN the new suite, but the omission is
  # named here and the build fails until the line grows to match.

  # The `|| true` is load bearing, for the reason given above the changelog
  # reader in this file: under errexit a failing command substitution aborts
  # the test AT THIS LINE, so the diagnostic below never runs. What is specific
  # here is what the grep looks for — the ci.yml bats line itself — so the
  # only way it finds nothing is that someone rewrote or deleted the invocation
  # this test exists to police, which is exactly the case the message below is
  # written for. Measured in both directions: without it that case fails at the
  # assignment printing nothing, and reads as a broken pattern rather than as a
  # workflow that no longer runs bats. It cannot mask a real failure: an empty
  # line is rejected on the next line, and would match no directory below anyway.
  line="$(grep -m1 -E 'bats" -r --print-output-on-failure' .github/workflows/ci.yml || true)"
  [ -n "$line" ] || { echo "no bats invocation found in ci.yml"; false; }

  # Discovery is over TRACKED files, not over the filesystem, and that is the
  # definition this invariant needs: a suite is a suite because the repository
  # carries it, and ci.yml can only be asked to name what a CI checkout will
  # actually contain. It also repairs a real failure. The scan here used to walk
  # everything beneath $ROOT except .git — and this project keeps its worktrees
  # in .claude/worktrees/, so from the repository root it discovered three
  # sibling checkouts' suites and demanded ci.yml name them, while from inside a
  # worktree it saw the two real ones and passed. Every run during development
  # happened inside a worktree; the first run from the root, on the release tree,
  # went red. `git ls-files` answers the same from both, honours .gitignore by
  # construction so no scratch directory added later can redden this, and outside
  # a checkout emits nothing — which the pin below turns into a named failure
  # rather than a silent pass.
  #
  # The `[ -n "$line" ]` above pins the grep half; this pins the discovery half,
  # for the same reason. If the listing emits nothing the loop body never runs,
  # `missing` stays empty, and the assertion below reports PASS having examined
  # zero directories — a suite-coverage gate that has stopped seeing any suites,
  # in the file whose own comments name this defect class. So count what was
  # examined, exactly as the version gate and the link test above do. Measured,
  # not assumed: with the pathspec pointed at something the index cannot match,
  # this body reports PASS without the pin and names the vacuum with it.
  missing=""
  checked=0
  while IFS= read -r d; do
    checked=$((checked + 1))
    case " $line " in *" $d "*) ;; *) missing="$missing $d" ;; esac
  done < <(git ls-files '*.bats' | xargs -n1 dirname | sort -u)

  [ "$checked" -ge 1 ] || { echo "no tracked .bats file was found under $ROOT; this gate examined nothing"; false; }
  [ -z "$missing" ] || { echo "suites absent from the ci.yml bats line:$missing"; false; }
}
