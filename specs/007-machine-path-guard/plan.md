# Implementation Plan: the machine path leaves the repository

**Branch**: `007-machine-path-guard` | **Date**: 2026-08-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-machine-path-guard/spec.md`

## Summary

Remove the maintainer's account name and one absolute working-directory path
from the tracked tree — 37 lines across 17 files, all currently on the public
default branch — then add the check that would have caught them, then correct
two records that describe a repository which no longer exists.

The technical approach is settled by Phase 0 research and one clarification:

- **Enumerate with `git ls-files`, scan with plain `grep`.** Not `git grep`,
  which exits 1 for a bad path and so cannot distinguish "clean" from "could
  not look" — the distinction the whole suite rests on (research R1).
- **One new pattern variable, separate from the existing denylist**, because
  sharing the new tighter spelling would change what a shipped gate catches as
  a side effect of a scrub (C-gate clarification, research R4).
- **Write the pattern with an exact-bytes file write and prove it landed
  before trusting any result** — the authoring route through a shell heredoc
  silently drops a backslash level and reports every branch dead
  (research R3, and the reason this plan states it three times).

## Technical Context

**Language/Version**: POSIX shell, run under Git Bash on Windows and system
`bash` on the other two platforms. No language runtime is added.

**Primary Dependencies**: `bats-core` 1.11.0 (pinned), `git`, `grep`, `jq`.
All already required by the suite; this feature adds none.

**Storage**: N/A — the feature stores nothing.

**Testing**: `bats`. Full house suite from the repository root:
`bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests`

**Target Platform**: ubuntu-latest, macos-latest, windows-latest — the three the
continuous integration matrix runs. macOS ships BSD `grep`, which constrains the
constructs available (research R5).

**Project Type**: Repository tooling. Two plugins plus a shared root test suite;
this feature touches the root suite and tracked working records only.

**Performance Goals**: None stated. The scan reads 132 tracked files once per
suite run; the slowest matrix job currently takes about two and a half minutes
and this must not move it materially.

**Constraints**:
- No banned shape may be written joined in any file this feature produces —
  they all land inside the scanned surface (FR-021).
- The existing denylist is byte-identical before and after (FR-022, C7).
- The three deliberate elided references are byte-identical before and after
  (FR-008, C3).
- Every scrubbed line differs by a path token and nothing else (FR-007).
- No `SHIPPED_*` list is widened (FR-016).
- No changelog entry (FR-020).

**Scale/Scope**: 37 lines across 17 files scrubbed; 2 checks added; 2 comments
corrected; suite grows 121 → 123.

## Constitution Check

**Status: not applicable — no constitution is set.**

`.specify/memory/constitution.md` is the unfilled template shipped by
`specify init`; the pre-flight probe reported `constitutionSet: false`, the
offer to write one was made to the owner at pre-flight, and it was declined for
this run and recorded under `gates.constitution`.

There are therefore no constitutional gates to evaluate, and none can fail. In
their place, this feature is bound by the repository's own written invariants,
which are enforced by tests rather than by a governance document:

| Invariant | Source | How this feature honours it |
|---|---|---|
| Fail safe, never fail silent | `tests/portability.bats:116-122` | C4: exit 2 fails the check; `-ne 0` is forbidden |
| A control must run the scan's own expression | `tests/portability.bats:30-35` | C5: one variable, referenced twice |
| Registration is explicit; scans never drift silently | `tests/portability.bats:49-56` | FR-016: no list widened; the new scan enumerates rather than registers |
| Portable constructs only | `tests/portability.bats:123-129` | R5, C8: `-w` never the GNU escape |
| Records are evidence, not prose | Campaign ruling 10 | FR-007: token substitution only |

**Re-check after Phase 1 design: passes.** The design adds one variable, two
checks and one enumeration, all inside the file that already owns this
responsibility. It introduces no new file, no new dependency and no new
registration list.

## Project Structure

### Documentation (this feature)

```text
specs/007-machine-path-guard/
├── plan.md                    # This file
├── spec.md                    # Phase B, clarified at C, corrected at C.5
├── research.md                # Phase 0 — six measured findings
├── data-model.md              # Phase 1 — the shell values and their edges
├── quickstart.md              # Phase 1 — eleven runnable validation blocks
├── contracts/
│   └── scan-contract.md       # Phase 1 — the eight observable guarantees
├── checklists/
│   └── requirements.md        # Spec quality checklist, 16/16
└── tasks.md                   # Phase E output, not created here
```

### Source (repository root)

```text
tests/
└── portability.bats           # +1 pattern variable, +2 checks, 1 comment corrected

main-plan.md                   # 3 lines scrubbed, 1 ruling amended
specs/001-pipeline-101-polish/ # 6 lines scrubbed across 4 files
specs/002-constitution-probe/  # 6 lines scrubbed across 3 files
specs/003-implementer-handoff/ # 4 lines scrubbed across 3 files
specs/004-implementer-key/     # 3 lines scrubbed across 2 files
specs/005-verify-iters-cap/    # 3 lines scrubbed across 2 files
specs/006-release-1-1-0/       # 12 lines scrubbed across 2 files
```

**Structure Decision**: no new files in the source tree. The scan belongs in
`tests/portability.bats` because that file already owns "what must not appear in
this repository", already holds the denylist the new pattern sits beside, and is
already excluded from the new scan by construction — which is the only place a
pattern can be written joined without becoming its own violation. A separate
suite would need its own exclusion, its own registration, and would put the two
path denylists in different files, making the drift this feature already accepts
strictly worse.

## Implementation order

The order is not cosmetic. Two of these steps prove things that cannot be
proven once the previous step has landed.

1. **Measure the "before" and record it.** Run the four scans and their
   controls; capture `35 / 1 / 0 / 1`. After step 4 this is unobtainable.
2. **Write the pattern variable and the two checks.** Exact-bytes file write.
   Prove what landed with `cat -A` on the pattern line before running anything.
3. **Watch the scan FAIL against the un-scrubbed tree** (SC-010). The paths are
   still there, so a correct scan must be red here. A scan that is green at this
   point is broken, and every later green means nothing. Record the output.
4. **Scrub the 37 lines.** Token substitution only; `git diff` reviewed line by
   line against FR-007.
5. **Watch the scan turn green**, and the control stay green.
6. **Correct the two records** — the stale comment and the amended ruling.
7. **Full suite from the repository root**: `1..123`.
8. **Execute the quickstart**, every block, in order. Do not read it — run it.

Steps 1 and 3 are the ones a hurried implementer skips, and they are the two
that distinguish this from a scrub with a decoration attached.

## Complexity Tracking

No constitution gates exist, so no violations require justification. One
accepted cost is recorded here because it is a genuine complexity the design
chose deliberately rather than avoided:

| Cost | Why accepted | Alternative rejected because |
|---|---|---|
| Two hand-maintained path denylists that can drift | Sharing one list would change what the existing installed-surface checks catch — a behaviour change to a shipped gate, made as a side effect of a scrub | Answered at the C gate. Mitigated by a cross-referencing comment in each (FR-022), which is a prompt, not a mechanism, and is recorded as such in the spec's accepted risks |
