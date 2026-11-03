# Tasks: F.5 cites a green suite result for main's commit

**Input**: `specs/053-f5-cites-main-suite/` (spec.md, plan.md, research.md, data-model.md, contracts/suite-base.md, quickstart.md)

**Tests**: test-first. Each new test is written and shown red against the unchanged script before its rule lands (FR-009).

Test command for a phase: `bash "$HOME/bats/bin/bats" --print-output-on-failure <file>` with the file the task names, run in the FOREGROUND from the repository root, output redirected to a NEW file in the run directory (`.delivery-kit/runs/053-f5-cites-main-suite/`), its exit status captured on the next line. Never pipe a test run into `tail`. Kill only PIDs you started. The full suite is the pipeline's J phase.

## Phase 1: One key, one record writer (refactor, no behaviour change)

**Goal**: the key's configuration read and its git part are two functions, and the record write is one function, so the background runner can call them (plan notes 1 and 2, Principle IV).

**Independent Test**: `pipeline/tests/suite-cache.bats` green with the same plan line as before; `suite-key` prints the same key as `main`'s script on this checkout.

- [ ] T001 In `pipeline/scripts/progress.sh`, split `suite_key` into `suite_config <feature> [base]` (validates the state file; sets `SK_CMD`, `SK_MODE`, `SK_LEAVE`, `SK_WHY`; everything above the `SK_SCRATCH=` line today) and `suite_key_here <scratch file>` (sets `SK_KEY`, `SK_TREE`, `SK_HEAD`, `SK_BYTES`, `SK_PLAT`; the `suite_key_check` call, `SK_PLAT`, and the hash), with `suite_key` calling the two in sequence and making and removing `SK_SCRATCH` as today. Comments above each say which caller needs the split (the base runner computes the key inside a worktree, with the configuration read from the main tree's state file).
- [ ] T002 In `pipeline/scripts/progress.sh`, move the record write of `cmd_suite_record` (from `mkdir -p "$SUITE_DIR"` to `mv "$tmp" "$out"`) into `suite_write_record <feature> <tap path> <rc> <suite dir>`, which uses the `SK_*` and `TJ_*` values set by its caller; `cmd_suite_record` calls it with `"$SUITE_DIR"`. No change to the record's fields or their order.
- [ ] T003 Run `pipeline/tests/suite-cache.bats`: green, plan line equals ok count and equals the count before T001. Differential (Principle II): `git show main:pipeline/scripts/progress.sh` into a scratch file; with the run's state file, `suite-key 053-f5-cites-main-suite` from both scripts prints the same key. Record both in `specs/053-f5-cites-main-suite/measurements.md`, dated.

**Checkpoint**: one key implementation and one writer, behaviour unchanged.

---

## Phase 2: The cited text names its commit and command (FR-004)

**Goal**: the lookup's summary line carries the record's commit (or its tree under `files`) and its command as JSON (research R6, contracts/suite-base.md).

**Independent Test**: a green lookup's second line ends `by run <feature> on commit <sha>, command "<command>"`, then the `--base` suffix when it applies.

- [ ] T004 In `pipeline/tests/suite-cache.bats`, change the three summary assertions (the tests that match `recorded "*" by run $F`, `*"by run $F"`, and the `--base` suffix) to the new text: `by run $F on commit $(git rev-parse HEAD), command "run-the-suite"`; add one test "the summary names the tree under files mode, and a command with a quote and a line break stays one line": `suiteReuse` `files`, a command holding `"` and a newline, a green record, lookup's output is exactly two lines and line 2 holds `on tree $(git rev-parse 'HEAD^{tree}')` and the command as `jq -c` prints it. Run the file: these tests red, every other test green.
- [ ] T005 In `pipeline/scripts/progress.sh`, `SUITE_LOOKUP_JQ`'s green branch: append ` on commit \(.head)` when `.head` is a non-empty string, else ` on tree \(.tree)`, then `, command \(.command | @json)`. Update the comment above `cmd_suite_lookup` to say what the summary names and why (the issue's rule: the cited result names its commit, command and counts). The decision part of the jq program is not touched.
- [ ] T006 Run `pipeline/tests/suite-cache.bats`: green, plan line equals ok count.

**Checkpoint**: a cited baseline says which commit and command it stands for.

---

## Phase 3: suite-base start and the runner (US1, US3) 🎯 MVP

