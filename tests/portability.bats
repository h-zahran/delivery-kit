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
      resolved="$(dirname "$f")/$target"
      if [ ! -e "$resolved" ]; then
        broken="$broken $f->$link"
        continue
      fi
      # The ANCHOR half. Until 2026-09-03 this test stripped `#...` and checked
      # only that the file existed, so a link to a real document and a heading
      # that was never there resolved clean. Measured with a deliberately broken
      # anchor: reported ok. A link that lands on the right page and the wrong
      # place is the failure a reader actually meets, and it is the half that
      # rots first, because headings get reworded and links do not.
      #
      # Slugged the way GitHub does it: lowercase, drop everything that is not
      # a letter, digit, space or hyphen — which is what removes the backticks
      # and the `@` in a heading like "Upgrading from `delivery-kit@delivery-kit`"
      # — then spaces to hyphens.
      anchor="${link#*#}"
      [ "$anchor" != "$link" ] && [ -n "$anchor" ] || continue
      [ -f "$resolved" ] || continue
      if ! grep -E '^#{1,6} ' "$resolved" \
          | sed -E 's/^#+ +//' \
          | tr '[:upper:]' '[:lower:]' \
          | sed -E 's/[^a-z0-9 -]//g; s/ +/-/g' \
          | grep -qxF "$anchor"; then
        broken="$broken $f->$link"
      fi
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
# Every invocation here uses `run bash -c '... && bash <script> ...' _ <args>`,
# with every path and name passed as an argument (U1), never
# `run bash <script>` at the start of a line. That is not cosmetic: the
# "one version-agreement script" test above requires EXACTLY ONE
# `run bash <path>.sh` in this file and asserts which @test owns it. A second
# such line would redden a correct tree.
# ---------------------------------------------------------------------------

# Put every changelog under <dir> into a RELEASED state: drop every line
# that could be, or could start or end, a level-2 heading the release form
# refuses. Removing one spelling, `## [Unreleased]`, was not enough once the
# gate judged every `## ` line, and removing every line beginning `## ` was
# not enough once it judged every heading form: a live `> ## Notes`, a
# setext underline or an unclosed fence would survive into the fixture and
# redden a correct tree.
#
# The rule is WIDER than the gate's, never narrower, so whatever the gate
# refuses this has removed: from a copy of each line it strips, one at a
# time and again and again, leading spaces and tabs, `>` markers and list
# markers, and tests the line before the first strip and after every one.
# A line is dropped when any of those forms is a fence line (three
# backticks or tildes), a run of `-` (an underline), or `##` then a space, a
# tab or the end, unless the raw line is a dated heading. Testing between
# strips matters: a bare `-` is an underline, and stripping it as a list
# marker would leave an empty string that is kept. The rule keeps NO state:
# it never asks whether a fence or a list item is open, because a fixture
# that tracked that would be a second copy of the gate's walk. Dropping
# every fence line leaves no fence open, and dropping every `##` line at
# any depth leaves no container or deep line for the gate to find.
#
# The dated pattern is the TEST's own, the one the plant steps below use
# (here in bracket spelling, as it reaches awk as a string), and never read
# from the gate: the fixture is the baseline the
# gate is judged against, so it must not depend on the code under test. A
# fixture that took the gate's pattern would agree with a wrong gate, and
# against a gate written another way (the quickstart's first-heading-only
# mutant) it failed as a fixture error instead of naming G1.
#
# Each failure echoes and returns 1 explicitly. Call this on its own line at
# the top level of a test, never under `if`, `||` or `$(...)`: errexit is
# inert there, and the message would be swallowed. Messages name a changelog
# by its plugin directory, never by a full path.
#
# Two more kinds of line are dropped, each a line the gate refuses whatever
# it holds: one holding a CR byte, and one longer than the gate's line
# limit. The helper keeps its own copy of that limit, LIMIT below, and
# never reads the gate's (FR-017). Both awk and the check below run under
# the C locale, so a length is a count of bytes, as the gate counts it.
normalise_to_released() {
  local re f name prog LIMIT=1000 LC_ALL=C
  re='^## [[][0-9]+[.][0-9]+[.][0-9]+[]] - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$'
  # It prints the lines it keeps. No `$` inside a group, and no interval
  # expression, for the awks CI runs.
  prog='
    function wide(s) {
      return s ~ /^```/ || s ~ /^~~~/ || s ~ /^-+[ \t]*$/ || s ~ /^##$/ || s ~ /^##[ \t]/
    }
    function hit(s) {
      if (wide(s)) return 1
      for (;;) {
        if (!sub(/^[ \t]/, "", s) && !sub(/^>[ \t]?/, "", s) \
            && !sub(/^([-*+]|[0-9]+[.)])[ \t]/, "", s) && !sub(/^([-*+]|[0-9]+[.)])$/, "", s)) return 0
        if (wide(s)) return 1
      }
    }
    index($0, "\r") || length($0) > ENVIRON["LIMIT"] + 0 { next }
    $0 ~ ENVIRON["DATED_RE"] || !hit($0) { print }
  '
  # The pattern must separate the two kinds before it may judge anything: one
  # that matched every heading would remove nothing and leave the guard below
  # green on a fixture that is not released.
  [ "$(printf '%s\n' '## [1.2.3] - 2026-01-01' '## [Unreleased]' \
        | DATED_RE="$re" awk '$0 ~ ENVIRON["DATED_RE"] { printf "%s;", NR }')" = "1;" ] \
    || { echo "fixture: the dated pattern does not accept a dated heading and refuse '## [Unreleased]'"; return 1; }
  for f in "$1"/*/CHANGELOG.md; do
    name="${f#"$1"/}"
    [ -f "$f" ] || { echo "fixture: no changelog in the fixture"; return 1; }
    # LC_ALL=C on the command, not only the `local` above: a local is not
    # exported, so awk would count characters in the caller's locale.
    DATED_RE="$re" LIMIT="$LIMIT" LC_ALL=C awk "$prog" "$f" > "$f.norm" \
      || { echo "fixture: awk could not normalise $name"; return 1; }
    mv "$f.norm" "$f" \
      || { echo "fixture: could not replace $name with its normalised copy"; return 1; }
    # The state, not the act: see released_state, run in a child bash.
    LC_ALL=C bash -c "$(declare -f released_state); released_state \"\$@\"" _ "$f" "$LIMIT" "$re" "$name" \
      || return 1
  done
}

# released_state <file> <limit> <dated pattern> <name>: the state, not the
# act. Released means no line is left that the gate could refuse, AND a
# dated heading still is. A rule that matched everything would have deleted
# every heading; the dated count catches that. This check is bash, not the
# awk program in normalise_to_released: a second reader of the file, so a
# fault in that program cannot also hide itself here. It runs in a child
# bash, under the C locale so a length counts bytes, because inside a bats
# test every command also runs bats' debug trap, and this loop, run there,
# took seconds per changelog. Each failure echoes and returns 1.
released_state() {
  local f=$1 LIMIT=$2 re=$3 name=$4 l s x n dated
  # CR bytes are counted with tr, never matched: this platform's tools
  # drop a CR from a pattern.
  [ "$(( $(LC_ALL=C tr -cd '\r' < "$f" | wc -c) ))" -eq 0 ] \
    || { echo "fixture: $name still holds a CR byte after normalising"; return 1; }
  n=0; dated=0
  while IFS= read -r l || [ -n "$l" ]; do
    n=$((n + 1))
    [ "${#l}" -le "$LIMIT" ] \
      || { echo "fixture: $name line $n is still longer than $LIMIT bytes after normalising"; return 1; }
    case "$l" in
      '## ['*) if [[ $l =~ $re ]]; then dated=$((dated + 1)); continue; fi ;;
    esac
    # The wide rule again: the line, then each strip of a leading blank,
    # a `>` marker or a list marker, tested before the first strip and
    # after every one. Globs and parameter expansion, not a regex per
    # strip: this loop runs on every line of every fixture.
    s=$l
    while :; do
      case "$s" in
        '```'*|'~~~'*|'##'|'##'[[:blank:]]*)
          echo "fixture: $name line $n still holds a heading or fence line after normalising"; return 1 ;;
        -*)
          # A run of `-`, then only blanks, is an underline.
          x=${s#"${s%%[!-]*}"}
          case "$x" in
            *[![:blank:]]*) ;;
            *) echo "fixture: $name line $n still holds an underline after normalising"; return 1 ;;
          esac ;;
      esac
      case "$s" in
        [[:blank:]]*) s=${s:1} ;;
        '>'*) s=${s:1}; case "$s" in [[:blank:]]*) s=${s:1} ;; esac ;;
        [-*+]) s='' ;;
        [-*+][[:blank:]]*) s=${s:2} ;;
        [0-9]*)
          # Digits, then `.` or `)`, then a blank or the end.
          x=${s#"${s%%[!0-9]*}"}
          case "$x" in
            [.\)]) s='' ;;
            [.\)][[:blank:]]*) s=${x:2} ;;
            *) break ;;
          esac ;;
        *) break ;;
      esac
    done
  done < "$f"
  [ "$dated" -gt 0 ] \
    || { echo "fixture: $name holds no dated version heading after normalising"; return 1; }
}

# forms_no_path [what]: fails, naming U2, when $output holds the test
# directory or the repository root in any spelling this platform prints:
# as given, and where cygpath exists its mixed, POSIX and Windows forms;
# where it does not, the `/c/...` and `C:/...` forms of a path with a drive
# letter. A drive letter is searched for in both cases. Called after every
# `run` in the --released tests, passing runs included: a refusal is not
# the only output that reaches a public CI log. The spellings are worked out
# once per test directory and kept in forms_spellings: each takes a process,
# and on a slow machine about forty runs a test would then near the per-test
# timeout.
forms_no_path() {
  local s
  [ "${forms_spelt_for:-}" = "$TEST_DIR" ] || forms_spell || return 1
  for s in "${forms_spellings[@]}"; do
    case "$output" in
      *"$s"*) echo "U2: ${1:+($1) }the output holds an absolute path. output: ${output:0:600}"; return 1 ;;
    esac
  done
}

