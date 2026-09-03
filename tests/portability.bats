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
# Folding the optional private list into the vocabulary is a NAMED FUNCTION and
# not a few inline lines, for one reason: the file it reads is untracked by
# design, so no public build ever exercises this path. The only thing that can
# exercise it is a test, and a test can only exercise it if it can CALL it.
# It used to be inline, and the test that claimed to cover it rebuilt the same
# join inside itself and checked its own copy — so a defect introduced here was
# not caught by the test named for it. One copy, THREE callers: this line, the
# RELAXED_WORDS line further down, and that test. The third was added as the fix
# for a regression this very extraction caused, and this comment still said two
# until review counted them.
#
# Blank lines are stripped before joining. An empty alternation branch would
# match at every position, turning the scan into something that fires on
# everything — loudly, since the tests assert "no match", but for a reason that
# has nothing to do with a leak. So when the private list contributes nothing -
# absent file, empty file, or only blank lines — the base list comes back
# UNCHANGED, with no trailing separator.
fold_leakwords() {
  local file="$1" base="$2" extra
  [ -f "$file" ] || { printf '%s' "$base"; return 0; }
  extra="$(grep -v '^[[:space:]]*$' "$file" | paste -sd'|' -)"
  if [ -n "$extra" ]; then
    printf '%s|%s' "$base" "$extra"
  else
    printf '%s' "$base"
  fi
}

BANNED_WORDS="$(fold_leakwords "$ROOT/.leakwords" "$BANNED_WORDS")"
# Absolute machine paths, for the SHIPPED surfaces. Its sibling is TREE_PATHS
# below, which covers the whole tracked tree. The two are SEPARATE ON PURPOSE
# and nothing keeps them in step: they scan different surfaces and need
# different tightness, and narrowing this one to match that one would change
# what the shipped scans catch. Changing either is a prompt to look at the
# other — that prompt is this comment, not a mechanism.
BANNED_PATHS='D:\\|/c/Users/|C:\\Users\\|~/\.claude/projects/[A-Za-z0-9-]'

# The same four shapes, for the WHOLE TRACKED TREE rather than the shipped
# surfaces — sibling of BANNED_PATHS above, and separate from it for the
# reasons stated there. Nothing keeps the two in step: they cover different
# surfaces and need different tightness, so a change to either is a prompt to
# open the other and decide, deliberately, whether it wants the same change.
# That prompt is this sentence and the one above BANNED_PATHS. It is a prompt,
# not a mechanism, and no test enforces it.
#
# Why this exists: the shipped lists cover what a stranger installs, and the
# working records under `specs/` and the plan file are not on them. A machine
# username reached the public branch through exactly that hole and multiplied
# to 37 lines across 17 files, because every pipeline run copies its seed into
# `specs/`. BANNED_PATHS was already the right pattern; nothing was pointing it
# at the right surface.
#
# One difference, and it is deliberate: the Git-Bash branch here requires a
# NAME CHARACTER after the prefix. Prose that names the shape with the
# identifying part elided is documentation, not a leak — one such line is the
# recorded deferral of this very sweep — and those references live inside this
# scan's surface, so an unnarrowed branch would delete the paper trail it is
# meant to protect. The narrowing is proven in both directions by the control
# test at the bottom of this file.
#
# Written joined here, and ONLY here. Every other tracked file is inside this
# scan's surface, so a joined literal anywhere else — a spec, a plan, this
# repository's own documentation — becomes a hit on the scan that wrote it.
# Root tests/ is outside the surface by construction, which is what makes this
# line safe to write at all.
# The four branches are named individually so a failure can say WHICH shape
# fired without printing the matched text, and so the control can prove each
# one alive on its own. The alternation is still assembled exactly once, here,
# and both the scan and its control read that one variable.
TP_DRIVE_ROOT='D:\\'
TP_WINDOWS_USERS='C:\\Users\\'
TP_GITBASH_HOME='/c/Users/[A-Za-z0-9_]'
TP_AGENT_PROJECTS='~/\.claude/projects/[A-Za-z0-9-]'
TREE_PATHS="$TP_DRIVE_ROOT|$TP_WINDOWS_USERS|$TP_GITBASH_HOME|$TP_AGENT_PROJECTS"

