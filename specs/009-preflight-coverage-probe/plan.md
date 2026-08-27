# Implementation Plan: preflight.sh coverage and a probe helper

**Branch**: `009-preflight-coverage-probe` | **Date**: 2026-08-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-preflight-coverage-probe/spec.md`

## Summary

Thirteen behaviours of `pipeline/scripts/preflight.sh` are reachable but
untested: four ways it refuses, four conditions it warns about and continues
past, two announced degradations, one base-branch route, and two edges of the
governance-file parser. Each gets exactly one test, watched failing before it is
trusted. Separately, the twenty-four near-identical probe invocations in
`pipeline/tests/preflight.bats` collapse into one named helper in
`tests/helper.bash`.

**The probed script is not modified.** This feature reads it.

All thirteen behaviours were driven and observed before this plan was written;
every fixture shape needed to reach them is recorded in
[research.md](./research.md). Nothing here is re-derived.

`pipeline/tests/preflight.bats` goes from **20 to 33** tests; the house suite
goes from **`1..134`** to **`1..147`**. No other suite's count moves.

## Technical Context

**Language/Version**: POSIX shell and `bash` (the probed script is `bash`; the
suites are `bats` files). No compiled language is involved.

**Primary Dependencies**: `bats` 1.5.0 or later (`bats_require_minimum_version
1.5.0` is already asserted by the suite), and the six external commands the
probe itself invokes — `awk`, `git`, `grep`, `head`, `jq`, `od`. **No new
dependency is introduced.**

**Storage**: N/A. Fixtures are directories of small files on disk.

**Testing**: the house suite, run from the repository root:

```
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

**Target Platform**: Git Bash on Windows (the development machine) and the
GitHub-hosted Linux runners. **Both must pass.** Several of these behaviours are
constructed by making a program unfindable, and the two platforms disagree about
which programs are ambient — see Constraints.

**Project Type**: A Claude Code plugin marketplace. Shell scripts, hook scripts
and `bats` suites; no application source tree.

**Performance Goals**: The conversion removes no process spawns by itself, but it
makes the count visible in one place. The per-test timeout of 60 s set in
`tests/helper.bash` is unchanged and is not approached: the new tests are probe
invocations and small `git init` calls.

**Constraints**:

- **The probed script must not change.** Its diff must be empty at the end
  (FR-021, SC-006).
- **No changelog entry** (FR-022, SC-007).
- **No machine-specific absolute path in any file this feature writes**, and the
  tracked-tree scan covers this feature's own documents.
- **Every reference is anchored to content, never to a line number** (FR-024).
  Two earlier phases in this campaign shipped seeds whose line numbers had
  already moved.
- **The ambient environment cannot be trusted for tool presence.** The
  command-line client is a shim Git Bash cannot see but every runner has; the
  device tool is the reverse. A test that reads the ambient environment passes
  on one platform and fails on the other, or — worse — passes on both for
  different reasons. Every such test constructs its own search path.