# forms_spell: sets forms_spellings to every spelling of the test directory
# and the root that forms_no_path searches for. It starts one process at
# most, a single cygpath call; every other form is built with parameter
# expansion, because a process costs a tenth of a second or more here.
forms_spell() {
  local p s d o pre m up=ABCDEFGHIJKLMNOPQRSTUVWXYZ lo=abcdefghijklmnopqrstuvwxyz
  local spellings=() mixed=()
  if command -v cygpath >/dev/null 2>&1; then
    m="$(cygpath -m "$TEST_DIR" "$ROOT")" \
      || { echo "fixture: U2 could not spell the test paths with cygpath"; return 1; }
    mixed=("${m%%$'\n'*}" "${m#*$'\n'}")
  fi
  # The physical form too, where a link in the path makes it differ: on
  # macOS a temporary directory under /var is /private/var to `pwd -P`.
  for p in "$TEST_DIR" "$ROOT"; do
    s="$(cd "$p" && pwd -P)" || { echo "fixture: U2 could not read the physical path of a test path"; return 1; }
    [ "$s" = "$p" ] || mixed+=("$s")
  done
  for p in "$TEST_DIR" "$ROOT" "${mixed[@]+"${mixed[@]}"}"; do
    spellings+=("$p")
    # A drive form gains its POSIX form and its Windows form; a POSIX form
    # with a drive letter gains its drive form.
    case "$p" in
      [a-zA-Z]:/*) spellings+=("/${p:0:1}/${p:3}" "${p//\//\\}") ;;
      /[a-zA-Z]/*) spellings+=("${p:1:1}:/${p:3}") ;;
    esac
  done
  # Every drive letter in its other case too.
  for s in "${spellings[@]}"; do
    case "$s" in
      [a-zA-Z]:*) d=${s:0:1} ;;
      /[a-zA-Z]/*) d=${s:1:1} ;;
      *) continue ;;
    esac
    pre=${up%%"$d"*}
    if [ "${#pre}" -lt 26 ]; then o=${lo:${#pre}:1}; else pre=${lo%%"$d"*}; o=${up:${#pre}:1}; fi
    case "$s" in
      /*) spellings+=("/$o${s:2}") ;;
      *) spellings+=("$o${s:1}") ;;
    esac
  done
  for s in "${spellings[@]}"; do
    # A spelling this short would match almost any output; refuse it rather
    # than report a path that is not there.
    [ "${#s}" -ge 4 ] || { echo "fixture: U2 was handed the path '$s', too short to search for"; return 1; }
  done
  forms_spellings=("${spellings[@]}")
  forms_spelt_for=$TEST_DIR
}

# forms_utf8: sets utf8 to a UTF-8 locale this machine has. Under a UTF-8
# locale a byte that is not valid text can pass a printable test, which the
# C locale the gate sets is there to stop; a run in the test's own locale
# cannot show that, because that locale may be C. A locale counts only when
# bash takes it without a word on stderr (bats would read a setlocale
# warning into $output) and counts a two-byte character as one. None found
# is a fixture failure, never a skip: every test here must run everywhere.
forms_utf8() {
  local l
  for l in C.UTF-8 en_US.UTF-8 en_US.utf8; do
    if [ "$(LC_ALL=$l bash -c 'printf %s "${#1}"' _ $'\xc3\xa9' 2>&1)" = "1" ]; then
      utf8=$l
      return 0
    fi
  done
  echo "fixture: no UTF-8 locale found (tried C.UTF-8, en_US.UTF-8, en_US.utf8)"
  return 1
}

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
  # must supply its own baseline, never borrow the tree's — and since the
  # gate refuses EVERY undated `## ` line, the baseline removes every one, not
  # only that spelling; the helper refuses a fixture it did not release.
  normalise_to_released "$base"

  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$base" "$ROOT" "$copied"
  forms_no_path
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
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$d" "$ROOT"
  forms_no_path
  [ "$status" -eq 0 ] \
    || { echo "the default run rejected a dangling heading; that is a behaviour change this test exists to make visible. output: $output"; false; }
  case "$output" in
    *UNRELEASED-ABOVE*) ;;
    *) echo "the default run passed but did not REPORT the dangling heading. output: $output"; false ;;
  esac

  # And --released must refuse it.
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied"
  forms_no_path
  [ "$status" -ne 0 ] \
    || { echo "--released accepted $copied with an Unreleased heading above its release; the check is not running"; false; }
  case "$output" in
    *"is NOT released"*) ;;
    *) echo "--released refused, but not for the planted reason. output: $output"; false ;;
  esac
  # A heading ABOVE the release keeps its own message, which names the
  # release it sits above. The whole-file rule added later refuses this
  # shape too, so without this pin the specific check could vanish and every
  # assertion above would still pass. Measured on 2026-10-01 against this
  # branch's tree over 5831822, by deleting that check.
  case "$output" in
    *"sits above the released heading"*) ;;
    *) echo "G3: the heading above the release was refused without its own message. output: $output"; false ;;
  esac

  # K2: a first heading holding an escape sequence reaches both forms'
  # output, and a CI log renders an escape sequence. Each form shows it as
  # `?`, and the default form still passes.
  d="$TEST_DIR/released-escape"
  cp -r "$base" "$d"
  awk -v esc="$(printf '\033')" 'done != 1 && /^## \[[0-9]+[.][0-9]+[.][0-9]+\] - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { print "## [Unreleased] " esc "[31mRED"; print ""; done = 1 } { print }' \
    "$d/$copied/CHANGELOG.md" > "$d/$copied/CHANGELOG.new"
  mv "$d/$copied/CHANGELOG.new" "$d/$copied/CHANGELOG.md"
  [ "$(( $(LC_ALL=C tr -cd '\033' < "$d/$copied/CHANGELOG.md" | wc -c) ))" -eq 1 ] \
    || { echo "fixture: the escape plant did not land once in the $copied fixture"; false; }
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$d" "$ROOT"
  forms_no_path
  [ "$status" -eq 0 ] \
    || { echo "K2: the default run rejected a first heading holding an escape sequence. output: $output"; false; }
  case "$output" in
    *"UNRELEASED-ABOVE:## [Unreleased] ?[31mRED"*) ;;
    *) echo "K2: the default run did not show the escape byte as '?'. output: $output"; false ;;
  esac
  [ "$(( $(printf '%s' "$output" | LC_ALL=C tr -cd '\033' | wc -c) ))" -eq 0 ] \
    || { echo "K2: the default run printed the escape byte"; false; }
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied"
  forms_no_path
  [ "$status" -ne 0 ] \
    || { echo "K2: --released accepted a heading above its release. output: $output"; false; }
  case "$output" in
    *"'## [Unreleased] ?[31mRED' sits above the released heading"*) ;;
    *) echo "K2: the first-heading refusal did not show the escape byte as '?'. output: $output"; false ;;
  esac
  [ "$(( $(printf '%s' "$output" | LC_ALL=C tr -cd '\033' | wc -c) ))" -eq 0 ] \
    || { echo "K2: the first-heading refusal printed the escape byte"; false; }

  # K2, K4: a first heading longer than the quote cut, holding a 0x9b byte
  # and an `é`, run under a UTF-8 locale, where the first is not valid text
  # and the second is a printable character. Both forms show every byte
  # that is not printable ASCII as `?`, the two bytes of the `é` included,
  # and cut to exactly the quote cut, then ` [cut]`: the state field as
  # well as the refusal. Under a UTF-8 locale grep used to call such a line
  # binary and print that in place of the heading.
  forms_utf8
  long="## [Unreleased] $(printf '%100s' '' | tr ' ' x)"$'\x9b\xc3\xa9'"$(printf '%200s' '' | tr ' ' y)"
  want="## [Unreleased] $(printf '%100s' '' | tr ' ' x)???$(printf '%81s' '' | tr ' ' y) [cut]"
  d="$TEST_DIR/released-long"
  cp -r "$base" "$d"
  LONG="$long" awk 'done != 1 && /^## \[[0-9]+[.][0-9]+[.][0-9]+\] - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { print ENVIRON["LONG"]; print ""; done = 1 } { print }' \
    "$d/$copied/CHANGELOG.md" > "$d/$copied/CHANGELOG.new"
  mv "$d/$copied/CHANGELOG.new" "$d/$copied/CHANGELOG.md"
  [ "$(( $(LC_ALL=C tr -cd '\233' < "$d/$copied/CHANGELOG.md" | wc -c) ))" -eq 1 ] \
    || { echo "fixture: the long first-heading plant did not land once in the $copied fixture"; false; }
  run bash -c 'export LC_ALL=$3; cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$d" "$ROOT" "$utf8"
  forms_no_path
  [ "$status" -eq 0 ] \
    || { echo "K2: under $utf8, the default run rejected a long first heading"; false; }
  case "$output"$'\n' in
    *" state=UNRELEASED-ABOVE:$want"$'\n'*) ;;
    *) echo "K4: under $utf8, the default run's state field is not the heading masked and cut"; false ;;
  esac
  [ "$(( $(printf '%s' "$output" | LC_ALL=C tr -cd '\233' | wc -c) ))" -eq 0 ] \
    || { echo "K4: under $utf8, the default run printed the 0x9b byte"; false; }
  run bash -c 'export LC_ALL=$4; cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied" "$utf8"
  forms_no_path
  [ "$status" -ne 0 ] || { echo "K2: under $utf8, --released accepted a heading above its release"; false; }
  case "$output" in
    *"'$want' sits above the released heading"*) ;;
    *) echo "K4: under $utf8, the first-heading refusal is not the heading masked and cut"; false ;;
  esac
  [ "$(( $(printf '%s' "$output" | LC_ALL=C tr -cd '\233' | wc -c) ))" -eq 0 ] \
    || { echo "K4: under $utf8, the first-heading refusal printed the 0x9b byte"; false; }
  # H8 needs no combined copy here: every plant in this test is a first
  # heading above the release, which the contract leaves out by name, since
  # such a copy cannot report state=released.
}

@test "--released refuses an undated heading below the release, and the default run does not" {
  cd "$ROOT"

  # The test above plants its heading ABOVE the release. That is the one place
  # the release form used to look: it compared the FIRST level-2 heading with
  # the version heading and read nothing below it, so a heading left lower in
  # the file passed every gate. The 1.3.0 release caught that shape only with a
  # one-off quickstart check that CI never runs. The release form now judges
  # every line beginning `## `, and anything that is not a dated version
  # heading is refused — `## [Unreleased]` and every other spelling of it.
  #
  # Every failure below names the contract clause it guards (G1, G2, G5, G6 in
  # specs/023-gate-reads-whole-changelog/contracts/release-form.md), so a red
  # says which promise broke rather than only that something did.

  # A faithful, released fixture first, required to PASS, as the test above
  # builds one: a fixture broken by construction would make every break below
  # succeed for the wrong reason.
  base="$TEST_DIR/undated-base"
  mkdir -p "$base/.claude-plugin"
  cp .claude-plugin/marketplace.json "$base/.claude-plugin/marketplace.json"
  copied=""
  other=""
  while IFS= read -r src; do
    src="${src%$'\r'}"
    d="${src#./}"; d="${d%/}"
    mkdir -p "$base/$d/.claude-plugin"
    cp "$d/.claude-plugin/plugin.json" "$base/$d/.claude-plugin/plugin.json"
    cp "$d/CHANGELOG.md" "$base/$d/CHANGELOG.md"
    if [ -z "$copied" ]; then copied="$d"; elif [ -z "$other" ]; then other="$d"; fi
  done < <(jq -r '.plugins[].source' .claude-plugin/marketplace.json)
  [ -n "$copied" ] && [ -n "$other" ] \
    || { echo "fixture: two plugins are needed, one judged and one not; got '$copied' and '$other'"; false; }
  # Normalised as the test above is, by the same dated pattern, so an
  # undated heading the live tree happens to hold cannot fail the base.
  normalise_to_released "$base"
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$base" "$ROOT" "$copied"
  forms_no_path
  [ "$status" -eq 0 ] \
    || { echo "fixture: the normalised copy already fails --released; nothing below would prove anything. output: $output"; false; }

  # Four plants, each BELOW the first dated heading: the exact Keep a
  # Changelog spelling; one the old exact-text idea would have let through;
  # and two that only an anchored pattern refuses — a dated heading with a
  # trailing note (the drift the version read above was anchored against)
  # and one with its closing bracket missing.
  n=0
  for plant in '## [Unreleased]' '## unreleased' '## [9.9.9] - 2026-01-01 (yanked)' '## [9.9.9 - 2026-01-01'; do
    n=$((n + 1))
    d="$TEST_DIR/undated-$n"
    cp -r "$base" "$d"
    # Insert the plant just before the SECOND dated heading. Repetitions are
    # spelled out rather than written as {4}: an awk without interval
    # expressions would otherwise match nothing and plant nothing.
    awk -v plant="$plant" '
      /^## \[[0-9]+[.][0-9]+[.][0-9]+\] - [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ {
        dated++
        if (dated == 2) { print plant; print "" }
      }
      { print }
    ' "$d/$copied/CHANGELOG.md" > "$d/$copied/CHANGELOG.new"
    mv "$d/$copied/CHANGELOG.new" "$d/$copied/CHANGELOG.md"

    # Prove the plant landed exactly once, and BELOW: the first heading is
    # still the dated one, so the old first-heading rule sees nothing wrong.
    [ "$(grep -c -x -F -- "$plant" "$d/$copied/CHANGELOG.md")" -eq 1 ] \
      || { echo "fixture: '$plant' did not land exactly once in the $copied copy"; false; }
    first="$(grep -m1 '^## ' "$d/$copied/CHANGELOG.md")"
    case "$first" in
      "## ["[0-9]*"] - "[0-9]*) ;;
      *) echo "fixture: '$plant' landed above the release; the first heading is '$first'"; false ;;
    esac
    line="$(grep -n -x -F -- "$plant" "$d/$copied/CHANGELOG.md" | cut -d: -f1)"

    # The default form is untouched: it reports and passes.
    run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$d" "$ROOT"
    forms_no_path
    [ "$status" -eq 0 ] \
      || { echo "G5: the default run rejected '$plant' below the release; the default form must not change. output: $output"; false; }
    printf '%s\n' "$output" | grep -q -- "^$copied: plugin=.* state=released\$" \
      || { echo "G5: the default run's line for $copied does not say state=released. output: $output"; false; }

    # The release form refuses, and says where and what.
    run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied"
    forms_no_path
    [ "$status" -ne 0 ] \
      || { echo "G1: --released accepted $copied with '$plant' at line $line, below its release. output: $output"; false; }
    case "$output" in
      *"is NOT released"*) ;;
      *) echo "G2: --released refused, but not as an unreleased tree. output: $output"; false ;;
    esac
    case "$output" in
      *"line $line "*) ;;
      *) echo "G2: the refusal does not name line $line. output: $output"; false ;;
    esac
    case "$output" in
      *"$plant"*) ;;
      *) echo "G2: the refusal does not quote '$plant'. output: $output"; false ;;
    esac
  done

  # G2's other half: the quoted line lands in a public CI log, so every byte
  # in it that is not printable is shown as `?`. Every plant above is
  # printable, so without this one the replacement could be deleted and the
  # suite stay green. The byte is STX (\002): a control byte no terminal acts
  # on, because CI's --print-output-on-failure prints $output raw, and if the
  # replacement is ever lost the byte reaches the log. Not ESC, which a
  # terminal acts on, and not \001, which bash uses internally and which old
  # bash mishandles in patterns. Appended, not inserted: the last line of the
  # file is below the release too, and this keeps one more copy of the dated
  # pattern out of the test.
  ctl="$(printf '\002')"
  plant="## Notes ${ctl}red"
  d="$TEST_DIR/undated-ctl"
  cp -r "$base" "$d"
  printf '\n%s\n' "$plant" >> "$d/$copied/CHANGELOG.md"
  [ "$(grep -c -x -F -- "$plant" "$d/$copied/CHANGELOG.md")" -eq 1 ] \
    || { echo "fixture: the control-byte plant did not land exactly once in the $copied copy"; false; }
  line="$(grep -n -x -F -- "$plant" "$d/$copied/CHANGELOG.md" | cut -d: -f1)"
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied"
  forms_no_path
  [ "$status" -ne 0 ] \
    || { echo "G1: --released accepted $copied with a control byte in a heading at line $line. output: ${output//$ctl/<STX>}"; false; }
  case "$output" in
    *"line $line holds '## Notes ?red'"*) ;;
    *) echo "G2: the refusal does not show the control byte at line $line as '?'. output, the byte written as <STX>: ${output//$ctl/<STX>}"; false ;;
  esac
  case "$output" in
    *"$ctl"*) echo "G2: the refusal carries the raw control byte into the log"; false ;;
  esac

  # Only the plugin being released is judged: an undated heading in the OTHER
  # plugin's changelog is that plugin's unreleased work, which is normal.
  d="$TEST_DIR/undated-other"
  cp -r "$base" "$d"
  printf '\n## [Unreleased]\n' >> "$d/$other/CHANGELOG.md"
  [ "$(grep -c -x -F -- '## [Unreleased]' "$d/$other/CHANGELOG.md")" -eq 1 ] \
    || { echo "fixture: the plant did not land in the $other copy"; false; }
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied"
  forms_no_path
  [ "$status" -eq 0 ] \
    || { echo "G6: --released $copied refused because of $other's changelog. output: $output"; false; }

  # H8: the default form passes one copy holding every refused plant above,
  # each after its own `Plain text.` and blank line, and still reports the
  # judged plugin as released.
  s=('' 'Plain text.' '')
  forms_put '## [Unreleased]' "${s[@]}" '## unreleased' "${s[@]}" '## [9.9.9] - 2026-01-01 (yanked)' "${s[@]}" \
    '## [9.9.9 - 2026-01-01' "${s[@]}" "$plant"
  forms_at "$plant"
  forms_default
}

# ---------------------------------------------------------------------------
# Every level-2 heading form (specs/024-gate-every-heading-form/).
#
# The test above judges lines beginning `## `. Markdown writes a level-2
# heading other ways too, and each rendered exactly like `## [Unreleased]`
# while passing the gate: a tab after `##`, an indent, no text, an
# underline, a quote or a list item around it, a deep indent that continues
# a list item. A fence that never closes, or whose end is unclear, could
# hide one. The six tests below plant each shape on a fresh copy and
# require a refusal, then plant what Markdown does NOT read as a heading and
# require a pass. Every failure names its clause in that feature's
# contracts/release-form.md (H1-H9).
#
# Six tests, not one: about forty gate runs do not fit the suite's
# per-test timeout with room to spare on a slow machine, and that timeout is
# set once for every suite (tests/helper.bash) and is not raised for one
# test. Measured on 2026-10-03 on this branch: split three ways, the
# largest part took about 21 s, and split four and five ways about 17 s,
# above the suite's slowest test; split six ways, by the contract's
# clauses, the slowest took about 13 s. The plants review added later
# raised that to about 18 s, well inside the timeout. Each plant still
# runs the gate on its own copy, so a red names the plant that caused it.
#
# The helpers below share state through these names: base (the released
# fixture), copied (the judged plugin), other (a second plugin, when the
# fixture holds one), d (the copy a plant went into), n (a plant counter)
# and line (set by forms_at). Each fails with an echo and an explicit
# `return 1`, so call each on its own line at the top level of a test,
# never under `if`, `||` or `$(...)`, where errexit is inert.
# ---------------------------------------------------------------------------

# forms_base <one|two>: build a released fixture under $TEST_DIR. With `one`
# it holds the first marketplace plugin only, behind a marketplace listing
# just that entry, which halves the time of every gate run; with `two` it
# holds the first two, for the test that a second plugin is not judged.
forms_base() {
  local src p i=0
  base="$TEST_DIR/forms-base"
  copied=""
  other=""
  # Never reset: a rebuilt base must not send the next plant into a copy
  # directory that already exists, where cp -r would nest it.
  : "${n:=0}"
  mkdir -p "$base/.claude-plugin"
  while IFS= read -r src; do
    src="${src%$'\r'}"
    p="${src#./}"; p="${p%/}"
    i=$((i + 1))
    if [ "$i" = "1" ]; then copied="$p"
    elif [ "$i" = "2" ] && [ "$1" = "two" ]; then other="$p"
    else continue
    fi
    mkdir -p "$base/$p/.claude-plugin"
    cp "$p/.claude-plugin/plugin.json" "$base/$p/.claude-plugin/plugin.json"
    cp "$p/CHANGELOG.md" "$base/$p/CHANGELOG.md"
  done < <(jq -r '.plugins[].source' .claude-plugin/marketplace.json)
  [ -n "$copied" ] || { echo "fixture: the marketplace names no plugin"; return 1; }
  if [ "$1" = "two" ]; then
    [ -n "$other" ] || { echo "fixture: two plugins are needed, one judged and one not"; return 1; }
    cp .claude-plugin/marketplace.json "$base/.claude-plugin/marketplace.json"
  else
    # By position, not by name: the first entry is the one `copied` came
    # from, and a by-name selection here is the marker the "one
    # version-agreement script" test refuses outside the gate.
    jq '.plugins |= .[:1]' .claude-plugin/marketplace.json \
      > "$base/.claude-plugin/marketplace.json" \
      || { echo "fixture: could not write a one-plugin marketplace"; return 1; }
  fi
  normalise_to_released "$base" || return 1
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$base" "$ROOT" "$copied"
  forms_no_path || return 1
  [ "$status" -eq 0 ] \
    || { echo "fixture: the normalised copy already fails --released; nothing below would prove anything. output: $output"; return 1; }
}

# forms_put <line>...: a fresh copy of the base, with the lines appended to
# the judged plugin's changelog after `Plain text.` and a blank line. That
# unindented paragraph ends the list item the real changelog closes on, so
# no plant's reading depends on the line before it. Sets d.
forms_put() {
  n=$((n + 1))
  d="$TEST_DIR/forms-$n"
  cp -r "$base" "$d"
  { printf '\nPlain text.\n\n'; printf '%s\n' "$@"; } >> "$d/$copied/CHANGELOG.md"
}

# forms_at <raw line>: sets line to that line's number in the copy, which
# must hold it exactly once. `|| true`: grep exits 1 when it finds none,
# and under errexit the bare assignment would end the test before the
# `fixture:` message below could say why (U5). One grep, and the count
# taken from its output with parameter expansion: a process is slow here.
forms_at() {
  local hits nl c=0
  hits="$(grep -n -x -F -- "$1" "$d/$copied/CHANGELOG.md" || true)"
  if [ -n "$hits" ]; then nl=${hits//[!$'\n']/}; c=$(( ${#nl} + 1 )); fi
  [ "$c" = "1" ] || { echo "fixture: the $copied copy holds '$1' $c times, not once"; return 1; }
  line=${hits%%:*}
}

# forms_refused <clause> <fragment>...: --released refuses the copy, saying
# `is NOT released` and every fragment, and printing no absolute path (U2).
forms_refused() {
  local id=$1 f
  shift
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied"
  forms_no_path "$id plant" || return 1
  [ "$status" -ne 0 ] \
    || { echo "$id: --released accepted the plant. output: $output"; return 1; }
  case "$output" in
    *"is NOT released"*) ;;
    *) echo "$id: --released refused, but not as an unreleased tree. output: $output"; return 1 ;;
  esac
  for f in "$@"; do
    case "$output" in
      *"$f"*) ;;
      *) echo "$id: the refusal does not say \"$f\". output: $output"; return 1 ;;
    esac
  done
}

# forms_unclear <opener> <unclear line>: the fence is refused at the unclear
# line, naming the opener's line and that line with its text.
forms_unclear() {
  local open
  forms_at "$1" || return 1
  open=$line
  forms_at "$2" || return 1
  forms_refused H6 "opened at line $open " "at line $line, which holds '$2'" || return 1
  case "$output" in
    *"never closed"*) echo "H6: an unclear fence was also reported as never closed. output: $output"; return 1 ;;
  esac
}

# forms_passes <planted line> <what>: --released accepts the copy. The
# planted line is found first, so a plant that did not land fails as a
# fixture instead of passing for having planted nothing (U3).
forms_passes() {
  forms_at "$1" || return 1
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied"
  forms_no_path "$2" || return 1
  [ "$status" -eq 0 ] \
    || { echo "H7: --released refused $2, which Markdown does not read as a heading. output: $output"; return 1; }
}

# forms_default: the default form passes the copy and still reports the
# judged plugin as released (H8). One copy holds every refused plant of a
# test, each after its own `Plain text.`, so one run covers them all.
forms_default() {
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$d" "$ROOT"
  forms_no_path || return 1
  [ "$status" -eq 0 ] \
    || { echo "H8: the default run failed on the refused plants; the default form must not change. output: $output"; return 1; }
  printf '%s\n' "$output" | grep -q -- "^$copied: plugin=.* state=released\$" \
    || { echo "H8: the default run's line for $copied does not say state=released. output: $output"; return 1; }
}

@test "--released refuses every bare level-2 heading form" {
  cd "$ROOT"
  forms_base one
  tab="$(printf '\t')"

  # H1: ATX forms. A tab is quoted as `?`, like every non-printable byte.
  forms_put "##${tab}Notes"
  forms_at "##${tab}Notes"
  forms_refused H1 "line $line holds '##?Notes', which is not a dated version heading"
  for raw in ' ## Notes' '   ## Notes' '##' '## Notes ##'; do
    forms_put "$raw"
    forms_at "$raw"
    forms_refused H1 "line $line holds '$raw'"
  done

  # H2: a version heading counts as dated only in its canonical form.
  forms_put ' ## [1.0.0] - 2026-01-01'
  forms_at ' ## [1.0.0] - 2026-01-01'
  forms_refused H2 "line $line holds ' ## [1.0.0] - 2026-01-01'"

  # H3: a setext heading is named by its text line.
  forms_put 'Notes' '---'
  forms_at 'Notes'
  forms_refused H3 "line $line holds 'Notes', underlined at line $((line + 1))"
  # Every line that is not blank counts as text above an underline. Each
  # line here follows a blank line, so Markdown reads only `--` then `---`
  # as a setext heading; it reads the others as code or a heading, then a
  # thematic break, and refusing them is the wrong refusal the rule costs.
  for raw in '    Notes' '--' '    >' '    > ### x'; do
    forms_put "$raw" '---'
    forms_at "$raw"
    forms_refused H3 "line $line holds '$raw', underlined at line $((line + 1))"
  done
  # K6: an ATX heading inside a quote still counts as text above an
  # underline; only a heading with no container stopped counting (N3).
  forms_put '> ### x' '> ---'
  forms_at '> ### x'
  forms_refused K6 "line $line holds '> ### x', underlined at line $((line + 1))"
  # A line of `>` marks is an empty quote line only while two marks are at
  # most one space apart: after five spaces the second `>` continues the
  # paragraph, and Markdown renders `a >` as a level-2 heading (N4, found at
  # pull request review).
  forms_put '> a' '>     >' '> ---'
  forms_at '>     >'
  forms_refused K6 "line $line holds '>     >', underlined at line $((line + 1))"
  # And so does one inside a list item, where the walk cannot tell the item
  # is still open.
  forms_put '- a' '  ### x' '  ---'
  forms_at '  ### x'
  forms_refused K6 "line $line holds '  ### x', underlined at line $((line + 1))"
  # The shapes review found passing, each a setext heading Markdown
  # renders: a deep `>` line continuing a paragraph, a fence closer of a
  # fence Markdown reads as paragraph text, a deep heading line and a `--`
  # run inside a list item.
  for raw in '    >' '    > ### x'; do
    forms_put 'Para' "$raw" '---'
    forms_at "$raw"
    forms_refused H3 "line $line holds '$raw', underlined at line $((line + 1))"
  done
  forms_put 'Para' '    ```' '    ```' '---'
  forms_at 'Para'
  forms_refused H3 "line $((line + 2)) holds '    \`\`\`', underlined at line $((line + 3))"
  forms_put '- item' '      ### x' '  ---'
  forms_at '      ### x'
  forms_refused H3 "line $line holds '      ### x', underlined at line $((line + 1))"
  forms_put '- item' '' '  --' '  ---'
  forms_at '  --'
  forms_refused H3 "line $line holds '  --', underlined at line $((line + 1))"

  # H8: the default form passes a copy holding every refused plant above,
  # each after its own `Plain text.` and blank line.
  s=('' 'Plain text.' '')
  forms_put "##${tab}Notes" "${s[@]}" ' ## Notes' "${s[@]}" '   ## Notes' "${s[@]}" '##' "${s[@]}" \
    '## Notes ##' "${s[@]}" ' ## [1.0.0] - 2026-01-01' "${s[@]}" 'Notes' '---' "${s[@]}" \
    '    Notes' '---' "${s[@]}" '--' '---' "${s[@]}" '    >' '---' "${s[@]}" '    > ### x' '---' "${s[@]}" \
    '> ### x' '> ---' "${s[@]}" '> a' '>     >' '> ---' "${s[@]}" \
    '- a' '  ### x' '  ---' "${s[@]}" 'Para' '    >' '---' "${s[@]}" \
    'Para' '    > ### x' '---' "${s[@]}" 'Para' '    ```' '    ```' '---' "${s[@]}" \
    '- item' '      ### x' '  ---' "${s[@]}" '- item' '' '  --' '  ---'
  forms_default
}

@test "--released refuses a level-2 heading inside a quote or a list item" {
  cd "$ROOT"
  forms_base one

  # H4: quotes and list items, in either order.
  for raw in '> ## Notes' '>## Notes' '- ## Notes' '* ## Notes' '+ ## Notes' \
             '1. ## Notes' '1) ## Notes' '- > ## Notes' '1. > ## Notes'; do
    forms_put "$raw"
    forms_at "$raw"
    forms_refused H4 "line $line holds '$raw'"
  done
  forms_put '> Notes' '> ---'
  forms_at '> Notes'
  forms_refused H4 "line $line holds '> Notes', underlined at line $((line + 1))"
  forms_put '- Notes' '  ---'
  forms_at '- Notes'
  forms_refused H4 "line $line holds '- Notes', underlined at line $((line + 1))"

  # H8: the default form passes a copy holding every refused plant above,
  # each after its own `Plain text.` and blank line.
  s=('' 'Plain text.' '')
  forms_put '> ## Notes' "${s[@]}" '>## Notes' "${s[@]}" '- ## Notes' "${s[@]}" '* ## Notes' "${s[@]}" \
    '+ ## Notes' "${s[@]}" '1. ## Notes' "${s[@]}" '1) ## Notes' "${s[@]}" '- > ## Notes' "${s[@]}" \
    '1. > ## Notes' "${s[@]}" '> Notes' '> ---' "${s[@]}" '- Notes' '  ---'
  forms_default
}

@test "--released judges a deep line while a list item can be open" {
  cd "$ROOT"
  forms_base one

  # H5: while a list item can be open, a deep line is judged.
  forms_put '- item' '' '    ## Notes'
  forms_at '    ## Notes'
  forms_refused H5 "line $line holds '    ## Notes'"
  forms_put '- item' '    ## Notes'
  forms_at '    ## Notes'
  forms_refused H5 "line $line holds '    ## Notes'"
  forms_put '- a' '  - b' '' '  c' '' '    ## Notes'
  forms_at '    ## Notes'
  forms_refused H5 "line $line holds '    ## Notes'"
  forms_put '-' '    ## Notes'
  forms_at '    ## Notes'
  forms_refused H5 "line $line holds '    ## Notes'"
  # A backtick line holding a further backtick is text, not a fence, so it
  # continues the item and does not end it. Found at H.7: a second, looser
  # opener rule ended the item here and passed the deep heading.
  forms_put '- item' '```a`' '    ## Notes'
  forms_at '    ## Notes'
  forms_refused H5 "line $line holds '    ## Notes'"
  # A line of `>` alone is not blank: deep in an item it is text, so the
  # lazy line after it continues the item. Found at review (phase I).
  forms_put '- item' '      >' 'lazy' '    ## Notes'
  forms_at '    ## Notes'
  forms_refused H5 "line $line holds '    ## Notes'"

  # H8: the default form passes a copy holding every refused plant above,
  # each after its own `Plain text.` and blank line.
  s=('' 'Plain text.' '')
  forms_put '- item' '' '    ## Notes' "${s[@]}" '- item' '    ## Notes' "${s[@]}" \
    '- a' '  - b' '' '  c' '' '    ## Notes' "${s[@]}" '-' '    ## Notes' "${s[@]}" \
    '- item' '```a`' '    ## Notes' "${s[@]}" '- item' '      >' 'lazy' '    ## Notes'
  forms_default
}

@test "--released refuses a code fence that never closes" {
  cd "$ROOT"
  forms_base one
  bt='```'
  tl='~~~'

  # H6: an unclosed fence, backticks and tildes.
  forms_put "$bt" 'unclosed'
  forms_at "$bt"
  forms_refused H6 "line $line opens a code fence that is never closed: '$bt'"
  forms_put "$tl" 'unclosed'
  forms_at "$tl"
  forms_refused H6 "line $line opens a code fence that is never closed: '$tl'"

  # H6, one refusal: a heading refused before an unclosed fence is the only
  # report, once.
  forms_put '## Notes' '' "$bt" 'unclosed'
  forms_at '## Notes'
  forms_refused H6 "line $line holds '## Notes'"
  [ "$(printf '%s\n' "$output" | grep -c 'is NOT released')" = "1" ] \
    || { echo "H6: the refusal is not reported exactly once. output: $output"; false; }
  case "$output" in
    *"never closed"*) echo "H6: an open fence was reported after a heading was already refused. output: $output"; false ;;
  esac
  # FR-009: two refusable lines, and only the first is reported.
  forms_put '## Notes' '' '## More'
  forms_at '## Notes'
  forms_refused H6 "line $line holds '## Notes'"
  case "$output" in
    *"## More"*) echo "H6: a second refusal was reported after the first. output: $output"; false ;;
  esac

  # H8: the default form passes a copy holding every refused plant above,
  # each after its own `Plain text.` and blank line.
  s=('' 'Plain text.' '')
  forms_put '## Notes' '' '## More' "${s[@]}" '## Notes' '' "$bt" 'unclosed' "${s[@]}" \
    "$tl" 'unclosed' "${s[@]}" "$bt" 'unclosed'
  forms_default
}

@test "--released refuses a code fence whose end is unclear" {
  cd "$ROOT"
  forms_base one
  bt='```'

  # H6: a fence whose end is unclear is refused at the first unclear line.
  forms_put "- $bt" '## Notes'
  forms_unclear "- $bt" '## Notes'
  forms_put "   $bt" "$bt"
  forms_unclear "   $bt" "$bt"
  forms_put "> $bt" 'x'
  forms_unclear "> $bt" 'x'
  forms_put "- $bt" "   $bt"
  forms_unclear "- $bt" "   $bt"
  forms_put "    $bt" '## Notes'
  forms_unclear "    $bt" '## Notes'
  forms_put '- item' "  > $bt" '> ## Notes'
  forms_unclear "  > $bt" '> ## Notes'
  forms_put "- > $bt" '>'
  forms_unclear "- > $bt" '>'
  forms_put ">$bt" ">    $bt"
  forms_unclear ">$bt" ">    $bt"

  # H6: a fence opener Markdown might not open is refused, because the
  # walk would skip a heading under it. Found at review (phase I).
  # An ordered marker other than 1 may not start a list after text:
  forms_put 'Para' "2. $bt" '   ## x' "   $bt"
  forms_at "2. $bt"
  forms_refused H6 "line $line opens a code fence on an ordered list marker other than 1"
  forms_put '- a' "  2) $bt" '     ## x' "     $bt"
  forms_at "  2) $bt"
  forms_refused H6 "line $line opens a code fence on an ordered list marker other than 1"
  # A fence line inside an HTML block is not a fence; some HTML blocks
  # run past a blank line, so any opener below a `<` line is refused.
  forms_put '<div>' "$bt" '' '## x' '' "$bt"
  forms_at '<div>'
  forms_refused H6 "line $((line + 1)) opens a code fence that the HTML at line $line may hold: '$bt'"
  forms_put '<!--' "$bt" '-->' '## x' "$bt"
  forms_at '<!--'
  forms_refused H6 "line $((line + 1)) opens a code fence that the HTML at line $line may hold: '$bt'"
  # K6: the neighbours of the two fence narrowings stay refused. An empty
  # `1.` does not start a list after a paragraph, a ten-digit number is not
  # a list marker, and a `<!--` comment runs past a blank line (N1, N2).
  forms_put 'Para' '1.' "2. $bt" '   ## x' "   $bt"
  forms_at "2. $bt"
  forms_refused K6 "line $line opens a code fence on an ordered list marker other than 1"
  forms_put '1234567890. a' "2. $bt" '   ## x' "   $bt"
  forms_at "2. $bt"
  forms_refused K6 "line $line opens a code fence on an ordered list marker other than 1"
  forms_put '<x' '<!--' '' "$bt" '-->' '## x' "$bt"
  forms_at '<!--'
  forms_refused K6 "line $((line + 2)) opens a code fence that the HTML at line $line may hold"
  # A `<pre>` block runs past a blank line too, in either case, and an
  # ordered item at another indent does not continue the list above it.
  for tag in '<pre>' '<PRE>'; do
    forms_put "$tag" '' "$bt" '</pre>' '## x' "$bt"
    forms_at "$tag"
    forms_refused K6 "line $((line + 2)) opens a code fence that the HTML at line $line may hold"
  done
  forms_put '1. a' "   2. $bt" '      ## x' "      $bt"
  forms_at "   2. $bt"
  forms_refused K6 "line $line opens a code fence on an ordered list marker other than 1"

  # H6: a fence never hides a heading after its clean close.
  forms_put "$bt" "> $bt" "$bt" '## Notes'
  forms_at '## Notes'
  forms_refused H1 "line $line holds '## Notes'"

  # H8: the default form passes a copy holding every refused plant above,
  # each after its own `Plain text.` and blank line.
  s=('' 'Plain text.' '')
  forms_put "- $bt" '## Notes' "${s[@]}" "   $bt" "$bt" "${s[@]}" "> $bt" 'x' "${s[@]}" \
    "- $bt" "   $bt" "${s[@]}" "    $bt" '## Notes' "${s[@]}" '- item' "  > $bt" '> ## Notes' "${s[@]}" \
    "- > $bt" '>' "${s[@]}" ">$bt" ">    $bt" "${s[@]}" 'Para' "2. $bt" '   ## x' "   $bt" "${s[@]}" \
    '- a' "  2) $bt" '     ## x' "     $bt" "${s[@]}" '<div>' "$bt" '' '## x' '' "$bt" "${s[@]}" \
    '<!--' "$bt" '-->' '## x' "$bt" "${s[@]}" 'Para' '1.' "2. $bt" '   ## x' "   $bt" "${s[@]}" \
    '1234567890. a' "2. $bt" '   ## x' "   $bt" "${s[@]}" '<x' '<!--' '' "$bt" '-->' '## x' "$bt" "${s[@]}" \
    '<pre>' '' "$bt" '</pre>' '## x' "$bt" "${s[@]}" '<PRE>' '' "$bt" '</pre>' '## x' "$bt" "${s[@]}" \
    '1. a' "   2. $bt" '      ## x' "      $bt" "${s[@]}" "$bt" "> $bt" "$bt" '## Notes'
  forms_default
}

@test "--released judges no non-heading, and only the named plugin" {
  cd "$ROOT"
  forms_base one
  tab="$(printf '\t')"
  bt='```'
  tl='~~~'

  # H7: what Markdown does not read as a heading passes.
  forms_put "$bt" '## Notes' "$bt"
  forms_passes '## Notes' 'a ## line inside a backtick fence'
  forms_put "$tl" '## Notes' "$tl"
  forms_passes '## Notes' 'a ## line inside a tilde fence'
  forms_put '- item' '' "  $bt" '  ## x' "  $bt"
  forms_passes '  ## x' 'a fence inside a list item'
  forms_put '---'
  forms_passes '---' 'a thematic break after a blank line'
  forms_put '    ## Notes'
  forms_passes '    ## Notes' 'a four-space indented ## line with no list item open'
  forms_put "${tab}## Notes"
  forms_passes "${tab}## Notes" 'a tab-indented ## line with no list item open'
  forms_put "$bt" '## Notes' "$bt" '' 'Plain text.' '' "$tl" '## Notes' "$tl" '' 'Plain text.' '' \
    '- item' '' "  $bt" '  ## x' "  $bt" '' 'Plain text.' '' '---' '' 'Plain text.' '' \
    '    ## Notes' '' 'Plain text.' '' "${tab}## Notes"
  forms_passes "${tab}## Notes" 'every non-heading together'
  # K6: the four shapes Phase 26 narrowed, each passing only because the
  # proof in specs/025-gate-closes-phase25-gaps/proof/ showed the narrowed
  # walk passes no level-2 heading a CommonMark reader renders.
  forms_put '1. a' "2. $bt" '   code' "   $bt"
  forms_passes "2. $bt" 'a fence on the second item of a numbered list (N1)'
  forms_put '<details>' '' 'x' '' '</details>' '' "$bt" 'code' "$bt"
  forms_passes '<details>' 'a fence after an HTML block a blank line ended (N2)'
  forms_put '### Plantnote' '---'
  forms_passes '### Plantnote' 'a thematic break under an ATX heading (N3)'
  forms_put '### x' '---'
  forms_passes '### x' 'the Phase 25 plant, a thematic break under a heading (N3)'
  forms_put '> Notes' '>' '> ---'
  forms_passes '> ---' 'a thematic break after an empty quote line (N4)'

  # H9: only the plugin being released is judged. This one needs a second
  # plugin, so the fixture is rebuilt with two.
  forms_base two
  d="$TEST_DIR/forms-other"
  cp -r "$base" "$d"
  printf '\nPlain text.\n\n##%sNotes\n' "$tab" >> "$d/$other/CHANGELOG.md"
  [ "$(grep -c -x -F -- "##${tab}Notes" "$d/$other/CHANGELOG.md")" -eq 1 ] \
    || { echo "fixture: the plant did not land in the $other copy"; false; }
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied"
  forms_no_path
  [ "$status" -eq 0 ] \
    || { echo "H9: --released $copied refused because of $other's changelog. output: $output"; false; }
}

# K1-K5: bytes and lines the walk cannot judge, each refused with a message
# of the gate's own. Every length here is in bytes, as the gate counts them
# under the C locale. The plants run in this order so that against an older
# gate the first red names K1, before the line of quote markers, which an
# older walk took minutes to read.
# The largest changelog, in bytes, the release form reads. The tests hold
# their own copy, never the gate's: a fixture that read the code under test
# would move with it.
changelog_limit=262144
# The longest line, in bytes, the release form judges: the tests' own
# copy too, for the same reason.
line_limit=1000

@test "--released refuses a byte or a line it cannot judge" {
  cd "$ROOT"
  forms_base one
  local c long cut room pairs

  # K1: a lone CR. Markdown reads it as a line end, so `CRplant`, a CR and
  # `## x` hold a level-2 heading. Built with $'\r', never a literal CR in
  # this file; Windows gawk strips only a CR that comes before a line feed.
  forms_put $'CRplant\r## x'
  c="$(LC_ALL=C tr -cd '\r' < "$d/$copied/CHANGELOG.md" | wc -c)"
  [ "$((c))" -eq 1 ] || { echo "fixture: the CR plant holds $((c)) CR bytes, not 1"; false; }
  line="$(grep -n -F 'CRplant' "$d/$copied/CHANGELOG.md" | cut -d: -f1)"
  [ -n "$line" ] || { echo "fixture: the CR plant did not land"; false; }
  forms_refused K1 "line $line holds a carriage return" "CRplant?## x"

  # K3, K4: one byte over the limit is refused for its length, and the
  # quote is cut to exactly the quote cut, then ` [cut]`. Exactly the limit
  # is not refused for its length.
  long="$(printf '%1001s' '' | tr ' ' x)"
  cut="$(printf '%200s' '' | tr ' ' x)"
  forms_put "$long"
  line="$(LC_ALL=C awk 'length($0) > 1000 { print NR }' "$d/$copied/CHANGELOG.md")"
  [ -n "$line" ] || { echo "fixture: the long line did not land"; false; }
  forms_refused K3 "line $line is 1001 bytes long"
  case "$output" in
    *"'$cut [cut]'"*) ;;
    *) echo "K4: the quote is not cut to exactly the quote cut, then ' [cut]'. output: ${output:0:600}"; false ;;
  esac
  printf '%s\n' "$output" | LC_ALL=C awk 'length($0) > 400 { bad = 1 } END { exit bad }' \
    || { echo "K4: a refusal line is longer than 400 bytes. output: ${output:0:600}"; false; }
  forms_put "${long:1}"
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied"
  forms_no_path
  [ "$status" -eq 0 ] \
    || { echo "K3: --released refused a line of exactly the limit. output: ${output:0:600}"; false; }

  # K4: a lone 0x9b byte (a bare terminal control) in a refused line is
  # shown as `?` and never printed.
  forms_put $'## x \x9b'
  line="$(LC_ALL=C awk 'index($0, "## x ") == 1 { print NR }' "$d/$copied/CHANGELOG.md")"
  [ -n "$line" ] || { echo "fixture: the 0x9b plant did not land"; false; }
  forms_refused K4 "line $line holds '## x ?'"
  [ "$(( $(printf '%s' "$output" | LC_ALL=C tr -cd '\233' | wc -c) ))" -eq 0 ] \
    || { echo "K4: the refusal printed the 0x9b byte"; false; }
  # Again under a UTF-8 locale, where the byte is not valid text: the gate
  # must mask it under its own C locale, whatever the caller's is.
  forms_utf8
  run bash -c 'export LC_ALL=$4; cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$d" "$ROOT" "$copied" "$utf8"
  forms_no_path
  [ "$status" -ne 0 ] || { echo "K4: under $utf8, --released accepted the 0x9b plant"; false; }
  case "$output" in
    *"line $line holds '## x ?'"*) ;;
    *) echo "K4: under $utf8, the refusal does not show the 0x9b byte as '?'"; false ;;
  esac
  [ "$(( $(printf '%s' "$output" | LC_ALL=C tr -cd '\233' | wc -c) ))" -eq 0 ] \
    || { echo "K4: under $utf8, the refusal printed the 0x9b byte"; false; }

  # K5: a NUL byte stops both forms with the gate's own message.
  forms_put 'NULplant'
  printf 'bad\000byte\n' >> "$d/$copied/CHANGELOG.md"
  [ "$(( $(LC_ALL=C tr -cd '\000' < "$d/$copied/CHANGELOG.md" | wc -c) ))" -eq 1 ] \
    || { echo "fixture: the NUL plant did not land once"; false; }
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$d" "$ROOT"
  forms_no_path
  [ "$status" -ne 0 ] || { echo "K5: the default form accepted a NUL byte. output: $output"; false; }
  case "$output" in
    *"$copied: CHANGELOG.md holds a NUL byte"*) ;;
    *) echo "K5: the default form stopped without its own message. output: $output"; false ;;
  esac
  forms_refused K5 "$copied: CHANGELOG.md holds a NUL byte"

  # K3, last: a line of quote markers, which an older walk took minutes to
  # read, is refused for its length at once. The release form refuses a
  # changelog over its size limit before the walk, so the line fills the
  # room left under the limit, less a margin, measured on the copy rather
  # than written down: the changelog grows with every release. The line is
  # found with awk: as an argument, a line this long fails on Linux. Its
  # only floor is the rule under test, a line longer than the line limit:
  # a fixed count of pairs failed a correct tree once the copy grew past
  # 153,948 bytes (research R6). The margin is what the plant needs, 64
  # bytes, so the plant fits until the copy leaves less than that and a
  # 1,001-byte line under the limit.
  forms_put 'LONGplant'
  room=$(( changelog_limit - 64 - $(LC_ALL=C wc -c < "$d/$copied/CHANGELOG.md") ))
  pairs=$(( room / 2 - 1 ))
  [ $(( pairs * 2 + 1 )) -gt "$line_limit" ] \
    || { echo "fixture: only $pairs quote markers fit under the size limit, no line longer than $line_limit"; false; }
  LC_ALL=C awk -v n="$pairs" 'BEGIN { s = ""; for (i = 0; i < n; i++) s = s "> "; print s "x" }' >> "$d/$copied/CHANGELOG.md"
  line="$(LC_ALL=C awk 'length($0) > 1000 { print NR }' "$d/$copied/CHANGELOG.md")"
  [ -n "$line" ] || { echo "fixture: the quote-marker line did not land"; false; }
  forms_refused K3 "line $line is $(( pairs * 2 + 1 )) bytes long"
  printf '%s\n' "$output" | LC_ALL=C awk 'length($0) > 400 { bad = 1 } END { exit bad }' \
    || { echo "K4: a refusal line is longer than 400 bytes"; false; }

  # K3, K4: an over-long line of bytes that each need masking is refused
  # for its length, cut, and masked. This line once also guarded the order
  # (cut, then mask) through the per-test timeout, at 400,000 bytes; the
  # size limit now bounds every line the walk reads well below that, so the
  # timeout can no longer see the order, and a short line checks the rest.
  forms_put 'DENSEplant'
  LC_ALL=C awk 'BEGIN { s = ""; for (i = 0; i < 1000; i++) s = s "a\033"; print s }' >> "$d/$copied/CHANGELOG.md"
  line="$(LC_ALL=C awk 'length($0) > 1000 { print NR }' "$d/$copied/CHANGELOG.md")"
  [ -n "$line" ] || { echo "fixture: the dense line did not land"; false; }
  forms_refused K3 "line $line is 2000 bytes long"
  [ "$(( $(printf '%s' "$output" | LC_ALL=C tr -cd '\033' | wc -c) ))" -eq 0 ] \
    || { echo "K4: the refusal of the dense line printed an escape byte"; false; }

  # H8: the default form passes a copy holding every refused plant above
  # that it accepts, each after its own `Plain text.` and blank line. The
  # NUL plant is left out by name: K5 stops both forms.
  forms_put $'CRplant\r## x' '' 'Plain text.' '' "$long" '' 'Plain text.' '' $'## x \x9b' '' 'Plain text.' '' 'LONGplant'
  LC_ALL=C awk 'BEGIN { s = ""; for (i = 0; i < 400000; i++) s = s "> "; print s "x" }' >> "$d/$copied/CHANGELOG.md"
  printf '\nPlain text.\n\nDENSEplant\n' >> "$d/$copied/CHANGELOG.md"
  LC_ALL=C awk 'BEGIN { s = ""; for (i = 0; i < 200000; i++) s = s "a\033"; print s }' >> "$d/$copied/CHANGELOG.md"
  [ "$(LC_ALL=C awk 'length($0) > 1000 { n++ } END { print n + 0 }' "$d/$copied/CHANGELOG.md")" = "3" ] \
    || { echo "fixture: the combined copy does not hold all three long lines"; false; }
  forms_default
}

# gate_run <copy> [<argument>...]: the gate, run in the copy as CI runs it.
# Its output must hold no absolute path (U2).
gate_run() {
  local c=$1
  shift
  run bash -c 'r=$1 c=$2; shift 2; cd "$c" && bash "$r/scripts/check-versions.sh" "$@"' _ "$ROOT" "$c" "$@"
  forms_no_path || return 1
}

# gate_says <clause> <exit status> <fragment>...: the last run exited with
# exactly that status, and its output holds every fragment, each matched as
# a literal: `?` is the mask character and also a glob wildcard.
gate_says() {
  local id=$1 want=$2 f
  shift 2
  [ "$status" -eq "$want" ] \
    || { echo "$id: the gate exited $status, not $want. output: ${output:0:600}"; return 1; }
  for f in "$@"; do
    case "$output" in
      *"$f"*) ;;
      *) echo "$id: the output does not say \"$f\". output: ${output:0:600}"; return 1 ;;
    esac
  done
}

# gate_lacks <clause> <fragment>: the last run's output does not hold the
# fragment, matched as a literal.
gate_lacks() {
  case "$output" in
    *"$2"*) echo "$1: the output says \"$2\". output: ${output:0:600}"; return 1 ;;
  esac
}

@test "the gate reads only a regular changelog of bounded size" {
  cd "$ROOT"
  forms_base one
  local c lk bl links other want size form sfx unreadable rc
  # The release form's refusals end with this; the default form's never do.
  local nr=$' \342\200\224 this tree is NOT released'

  # L1: a link to a regular file, and a link to nothing, are refused as
  # links in both forms. `|| true`: where `ln` cannot make a native link it
  # exits non-zero, and under errexit that would end the test before the
  # fallback below could run.
  lk="$TEST_DIR/regular-link"
  bl="$TEST_DIR/regular-broken"
  cp -r "$base" "$lk"
  cp -r "$base" "$bl"
  cp "$lk/$copied/CHANGELOG.md" "$lk/$copied/real.md"
  rm "$lk/$copied/CHANGELOG.md" "$bl/$copied/CHANGELOG.md"
  (cd "$lk/$copied" && MSYS=winsymlinks:nativestrict ln -s real.md CHANGELOG.md 2>/dev/null) || true
  (cd "$bl/$copied" && MSYS=winsymlinks:nativestrict ln -s missing.md CHANGELOG.md 2>/dev/null) || true
  if [ -L "$lk/$copied/CHANGELOG.md" ]; then links="made"; else links="not available here"; fi
  # Which way this system took, on a pass too: bats hides a passing test's
  # output, so file descriptor 3, and `# ` keeps the line a TAP comment.
  echo "# links: $links" >&3
  if [ -L "$bl/$copied/CHANGELOG.md" ]; then other="made"; else other="not available here"; fi
  [ "$other" = "$links" ] \
    || { echo "fixture: one link was made and the other was not ($links, then $other)"; false; }
  if [ "$links" = "made" ]; then
    want="is a symbolic link"
    sfx=$nr
  else
    # Only where the runner may not make a link: there, what a checkout
    # makes in a link's place, a file holding the target path, is checked
    # instead, and the link rule itself is not reached.
    case "$(uname -s)" in
      MINGW*|MSYS*|CYGWIN*) ;;
      *) echo "fixture: this system made no symbolic link"; false ;;
    esac
    rm -f "$lk/$copied/CHANGELOG.md" "$bl/$copied/CHANGELOG.md"
    printf 'real.md' > "$lk/$copied/CHANGELOG.md"
    printf 'missing.md' > "$bl/$copied/CHANGELOG.md"
    # That refusal is no link refusal, and carries no suffix in either form.
    want="no changelog heading"
    sfx=""
  fi
  for c in "$lk" "$bl"; do
    gate_run "$c"
    gate_says L1 1 "$copied: " "$want"
    gate_lacks L1 "NOT released"
    gate_run "$c" --released "$copied"
    gate_says L1 1 "$copied: " "$want" "$sfx"
  done

  # L2: a directory where the changelog should be is refused in both forms.
  c="$TEST_DIR/regular-dir"
  cp -r "$base" "$c"
  rm "$c/$copied/CHANGELOG.md"
  mkdir "$c/$copied/CHANGELOG.md"
  gate_run "$c"
  gate_says L2 1 "$copied: CHANGELOG.md is not a regular file"
  gate_lacks L2 "NOT released"
  gate_run "$c" --released "$copied"
  gate_says L2 1 "$copied: CHANGELOG.md is not a regular file$nr"

  # L3: exactly the limit is not refused for its size; one byte more is,
  # by the release form only. The padding is one awk program: a per-line
  # bash loop runs bats' debug trap on every line and took 19 s.
  c="$TEST_DIR/regular-size"
  cp -r "$base" "$c"
  size=$(( $(LC_ALL=C wc -c < "$c/$copied/CHANGELOG.md") ))
  [ "$size" -le "$changelog_limit" ] || { echo "fixture: the changelog is already $size bytes"; false; }
  LC_ALL=C awk -v BINMODE=3 -v n=$((changelog_limit - size)) \
    'BEGIN { while (n >= 12) { print "Plain text."; n -= 12 } if (n > 0) { t = ""; for (i = 1; i < n; i++) t = t "y"; print t } }' \
    >> "$c/$copied/CHANGELOG.md"
  size=$(( $(LC_ALL=C wc -c < "$c/$copied/CHANGELOG.md") ))
  [ "$size" -eq "$changelog_limit" ] || { echo "fixture: the padded changelog is $size bytes, not $changelog_limit"; false; }
  gate_run "$c" --released "$copied"
  gate_says L3 0
  printf 'y' >> "$c/$copied/CHANGELOG.md"
  size=$(( $(LC_ALL=C wc -c < "$c/$copied/CHANGELOG.md") ))
  [ "$size" -eq $((changelog_limit + 1)) ] || { echo "fixture: the changelog is $size bytes, not $((changelog_limit + 1))"; false; }
  gate_run "$c" --released "$copied"
  gate_says L3 1 "$copied: " "$((changelog_limit + 1)) bytes" "($changelog_limit)$nr"
  gate_run "$c"
  gate_says L3 0

  # L4: a missing changelog gets the gate's own line in both forms, and
  # nothing else: a line from another program would print the path raw.
  c="$TEST_DIR/regular-missing"
  cp -r "$base" "$c"
  rm "$c/$copied/CHANGELOG.md"
  for form in "" "--released"; do
    gate_run "$c" ${form:+--released "$copied"}
    gate_says L4 1
    [ "$output" = "check-versions.sh: $copied: no changelog heading in the pinned '## [X.Y.Z] - YYYY-MM-DD' format" ] \
      || { echo "L4: the output is not the gate's own line alone. output: ${output:0:600}"; false; }
  done

  # L5: a plugin.json, then a changelog, that the gate may not open gets
  # the gate's own line alone: the shell would print the path raw. Only
  # where a mode of 000 stops a read; on Windows it does not, and as root
  # nothing does, so there this sub-check cannot run, and says so. Its
  # mutant can therefore go red only on the Linux and macOS runners.
  c="$TEST_DIR/regular-unreadable"
  cp -r "$base" "$c"
  chmod 000 "$c/$copied/.claude-plugin/plugin.json"
  if [ -r "$c/$copied/.claude-plugin/plugin.json" ]; then unreadable="not available here"; else unreadable="made"; fi
  echo "# unreadable: $unreadable" >&3
  if [ "$unreadable" = "made" ]; then
    gate_run "$c"
    gate_says L5 1
    [ "$output" = "check-versions.sh: $copied: plugin.json could not be read" ] \
      || { echo "L5: the output is not the gate's own line alone. output: ${output:0:600}"; false; }
    # Again in bash's POSIX mode, where a failed redirect on `:` would end
    # the script before its message (L6).
    run bash -c 'cd "$1" && POSIXLY_CORRECT=1 bash "$2/scripts/check-versions.sh"' _ "$c" "$ROOT"
    forms_no_path
    [ "$output" = "check-versions.sh: $copied: plugin.json could not be read" ] \
      || { echo "L5: in POSIX mode, the output is not the gate's own line alone. output: ${output:0:600}"; false; }
    chmod 644 "$c/$copied/.claude-plugin/plugin.json"
    chmod 000 "$c/$copied/CHANGELOG.md"
    gate_run "$c" --released "$copied"
    gate_says L5 1
    [ "$output" = "check-versions.sh: $copied: CHANGELOG.md could not be read$nr" ] \
      || { echo "L5: the output is not the gate's own line alone. output: ${output:0:600}"; false; }
  fi
  chmod 644 "$c/$copied/.claude-plugin/plugin.json" "$c/$copied/CHANGELOG.md"

  # L6: bash's POSIX mode, set by POSIXLY_CORRECT in the caller's
  # environment, changes nothing in either form. In it GNU grep reads the
  # `--` after a pattern as a file name: a grep error, and a raw path in
  # the report line (measured).
  for form in "" "--released"; do
    gate_run "$base" ${form:+--released "$copied"}
    want=$output
    rc=$status
    run bash -c 'r=$1 c=$2; shift 2; cd "$c" && POSIXLY_CORRECT=1 bash "$r/scripts/check-versions.sh" "$@"' \
      _ "$ROOT" "$base" ${form:+--released "$copied"}
    forms_no_path
    [ "$status" -eq "$rc" ] && [ "$output" = "$want" ] \
      || { echo "L6: in POSIX mode the gate exited $status (not $rc) or printed otherwise. output: ${output:0:600}"; false; }
  done
}

# gate_safe <clause>: the last run's output is printed safely. With only
# the gate's own ` — this tree is NOT released` removed, no byte is
# outside space to `~`, no line starts with `::` after any spaces, and no
# line holds `##[` (research R6). Any other em dash fails it: removing
# every one passed an em dash a value carried. The gate's other em dash,
# in "run me from the repository root", is in no output read here; if it
# ever is, this fails, as it should. Matched in bash under the C locale,
# with no process: a CR is caught as any other byte, where Windows gawk
# would drop one before a line feed. The suffix is held in a variable and
# quoted as the pattern, as the gate holds its own.
gate_safe() {
  local LC_ALL=C
  local sfx=$' \342\200\224 this tree is NOT released' hh='##['
  local o=$'\n'"${output//"$sfx"/}" bad=$'[^\n -~]' cmd=$'\n *::'
  if [[ $o =~ $bad ]] || [[ $o =~ $cmd ]] || [[ $o == *"$hh"* ]]; then
    echo "$1: the output is not printed safely. output: ${output:0:600}"
    return 1
  fi
}

# die_raw <file>: prints `<line>: <name>` for every variable a `die "` line
# of the file expands that is neither a masked copy (named `_s`) nor one of
# the values the gate itself makes. `$((size))` is arithmetic, not a name.
# A static scan: no run of the gate can reach every die line.
# The report line's printf is scanned too, with every line it continues on;
# so are positional parameters. A name ending `_s` is trusted only because
# every line that assigns one is checked too: it may be set to '' (the
# declarations), or be pr_s, which the report line builds from p_s. Any
# other such assignment prints as `<line>: <name>=`, and so does a name
# ending `_s` that `printf -v`, `read` or `for` sets. A `$(` in a scanned
# line that is not `$((` prints as `<line>: $(`: a command substitution
# prints what it runs, raw. A `die` line ending in `\` is continued onto
# the next line, as the report line is. Comments are skipped.
die_raw() {
  LC_ALL=C awk '
    function scan(s,  v, u, k) {
      u = s
      while ((k = index(u, "$(")) > 0) {
        if (substr(u, k + 2, 1) != "(") print NR ": $("
        u = substr(u, k + 2)
      }
      while (match(s, /[$]([{]?[A-Za-z_][A-Za-z0-9_]*|[{]?[0-9]|[*@#?])/)) {
        v = substr(s, RSTART + 1, RLENGTH - 1)
        sub(/^[{]/, "", v)
        s = substr(s, RSTART + RLENGTH)
        if (v ~ /_s$/ || v ~ /^(refusal|unreleased|changelog_limit|source_limit|component_limit|entries|checked|released_state)$/) continue
        print NR ": " v
      }
    }
    /^[ \t]*#/ { next }
    {
      t = $0
      while (match(t, /[A-Za-z_][A-Za-z0-9_]*_s=/)) {
        n = substr(t, RSTART, RLENGTH - 1)
        t = substr(t, RSTART + RLENGTH)
        if (n != "pr_s" && substr(t, 1, 2) != "\047\047") print NR ": " n "="
      }
      t = " " $0
      while (match(t, /[^A-Za-z0-9_]printf[ \t]+-v[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
        n = substr(t, RSTART, RLENGTH)
        t = substr(t, RSTART + RLENGTH)
        sub(/^.printf[ \t]+-v[ \t]+/, "", n)
        if (n ~ /_s$/) print NR ": " n "="
      }
      t = " " $0
      while (match(t, /[^A-Za-z0-9_]read[ \t][^;&|<>)]*/)) {
        r = substr(t, RSTART + 6, RLENGTH - 6)
        t = substr(t, RSTART + RLENGTH)
        k = split(r, w, /[ \t]+/)
        for (i = 1; i <= k; i++) if (w[i] ~ /^[A-Za-z_][A-Za-z0-9_]*_s$/) print NR ": " w[i] "="
      }
      t = " " $0
      while (match(t, /[^A-Za-z0-9_]for[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
        n = substr(t, RSTART, RLENGTH)
        t = substr(t, RSTART + RLENGTH)
        sub(/^.for[ \t]+/, "", n)
        if (n ~ /_s$/) print NR ": " n "="
      }
    }
    more { scan($0); more = /\\$/; next }
    index($0, "plugin=%s") { scan($0); more = /\\$/; next }
    index($0, "die \"") { scan(substr($0, index($0, "die \""))); more = /\\$/ }' "$1"
}

