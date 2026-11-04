# Feature Specification: Close the five pipeline gaps

**Feature Branch**: `058-five-pipeline-gaps`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "Read docs/plans/2026-11-04-speed-and-gaps-seeds.md first. Its section 'Run 2' is the seed: fix the five gaps." The seed is saved verbatim at `.delivery-kit/runs/058-five-pipeline-gaps/seed.md`.

## Clarifications

### Session 2026-11-04

- Q: What should the run do in phase B when no test command is recorded? → A: Stop and ask. The owner gives a command, or says go on with none; F.5, J and N then say no suite ran. `--auto` does not collapse the stop.
- Q: Who should work out the test command and its layer for the new probe line? → A: The orchestrator, as for the Implementer line. `preflight.sh` reads no configuration file.
- Q: What should `branch-cut` do when the branch already exists and HEAD is on another branch? → A: Switch only when the base is the branch's ancestor; otherwise refuse and name both.
- Q: Should this run also stop pre-flight from typing tracked values into a shell? → A: Yes. `preflight.sh` takes tracked trailers and a tracked `baseBranchOverride` from a JSON file, with all its checks kept.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A base suite that cannot start says so with its own status (Priority: P1)

A pipeline run reaches phase B with no usable test command in its state file. Today the start command prints one line and exits 0, the same status as a legal "not started". The orchestrator can pass over it, and this is how run 056's ordering fault stayed hidden. The owner wants a status that nobody can read as success.

**Why this priority**: Silence is the failure the constitution ranks first (Principle I).

**Independent Test**: In a repository fixture, remove the test command from the state file, run the start command, and test the exact exit status. Then run each legal "not started" case and test that each still exits 0.

**Acceptance Scenarios**:

1. **Given** a state file whose `config.testCommand` is absent, null, empty or not a string, **When** the start command runs, **Then** it prints the reason on one line, starts nothing, makes no bookkeeping folder, and exits with a status that no other start outcome uses.
2. **Given** `suiteReuse` is `off`, or a green result is already recorded for the base files, or the run was abandoned, **When** the start command runs, **Then** it prints its "not started" line and exits 0.
3. **Given** the distinct status, **When** phase B reads it, **Then** the skill's text says what the run does next, and the old sentence "An exit 1 is printed too and does not stop the run" no longer describes this case.

---

### User Story 2 - The owner sees the test command before it runs (Priority: P1)

A tracked `testCommand` starts in the background in phase B, before the first human stop. A repository just cloned can name any command there. The owner wants the command and the layer that set it on the screen before it runs.

**Why this priority**: It is the only thing the run executes from a tracked file before anyone answers a question.

**Independent Test**: Read the probe block rule and its layer rule. Run the start command on a fixture whose state file records a layer, and read the layer in its `started` line.

**Acceptance Scenarios**:

1. **Given** a fresh run whose test command resolves to a value, **When** pre-flight renders the probe block, **Then** the block has a line with the exact command and the layer that won.
2. **Given** a fresh run whose test command resolves to nothing, **When** pre-flight renders the probe block, **Then** that line says no test command resolved.
3. **Given** a resumed run, **When** the probe block is rendered from the state file, **Then** the line shows the recorded command and the recorded layer.
4. **Given** a state file that records the layer, **When** the start command starts the suite, **Then** its `started` line names the command and the layer.

---

### User Story 3 - A resume crosses the branch cut safely (Priority: P1)

A run stops after it cut its feature branch and re-enters phase B. A second `git checkout -b` exits 128, and no text says what to do. The owner wants one command that is safe to run again, as `init` is.

**Why this priority**: A resume into B fails today on a real command, and the replacement text saves bytes that gaps 1 and 2 need.

**Independent Test**: In a repository fixture, run the new command three ways: no branch yet, on the branch already, and branch present with HEAD elsewhere. Test the exit status, the current branch and the commit the branch names after each.

**Acceptance Scenarios**:

1. **Given** the recorded branch does not exist, **When** the command runs, **Then** the branch is created from the recorded base, uncommitted spec files stay in the tree, and it prints one line.
2. **Given** HEAD is already on the recorded branch, **When** the command runs again, **Then** nothing changes, it prints one line that says so, and it exits 0.
3. **Given** the recorded branch exists and HEAD is elsewhere, **When** the command runs, **Then** it switches to the branch when the base is an ancestor of that branch, and otherwise refuses and names both.
4. **Given** any case, **When** the command runs, **Then** it never deletes a branch, never moves a branch's commit, and never discards uncommitted work.

---

### User Story 4 - A region test reads only its region (Priority: P2)

