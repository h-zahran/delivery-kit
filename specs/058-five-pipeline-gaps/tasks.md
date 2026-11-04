# Tasks: Close the five pipeline gaps

**Input**: `specs/058-five-pipeline-gaps/` (spec.md, plan.md, research.md, contracts/commands.md, quickstart.md)

**Tests**: the spec asks for them (SC-001 to SC-005), so each test comes first and is seen red.

Each phase is one review piece. The order frees the skill's bytes first, and leaves `prose_slice` until B's prose is final.

---

## Phase 1: User Story 3, the branch cut (Priority: P1) 🎯 MVP

**Goal**: `progress.sh branch-cut` replaces B's branch sentence (FR-012 to FR-016), and frees bytes in the skill.

**Independent Test**: `bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/branch-cut.bats` passes, and quickstart section 3 prints `PASS`.

- [X] T001 [US3] Create `pipeline/tests/branch-cut.bats` with one test per row of the `branch-cut` table in `specs/058-five-pipeline-gaps/contracts/commands.md`, each with the exact status and stdout line: branch absent (uncommitted spec file stays, the branch names the base's commit); three runs in a row; HEAD on the branch; HEAD elsewhere with the base as ancestor, and on a detached HEAD; base not an ancestor (refused, HEAD and every ref unchanged, stderr names both and the `git checkout` command); empty `branch`; empty `baseBranch`; a name with a leading dash and `@{-1}`; base absent; a tag of the same name as the branch or base; a switch git refuses because it would overwrite an uncommitted file (status 1, the file's bytes unchanged); the branch checked out in another worktree. Run the file and see it red.
- [X] T002 [US3] In `pipeline/scripts/progress.sh`, add `cmd_branch_cut` per research "`branch-cut`", add the dispatch line, and add `branch-cut` to the `usage` list. Update the pinned list in `pipeline/tests/progress.bats` (the `<init|read|...>` line). Run `pipeline/tests/branch-cut.bats` and `pipeline/tests/progress.bats` until green, on bash 3.2 rules, and run `shellcheck --norc -f gcc pipeline/scripts/progress.sh`.
- [X] T003 [US3] In `pipeline/skills/pipeline/SKILL.md`, phase B, replace the sentence that begins `THEN create the feature branch` with a sentence that runs `progress.sh branch-cut <feature>` and says it is safe to run again. Update the pins that name the old sentence in `pipeline/tests/prose.bats` and the `checkout -b` comments that describe B in `pipeline/tests/preflight.bats`, and the `B runs` bullets in `pipeline/docs/configuration.md`. Record the skill's byte count, and check it is lower than 65,411.

**Checkpoint**: a second run of the command changes nothing, and the skill has more bytes free.

---

## Phase 2: User Story 5, JSON through a file (Priority: P2)

**Goal**: `state-set --json-file` (FR-021, FR-022) and `preflight.sh --values-file` (FR-024a, FR-024b), and the docs that use them (FR-023, FR-024, FR-024c). It comes before phase 3, because B's stop records a command through the file form.

**Independent Test**: quickstart section 5 prints `PASS`.

- [X] T004 [P] [US5] In `pipeline/tests/progress.bats`, add tests for `state-set --json-file`: a whole key and a sub-key; a list holding an apostrophe and `'$(touch marker)`, stored byte-exact, with no `marker` afterwards; every refusal in the contract (missing file, folder, empty file, two documents, bad JSON), each with status 1, the state file's bytes unchanged, and none of the file's content on stdout or stderr, tested by a marker word in the file; the same type check and `gates.pending` guard as the inline form; the inline form unchanged. Run them and see them red.
- [X] T005 [P] [US5] In `pipeline/tests/preflight.bats`, add tests for `--values-file`: each refusal in the contract, with no value printed; trailers in the documented order with the flag before and after it on the command line; `--base-branch-override` beating the file's value; a report byte-identical to the flag form; a hostile trailer and a hostile override, each refused by name with no `marker` afterwards; a trailing line feed in a trailer refused; a relative path read from the caller's folder under `--dir`. Update the pinned `legal:` list if one pins it. Run them and see them red.
- [X] T006 [US5] In `pipeline/scripts/progress.sh`, `cmd_state_set`, add `--json-file` per research "`state-set --json-file`", and update its usage line. Run `pipeline/tests/progress.bats` until green.
- [X] T007 [US5] In `pipeline/scripts/preflight.sh`, add `--values-file` per research "`preflight.sh --values-file`", and add it to the `legal:` list. Run `pipeline/tests/preflight.bats` until green, and run `shellcheck --norc -f gcc pipeline/scripts/preflight.sh`.
- [X] T008 [US5] In `pipeline/docs/configuration.md`: replace the `state-set <feature> config commitTrailers '<json array>'` text with the file form, for the list and for `config.commitTrailersFrom`; change the `--trailer` and `--base-branch-override` bullets so the run writes values from configuration to a file and passes `--values-file`, and types only keyboard values as flags; change the reason at "because the run types the list into a shell command"; add one rule that any value from a tracked file reaches `state-set` by file. In `pipeline/scripts/trailer-check.sh`, change the comment at lines 81 to 86. In `pipeline/skills/pipeline/SKILL.md`, add `--values-file` to the pre-flight list of flags and add `--json-file` to the ground rule on state writes. Update any pin these edits touch in `pipeline/tests/prose.bats` and any file that pins the changed sentence.

