# Tasks: The pre-flight report says which git fields it never read

**Input**: `specs/050-preflight-unread-git-fields/` (spec.md, plan.md, research.md, data-model.md, contracts/not-read.md, quickstart.md)

**Tests**: test-first. Each new assertion is written and shown red against the unchanged script before the key lands (FR-007).

Test command for a phase: `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` (Phase 1) or `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` (Phase 2), run in the FOREGROUND. The full suite is the pipeline's J phase.

## Phase 1: The report names the fields it did not read (US1, US2, US3) 🎯 MVP

**Goal**: `preflight.sh` emits `notRead`, built where each field is produced; the suite pins it for every git reason and both base-source cases.

**Independent Test**: `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` passes; quickstart.md steps 1 to 3 print the expected lists.

- [ ] T001 [US1] In `pipeline/tests/preflight.bats`, after the `git_report_is` helper, add a helper `not_read_is <json-list>` that asserts, in one `jq -e`, that `.notRead` has `type == "array"` and equals the given list exactly, and on failure prints the wanted and the got list. Define the two expected lists once, as variables beside the helper: `NOT_READ_ALL='["baseBranch","baseBranchSource","remote.kind","tree.dirty","willSkip.L","willSkip.M"]'` and `NOT_READ_NO_BASE='["remote.kind","tree.dirty","willSkip.L","willSkip.M"]'`, with a comment that the second is for a base from configuration or an override (data-model.md).
- [ ] T002 [US1] In `pipeline/tests/preflight.bats`, add one line, `not_read_is "$NOT_READ_NO_BASE"`, after `git_report_is` in each of these existing unusable-git tests (each probes with `--base-branch main`): "the capability report names git absent, and the report survives it", "the capability report names a git that refuses the repository for ownership", "the ownership refusal is found from exit codes, with git's messages gone", "the capability report names a git that opens no repository here", "the capability report names a git that is found but cannot run". Add no other line and edit no existing line.
- [ ] T003 [US1] In `pipeline/tests/preflight.bats`, add the test "an unusable git with no base flag names the base fields as not read": build the refused repository the ownership test builds (`git_isolate`, `git init`, `refuse_for_ownership`), `probe --dir <repo>` with no base flag; assert status 0, `git_report_is true refused-ownership`, `.baseBranchSource == "current branch"`, and `not_read_is "$NOT_READ_ALL"`. Then the same with git absent: a shim directory from `PROBE_TOOLS` minus git, derived the way the absent test derives it, `probe --path <dir> --dir "$FIX/other"`; assert `git_report_is false absent` and `not_read_is "$NOT_READ_ALL"`. Two reasons, not four: the base rule reads the base source only, never `gitReason`, and the four reasons share it through the `--base-branch` assertions T002 adds.
- [ ] T004 [US1] In `pipeline/tests/preflight.bats`, add the test "an override is established without git, so an unusable git does not name it": the refused repository, `probe --dir <repo> --base-branch-override integration` (seed one commit and `git branch integration` before `refuse_for_ownership`, as "an unusable git reports names unchecked" does); assert status 0, `.baseBranchSource == "override"`, `.baseBranch == "integration"`, and `not_read_is "$NOT_READ_NO_BASE"`.
- [ ] T005 [US2] In `pipeline/tests/preflight.bats`, add the test "a usable git names nothing, even with no remote": `git init -q` a repository in `$BATS_TEST_TMPDIR/noremote` with no remote, `probe --dir <repo>` (no base flag); assert `git_report_is true usable`, that `willSkip` holds an `L` entry (the precondition: the no-remote skips ARE there, so an empty list is not empty for want of them), and `not_read_is '[]'`. Then `probe --dir <repo> --base-branch main` and assert `not_read_is '[]'` again.
- [ ] T006 [US1] Run `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` against the UNCHANGED script in the FOREGROUND and confirm every test T002-T005 touched is red and every other test is green (record the red list, for T009).
- [ ] T007 [US1] In `pipeline/scripts/preflight.sh`: after the base-branch block, start `not_read='[]'` and add a helper `mark_not_read <name>` that appends `<name>` with `jq -n --argjson a "$not_read" --arg n "$1" '$a + [$n]'`. When `git_usable` is not `true`: after the base block, mark `baseBranch` and `baseBranchSource` unless `base_source` is `override` or `configured` (research R4: written as "not override or configured"); after the remote block, mark `remote.kind`; after the `dirty` line, mark `tree.dirty`. Add `add_git_skip <phase> <reason>` beside `add_skip`: it calls `add_skip`, then, when `git_usable` is not `true`, `mark_not_read "willSkip.$1"`. Use it for the no-remote `L` and `M` skips and the non-GitHub `M` skip; leave the `N.5` and `gh`-absent skips on `add_skip`. Add `--argjson not_read "$not_read"` to the final `jq -n` and `notRead: $not_read` after `gitReason`. Write a comment above `not_read` saying what the list names, that it is built at each field's production site so no field list is written twice (Principles IV, V), and that a later git-derived base source is unread by default.
- [ ] T008 [US1] Run `bash "$HOME/bats/bin/bats" pipeline/tests/preflight.bats` in the FOREGROUND: green, the plan line equals the ok count, no skip. Run quickstart.md steps 1-3 and check the printed lists. Then the differential SC-002 needs (Principle II): with the script from `main` (`git show main:pipeline/scripts/preflight.sh` into a scratch file) and the changed one, probe the same usable repositories (this checkout; a fresh `git init` with no remote; the same with `--base-branch main`), and compare each pair as `jq -S 'del(.notRead)'`: identical. Record the command, the cases and the result in `measurements.md` (T009).
- [ ] T009 [US3] Write `specs/050-preflight-unread-git-fields/measurements.md`: date, commit, git and jq versions; the T006 red list; and a mutation table (FR-007). Run it in a git worktree, never the main checkout: each mutant applied to a COPY of the script, the suite pointed at it with `PREFLIGHT_UNDER_TEST`, the mutated line echoed to prove it landed, and the tests that went red recorded: (a) drop `notRead` from the output; (b) never mark the base fields; (c) mark the base fields for every source, `configured` and `override` included; (d) mark the skips whatever `git_usable` says (`add_git_skip` marks unconditionally); (e) `--argjson not_read` to `--arg`; (f) never mark `tree.dirty`. Every new or extended test must go red under at least one mutant; say which. A mutant that changed nothing is NO-OP, not a pass.

