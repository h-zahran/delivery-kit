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
SHIPPED_HANDOFF="handoff/hooks handoff/scripts handoff/skills handoff/README.md handoff/CHANGELOG.md handoff/docs handoff/tests handoff/.claude-plugin"
SHIPPED_PIPELINE="pipeline/README.md pipeline/CHANGELOG.md pipeline/.claude-plugin pipeline/commands pipeline/docs"
SHIPPED_MISSION_CONTROL="mission-control/README.md mission-control/CHANGELOG.md mission-control/.claude-plugin mission-control/hooks mission-control/sounds mission-control/types mission-control/tsconfig.json"
SHIPPED="$SHIPPED_ROOT $SHIPPED_HANDOFF $SHIPPED_PIPELINE $SHIPPED_MISSION_CONTROL"

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
# in POSIX ERE, and CI runs the macOS runner with BSD grep, where it either errors
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
  # And the hook after every tool call is still the context guard. (Since
  # 2026-10-10 handoff also ships a SessionStart hook; the loop above holds it
  # to the same plugin-root rule, and session-start.bats pins its entry.)
  cmd0="$(jq -r '.hooks.PostToolUse[0].hooks[0].command' handoff/hooks/hooks.json)"
  [[ "$cmd0" == *'context-guard.sh'* ]]
}