A prose test takes a slice of a document between two boundaries. Today the slice also holds the closing boundary's line, so text placed on the next section's first line satisfies a test that claims to read one section. Run 056 measured this with a mutant.

**Why this priority**: It makes every region pin honest, but no shipped behaviour changes.

**Independent Test**: Run the 056 mutant again: remove the instructions from phase B and place them on the phase C line. The test goes red. Run the helper's own fixtures for the default and for the opt-in.

**Acceptance Scenarios**:

1. **Given** a caller that does not opt in, **When** it takes a slice, **Then** the slice is byte-identical to today's, closing line included.
2. **Given** a caller that opts in, **When** it takes a slice, **Then** the closing line is absent, and every guard still fires on the same document faults.
3. **Given** a slice that holds only its boundary line once the closing line is dropped, **When** a caller opts in, **Then** the helper refuses rather than return an empty slice.
4. **Given** the audit list below, **When** the work is done, **Then** each of the 14 tests is recorded with its verdict: switched, or kept on the default with the reason.

---

### User Story 5 - A JSON value travels through a file (Priority: P2)

The run records JSON with a shell command. A value between single quotes breaks on an apostrophe, and `'$(...)` in it runs code. Trailers and commands can come from a tracked file. The owner wants a way to pass the JSON that no shell reads.

**Why this priority**: The documented command runs a tracked file's text through a shell.

**Independent Test**: Write a file that holds a list with an apostrophe and `$(touch marker)`. Pass it with the new option. Read back the stored value byte for byte and check that `marker` does not exist.

**Acceptance Scenarios**:

1. **Given** a file that holds one JSON document, **When** `state-set` takes that file, **Then** the stored value equals the document, under the same key checks, type checks and `gates.pending` guard as the inline form.
2. **Given** a missing file, a folder, an empty file, or a file that holds two documents or bad JSON, **When** `state-set` takes that file, **Then** it refuses, writes nothing, and exits non-zero.
3. **Given** `pipeline/docs/configuration.md`, **When** it describes the trailer record, **Then** it uses the file form.
4. **Given** the inline form, **When** a caller uses it, **Then** it behaves as today.
5. **Given** a values file that holds a trailer with `'$(touch marker)`, **When** `preflight.sh` takes that file, **Then** the trailer check refuses it by name, no shell has read the value, and `marker` does not exist.
6. **Given** a values file that holds legal trailers and a legal override, **When** `preflight.sh` takes that file, **Then** its report is byte-identical to a report from the same values typed as flags.

---

### Edge Cases

- `suite-base start` run a second time after a first exit 3: nothing was started, so it checks again, and it starts when the test command is now recorded.
- The new branch command on a detached HEAD: treated as "HEAD elsewhere".
- The recorded branch is checked out in another worktree, or the switch would overwrite uncommitted files: git refuses, and the command exits non-zero, names the reason, and changes nothing.
- The recorded base branch no longer exists: the command refuses when it would need to create or test against it. When HEAD is already on the recorded branch, no check of the base is needed.
- A state file with an empty `branch` or `baseBranch`: the command refuses. It never guesses a name.
- A value `git` reads as an option (leading dash): the command refuses it, as `init`'s fixed-position arguments are not checked.
- An opt-in slice whose closing boundary is also the opening line: refused, as above.
- A JSON file with a byte-order mark or carriage returns: jq decides, and its refusal stops the write. A file with a trailing line feed is one document.
- A JSON file larger than a single command-line argument can hold: it fails loudly and writes nothing.
- The probe line's command text is data, and it can hold terminal escapes from a tracked file. So the line shows it JSON-quoted, as the `started` line does, without running or expanding it.

## Requirements *(mandatory)*

### Functional Requirements

**Gap 1: the base suite's status**

- **FR-001**: `suite-base <feature> start` MUST exit with status 3 when `config.testCommand` is not recorded as a non-empty string, and MUST print its existing reason line on stdout. Status 3 MUST mean this case only among the start's outcomes, together with FR-002's.
- **FR-002**: `suite-base <feature> start` MUST treat an `artifacts.spec` that names no existing spec file as the same class: phase B records it just before the start, so its absence is the same ordering fault. It MUST exit 3 with its existing line.
- **FR-003**: Every other "not started" line MUST keep exit 0, and each MUST be covered by a test of the exact status: run abandoned; `suiteReuse` off; `suiteReuse` any other value; a green result already recorded; a spec file at the top level, under the state directory or outside the repository; an index entry hidden from `git status`; an unmerged path, a submodule or a nested repository; HEAD with no commit; `TMPDIR` inside the work tree; base files that differ; and "already started".
- **FR-004**: Exit 1 MUST keep its meaning: a check could not be made. It prints, and it does not stop the run.
- **FR-005**: The stale comment above `base_start` (`pipeline/scripts/progress.sh:2798`) MUST state the three statuses, and phase B's prose and the docs in `pipeline/docs/phases.md` MUST say what the run does on status 3.
- **FR-006**: On status 3 phase B MUST stop and ask, as a conditional stop that `--auto` does not collapse. The owner gives a command, which the run records with its layer before it runs the start again, or says to go on with none. A "go on" is recorded under `gates`, and F.5, J and N then report that no suite ran; they never report a pass. The rule lives in `pipeline/docs/rare-paths.md`, with a one-sentence pointer in the skill.

