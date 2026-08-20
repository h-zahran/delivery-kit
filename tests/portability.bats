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

# R2's per-surface vocabulary (design section 20, decision A; amended by
# the R2 plan to include the suite): the pipeline directories that execute
# — skills and scripts — plus the suite that asserts their output, are
# scanned with the strict list minus the five terms a phase instruction, a
# detector, or a test asserting either cannot function without writing.
# The three published terms banned everywhere stay banned here, and
# .leakwords folds in exactly as above: the relaxed list is named
# exceptions, not a weaker principle.
RELAXED_WORDS='supabase|graphify|superpowers'
if [ -n "${extra:-}" ]; then RELAXED_WORDS="$RELAXED_WORDS|$extra"; fi
RELAXED_RE="($RELAXED_WORDS)"

# Everything a stranger installs or reads, registered entry by entry — a
# file, or a directory whose whole tree ships. Registration costs something —
# a document added later and never registered here goes unscanned — and buys
# something better: no NEW tree joins or leaves the scan without a line here
# changing, so the scanned surface cannot drift silently. (A registered
# directory does grow with its own contents; that is what registering a
# directory means.) The scans assert `-eq 1`, so a rename of something listed
# fails loudly rather than switching the scan off.
#
# Three lists rather than one, because the surface now spans three trees.
# The RELAXED vocabulary for the pipeline directories that execute is a
# different mechanism — its own test, its own explicit path operands —
# arriving WITH the directories it describes and never ahead of them,
# because an empty one does not fail: `grep -r` given no path operand does
# not error, it defaults to the working directory. An early relaxed scan
# would not exit 2 and redden — it would silently rescan the whole
# repository under the relaxed vocabulary, and whatever it reported would
# say nothing about the surface it was meant to cover. Exit 2 needs a named
# path that is missing — or unreadable, or a regex this platform's grep
# rejects, exactly as the comment above the scans spells out — and those
# are the cases the `-eq 1` assertions below are written to catch.
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
SHIPPED_HANDOFF="handoff/hooks handoff/skills handoff/README.md handoff/CHANGELOG.md handoff/docs handoff/tests handoff/.claude-plugin"
SHIPPED_PIPELINE="pipeline/README.md pipeline/CHANGELOG.md pipeline/.claude-plugin pipeline/commands pipeline/docs"
SHIPPED="$SHIPPED_ROOT $SHIPPED_HANDOFF $SHIPPED_PIPELINE"

# Root tests/ cannot be registered, by construction: it holds the denylist
# and the fixtures the scanners are fired at, so a scan covering it would
# fail on its own contents.
#
# pipeline/skills, pipeline/scripts and pipeline/tests are absent from
# these lists for a third reason: they are scanned by the RELAXED test
# below with its own explicit operands. Not exempt — scanned under the
# vocabulary that lets a detector name the files it detects and a suite
# assert the defaults it must prove.
#
# handoff/tests IS registered, and that reverses a 2.0.0 comment which called
# it "a suite, not a surface a reader is directed to". The install contradicts
# that premise: the marketplace entry's source is ./handoff, the installer
# copies that whole tree, and the plugin's suite lands on every user's
# machine. What ships is scanned — a banned term pasted into a test fixture
# would otherwise reach every install with the build green. Fixtures that
# NEED banned terms belong in root tests/, beside the denylist.
#
# Be exact about what these lists cover, because "everything tracked" is not
# it. They cover what a stranger installs or reads: the plugin trees, and the
# root documents and metadata. `docs/specs` and `docs/handoffs` are the
# working record of how this was built — nearly every file under them matches
# the vocabulary above, by design — and the release curation keeps them off
# the published branch, not these lists. Registering them would redden the
# scan on contents that are correct, and the only way back to green would be
# weakening the vocabulary: the wrong trade in the wrong direction. The
# property to hold is narrower: every plugin directory owns a non-empty
# SHIPPED_* list — that half is pinned by a test below. The other half stays
# a review property no test here checks: no file in the installed-and-read
# surface sits outside one — `.gitignore` sat outside them through two
# reviews while naming a denylisted tool.

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