# What this does NOT cover, recorded because a guard's blind spots belong
# beside it and not in a review nobody re-reads:
#
#   the forward-slash drive form, the msys /d/... form, lowercase drive
#   letters, drive letters other than C: and D:, UNC shares, and POSIX
#   /home/... or /Users/... homes.
#
# Widening to reach them was measured on 2026-08-26 and NOT done. A branch of
# the shape `[A-Za-z]:[\\/]` matches `https://` — the colon-slash in every URL
# in the repository — and an msys branch broad enough to catch `/d/Github`
# also catches `/c/Users/...`, the elided form the narrowing above exists to
# protect. The candidate produced 42 hits over a tree with 0 real ones. A
# pattern that cries wolf gets switched off, so this stays narrow and honest
# rather than wide and disabled. Widening it properly needs its own design
# pass and its own per-branch controls; it is not a thing to bolt onto a
# scrub.

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
# Folded through the SAME function as BANNED_WORDS above, and it must stay that
# way. This line used to read the inline block's `extra` variable, which was a
# file-scope global. The moment that block became a function with a `local
# extra`, this line went dead and the private vocabulary silently stopped
# guarding the relaxed surfaces — which are the ONLY surfaces the shipped lists
# above deliberately exclude. Nothing went red, and nothing could: .leakwords is
# untracked by design, so no public build can ever observe the loss. Caught in
# review, not by a test. Do not reintroduce a shared variable here; call the
# function.
RELAXED_WORDS="$(fold_leakwords "$ROOT/.leakwords" 'supabase|graphify|superpowers')"
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
SHIPPED_ROOT="README.md CONTRIBUTING.md CHANGELOG.md CODE_OF_CONDUCT.md LICENSE .claude-plugin .gitignore .gitattributes .github scripts"
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
# root documents and metadata.
#
# The working record of how this was built is deliberately outside them, and
# stays outside them. Nearly every file under it matches the vocabulary above,
# BY DESIGN — a plan that specifies a detector has to name what the detector
# detects. Registering it would redden the scan on contents that are correct,
# and the only way back to green would be weakening the vocabulary: the wrong
# trade in the wrong direction.
#
# CORRECTED 2026-08-26, because two of this paragraph's facts had gone stale
# and a stale comment about a scan is worse than no comment: a reader trusts it
# and stops checking.
#
#   `docs/specs` no longer exists. The specifications moved to root `specs/`,
#   which IS tracked and IS published — the README advertises those directories
#   as in-repo examples. The old sentence said the release curation keeps them
#   off the published branch. That has not been true since they moved.
#
#   `docs/handoffs` does still exist, and is still untracked — ignored via
#   `.git/info/exclude`, which is per-clone and never leaves the machine.
#
# The consequence was a real leak, not a tidiness problem. Because `specs/` is
# published but on no SHIPPED_* list, BANNED_PATHS never read it, and a machine
# username reached the public branch and multiplied to 37 lines across 17 files
# — every pipeline run copies its seed into `specs/`.
#
# What now covers that surface: TREE_PATHS and the tree-wide scan below, which
# enumerate every tracked file except root tests/. Note precisely what changed
# and what did not. PATHS are now covered everywhere. VOCABULARY is still
# scanned only on the SHIPPED_* surfaces, and that asymmetry is deliberate for
# the reason in the paragraph above: a machine path is never legitimate
# anywhere, while the banned vocabulary is legitimate — necessary, even — in a
# document that specifies a detector.
#
# The property to hold here is still narrower: every plugin directory owns a
# non-empty SHIPPED_* list — that half is pinned by a test below. The other
# half stays a review property no test here checks: no file in the
# installed-and-read surface sits outside one — `.gitignore` sat outside them
# through two reviews while naming a denylisted tool.

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