**Gap 2: show the command before it runs**

- **FR-007**: The probe block MUST carry a `Test command` line on every fresh run and every re-entry. The orchestrator renders it from the RESOLVED configuration, as the Implementer line is rendered. `preflight.sh` still reads no configuration file.
- **FR-008**: The line MUST name the layer that won: `~/.delivery-kit.json`, the repository's `.delivery-kit.json`, `--config`, or `project type` for a value worked out from the detected type. When nothing resolves, the line MUST say so.
- **FR-009**: Phase B MUST record that layer as `config.testCommandFrom` with `config`, so a resume prints the recorded command and layer and never re-resolves.
- **FR-010**: The `started` line of `suite-base start` MUST also name `config.testCommandFrom` when the state file records it.
- **FR-011**: The rule MUST live in `pipeline/docs/configuration.md`, in the section beside "The Implementer line", and the skill's probe block MUST hold the one line and a pointer.

**Gap 3: the branch cut**

- **FR-012**: `progress.sh` MUST gain a subcommand, `branch-cut <feature>`, that reads `branch` and `baseBranch` from the state file. It takes no branch name as an argument.
- **FR-013**: `branch-cut` MUST create the branch from the base when the branch is absent, MUST do nothing and exit 0 when HEAD is on it, and MUST switch to it when it exists elsewhere and the base is its ancestor. Otherwise it MUST refuse, name both, and change nothing. Each outcome prints one line on stdout.
- **FR-014**: `branch-cut` MUST never use a destructive form: no `-B`, no `--force`, no delete, no reset, no move of a branch's commit. It MUST keep uncommitted work in the tree, or refuse.
- **FR-015**: `branch-cut` MUST be refused on an abandoned run, as other writing commands are, and MUST join the usage list.
- **FR-016**: Phase B's text MUST use `branch-cut` in place of its branch sentence. The saved bytes pay for gaps 1 and 2.

**Gap 4: `prose_slice`**

- **FR-017**: `prose_slice` MUST keep today's default: the slice includes the closing line, byte for byte. Test 20's fixture still records it.
- **FR-018**: `prose_slice` MUST gain an opt-in that drops the closing line after all guards have read the whole slice, so no guard's reach changes. A slice left empty MUST be refused with its own message.
- **FR-019**: Every caller that means "inside this region" MUST switch to the opt-in, by a script that refuses to write unless its counts match. A caller left on the default MUST carry a one-line reason. The 056 test MUST drop its hand-written cut at the closing heading.
- **FR-020**: Each of the 14 tests below MUST get a recorded verdict. Where a test passes only because of the closing line, the audit MUST decide whether its boundary moves (the text belongs in its region) or whether it keeps the default (the closing line is part of what it pins).

The audit list, named from a run of `pipeline/tests/prose.bats` on `126f045` (2026-11-04), because the numbers move when a test is added:

| No. on `126f045` | Test |
|---|---|
| 20 | a declared inner line is admitted, and admits nothing else |
| 39 | the seed-form rule never falls through to a verbatim description |
| 40 | a failed phase rolls nothing back, keeps its place and drops the lock |
| 41 | phase J carries a waved-through red into everything that leaves the machine |
| 42 | phase N is degraded but never skipped, and never re-owns an accepted red |
| 43 | F.5, J and N reuse only a green suite result for identical files |
| 44 | every red-flag row is pinned, and every pinned row is still there |
| 56 | late phases commit their own work, each under its kind |
| 59 | K shows the commit list and stops for a path outside the feature |
| 61 | the review guide is in the PR body and the DONE summary |
| 69 | phase F ends after a round with no CRITICAL or HIGH finding, and narrows later rounds |
| 98 | each rare path's old site still sends the run to its section |
| 100 | no AI attribution leaves the machine: the ground rule, and M, L, N and the commits obey it |
| 101 | the Resume section is exactly its text: nothing appended after the tracked-state pointer |