**Scale/Scope**: One suite file, one shared helper file, six new fixture trees,
thirteen new tests, twenty-four converted call sites. No production code.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` **is still the unfilled template a fresh init
writes.** Its principle names and descriptions are the shipped placeholder
tokens. The probe reports `constitutionSet: false` against it, correctly.

The constitution offer was made once and **declined**, with a standing scope
covering the whole of Campaign 2 (phases 8 to 16). That answer is recorded in
this run's state file and was read rather than re-asked.

**There are therefore no constitutional gates to evaluate.** In their place this
plan is checked against the repository's own standing invariants, which are
enforced by the suite rather than by a document:

| Invariant | How this feature honours it | Enforced by |
|---|---|---|
| A test must be watched failing before it is trusted | Every one of the thirteen is red-first, by **inverting** its operative assertion and echoing the altered line back — never by deleting the test | SC-002; Phase H procedure below |
| A search that reports zero must first prove it can report one | Every ad-hoc scan fires a control that must match before any zero is believed | SC-011 |
| No machine-specific path enters the tracked tree | Scanned with needles built inside `awk`, so no backslash crosses a shell, an argv, a heredoc or a file write | `tests/portability.bats` and this feature's own scans |
| A verification block must be able to go red | Every quickstart block carries its own exit status and is run separately | quickstart.md, and the decoy drill in it |
| The public tree discloses nothing private | No new path outside `pipeline/tests/`, `tests/` and this feature's spec directory | `tests/layout.bats`, `tests/portability.bats` |

**Result: PASS.** No violation, so Complexity Tracking below is empty.

**Post-design re-check**: PASS. The Phase 1 design adds one helper function, two
shared variables and six fixture trees. It introduces no new dependency, no new
top-level directory and no change to any shipped surface.

## Project Structure

### Documentation (this feature)

```text
specs/009-preflight-coverage-probe/
├── spec.md                        # Phase B, amended at C.5
├── checklists/requirements.md     # Phase B
├── research.md                    # Phase D — every behaviour measured
├── plan.md                        # This file
├── data-model.md                  # Phase D
├── quickstart.md                  # Phase D
├── contracts/
│   └── probe-helper-contract.md   # Phase D
└── tasks.md                       # Phase E — not created here
```

### Source Code (repository root)

This repository has no application source tree. The real paths this feature
touches are:

```text
tests/
└── helper.bash                    # MODIFIED — gains PIPELINE, PROBE, BASH_ABS
                                   #   and the one `probe` helper (FR-017)

pipeline/
├── scripts/
│   └── preflight.sh               # READ ONLY — must not change (FR-021)
└── tests/
    ├── preflight.bats             # MODIFIED — 20 tests -> 33; 24 call sites converted
    └── fixtures/                  # 6 NEW trees, all tracked
        ├── speckit-no-version/    #   init-options with a flavour and no version
        ├── speckit-no-flavour/    #   init-options with a version and no flavour
        ├── foreign-agent/         #   .agents/skills/speckit-* and no local form
        ├── constitution-nul/      #   a NUL byte in the head of the document
        ├── constitution-bom/      #   a byte-order mark then whitespace only
        └── constitution-unclosed/ #   a comment opened and never closed
