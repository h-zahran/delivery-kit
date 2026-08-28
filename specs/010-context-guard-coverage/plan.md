# Implementation Plan: context-guard.sh coverage and a config fixture helper

**Branch**: `010-context-guard-coverage` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-context-guard-coverage/spec.md`

## Summary

Seven paths through the context guard have never executed under test — two of
them run for every real user and for no test at all. Each gets exactly one test,
watched failing first. Separately, twenty-six configuration-fixture writes
collapse into one helper — three others cannot and stay as they are — and a
four-site byte-cap idiom collapses into a second helper.

**The hook is not modified.** A later phase owns it.

All seven behaviours were driven and observed before this plan was written, each
with a control that fires the other way. Everything is in
[research.md](./research.md); nothing here is re-derived.

The house suite goes from **`1..147`** to **`1..154`**. Only
`handoff/tests/context-guard.bats` grows.

## Technical Context

**Language/Version**: POSIX shell and `bash`; the suites are `bats` files.

**Primary Dependencies**: `bats` 1.5.0+, and `jq`, which the guard requires and
degrades loudly without. **No new dependency.**

**Storage**: N/A. Fixtures are small files written into per-test temporary
directories.

**Testing**: the house suite, from the repository root:

```
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

**Target Platform**: Git Bash on Windows and the GitHub-hosted runners. Both
must pass.

**Project Type**: A Claude Code plugin marketplace. No application source tree.

**Performance Goals**: None set. Worth stating, because Phase 9 nearly doubled
one suite's runtime with process-heavy tests: these tests spawn the guard a
handful of times each and build no shim directories, so the same cost is not
expected here. It will be **measured, not assumed** — see Implementation order.

**Constraints**:

- **`handoff/hooks/context-guard.sh` must not change.** Its diff must be empty
  (FR-015, SC-007).
- **No changelog entry** (FR-016, SC-008).
- **`handoff/tests/` is a registered STRICT-vocabulary surface.** This is
  tighter than Phase 9's ground: those fixtures lived under `pipeline/tests`,
  which is relaxed. A banned term pasted into a fixture here ships to every
  install (FR-017, SC-012).
- **Every reference is anchored to content, never a line number** (FR-018).
  Three of the seed's eight had already drifted.
- **No machine-specific absolute path** in any file this feature writes.

**Scale/Scope**: One suite file, one shared helper file, seven new tests,
twenty-six converted sites, three deliberately unconverted, four converted
byte-cap sites. No production code.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template. The offer was
made once and **declined**, with a standing scope covering phases 8 to 16;
Phase 10 is inside it, and the recorded answer was read rather than re-asked.

**No constitutional gates to evaluate.** In their place, the repository's own
standing invariants:

| Invariant | How this feature honours it | Enforced by |
|---|---|---|
| A test is watched failing before it is trusted | All seven, by **inverting** the operative assertion and echoing the altered line back | SC-002; Phase H |
| A search reporting zero must first prove it can report one | Every ad-hoc scan fires a control | SC-011 |
| A silent success is not evidence | Every one of these behaviours exits 0; each test asserts on an observable, never on status alone | research.md §3 |
| No machine-specific path enters the tree | Needles built inside `awk` from character codes | `tests/portability.bats`, quickstart Block 8 |
| The strict vocabulary is not widened | New fixtures live in a strict surface and are scanned as such | `tests/portability.bats`, SC-012 |

**Result: PASS.** No violation; Complexity Tracking is empty.

**Post-design re-check**: PASS. The design adds two helper functions and seven
tests. No new dependency, no new directory, no change to any shipped surface.

## Project Structure

### Documentation (this feature)

```text
specs/010-context-guard-coverage/
├── spec.md
├── checklists/requirements.md
├── research.md                       # every behaviour measured, with controls
├── plan.md                           # this file
├── data-model.md
├── quickstart.md
├── contracts/
│   └── fixture-helper-contract.md
└── tasks.md                          # Phase E
```

### Source Code (repository root)

```text
tests/
└── helper.bash                       # MODIFIED — gains write_config and bytes_of

handoff/
├── hooks/
│   └── context-guard.sh              # READ ONLY — must not change (FR-015)
└── tests/
    └── context-guard.bats            # MODIFIED — +7 tests; 26 + 4 sites converted
```