# The scans above cover what a stranger INSTALLS. This one covers what the
# repository PUBLISHES, which is a wider and differently-shaped surface: every
# tracked file, minus root tests/.
#
# It ENUMERATES rather than registers, and that is the opposite of the choice
# the SHIPPED_* lists make twenty lines up. Both are right for their surface. A
# registration buys "no new tree joins the scan silently", which is what you
# want when the scanned set is a curated subset. Here the scanned set is
# "everything", so a registration would buy nothing and cost the very thing
# that failed before: a file nobody remembered to add.
#
# Three deliberate choices, each of which has a failure mode behind it:
#
#   git ls-files + grep, never `git grep`. Measured: `git grep` exits 1 for a
#   path that does not exist, the same status it uses for "found nothing". It
#   cannot tell a clean repository from one it failed to read, and this whole
#   file rests on that distinction. grep over explicit operands keeps the 2.
#
#   The non-empty guard is not defensive padding. `grep -E pattern` with no
#   file operands reads STDIN — under bats that is a silent pass on nothing at
#   all. It is the same hazard the comment above the SHIPPED lists records for
#   `grep -r` with no path operand, arriving by a different route.
#
#   `-eq 1`, never `-ne 0`, for the reason spelled out above the shipped scans:
#   exit 2 is an errored scan, and accepting it turns a rename into a green.
@test "no machine paths anywhere in the tracked tree" {
  cd "$ROOT"
  files="$(git ls-files -- . ':(exclude)tests/')"
  [ -n "$files" ] || { echo "the tracked-file enumeration returned NOTHING; the scan below would have read stdin and passed on an empty surface"; false; }
  n="$(printf '%s\n' "$files" | wc -l | tr -d '[:space:]')"

  # Coverage, DERIVED — not a threshold, and not a hand-written list.
  #
  # A numeric floor is a magic number a narrowed enumeration walks under:
  # pointing this at `specs/` alone clears any sane floor while leaving most
  # of the tree unscanned. Measured; it passed.
  #
  # A hand-written list of anchor files is barely better, and the first
  # attempt here proved it. Six anchors were chosen — root documents, both
  # plugin trees, the workflow — and `specs/` was not among them. `specs/` is
  # the tree whose absence from the SHIPPED_* lists caused the leak this file
  # exists to stop, and it is on no other list, so it had no protection at
  # all. An enumeration silently narrowed to drop `specs/` passed all six
  # anchors. The list went stale the moment it was written, in exactly the
  # direction that hurts.
  #
  # So the requirement is derived from the tree instead: every top-level
  # tracked entry, except root tests/, must be represented in what we are
  # about to scan. A new top-level directory is covered the day it is added,
  # by nobody remembering anything.
  scanned_top="$(printf '%s\n' "$files" | awk -F/ '{print ($0 ~ /\//) ? $1"/" : $0}' | sort -u)"
  for top in $(git ls-files | awk -F/ '{print ($0 ~ /\//) ? $1"/" : $0}' | sort -u); do
    [ "$top" = "tests/" ] && continue
    printf '%s\n' "$scanned_top" | grep -qxF "$top" || { echo "the enumeration does not reach $top - the scanned surface has narrowed, and every assertion below it would pass on a smaller tree"; false; }
  done
  echo "scanning $n tracked files outside root tests/"

  # NO `run` here, and that is the whole point of this block.
  #
  # `run` stores the command's full output in $output, and bats prints $output
  # verbatim under `--print-output-on-failure` — the flag CI mandates
  # (.github/workflows/ci.yml) and which a test below ASSERTS is present. So a
  # `run grep` here would print every matched line, in full, onto a public
  # build page, at exactly the moment a real machine path exists. The guard
  # would become the loudest publisher of the thing it exists to remove.
  #
  # Measured 2026-08-26 against a planted decoy under the real CI invocation:
  # the redacted site list printed, and then bats printed `Last output:`
  # followed by the complete matching line. Redaction that is reasoned about
  # rather than fired at a decoy is not redaction.
  #
  # So: grep writes to a file, its exit status is read directly, and only
  # file:line ever reaches stdout.
  # The `if` is not stylistic. bats runs each test under `set -e`, so a bare
  # `grep` that exits 1 — the CLEAN case, the case that must pass — aborts the
  # test at that line before its status can be read. That is the service `run`
  # normally provides, and it is the only reason to reach for `run` here. An
  # `if` condition suspends errexit and keeps the status, without ever putting
  # the match into $output. Measured both ways: without the `if`, a clean tree
  # fails at this line.
  if grep -nE "$TREE_PATHS" -- $files /dev/null > "$TEST_DIR/hits.txt"; then st=0; else st=$?; fi

  if [ "$st" -eq 0 ]; then
    echo "machine paths found in the tracked tree."
    echo "The matched text is deliberately NOT printed - it IS the leak, and"
    echo "this output reaches a public build log. Shape and site only:"
    # Name the SHAPE as well as the site. The four shapes have four different
    # fixes, and a bare file:line leaves the reader to guess which. A shape's
    # NAME republishes nothing.
    for shape in DRIVE_ROOT WINDOWS_USERS GITBASH_HOME AGENT_PROJECTS; do
      eval "pat=\$TP_$shape"
      hits="$(grep -E "$pat" "$TEST_DIR/hits.txt" | cut -d: -f1,2 | sort -u)"
      [ -n "$hits" ] || continue
      echo "  shape $shape:"
      printf '    %s\n' $hits
    done
  fi
  [ "$st" -eq 1 ]
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
  # The logic this test used to hold inline now lives in scripts/check-versions.sh,
  # and ci.yml's version job calls the same file. Those two copies were kept in
  # step BY HAND and drifted once — an unanchored regex in one accepted a
  # changelog heading the other rejected — and the drift was invisible until a
  # release. One implementation is the only arrangement that cannot drift.
  #
  # The test KEEPS ITS NAME across that change on purpose: the suite's own
  # record of what it covers stays continuous, and a reader diffing releases
  # sees a body change rather than a coverage change.
  #
  # `cd "$ROOT"` above is not incidental. The script asserts its working
  # directory holds the marketplace manifest and refuses otherwise, so a caller
  # starting somewhere else gets a named refusal instead of a walk over zero
  # plugins that passes having verified nothing.
  #
  # `run` rather than a bare call: on failure the script's diagnostic is in
  # $output, and --print-output-on-failure puts it in the log. A bare call under
  # errexit would abort the test with the status alone.
  run bash scripts/check-versions.sh
  [ "$status" -eq 0 ]

  # It must have REPORTED, not merely exited zero. The script prints one line
  # per plugin naming the three versions it compared; a run that produced none
  # of them examined nothing.
  case "$output" in
    *plugin=*) ;;
    *) echo "the script exited 0 without reporting a single plugin. output: $output"; false ;;
  esac

  # And it must be CAPABLE of failing. Everything above is satisfied by a
  # script whose entire body is `exit 0` — measured in review, where exactly
  # that substitution left this suite green with all twelve checks deleted.
  # Moving logic out of a test file moves it out of the diff a reviewer reads,
  # so the gate has to prove the thing it delegates to still bites.
  #
  # TWO breaks, not one, and each chosen so that exactly ONE comparison in the
  # script can see it. A single break that disagrees with two recorded places
  # is caught by either comparison, so deleting one of them leaves this test
  # green — measured, on the first version of this fixture. The pair closes
  # that: break the marketplace entry and only plugin-vs-marketplace fires;
  # break the changelog heading and only plugin-vs-changelog fires.
  #
  # Be exact about what this still does not prove: the script has twelve
  # checks and this exercises two of them. The full per-check sweep lives in
  # the run record, not in the suite, because the suite's size is fixed here.
  #
  # The fixture is built from the marketplace's OWN source list rather than by
  # re-walking */ here: a second copy of the discovery rule, inside the test
  # that exists because a second copy of this logic drifted, would be a poor
  # joke. Every plugin is copied so the script's count reconciliation is
  # satisfied and a failure can only come from the value deliberately broken.
  base="$TEST_DIR/version-fire-base"
  mkdir -p "$base/.claude-plugin"
  cp .claude-plugin/marketplace.json "$base/.claude-plugin/marketplace.json"
  copied=""
  while IFS= read -r src; do
    src="${src%$'\r'}"
    d="${src#./}"; d="${d%/}"
    mkdir -p "$base/$d/.claude-plugin"
    cp "$d/.claude-plugin/plugin.json" "$base/$d/.claude-plugin/plugin.json"
    cp "$d/CHANGELOG.md" "$base/$d/CHANGELOG.md"
    [ -n "$copied" ] || copied="$d"
  done < <(jq -r '.plugins[].source' .claude-plugin/marketplace.json)

  # A fixture built over nothing proves nothing — the same non-empty
  # discipline the scans below apply to their own operands.
  [ -n "$copied" ] || { echo "the fire-proof fixture copied no plugin; it proves nothing"; false; }

  # The faithful copy must PASS. Without this, a fixture broken by accident of
  # construction would make both breaks below succeed for the wrong reason.
  run bash -c "cd \"$base\" && bash \"$ROOT/scripts/check-versions.sh\""
  [ "$status" -eq 0 ] \
    || { echo "the untouched fire-proof fixture already fails; the breaks below would prove nothing. output: $output"; false; }

  # Break 1 — the MARKETPLACE entry's version. The manifest and the changelog
  # still agree with each other, so only plugin-vs-marketplace can see this.
  m="$TEST_DIR/version-fire-marketplace"
  cp -r "$base" "$m"
  jq --arg n "$copied" '.plugins |= map(if .name == $n then .version = "0.0.0-fireproof" else . end)' \
    "$base/.claude-plugin/marketplace.json" > "$m/.claude-plugin/marketplace.json"
  run bash -c "cd \"$m\" && bash \"$ROOT/scripts/check-versions.sh\""
  [ "$status" -ne 0 ] \
    || { echo "the script accepted $copied with its MARKETPLACE version changed to 0.0.0-fireproof; the plugin-vs-marketplace check is not running"; false; }
  case "$output" in
    *0.0.0-fireproof*) ;;
    *) echo "the script rejected the marketplace break, but not for the planted value. output: $output"; false ;;
  esac

  # Break 2 — the CHANGELOG heading. The manifest and the marketplace still
  # agree with each other, so only plugin-vs-changelog can see this.
  c="$TEST_DIR/version-fire-changelog"
  cp -r "$base" "$c"
  # awk, not `sed -i`. BSD sed — which is macos-latest's sed — requires an
  # argument after -i and has no address 0, so the GNU one-liner this replaces
  # failed there with "invalid command code" while passing on the other two
  # platforms. Measured on CI, not guessed: the first version of this fixture
  # went green locally and red on macos alone.
  # The guard matches the SAME anchored shape check-versions.sh parses, not a
  # looser one. A looser guard rewrote headings the script never reads — one
  # carrying a trailing parenthetical, say — and the test then accused a
  # working check of not running. That trailing-parenthetical heading is the
  # exact divergence this whole change exists to end, so planting on it was
  # the worst available way to be wrong.
  awk 'done != 1 && /^## \[[0-9]+[.][0-9]+[.][0-9]+\] - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { sub(/^## \[[0-9]+[.][0-9]+[.][0-9]+\]/, "## [9.9.9]"); done = 1 } { print }' \
    "$c/$copied/CHANGELOG.md" > "$c/$copied/CHANGELOG.new"
  mv "$c/$copied/CHANGELOG.new" "$c/$copied/CHANGELOG.md"
  grep -q '^## \[9\.9\.9\] - ' "$c/$copied/CHANGELOG.md" \
    || { echo "the changelog break did not land in the $copied fixture; the assertion below would prove nothing"; false; }
  run bash -c "cd \"$c\" && bash \"$ROOT/scripts/check-versions.sh\""
  [ "$status" -ne 0 ] \
    || { echo "the script accepted $copied with its CHANGELOG heading changed to 9.9.9; the plugin-vs-changelog check is not running"; false; }
  case "$output" in
    *changelog=9.9.9*) ;;
    *) echo "the script rejected the changelog break, but not for the planted value. output: $output"; false ;;
  esac
}

