# Implementation Plan: The context guard stops counting jq

**Branch**: `014-guard-jq-spawn-count` | **Date**: 2026-09-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/014-guard-jq-spawn-count/spec.md`

## Summary

Two extraction sites in `handoff/hooks/context-guard.sh` each call `jq` once per
field. Both become one call per source, splitting the result in shell. Nothing
else changes: not the validation, not the messages, not the comments, not the
tests.

The split uses the **unit separator**, not a tab. That is not a style
preference — the tab spelling the seed suggests is measured to break the guard
outright. See [research.md](./research.md) Decisions 1 to 3.

## Technical Context

**Language/Version**: Bash, but written in portable shell — the file uses no
`mapfile`, no `readarray`, no `[[ ]]` and no `local`. The one bashism introduced
here is `$'\037'`, chosen deliberately (see Structure Decision).

**Primary Dependencies**: `jq`, already a hard dependency the hook checks for
and reports on. `bats-core` for the suites. `shellcheck` for analysis.

**Storage**: N/A.

**Testing**: `bats-core` from the repository root:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`

**Target Platform**: Linux, macOS and Windows under Git Bash. The Windows shell
is where this change matters most (process spawn is expensive there) and it is
also where both measured hazards live.

**Performance Goals**: helper-process count per guard run on the zero-, one- and
two-configuration-file paths. Two figures, both measured, both recorded:

| | 0 files | 1 file | 2 files |
|---|---|---|---|
| whole run, before | 8 | 12 | 16 |
| whole run, after | 5 | 6 | 7 |
| the seed's slice (before the transcript is read), before | 5 | 9 | 13 |
| the seed's slice, after | 2 | 3 | 4 |

The seed quotes the slice, and its numbers are exactly right. The constant
difference of three is the transcript reading, which this change does not
touch. Quoting only the slice would flatter the result, so both are carried.

**Constraints**:

- Behaviour identical. The hook's own suite must pass **unedited**.
- The suite size is unchanged. Measured at F.5, not read from the seed, which
  says `1..162` and is stale by the test Phase 13 added.
- `handoff/hooks/` is a restricted-vocabulary surface, gated by the suite.
- Every explanatory comment survives uncompressed; every named failure stays
  loud.
- The availability check counts against the budget and is not removed.

**Scale/Scope**: one file changed, plus one changelog entry. Roughly 15 lines
moved and rewritten; a similar number of comment lines added to explain why.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

No constitution is set (`speckit.constitutionSet` false; the owner declined the
offer at pre-flight for the second run running). These gates pass vacuously,
recorded so the absence is visible.

The repository's real constraints are the Constraints list above, checked at F
and again at J.

**Post-design re-check**: unchanged. The design adds no dependency, no surface
and no consent point; it removes process spawns and adds comments.

## Project Structure

### Documentation (this feature)

```text
specs/014-guard-jq-spawn-count/
├── plan.md              # This file
├── spec.md              # The specification
├── research.md          # Phase 0 — the measurements that force the design
├── data-model.md        # Phase 1 — the two extraction shapes, before and after
├── quickstart.md        # Phase 1 — how to reproduce every measurement
├── contracts/
│   └── extraction.md    # Phase 1 — what each extraction must yield
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
handoff/
├── hooks/
│   └── context-guard.sh      # the only production file changed
├── tests/
│   └── context-guard.bats    # NOT EDITED — the tripwire
└── CHANGELOG.md              # gains one `### Changed` entry
```

**Structure Decision**: no new files, one production file touched. The change is
two local rewrites inside a script that keeps its shape.

**On the two bashisms.** `IFS=$'\037'` is not POSIX. The alternative is a
literal unit-separator byte in the source, which is worse: invisible in a diff,
easy for an editor to eat, and it trips tooling that rejects control characters
in input. That hazard is not theoretical — it happened three times while writing
this change, once into the hook itself, because both the editor and GNU `sed`
(whose `\u` is a case operator) silently consumed the escape.

The second is the here-string `<<<`, which replaces a three-line here-document
at each of the two sites. It is free: `$'…'` on the same line already requires
bash, so no portability is spent that was not spent already. Equivalence was
measured across six input shapes, including a path containing a tab, before the
substitution was made.

Both are stated here so the choices read as deliberate rather than as drift.

### Exact insertion points, measured 2026-09-01

| File | Where | What |
|---|---|---|
| `context-guard.sh` | after `input=$(cat)` at `:47`, and after the availability check at `:55` | one `jq` call extracting all four payload fields, joined by the unit separator, captured with `$()` and split with `IFS=$'\037' read -r` |
| `context-guard.sh` | `:89` | the `if` now tests the already-extracted variable instead of calling `jq` |
| `context-guard.sh` | `:93`, `:94` | assignments removed; the variables are already set |
| `context-guard.sh` | `:104` | assignment removed; the configuration-precedence comment above it **stays where it is** — it explains precedence, not extraction |
| `context-guard.sh` | `:134`–`:137` | four `jq` calls become one, split the same way |
| `handoff/CHANGELOG.md` | under the existing `## [Unreleased]` | a `### Changed` entry |

**Ordering note.** The payload extraction must sit **before** the subagent
check, because that check now reads one of its outputs. This costs nothing: on
the subagent path the hook runs the availability check plus one extraction and
exits — two processes, exactly as many as the two it runs today.

## Design decisions

Full evidence in [research.md](./research.md). In brief:

1. **Unit separator, not tab.** Tab is IFS-whitespace, so `read` collapses it
   and an empty leading field shifts everything left. Measured: with the tab
   spelling, a main-session payload makes the hook exit as though it were a
   subagent — the guard would never fire again, silently.
2. **One line, not four.** `jq` emits CRLF on this platform. `$()` strips the
   trailing carriage return; `read` does not. A multi-line design would put a
   stray carriage return on three of four values.
3. **The configuration site has the same bug, and it is quieter.** A shifted
   value there still passes validation, so the guard installs the wrong
   threshold with no error and no failing test.
4. **`tostring` on configuration values.** Unnecessary on the local `jq` and
   kept anyway, because CI runs a different one and this repository has already
   been bitten by exactly that class of version gap.
5. **The availability check stays.** It is what makes a missing `jq` a named
   failure rather than a silent death, and the target number includes it.

## Complexity Tracking

No constitution violations to justify. The table is omitted.