# json_set <file> <jq program> <value>: rewrites the file through jq, the
# value as $v. Read on standard input: native Windows jq cannot open a path
# holding `:` or a control byte. Entries are chosen by position, never by
# name, which is the one-script test's marker.
json_set() {
  local j
  j="$(jq --arg v "$3" "$2" < "$1")" \
    || { echo "fixture: jq could not edit ${1##*/}"; return 1; }
  printf '%s\n' "$j" > "$1"
}

# gate_forged <clause> <copy name> <file in the copy> <jq program>
# <fragment>...: a fresh copy of the base with the forged value F written
# by the program, run in the default form. It must exit 1, say every
# fragment, and print safely. F is the caller's.
gate_forged() {
  local id=$1 c="$TEST_DIR/$2" f=$3 prog=$4
  shift 4
  cp -r "$base" "$c"
  json_set "$c/$f" "$prog" "$F" || return 1
  gate_run "$c" || return 1
  gate_says "$id" 1 "$@" || return 1
  gate_safe "$id"
}

@test "the gate prints every value masked, and no line starts with ::" {
  cd "$ROOT"
  # X2, a TEMPORARY probe: on a runner only, five lines through file
  # descriptor 3, which bats writes to the log as they are, to measure
  # where in a line the runner acts on `##[`, with `::warning::` as a
  # control it is known to act on. Measured once in this pull request's
  # CI, recorded in research R3, and removed before merge. Locally it
  # prints nothing: the suite check refuses a line that is not TAP.
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    printf '%s\n' '##[warning]p28 probe: start of line' '# x ##[warning]p28 probe: mid-line' \
      '##[group]p28 probe: group' '##[endgroup]' '::warning::p28 probe: control' >&3
  fi
  local F E c dn want long cut o rc raw
  # The check itself, before anything leans on it: each unsafe shape must
  # fail it, with exactly 1, including an em dash that is not the gate's
  # own suffix and a `##[`, and the gate's own suffix must pass it.
  for o in $'a\033b' $'ok\n  ::x' $'a\rb' $'ok \342\200\224 ok' $'a \342\200\224 b' 'x ##[y'; do
    output=$o
    rc=0
    gate_safe ctl > /dev/null || rc=$?
    [ "$rc" -eq 1 ] || { echo "control: gate_safe returned $rc on an unsafe output, not 1"; false; }
  done
  output=$'x: y \342\200\224 this tree is NOT released'
  gate_safe ctl || { echo "control: gate_safe refused the gate's own suffix"; false; }

  forms_base one
  # A forged value: a line feed, a workflow command, an escape sequence.
  E=$'\033'
  F="1.0.0"$'\n'"::error title=x::y${E}[2K"

  # P1: a plugin.json version, then a name. The fragments avoid the line
  # feed: native Windows jq writes it as CR LF, so it is masked as one `?`
  # or two.
  gate_forged P1 masked-pv "$copied/.claude-plugin/plugin.json" '.version = $v' "1.0.0?" "::error title=x::y?[2K"
  gate_forged P1 masked-pn "$copied/.claude-plugin/plugin.json" '.name = $v' "1.0.0?" "::error title=x::y?[2K"

  # P2: the marketplace entry's version and source, then two appended
  # entries, which only the reverse walk reaches. It reads them through
  # @tsv, which writes the line feed as a backslash and `n`.
  gate_forged P2 masked-mv .claude-plugin/marketplace.json '.plugins[0].version = $v' "1.0.0?" "::error title=x::y?[2K"
  gate_forged P2 masked-ms .claude-plugin/marketplace.json '.plugins[0].source = $v' "1.0.0?" "::error title=x::y?[2K"
  gate_forged P2 masked-ghost .claude-plugin/marketplace.json '.plugins += [{name: $v, source: ("./ghost" + $v)}]' \
    '1.0.0\n::error title=x::y?[2K' "names no plugin directory"
  gate_forged P2 masked-abs .claude-plugin/marketplace.json '.plugins += [{name: $v, source: ("/abs" + $v)}]' \
    '1.0.0\n::error title=x::y?[2K' "is an absolute path"
  gate_forged P2 masked-up .claude-plugin/marketplace.json '.plugins += [{name: $v, source: ("../x" + $v)}]' \
    '1.0.0\n::error title=x::y?[2K' "leaves the repository"

  # P3: a plugin directory named `::`, an escape, `x`; then the same after
  # a space. The run passes, and the report line starts with `?`. The name
  # is set before the rename: jq could not open the renamed path.
  for dn in "::${E}x" " ::${E}x"; do
    want="?:?x: plugin="
    if [ "${dn:0:1}" = " " ]; then want="??:?x: plugin="; fi
    c="$TEST_DIR/masked-dir-${#dn}"
    cp -r "$base" "$c"
    json_set "$c/$copied/.claude-plugin/plugin.json" '.name = $v' "$dn"
    json_set "$c/.claude-plugin/marketplace.json" '.plugins[0].name = $v | .plugins[0].source = ("./" + $v)' "$dn"
    mv "$c/$copied" "$c/$dn"
    [ -f "$c/$dn/.claude-plugin/plugin.json" ] || { echo "fixture: the directory '${dn//$E/?}' could not be made"; false; }
    gate_run "$c"
    gate_says P3 0
    gate_safe P3
    case "$output" in
      "$want"*) ;;
      *) echo "P3: the report line does not start with '$want'. output: ${output:0:600}"; false ;;
    esac
  done
  # The name in a die message: plugin.json names another plugin.
  c="$TEST_DIR/masked-dir-other"
  cp -r "$base" "$c"
  json_set "$c/$copied/.claude-plugin/plugin.json" '.name = $v' "other"
  mv "$c/$copied" "$c/::${E}x"
  gate_run "$c"
  gate_says P3 1 "::?x: plugin.json name 'other'"
  gate_safe P3

  # P4: an escape in the --released argument, and in an unknown argument.
  gate_run "$base" --released "a${E}b"
  gate_says P4 1 "'a?b'"
  gate_safe P4
  gate_run "$base" "x${E}y"
  gate_says P4 1 "'x?y'"
  gate_safe P4

  # P5: a first heading holding an escape sequence above the release. It
  # is masked in the report line and in the refusal, and the refusal keeps
  # the gate's own em dash.
  c="$TEST_DIR/masked-first"
  cp -r "$base" "$c"
  { printf '## [Unreleased] %s[2K\n' "$E"; cat "$base/$copied/CHANGELOG.md"; } > "$c/$copied/CHANGELOG.md"
  gate_run "$c" --released "$copied"
  gate_says P5 1 "state=UNRELEASED-ABOVE:## [Unreleased] ?[2K" \
    "'## [Unreleased] ?[2K' sits above the released heading" $'\342\200\224 this tree is NOT released'
  gate_safe P5

  # P6: a value over the quote cut is cut, then ` [cut]`.
  printf -v long '%250s' ''
  long=${long// /x}
  cut=${long:0:200}
  c="$TEST_DIR/masked-long"
  cp -r "$base" "$c"
  json_set "$c/$copied/.claude-plugin/plugin.json" '.version = $v' "$long"
  gate_run "$c"
  gate_says P6 1 "plugin=$cut [cut]"
  case "$output" in
    *"${cut}x"*) echo "P6: more than the quote cut of the value was printed. output: ${output:0:600}"; false ;;
  esac
  gate_safe P6
  # Exactly the quote cut is printed whole, with no ` [cut]`.
  c="$TEST_DIR/masked-edge"
  cp -r "$base" "$c"
  json_set "$c/$copied/.claude-plugin/plugin.json" '.version = $v' "$cut"
  gate_run "$c"
  gate_says P6 1 "plugin=$cut marketplace="
  gate_lacks P6 " [cut]"
  # A value of 1,000,000 escape bytes is cut before it is masked: masking
  # it whole takes time that grows with the square of its length, minutes
  # here, and a plugin.json has no size limit. Bounded by timeout where the
  # system has one, and by the per-test timeout where it does not. jq takes
  # the value from a file: as an argument it is too long.
  c="$TEST_DIR/masked-huge"
  cp -r "$base" "$c"
  printf '%1000000s' '' | LC_ALL=C tr ' ' '\033' > "$TEST_DIR/huge.bin"
  jq --rawfile v "$TEST_DIR/huge.bin" '.version = $v' < "$c/$copied/.claude-plugin/plugin.json" > "$TEST_DIR/huge.json" \
    || { echo "fixture: jq could not write the 1,000,000-byte version"; false; }
  cp "$TEST_DIR/huge.json" "$c/$copied/.claude-plugin/plugin.json"
  if command -v timeout > /dev/null; then
    run timeout 20 bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$c" "$ROOT"
  else
    run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$c" "$ROOT"
  fi
  forms_no_path
  gate_says P6 1 "plugin=$(printf '%200s' '' | tr ' ' '?') [cut]"
  gate_safe P6
  # And under a UTF-8 locale: a byte that is not valid text, and an `é`,
  # are each shown as `?`, one per byte.
  forms_utf8
  run bash -c 'export LC_ALL=$1; cd "$2" && bash "$3/scripts/check-versions.sh" "$4"' _ "$utf8" "$base" "$ROOT" $'x\x9b\xc3\xa9y'
  forms_no_path
  gate_says P6 1 "'x???y'"
  gate_safe P6

  # X1: `##[`, which a workflow log may read as a command, is shown as
  # `#?[` wherever a printed value holds it: a plugin.json version; a
  # first heading above the release; a changelog line the walk refuses,
  # whose text the walk prints, under the C locale and then with LANG set
  # to a UTF-8 locale and LC_ALL unset, as runners set them.
  F='1.0.0 ##[error]x'
  gate_forged X1 x1-version "$copied/.claude-plugin/plugin.json" '.version = $v' "plugin=1.0.0 #?[error]x"
  gate_lacks X1 '##['
  c="$TEST_DIR/x1-first"
  cp -r "$base" "$c"
  { printf '## [Unreleased] ##[error]x\n'; cat "$base/$copied/CHANGELOG.md"; } > "$c/$copied/CHANGELOG.md"
  gate_run "$c" --released "$copied"
  gate_says X1 1 "state=UNRELEASED-ABOVE:## [Unreleased] #?[error]x" \
    "'## [Unreleased] #?[error]x' sits above the released heading"
  gate_lacks X1 '##['
  gate_safe X1
  forms_put '## Notes ##[error]x'
  gate_run "$d" --released "$copied"
  gate_says X1 1 "holds '## Notes #?[error]x', which is not a dated version heading"
  gate_lacks X1 '##['
  gate_safe X1
  forms_utf8
  run bash -c 'unset LC_ALL; export LANG=$1; r=$2 c=$3; shift 3; cd "$c" && bash "$r/scripts/check-versions.sh" "$@"' \
    _ "$utf8" "$ROOT" "$d" --released "$copied"
  forms_no_path
  gate_says X1 1 "holds '## Notes #?[error]x', which is not a dated version heading"
  gate_lacks X1 '##['
  gate_safe X1

  # P0, last, so that against an older gate a run's own clause speaks
  # first: every value a die line prints is a masked copy, including the
  # die lines no run above reaches. First the scan itself, on lines of
  # its own rather than a copy of the gate, which would move with the
  # gate: a raw name, plain and braced, must be found by name, and the
  # allowed shapes must not. Then (T1) a name ending `_s` set by
  # `printf -v`, by `read` and by `for`, a `$(` in a die message, and a
  # raw name on the line a die line ending in `\` continues onto; and
  # last the gate's own shapes of each, which must not be found.
  printf '%s\n' 'die "$p_s: $((size)) ($changelog_limit)$unreleased"' \
    'shown arg_s "$1"; die "x $p y ${pn}"' 'die "$refusal $entries $checked"' \
    'printf "%s: plugin=%s\n" \' '  "$pr_s" "$pv" "$released_state"' 'echo "$x"' \
    'die "z $1 $*"' 'size_s=$pv' $'p_s=\'\' pr_s=$x' '  # die "$q" size_s=$q' \
    'printf -v a_s %s "$x"' 'IFS= read -r b_s c' 'for c_s in x; do :; done' \
    'die "x $(id) $((n))"' 'die "y \' '  $q"' \
    'printf -v "$1" %s "$s"; read -r en es; for dir in x; do :; done; die "could not be read$u_s"' > "$TEST_DIR/planted.sh"
  raw="$(die_raw "$TEST_DIR/planted.sh")"
  [ "$raw" = "2: p"$'\n'"2: pn"$'\n'"5: pv"$'\n'"7: 1"$'\n'"7: *"$'\n'"8: size_s="$'\n'"11: a_s="$'\n'"12: b_s="$'\n'"13: c_s="$'\n'"14: \$("$'\n'"16: q" ] \
    || { echo "control: the die scan did not name exactly the planted p, pn, pv, 1, *, size_s=, a_s=, b_s=, c_s=, \$( and q. it printed: $raw"; false; }
  raw="$(die_raw scripts/check-versions.sh)"
  [ -z "$raw" ] || { echo "P0: a die line prints a raw value: $raw"; false; }
}