@test "every shipped hook timeout leaves headroom over the measured worst case" {
  cd "$ROOT"
  # A hook killed by its own timeout emits nothing, and a guard that emits
  # nothing is silently off — the exact failure this project exists to
  # prevent. Measured on a 48MB transcript whose readings fall inside the
  # 5000-line window but outside the 8MB byte cap, so the starvation fallback
  # fires and the file is read twice: 8.2s. The common capped path was 2.0s at
  # 8MB; the common read is 1MB since 2026-10-10.
  # 30 leaves ~3.6x over the worst case; 10 left 1.2x. Re-measured 2026-10-10,
  # when the guard began reading 1MB first: the same transcript reads three
  # times, 9.4s against 8.4s on a loaded machine, so 30 still leaves ~3.2x.
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
# a real leak, and it would survive a first green run on the macOS runner. A bare
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
  for f in README.md CONTRIBUTING.md CHANGELOG.md handoff/README.md handoff/CHANGELOG.md pipeline/README.md pipeline/CHANGELOG.md mission-control/README.md mission-control/CHANGELOG.md pipeline/commands/pipeline.md scripts/check-versions.md pipeline/docs/*.md handoff/docs/*.md handoff/skills/*/SKILL.md pipeline/skills/*/SKILL.md; do
    # Per entry, not `continue`: one entry going stale — a glob emptying, a
    # file moving — used to be absorbed by the aggregate counter while the
    # other files kept it positive. An unexpanded glob arrives here as its
    # own literal text and fails the same way.
    [ -f "$f" ] || { echo "link-test entry '$f' does not resolve; the list has gone stale"; false; }
    while IFS= read -r link; do
      case "$link" in http*|https*|mailto:*) continue ;; esac
      target="${link%%#*}"
      # Counted here rather than per file, so a file that ships with only
      # external links cannot stand in for one whose relative links vanished.
      checked=$((checked + 1))
      # A bare `#x` points into this same file. Until the README rewrite of
      # item 15 those were skipped, so renaming a heading that its own page
      # linked to stayed green.
      if [ -n "$target" ]; then resolved="$(dirname "$f")/$target"; else resolved="$f"; fi
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
      # a letter, digit, underscore, space or hyphen — which is what removes
      # the backticks and the `@` in a heading like "Upgrading from
      # `delivery-kit@delivery-kit`" — then EACH space to a hyphen. GitHub does
      # not collapse spaces, so "Windows — notes" is `windows--notes`; the old
      # `s/ +/-/g` read the right link as broken and the wrong one as fine. A
      # repeated heading gets `-1`, `-2`; a `#` line inside a code fence is not
      # a heading. (Review of item 15 measured each of these going the wrong
      # way.) The awk uses no `{m,n}` interval, which not every CI awk reads.
      anchor="${link#*#}"
      [ "$anchor" != "$link" ] && [ -n "$anchor" ] || continue
      [ -f "$resolved" ] || continue
      if ! tr -d '\r' < "$resolved" \
          | awk '
              /^ *(```|~~~)/ { fence = !fence; next }
              fence { next }
              /^#+ / {
                t = $0; sub(/^#+ +/, "", t); sub(/[ #]*$/, "", t)
                t = tolower(t); gsub(/[^a-z0-9_ -]/, "", t); gsub(/ /, "-", t)
                if (t in seen) { print t "-" seen[t]; seen[t]++ } else { print t; seen[t] = 1 }
              }' \
          | grep -qxF -- "$anchor"; then
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
  # The root README deep-links to this heading's anchor. The link test has
  # checked anchors since 2026-09-03, so this pin is a second guard: it names
  # the exact heading, in the test that owns the root documents' promises
  # (global constraint; scaffold item 9).
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
  # are policed: ci.yml's suite matrix, and the contributing guide's command — the
  # guide's paragraph warns that running a subset "is the failure this
  # project exists to prevent, arriving by way of its own contributing
  # guide", and until this test read the guide, nothing held that copy to it.
  #
  # The `|| true` on each grep is load bearing: under errexit a failing
  # command substitution aborts the test AT THAT LINE, so the named
  # diagnostic below it never runs. It cannot mask a real failure — an empty
  # line is rejected on the next line either way.
  #
  # CI is SHARDED: one job per OS per suite root, and the one bats invocation
  # names "$SUITE", which the step maps from the matrix. So ci.yml's coverage
  # is not read off the command line but off the matrix's `suite:` list, and
  # the command line must be the one invocation and must take its path from
  # that list. A second bats line would be a second copy to police, so
  # exactly one is required.
  wf=.github/workflows/ci.yml
  ciline="$(grep -m1 -E '^ *(run: *)?bash .*bats.* -r ' "$wf" || true)"
  [ -n "$ciline" ] || { echo "no 'bash ... bats ... -r' line found in ci.yml"; false; }
  n="$(grep -cE '^ *(run: *)?bash .*bats/bin/bats' "$wf" || true)"
  [ "$n" -eq 1 ] || { echo "expected exactly one bats invocation in ci.yml, found $n"; false; }
  docline="$(grep -m1 -E '^bash .*bats.* -r ' CONTRIBUTING.md || true)"
  [ -n "$docline" ] || { echo "no 'bash ... bats ... -r' command found in CONTRIBUTING.md"; false; }

  # The suite list, read from the one flow-sequence line `suite: [a, b, c]`.
  # Exactly one, so a second matrix cannot quietly be the one that counts.
  n="$(grep -cE '^ *suite: *\[[^]]*\] *$' "$wf" || true)"
  [ "$n" -eq 1 ] || { echo "expected exactly one 'suite: [...]' matrix line in ci.yml, found $n"; false; }
  suiteline="$(grep -m1 -E '^ *suite: *\[[^]]*\] *$' "$wf")"
  suiteline="${suiteline#*[}"
  suiteline="${suiteline%]*}"
  read -r -a cisuites <<< "${suiteline//,/ }"
  [ "${#cisuites[@]}" -ge 1 ] || { echo "the ci.yml suite matrix is empty"; false; }
  # Every entry must hold a tracked suite, or its shard runs nothing; and no
  # entry may sit beneath another, or repeat, or bats runs those tests in two
  # shards. An entry must be a plain relative path: `.` (or `./x`, `x/`,
  # `../x`, `/x`) would slip past the ancestor comparison, which is textual,
  # while `.` contains every other entry.
  for s in "${cisuites[@]}"; do
    case "$s" in
      .|./*|*/|/*|..|../*|*/..|*/../*|*/./*|*/.)
        echo "the ci.yml suite matrix names '$s'; entries must be plain relative paths"; false ;;
    esac
    [ -n "$(git ls-files -- "$s/*.bats")" ] \
      || { echo "the ci.yml suite matrix names '$s', which holds no tracked .bats file"; false; }
    seen=0
    for o in "${cisuites[@]}"; do
      [ "$o" = "$s" ] && seen=$((seen + 1))
      case "$o" in "$s"/*) echo "ci.yml shards '$o' AND its ancestor '$s'; those tests would run twice"; false ;; esac
    done
    [ "$seen" -eq 1 ] || { echo "the ci.yml suite matrix names '$s' $seen times; those tests would run twice"; false; }
  done
  # The path the command runs is the matrix's, and every combination of OS
  # and suite exists: the job runs on matrix.os, and nothing EXCLUDES a
  # combination. (`include:` only adds keys to matching combinations.)
  grep -qE '^ *SUITE: \$\{\{ matrix\.suite \}\} *$' "$wf" \
    || { echo "ci.yml no longer maps SUITE from matrix.suite"; false; }
  grep -qE '^ *runs-on: \$\{\{ matrix\.os \}\} *$' "$wf" \
    || { echo "the ci.yml test job no longer runs on matrix.os"; false; }
  if grep -qE '^ *exclude:' "$wf"; then
    echo "ci.yml carries a matrix exclude:, so some suite no longer runs on every OS"; false
  fi
  # Nor may a condition drop or excuse a shard: no `continue-on-error:`
  # anywhere in the test job, and no `if:` on the job itself or on its shard
  # step. (Setup steps keep their own `if:` keyed on the bats cache and the
  # runner's symlink support; a shard whose setup is skipped wrongly fails.)
  # The slices go to files and are grepped there, never through a herestring.
  awk '/^  test:$/ { on = 1; next } on && /^  [^ #]/ { exit } on' "$wf" > "$TEST_DIR/testjob.yml"
  [ -s "$TEST_DIR/testjob.yml" ] || { echo "no 'test:' job found in ci.yml"; false; }
  awk 'index($0, "- name: Run the ${{ matrix.suite }} suite") { on = 1; print; next }
       on && /^      - / { exit }
       on' "$TEST_DIR/testjob.yml" > "$TEST_DIR/shardstep.yml"
  [ -s "$TEST_DIR/shardstep.yml" ] || { echo "no shard step found in the ci.yml test job"; false; }
  if grep -qE '^[[:space:]]*continue-on-error:' "$TEST_DIR/testjob.yml"; then
    echo "the ci.yml test job carries continue-on-error:, which can excuse a failing shard"; false
  fi
  if grep -qE '^    if:' "$TEST_DIR/testjob.yml"; then
    echo "the ci.yml test job carries a job-level if:, which can skip shards"; false
  fi
  if grep -qE '^[[:space:]]*(- )?if:' "$TEST_DIR/shardstep.yml"; then
    echo "the ci.yml shard step carries an if:, which can skip a shard"; false
  fi
  cimatrix=" ${cisuites[*]} "

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
  # CI's line also prints per-test timings (the slow-test warning reads
  # them) and runs the shard's suite, by name, as its only path.
  case " $ciline " in *" --timing "*) ;; *) echo "ci.yml bats line lost --timing"; false ;; esac
  case "$ciline" in *' "$SUITE"'*) ;; *) echo "ci.yml bats line no longer runs \"\$SUITE\""; false ;; esac

  # Discovery is over TRACKED files — see the SKILL.md test above for why.
  # Dirnames are computed in the shell so a path with a space cannot be split
  # into two bogus names (xargs -n1 dirname word-splits; measured). Residual,
  # accepted: matching tokens against a command line textually means a suite
  # directory literally named `bash` or `-r` would be miscounted as covered —
  # this repository names its suite directories, and names none of them that.
  checked=0
  for line in "$cimatrix" "$docline"; do
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

# The CI shard step decides whether a shard is green, and that decision is
# shell, so it is RUN here rather than read. Its script is cut out of ci.yml
# by the step's name and executed the way the runner executes it (bash with
# errexit and pipefail), against a STUB bats that prints canned TAP and exits
# with a chosen status. Every refusal is fired directly, at its edges.
shard_step_script() {
  # -> prints the path of the extracted script
  local out="$TEST_DIR/shard-step.sh"
  awk '
    index($0, "- name: Run the ${{ matrix.suite }} suite") { found = 1; next }
    found && !inblock && /^ *- / { exit }
    found && !inblock && /^ *run: *[|]$/ { inblock = 1; ind = -1; next }
    inblock {
      if ($0 ~ /^ *$/) { print ""; next }
      match($0, /^ */)
      if (ind < 0) ind = RLENGTH
      if (RLENGTH < ind) exit
      print substr($0, ind + 1)
    }
  ' "$ROOT/.github/workflows/ci.yml" > "$out"
  [ -s "$out" ] || { echo "no run: block found under the shard step in ci.yml" >&2; return 1; }
  printf '%s' "$out"
}

