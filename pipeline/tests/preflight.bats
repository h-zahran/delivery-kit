#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Suite for pipeline/scripts/preflight.sh — detection and probe. Fixture
# directories sit INSIDE this repository, so git facts read from them
# belong to the enclosing checkout — which is why no fixture test asserts
# baseBranch or remote, and why those assertions get their own scratch
# repositories below. The --base-branch flag on fixture runs is a
# formality: where the checkout publishes origin/HEAD, that wins by
# design.

load ../../tests/helper

setup() {
  FIX="$ROOT/pipeline/tests/fixtures"
}

# The six external commands the probe actually invokes, read out of the script
# rather than guessed. A search path holding exactly these lets the probe run
# normally while any OTHER tool reads as absent — which is the only way to reach
# the degradation branches.
PROBE_TOOLS="awk git grep head jq od"

# shimdir <dir> [tool...] — a directory of tiny shims, each execing the real
# tool. Hand it to `probe --path` to control precisely what the probe can find.
#
# The directory must be a path with no drive letter: under Git Bash a `C:/...`
# entry splits on its own colon into two broken entries and then EVERY tool
# reads as absent, including jq — so the probe would die for a reason no test
# named, and pass for the wrong cause. $BATS_TEST_TMPDIR is already POSIX-form.
shimdir() {
  local d="$1"; shift
  mkdir -p "$d"
  local t src
  for t in "$@"; do
    src="$(command -v "$t")" || continue
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$src" > "$d/$t"
    chmod +x "$d/$t"
  done
}

# stub <path> — a program that exists and does nothing. The probe asks only
# whether a capability can be FOUND, so presence is the whole behaviour.
stub() {
  printf '#!/bin/sh\nexit 0\n' > "$1"
  chmod +x "$1"
}

@test "the web fixture detects web, from the package.json toolchain" {
  probe --dir "$FIX/web" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "web" ]
  [ "$(jq -r '.projectTypeSource' <<<"$output")" = "package.json toolchain" ]
}

@test "the mobile-android fixture detects mobile-android" {
  probe --dir "$FIX/mobile-android" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "mobile-android" ]
}

@test "the other fixture detects other, by default" {
  probe --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "other" ]
  [ "$(jq -r '.projectTypeSource' <<<"$output")" = "default" ]
}

@test "--project-type overrides detection and says so" {
  probe --dir "$FIX/web" --base-branch main --project-type other
  [ "$status" -eq 0 ]
  [ "$(jq -r '.projectType' <<<"$output")" = "other" ]
  [ "$(jq -r '.projectTypeSource' <<<"$output")" = "override" ]
}

@test "the no-speckit fixture reports the tool absent, exit 0 -- reporting is not failing" {
  probe --dir "$FIX/no-speckit" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.present' <<<"$output")" = "false" ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ]
}

@test "the web fixture reads version and sh flavour, resolving the bash scripts dir" {
  probe --dir "$FIX/web" --base-branch main
  [ "$(jq -r '.speckit.version' <<<"$output")" = "0.16.5" ]
  [ "$(jq -r '.speckit.script' <<<"$output")" = "sh" ]
  [ "$(jq -r '.speckit.scriptsDir' <<<"$output")" = ".specify/scripts/bash" ]
  [ "$(jq -r '.speckit.versionInRange' <<<"$output")" = "true" ]
}

@test "the mobile-android fixture's ps flavour resolves the powershell scripts dir" {
  probe --dir "$FIX/mobile-android" --base-branch main
  [ "$(jq -r '.speckit.script' <<<"$output")" = "ps" ]
  [ "$(jq -r '.speckit.scriptsDir' <<<"$output")" = ".specify/scripts/powershell" ]
}

@test "the py flavour is handled loudly: exit 0, empty scriptsDir, stderr names it" {
  probe --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.script' <<<"$output")" = "py" ]
  [ "$(jq -r '.speckit.scriptsDir' <<<"$output")" = "" ]
  [[ "$stderr" == *"'py'"* ]]
}

@test "an out-of-range version warns on stderr and continues" {
  probe --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.versionInRange' <<<"$output")" = "false" ]
  [[ "$stderr" == *"0.14.0"* ]]
}