# The gate above and ci.yml's version job used to hold two copies of one piece
# of logic. The workflow's own comment said they were kept in step BY HAND and
# had drifted once already. Nothing held them together, so nothing noticed.
#
# This test is what now holds them together. It asserts the two callers name
# ONE script, and — separately — that neither has quietly grown an inline copy
# beside the call, which is the arrangement a well-meaning revert produces and
# which every other assertion here would accept.
@test "one version-agreement script, and both gates call it" {
  cd "$ROOT"

  # The invocation must live INSIDE the version gate, not merely somewhere in
  # this file. Measured in review: gutting the gate's body to `true` and parking
  # the invocation in an unrelated test left this test green while the suite
  # carried no version coverage at all — `grep -m1` binds to the first match in
  # the file, and the first match is not necessarily the gate's.
  #
  # So map each invocation to the @test block that encloses it, and require
  # exactly one, owned by the gate. awk carries the current block's name
  # forward; the name is compared as a STRING, not matched as a pattern, so the
  # apostrophe in it needs no escaping and cannot behave as a metacharacter.
  gate_name="every plugin's manifest, marketplace entry and changelog agree"
  owned="$(awk '
    /^@test "/ { name = $0; sub(/^@test "/, "", name); sub(/" \{$/, "", name) }
    /^[[:space:]]*run[[:space:]]+bash[[:space:]]+[^[:space:]]+\.sh/ {
      # match(), not the last field of split(). Stripping a trailing comment
      # leaves trailing whitespace, and split() then emits an EMPTY final
      # field — so a call written with a trailing comment yielded an empty
      # path and reddened a CORRECT tree with "the two gates call different
      # scripts: suite=". Reproduced before this line was changed. match()
      # takes the path itself and cannot pick up a comment, because the
      # pattern it matches contains no whitespace.
      if (match($0, /[^[:space:]]+[.]sh/)) {
        print name "\t" substr($0, RSTART, RLENGTH)
      }
    }
  ' tests/portability.bats)"
  [ -n "$owned" ] || { echo "no 'run bash <script>.sh' invocation found in tests/portability.bats"; false; }
  [ "$(printf '%s\n' "$owned" | wc -l)" -eq 1 ] \
    || { echo "expected exactly one 'run bash <script>.sh' invocation in this file, found:"; printf '%s\n' "$owned"; false; }
  owner="${owned%%$'\t'*}"
  suite_path="${owned##*$'\t'}"
  [ "$owner" = "$gate_name" ] \
    || { echo "the invocation of $suite_path lives in '$owner', not in the version gate '$gate_name'"; false; }

  # The workflow side. Accept the invocation whether it sits on the `run:` line
  # or inside a block scalar beneath one, so that adding a `set -x` to the step
  # cannot red this test on a workflow that is still correct. Require exactly
  # one, for the same binding reason as above.
  ci_all="$(grep -oE '^[[:space:]]*(run:[[:space:]]*)?bash[[:space:]]+[^[:space:]]+\.sh' .github/workflows/ci.yml || true)"
  [ -n "$ci_all" ] || { echo "no 'bash <script>.sh' invocation found in .github/workflows/ci.yml"; false; }
  [ "$(printf '%s\n' "$ci_all" | wc -l)" -eq 1 ] \
    || { echo "expected exactly one 'bash <script>.sh' invocation in ci.yml, found:"; printf '%s\n' "$ci_all"; false; }
  ci_path="${ci_all##*[[:space:]]}"

  # Compare what the two callers NAME, not how they spelled the path: `./x.sh`
  # and `x.sh` are the same file and must not read as a disagreement.
  [ "${suite_path#./}" = "${ci_path#./}" ] \
    || { echo "the two gates call different scripts: suite=$suite_path ci=$ci_path"; false; }
  [ -s "$suite_path" ] \
    || { echo "both gates name '$suite_path', which is not a non-empty file"; false; }

  # Calling the script while ALSO keeping an inline copy satisfies everything
  # above and restores exactly the hazard this test exists to close. So assert
  # the absence of the logic in both callers, by a marker only the
  # implementation has reason to carry: the by-name selection of a marketplace
  # entry, which is the heart of the walk.
  #
  # A REGEX, not a fixed string, and tolerant of the whitespace around the
  # operator: measured in review, a re-typed inline copy that closed up the
  # spaces around the equality — one character different — evaded a
  # fixed-string marker completely. This widens the net; it does not make it
  # complete, and the limit is stated plainly below rather than left for a
  # reader to discover.
  #
  # This comment deliberately DESCRIBES that spelling instead of showing it.
  # Written out, the example would sit in a file this test greps, and the
  # test would report its own comment as an inline copy — which is exactly
  # what happened on the first attempt.
  #
  # The regex cannot match the line that defines it: that line spells the
  # parenthesis escaped, so the literal the pattern requires is not present.
  # If that were ever wrong the failure is a RED on a correct tree, never a
  # green on a broken one.
  marker='select\(\.name[[:space:]]*==[[:space:]]*\$n\)'
  for f in tests/portability.bats .github/workflows/ci.yml; do
    if grep -qE -- "$marker" "$f"; then
      echo "$f holds the version-agreement logic inline as well as calling $suite_path"
      false
    fi
  done

  # A marker that has quietly stopped matching reports both callers clean and
  # proves nothing — the same failure shape as a denylist that has stopped
  # working. Fire it against the implementation, where it MUST match, before
  # believing the two absences above.
  grep -qE -- "$marker" "$suite_path" \
    || { echo "the inline-copy marker matched nothing in $suite_path; this test's copy detection is dead"; false; }

  # What this test does NOT prove, said out loud so no reader infers more from
  # a green than it carries: it is textual. It cannot see that the workflow
  # step is reached — a step disabled with `if: false` still satisfies every
  # assertion above — and a copy rewritten to select an entry some other way
  # carries no marker to find. It closes the drift that actually happened, and
  # the literal revert that would bring it back.
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

# The control for TREE_PATHS, and it runs THAT VARIABLE — not a copy of it and
# not a re-spelling. A control that exercises a different expression proves
# nothing about the scan, which is the same reason VOCAB_RE exists above.
#
# What this proves: the scan is CAPABLE of failing. What it does NOT prove:
# that the scan fails only when it should. Those are different claims and only
# the first is tested here. Read it as the first and nothing more.
#
# It counts FOUR matches rather than asserting "matched something", and the
# fixture carries one line per branch. A single-line fixture would pass while
# three of the four branches were dead, and a dead branch is invisible from a
# green suite: the real scan asserts only the ABSENCE of a hit, so an
# expression that has quietly stopped matching reads exactly like a clean tree.
# That is not hypothetical here. On 2026-08-26, while this feature was being
# written, the same four branches were measured DEAD (0/0/0/0) because the
# authoring route ate one level of backslash escaping; the file itself was
# correct all along. The measurement lied, not the pattern. Counting per branch
# is what turns that class of mistake into a red instead of a false green.
#
# The fixtures are synthetic. A real machine path has no business in a
# committed file, and a fabricated one demonstrates the point identically.
@test "the tree-wide machine-path scan fires on every one of its four shapes" {
  {
    printf 'drive root      D:\\Github\\thing\n'
    printf 'windows users   C:\\Users\\someone\\thing\n'
    printf 'git-bash home   /c/Users/someone/bats/bin/bats\n'
    printf 'agent projects  ~/.claude/projects/D--Acme-Widget/memory/MEMORY.md\n'
  } > "$TEST_DIR/tree_paths.txt"
  # `run` is safe HERE and nowhere else in this pair. The scan above must not
  # use it, because $output would carry a real machine path onto a public
  # build log; these fixtures are synthetic, so there is nothing to leak.
  run grep -cE "$TREE_PATHS" "$TEST_DIR/tree_paths.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "4" ]

  # And per branch, by name. The count above proves four lines matched
  # SOMETHING; this proves each branch is the one that matched its own line.
  # Without it, two branches could cover one fixture line while a third was
  # dead and the total still read 4.
  for shape in DRIVE_ROOT WINDOWS_USERS GITBASH_HOME AGENT_PROJECTS; do
    eval "pat=\$TP_$shape"
    run grep -cE "$pat" "$TEST_DIR/tree_paths.txt"
    [ "$status" -eq 0 ] || { echo "branch $shape matched nothing - it is dead, and the scan would report a clean tree it never really searched"; false; }
    [ "$output" = "1" ] || { echo "branch $shape matched $output fixture lines, expected exactly 1"; false; }
  done

  # The narrowing, in the other direction. An elided reference names the shape
  # without naming a person, and such lines are live documentation inside the
  # scanned surface, and one of them is the recorded deferral of this very
  # sweep. Without this assertion, narrowing the pattern and deleting the
  # narrowing look identical. This is an assertion inside the control rather
  # than a test of its own on purpose: it is the same claim about the same
  # expression, and splitting it would add a test without adding a property.
  # One elided line per NARROWED branch. Branch 3 was covered from the start;
  # branch 4 was not, and its narrowing survived a mutation as a result —
  # removing the trailing character class left this control green and was
  # caught only by prose elsewhere in the tree that a reword could delete.
  # A narrowing with no control is a narrowing that can be removed silently.
  {
    printf 'the prefix /c/Users/... names the shape, not a person\n'
    printf 'transcripts live under `~/.claude/projects/`, one per project\n'
  } > "$TEST_DIR/elided.txt"
  run grep -nE "$TREE_PATHS" "$TEST_DIR/elided.txt"
  [ "$status" -eq 1 ]
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
  # nothing in CI exercises it and it would rot unnoticed. This drives the REAL
  # folding — fold_leakwords, the very function the suite calls at load time -
  # against a fixture, and checks the things that have each been a real failure
  # mode here: the extra term is matched; a blank line does not produce an empty
  # alternation branch that matches everything; and the shipped terms still work
  # alongside it.
  #
  # It used to rebuild the join inside itself and check its own copy, which meant
  # a defect introduced in the real folding was NOT caught by the test named for
  # it. If you are tempted to inline the pipeline here again for readability:
  # that is the bug, not the style.
  # TWO terms, not one. With a single term the join in fold_leakwords is never
  # asked to join anything, so a mutation changing its separator character
  # stayed green — measured in review. Two terms make the separator
  # load-bearing.
  printf 'acmecorp\nnorthwind\n\n  \n' > "$TEST_DIR/.leakwords"
  folded="$(fold_leakwords "$TEST_DIR/.leakwords" "$BANNED_WORDS")"
  # Exact equality, not a suffix match. A suffix match accepts an INTERIOR empty
  # branch, and an empty branch matches at every position — the precise failure
  # the blank-line stripping exists to prevent.
  [ "$folded" = "$BANNED_WORDS|acmecorp|northwind" ]
  re="($folded)"

  printf 'we use acmecorp internally\n' > "$TEST_DIR/private.txt"
  run grep -rniwE "$re" "$TEST_DIR/private.txt"
  [ "$status" -eq 0 ]

  printf 'northwind is ours too\n' > "$TEST_DIR/second.txt"
  run grep -rniwE "$re" "$TEST_DIR/second.txt"
  [ "$status" -eq 0 ]

  printf 'nothing to see here\n' > "$TEST_DIR/clean.txt"
  run grep -rniwE "$re" "$TEST_DIR/clean.txt"
  [ "$status" -eq 1 ]

  printf 'a flutter reference\n' > "$TEST_DIR/stack.txt"
  run grep -rniwE "$re" "$TEST_DIR/stack.txt"
  [ "$status" -eq 0 ]

  # The empty-contribution case, which is what makes a blank line safe: a list
  # that contributes nothing returns the base UNCHANGED — no trailing separator,
  # and so no empty branch that would match at every position.
  : > "$TEST_DIR/empty.leakwords"
  [ "$(fold_leakwords "$TEST_DIR/empty.leakwords" "$BANNED_WORDS")" = "$BANNED_WORDS" ]
  printf '\n  \n\n' > "$TEST_DIR/blank.leakwords"
  [ "$(fold_leakwords "$TEST_DIR/blank.leakwords" "$BANNED_WORDS")" = "$BANNED_WORDS" ]
  # And an absent file, which is the state of every public build.
  [ "$(fold_leakwords "$TEST_DIR/nope.leakwords" "$BANNED_WORDS")" = "$BANNED_WORDS" ]
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

  # The bats VERSION is a second cross-copy agreement, and this change is what
  # created it. Removing the version-gate twin added one here: the pin's commit
  # in ci.yml, the release name in the comment above it, and the clone command
  # in each of the two documents. Bump the pin and forget the rest and CI runs
  # one bats while every contributor runs another, with nothing going red —
  # the same drift class, one dependency over.
  #
  # This is asserted HERE, inside the test that already polices these two files
  # against each other, rather than as a test of its own: the suite's size is
  # fixed by this feature's own stated delta, and this belongs to the property
  # this test already owns.
  #
  # The commit hash is deliberately NOT checked against the network. A gate that
  # needs the internet to pass is a gate that fails on a bad afternoon. What is
  # checked is that the three human-readable copies agree; re-deriving the hash
  # is a release-time act, and the comment beside the pin says how.
  civer="$(grep -m1 -oE '^ *# bats-core v[0-9]+\.[0-9]+\.[0-9]+' .github/workflows/ci.yml | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || true)"
  [ -n "$civer" ] || { echo "no '# bats-core vX.Y.Z' release name found beside the pin in ci.yml"; false; }
  for doc in CONTRIBUTING.md README.md; do
    docver="$(grep -m1 -oE '[-][-]branch v[0-9]+[.][0-9]+[.][0-9]+' "$doc" | grep -oE 'v[0-9]+[.][0-9]+[.][0-9]+' || true)"
    [ -n "$docver" ] || { echo "no '--branch vX.Y.Z' bats clone command found in $doc"; false; }
    [ "$docver" = "$civer" ] \
      || { echo "$doc clones bats $docver but ci.yml pins $civer; the pin and the documented command have drifted"; false; }
  done
  # And the pin itself must be present and shaped like a commit, so that
  # deleting it cannot leave the three release names agreeing about nothing.
  pin="$(grep -m1 -oE '^ *BATS_PIN: [0-9a-f]{40}$' .github/workflows/ci.yml | grep -oE '[0-9a-f]{40}' || true)"
  [ -n "$pin" ] || { echo "no 40-character BATS_PIN found in ci.yml; the release names above agree about nothing"; false; }
}

# ---------------------------------------------------------------------------
# The three gaps this repository recorded at the 1.2.0 / 2.1.1 release and did
# not close then. Each test below fires the break FIRST and requires the gate to
# refuse it, because a gate that has only ever passed has not been shown capable
# of failing.
#
# Every invocation here uses `run bash -c "... && bash <script> ..."`, never
# `run bash <script>` at the start of a line. That is not cosmetic: the
# "one version-agreement script" test above requires EXACTLY ONE
# `run bash <path>.sh` in this file and asserts which @test owns it. A second
# such line would redden a correct tree.
# ---------------------------------------------------------------------------

@test "--released refuses a dangling Unreleased heading, and the default run does not" {
  cd "$ROOT"

  # Build a faithful copy first and require it to PASS. Without this, a fixture
  # broken by accident of construction makes the break below succeed for the
  # wrong reason.
  base="$TEST_DIR/released-base"
  mkdir -p "$base/.claude-plugin"
  cp .claude-plugin/marketplace.json "$base/.claude-plugin/marketplace.json"
  copied=""
  while IFS= read -r src; do
    src="${src%$'\r'}"
    d="${src#./}"; d="${d%/}"
    mkdir -p "$base/$d/.claude-plugin"
    cp "$d/.claude-plugin/plugin.json" "$base/$d/.claude-plugin/plugin.json"
    cp "$d/CHANGELOG.md" "$base/$d/CHANGELOG.md"
    [ -n "$copied" ] || copied="$d"
  done < <(jq -r '.plugins[].source' .claude-plugin/marketplace.json)
  [ -n "$copied" ] || { echo "the fixture copied no plugin; it proves nothing"; false; }

  # NORMALISE the fixture into a known RELEASED state before asserting anything.
  # An earlier version of this test skipped this and required the faithful copy
  # to pass --released as it stood — which coupled the test to whether this
  # repository happened to have unreleased work at the moment it ran. It went
  # red the first time anyone opened an `## [Unreleased]` heading, which is the
  # normal condition of this repository and not a defect at all. The fixture
  # must supply its own baseline, never borrow the tree's.
  for f in "$base"/*/CHANGELOG.md; do
    grep -v '^## \[Unreleased\]$' "$f" > "$f.norm" && mv "$f.norm" "$f"
  done
  [ -z "$(grep -l '^## \[Unreleased\]$' "$base"/*/CHANGELOG.md 2>/dev/null)" ] \
    || { echo "normalisation did not land; the fixture is not in a released state"; false; }

  run bash -c "cd \"$base\" && bash \"$ROOT/scripts/check-versions.sh\" --released \"$copied\""
  [ "$status" -eq 0 ] \
    || { echo "the normalised fixture already fails --released; the break below would prove nothing. output: $output"; false; }

  # Plant an `## [Unreleased]` heading ABOVE the released one. Every version
  # value still agrees; only the ordering is wrong.
  d="$TEST_DIR/released-dangling"
  cp -r "$base" "$d"
  awk 'done != 1 && /^## \[[0-9]+[.][0-9]+[.][0-9]+\] - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { print "## [Unreleased]"; print ""; done = 1 } { print }' \
    "$d/$copied/CHANGELOG.md" > "$d/$copied/CHANGELOG.new"
  mv "$d/$copied/CHANGELOG.new" "$d/$copied/CHANGELOG.md"

  # Prove the plant landed, and landed ABOVE. A mutation that did not land is a
  # silent false green.
  first="$(grep -m1 '^## ' "$d/$copied/CHANGELOG.md")"
  [ "$first" = "## [Unreleased]" ] \
    || { echo "the plant did not land first in the $copied fixture; got '$first'"; false; }

  # The DEFAULT run must still pass. This is not slack — it is the documented
  # blindness, asserted so that closing it silently would redden this test and
  # force the change to be stated.
  run bash -c "cd \"$d\" && bash \"$ROOT/scripts/check-versions.sh\""
  [ "$status" -eq 0 ] \
    || { echo "the default run rejected a dangling heading; that is a behaviour change this test exists to make visible. output: $output"; false; }
  case "$output" in
    *UNRELEASED-ABOVE*) ;;
    *) echo "the default run passed but did not REPORT the dangling heading. output: $output"; false ;;
  esac

  # And --released must refuse it.
  run bash -c "cd \"$d\" && bash \"$ROOT/scripts/check-versions.sh\" --released \"$copied\""
  [ "$status" -ne 0 ] \
    || { echo "--released accepted $copied with an Unreleased heading above its release; the check is not running"; false; }
  case "$output" in
    *"is NOT released"*) ;;
    *) echo "--released refused, but not for the planted reason. output: $output"; false ;;
  esac
}

