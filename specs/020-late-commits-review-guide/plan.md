# Implementation Plan: the orchestrator commits late fixes and guides the reviewer

**Branch**: `020-late-commits-review-guide` | **Date**: 2026-09-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/020-late-commits-review-guide/spec.md`

## Summary

Rewrite the back half of the orchestrator document
`pipeline/skills/pipeline/SKILL.md`. In the piece flow, H.5, H.7, I and J each
end with one late commit of their own, recorded with `commit-add` under its
kind; the rule is written once, after H.5. J's carry duty names J's own commit,
and an empty commit carries a waved-through red when J changed nothing. K shows
the whole commit list with each commit's files, commits the remainder only
after the answer, and stops even under `--auto` for a path outside the
feature. L's pull-request body and the DONE summary carry a review guide built
from the state file's `commits`. H.7 and I read the run's whole change; a
re-entry stops when the state file is tracked in git; a plain-string `gates.G`
takes the review answer. Every sentence this makes false elsewhere — the
`--auto` flags row, K's gate row, MAY-do — is rewritten in the same change.
New pins go into `pipeline/tests/prose.bats`, each proven by an inverted
mutant; the pins the contract lists under "Changed on purpose", and the J span, change on purpose. `pipeline/CHANGELOG.md`
adds to `## [Unreleased]`.

## Technical Context

**Language/Version**: Markdown prose read by an agent (the orchestrator); bash for the tests
**Primary Dependencies**: bats 1.11.0 (pinned in CI); the suite's `prose_slice`, `assert_span`, `pins_in`, `rows_in`, `absent_in`; `progress.sh` `commit-add` and `piece-next` (spec 018) as the commands the new prose names
**Storage**: n/a — the prose tells the orchestrator what to write to the run state file (`commits`, `measurements.lateBefore`, `gates.K`, `gates.trackedState`, `gates.G`); see [data-model.md](data-model.md)
**Testing**: `bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests` from the repository root
**Target Platform**: the CI matrix — ubuntu, macOS, Windows (Git Bash)
**Project Type**: prose contract inside a plugin, pinned by grep tests
**Performance Goals**: n/a
**Constraints**: `span_n`, `span_fail` and `span_seed` are not edited; `span_j` changes on purpose (FR-006); K's heading line stays byte-identical (research R2); no line inside a pinned slice may start with `**` or `#`; the pinned left cells of the gate table do not change; no script changes (research R4); documents outside the orchestrator are Phase 22's
**Scale/Scope**: one document, one test file, one changelog

## Constitution Check

*Checked before research and again after design; both pass.*

| Principle | How this plan meets it |
|---|---|
| I. Silence is the failure | A late phase that commits nothing says so (L6). The tracked-state check reads exit 1 as untracked and every other non-zero exit as a hard failure — 128 outside a repository never passes as "untracked" (R4, research R5). A hook rejecting a late commit is a hard stop (L7). |
| II. Measure; never assert | Every touched pin was found by grep (research R1); the detection command, the empty commit, the log shapes and the guide's jq were each run before being written into the plan (R5–R7, data-model). The dry read is measured with `piece-next` and saved (SC-003). The suite count is measured before and after. |
| III. A gate must be shown able to go red | Every new and changed pin is run red under an INVERTED mutant in a scratch tree, the mutated line echoed first, a no-op mutant failing the rig; each absent string is proven by a mutant that restores it. The SC-004 check carries a positive control against the saved original. |
| IV. One implementation | The late-commit rule is written once (after H.5) and H.7, I and J point at it. The late commit reuses H's path-file stage and commit; K's remainder reuses them too; "the run's change" is defined once (H.7) and I points at it. The guide is defined once (L) and DONE rebuilds it "as at L". |
| V. Derive coverage | The guide is built from `commits`, after recording every unrecorded commit in `<base>..HEAD` — never a hand list (research R9). The commit list is read from git. The SC-004 strings and the mutant list are read from the contract, never retyped. No count is written into the spec, plan or contract, except SC-002's dated suite baseline (Principle II's one dated record). |

Surface rules: `pipeline/skills/` and `pipeline/tests/` are RELAXED surfaces.
Changelog: adds to `## [Unreleased]` (opened by Phase 20). Departures: listed
in the contract's "Recorded departures".

## Project Structure

### Documentation (this feature)