@test "an illegal script flavour fails loudly, naming the value" {
  T="$BATS_TEST_TMPDIR/bad"
  mkdir -p "$T/.specify/templates" "$T/.specify/scripts"
  printf '{ "speckit_version": "0.16.5", "script": "bat" }\n' > "$T/.specify/init-options.json"
  probe --dir "$T" --base-branch main
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'bat'"* ]]
}

@test "a hyphen-skill install is recorded as hyphen-skills" {
  probe --dir "$FIX/web" --base-branch main
  [ "$(jq -r '.speckit.invocationForm' <<<"$output")" = "hyphen-skills" ]
}

@test "a dot-command install is recorded as dot-commands" {
  probe --dir "$FIX/mobile-android" --base-branch main
  [ "$(jq -r '.speckit.invocationForm' <<<"$output")" = "dot-commands" ]
}

@test "remote classification: none, github, other" {
  T="$BATS_TEST_TMPDIR/remote"
  mkdir -p "$T"; cd "$T"; git init -q .
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "none" ]
  git remote add origin https://github.com/example/thing.git
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "github" ]
  git remote set-url origin https://gitlab.example.com/x/y.git
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.remote.kind' <<<"$output")" = "other" ]
}

@test "base branch: origin/HEAD first, then the override, each with its source" {
  T="$BATS_TEST_TMPDIR/base"
  mkdir -p "$T"; cd "$T"; git init -q -b work .
  probe --dir "$T" --base-branch trunk
  [ "$(jq -r '.baseBranch' <<<"$output")" = "trunk" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "configured" ]
  git remote add origin https://github.com/example/thing.git
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  probe --dir "$T" --base-branch trunk
  [ "$(jq -r '.baseBranch' <<<"$output")" = "main" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "origin/HEAD" ]
}

@test "stdout is pure JSON even when stderr is talking" {
  probe --dir "$FIX/other" --base-branch main
  jq -e . <<<"$output" > /dev/null
  [ -n "$stderr" ]
}

@test "capabilities reports jq true and booleans for gh and adb" {
  probe --dir "$FIX/web" --base-branch main
  [ "$(jq -r '.capabilities.jq' <<<"$output")" = "true" ]
  [[ "$(jq -r '.capabilities.gh' <<<"$output")" =~ ^(true|false)$ ]]
  [[ "$(jq -r '.capabilities.adb' <<<"$output")" =~ ^(true|false)$ ]]
}

@test "willSkip names phases L and M in a repository with no remote" {
  T="$BATS_TEST_TMPDIR/skips"
  mkdir -p "$T"; cd "$T"; git init -q .
  probe --dir "$T" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '[.willSkip[].phase] | index("L") != null' <<<"$output")" = "true" ]
  [ "$(jq -r '[.willSkip[].phase] | index("M") != null' <<<"$output")" = "true" ]
}

@test "tree reports dirty and runsLive from the facts on disk" {
  T="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$T"; cd "$T"; git init -q .
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.tree.dirty' <<<"$output")" = "false" ]
  [ "$(jq -r '.tree.runsLive' <<<"$output")" = "false" ]
  printf 'x' > dirt.txt
  mkdir -p .delivery-kit/runs/001-x
  printf '{"current_phase":"B"}' > .delivery-kit/runs/001-x/progress.json
  probe --dir "$T" --base-branch main
  [ "$(jq -r '.tree.dirty' <<<"$output")" = "true" ]
  [ "$(jq -r '.tree.runsLive' <<<"$output")" = "true" ]
}

@test "constitutionSet is false on a fresh-init-shaped constitution" {
  probe --dir "$FIX/constitution-unset" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ]
}

@test "constitutionSet is true once the constitution carries real principles" {
  probe --dir "$FIX/constitution-set" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "true" ]
}

# --- refusals -----------------------------------------------------------------
# Each of these exits non-zero, so a test could "pass" on the status alone while
# the message said nothing, or named the wrong thing. The naming IS the property
# — it is what a person reads at the moment nothing works yet — so every one of
# these asserts on the message and not merely on the status.

@test "an unrecognised argument is refused, naming it and listing the legal ones" {
  probe --nope
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"'--nope'"* ]]
  [[ "$stderr" == *"--dir --project-type --base-branch"* ]]
}

@test "a flag supplied without its value is refused, naming what the flag needed" {
  probe --dir
  [ "$status" -ne 0 ]
  # Assert on the phrase the script chose, and on nothing else in this line.
  # It is emitted by the shell's own ${2:?...} expansion rather than by the
  # script's die(), so it also carries the script's path and a LINE NUMBER —
  # and that number moves every time the script is edited. A test that pinned
  # it would go red on an unrelated change and teach people to loosen it.
  [[ "$stderr" == *"--dir needs a path"* ]]
}

