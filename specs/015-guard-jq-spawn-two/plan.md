# Implementation Plan: the guard stops counting jq, part two

**Branch**: `015-guard-jq-spawn-two` | **Date**: 2026-09-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/015-guard-jq-spawn-two/spec.md`

## Summary

The context guard runs after every tool call. On the path it takes almost every
time it starts four to six jq processes, one `grep`, one `cat` and one `printf`
subshell. Two of those are pure detour and one jq call is redundant.

Two changes, independent of each other:

- **F7** — stop copying stdin into a shell variable and writing it back out.
  jq reads stdin directly. The jq-unavailable branch gains one `cat` so that
  every path still consumes its stdin; the measurement in
  [research.md](./research.md) R2 shows a reader that does not read costs the
  caller a broken-pipe signal, so this is required, not tidy.
- **F8** — get the reading count and the median from one jq pass instead of
  two jq passes plus a `grep -c`. The starved path keeps its uncapped re-read
  and so spends one more, exactly as today.

The fallback arithmetic does not change: the floor of fifteen, the median of the
last fifteen and the uncapped re-read are all preserved, including the quirk
that a negative reading is excluded from the count and included in the median.

## Technical Context

**Language/Version**: POSIX-targeted bash. Measured on GNU bash 5.3.9
(x86_64-pc-cygwin). The hook has no `set -e`, so a failing command substitution
does not abort it — relied on by the existing code and by this change.

**Primary Dependencies**: jq — a hard dependency, probed at run time. Measured
on jq-1.8.1. The new program uses `inputs`, `try` in its `?` spelling, `test`
and `tostring`, all present since jq 1.5. No version floor moves.

**Storage**: none. The hook reads a JSONL transcript and writes one flag file
per session bucket under the temporary directory.

**Testing**: `bats`. The full house suite is
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`,
run from the repository root. Expected: `1..163`, zero failures.

**Target Platform**: macOS, Linux and Windows under Git Bash. Windows is the
one that makes this change worth doing — process creation there is expensive
enough to dominate the hook's cost.

**Project Type**: shell hook shipped inside a Claude Code plugin.

**Performance Goals**: one fewer jq process and one fewer `grep` per run on both
transcript shapes; one fewer `cat` and one fewer `printf` subshell per run on
the ordinary path. Target columns, to be confirmed by measurement:
ordinary 4/5/6 → 3/4/5, starved 5/6/7 → 4/5/6, for zero, one and two
configuration files.

**Constraints**: byte-identical stdout and exit status on every shape.
`handoff/tests/context-guard.bats` may not be edited — a constraint the owner
lifted during implementation, for one test whose anchors pinned the shape of the
caller rather than the program; spec FR-011 carries the decision and what was
done to keep the test as strong. `handoff/hooks/` is a
restricted-vocabulary surface, so comments move but are never compressed.

**Scale/Scope**: two files changed for behaviour. `handoff/hooks/context-guard.sh`
in two regions, about 25 lines of code and the comments that carry the reasons;
and `handoff/skills/setup/SKILL.md`, which holds the same reading rule and is
pinned to the hook by the suite, so it cannot stay behind. Three supporting
files changed: `scripts/context-guard/differential.sh` gains transcript shapes,
`handoff/tests/context-guard.bats` gains two updated extraction anchors, and
`handoff/CHANGELOG.md` gains the entry. One more record follows the work rather
than driving it: `scripts/context-guard/README.md`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is the unfilled template. The owner was
offered the chance to write one at pre-flight and declined, for the twelfth
consecutive run. **There are therefore no constitution gates to evaluate, and
this section passes vacuously — it is not evidence of compliance with anything.**

Recorded so the vacuum is not mistaken for a clean bill: this repository keeps
its governance as in-file comments and pinned test strings rather than as a
constitution document, and those are what the review phases actually read. The
rules this change is held to are the ones in the spec, not in a governance file.