**Checkpoint**: quickstart section 5 prints `PASS`, and no doc holds tracked text between single quotes.

---

## Phase 3: User Story 1, the base suite's status (Priority: P1)

**Goal**: `suite-base start` exits 3 on a record that cannot serve it (FR-001 to FR-005), and B stops on it (FR-006).

**Independent Test**: `bash "$HOME/bats/bin/bats" --print-output-on-failure pipeline/tests/base-suite.bats` passes, and quickstart section 1 prints `PASS`.

- [X] T009 [US1] In `pipeline/tests/base-suite.bats`: change the test "a state file with no usable test command starts nothing" to assert status 3 on all four shapes; add a test that a missing or absent `artifacts.spec` exits 3; add a test that a run after status 3 starts once the record is fixed; add a test that reads every `base suite not started` site in `pipeline/scripts/progress.sh` and holds each to the row it belongs to in the contract, so a new line cannot go unclassified. Check that the legal paths keep their assertion through the `runs` helper. Run the file and see the changed tests red.
- [X] T010 [US1] In `pipeline/scripts/progress.sh`: set `SK_FAULT` on the two paths in `suite_config`, and return 3 from `base_start` when it is set; replace the comment above `base_start` with the three statuses. Run `pipeline/tests/base-suite.bats` until green.
- [X] T011 [US1] In `pipeline/docs/rare-paths.md`, add the section "No test command" per FR-006: B stops; a command the owner gives is recorded by file with its layer, and the start runs again; a "go on with none" is recorded under `gates.B`; F.5 records "no test command: no suite ran" in `test_baseline`; J and N run `analyzeCommand`, say no suite ran, and never report a pass; the PR body says so. In `pipeline/docs/phases.md`, state the start's statuses. In `pipeline/skills/pipeline/SKILL.md`, replace `An exit 1 is printed too and does not stop the run: F.5 then runs the suite.` with a sentence that keeps exit 1's meaning and sends exit 3 to that section, and add the stop to the list of conditional stops under "Gates". If the bytes run short, move other text from the skill to its docs page: the stop stays on the list. In `pipeline/docs/configuration.md`, add the stop to the paragraph that begins "What stops a run is a range". Update the pins in `pipeline/tests/prose.bats`, and add a pin for the pointer.

**Checkpoint**: status 3 stops B, and a run with no test command says so in every later phase.

---

## Phase 4: User Story 2, show the command before it runs (Priority: P1)

**Goal**: The probe block and the `started` line show the command and its layer (FR-007 to FR-011).

**Independent Test**: quickstart section 2 prints `PASS`, and the prose pins for the line pass.

- [X] T012 [US2] In `pipeline/tests/base-suite.bats`, add tests: the `started` line ends in `, from <json>` when `config.testCommandFrom` is a string, and has no such part when it is absent. In `pipeline/tests/prose.bats`, add pins: the probe block holds the `Test command` line between `Base branch` and `Branch`; `pipeline/docs/configuration.md` holds "The Test command line" with the layer list, the JSON quoting and the resume rule. Run them and see them red.
- [X] T013 [US2] In `pipeline/scripts/progress.sh`, `base_start`, read `config.testCommandFrom` and add it to the `started` line, per the contract.
- [X] T014 [US2] In `pipeline/docs/configuration.md`, after "The Implementer line", add "The Test command line" per the contract and FR-008, FR-009. In `pipeline/skills/pipeline/SKILL.md`, add the line to the probe block and extend the `**Implementer:**` pointer to name it. In `pipeline/README.md`, add the line to the sample probe block. Check the byte count is under 65,536. Run `pipeline/tests/prose.bats` and `pipeline/tests/base-suite.bats` until green.

