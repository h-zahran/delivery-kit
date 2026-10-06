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