# run_shard <bats exit status> <TAP line>... ; the stub prints the lines.
run_shard() {
  local rc="$1"
  shift
  printf '%s\n' "$@" > "$TEST_DIR/stub.tap"
  run env STUB_RC="$rc" STUB_TAP="$TEST_DIR/stub.tap" STUB_ARGS="$TEST_DIR/stub.args" \
    SUITE=some/suite bash -eo pipefail "$step"
}

@test "a CI shard fails on a skip, an empty plan or a plan mismatch, and only warns when slow" {
  step="$(shard_step_script)"
  mkdir -p "$HOME/bats/bin"
  printf '%s\n' 'printf "%s\n" "$@" > "$STUB_ARGS"' 'cat "$STUB_TAP"' 'exit "$STUB_RC"' > "$HOME/bats/bin/bats"

  # Green, with one test over the 30 s budget and one exactly at it: the job
  # passes, the slow one is annotated, the one at the budget is not.
  # Test 4's NAME ends in a timing-shaped phrase: only the real timing at the
  # end of the line may be read. Test 5's name carries a %, which a workflow
  # command must receive escaped as %25.
  run_shard 0 '1..5' 'ok 1 fast in 12ms' 'ok 2 slow one in 30001ms' 'ok 3 at budget in 30000ms' \
    'ok 4 named in 40000ms in 5ms' 'ok 5 50% slow in 31000ms'
  [ "$status" -eq 0 ] || { echo "a green shard with a slow test failed: $output"; false; }
  [[ $output == *"::warning title=slow test in some/suite::test 2 slow one took 30001 ms"* ]] \
    || { echo "no slow-test warning for the 30001 ms test: $output"; false; }
  [[ $output != *"at budget took"* ]] || { echo "a test AT the budget was warned about: $output"; false; }
  [[ $output != *"test 4 named"* ]] \
    || { echo "a timing-shaped test NAME was read as the timing: $output"; false; }
  [[ $output == *"::warning title=slow test in some/suite::test 5 50%25 slow took 31000 ms"* ]] \
    || { echo "the % in a slow test's name was not escaped as %25: $output"; false; }
  # The stub saw the shard's own suite as the only path, with the flags.
  [ "$(cat "$TEST_DIR/stub.args")" = "$(printf '%s\n' -r --print-output-on-failure --timing some/suite)" ] \
    || { echo "bats was called with: $(cat "$TEST_DIR/stub.args")"; false; }
  # The tap formatter's spelling of the timing is read too.
  run_shard 0 '1..1' 'ok 1 slow one # in 45000 ms'
  [ "$status" -eq 0 ]
  [[ $output == *"::warning title=slow test in some/suite::test 1 slow one took 45000 ms"* ]] \
    || { echo "the ' # in N ms' timing was not read: $output"; false; }

  # A skip is a failure, though bats exits 0 for it.
  run_shard 0 '1..2' 'ok 1 a in 1ms' 'ok 2 b in 1ms # skip why'
  [ "$status" -eq 1 ] && [[ $output == *"::error title=skipped tests::"* ]] \
    || { echo "a skipped test passed the shard: $output"; false; }
  # And a bare skip, with no reason after it.
  run_shard 0 '1..2' 'ok 1 a in 1ms' 'ok 2 b in 1ms # skip'
  [ "$status" -eq 1 ] && [[ $output == *"::error title=skipped tests::"* ]] \
    || { echo "a bare skip passed the shard: $output"; false; }

  # A shard that ran nothing: a zero plan, and no plan line at all.
  run_shard 0 '1..0'
  [ "$status" -eq 1 ] && [[ $output == *"::error title=empty shard::"* ]] \
    || { echo "a 1..0 shard passed: $output"; false; }
  run_shard 0 'ok 1 a in 1ms'
  [ "$status" -eq 1 ] && [[ $output == *"::error title=empty shard::"* ]] \
    || { echo "a shard with no plan line passed: $output"; false; }

  # Counted and never run, and the other direction.
  run_shard 0 '1..3' 'ok 1 a in 1ms' 'ok 2 b in 1ms'
  [ "$status" -eq 1 ] && [[ $output == *"::error title=plan mismatch::"* ]] \
    || { echo "a shard reporting fewer tests than planned passed: $output"; false; }
  run_shard 0 '1..1' 'ok 1 a in 1ms' 'ok 2 b in 1ms'
  [ "$status" -eq 1 ] && [[ $output == *"::error title=plan mismatch::"* ]] \
    || { echo "a shard reporting more tests than planned passed: $output"; false; }
  # The right COUNT with the wrong numbers: a stray number, a repeat, a zero.
  run_shard 0 '1..2' 'ok 1 a in 1ms' 'ok 7 b in 1ms'
  [ "$status" -eq 1 ] && [[ $output == *"::error title=plan mismatch::"* ]] \
    || { echo "a stray test number stood in for a missing test: $output"; false; }
  run_shard 0 '1..2' 'ok 1 a in 1ms' 'ok 1 b in 1ms'
  [ "$status" -eq 1 ] && [[ $output == *"::error title=plan mismatch::"* ]] \
    || { echo "a repeated test number stood in for a missing test: $output"; false; }
  run_shard 0 '1..2' 'ok 0 a in 1ms' 'ok 2 b in 1ms'
  [ "$status" -eq 1 ] && [[ $output == *"::error title=plan mismatch::"* ]] \
    || { echo "test number 0 stood in for test 1: $output"; false; }

  # A not-ok line fails the shard even when bats itself exits 0.
  run_shard 0 '1..2' 'ok 1 a in 1ms' 'not ok 2 b in 1ms'
  [ "$status" -eq 1 ] && [[ $output == *"::error title=failed tests::"* ]] \
    || { echo "a not-ok test passed the shard because bats exited 0: $output"; false; }

  # A failing test fails the shard, and so does a bats failure on clean TAP.
  run_shard 1 '1..1' 'not ok 1 a in 5ms'
  [ "$status" -eq 1 ] || { echo "a failing test passed the shard: $output"; false; }
  run_shard 1 '1..1' 'ok 1 a in 5ms'
  [ "$status" -eq 1 ] || { echo "a bats failure on clean TAP passed the shard: $output"; false; }
  # The status is read from PIPESTATUS, so it survives a shell WITHOUT
  # pipefail too, where the pipe itself reports tee's 0.
  printf '%s\n' '1..1' 'ok 1 a in 5ms' > "$TEST_DIR/stub.tap"
  run env STUB_RC=1 STUB_TAP="$TEST_DIR/stub.tap" STUB_ARGS="$TEST_DIR/stub.args" \
    SUITE=some/suite bash -e "$step"
  [ "$status" -eq 1 ] || { echo "without pipefail, a bats failure passed the shard: $output"; false; }
}