@test "--released refuses a plugin name that matches nothing, rather than enforcing nothing" {
  cd "$ROOT"
  # A caller asking for a STRICTER check must never receive a weaker one. With
  # no plugin matching the name, the enforcement runs zero times, and a walk
  # over zero items reports zero problems.
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released "$3"' _ "$ROOT" "$ROOT" definitely-not-a-plugin
  forms_no_path
  [ "$status" -ne 0 ] \
    || { echo "--released accepted a plugin name matching nothing and enforced nothing. output: $output"; false; }
  case "$output" in
    *"nothing was enforced"*) ;;
    *) echo "it refused, but not for the vacuous-enforcement reason. output: $output"; false ;;
  esac
  # An empty name matches nothing too, and once passed, enforcing nothing:
  # the end check skipped an empty name. A tag spelled `-v1.2.0` makes CI
  # pass one.
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh" --released ""' _ "$ROOT" "$ROOT"
  forms_no_path
  [ "$status" -ne 0 ] \
    || { echo "--released accepted an empty plugin name and enforced nothing. output: $output"; false; }
  case "$output" in
    *"--released needs a plugin name"*) ;;
    *) echo "an empty --released name was refused, but not as a missing name. output: $output"; false ;;
  esac
}

# gate_json <clause> <copy> <message>: the gate, run in the copy in the
# default form, exits 1 and prints the gate's whole line alone (research
# R2): no line from jq, and not bash's line about a NUL read through
# `$( )`. The clause's own checks come before forms_no_path, because
# bash's line names the gate by its path: it must be red on the clause.
gate_json() {
  local id=$1 c=$2 want=$3
  run bash -c 'r=$1 c=$2; cd "$c" && bash "$r/scripts/check-versions.sh"' _ "$ROOT" "$c"
  case $'\n'"$output" in
    *$'\n'jq:*) echo "$id: a line from jq reached the output. output: ${output:0:600}"; return 1 ;;
  esac
  case "$output" in
    *"ignored null byte"*) echo "$id: bash's line about a NUL byte reached the output. output: ${output:0:600}"; return 1 ;;
  esac
  gate_refuses "$id" "$want" || return 1
  [ "$output" = "$want" ] \
    || { echo "$id: the output is not the gate's own line alone. output: ${output:0:600}"; return 1; }
  forms_no_path || return 1
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
  #
  # The first plant below, an entry whose name is an object, is now stopped
  # by the gate's shape check of marketplace.json, before the @tsv read it
  # was written for (research R2): no plant reaches that read failing any
  # more, and its `|| die` is a backstop. The J plants at the end check the
  # shape check's own lines.
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

  # The walk's input, sized by a trailing entry's name to 65,600 bytes:
  # Git Bash hung, naming nothing, on a herestring of 65,536 to about
  # 65,700 bytes. Measured with the walk's own jq program, held here as a
  # copy: a fixture that read the gate would move with it.
  local w="$TEST_DIR/trailing-long" prog='.plugins[] | [.name, (.source // "")] | @tsv' len n
  mkdir -p "$w/.claude-plugin"
  cp -r "$t/$d" "$w/$d"
  jq --argjson n 1 '{name: "fixture", plugins: [ .plugins[0], {name: ("f" * $n), source: "./ghost"} ]}' \
    .claude-plugin/marketplace.json > "$w/.claude-plugin/marketplace.json"
  len="$(jq -r "$prog" "$w/.claude-plugin/marketplace.json")"
  len=$(LC_ALL=C; echo "${#len}")
  n=$(( 65600 - len + 1 ))
  jq --argjson n "$n" '{name: "fixture", plugins: [ .plugins[0], {name: ("f" * $n), source: "./ghost"} ]}' \
    .claude-plugin/marketplace.json > "$w/.claude-plugin/marketplace.json"
  len="$(jq -r "$prog" "$w/.claude-plugin/marketplace.json")"
  len=$(LC_ALL=C; echo "${#len}")
  [ "$len" -eq 65600 ] || { echo "fixture: the walk's input is $len bytes, not 65600"; false; }
  if command -v timeout > /dev/null; then
    run timeout 30 bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$w" "$ROOT"
  else
    run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$w" "$ROOT"
  fi
  [ "$status" -eq 1 ] \
    || { echo "a 65,600-byte walk input: the gate exited $status, not 1 (124 is the timeout). output: ${output:0:600}"; false; }
  case "$output" in
    *"names no plugin directory"*) ;;
    *) echo "a 65,600-byte walk input was not refused for its ghost entry. output: ${output:0:600}"; false ;;
  esac

  # A source of exactly the source limit (the tests' own copy) is read; one
  # character more is refused before it is normalised, in the forward walk
  # and in the reverse walk, which alone reaches an entry naming no plugin.
  # Padded with separators, which normalising collapses.
  local source_limit=4096 pad
  pad="$(printf '%*s' $(( source_limit - 2 - ${#d} )) '' | tr ' ' /)"
  jq --arg s "./$pad$d" '{name: "fixture", plugins: [ .plugins[0] | .source = $s ]}' \
    .claude-plugin/marketplace.json > "$w/.claude-plugin/marketplace.json"
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$w" "$ROOT"
  [ "$status" -eq 0 ] \
    || { echo "a source of exactly $source_limit characters was refused. output: ${output:0:600}"; false; }
  jq --arg s "./$pad/$d" '{name: "fixture", plugins: [ .plugins[0] | .source = $s ]}' \
    .claude-plugin/marketplace.json > "$w/.claude-plugin/marketplace.json"
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$w" "$ROOT"
  [ "$status" -eq 1 ] || { echo "a source one character over the limit: exit $status, not 1"; false; }
  case "$output" in
    *"has a source longer than $source_limit characters"*) ;;
    *) echo "the forward walk did not refuse a source over the limit. output: ${output:0:600}"; false ;;
  esac
  jq --arg s "./$pad/$d" '{name: "fixture", plugins: [ .plugins[0], {name: "ghost", source: $s} ]}' \
    .claude-plugin/marketplace.json > "$w/.claude-plugin/marketplace.json"
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$w" "$ROOT"
  [ "$status" -eq 1 ] || { echo "a ghost source one character over the limit: exit $status, not 1"; false; }
  case "$output" in
    *"marketplace entry 'ghost': source"*"is longer than $source_limit characters"*) ;;
    *) echo "the reverse walk did not refuse a source over the limit. output: ${output:0:600}"; false ;;
  esac

  # J1, J2: a marketplace.json or plugin.json that is not JSON, or not of
  # the shape the gate's reads need, is refused with the gate's own line
  # alone, before any other read of the file (research R2). Each plant is
  # its own copy of a clean base, which must pass first. A NUL is written
  # with jq as the \u0000 escape: a raw NUL byte is not JSON.
  local jb="$TEST_DIR/json-base" m=.claude-plugin/marketplace.json pj="$d/.claude-plugin/plugin.json" c
  local E=$'\033' mw mn pw pn
  mw="check-versions.sh: .claude-plugin/marketplace.json is not one object whose plugins is a list of entries with string name, source and version, and no NUL character"
  mn="check-versions.sh: .claude-plugin/marketplace.json is not valid JSON"
  pw="check-versions.sh: $d: plugin.json is not one object with a string name and version, and no NUL character"
  pn="check-versions.sh: $d: plugin.json is not valid JSON"
  mkdir -p "$jb/.claude-plugin"
  cp -r "$t/$d" "$jb/$d"
  jq '.plugins |= .[:1]' .claude-plugin/marketplace.json > "$jb/$m"
  run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$jb" "$ROOT"
  forms_no_path
  [ "$status" -eq 0 ] \
    || { echo "fixture: the clean base is refused, so no plant below would prove anything. output: ${output:0:600}"; false; }

  # J1: a trailing entry whose name is an object; a plugins that is a
  # string holding a workflow command and an escape; two documents, of
  # which jq -e alone judges only the last (measured); valid JSON of the
  # wrong type.
  c="$TEST_DIR/json-name-object"; cp -r "$jb" "$c"
  json_set "$c/$m" '.plugins += [{name: {"::error title=x::y": 1}, source: "./ghost"}]' ""
  gate_json J1 "$c" "$mw"
  c="$TEST_DIR/json-plugins-string"; cp -r "$jb" "$c"
  json_set "$c/$m" '.plugins = $v' "::error title=x::y${E}[2K"
  gate_json J1 "$c" "$mw"
  c="$TEST_DIR/json-two-documents"; cp -r "$jb" "$c"
  { printf '{"plugins": "x"}\n'; cat "$jb/$m"; } > "$c/$m"
  gate_json J1 "$c" "$mw"
  c="$TEST_DIR/json-array"; cp -r "$jb" "$c"
  printf '[]\n' > "$c/$m"
  gate_json J1 "$c" "$mw"

  # J2: each file not JSON, then empty, which is not JSON either; a
  # plugin.json whose name is a number, of two documents, or that is `[]`;
  # a NUL in a plugin.json string and in a marketplace string. The two
  # documents come before `[]`: read without -s, `[]` is sent to error as
  # empty, so a gate that dropped -s would be red on `[]` first, hiding
  # whether the two documents alone catch it.
  c="$TEST_DIR/json-m-not-json"; cp -r "$jb" "$c"
  printf '{"plugins": [\n' > "$c/$m"
  gate_json J2 "$c" "$mn"
  c="$TEST_DIR/json-m-empty"; cp -r "$jb" "$c"
  : > "$c/$m"
  gate_json J2 "$c" "$mn"
  c="$TEST_DIR/json-p-not-json"; cp -r "$jb" "$c"
  printf '{"name": [\n' > "$c/$pj"
  gate_json J2 "$c" "$pn"
  c="$TEST_DIR/json-p-empty"; cp -r "$jb" "$c"
  : > "$c/$pj"
  gate_json J2 "$c" "$pn"
  c="$TEST_DIR/json-p-name-number"; cp -r "$jb" "$c"
  json_set "$c/$pj" '.name = 1' ""
  gate_json J2 "$c" "$pw"
  c="$TEST_DIR/json-p-two-documents"; cp -r "$jb" "$c"
  { printf '{"name": 1}\n'; cat "$jb/$pj"; } > "$c/$pj"
  gate_json J2 "$c" "$pw"
  c="$TEST_DIR/json-p-array"; cp -r "$jb" "$c"
  printf '[]\n' > "$c/$pj"
  gate_json J2 "$c" "$pw"
  c="$TEST_DIR/json-p-nul"; cp -r "$jb" "$c"
  json_set "$c/$pj" '.version += "\u0000"' ""
  LC_ALL=C grep -q -F -- '\u0000' "$c/$pj" || { echo "fixture: the plugin.json NUL plant did not land"; false; }
  gate_json J2 "$c" "$pw"
  c="$TEST_DIR/json-m-nul"; cp -r "$jb" "$c"
  json_set "$c/$m" '.plugins[0].source += "\u0000"' ""
  LC_ALL=C grep -q -F -- '\u0000' "$c/$m" || { echo "fixture: the marketplace NUL plant did not land"; false; }
  gate_json J2 "$c" "$mw"

  # C1, after the J plants: the first plugin and 2,000 more entries naming
  # it, which the reverse walk reads one by one before the count refuses
  # them. With a process per entry that took 20 to 37 ms an entry here
  # (research R5), 40 s or more; without, a few seconds. Where a process is
  # cheap the bound cannot see one, so the system is printed, on a pass
  # as on a failure.
  echo "# walk: $(uname -s)" >&3
  c="$TEST_DIR/walk-2000"; cp -r "$jb" "$c"
  jq --arg s "./$d" '.plugins = [.plugins[0]] + [range(2000) | {name: "x\(.)", source: $s}]' "$jb/$m" > "$c/$m" \
    || { echo "fixture: jq could not write the 2,000 entries"; false; }
  [ "$(jq '.plugins | length' "$c/$m")" = "2001" ] || { echo "fixture: the marketplace does not list 2,001 entries"; false; }
  if command -v timeout > /dev/null; then
    run timeout 15 bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$c" "$ROOT"
  else
    run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$c" "$ROOT"
  fi
  forms_no_path
  [ "$status" -eq 1 ] \
    || { echo "C1: 2,001 entries: the gate exited $status, not 1 (124 is the timeout). output: ${output:0:600}"; false; }
  gate_says C1 1 "check-versions.sh: marketplace lists 2001 plugins, the tree holds 1"
  gate_safe C1
}