@test "a directory that cannot be entered is refused, naming the directory" {
  gone="$BATS_TEST_TMPDIR/no-such-directory"
  probe --dir "$gone" --base-branch main
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"cannot enter '$gone'"* ]]
}

@test "a required tool absent is refused BY NAME, not merely non-zero" {
  # An empty search path breaks the probe several ways at once, so a test
  # asserting only a non-zero exit would pass for any of them — including for
  # the interpreter never starting. Name the tool, and reach it through an
  # absolute interpreter, because stripping PATH removes bash too.
  empty="$BATS_TEST_TMPDIR/empty-path"
  mkdir -p "$empty"
  probe --path "$empty" --dir "$FIX/web" --base-branch main
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"jq is required and was not found on PATH"* ]]
}

# --- warnings that do not stop the run ----------------------------------------
# The probe exits ZERO in every one of these, so the status carries no
# information and asserting on it would prove nothing. Each asserts on the
# diagnostic stream's CONTENT, and each also confirms the data stream still
# parses whole — a warning leaking into the data stream is the regression these
# exist to catch, and it would be invisible to a stderr-only assertion.
#
# Each fixture is shaped to fire exactly ONE warning. A fixture missing its
# whole init-options file fires two at once, and a test built on that could
# attribute neither.

@test "an empty recorded version warns, succeeds, and leaves the data stream whole" {
  probe --dir "$FIX/speckit-no-version" --base-branch main
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"no version recorded"* ]]
  jq -e . <<<"$output" > /dev/null
  [ "$(jq -r '.speckit.version' <<<"$output")" = "" ]
}

@test "an empty recorded script flavour warns, succeeds, and leaves the data stream whole" {
  probe --dir "$FIX/speckit-no-flavour" --base-branch main
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"no script flavour recorded"* ]]
  jq -e . <<<"$output" > /dev/null
  [ "$(jq -r '.speckit.script' <<<"$output")" = "" ]
}

@test "a foreign agent's skills give the warning and an invocationForm of none, together" {
  # Both halves, in ONE run — that pairing is the requirement. The fixture
  # carries no .claude/skills/speckit-* and no .claude/commands/speckit.*.md:
  # either one holds the form away from none and silences the warning outright,
  # which is the measured negative control behind this test.
  probe --dir "$FIX/foreign-agent" --base-branch main
  [ "$status" -eq 0 ]
  [[ "$stderr" == *".agents/skills/"* ]]
  [[ "$stderr" == *"not adopting it"* ]]
  jq -e . <<<"$output" > /dev/null
  [ "$(jq -r '.speckit.invocationForm' <<<"$output")" = "none" ]
}

@test "a constitution saved in an unreadable encoding warns and reads as not set" {
  probe --dir "$FIX/constitution-nul" --base-branch main
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"NUL bytes"* ]]
  jq -e . <<<"$output" > /dev/null
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ]
}

# --- the governance parser's remaining edges ----------------------------------

@test "a byte-order mark is stripped before the constitution is judged" {
  # The fixture is a mark followed by NOTHING BUT WHITESPACE, and it has to be.
  # A mark followed by real prose reads as set with or without the stripping,
  # because the mark merely rides in front of text that already counts — that
  # fixture is vacuous, measured twice. Here the mark is the only candidate for
  # content, so stripping it is the whole difference.
  probe --dir "$FIX/constitution-bom" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "false" ]
}

@test "a comment opened and never closed does not swallow the rest of the file" {
  # The fixture OPENS with the comment, on its very first byte. Any real text
  # before it would make the file read as set whether or not the text after the
  # comment survived — vacuous for the same reason as the mark above.
  probe --dir "$FIX/constitution-unclosed" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.speckit.constitutionSet' <<<"$output")" = "true" ]
}

# --- announced degradations, per cause ----------------------------------------
# The ambient environment cannot be trusted here and these tests do not read it.
# On the development machine the command-line client is a shim this shell cannot
# see; on every CI runner it is present. The device tool is the reverse. A test
# that relied on either would pass on one platform and fail on the other — or,
# worse, pass on both for different reasons. Each builds its own search path.

