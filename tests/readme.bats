#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# The root README became a short start page in item 15, and its Windows section
# and quick start state facts that live in code: the names pre-flight probes
# for gh, the jq install command, the guard's default window, the skills a
# reader is told to type, the marketplace add line, and the pre-flight block's
# shape. Each test derives the fact from the code and requires the prose to
# say the same, so a change on either side goes red. Sentences are matched in
# the shell after flattening newlines, never by grep on a process
# substitution, which has given false matches on Windows.

load helper

# The lines of one "## " section of a markdown file, CR removed.
section() {
  tr -d '\r' < "$1" | awk -v h="$2" '$0 == h { f = 1; next } f && /^## / { exit } f'
}

# A file's text with newlines and blockquote markers flattened to single spaces.
flat() {
  tr -d '\r' < "$1" | sed 's/^> //' | tr '\n' ' ' | tr -s ' '
}

@test "the Windows gh row names every name pre-flight probes" {
  cd "$ROOT"
  local loops names phrase win
  loops="$(awk '/^for c in gh( [^;]+)?; do$/ { n++ } END { print n + 0 }' pipeline/scripts/preflight.sh)"
  [ "$loops" = 1 ] || { echo "expected one 'for c in gh ...; do' probe loop in preflight.sh, found $loops"; false; }
  names="$(awk '/^for c in gh( [^;]+)?; do$/ { sub(/^for c in /, ""); sub(/; do$/, ""); print }' pipeline/scripts/preflight.sh)"
  # `gh`, `gh.exe` and `gh.cmd`: commas, then "and" before the last.
  phrase="$(printf '%s\n' "$names" | awk '{ for (i = 1; i <= NF; i++) s = s (i == 1 ? "" : (i == NF ? " and " : ", ")) "`" $i "`"; print s }')"
  win="$(section README.md '## Windows' | tr '\n' ' ' | tr -s ' ')"
  [[ $win == *"looks for $phrase"* ]] || { echo "the root README's Windows section does not say pre-flight looks for $phrase"; false; }
  # The row's two halves: the run's own calls use the found name, which the
  # skill states; and the review phase's code-review plugin calls plain gh.
  [[ $win == *"the run's own calls use the one it finds"* ]] || { echo "the Windows gh row no longer says the run's own calls use the name found"; false; }
  [[ $(flat pipeline/skills/pipeline/SKILL.md) == *'Every `gh` call this run makes uses the name `remote.ghCommand` reports'* ]] \
    || { echo "the skill no longer says every gh call uses the reported name, which the Windows row relies on"; false; }
  [[ $win == *'the review phase (M) runs the separate code-review plugin, which calls plain `gh`'* ]] \
    || { echo "the Windows gh row no longer warns that the review phase calls plain gh"; false; }
}

@test "the Windows jq install command is the one the install guide gives" {
  cd "$ROOT"
  local win cmd row
  win="$(section README.md '## Windows' | tr '\n' ' ')"
  cmd="${win#*\`winget install }"
  [ "$cmd" != "$win" ] || { echo "no winget install command in the root README's Windows section"; false; }
  cmd="winget install ${cmd%%\`*}"
  row="$(tr -d '\r' < handoff/docs/install.md | awk '/^\| Windows \|/ { print; exit }')"
  [ "$row" = "| Windows | \`$cmd\` |" ] || { echo "README says '$cmd'; handoff/docs/install.md's Windows row is '$row'"; false; }
}

@test "the default window the READMEs state is the hook's default" {
  cd "$ROOT"
  local dw dwc
  dw="$(awk -F= '/^DEFAULT_WINDOW=[0-9]+$/ { print $2; exit }' handoff/hooks/context-guard.sh)"
  [ -n "$dw" ] || { echo "no DEFAULT_WINDOW=<digits> line in context-guard.sh"; false; }
  # Thousands separators by awk: printf %'d follows the locale, and a sed
  # alternation (\|) is GNU only, which the macOS runner would not read.
  dwc="$(printf '%s\n' "$dw" | awk '{ s = $0; r = ""; while (length(s) > 3) { r = "," substr(s, length(s) - 2) r; s = substr(s, 1, length(s) - 3) } print s r }')"
  [[ $(flat README.md) == *"The guard assumes a $dwc-token window."* ]] || { echo "README.md does not state the default window as $dwc"; false; }
  [[ $(flat handoff/README.md) == *"The defaults assume a $dwc-token context window"* ]] || { echo "handoff/README.md does not state the default window as $dwc"; false; }
}