**Structure Decision**: Both helpers go in `tests/helper.bash` because FR-010
names the file every suite loads, and because Phase 9 already established
`PIPELINE`, `PROBE` and `BASH_ABS` there — the file is the agreed home for
cross-suite fixtures. **No new fixture directory is created**: every one of
these seven tests builds what it needs in its own temporary directory, so
nothing new enters the strict-vocabulary surface as a tracked fixture.

## The seven tests

| # | FR | What it proves | Its control |
|---|---|---|---|
| 1 | FR-001 | The guard falls back to its own working directory when the payload carries none | run from a directory with **no** configuration → silent |
| 2 | FR-002 | It finds configuration at a repository root from **two levels** down | the same shape with **no repository** → silent |
| 3 | FR-004 | The seven-day sweep removes flags past the threshold, across all three swept name patterns | a **seven-day** flag, a fresh flag, an unnamed aged file and an aged directory all survive the same run |
| 4 | FR-005 | A transcript yielding no readings exits quietly | — |
| 5 | FR-006 | A payload with no session identifier still works | the flag is named for the **placeholder** |
| 6 | FR-007 | The proportional threshold override changes behaviour | 99% → silent, 1% → warns |
| 7 | FR-008 | The absolute threshold override changes behaviour | 999,999 → silent, 50,000 → warns |

FR-003 and FR-009 are **not tests**. They are properties tests 1–2 and 6–7 must
carry.

### The five traps these tests must not fall into

Each is measured, not anticipated; all are in research.md.

1. **The sweep only runs after a warning fires.** It sits past the firing
   decision. A test that ages a file and runs the guard without crossing a
   threshold observes nothing and would assert "nothing happened" — passing for
   the wrong reason.
2. **The absolute-threshold test must pin the proportional one at 99%.** Left at
   its default, the proportional threshold fires first at 90% and the absolute
   setting does nothing, while the test still goes green.
3. **The two override tests must assert on the message wording.** The two paths
   word their reason differently — one as a percentage of the window, one as a
   token count past a token threshold. "Something warned" does not say which
   fired.
4. **The missing-identifier test must assert on the flag file's name.** The
   placeholder is otherwise invisible, and "did not crash" is nearly
   unfalsifiable.
5. **The configuration-discovery tests need a valid transcript.** Their payload
   omits the working directory but must keep everything else, or it dies at the
   earlier gate and passes silently for the wrong reason. **The warning itself
   is the proof of arrival** — a payload that died at the gate cannot produce
   one. That is how FR-003 is discharged, and it is worth saying because a
   reader may expect a separate assertion.

## The helpers

Full interface, rationale and rejected alternatives:
[contracts/fixture-helper-contract.md](./contracts/fixture-helper-contract.md).

Both parameters of `write_config` are required **by measurement**:

- **The path**, because 4 of the convertible sites write the **user** configuration file,
  not the repository one — they are the precedence test, and a hardcoded path
  could not express them.
- **The body**, because there are **19 distinct bodies**, several deliberately
  invalid to exercise the validator. A helper that rebuilt the body would repair
  exactly the inputs those tests exist to reject.

Its output is **byte-identical** to the literal it replaces, verified with `cmp`.

`bytes_of` has four call sites and this plan says four.

## Implementation order

1. **The two helpers**, in `tests/helper.bash`. Nothing consumes them yet.
   **Checkpoint: the suite still reports `1..147`.**
2. **Convert the 27 configuration sites and the 4 byte-cap sites**, mechanically.
   **Checkpoint: still `1..147`, and this suite's own count unmoved.** This is
   what makes every later red attributable to a new test.
3. **The seven tests, one at a time**, each watched failing first by inverting
   its operative assertion, with the altered line echoed back, then restored and
   watched green.
4. **The whole suite from the repository root: `1..154`.**
5. **Measure this suite's runtime before and after.** Phase 9 nearly doubled one
   suite's; this plan claims the same will not happen here, and a claim about
   performance is worth what its measurement is worth.

Step 2's checkpoint is not optional. Without it a red in step 3 has two possible
causes.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. Intentionally empty.