**Post-design re-check**: unchanged. Phase 1 introduced no new project, no new
dependency and no new abstraction. Complexity Tracking below is empty for the
same reason.

## Project Structure

### Documentation (this feature)

```text
specs/015-guard-jq-spawn-two/
├── plan.md              # This file
├── spec.md              # Phase B output, clarified at Phase C
├── research.md          # Phase 0 output — eight measurements
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output — the verification recipe
├── contracts/
│   └── context-guard.md # The hook's observable contract
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase E output
```

### Source Code (repository root)

```text
handoff/
├── hooks/
│   └── context-guard.sh        # CHANGED — the two regions below
├── skills/setup/SKILL.md       # CHANGED — same reading rule, pinned to the
│                               #   hook by the suite, so it moves with it
├── tests/
│   └── context-guard.bats      # CHANGED — two anchors in one test, by the
│                               #   owner's decision; see spec FR-011
└── CHANGELOG.md                # CHANGED — one Changed entry under Unreleased

scripts/
└── context-guard/
    ├── README.md               # CHANGED — records the new shapes and results
    └── differential.sh         # CHANGED — gains the transcript shapes

specs/014-guard-jq-spawn-count/
└── quickstart.md               # READ, NOT CHANGED — the process-counting rig
```

**Structure Decision**: no new directories and no new files. The change is
confined to two regions of one hook and the one document that duplicates its
reading rule, plus the maintainer rigs that prove it and the records that
describe it. The rigs live under `scripts/` rather than
`handoff/` because `handoff/` is copied onto every user's machine at install and
these are maintainer tools; that decision was made in the previous phase and is
inherited, not revisited.

### The two regions

**Region one — stdin, around lines 47 to 63.**

Today: `input=$(cat)` at the top, a jq availability probe below it, and the
payload extraction further down doing `printf '%s' "$input" | jq`.

After: the probe moves above where stdin is read, its branch gains a step that
consumes stdin, and the payload extraction lets jq read stdin itself. The
variable holding the payload text disappears; it had exactly one consumer,
confirmed by search.

**Region two — the transcript, around lines 283 to 327.**

Today: one jq over the capped read, a `grep -c` to count, a conditional second
jq over the uncapped read, and a third jq for the median.

After: one jq over the capped read producing the count and the median joined by
the separator this file already defines once; a shell split; a guard that forces
a non-numeric count to zero so a broken count means *starved*; and the same
conditional second jq over the uncapped read. The `grep` and the third jq are
gone.

The jq program string stays a single variable used by both calls, so the capped
and uncapped forms cannot drift apart — that property exists today and is kept.

## Risks, and what each is closed by

| Risk | Closed by |
|---|---|
| An array comprehension swallows every reading when one line errors | The `?` in the program. R1 measured it: without the `?`, jq emits nothing and exits 5. |
| The caller is signalled when the guard exits without reading stdin | The consume step in the jq-unavailable branch. R2 measured the writer at exit 141. |
| The new count changes the fallback decision | The count reproduces the digit-prefix quirk. R3 measured the divergence; the positive control shows it is the one shape a naive count gets wrong. |
| The refactor changes the answer somewhere untested | The side-by-side harness, extended with the transcript shapes, run against a baseline pinned to a commit id, with its positive control fired first. |
| The saving is claimed rather than measured | The process-counting rig, executed rather than read, on both transcript shapes and all three configuration counts. |
| A comment explaining a dated incident is lost | An explicit before-and-after inventory of every incident date and named failure mode in the file. |
| The measurement rig silently reads zero | The shim directory carries no drive letter. A `C:/…` entry in the search path splits on its own colon under Git Bash and the shim is never found. |
| The baseline is not a baseline | Every diff and every harness run pins `168edc1` as a commit id. This repository rebase-merges, so a branch name stops being a baseline the moment the work lands. |

## Complexity Tracking

No constitution violations to justify — there is no constitution. No new
projects, dependencies or patterns were introduced. The table is empty by fact,
not by omission.