@test "every plugin skill a README names is a shipped skill" {
  cd "$ROOT"
  local f t miss="" n=0
  for f in README.md handoff/README.md pipeline/README.md; do
    # Inline (`handoff:setup`) and as a command line of its own inside a fence
    # (mutation found the fenced quick-start step unread). Either may carry
    # the slash a reader types (`/handoff:setup`).
    for t in $(tr -d '\r' < "$f" | grep -oE '`/?(handoff|pipeline):[a-z][a-z-]*`|^/?(handoff|pipeline):[a-z][a-z-]*( |$)' | tr -d '`/ ' | sort -u); do
      n=$((n + 1))
      [ -f "${t%%:*}/skills/${t#*:}/SKILL.md" ] || miss="$miss $f:$t"
    done
  done
  [ "$n" -gt 0 ] || { echo "no plugin:skill names read from the READMEs; the extraction is broken"; false; }
  [ -z "$miss" ] || { echo "named but not shipped:$miss"; false; }
}

@test "the quick start adds the marketplace, installs, then runs /handoff:setup" {
  cd "$ROOT"
  local owner mname want qs la li ls distinct
  # The repository is named like the marketplace, so owner/name is the add line.
  owner="$(jq -r '.owner.url' .claude-plugin/marketplace.json | tr -d '\r')"
  owner="${owner#https://github.com/}"
  mname="$(jq -r '.name' .claude-plugin/marketplace.json | tr -d '\r')"
  want="/plugin marketplace add $owner/$mname"
  distinct="$(cat README.md handoff/README.md pipeline/README.md handoff/docs/install.md | tr -d '\r' | awk '/^\/plugin marketplace add / { print }' | sort -u)"
  [ "$distinct" = "$want" ] || { echo "marketplace add lines differ from '$want': $distinct"; false; }
  qs="$(section README.md '## Quick start')"
  la="$(printf '%s\n' "$qs" | awk -v w="$want" '$0 == w { print NR; exit }')"
  li="$(printf '%s\n' "$qs" | awk '$0 == "/plugin install handoff@delivery-kit" { print NR; exit }')"
  ls="$(printf '%s\n' "$qs" | awk '$0 == "/handoff:setup" { print NR; exit }')"
  [ -n "$la" ] && [ -n "$li" ] && [ -n "$ls" ] || { echo "quick start lacks a step: add=$la install=$li setup=$ls"; false; }
  [ "$la" -lt "$li" ] && [ "$li" -lt "$ls" ] || { echo "quick start order is add=$la install=$li setup=$ls"; false; }
}

@test "the README sample pre-flight block uses the skill's labels, in order" {
  cd "$ROOT"
  local labels_awk out p ph rs n=0
  labels_awk='/^Project type : / { f = 1 } f { l = $0; sub(/ *:.*$/, "", l); print l } f && /^Will skip / { exit }'
  tr -d '\r' < pipeline/skills/pipeline/SKILL.md | awk "$labels_awk" > "$BATS_TEST_TMPDIR/skill-labels"
  tr -d '\r' < pipeline/README.md | awk "$labels_awk" > "$BATS_TEST_TMPDIR/readme-labels"
  [ -s "$BATS_TEST_TMPDIR/skill-labels" ] && [ -s "$BATS_TEST_TMPDIR/readme-labels" ] || { echo "no pre-flight block read from the skill or the README"; false; }
  # Every README label in the skill's template, in the template's order.
  out="$(awk 'NR == FNR { a[++n] = $0; next } { while (i < n && a[++i] != $0) {} if (a[i] != $0) { print $0; exit } }' \
    "$BATS_TEST_TMPDIR/skill-labels" "$BATS_TEST_TMPDIR/readme-labels")"
  [ -z "$out" ] || { echo "README pre-flight label not in the skill's template, or out of order: $out"; false; }
  # Every Will skip line is a skip preflight.sh can make, word for word.
  tr -d '\r' < pipeline/README.md | awk '/^Will skip    : / { sub(/^Will skip    : /, ""); print }' > "$BATS_TEST_TMPDIR/readme-skips"
  while IFS= read -r p; do
    n=$((n + 1))
    ph="${p%% — *}"; rs="${p#* — }"
    grep -qF -- "add_skip \"$ph\" \"$rs\"" pipeline/scripts/preflight.sh || { echo "pre-flight never prints this skip: $p"; false; }
  done < "$BATS_TEST_TMPDIR/readme-skips"
  [ "$n" -gt 0 ] || { echo "the README sample shows no Will skip line"; false; }
}