# The relaxed operands are EXPLICIT and this assertion is `-eq 1` for the
# same reason as above: a missing operand is exit 2 and a red, never a
# silent rescan of the working directory. These three paths exist from the
# commit that adds this test — the list arrived WITH the directories it
# describes.
@test "no banned-everywhere vocabulary in the relaxed pipeline surfaces" {
  cd "$ROOT"
  run grep -rniwE "$RELAXED_RE" pipeline/skills pipeline/scripts pipeline/tests
  [ "$status" -eq 1 ]
}

@test "no absolute local paths in the relaxed pipeline surfaces" {
  cd "$ROOT"
  run grep -rnE "$BANNED_PATHS" pipeline/skills pipeline/scripts pipeline/tests
  [ "$status" -eq 1 ]
}

# A non-ASCII byte in a bats @test NAME makes bats on this platform skip
# the test SILENTLY -- no TAP line, nonzero exit -- so the suite lies by
# omission. Proven reachable: an em dash in a test name cost a dead
# detector test during R2. Names stay ASCII; bodies and comments may say
# what they like.
@test "every bats test name is pure ASCII" {
  cd "$ROOT"
  bad=0
  while IFS= read -r f; do
    if LC_ALL=C grep -n '^@test' "$f" | LC_ALL=C grep -q '[^ -~]'; then
      echo "non-ASCII @test name in $f:"
      LC_ALL=C grep -n '^@test' "$f" | LC_ALL=C grep '[^ -~]'
      bad=1
    fi
  done < <(git ls-files '*.bats')
  [ "$bad" -eq 0 ]
}

@test "every plugin directory owns a non-empty shipped-surface list" {
  cd "$ROOT"
  # SHIPPED_* lists are hand-maintained registrations, and an unregistered
  # file is an unscanned one — that has happened twice to single files. A
  # whole plugin tree can go the same way: the version gates pick a new
  # directory up automatically, so every OTHER gate turning green lends
  # credibility to a surface the leak scans never read. A plugin directory
  # must bring its list with it: SHIPPED_<DIRNAME>, hyphens as underscores.
  checked=0
  for dir in */; do
    p="${dir%/}"
    [ -f "$p/.claude-plugin/plugin.json" ] || continue
    checked=$((checked + 1))
    varname="SHIPPED_$(printf '%s' "$p" | tr '[:lower:]-' '[:upper:]_')"
    list="${!varname:-}"
    [ -n "$list" ] || { echo "$p ships, but $varname is empty or missing from this file"; false; }
    # And the union must carry it verbatim, or the registration exists
    # without being scanned. This works because SHIPPED is built by
    # concatenating the per-tree lists; keep building it that way.
    case " $SHIPPED " in *" $list "*) ;; *) echo "$varname is not part of SHIPPED, so nothing scans it"; false ;; esac
    # Direction (scaffold item 11): a list naming another plugin's paths
    # passes both checks above while scanning nothing of THIS plugin. Every
    # entry must point into the directory that registered it.
    for tok in $list; do
      case "$tok" in "$p"/*) ;; *) echo "$varname entry '$tok' does not point into $p/"; false ;; esac
    done
  done
  [ "$checked" -ge 1 ] || { echo "no plugin directories found under $ROOT"; false; }
}

@test "every SKILL.md has name and description frontmatter" {
  cd "$ROOT"
  # Discovery is over TRACKED files, for the same reason the suite-coverage
  # gate at the bottom of this file switched to `git ls-files`: a filesystem
  # walk sees sibling worktrees under .claude/worktrees/ and whatever scratch
  # a dev workflow drops, so a half-written SKILL.md that was never in the
  # release reddened the release-tree run while `git status` sat clean.
  # `git ls-files` answers identically from the root and from a worktree, and
  # it lists the index, so untracked scratch never appears. Outside a checkout
  # it FAILS — and the `|| true` below is load bearing for exactly that case:
  # under errexit a failing command substitution kills the test AT THE
  # ASSIGNMENT, so without it that failure carries git's stderr instead of the
  # named diagnostic on the next line. Measured, not assumed. The search is
  # repository-wide rather than one plugin's directory, so a second plugin's
  # skills are covered the day they are committed.
  # Repository-wide, so this sweep also polices fixture SKILL.md files
  # under pipeline/tests/fixtures. Deliberate coupling: a future fixture
  # that needs MALFORMED frontmatter must use a different filename.
  skills="$(git ls-files ':(glob)**/SKILL.md' || true)"
  [ -n "$skills" ] || { echo "no tracked SKILL.md found; this gate examined nothing"; false; }
  while IFS= read -r skill; do
    [ "$(head -1 "$skill")" = "---" ]
    fm="$(awk 'NR>1 && /^---$/{exit} NR>1{print}' "$skill")"
    grep -qE '^name:' <<< "$fm"
    grep -qE '^description:' <<< "$fm"
  done <<< "$skills"
}