**Goal**: `progress.sh suite-base <feature> start` makes a detached worktree of HEAD's commit and launches the runner, which records the result with the Phase 1 functions (FR-001, FR-002, FR-006, FR-006a).

**Independent Test**: on a scratch repository with the run's spec directory untracked, `start` with a stub green command, then (Phase 3 only) poll for `base-suite/outcome`, then `suite-lookup <feature> --base` exits 0 and names the commit.

- [ ] T007 [US1] Create `pipeline/tests/base-suite.bats`, built like `suite-cache.bats` (its `setup`, `repo`, `state`, `runs` and `refuses` shapes; read that file first). `repo` also writes an untracked `specs/001-demo/spec.md` and sets `artifacts.spec` to it. Stub commands: green `printf '1..1\nok 1 a\n'`; red `printf '1..1\nnot ok 1 a\n'; exit 1`. A helper `outcome_wait` polls `.delivery-kit/runs/$F/base-suite/outcome` every 0.2 s for at most 30 s (a loop with its own counter, never a bare `wait`). A `teardown` stops only the pid in `base-suite/pid`, if alive, and removes worktrees `git worktree list --porcelain` names besides the main one. Tests, each with a comment naming the mutation that turns it red: (a) "start records a green result F.5's --base lookup finds": `start` prints `base suite started on commit <HEAD>`; after `outcome_wait`, outcome is `green`; `suite-lookup $F --base` exits 0 and line 2 holds `on commit <HEAD>` and `— for these files without the untracked specs/001-demo/`; (b) red stub → outcome `red`; lookup exits 1 naming `red`; (c) after a green record, a tracked file changed in the main tree → lookup exits 1; (d) `suiteReuse` `off` → `start` prints `base suite not started: ` and the off reason, and no `base-suite/` directory and no extra worktree exist; (e) a green record already there (run (a)'s steps first) → a second run `002-next` with its own untracked spec directory: `start` prints `base suite not started: a green result is already recorded for commit <HEAD>`; (f) `start` twice → the second prints `base suite already started on commit <HEAD>` and one worktree exists besides the main one; (g) the main tree is untouched: `git rev-parse HEAD`, `git symbolic-ref HEAD`, `git status --porcelain=v1 -z` bytes, `git ls-files -s` and `git for-each-ref` output are identical before `start` and after the outcome, and after the outcome `git worktree list --porcelain` names only the main tree; (h) the runner's `TMPDIR` is its own: the stub prints `# tmp=$TMPDIR` before its plan line (a comment line keeps the TAP green), and the TAP's value is neither the test's `TMPDIR` nor empty, and that directory no longer exists after the outcome; (i) a stub that leaves a file in its working directory (`: > left.txt` then the green lines) → outcome starts `nothing recorded — ` and the lookup exits 1; (p) "one key and one record writer" (Principle IV): in `pipeline/scripts/progress.sh`, the key's jq template `{mode: $m, head: $h, files: $b, command: $c, platform: $p}` occurs exactly once and the record's `recordedAt: $at` occurs exactly once, counted with `grep -cF --` from a file, and the runner's function body names `suite_key_here` and `suite_write_record`.
- [ ] T008 [US1] Run `pipeline/tests/base-suite.bats` against the unchanged script: every test red (no `suite-base` subcommand). Record the red list in `measurements.md`.
- [ ] T009 [US1] In `pipeline/scripts/progress.sh`, add `cmd_suite_base <feature> start` and the internal `cmd_suite_base_run <feature>` per `contracts/suite-base.md` and `data-model.md`: `start` runs `need_git_top`, `suite_config "$1" base` (on refusal print the `not started` line with `SK_WHY`, exit 0), takes the base key with `suite_key "$1" base` and prints `not started: a green result is already recorded for commit <sha>` when `suite_lookup_one` finds a green one; an existing `base-suite/pid` prints `already started`; otherwise `mktemp -d "${TMPDIR:-/tmp}/dk-base-suite.XXXXXX"`, `git worktree add --quiet --detach "<tmp>/tree" HEAD`, writes `commit`, `tree`, `started`, then launches `bash "$SCRIPT_DIR/progress.sh" suite-base-run "$1"` detached: `setsid` when `command -v setsid` finds it, else `( set -m; … & )`, with `</dev/null >/dev/null 2>"<bookkeeping>/runner.log" 3>&-`, writes `pid`, prints `started`. The runner: resolves the bookkeeping and suite-results directories to absolute paths, reads `suite_config`, writes `heartbeat` (epoch seconds) now and every 5 s from a background loop it stops on exit, `cd`s into the worktree, `suite_key_here` with an absolute scratch file, runs `bash -c "$SK_CMD"` as a child with `TMPDIR` set to a new `mktemp -d` beside the worktree and output to `base-suite/suite.tap` (stdout and stderr), writes `child`, waits, re-takes the key, `cd`s back, judges with `tap_judge`, writes with `suite_write_record` (or `nothing recorded — <reason>` when the key moved), removes the worktree with `git worktree remove --force` and its temporary directories, writes `outcome` by rename last. A TERM trap stops the child, cleans up, and writes `stopped`. Add `suite-base` and `suite-base-run` to `usage()` and the dispatch `case`; comments say why each choice (research R1 to R4).
- [ ] T010 [US1] Run `pipeline/tests/base-suite.bats` and `pipeline/tests/suite-cache.bats`: green, plan line equals ok count. Prove one mutation lands and goes red: in a scratch copy of the script (`PROGRESS_SH_UNDER_TEST`), drop the `--detach` worktree in favour of running in the main tree; echo the mutated line; test (g) or (a) goes red. Record in `measurements.md`.

**Checkpoint**: a run can make the base record by itself.

---

## Phase 4: suite-base wait (US2, FR-003a)

**Goal**: `suite-base <feature> wait [--slice <s>] [--limit <s>]` waits in slices, stops at the limit only a runner whose heartbeat is fresh, and never judges reuse itself.

**Independent Test**: every row of the wait table in `contracts/suite-base.md` has a test.

- [ ] T011 [US2] In `pipeline/tests/base-suite.bats`, add: (j) "wait says none was started" → exit 0, `no base suite was started for this run`; (k) "wait returns when the runner ends": green stub, `wait --slice 30` → exit 0, `base suite ended: green`; (l) "wait gives back control while the runner works": stub `exec sleep 20`, `wait --slice 1 --limit 60` → exit 2, `base suite still running after `; (m) "wait stops only its own runner at the limit": stub `exec sleep 60`, `wait --slice 1 --limit 2` repeated while it exits 2, at most 10 times → exit 0, `base suite stopped at the 2 s limit`; the pids in `pid` and `child` are gone (`kill -0` fails); an unrelated `sleep 60` the test started first is still alive (then the test stops it); no extra worktree; (n) "a runner that stopped reporting is never signalled": no runner; the test writes `pid` with the pid of its own `sleep 60` and a `heartbeat` 120 s old → `wait` exits 0, `base suite stopped reporting`, and that `sleep` is still alive; (n2) "a dead runner's worktree is removed": after `start` with stub `exec sleep 60`, the test stops the runner and its child with KILL (their recorded pids only) → `wait` exits 0, `stopped reporting`, and `git worktree list --porcelain` names only the main tree; (o) "the limit counts from the first wait": stub `exec sleep 60`, `wait --slice 1 --limit 3` twice, then `wait --slice 5 --limit 3` → the third call stops it within its slice (exit 0, `stopped at the 3 s limit`).
- [ ] T012 [US2] Run `pipeline/tests/base-suite.bats`: T011's tests red, the rest green. Record in `measurements.md`.
- [ ] T013 [US2] In `pipeline/scripts/progress.sh`, add `wait` to `cmd_suite_base` per the contract and `data-model.md`'s state order: parse `--slice` and `--limit` (whole seconds, defaults 540 and 900, else die with usage); write `wait-started` on the first call; poll every second; a heartbeat older than 60 s or a dead pid with no `outcome` → `stopped reporting`, never signalled; when the pid is dead, also remove the worktree `tree` names, if it still exists, with `git worktree remove --force` (it is the run's own; a live pid's worktree is never touched); at the limit with a fresh heartbeat: `kill -TERM -- -<pid>` and, when that fails, `kill -TERM <pid>`; wait up to 10 s for `outcome`; if the worktree in `tree` still exists, `git worktree remove --force` it; write `outcome` `stopped at the <n> s limit` when the runner wrote none; print and exit 0. Exit 2 when the slice ends first.
- [ ] T014 [US2] Run `pipeline/tests/base-suite.bats` three times in a row (timing tests): green each time, plan line equals ok count. Prove one mutation lands and goes red: in a scratch copy (`PROGRESS_SH_UNDER_TEST`), drop the heartbeat-freshness check before the TERM; echo the mutated line; test (n) goes red. Record the three runs and the mutation in `measurements.md`.

**Checkpoint**: F.5 can wait without hanging and without stopping anything it did not start.

---

## Phase 5: The skill and the docs say when it runs (FR-007, FR-008)

**Goal**: B starts the base run; F.5 waits, then looks up; the metrics carry `f5Cited`; phases.md and configuration.md describe it.

**Independent Test**: `pipeline/tests/prose.bats` green, with new pins that go red when the B line, the F.5 loop or the metrics key is removed.

- [ ] T015 In `pipeline/tests/prose.bats`, extend the test "F.5, J and N reuse only a green suite result for identical files": pin, with `[[ "$flat" == *"…"* ]]`, the F.5 sentences of T016 (the wait loop while it exits 2, then `suite-lookup <feature> --base`, and `f5Cited` as a JSON boolean); update `span_f5` to T016's text. Add a test "B starts the base suite run once the branch is cut": slice B (`^\*\*B — specify\.\*\*` to `^\*\*C — clarify`), pin `progress.sh suite-base <feature> start` and that its one line is printed. In the test "phases.md states the suite reuse rules the state helper enforces", pin the new paragraph's sentences of T018 (the worktree, the 900-second limit, `suiteReuse: off` stops it, the heartbeat rule). Run `pipeline/tests/prose.bats`: the new pins red, the rest green.
- [ ] T016 In `pipeline/skills/pipeline/SKILL.md`, B: after "Record `artifacts.spec`.", add: "Then run `progress.sh suite-base <feature> start` and print the one line it prints: on a fresh run whose base commit has no green suite result, it starts the full suite on that commit in the background, in a separate checkout, for F.5 to cite. An exit 1 is printed too and does not stop the run: F.5 then runs the suite." F.5: before "F.5 adds `--base`", add: "F.5 first runs `progress.sh suite-base <feature> wait` again while it exits 2 — the background run B started; it never decides reuse — then asks `suite-lookup <feature> --base`." After the `--base` sentence add: "F.5 records in the run's metrics whether it cited a result, as `f5Cited`, a JSON boolean, and the wait's last line as `baseSuite`."
- [ ] T017 In `pipeline/skills/pipeline/SKILL.md`, keep the rest of F.5 and B as they are; confirm `span_f5` and any B span in `prose.bats` match the new text exactly (generate the span from the file, never type it).
- [ ] T018 In `pipeline/docs/phases.md`, "Reusing a suite run": add a paragraph after the `--base` paragraph describing the base suite run (who starts it, when, the detached worktree outside the tree and why, the record it makes being an ordinary record, the 900-second wait limit counted from F.5's first wait and why it is a loop of calls, the heartbeat rule, `suiteReuse: off` turning it off with all reuse, and that the summary line names the commit and the command). In the F.5 row of the phase table add "or a result the run's own background run recorded on the base commit". In `pipeline/docs/configuration.md`, the `suiteReuse` row: `off` also starts no base run.
- [ ] T019 Run `pipeline/tests/prose.bats` and `pipeline/tests/skills.bats`: green, plan line equals ok count.

**Checkpoint**: the owner can read when the base run happens, what it costs and how to turn it off.

---

## Phase 6: Release pipeline 1.8.0

**Goal**: the change ships as a MINOR (research R8).

**Independent Test**: `bash scripts/check-versions.sh` exits 0 and reports the released state.

- [ ] T020 In `pipeline/CHANGELOG.md`, add `## [1.8.0] - 2026-11-03` above `## [1.7.6]`, with Highlights (F.5 cites a green result for the base commit, recorded by the run's own background suite run started in B) and Added/Changed entries: `suite-base start|wait`, the summary line naming commit and command, the skill's B and F.5 steps, `f5Cited`; Closes #110. Set `"version": "1.8.0"` in `pipeline/.claude-plugin/plugin.json` and the pipeline entry of `.claude-plugin/marketplace.json` (edit with `sed`, never `jq`; prove the diff is one line each).
- [ ] T021 Run `bash scripts/check-versions.sh`: exit 0. Run `bash "$HOME/bats/bin/bats" -r tests` from the repository root: green, plan line equals ok count.

**Checkpoint**: 1.8.0 is ready to tag after merge.