@test "the READMEs keep the seed and settings sentences readers rely on" {
  cd "$ROOT"
  [[ $(flat pipeline/README.md) == *'With no GitHub remote or no `gh`, a `#123` seed **stops** rather than quietly specifying a feature called "#123".'* ]] \
    || { echo "pipeline/README.md no longer says a #123 seed stops without a remote or gh"; false; }
  [[ $(flat README.md) == *'It is in your Windows user folder: `%USERPROFILE%\.delivery-kit.json`'* ]] \
    || { echo "the root README no longer says where ~/.delivery-kit.json is on Windows"; false; }
  [[ $(flat README.md) == *'Upgrading from the 1.x plugin called `delivery-kit`? Uninstall it **first**'* ]] \
    || { echo "the root README's quick start no longer says to uninstall the 1.x plugin first"; false; }
}

@test "a skill the READMEs tell you to type carries its slash" {
  cd "$ROOT"
  local f bare=""
  # A line of its own (indented or not) that starts with a bare plugin:skill
  # is a command to type without the slash Claude Code lists it under.
  for f in README.md handoff/README.md pipeline/README.md; do
    if tr -d '\r' < "$f" | grep -nE -- '^[[:space:]]*(handoff|pipeline):[a-z]' > "$BATS_TEST_TMPDIR/bare"; then
      bare="$bare $f: $(tr '\n' ' ' < "$BATS_TEST_TMPDIR/bare")"
    fi
  done
  [ -z "$bare" ] || { echo "typed without its slash:$bare"; false; }
  [[ $(flat README.md) == *'Type it as shown, slash included: Claude Code lists each plugin skill as `/<plugin>:<skill>`'* ]] \
    || { echo "the root README no longer says how a plugin skill is typed"; false; }
  # "Asking in words works too" (setup) and "or say *hand off*" (handoff) hold
  # only while Claude may load each skill by itself.
  [[ $(flat handoff/README.md) == *'You run `/handoff:handoff`, or say *hand off*.'* ]] \
    || { echo "handoff/README.md no longer offers saying hand off"; false; }
  for f in handoff/skills/setup/SKILL.md handoff/skills/handoff/SKILL.md; do
    if grep -qE -- '^disable-model-invocation: *true' "$f"; then
      echo "$f is no longer model-invocable, but a README says asking in words works"; false
    fi
  done
}

@test "the README says which of /pipeline and /pipeline:pipeline runs what" {
  cd "$ROOT"
  local p
  p="$(flat pipeline/README.md)"
  [[ $p == *'Typed bare, `/pipeline` runs the pipeline skill directly. `/pipeline:pipeline` goes through the plugin'"'"'s command, which hands the skill your seed unchanged.'* ]] \
    || { echo "pipeline/README.md no longer says what bare /pipeline and /pipeline:pipeline run"; false; }
  if [[ $p == *'resolves to the same command'* ]]; then echo "the old, measured-false sentence is back"; false; fi
  # Bare /pipeline reaches the skill because the skill is named pipeline; the
  # namespaced form is the command file's name.
  grep -qx -- 'name: pipeline' pipeline/skills/pipeline/SKILL.md || { echo "the pipeline skill is no longer named pipeline"; false; }
  [ -f pipeline/commands/pipeline.md ] || { echo "no commands/pipeline.md, so /pipeline:pipeline names nothing"; false; }
}

