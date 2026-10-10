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