# nolink_make <target> <name>: a symbolic link, made as L1 makes one.
# `|| true`: where ln cannot make a native link it exits non-zero, and
# under errexit that would end the test before the fixture line below.
# Called only where the test's first link was made, so a link not made
# here is a fixture failure on every system.
nolink_make() {
  MSYS=winsymlinks:nativestrict ln -s "$1" "$2" 2>/dev/null || true
  [ -L "$2" ] || { echo "fixture: the link ${2##*/} was not made"; return 1; }
}

# gate_refuses <clause> <message>: the last run exited 1, said the whole
# message, from `check-versions.sh: ` on, and printed safely.
gate_refuses() {
  gate_says "$1" 1 "$2" || return 1
  gate_safe "$1"
}

@test "the gate follows no link, and keeps its own shell options" {
  cd "$ROOT"
  forms_base one
  local c k o m src pad links aa='a/' to=""
  # The test's own copies of the gate's limits and words: a fixture that
  # read the gate would move with it.
  local component_limit=64 quote_cut=200 source_limit=4096
  local fol=", which the gate does not follow"
  local out="$TEST_DIR/nolink-outside"
  mkdir -p "$out"

  # N5, before any run, so the line is printed whatever fails below. The
  # first link, N1's plugin.json pointing at a file outside the copy,
  # decides whether this system makes links at all, as L1 decides. Which
  # way it took goes through file descriptor 3: bats hides a passing
  # test's output.
  printf '{"name":"OUTSIDE-NAME","version":"9.9.9"}\n' > "$out/plugin.json"
  c="$TEST_DIR/nolink-n1"
  cp -r "$base" "$c"
  rm "$c/$copied/.claude-plugin/plugin.json"
  MSYS=winsymlinks:nativestrict ln -s "$out/plugin.json" "$c/$copied/.claude-plugin/plugin.json" 2>/dev/null || true
  if [ -L "$c/$copied/.claude-plugin/plugin.json" ]; then links="made"; else links="not available here"; fi
  echo "# nolinks: $links" >&3
  if [ "$links" != "made" ]; then
    case "$(uname -s)" in
      MINGW*|MSYS*|CYGWIN*) ;;
      *) echo "fixture: this system made no symbolic link"; false ;;
    esac
  fi

  # N7, first among the runs: it needs no link, so against an older gate it
  # is the first red on every system. Each source is `./` and then `a/a/…`,
  # its first component a real directory and the rest missing. At the
  # limit the source is read, and names no plugin directory; over it, the
  # count refuses it before any file test, at 2,046 components too (under
  # the source limit). The limit's own source first, so a limit set one
  # lower is red on it.
  if command -v timeout > /dev/null; then to=1; fi
  for k in "$component_limit" $((component_limit + 1)) 2046; do
    printf -v pad '%*s' $((k - 1)) ''
    src="./${pad// /$aa}a"
    [ "${#src}" -le "$source_limit" ] || { echo "fixture: the $k-component source is ${#src} characters, over the source limit"; false; }
    c="$TEST_DIR/nolink-n7-$k"
    cp -r "$base" "$c"
    mkdir "$c/a"
    json_set "$c/.claude-plugin/marketplace.json" '.plugins += [{name: "deep", source: $v}]' "$src"
    if [ -n "$to" ]; then
      run timeout 15 bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$c" "$ROOT"
    else
      run bash -c 'cd "$1" && bash "$2/scripts/check-versions.sh"' _ "$c" "$ROOT"
    fi
    forms_no_path
    if [ "$k" -gt "$component_limit" ]; then
      m="'$src'"
      if [ "${#src}" -gt "$quote_cut" ]; then m="'${src:0:$quote_cut} [cut]'"; fi
      gate_refuses N7 "check-versions.sh: marketplace entry 'deep': source $m has more than $component_limit components"
    else
      gate_refuses N7 "check-versions.sh: marketplace entry 'deep': source '$src' names no plugin directory"
    fi
  done

  if [ "$links" = "made" ]; then
    # N1, in both forms: no link check reads anything the form sets, so
    # the release form refuses the link as the default form does, with no
    # suffix. The outside file must be reachable, or its name missing from
    # the output would prove nothing.
    c="$TEST_DIR/nolink-n1"
    [ -f "$c/$copied/.claude-plugin/plugin.json" ] \
      || { echo "fixture: the N1 link does not reach the outside file"; false; }
    for o in "" "--released"; do
      gate_run "$c" ${o:+--released "$copied"}
      gate_refuses N1 "check-versions.sh: $copied: plugin.json is a symbolic link$fol"
      gate_lacks N1 "OUTSIDE-NAME"
    done

    # N2: the repository's marketplace.json linked to a copy outside; its
    # .claude-plugin directory moved outside and linked back; a broken
    # marketplace.json link. Each is a link, never "run me from the
    # repository root", which a broken link alone gave.
    cp "$base/.claude-plugin/marketplace.json" "$out/marketplace.json"
    c="$TEST_DIR/nolink-n2-file"
    cp -r "$base" "$c"
    rm "$c/.claude-plugin/marketplace.json"
    nolink_make "$out/marketplace.json" "$c/.claude-plugin/marketplace.json"
    gate_run "$c"
    gate_refuses N2 "check-versions.sh: .claude-plugin/marketplace.json is a symbolic link$fol"
    c="$TEST_DIR/nolink-n2-dir"
    cp -r "$base" "$c"
    mv "$c/.claude-plugin" "$out/n2-dir"
    nolink_make "$out/n2-dir" "$c/.claude-plugin"
    gate_run "$c"
    gate_refuses N2 "check-versions.sh: .claude-plugin is a symbolic link$fol"
    c="$TEST_DIR/nolink-n2-broken"
    cp -r "$base" "$c"
    rm "$c/.claude-plugin/marketplace.json"
    nolink_make "$out/missing.json" "$c/.claude-plugin/marketplace.json"
    gate_run "$c"
    gate_refuses N2 "check-versions.sh: .claude-plugin/marketplace.json is a symbolic link$fol"
    gate_lacks N2 "run me from the repository root"

    # N3: the plugin directory moved outside and linked back under its
    # name; then its .claude-plugin directory. Each message names this
    # plugin, never the one before.
    c="$TEST_DIR/nolink-n3-dir"
    cp -r "$base" "$c"
    mv "$c/$copied" "$out/n3-dir"
    nolink_make "$out/n3-dir" "$c/$copied"
    gate_run "$c"
    gate_refuses N3 "check-versions.sh: $copied: the plugin directory is a symbolic link$fol"
    c="$TEST_DIR/nolink-n3-cp"
    cp -r "$base" "$c"
    mv "$c/$copied/.claude-plugin" "$out/n3-cp"
    nolink_make "$out/n3-cp" "$c/$copied/.claude-plugin"
    gate_run "$c"
    gate_refuses N3 "check-versions.sh: $copied: .claude-plugin is a symbolic link$fol"

    # N4: a source the reverse walk alone meets, passing through a link. A
    # linked component; then, because a top-level source is met by the
    # forward loop first, a nested source whose .claude-plugin is a link,
    # and one whose plugin.json alone is.
    mkdir -p "$out/n4-via/x/.claude-plugin" "$out/n4-cp"
    cp "$base/$copied/.claude-plugin/plugin.json" "$out/n4-via/x/.claude-plugin/plugin.json"
    cp "$base/$copied/.claude-plugin/plugin.json" "$out/n4-cp/plugin.json"
    c="$TEST_DIR/nolink-n4-via"
    cp -r "$base" "$c"
    nolink_make "$out/n4-via" "$c/via"
    json_set "$c/.claude-plugin/marketplace.json" '.plugins += [{name: "ghost", source: $v}]' "./via/x"
    gate_run "$c"
    gate_refuses N4 "check-versions.sh: marketplace entry 'ghost': source './via/x' passes through a symbolic link"
    c="$TEST_DIR/nolink-n4-cp"
    cp -r "$base" "$c"
    mkdir -p "$c/nest/x"
    nolink_make "$out/n4-cp" "$c/nest/x/.claude-plugin"
    json_set "$c/.claude-plugin/marketplace.json" '.plugins += [{name: "ghost", source: $v}]' "./nest/x"
    gate_run "$c"
    gate_refuses N4 "check-versions.sh: marketplace entry 'ghost': source './nest/x' passes through a symbolic link"
    c="$TEST_DIR/nolink-n4-json"
    cp -r "$base" "$c"
    mkdir -p "$c/nest/x/.claude-plugin"
    nolink_make "$out/plugin.json" "$c/nest/x/.claude-plugin/plugin.json"
    json_set "$c/.claude-plugin/marketplace.json" '.plugins += [{name: "ghost", source: $v}]' "./nest/x"
    gate_run "$c"
    gate_refuses N4 "check-versions.sh: marketplace entry 'ghost': source './nest/x' passes through a symbolic link"
  fi

  # O1, after the N plants, so against an older gate the first red is an
  # N clause: a caller's xtrace, verbose, noglob or keyword changes nothing.
  # In the default form only, as N2-N4 are (research R8): the options line
  # is the gate's first command and reads nothing the form sets, so after
  # it both forms run with the four options off; with the line removed,
  # each option changed both forms alike, at the same line (measured at
  # T010), and the quickstart's SC-003 check runs both forms on the real
  # tree. Each is set through SHELLOPTS on the gate's own command
  # only: on the wrapper's command line xtrace would trace the test's
  # paths, and `SHELLOPTS=$o bash` inside bash is a read-only variable,
  # which runs the gate without the option (measured). Exit status and
  # standard output must equal one run without it; standard error
  # must be exactly what FR-006 allows, from the test's own copy of the
  # gate's first two lines: the options line traced for xtrace, the `#!`
  # line and the options line echoed for verbose, nothing for the others.
  # Each output goes to a file, then both are printed, so forms_no_path
  # reads them too, after the clause's own checks.
  local optline='set +o xtrace +o verbose +o noglob +o keyword' prc unreadable
  local po="$TEST_DIR/o1-plain-out.txt" so="$TEST_DIR/o1-out.txt" se="$TEST_DIR/o1-err.txt" pe="$TEST_DIR/o1-want-err.txt"
  run bash -c 'r=$1 c=$2 so=$3 se=$4; shift 4; cd "$c" && bash "$r/scripts/check-versions.sh" "$@" > "$so" 2> "$se"; s=$?; cat "$so" "$se"; exit "$s"' \
    _ "$ROOT" "$base" "$po" "$se"
  forms_no_path
  prc=$status
  [ "$prc" -eq 0 ] && [ -s "$po" ] && [ ! -s "$se" ] \
    || { echo "fixture: the default form without an option exited $prc, or printed no report line, or wrote standard error. output: ${output:0:600}"; false; }
  for o in xtrace verbose noglob keyword; do
    run bash -c 'o=$1 r=$2 c=$3 so=$4 se=$5; shift 5; cd "$c" && env SHELLOPTS="$o" bash "$r/scripts/check-versions.sh" "$@" > "$so" 2> "$se"; s=$?; cat "$so" "$se"; exit "$s"' \
      _ "$o" "$ROOT" "$base" "$so" "$se"
    [ "$status" -eq "$prc" ] \
      || { echo "O1: with $o set, the default form exited $status, not $prc. output: ${output:0:600}"; false; }
    cmp -s "$po" "$so" \
      || { echo "O1: with $o set, the default form's standard output changed. output: ${output:0:600}"; false; }
    case $o in
      xtrace) printf '+ %s\n' "$optline" > "$pe" ;;
      verbose) printf '%s\n' '#!/usr/bin/env bash' "$optline" > "$pe" ;;
      *) : > "$pe" ;;
    esac
    cmp -s "$pe" "$se" \
      || { echo "O1: with $o set, the default form's standard error is not what FR-006 allows. output: ${output:0:600}"; false; }
    forms_no_path
  done

  # N6, after O1, so against the gate before the open check the first red
  # in this test is O1 on every system. Where a mode of 000 stops a read
  # (decided as L5 decides; not on Windows, and not as root), an
  # unreadable marketplace.json is refused as unreadable, alone, and never
  # as "is not valid JSON". Its mutant can go red on Linux and macOS only.
  c="$TEST_DIR/nolink-n6"
  cp -r "$base" "$c"
  chmod 000 "$c/.claude-plugin/marketplace.json"
  if [ -r "$c/.claude-plugin/marketplace.json" ]; then unreadable="not available here"; else unreadable="made"; fi
  echo "# unreadable: $unreadable" >&3
  if [ "$unreadable" = "made" ]; then
    gate_run "$c"
    gate_refuses N6 "check-versions.sh: .claude-plugin/marketplace.json could not be read"
    [ "$output" = "check-versions.sh: .claude-plugin/marketplace.json could not be read" ] \
      || { echo "N6: the output is not the gate's own line alone. output: ${output:0:600}"; false; }
  fi
  chmod 644 "$c/.claude-plugin/marketplace.json"
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