@test "the /pipeline:pipeline description names every seed form the skill reads" {
  cd "$ROOT"
  local forms n line desc form1 form2 form3
  forms="$(tr -d '\r' < pipeline/skills/pipeline/SKILL.md | awk '/^\*\*Seed forms\.\*\*/ { f = 1; next } f && /^## / { exit } f')"
  n="$(printf '%s\n' "$forms" | grep -cE -- '^[0-9]+\. ' || true)"
  [ "$n" = 3 ] || { echo "the skill now lists $n seed forms; the command description names three"; false; }
  # Each form's operative words, read from the skill: form 1's pattern, form
  # 2's trigger and source, form 3's name for what it passes through.
  form1="$(printf '%s\n' "$forms" | awk '/^1\. / { sub(/^[^`]*`/, ""); sub(/`.*$/, ""); print; exit }')"
  form2="$(printf '%s\n' "$forms" | awk '/^2\. / { print; exit }')"
  form3="$(printf '%s\n' "$forms" | awk '/^3\. / { print; exit }')"
  [ -n "$form1" ] || { echo "no backticked pattern read from the skill's first seed form"; false; }
  [[ $form2 == *'`#` followed by digits — fetch that GitHub issue'* ]] || { echo "the skill's second seed form changed: $form2"; false; }
  [[ $form3 == *'Anything else — the feature description, verbatim'* ]] || { echo "the skill's third seed form changed: $form3"; false; }
  # The description is a double-quoted YAML string: unquoted, its `: ` and ` #`
  # would end the value early. `claude plugin validate` does not catch that.
  line="$(tr -d '\r' < pipeline/commands/pipeline.md | awk '/^description: / { print; exit }')"
  [[ $line == 'description: "'*'"' ]] || { echo "the command description is not one double-quoted YAML string: $line"; false; }
  desc="${line#description: \"}"; desc="${desc%\"}"
  [[ $desc != *'"'* ]] || { echo "the quoted description holds a double quote of its own"; false; }
  [[ $desc == *"\`$form1\`"* ]] || { echo "the command description does not name the plan-file form $form1"; false; }
  local re='a GitHub issue as `#[0-9]+`'
  [[ $desc =~ $re ]] || { echo "the command description does not name the issue form as # and digits"; false; }
  [[ $desc == *'a feature description in your own words'* ]] || { echo "the command description does not name the verbatim form"; false; }
}

