#!/usr/bin/env bats

load ../../tests/helper

# The handoff skill is prose: its behaviour is instructions to Claude, so the
# suite cannot execute it. These tests pin the instructions that close one
# measured gap, the way tests/portability.bats pins the skill's refusal to write
# to git. They are regression guards, not proofs: they show the clauses are
# still on the page and still attached to the right branch, not that Claude
# follows them.
#
# The gap: when <docsDir> is ignored or excluded, the skill used to print a
# `git add` line naming the handoff document. Measured in a throwaway repository
# with `/docs/` in .git/info/exclude: `git add -- src/a.txt docs/handoffs/h.md`
# exited 1 AND staged src/a.txt, so the printed line failed halfway. And
# `git status --porcelain` never lists an ignored file (`--ignored` collapses it
# to `!! docs/`), so the Uncommitted work inventory omitted the document itself.
#
# The skill is read flattened: every line break becomes a space and runs of
# spaces collapse, so a clause pinned here survives being re-wrapped, and a
# pin cannot pass on two halves that only happen to sit on adjacent lines.

setup() {
  SKILL="$HANDOFF/skills/handoff/SKILL.md"
  [ -f "$SKILL" ] || { echo "no handoff skill at $SKILL"; false; }
  FLAT="$(tr '\r\n' '  ' < "$SKILL" | tr -s ' ')"
  [ -n "$FLAT" ] || { echo "flattened skill is empty"; false; }
}

# Prints the text strictly between the first $1 and the next $2 after it.
# Fails, naming the marker, when either is missing: a parameter expansion whose
# pattern does not match returns the whole string, and a region that silently
# widens to the whole file would let every pin below pass on the wrong text.
region() {
  case "$FLAT" in *"$1"*) ;; *) echo "start marker not found: $1" >&2; return 1 ;; esac
  local rest="${FLAT#*"$1"}"
  case "$rest" in *"$2"*) ;; *) echo "end marker not found after start: $2" >&2; return 1 ;; esac
  printf '%s' "${rest%%"$2"*}"
}

has() {
  case "$1" in *"$2"*) return 0 ;; esac
  echo "missing: $2"
  return 1
}

@test "the handoff skill checks whether its own document is git-ignored" {
  has "$FLAT" 'run `git check-ignore -q -- <path-to-handoff-document>`'
  # cwd-relative: measured, a root-relative path checked from a subdirectory
  # reported not ignored. The instruction must say where to run it.
  has "$FLAT" 'From the repository root, run `git check-ignore'
}

@test "an ignored handoff document is said to stay on this machine only" {
  ignored="$(region '**0, ignored.**' '**Any other status**')"
  has "$ignored" 'the handoff document is ignored and stays on this machine only'
  has "$ignored" 'a fresh clone will not have it'
}

@test "an ignored handoff document is kept out of the plain git add line" {
  ignored="$(region '**0, ignored.**' '**Any other status**')"
  has "$ignored" 'Keep the document out of the `git add` line'
  # The forced add is offered, separately, as the developer's optional choice.
  has "$ignored" 'git add -f -- <path-to-handoff-document> # optional'
  has "$ignored" 'printed for them to run, never run by you'

  # Inversion guard: the include instruction belongs to the not-ignored branch
  # and to nothing else. Swapping the two branches' bodies reddens here.
  plain="$(region '**1, not ignored.**' '**0, ignored.**')"
  has "$plain" 'Include the document itself in the `git add` line'
  run has "$ignored" 'Include the document itself'
  [ "$status" -ne 0 ]

  # The unconditional instruction this replaced must not come back.
  run has "$FLAT" 'Tell the developer the path, and include the document itself in the `git add` line'
  [ "$status" -ne 0 ]
}

@test "an ignored handoff document is listed under Uncommitted work, marked ignored" {
  inventory="$(region '**Uncommitted work**' '**Verification state**')"
  has "$inventory" '`git status --porcelain` never lists an ignored file'
  has "$inventory" '!! <path-to-handoff-document> (ignored: this handoff document, on this machine only)'
  # And the ignored branch of the save step sends the reader there.
  ignored="$(region '**0, ignored.**' '**Any other status**')"
  has "$ignored" 'Add the document to the Uncommitted work section'
}

# Audit item 14 (2026-10-10): the handoff ends by recording branch, HEAD and the
# `git status` lines into the document with handoff/scripts/reconcile-block.sh,
# and the next session's first step runs that record. The script and its block
# are tested in reconcile-block.bats; these pins hold the instructions that
# make the skill use them, in the right place and order.