**Checkpoint**: the report is honest and pinned.

---

## Phase 2: The docs read the list, and the gap is closed (US1, US3)

**Goal**: the probe-block rule reads `notRead`; `configuration.md` documents the key; both are pinned; the 013 deferral is marked closed.

**Independent Test**: `bash "$HOME/bats/bin/bats" pipeline/tests/prose.bats` passes; deleting the configuration.md sentence in a copy turns a pin red.

- [ ] T010 [US1] In `pipeline/docs/rare-paths.md`, rewrite "The probe block without git" (heading unchanged) so it marks exactly what the report's `notRead` names (research R7): keep the first sentence, add that the report's `notRead` list names those parts and that the block marks what it names and nothing else; `Base branch`: when `notRead` names `baseBranch`, print `— not read: git is not usable here (<gitReason>)`, and when it does not, the name came from a configuration file or an override and IS established — print it, add that it was not checked against the repository, and for `override` name its layer; `Remote`: when `notRead` names `remote.kind`, print it as not read, and keep the `ghPresent` sentence; `Will skip`: mark as not established each entry `notRead` names as `willSkip.<phase>`, keeping the `no git remote` explanation, and print every other entry as it stands.
- [ ] T011 [P] [US1] In `pipeline/docs/configuration.md`, add a section `## Fields the report did not read` after "The Implementer line": one paragraph saying `preflight.sh`'s report carries `notRead`, a list naming each field whose git read did not run or failed, `[]` whenever `capabilities.gitUsable` is `true`; that a named field holds a placeholder, not a fact; that a base branch from configuration or an override is never named, since it is established without git; that names are dotted paths and a skip is named `willSkip.<phase>`; and that a consumer tests membership, not position. Point to `specs/050-preflight-unread-git-fields/contracts/not-read.md` for the full contract only if the page already links to `specs/` elsewhere; otherwise do not.
- [ ] T012 [US3] In `pipeline/tests/prose.bats`: replace "The probe block without git" span in `rare_spans` with the flattened text T010 wrote (generate it from the file, then compare it byte for byte); add a pin, in the test that pins `configuration.md`'s sections or a new test beside it, for T011's sentence that `notRead` is `[]` whenever `capabilities.gitUsable` is `true` and the sentence that a base from configuration or an override is never named; add a pin on the rare-paths section that the block "marks what it names and nothing else". Run the prose suite in the FOREGROUND: green. Then, in a worktree, delete T011's paragraph in a copy and confirm a pin goes red, and restore the old `baseBranchSource`-keyed rule in a copy of rare-paths and confirm a pin goes red; record both in `measurements.md`.
- [ ] T013 [P] [US1] In `specs/013-preflight-git-probe/spec.md`, at the start of the "Several reported fields still speak confidently from reads that never happened." bullet under "Known gaps, deferred with cause", add `**CLOSED by feature 050 (\`specs/050-preflight-unread-git-fields/\`), as an additive \`notRead\` list.**`, matching how the first bullet there marks its closure. Change nothing else in that file.

**Checkpoint**: the docs read the report, and the deferral is recorded closed.

---

## Phase 3: Release pipeline 1.7.4

**Goal**: installed copies get the change (FR-010).

- [ ] T014 In `pipeline/CHANGELOG.md`, add `## [1.7.4] - 2026-11-02` above `## [1.7.3]` with `### Highlights` (one line) and `### Added` (the `notRead` list: what it names, `[]` with a usable git, no existing key changed; the probe block now marks exactly what it names; closes the gap 013 deferred), in the file's style; set `"version": "1.7.4"` in `pipeline/.claude-plugin/plugin.json`; set the pipeline entry's version to `1.7.4` in `.claude-plugin/marketplace.json` with `sed`, never `jq` (`git diff --stat` shows one line changed there).
- [ ] T015 Run `bash scripts/check-versions.sh` (rc 0, pipeline released at 1.7.4) and `bash "$HOME/bats/bin/bats" tests` in the FOREGROUND: green.

---

## Dependencies

- Phase 1 before Phase 2 (the docs name a key the probe must emit). Phase 3 last.
- In Phase 1: T001-T005 (tests) before T006 (red run) before T007 (script) before T008-T009.
- In Phase 2: T010, T011 and T013 touch different files; T012 after T010 and T011.

## Parallel examples

- Phase 1: none; every task edits `preflight.bats` or depends on one that does.
- Phase 2: T011 and T013 in parallel with T010.

## Implementation strategy

Phase 1 alone makes the report honest (MVP); Phase 2 makes the docs read it and records the closure; Phase 3 ships it.