@test "the runtime-check phase is announced skipped when a mobile project has no device tool" {
  d="$BATS_TEST_TMPDIR/no-device"
  shimdir "$d" $PROBE_TOOLS
  probe --path "$d" --dir "$FIX/mobile-android" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.capabilities.adb' <<<"$output")" = "false" ]
  # Select by PHASE, never by index. This run also announces a review skip,
  # because the fixture sits inside this checkout and inherits its remote while
  # the client is off the shim path — so reading willSkip[0] would pass or fail
  # on ordering rather than on the property.
  [ "$(jq -r '[.willSkip[] | select(.phase=="N.5")] | length' <<<"$output")" = "1" ]
  [[ "$(jq -r '[.willSkip[] | select(.phase=="N.5")] | .[0].reason' <<<"$output")" == *"adb"* ]]
}

@test "the review phase is announced skipped for both of its causes" {
  # ONE test, because this is ONE branch in the script reached by two routes.
  # Splitting it would put the suite at fourteen new tests against thirteen.
  # The already-covered no-remote cause is deliberately not repeated here.

  # Route (a): the client IS findable, but the remote is not the expected host.
  # The stub is what makes this route provable. Without it the client reads
  # absent on this machine, the skip fires for route (b)'s reason, and the
  # assertion below would pass while proving nothing.
  a="$BATS_TEST_TMPDIR/with-client"
  shimdir "$a" $PROBE_TOOLS
  stub "$a/gh"
  ra="$BATS_TEST_TMPDIR/repo-elsewhere"
  mkdir -p "$ra"
  ( cd "$ra" && git init -q . && git remote add origin https://gitlab.example.com/x/y.git )
  probe --path "$a" --dir "$ra" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.capabilities.gh' <<<"$output")" = "true" ]
  [ "$(jq -r '.remote.kind' <<<"$output")" = "other" ]
  [ "$(jq -r '[.willSkip[] | select(.phase=="M")] | length' <<<"$output")" = "1" ]

  # Route (b): the remote IS the expected host, but the client cannot be found.
  b="$BATS_TEST_TMPDIR/without-client"
  shimdir "$b" $PROBE_TOOLS
  rb="$BATS_TEST_TMPDIR/repo-expected-host"
  mkdir -p "$rb"
  ( cd "$rb" && git init -q . && git remote add origin https://github.com/example/thing.git )
  probe --path "$b" --dir "$rb" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.capabilities.gh' <<<"$output")" = "false" ]
  [ "$(jq -r '.remote.kind' <<<"$output")" = "github" ]
  [ "$(jq -r '[.willSkip[] | select(.phase=="M")] | length' <<<"$output")" = "1" ]

  # Negative control. Neither cause holds, so the phase must NOT be announced.
  # Without this the two assertions above cannot be shown to go red when they
  # should — they would pass against a script that skipped M unconditionally.
  stub "$b/gh"
  probe --path "$b" --dir "$rb" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '[.willSkip[] | select(.phase=="M")] | length' <<<"$output")" = "0" ]
}

# --- the last unpinned base-branch route --------------------------------------

@test "with no published default and no override, the base branch falls back to the current branch" {
  T="$BATS_TEST_TMPDIR/fallback"
  mkdir -p "$T"
  # The commit is load-bearing, not tidiness. On an UNBORN branch the command
  # this fallback uses exits 128 and prints the literal word HEAD on stdout,
  # which the script adopts as a branch name — so without a commit the source
  # assertion below still passes while the branch name means nothing.
  ( cd "$T" \
      && git init -q -b feature-x . \
      && git -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init )
  # The base-branch flag is OMITTED. This route needs BOTH earlier routes to be
  # unavailable, and every other call site in this suite supplies an override —
  # which is why no existing test could reach it.
  probe --dir "$T"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.baseBranch' <<<"$output")" = "feature-x" ]
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "current branch" ]
}

# --- the git capability -------------------------------------------------------
# git is the one probed tool the run cannot proceed without: phases B, K and L
# are git operations, and four of this script's own reads are git commands. It
# is reported here like any other capability, and NOTHING here asserts on a
# stop, because a report is the only thing this script produces. The stop is
# the orchestrator's pre-flight decision 11, made from what is asserted below.