**Checkpoint**: a fresh run shows the command before B starts it.

---

## Phase 5: User Story 4, `prose_slice` (Priority: P2)

**Goal**: An opt-in form that drops the closing line (FR-017, FR-018), and every region test switched to it (FR-019, FR-020).

**Independent Test**: quickstart section 4 prints `PASS`, `pipeline/tests/prose.bats` passes, and `specs/058-five-pipeline-gaps/audit-prose-slice.md` holds a verdict for each of the 14 named tests.

- [X] T015 [US4] In `pipeline/tests/prose.bats`, add fixture tests beside test "a declared inner line is admitted, and admits nothing else": `raw-inside` and `flat-inside` return the slice without the closing line; `raw` and `flat` still hold it; every guard fires the same way on an inside form (unterminated, empty, opener twice, inner heading, stale declared line); a one-line region is refused with the new message. Run them and see them red.
- [X] T016 [US4] In `pipeline/tests/prose.bats`, `prose_slice`, add the two forms per research, and extend the form and arity messages. Keep the default path byte-identical. Update the header comment.
- [X] T017 [US4] Write a throwaway script under the run's directory `.delivery-kit/runs/058-five-pipeline-gaps/` that rewrites the form argument in every `prose_slice` call in `pipeline/tests/prose.bats` that is not one of the helper's own fixture tests, and refuses to write unless its counts match a count taken by a second method. Run it, and run `pipeline/tests/prose.bats`. Each red test goes on a list.
- [X] T018 [US4] For each of the 14 tests named in FR-020, and each other red from T017, read what it pins. Decide: the text belongs in its region, so the boundary moves; or the closing line is part of what it pins, so that call keeps the default with a one-line reason. Record each verdict in `specs/058-five-pipeline-gaps/audit-prose-slice.md`, with the test's name. Remove the hand-written cut `flat=${flat%%'**C — clarify'*}` from the test "B records config before it starts the base suite run", and correct its comment. Run `pipeline/tests/prose.bats` until green.
- [X] T019 [US4] Run quickstart section 4, and record in `specs/058-five-pipeline-gaps/audit-prose-slice.md` that the mutant landed and the test went red.

**Checkpoint**: text on a closing line can no longer satisfy a region test.

---

## Phase 6: Release records

**Goal**: The versions and changelog agree (FR-025, FR-026).

**Independent Test**: `bash scripts/check-versions.sh` exits 0, and `wc -c < pipeline/skills/pipeline/SKILL.md` prints a number under 65536.

- [ ] T020 In `pipeline/CHANGELOG.md`, add the `[1.11.0] - 2026-11-04` section above `[1.10.0]`: the five gaps, with `branch-cut`, status 3, the `Test command` line, `--json-file`, `--values-file`. Say that `prose_slice` is test code and does not ship.
- [ ] T021 In `pipeline/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, change the pipeline version to `1.11.0`. Run `bash scripts/check-versions.sh`.

**Checkpoint**: the versions agree.

---

## Dependencies

- Phase 1 comes first: it frees the bytes phases 2, 3 and 4 spend.
- Phase 2 before phase 3: B's stop records a command by file.
- Phase 5 after phases 1 to 4: their edits change B's text and its pins, and the switch must read the final text.
- Phase 6 comes last. If phase I or J changes a shipped file, the changelog text is checked again before the release stamp holds.
- Within a phase, each test task comes before its code, and is seen red first.

## Parallel opportunities

- T004 and T005 touch different test files.
- Phases do not overlap, because several edit `pipeline/skills/pipeline/SKILL.md` and `pipeline/tests/prose.bats`.

## Implementation Strategy

Phase 1 alone fixes the failing resume. Phases 2 to 4 close the two silent paths. Phase 5 makes the tests honest about their region. The owner merges, and the tag follows the merge. DONE reports each phase's minutes against run 056 and run 057 (FR-027); it needs no task, and it writes nothing to the branch.