```text
specs/020-late-commits-review-guide/
├── spec.md
├── plan.md               # this file
├── research.md           # R1–R14
├── data-model.md         # the state the new prose writes, and the guide's shape
├── quickstart.md         # how to prove it
├── contracts/
│   └── orchestrator-prose.md   # every sentence that must hold, and its pin
├── checklists/
│   └── requirements.md
├── dry-read-017.md       # SC-003, written at implementation
└── tasks.md              # next phase
```

### Source Code (repository root)

```text
pipeline/skills/pipeline/SKILL.md   # H (FR-019), H.5 (late-commit rule), H.7, I, J (span), K, L (guide), DONE, G (plain-string gates.G), Resume (tracked state), Gates (row + conditional stops), Flags (--auto row), Never-bend (MAY-do)
pipeline/tests/prose.bats           # the "Changed on purpose" pins + span_j; new test blocks per story; absent strings
pipeline/CHANGELOG.md               # ## [Unreleased]: ### Added (the review guide), ### Changed (late commits; K's commit list)
```

**Structure Decision**: nothing new is created outside the spec directory. New
pins go in their own `@test` blocks after Phase 20's block, reusing
`prose_slice`, `pins_in`, `rows_in` and `absent_in`.

## Design notes

- **H.5** (FR-001–FR-004, FR-013 support): H.5's first paragraph stays; the
  late-commit rule follows it as plain paragraphs (contract L1–L9): which
  phases, which kinds, the piece flow only, the before list under
  `measurements.lateBefore` (as H's piece list, research R10), the commit
  mechanics shared with H plus a `Late: <phase letter>` line, the
  nothing-changed case, the no-rewrite rule, the hook stop, crash recovery
  (research R12), and H.5's appended heading as its piece (research R3).
- **H.7 and I** (FR-013): "the run's change" is defined once in H.7 as a diff
  from `git merge-base <base> HEAD` to the working tree plus untracked files
  (research R8); I's input names it; both end with their late commit.
- **J** (FR-005, FR-006): the span changes where J's own text changes — the carry
  names J's own commit, the single-commit flow falls to K's commit, and the
  empty commit uses `--allow-empty --only` with no path (research R6); J
  commits once, when its loop ends. `span_j` is regenerated from the file and
  quoted old and new in the commit message.
- **K** (FR-007–FR-010, FR-007b): the heading stays; the body splits by
  whether `<base>..HEAD` holds a commit (research R11), not by flow. With
  commits it shows the commit list read from `git rev-list` and
  `git diff-tree -z` (research R7), then the remainder with its message,
  commits it after the answer as kind `other`, records "nothing to commit",
  and stops even under `--auto` for an odd path (research R11). The
  constitution sentence is kept and now pinned, and its commit is recorded.
- **L and DONE** (FR-011, FR-012): L's body carries the guide, shown in full;
  one paragraph defines the guide — one row per commit in `rev-list` order,
  joined to `commits` by sha, unrecorded commits recorded first as `other`, a
  stale entry a stop (research R9), a heading line, pipes escaped, never
  truncated. DONE rebuilds it.
- **Resume** (FR-014): one paragraph after `validate`: the `ls-files` check,
  run at pre-flight before item 5 and on a B that adopts a state file, the
  three exit readings, the stop that shows every recorded answer, the
  confirmation that never carries over (research R5, R14).
- **H** (FR-019): one sentence after H4b: a spec the owner already committed
  makes no spec commit.
- **G** (FR-015): one sentence after the `gates.G`-is-an-object sentence.
- **Gates and Flags** (research R13): K's row third cell; the
  conditional-stops sentence names both new stops (GT8) and GT9 says `--auto`
  collapses neither; the `--auto` row names both new stops.
- **Never-bend MAY-do**: "spec and piece commits H makes" → "spec, piece and
  late commits the run makes"; "H's local commits" → "the spec, piece and
  late commits" — K's and N's commits are not consented at G.
- **Tests**: see [contracts/orchestrator-prose.md](contracts/orchestrator-prose.md).
  Red first: every new pin is written before the prose and run red against the
  unchanged file, then green, then inverted-mutant red. The Phase 20 run's
  tools (`.delivery-kit/runs/019-orchestrator-builds-in-pieces/`: `contract.py`,
  `build_prose.py`, `build_tests.py`, `minimize_reflow.py`, `mutate.py`) are
  copied into this run's directory and pointed at this contract.

## Complexity Tracking

No constitution violation to justify.