@test "--released refuses a plugin name that matches nothing, rather than enforcing nothing" {
  cd "$ROOT"
  # A caller asking for a STRICTER check must never receive a weaker one. With
  # no plugin matching the name, the enforcement runs zero times, and a walk
  # over zero items reports zero problems.
  run bash -c "cd \"$ROOT\" && bash \"$ROOT/scripts/check-versions.sh\" --released definitely-not-a-plugin"
  [ "$status" -ne 0 ] \
    || { echo "--released accepted a plugin name matching nothing and enforced nothing. output: $output"; false; }
  case "$output" in
    *"nothing was enforced"*) ;;
    *) echo "it refused, but not for the vacuous-enforcement reason. output: $output"; false ;;
  esac
}

@test "a TRAILING malformed marketplace entry cannot escape the reverse walk" {
  cd "$ROOT"
  # The reverse walk used to be fed by a process substitution, whose exit status
  # `set -e` cannot see: the shell waits for the loop, not for the producer. A
  # marketplace whose SECOND entry is malformed made jq emit the first line,
  # error on the second and exit non-zero, while the script read the one good
  # line, reconciled its counts and exited 0 — never validating the bad entry's
  # `source`, which named a directory that did not exist. A LEADING malformed
  # entry died correctly, so only trailing ones escaped.
  t="$TEST_DIR/trailing-malformed"
  mkdir -p "$t/.claude-plugin"
  first_src="$(jq -r '.plugins[0].source' .claude-plugin/marketplace.json)"
  d="${first_src#./}"; d="${d%/}"
  mkdir -p "$t/$d/.claude-plugin"
  cp "$d/.claude-plugin/plugin.json" "$t/$d/.claude-plugin/plugin.json"
  cp "$d/CHANGELOG.md" "$t/$d/CHANGELOG.md"
  jq '{name: "fixture", plugins: [ .plugins[0], {name: {obj: 1}, source: "./ghost", version: "9.9.9"} ]}' \
    .claude-plugin/marketplace.json > "$t/.claude-plugin/marketplace.json"

  # The ghost directory must NOT exist, or the entry would be legitimately valid
  # and this fixture would prove nothing.
  [ ! -d "$t/ghost" ] || { echo "the ghost directory exists; the fixture proves nothing"; false; }

  run bash -c "cd \"$t\" && bash \"$ROOT/scripts/check-versions.sh\""
  [ "$status" -ne 0 ] \
    || { echo "the script exited 0 on a marketplace whose trailing entry jq could not read, having never validated it. output: $output"; false; }
}

@test "only spec-kit scaffolding is tracked under .claude/" {
  cd "$ROOT"
  # `.git/info/exclude` lists `.claude/` and describes it as never published.
  # That is false and cannot be made true by editing the comment: gitignore
  # never applies to already-tracked paths, and this tree tracks files there.
  # What IS true, and what this test pins, is that everything tracked under
  # .claude/ is public spec-kit scaffolding.
  #
  # Matched by PATTERN, never against a list of names. A list goes stale the day
  # spec-kit adds a command, and it goes stale in the direction that stops the
  # check noticing the file nobody meant to commit.
  tracked="$(git ls-files '.claude/*')"
  [ -n "$tracked" ] || skip "nothing is tracked under .claude/ in this checkout"
  bad=""
  while IFS= read -r f; do
    f="${f%$'\r'}"
    case "$f" in
      .claude/skills/speckit-*/SKILL.md) ;;
      *) bad="$bad$f"$'\n' ;;
    esac
  done <<< "$tracked"
  [ -z "$bad" ] || { echo "unexpected tracked path(s) under .claude/ — only spec-kit SKILL.md files belong there:"; printf '%s' "$bad"; false; }
}
