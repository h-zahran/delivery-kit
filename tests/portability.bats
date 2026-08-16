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
if [ -f "$REPO/.leakwords" ]; then
  # Blank lines are stripped before joining. An empty alternation branch would
  # match at every position, turning the scan into something that fires on
  # everything — loudly, since the tests assert "no match", but for a reason
  # that has nothing to do with a leak.
  extra="$(grep -v '^[[:space:]]*$' "$REPO/.leakwords" | paste -sd'|' -)"
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
SHIPPED="hooks skills README.md CONTRIBUTING.md CHANGELOG.md docs/why.md docs/install.md docs/configuration.md .claude-plugin .gitignore .gitattributes .github CODE_OF_CONDUCT.md LICENSE"

# `tests/` is published but cannot be registered above, and that is structural
# rather than an oversight: this file holds the denylist and the fixtures the
# scanners fire at, so every banned term appears here by design and a scan
# covering itself would fail by construction. Registering it would produce a
# permanently red suite, so do not "fix" this. Everything else that ships is
# listed, which is the property that matters — `.gitignore` sat outside this
# list through two reviews while naming a denylisted tool.

# Exit status is the whole assertion here, so read it exactly: grep returns 0
# for a match, 1 for no match, and 2 for an error — an absent or renamed path,
# an unreadable file, a regex this platform's grep rejects. Only 1 means the
# surface was scanned and was clean. `-ne 0` would accept 2 as well, so a
# rename of `hooks/` or `skills/` would silently switch the scan off and the
# test would go on passing. Fail safe, never fail silent applies to the guard
# that protects the guard.
# Word boundaries come from `-w`, not `\b`. `\b` is a GNU extension and is not
# in POSIX ERE, and CI runs macos-latest with BSD grep, where it either errors
# out or is read as a literal `b` — the first exits 2, the second matches
# nothing, and under the old `-ne 0` both looked like a clean repository. `-w`
# is POSIX, behaves identically on GNU for an alternation of plain words, and
# takes the question off the table rather than leaving it to be discovered at
# the release gate.
@test "no originating-project vocabulary in the shipped surface" {
  cd "$REPO"
  run grep -rniwE "$VOCAB_RE" $SHIPPED
  [ "$status" -eq 1 ]
}

@test "no absolute local paths in the shipped surface" {
  cd "$REPO"
  run grep -rnE "$BANNED_PATHS" $SHIPPED
  [ "$status" -eq 1 ]
}

@test "every SKILL.md has name and description frontmatter" {
  # An empty `find` leaves the loop body unexecuted and the test passing
  # without having read anything, so pin that there is something to check.
  # There is exactly one SKILL.md today, which means a single rename of
  # `skills/` would otherwise quietly disable both this test and the skills
  # half of the vocabulary scan above.
  skills="$(find "$REPO/skills" -name SKILL.md)"
  [ -n "$skills" ]
  while IFS= read -r skill; do
    [ "$(head -1 "$skill")" = "---" ]
    fm="$(awk 'NR>1 && /^---$/{exit} NR>1{print}' "$skill")"
    grep -qE '^name:' <<< "$fm"
    grep -qE '^description:' <<< "$fm"
  done <<< "$skills"
}

@test "the manifests parse" {
  jq -e . "$REPO/.claude-plugin/plugin.json" > /dev/null
  jq -e . "$REPO/.claude-plugin/marketplace.json" > /dev/null
  jq -e . "$REPO/hooks/hooks.json" > /dev/null
}

@test "the hook is registered with a plugin-root-relative path" {
  cmd="$(jq -r '.hooks.PostToolUse[0].hooks[0].command' "$REPO/hooks/hooks.json")"
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
  timeout="$(jq -r '.hooks.PostToolUse[0].hooks[0].timeout' "$REPO/hooks/hooks.json")"
  [ "$timeout" -ge 30 ]
}

@test "plugin.json, the marketplace entry and the changelog agree on the version" {
  pv="$(jq -r '.version' "$REPO/.claude-plugin/plugin.json")"
  # Select by name, never by position. A second plugin prepended to the array
  # would otherwise be compared against the wrong entry — and could agree with
  # it by accident. ci.yml's version job selects by name for this same reason
  # and says so; this suite should not do the thing the workflow warns against.
  mv="$(jq -r '.plugins[] | select(.name == "delivery-kit") | .version' "$REPO/.claude-plugin/marketplace.json")"
  # The heading format is pinned to `## [X.Y.Z] - YYYY-MM-DD` precisely because
  # this line parses it, so assert the date half too rather than trusting it to
  # stay. Matching the whole shape also means a heading that has drifted fails
  # here, naming the format, instead of yielding an empty version and failing
  # later as a bogus disagreement.
  head="$(grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$REPO/CHANGELOG.md")"
  [ -n "$head" ] || { echo "no changelog heading in the pinned '## [X.Y.Z] - YYYY-MM-DD' format"; false; }
  cv="$(printf '%s' "$head" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  # Name the values on failure. A bare line number tells you the versions
  # disagree but not which file is the odd one out.
  [ "$pv" = "$mv" ] || { echo "plugin=$pv marketplace=$mv"; false; }
  [ "$pv" = "$cv" ] || { echo "plugin=$pv changelog=$cv"; false; }
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
  cd "$REPO"
  broken=""
  for f in README.md CONTRIBUTING.md docs/*.md; do
    [ -f "$f" ] || continue
    while IFS= read -r link; do
      case "$link" in http*|https*|mailto:*|'#'*) continue ;; esac
      target="${link%%#*}"
      [ -n "$target" ] || continue
      [ -e "$(dirname "$f")/$target" ] || broken="$broken $f->$link"
    done < <(grep -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//')
  done
  [ -z "$broken" ] || { echo "broken links:$broken"; false; }
}