```

**Structure Decision**: The helper lives in `tests/helper.bash` because FR-017
requires it to live in the file every suite loads, and because that file already
holds the repository-root resolution (`ROOT`) the helper needs. The convention it
follows is already there: `HANDOFF` and `HOOK` are derived from `ROOT` at load
time, and that file's own comment anticipates a `PIPELINE` beside them.

New fixtures go under `pipeline/tests/fixtures/` because the tracked ignore rules
re-include that tree wholesale (FR-023). This was checked with controls in both
directions, **including the new `.agents/` shape** — see research.md §6. No
ignore rule needs to change.

## The thirteen tests

One requirement, one test. The arithmetic is stated in the spec and is not
restated differently here.

| # | FR | What it proves | How it is reached |
|---|---|---|---|
| 1 | FR-001 | An unrecognised argument is refused, and the message names it and lists the legal ones | an unknown flag, no fixture needed |
| 2 | FR-002 | A flag supplied without its value is refused, naming what the flag needed | the directory flag with nothing after it |
| 3 | FR-003 | A directory that cannot be entered is refused, naming the directory | a path that does not exist |
| 4 | FR-004 | The required data tool absent is refused **by name** | search path set to an empty directory |
| 5 | FR-005 | An empty recorded version warns, the run succeeds, the data stream still parses | fixture `speckit-no-version` |
| 6 | FR-006 | The same for an empty recorded flavour | fixture `speckit-no-flavour` |
| 7 | FR-007 | A foreign agent's skills directory produces the warning **and** an invocation form of `none`, in one run | fixture `foreign-agent` |
| 8 | FR-008 | A governance file in an unreadable encoding warns and reads as not carrying principles | fixture `constitution-nul` |
| 9 | FR-011 | The runtime-check phase is announced skipped when a mobile project has no device tool, with the tool named | the mobile fixture + a shim search path |
| 10 | FR-012 | The review phase is announced skipped for **both** causes — one test | two scratch repositories + shim search paths, plus a negative control |
| 11 | FR-013 | The base-branch fallback reports the current branch and names the fallback | a scratch repository, **one commit**, no override |
| 12 | FR-014 | A byte-order mark is stripped before the file is judged | fixture `constitution-bom` |
| 13 | FR-015 | A comment opened and never closed does not swallow the rest of the file | fixture `constitution-unclosed` |

FR-009 and FR-010 are not separate tests. They are **properties every one of
tests 5 to 8 must carry**: assert on the diagnostic stream's content, never on
exit status alone, and confirm the data stream still parses whole.

### The four traps these tests must not fall into

Each is measured, not anticipated. All four are recorded with their evidence in
research.md.

1. **Test 11 needs a commit.** On an unborn branch the fallback reports the
   literal string `HEAD`, because the command it uses exits 128 and prints
   `HEAD` on stdout while the script discards the status. Without a commit the
   test passes its source assertion while the branch name means nothing.
2. **Test 10's first cause is environment-dependent unless forced.** The
   command-line client reads absent on the development machine and present on
   every runner. A non-GitHub remote alone therefore passes here for the *other*
   cause. The test puts a client shim on the search path first, so the cause it
   names is the cause that fires. A negative control — client present *and* a
   GitHub remote — must produce an empty skip list.
3. **Test 12's fixture must be a mark followed by nothing but whitespace.** A
   mark followed by a real constitution reads as set with or without the
   stripping, so that fixture proves nothing.
4. **Test 2 must not assert on the line number or the script path.** That
   message comes from the shell's own parameter expansion, not from the script's
   diagnostic function. It asserts on the substring the script chose.

### And the one that must NOT be written

**FR-016**: no test for the multi-line comment case. It is already pinned — the
existing fixture opens with such a comment carrying a bracketed token, and the
existing test *constitutionSet is true once the constitution carries real
principles* goes red when the multi-line stripping is broken. That was measured,
not assumed, because the seed warns that a previous review got it wrong. A
fourteenth test here would also break the stated arithmetic.

## The helper

The full interface, its rationale and its rejected alternatives are in
[contracts/probe-helper-contract.md](./contracts/probe-helper-contract.md). In
summary:

- **One function, `probe`**, in `tests/helper.bash`. It is a thin pass-through:
  it supplies the `run` invocation and the script path, and nothing else. Every
  caller writes its own arguments, fixture included — so FR-020 holds by
  construction and FR-019's conversion is a straight substitution.
- **One optional leading option, `--path <dir>`**, gives the probe a search path
  of exactly `<dir>`. It cannot collide with a probe flag: the probe's legal
  flags are the directory, the project-type and the base-branch, and it refuses
  anything else by name.
- **`run` stays at the caller's level inside the function** — measured to set
  the status, the data capture and the diagnostic capture for the calling test.
  A subshell would lose all three, which is why the previously recorded subshell
  technique is **not** used.
- **The invocation appears exactly once**, as the helper's body, which is what
  SC-004 asks for.

## Implementation order

The order matters: the helper must exist and be proven before twenty-four call
sites depend on it, and the fixtures must exist before the tests that read them.

1. **The helper and its shared variables**, in `tests/helper.bash`. Nothing
   consumes it yet.
2. **Convert the twenty-four existing call sites**, mechanically. Run the suite.
   **It must still report `1..134` with 20 tests in this suite** — the
   conversion changes no count and no assertion. This is the checkpoint that
   makes every later red attributable to a new test rather than to the
   conversion.
3. **The six fixture trees.** No test reads them yet. Confirm each is tracked
   (`git check-ignore` with controls) and that the two byte-exact ones are
   byte-identical to what was intended.
4. **The thirteen tests, added one at a time**, each watched failing first by
   inverting its operative assertion, with the altered line echoed back before
   the red is believed, then restored and watched green.
5. **The whole suite from the repository root.** `1..147`.

Step 2's checkpoint is not optional. Without it, a red in step 4 has two
possible causes and the run has to bisect to find out which.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. This table is intentionally empty.
