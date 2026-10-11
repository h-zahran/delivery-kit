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
    for t in $(tr -d '\r' < "$f" | grep -oE '`(handoff|pipeline):[a-z][a-z-]*`' | tr -d '`' | sort -u); do
      n=$((n + 1))
      [ -f "${t%%:*}/skills/${t#*:}/SKILL.md" ] || miss="$miss $f:$t"
    done
  done
  [ "$n" -gt 0 ] || { echo "no plugin:skill names read from the READMEs; the extraction is broken"; false; }
  [ -z "$miss" ] || { echo "named but not shipped:$miss"; false; }
}

@test "the quick start adds the marketplace, installs, then runs handoff:setup" {
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
  ls="$(printf '%s\n' "$qs" | awk '$0 == "handoff:setup" { print NR; exit }')"
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