@test "CI pins its runner images, jq and actionlint, each tool with a checksum" {
  wf="$ROOT/.github/workflows/ci.yml"
  # No moving image label anywhere outside a comment.
  if grep -vE '^ *#' "$wf" | grep -qE -- '-latest'; then
    echo "ci.yml names a -latest image outside a comment:"; grep -vE '^ *#' "$wf" | grep -E -- '-latest'; false
  fi
  # The test matrix runs one pinned label per OS, all three present.
  osline="$(grep -m1 -E '^ *os: *\[[^]]*\] *$' "$wf" || true)"
  [ -n "$osline" ] || { echo "no 'os: [...]' matrix line in ci.yml"; false; }
  for family in ubuntu macos windows; do
    re="(\[|[[:space:]])$family-[0-9][^],]*[],]"
    [[ $osline =~ $re ]] \
      || { echo "the os matrix has no version-pinned $family label: $osline"; false; }
  done

  # jq: one version, one checksum per asset, installed and verified by steps
  # defined once and reused by alias in the version job.
  grep -qE "^  JQ_VERSION: '?[0-9]+[.][0-9]+([.][0-9]+)?'?$" "$wf" || { echo "no JQ_VERSION pin in ci.yml"; false; }
  for asset in LINUX_AMD64 MACOS_ARM64 WINDOWS_AMD64; do
    grep -qE "^  JQ_SHA256_$asset: [0-9a-f]{64}$" "$wf" || { echo "no 64-hex JQ_SHA256_$asset in ci.yml"; false; }
  done
  for anchor in install-jq check-jq; do
    [ "$(grep -cE -- "^ *- &$anchor$" "$wf")" -eq 1 ] || { echo "expected one '- &$anchor' step in ci.yml"; false; }
    [ "$(grep -cE -- "^ *- \*$anchor$" "$wf")" -ge 1 ] || { echo "no job reuses '*$anchor' in ci.yml"; false; }
  done
  grep -qF -- '[ "$got" = "$want" ] || {' "$wf" || { echo "the jq install no longer compares its checksum"; false; }
  grep -qF -- '[ "$have" = "jq-$JQ_VERSION" ] || {' "$wf" || { echo "nothing asserts the jq version in ci.yml"; false; }

  # actionlint: pinned, checksummed, run with the pinned shellcheck, after a
  # control that must go red.
  grep -qE "^ *ACTIONLINT_VERSION: '?[0-9]+[.][0-9]+[.][0-9]+'?$" "$wf" || { echo "no ACTIONLINT_VERSION pin"; false; }
  grep -qE '^ *ACTIONLINT_SHA256: [0-9a-f]{64}$' "$wf" || { echo "no 64-hex ACTIONLINT_SHA256"; false; }
  grep -qF -- '[ "$got" = "$ACTIONLINT_SHA256" ] || {' "$wf" || { echo "the actionlint install no longer compares its checksum"; false; }
  grep -qF -- "grep -q -- 'SC2086' \"\$RUNNER_TEMP/canary.out\"" "$wf" || { echo "the actionlint positive control is gone"; false; }
  grep -qF -- 'actionlint -shellcheck "$sc" -- "${workflows[@]}"' "$wf" || { echo "actionlint no longer lints the workflows with the pinned shellcheck"; false; }
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