@test "the capability report names git present when git is findable" {
  d="$BATS_TEST_TMPDIR/with-git"
  shimdir "$d" $PROBE_TOOLS
  probe --path "$d" --dir "$FIX/other" --base-branch main
  [ "$status" -eq 0 ]
  [ "$(jq -r '.capabilities.git' <<<"$output")" = "true" ]
  # The TYPE, not only the value, and it needs its own assertion. `jq -r`
  # prints the JSON string "true" as a bare true, so a value comparison alone
  # cannot tell a boolean from a string. Measured 2026-08-30: changing
  # --argjson to --arg in the script made the emitted type "string" and NOT ONE
  # test in this suite went red. A consumer writing `.capabilities.git | not`
  # then gets the wrong answer, because the string "false" is truthy.
  jq -e '.capabilities.git | type == "boolean"' <<<"$output" > /dev/null
}

@test "the capability report names git absent, and the report survives it" {
  # This test asserts baseBranch, and a willSkip set that is wholly a function
  # of the remote — both of which the header at the top of this file says no
  # fixture test does. The exception is deliberate and it is safe for ONE
  # reason: git is off the search path built below, so the enclosing
  # checkout's origin/HEAD cannot be read and the fixture's git facts come
  # from this call's flags and the script's defaults instead of from this
  # repository. Put git back on that path and the exception collapses.
  #
  # What catches that, measured rather than asserted. Restoring git to the list
  # below turns this test red at its FIRST assertion, the capability itself,
  # which is where bats stops. The baseBranchSource and willSkip assertions are
  # corroborating, not the tripwire: they prove the git facts below came from
  # this call's flags and the script's defaults rather than from the enclosing
  # checkout. And note which assertion does NOT catch it — the baseBranch VALUE
  # stays "main" either way, because origin/HEAD here points at main, so it
  # would pass for a route this test does not intend. That is why the SOURCE is
  # asserted beside it.
  d="$BATS_TEST_TMPDIR/without-git"
  # DERIVED from PROBE_TOOLS by removing one name, never hand-listed. A hand
  # list goes stale the day a tool is added to that variable, and it goes stale
  # in the direction that hurts: the shim directory would then be missing TWO
  # tools, and this test would pass for a cause it does not name.
  tools=""
  for t in $PROBE_TOOLS; do [ "$t" = git ] || tools="$tools $t"; done
  shimdir "$d" $tools
  probe --path "$d" --dir "$FIX/other" --base-branch main

  # Reporting is not failing. The script still exits 0 and still emits one
  # well-formed document with git absent — which is exactly why the stop lives
  # in the orchestrator and not here. A script that died would leave this test
  # nothing to read, and the capability could only be inferred from an exit
  # code.
  [ "$status" -eq 0 ]
  jq -e . <<<"$output" > /dev/null
  [ "$(jq -r '.capabilities.git' <<<"$output")" = "false" ]
  # Type, for the same reason the present-git test asserts it: `jq -r` cannot
  # tell the boolean false from the string "false", and a consumer writing
  # `.capabilities.git | not` reads the string as truthy.
  jq -e '.capabilities.git | type == "boolean"' <<<"$output" > /dev/null

  # The report is COMPLETE, not truncated. Absence sets a field to false; it
  # never drops a key, and no consumer should have to read a short document as
  # the signal for a missing tool.
  [ "$(jq -r '.projectType' <<<"$output")" = "other" ]
  [ "$(jq -r '.baseBranch' <<<"$output")" = "main" ]
  # THE TRIPWIRE for the exception declared above, and it is the SOURCE, not
  # the value. Measured: this checkout publishes origin/HEAD -> origin/main, so
  # with git restored to the search path baseBranch resolves to "main" from
  # origin/HEAD — the same string the line above asserts, arriving by a route
  # this test does not intend. The value alone therefore proves nothing. The
  # source does: it reads "configured" only while git cannot be found, and
  # flips to "origin/HEAD" the moment it can.
  [ "$(jq -r '.baseBranchSource' <<<"$output")" = "configured" ]

  # No skip is announced on git's OWN account. The two that are announced belong
  # to the pre-existing no-remote branch: without git the remote cannot be read,
  # so it reads "none", and that branch names L and M. The exact set is pinned
  # rather than a count, because a count would let a future git-flavoured skip
  # replace one of these silently. A degradation names a phase the run can do
  # without, and for git there is no such phase — hence a stop, not a skip.
  [ "$(jq -c '[.willSkip[].phase] | sort' <<<"$output")" = '["L","M"]' ]
}