@test "the handoff skill records the state with the plugin's script, as its last write" {
  rec="$(region '### 4. Record the state for the next session' '### 5. Print the resume prompt and stop')"
  has "$rec" 'bash "${CLAUDE_PLUGIN_ROOT}/scripts/reconcile-block.sh" <path-to-handoff-document>'
  has "$rec" 'From the repository root, run:'
  has "$rec" '**This is the last write of the handoff.**'
  # The whole sentence, through its list: a bare prefix let review's mutant
  # "nothing may change the repository after it, except the plan …" pass.
  has "$rec" 'nothing may change the repository after it: not the document, not the plan, not a memory file inside the repository.'
  has "$rec" 'If something must change after all, run the command again.'
  has "$rec" 'If it refuses (exit status other than 0), say so in the final message'
  # The record comes after durable knowledge, which may be written inside the
  # repository; the region above proves it sits between steps 4 and 5, and
  # this proves step 3 comes before it.
  before="${FLAT%%'### 4. Record the state'*}"
  has "$before" '### 3. Persist durable knowledge'
}

@test "the script the skill names is the one the plugin ships" {
  rel="$(region 'bash "${CLAUDE_PLUGIN_ROOT}/' '" <path-to-handoff-document>')"
  [ "$rel" = 'scripts/reconcile-block.sh' ]
  [ -f "$HANDOFF/$rel" ]
}

@test "Resume step 1 runs the Reconcile section, and falls back to a check by hand without one" {
  resume="$(region '**Resume protocol**' 'Before you finish the document')"
  has "$resume" 'run the one-line command in the `~~~sh` fence of the Reconcile section at the end of this document (not the script below it) and report its output'
  # An empty output is a check that did not run: bash fed nothing exits 0.
  has "$resume" 'if the output does not end in a `RECONCILE:` line, the check did not run, so say so and check by hand'
  # Named by its title, so "step 4" cannot be read as the Resume protocol's.
  has "$resume" 'checklist step 4 (Record the state for the next session) writes it'
  has "$resume" 'PR and CI state it cannot see, so step 1 still names them for a check by hand'
  has "$resume" 'If the document has no Reconcile section when the next session reads it, step 1 falls back to checking the branch, SHA and the Uncommitted work section by hand'
  # The skill's refusal branch points at the same fallback.
  rec="$(region '### 4. Record the state for the next session' '### 5. Print the resume prompt and stop')"
  has "$rec" 'the document then has no current Reconcile section (an earlier one, if any, is left as it was and will report MISMATCH), and step 1 of its Resume protocol falls back to the check by hand'
}

@test "a document the developer may commit is listed with the uncommitted work, so the two records agree" {
  plain="$(region '**1, not ignored.**' '**0, ignored.**')"
  has "$plain" 'list it in the Uncommitted work section as this run'"'"'s work, so that section and the Reconcile record describe the same tree'
}

# Audit item H10 (2026-10-12): the skill and the plugin's README and
# configuration page each describe the handoff document, and nothing held them
# together. Each test below reads both sides from the files, never from a list
# of its own: a list written into a test goes stale the day a section is added,
# in the direction that keeps the test green.

# The sections the skill requires, in order: the bold name opening each
# top-level bullet under "Required sections:", then the section that step 4's
# script appends to the document ("It appends the <Name> section").
skill_sections() {
  tr -d '\r' < "$SKILL" | awk '
    $0 == "Required sections:" { f = 1; next }
    /^Before you finish the document/ { f = 0 }
    f && /^- \*\*/ { s = $0; sub(/^- \*\*/, "", s); sub(/\*\*.*/, "", s); print s }'
  local rec re='It appends the ([A-Z][A-Za-z]*) section'
  rec="$(region '### 4. Record the state for the next session' '### 5. Print the resume prompt and stop')" || return 1
  [[ $rec =~ $re ]] || { echo "step 4 no longer says which section its script appends" >&2; return 1; }
  printf '%s\n' "${BASH_REMATCH[1]}"
}

# The first cell of every row of the README's section table.
readme_sections() {
  tr -d '\r' < "$HANDOFF/README.md" | awk '
    $0 == "| Section | What it holds |" { f = 1; next }
    f && /^\|---/ { next }
    f && !/^\|/ { exit }
    f { s = $0; sub(/^\| */, "", s); sub(/ *\|.*/, "", s); print s }'
}