@test "the manifests parse" {
  cd "$ROOT"
  jq -e . .claude-plugin/marketplace.json > /dev/null
  checked=0
  for dir in */; do
    p="${dir%/}"
    [ -f "$p/.claude-plugin/plugin.json" ] || continue
    checked=$((checked + 1))
    jq -e . "$p/.claude-plugin/plugin.json" > /dev/null
    # Hooks are optional per plugin; a plugin that ships them ships them
    # parseable.
    [ ! -f "$p/hooks/hooks.json" ] || jq -e . "$p/hooks/hooks.json" > /dev/null
  done
  [ "$checked" -ge 1 ] || { echo "no plugin directories found under $ROOT"; false; }
}

@test "every shipped hook is registered with a plugin-root-relative path" {
  cd "$ROOT"
  hooked=0
  for dir in */; do
    p="${dir%/}"
    [ -f "$p/hooks/hooks.json" ] || continue
    hooked=$((hooked + 1))
    while IFS= read -r cmd; do
      # Same text-mode jq as the timeout loop below: `read` keeps the CR.
      # The substring match survives it — measured, the gate still fired on
      # an absolute path — but the diagnostic did not: the embedded CR sent
      # the cursor back to column 0 mid-message (od-verified), overwriting
      # the start of the very line that names the offending command.
      cmd="${cmd%$'\r'}"
      [[ "$cmd" == *'${CLAUDE_PLUGIN_ROOT}'* ]] || { echo "$p: hook command '$cmd' is not plugin-root-relative"; false; }
    done < <(jq -r '.. | objects | select(has("command")) | .command' "$p/hooks/hooks.json")
  done
  # handoff ships a hook today, so a loop that found none has lost its
  # subject; a plugin without hooks/ is skipped, not failed.
  [ "$hooked" -ge 1 ] || { echo "no hooks.json found in any plugin directory"; false; }
  # And the one hook this repository ships is still the context guard.
  cmd0="$(jq -r '.hooks.PostToolUse[0].hooks[0].command' handoff/hooks/hooks.json)"
  [[ "$cmd0" == *'context-guard.sh'* ]]
}