Test 20 is the helper's own fixture: it records today's behaviour, and no caller needs the line because of it.

**Gap 5: JSON through a file**

- **FR-021**: `state-set` MUST accept `--json-file <path>` in place of the inline value, for a whole key and for a sub-key. The value read MUST pass the same checks as the inline value.
- **FR-022**: A file that does not hold exactly one JSON document MUST be refused, with nothing written. The refusal MUST name the path and MUST NOT print the file's content.
- **FR-023**: `pipeline/docs/configuration.md` MUST use the file form for the trailer record, and for `config.commitTrailersFrom`. It MUST also say that any value from a tracked file goes through the file form. Every other doc line that puts tracked text between single quotes MUST change too.
- **FR-024**: The trailer refusal of a quote, a dollar sign or a backtick MUST stay, because a person may still type `--trailer`. The comment at `pipeline/scripts/trailer-check.sh:82` and the reason in `configuration.md` MUST stop naming `state-set`.
- **FR-024a**: `preflight.sh` MUST accept `--values-file <path>`: one JSON object, with the optional keys `commitTrailers` (a list of strings) and `baseBranchOverride` (a string). It MUST refuse, by its own message and printing no value, a missing file, a folder, a file that does not hold exactly one JSON object, an unknown key, and a value of the wrong type.
- **FR-024b**: Every value from the file MUST pass the same checks as the flag form. Trailers MUST keep the documented order: the file's first, then each `--trailer`, whatever the order on the command line. A typed `--base-branch-override` MUST beat the file's, as a flag beats a key.
- **FR-024c**: `pipeline/docs/configuration.md` MUST tell the run to write values from configuration into that file, and to pass only values typed at the keyboard as flags.

**The whole run**

- **FR-025**: `pipeline/skills/pipeline/SKILL.md` MUST stay under 65,536 bytes.
- **FR-026**: The release MUST follow the 057 shape: a `pipeline/CHANGELOG.md` section, and the version in `pipeline/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, as `1.11.0`. The tag follows the merge.
- **FR-027**: At DONE the run MUST report each phase's minutes, the gate waiting time, the comparison with run 056 and run 1 (057), and whether one fault harness served the run. This is the measurement of run 1's savings, and a saving not shown MUST be reported as not shown.

### Key Entities

- **Start status**: The exit status of `suite-base start`: 0 started or legally not started, 1 a check could not be made, 3 the run's own record cannot serve the start.
- **Test command layer**: The configuration layer that set `testCommand`, recorded in the state file beside the value.
- **Slice form**: How `prose_slice` returns its region: today's form with the closing line, or the opt-in form without it.
- **JSON file**: A file that holds one JSON document, which `state-set` reads so that no shell reads the value.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A forced "no test command" start exits with status 3, on all four shapes of the fault, and every legal "not started" path exits 0. The tests assert the exact status, and each goes red under its own mutant.
- **SC-002**: A fresh probe block and a resumed probe block each show the test command and its layer, before any command from a tracked file runs.
- **SC-003**: Three runs of the branch command in a row exit 0, and leave the branch on the same commit with the same uncommitted files.
- **SC-004**: The 056 mutant (text moved to the closing line) turns its test red. All 14 audit verdicts are recorded in `specs/058-five-pipeline-gaps/audit-prose-slice.md`.
- **SC-005**: A trailer list with an apostrophe and `'$(...)` is stored byte-exact through `state-set`'s file form, `preflight.sh`'s file form refuses it by name, and the marker file it names does not exist after either.
- **SC-006**: `pipeline/skills/pipeline/SKILL.md` is under 65,536 bytes, and the full suite and `shellcheck` are green against the baseline at J.
- **SC-007**: The DONE report holds the phase minutes for this run, run 056 and run 057, measured from their state files.

## Assumptions

- A saving must not reappear in another phase. No check is capped and no finding is deferred (the owner's rule, recorded in the seed).
- This run uses `bash scripts/run-suite.sh`, the first run on the side-by-side suite. The plugin that runs this pipeline is the cached 1.10.0; the changed copy is only used from the next run on.
- CI stays serial and sharded, and bash 3.2 rules apply to everything that CI runs on macOS.
- Tests that pin phase B's wording in `pipeline/tests/prose.bats` change with the wording.
- Status 3 is free: `start` uses 0 and 1, and `wait`'s 2 belongs to a different subcommand. A distinct 3 keeps "still running" and "cannot start" apart if a caller confuses the two.

## Out of Scope

- Any change to the serial CI jobs.
- A rewrite of `prose_slice`'s guards.