@test "the sections the handoff skill requires are the README's section table, in order" {
  skill="$(skill_sections)"
  readme="$(readme_sections)"
  # Two lists that are both empty compare equal: require each to hold work.
  [ "$(printf '%s\n' "$skill" | grep -c .)" -ge 10 ] || { echo "skill list too short: $skill"; false; }
  [ "$(printf '%s\n' "$readme" | grep -c .)" -ge 10 ] || { echo "README table too short: $readme"; false; }
  # One measured difference, accepted by name and for this pair only: the
  # README's table says "Gotchas" where the skill names the section "Gotchas
  # discovered this session" (both as of 2.3.1). Any other spelling, on either
  # side, still differs.
  skill="$(printf '%s\n' "$skill" | awk '$0 == "Gotchas discovered this session" { $0 = "Gotchas" } { print }')"
  [ "$skill" = "$readme" ] || {
    echo "skill sections:"; printf '%s\n' "$skill"
    echo "README table:"; printf '%s\n' "$readme"
    false
  }
}

# The fenced block holding the line "Resume with:", from its opening fence to
# its closing one, CR removed.
resume_block() {
  tr -d '\r' < "$1" | awk '
    f { print; if ($0 == "```") exit; next }
    $0 == "Resume with:" && prev == "```" { print prev; print; f = 1; next }
    { prev = $0 }'
}

@test "the README's resume block is the skill's block, word for word but the path" {
  skill="$(resume_block "$SKILL")"
  readme="$(resume_block "$HANDOFF/README.md")"
  [ "$(printf '%s\n' "$skill" | grep -c .)" -ge 4 ] || { echo "no whole resume block in the skill: $skill"; false; }
  # The README shows a real path where the skill has its placeholder; put the
  # placeholder back, and every other byte must agree.
  readme="$(printf '%s\n' "$readme" | awk '/^Read [^ ]+ / { sub(/^Read [^ ]+ /, "Read <path-to-handoff-document> ") } { print }')"
  [ "$skill" = "$readme" ] || {
    echo "skill block:"; printf '%s\n' "$skill"
    echo "README block (path replaced):"; printf '%s\n' "$readme"
    false
  }
  # And the skill still says the block never varies, which is why one copy
  # in the README can stand for every handoff.
  has "$FLAT" 'The wording never varies; only the path does'
}

@test "the skill resolves docsDir in the precedence order docs/configuration.md gives" {
  conf="$HANDOFF/docs/configuration.md"
  [ -f "$conf" ] || { echo "no $conf"; false; }
  has "$FLAT" "documented in the plugin's \`docs/configuration.md\`"
  cflat="$(tr '\r\n' '  ' < "$conf" | tr -s ' ')"
  # The setting's own row: its default and its environment variable.
  row="$(tr -d '\r' < "$conf" | awk -F'|' '$2 == " `handoff.docsDir` " { print $3 "|" $4; exit }')"
  def="$(printf '%s' "${row%%|*}" | tr -d ' ')"
  env="$(printf '%s' "${row#*|}" | tr -d ' ')"
  [ -n "$def" ] && [ -n "$env" ] && [ "$def" != "$env" ] || { echo "no handoff.docsDir row: '$row'"; false; }
  # The order, as the page states it: "Defaults -> a -> b -> environment
  # variables." Each layer is turned into the words the skill uses for it,
  # and an unknown layer fails rather than being skipped.
  case "$cflat" in *'Defaults → '*) ;; *) echo "no precedence chain in $conf"; false ;; esac
  chain="Defaults → ${cflat#*Defaults → }"
  chain="${chain%%. *}"
  where="$(region '## Where the document goes' '## Checklist')"
  last=-1 n=0
  while [ -n "$chain" ]; do
    layer="${chain%% → *}"
    case "$chain" in *' → '*) chain="${chain#* → }" ;; *) chain= ;; esac
    case "$layer" in
      Defaults) words="the default $def" ;;
      'environment variables') words="$env" ;;
      '`<repo>/'*) f="${layer#\`<repo>/}"; words="\`$f at the repository root" ;;
      '`~/'*) words="$layer" ;;
      *) echo "unknown precedence layer '$layer'"; false ;;
    esac
    has "$where" "$words"
    before="${where%%"$words"*}"
    [ "${#before}" -gt "$last" ] || { echo "the skill names '$words' before the layer that precedes it"; false; }
    last=${#before}
    n=$((n + 1))
  done
  [ "$n" -eq 4 ] || { echo "expected 4 precedence layers, read $n"; false; }
  # The order alone is not the rule: review kept it while turning "take that
  # instead" into "ignore it instead" and "beats both files" into "loses to
  # both files", and the walk above stayed green. So the clause that says what
  # each layer does is pinned too, whole, with the values read from the page.
  has "$where" "start from the default $def; if \`~/.delivery-kit.json\` exists and sets it, take that; if \`.delivery-kit.json\` at the repository root sets it, take that instead; and the environment variable $env beats both files."
  has "$where" 'A missing or malformed file just leaves the previous value standing.'
  # And the page states the same two wins in words.
  has "$cflat" 'The environment wins'
  has "$cflat" 'The repository file beats the user-level one'
}