@test "the plan-file seed is documented as the skill reads it" {
  cd "$ROOT"
  local p
  p="$(flat pipeline/README.md)"
  [[ $p == *'No script reads the plan file: Claude does, so nothing in the plugin fixes the heading level or where the section stops.'* ]] \
    || { echo "pipeline/README.md no longer says how the plan-file seed is read"; false; }
  # The sentence is true only while no script reads planFile.
  if grep -lF -- 'planFile' pipeline/scripts/*.sh > "$BATS_TEST_TMPDIR/readers"; then
    echo "a script now reads planFile, so the README's account of the plan-file seed is stale: $(tr '\n' ' ' < "$BATS_TEST_TMPDIR/readers")"; false
  fi
  [[ $(flat pipeline/skills/pipeline/SKILL.md) == *'For the plan-file form, quote the section verbatim'* ]] \
    || { echo "the skill no longer quotes the plan-file section verbatim, which the README says"; false; }
  [[ $p == *'each phase is a `## Phase <N>: <title>` heading'* ]] \
    || { echo "pipeline/README.md no longer shows the plan file's heading shape"; false; }
  # Where a section ends, as this repository's own plan has it: a phase holds
  # no deeper heading, and one phase is followed by a `#` heading, not `##`.
  [[ $p == *'its section runs to the next `#` or `##` heading'* ]] \
    || { echo "pipeline/README.md no longer says where a plan-file section ends"; false; }
  local deeper top
  deeper="$(tr -d '\r' < main-plan.md | awk '/^## Phase [0-9]+:/ { p = 1; next } /^##? / { p = 0 } p && /^###/ { c++ } END { print c + 0 }')"
  top="$(tr -d '\r' < main-plan.md | awk '/^## Phase [0-9]+:/ { p = 1; next } p && /^# / { c++ } /^##? / { p = 0 } END { print c + 0 }')"
  [ "$deeper" = 0 ] || { echo "main-plan.md has $deeper deeper heading(s) inside a phase; the README's section end is stale"; false; }
  [ "$top" -gt 0 ] || { echo "no phase in main-plan.md ends at a # heading; the README need not name one"; false; }
}

@test "the README warns what a dry run leaves behind, naming the run folder" {
  cd "$ROOT"
  local root fmt rundir sfile slice row c
  root="$(sed -n 's/^STATE_ROOT="\(.*\)"$/\1/p' pipeline/scripts/progress.sh)"
  fmt="$(sed -n "s/^run_dir() { printf '\([^']*\)'.*/\1/p" pipeline/scripts/progress.sh)"
  sfile="$(sed -n "s/^state_file() { printf '[^']*\/\([^'/]*\)'.*/\1/p" pipeline/scripts/progress.sh)"
  [ -n "$root" ] && [ -n "$fmt" ] && [ -n "$sfile" ] || { echo "no STATE_ROOT, run_dir() or state file name read from progress.sh: root=$root fmt=$fmt file=$sfile"; false; }
  # shellcheck disable=SC2059 # the format is progress.sh's own
  rundir="$(printf "$fmt" "$root" '<feature>')/"
  # The warning paragraph alone, from its first sentence to its last: the flag
  # table above it says "the feature branch" and "the spec folder" too, so a
  # whole-file match would pass with the warning inverted.
  slice="$(tr -d '\r' < pipeline/README.md | awk '/^`--dry-run` is not a preview/ { f = 1 } f && /^$/ { exit } f { print }' | tr '\n' ' ' | tr -s ' ')"
  [ -n "$slice" ] || { echo "no dry-run warning paragraph in pipeline/README.md"; false; }
  [[ $slice == *'happy to branch from.'* ]] || { echo "the dry-run paragraph slice did not reach its last sentence: $slice"; false; }
  for c in 'it creates the feature branch' 'and switches you onto it' 'the spec folder the spec tool writes' \
           "the run's folder, \`$rundir\`, which holds the state file \`$sfile\`" 'All three are still there when it stops.' \
           'You are left on the new branch with the spec folder uncommitted' 'a dry run stops before H'; do
    [[ $slice == *"$c"* ]] || { echo "the dry-run paragraph lost: $c"; false; }
  done
  row="$(tr -d '\r' < pipeline/README.md | awk '/^\| `--dry-run` \|/ { print; exit }')"
  [[ $row == *'Leaves a branch, a spec folder and a state file behind'* ]] || { echo "the --dry-run flag row lost its warning: $row"; false; }
  [[ $(flat pipeline/skills/pipeline/SKILL.md) == *'Run the spec phases A–F.5 normally'* ]] \
    || { echo "the skill's --dry-run no longer runs the spec phases normally, which the warning rests on"; false; }
}

@test "the README says gh must be logged in, and pre-flight does not check it" {
  cd "$ROOT"
  local p
  p="$(flat pipeline/README.md)"
  [[ $p == *'`gh` must also be logged in: run `gh auth login` once'* ]] || { echo "pipeline/README.md does not say gh must be logged in"; false; }
  [[ $p == *'Pre-flight checks only that `gh` is on PATH, not that it is logged in'* ]] \
    || { echo "pipeline/README.md no longer says pre-flight checks presence only"; false; }
  # Pre-flight runs no gh at all: the probe loop's body only looks gh up, and
  # nothing outside the loop runs gh by any name or through the name it found.
  # A verb list (auth status, auth login) would let `gh api user` through.
  local pf loop rest
  pf="$(tr -d '\r' < pipeline/scripts/preflight.sh)"
  loop="$(printf '%s\n' "$pf" | awk '/^for c in gh / { f = 1; next } f && /^done$/ { exit } f')"
  [[ $loop == *'command -v "$c"'* ]] || { echo "no gh probe loop that looks gh up with command -v in preflight.sh"; false; }
  local used="${loop//command -v \"\$c\"/}"; used="${used//gh_command=\"\$c\"/}"
  [[ $used != *'$c'* ]] || { echo "the gh probe loop uses the name for more than a lookup and a record: $loop"; false; }
  rest="$(printf '%s\n' "$pf" | awk '/^for c in gh / { s = 1; next } s && /^done$/ { s = 0; next } s { next } /^[[:space:]]*#/ { next } { print }')"
  # The allowed uses: its empty start, and handing it to jq for the report.
  rest="${rest//gh_command=\"\"/}"; rest="${rest//--arg gh_command \"\$gh_command\"/}"; rest="${rest//ghCommand: \$gh_command/}"
  [[ $rest != *'gh_command'* ]] || { echo "preflight.sh uses the found gh name outside the probe and its report"; false; }
  if printf '%s\n' "$rest" | awk '{ l = $0; gsub(/"[^"]*"/, "", l); gsub(/'"'"'[^'"'"']*'"'"'/, "", l); sub(/[[:space:]]#.*$/, "", l); gsub(/--arg[a-z]* [A-Za-z_]+/, "", l); print l }' \
       | grep -nE -- '(^|[;&|(`[:space:]])gh(\.exe|\.cmd)?([[:space:]]|$)' > "$BATS_TEST_TMPDIR/ghrun"; then
    echo "preflight.sh now runs gh outside the probe loop, so the README's presence-only sentence may be stale: $(cat "$BATS_TEST_TMPDIR/ghrun")"; false
  fi
}

@test "the Windows CRLF row names jq -b, and the scripts it vouches for still cope" {
  cd "$ROOT"
  local win
  win="$(section README.md '## Windows' | tr '\n' ' ' | tr -s ' ')"
  [[ $win == *'The Windows build of `jq` ends each line with CRLF'* ]] || { echo "the Windows section has no CRLF row"; false; }
  # The whole clause: a bare "use `jq -b`" is also a substring of its negation.
  [[ $win == *'In your own scripts, use `jq -b`: it writes LF only.'* ]] || { echo "the CRLF row no longer tells you to use jq -b"; false; }
  [[ $win == *'They never read `jq` line by line without `-b`'* ]] || { echo "the CRLF row no longer says how the plugins cope"; false; }
  # The row names no file the pipeline writes: a state-file write may become
  # LF-only, and the row must stay true either way.
  if [[ $win == *'progress.json'* ]]; then echo "the Windows section names the state file again"; false; fi
  # "Never line by line without -b": no shipped script feeds jq's output to a
  # line reader (a process substitution, a pipe into while, mapfile or
  # readarray) unless that jq call passes -b. jqs is progress.sh's -b wrapper.
  local f bad=""
  for f in handoff/hooks/*.sh handoff/scripts/*.sh pipeline/scripts/*.sh; do
    if tr -d '\r' < "$f" | awk '/^[[:space:]]*#/ { next } /(< <\(|mapfile|readarray)[^#]*jq / || /jq [^#]*\| *(while|mapfile|readarray)/' \
         | grep -vE -- 'jq -[a-zA-Z]*b ' > "$BATS_TEST_TMPDIR/reader"; then
      bad="$bad $f: $(tr '\n' ' ' < "$BATS_TEST_TMPDIR/reader")"
    fi
  done
  [ -z "$bad" ] || { echo "a line reader takes jq output without -b:$bad"; false; }
  grep -qF -- 'v="$(jq ${JQB:+"$JQB"} -r "$@")" || return 1' pipeline/scripts/progress.sh \
    || { echo "progress.sh's jqs no longer passes the probed jq -b, which the CRLF row says"; false; }
  grep -qF -- "v=\${v%\$'\\r'}" handoff/hooks/session-start.sh \
    || { echo "session-start.sh no longer strips a trailing CR from jq, which the CRLF row says"; false; }
}

@test "CONTRIBUTING gives the local plugin loop and CI's own shellcheck lines" {
  cd "$ROOT"
  local ci contrib l
  ci="$(tr -d '\r' < .github/workflows/ci.yml | awk '/^ *mapfile -d .. files < <\(git ls-files/ || /^ *shellcheck --norc / { sub(/^ */, ""); print }')"
  [ "$(printf '%s\n' "$ci" | grep -c -- .)" = 2 ] || { echo "expected one discovery line and one shellcheck line in ci.yml, read: $ci"; false; }
  contrib="$(tr -d '\r' < CONTRIBUTING.md | awk '{ sub(/^ */, ""); print }')"
  while IFS= read -r l; do
    [[ $'\n'"$contrib"$'\n' == *$'\n'"$l"$'\n'* ]] || { echo "CONTRIBUTING.md does not carry CI's line: $l"; false; }
  done <<< "$ci"
  [[ $contrib == *'claude --plugin-dir ./handoff --plugin-dir ./pipeline'* ]] || { echo "CONTRIBUTING.md lost the local plugin loop"; false; }
  local cflat
  cflat="$(flat CONTRIBUTING.md)"
  [[ $cflat == *'After an edit, run `/reload-plugins` in the session to load the change.'* ]] \
    || { echo "CONTRIBUTING.md no longer says how to load an edit"; false; }
  # mapfile -d arrived in bash 4.4; the discovery line uses it.
  [[ $ci == *'mapfile -d '* ]] && [[ $cflat == *'in bash 4.4 or later (`mapfile -d` needs it'* ]] \
    || { echo "CONTRIBUTING.md no longer names the bash that mapfile -d needs"; false; }
  [[ $cflat == *'The vocabulary is names from the project the plugins were extracted from: none of them may appear in a shipped file'* ]] \
    || { echo "CONTRIBUTING.md no longer says what the vocabulary scan guards"; false; }
}