@test "every shipped hook timeout leaves headroom over the measured worst case" {
  cd "$ROOT"
  # A hook killed by its own timeout emits nothing, and a guard that emits
  # nothing is silently off — the exact failure this project exists to
  # prevent. Measured on a 48MB transcript whose readings fall inside the
  # 5000-line window but outside the 8MB byte cap, so the starvation fallback
  # fires and the file is read twice: 8.2s. The common capped path is 2.0s.
  # 30 leaves ~3.6x over the worst case; 10 left 1.2x.
  hooked=0
  for dir in */; do
    p="${dir%/}"
    [ -f "$p/hooks/hooks.json" ] || continue
    hooked=$((hooked + 1))
    while IFS= read -r timeout; do
      # jq here is a native Windows binary whose stdout is text mode: every
      # line it prints ends `\r\n`, and `read` keeps that CR. The present-key
      # path survives it — measured, `[ "30"$'\r' -ge 30 ]` is 0 on bash
      # 5.3.9 — so a clean tree stays green either way. The ABSENT-key path
      # does not: `.timeout // ""` prints an empty line, `read` yields a lone
      # CR, `[ -n ]` calls that non-empty, and the missing-timeout gate below
      # is skipped in favour of `-ge` failing with "integer expected".
      # Measured: without this strip, deleting the timeout key sent the test
      # red at the floor message instead of the one naming the real fault.
      timeout="${timeout%$'\r'}"
      [ -n "$timeout" ] || { echo "$p: a hook declares no timeout"; false; }
      [ "$timeout" -ge 30 ] || { echo "$p: hook timeout $timeout is under the 30-second floor"; false; }
    done < <(jq -r '.. | objects | select(has("command")) | .timeout // ""' "$p/hooks/hooks.json")
  done
  [ "$hooked" -ge 1 ] || { echo "no hooks.json found in any plugin directory"; false; }
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

    # The tag gate resolves a plugin FROM THE DIRECTORY NAME — ci.yml strips
    # `-v<version>` from the tag and reads <plugin>/.claude-plugin/plugin.json
    # — while this loop resolves the marketplace entry from the manifest's
    # .name. Nothing else holds those two identities together: a manifest
    # renamed without its directory left every gate green while release tags
    # silently stopped naming the plugin.
    [ "$pn" = "$p" ] || { echo "$p: plugin.json name '$pn' does not match its directory"; false; }

    # Select by name, never by position. A second plugin prepended to the array
    # would otherwise be compared against the wrong entry — and could agree
    # with it by accident.
    # Existence and the version key are two different absences with two
    # different fixes, so they get two different messages. Without `// empty`,
    # jq prints the literal string "null" for a present entry missing the
    # key, which passes [ -n ] and sends the maintainer diffing two version
    # numbers when one of them does not exist.
    jq -e --arg n "$pn" '.plugins[] | select(.name == $n)' .claude-plugin/marketplace.json > /dev/null \
      || { echo "$p: no marketplace entry named $pn"; false; }
    mv="$(jq -r --arg n "$pn" '.plugins[] | select(.name == $n) | .version // empty' .claude-plugin/marketplace.json)"
    [ -n "$mv" ] || { echo "$p: marketplace entry $pn has no version"; false; }

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

  # The loop above walks directory -> entry, so an entry whose directory is
  # missing is never visited: a retired plugin's leftover entry, or an entry
  # added ahead of its directory (the exact ordering hazard of landing a
  # second plugin), advertises a broken install while every gate calls it
  # agreement. Walk the other direction too, and pin the two counts to each
  # other so the walks cannot quietly cover different sets.
  entries=0
  while IFS= read -r en; do
    # jq here is a native Windows binary whose stdout is text mode: every line
    # it prints ends `\r\n`. Command substitution strips that trailing CR, but
    # `read` does not, and a name carrying a stray CR matches no marketplace
    # entry. Measured: without this strip, the lookup below returned empty for
    # every entry on this platform, failing a clean tree. A no-op elsewhere.
    en="${en%$'\r'}"
    entries=$((entries + 1))
    es="$(jq -r --arg n "$en" '.plugins[] | select(.name == $n) | .source // empty' .claude-plugin/marketplace.json)"
    ed="${es#./}"; ed="${ed%/}"
    [ -n "$ed" ] && [ -f "$ed/.claude-plugin/plugin.json" ] \
      || { echo "marketplace entry '$en': source '$es' names no plugin directory"; false; }
  done < <(jq -r '.plugins[].name' .claude-plugin/marketplace.json)
  [ "$entries" -eq "$checked" ] || { echo "marketplace lists $entries plugins, the tree holds $checked"; false; }

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
  # Count the links actually resolved, and refuse to pass on zero. Staleness
  # in the list itself — a file moved, a directory renamed out from under a
  # glob — now fails at the entry, in the loop below. The aggregate `checked`
  # pin is what remains for a case those per-entry guards cannot see: every
  # entry resolves, and not one relative link was examined.
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
  for f in README.md CONTRIBUTING.md CHANGELOG.md handoff/README.md handoff/CHANGELOG.md pipeline/README.md pipeline/CHANGELOG.md pipeline/commands/pipeline.md pipeline/docs/*.md handoff/docs/*.md handoff/skills/*/SKILL.md pipeline/skills/*/SKILL.md; do
    # Per entry, not `continue`: one entry going stale — a glob emptying, a
    # file moving — used to be absorbed by the aggregate counter while the
    # other files kept it positive. An unexpanded glob arrives here as its
    # own literal text and fails the same way.
    [ -f "$f" ] || { echo "link-test entry '$f' does not resolve; the list has gone stale"; false; }
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
  [ "$checked" -gt 0 ] || { echo "every listed file resolved, but not one relative link was examined"; false; }
  [ -z "$broken" ] || { echo "broken links:$broken"; false; }
}

@test "every plugin is indexed and installable from the root documents" {
  cd "$ROOT"
  # The version gates check each plugin's changelog, and nothing checked that
  # the root index NAMES it — a plugin added later would get a changelog both
  # gates read and an index entry nobody demanded. Same for the README: the
  # front door must link the plugin and show the exact install string, and
  # the manifest name is what that string must carry.
  checked=0
  for dir in */; do
    p="${dir%/}"
    [ -f "$p/.claude-plugin/plugin.json" ] || continue
    checked=$((checked + 1))
    pn="$(jq -r '.name // empty' "$p/.claude-plugin/plugin.json")"
    grep -qF "($p/CHANGELOG.md)" CHANGELOG.md || { echo "root CHANGELOG.md does not index $p/CHANGELOG.md"; false; }
    grep -qF "($p/README.md)" README.md || { echo "root README.md does not link $p/README.md"; false; }
    grep -qF "/plugin install $pn@delivery-kit" README.md || { echo "root README.md does not show '/plugin install $pn@delivery-kit'"; false; }
  done
  # The root README deep-links to this heading's anchor, and the link test
  # strips '#...' fragments, so a rename breaks that link silently (global
  # constraint; scaffold item 9). Pinned in this gate because this is the
  # test that owns the root documents' promises.
  grep -qF '### Upgrading from `delivery-kit@delivery-kit`' handoff/README.md \
    || { echo "handoff/README.md renamed the upgrade heading the root README deep-links to"; false; }
  [ "$checked" -ge 1 ] || { echo "no plugin directories found under $ROOT"; false; }
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

# 2.0.0 shipped a skill that read only the repository's .delivery-kit.json,
# while the configuration page shipped beside it documented handoff.docsDir in
# the full precedence chain — a user-level value was silently ignored. The
# skill is prose, so the fix is pinned the way this file pins prose: the
# instruction must keep naming all three sources. This cannot prove Claude
# resolves them in order; it proves the order is still on the page.
@test "the handoff skill names every documented source of docsDir" {
  skill="$ROOT/handoff/skills/handoff/SKILL.md"
  grep -qF '~/.delivery-kit.json' "$skill"
  grep -qF '`.delivery-kit.json` at the repository root' "$skill"
  grep -qF 'DELIVERY_KIT_HANDOFF_DIR' "$skill"
}

@test "CI and the contributing guide run every suite in the repository" {
  cd "$ROOT"
  # `-r` recurses beneath the paths it is given, so a suite is covered when
  # the invocation names it OR any ancestor of it — demanding the literal
  # token forced the line to grow for tests/unit/, which bats would then run
  # TWICE, since overlapping path arguments are not deduplicated. Two copies
  # of the command are policed: ci.yml's, and the contributing guide's — the
  # guide's paragraph warns that running a subset "is the failure this
  # project exists to prevent, arriving by way of its own contributing
  # guide", and until this test read the guide, nothing held that copy to it.
  #
  # The `|| true` on each grep is load bearing: under errexit a failing
  # command substitution aborts the test AT THAT LINE, so the named
  # diagnostic below it never runs. It cannot mask a real failure — an empty
  # line is rejected on the next line either way.
  ciline="$(grep -m1 -E '^ *run: *bash .*bats.* -r ' .github/workflows/ci.yml || true)"
  [ -n "$ciline" ] || { echo "no 'run: bash ... bats ... -r' line found in ci.yml"; false; }
  docline="$(grep -m1 -E '^bash .*bats.* -r ' CONTRIBUTING.md || true)"
  [ -n "$docline" ] || { echo "no 'bash ... bats ... -r' command found in CONTRIBUTING.md"; false; }

  # A token inside a trailing comment must not count — not a path token as
  # coverage, and not the flag as the flag ("# --print-output-on-failure was
  # too noisy" must red the guard below, not satisfy it). Strip comments
  # BEFORE the flag guards below inspect the line. The locator greps above
  # match the raw line, so ` -r ` in a trailing comment could satisfy the
  # anchor alone — which is why the guards below also demand ` -r ` in the
  # STRIPPED line: the residual Plan 1 accepted is closed here.
  ciline="${ciline%%#*}"
  docline="${docline%%#*}"

  # Both copies carry the flag that makes a red run legible in a log.
  case "$ciline" in *--print-output-on-failure*) ;; *) echo "ci.yml bats line lost --print-output-on-failure"; false ;; esac
  case "$docline" in *--print-output-on-failure*) ;; *) echo "CONTRIBUTING.md bats command lost --print-output-on-failure"; false ;; esac
  case " $ciline " in *" -r "*) ;; *) echo "ci.yml bats line lost -r after comment-stripping"; false ;; esac
  case " $docline " in *" -r "*) ;; *) echo "CONTRIBUTING.md bats command lost -r after comment-stripping"; false ;; esac

  # Discovery is over TRACKED files — see the SKILL.md test above for why.
  # Dirnames are computed in the shell so a path with a space cannot be split
  # into two bogus names (xargs -n1 dirname word-splits; measured). Residual,
  # accepted: matching tokens against a command line textually means a suite
  # directory literally named `bash` or `-r` would be miscounted as covered —
  # this repository names its suite directories, and names none of them that.
  checked=0
  for line in "$ciline" "$docline"; do
    missing=""
    suites=""
    while IFS= read -r f; do
      d="${f%/*}"; [ "$d" = "$f" ] && d="."
      case " $suites " in *" $d "*) continue ;; esac
      suites="$suites $d"
      checked=$((checked + 1))
      a="$d"; covered=0
      while :; do
        case " $line " in *" $a "*) covered=1; break ;; esac
        case "$a" in */*) a="${a%/*}" ;; *) break ;; esac
      done
      [ "$covered" -eq 1 ] || missing="$missing $d"
    done < <(git ls-files '*.bats')
    [ -z "$missing" ] || { echo "suites not covered by: ${line# *}->$missing"; false; }
  done
  # 2 = two policed lines x at least one suite dir each ($checked counts
  # suite-dirs PER LINE, not suites): this pins discovery non-empty for both
  # copies, not a minimum suite count. Change the set of policed copies and
  # this number changes with it.
  [ "$checked" -ge 2 ] || { echo "no tracked .bats file was found under $ROOT; this gate examined nothing"; false; }
}