@test "CONTRIBUTING puts the maintainer exclude steps after the tests" {
  cd "$ROOT"
  local tests maint ex
  tests="$(tr -d '\r' < CONTRIBUTING.md | awk '$0 == "## Running the tests" { print NR; exit }')"
  maint="$(tr -d '\r' < CONTRIBUTING.md | awk '$0 == "## Maintainers" { print NR; exit }')"
  ex="$(tr -d '\r' < CONTRIBUTING.md | awk 'index($0, ">> .git/info/exclude") { print NR; exit }')"
  [ -n "$tests" ] && [ -n "$maint" ] && [ -n "$ex" ] || { echo "missing: tests=$tests maintainers=$maint exclude=$ex"; false; }
  [ "$tests" -lt "$maint" ] && [ "$maint" -lt "$ex" ] || { echo "order is tests=$tests maintainers=$maint exclude=$ex"; false; }
  if grep -nF -- 'This plugin was extracted' CONTRIBUTING.md; then echo "the stale one-plugin sentence is back"; false; fi
}

@test "the handoff README's resume block is the skill's, on one Read line" {
  cd "$ROOT"
  local skill pre post got next
  skill="$(tr -d '\r' < handoff/skills/handoff/SKILL.md | awk 'f { print; exit } $0 == "Resume with:" { f = 1 }')"
  [[ $skill == *'<path-to-handoff-document>'* ]] || { echo "no placeholder line after 'Resume with:' in the skill: $skill"; false; }
  pre="${skill%%<path-to-handoff-document>*}"
  post="${skill#*<path-to-handoff-document>}"
  got="$(tr -d '\r' < handoff/README.md | awk 'f { print; exit } $0 == "Resume with:" { f = 1 }')"
  next="$(tr -d '\r' < handoff/README.md | awk 'f == 2 { print; exit } f { f++ } $0 == "Resume with:" { f = 1 }')"
  [[ $got == "$pre"*"$post" ]] || { echo "README Read line '$got' is not the skill's '$skill'"; false; }
  local mid="${got#"$pre"}"; mid="${mid%"$post"}"
  [ -n "$mid" ] && [[ $mid != *' '* ]] || { echo "README path '$mid' is empty or holds a space"; false; }
  [ "$next" = '```' ] || { echo "the README block continues past the Read line: '$next'"; false; }
}

# Audit item D14 (2026-10-12): Install sat twelfth of fifteen sections, near
# the end of a page the marketplace shows first. It is the first section now,
# right after the paragraph saying what the plugin is, so a reader who wants
# only the two commands finds them without the walkthrough.
@test "the pipeline README puts Install first, before the walkthrough" {
  cd "$ROOT"
  local first install walk
  first="$(tr -d '\r' < pipeline/README.md | awk '/^## / { print; exit }')"
  [ "$first" = '## Install' ] || { echo "the first section of pipeline/README.md is '$first', not '## Install'"; false; }
  install="$(tr -d '\r' < pipeline/README.md | awk '$0 == "## Install" { print NR; exit }')"
  walk="$(tr -d '\r' < pipeline/README.md | awk '$0 == "## How you start it" { print NR; exit }')"
  [ -n "$install" ] && [ -n "$walk" ] && [ "$install" -lt "$walk" ] \
    || { echo "order is install=$install how-you-start-it=$walk"; false; }
  # The section still holds the install line the other READMEs give.
  local sec
  sec="$(section pipeline/README.md '## Install')"
  [[ $'\n'$sec$'\n' == *$'\n/plugin install pipeline@delivery-kit\n'* ]] \
    || { echo "the Install section no longer holds /plugin install pipeline@delivery-kit"; false; }
}
