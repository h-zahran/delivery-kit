---

description: "Task list for 015-guard-jq-spawn-two"
---

# Tasks: the guard stops counting jq, part two

**Input**: Design documents from `/specs/015-guard-jq-spawn-two/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: No test tasks. The specification forbids editing
`handoff/tests/context-guard.bats` and adds no tests of its own — this change
must be invisible to the suite. Verification is by side-by-side comparison and
by process counting, both of which have their own tasks below.

**Baseline commit**: `168edc1`. Pinned as a commit id in every diff and every
harness run. Never a branch name — this repository rebase-merges, so a branch
name stops being a baseline the moment the work lands.

---

## Phase 1: Setup

- [X] T001 Confirm `168edc1` is a true baseline for the file under change by running `git diff --stat 168edc1 173aaf2 -- handoff/hooks/context-guard.sh` and requiring empty output
- [X] T002 [P] Record the before process counts by executing section 1 of `specs/015-guard-jq-spawn-two/quickstart.md` into `.delivery-kit/runs/015-guard-jq-spawn-two/proc-count-before.txt`
- [X] T003 [P] Record the restricted vocabulary that binds `handoff/` by reading the banned list in `tests/portability.bats`, and confirm no word planned for a new comment appears in it
- [X] T004 [P] Record the before full-suite result verbatim into `.delivery-kit/runs/015-guard-jq-spawn-two/test-baseline.tap` by running the house suite from the repository root
- [X] T005 [P] Write the before-side comment inventory of `handoff/hooks/context-guard.sh` at `168edc1` into `.delivery-kit/runs/015-guard-jq-spawn-two/comment-inventory-before.txt`, one line per dated incident and named failure mode with its count

## Phase 2: Foundational — the proof harness, before anything it must prove

**Blocking**: neither user story may be verified until the harness can see the
kind of change each makes. Extending it afterwards would mean the harness was
shaped by the change it is meant to judge.

- [X] T006 Extend `scripts/context-guard/differential.sh` with transcript shapes: empty, one reading, fourteen, fifteen, sixteen, an unparseable line among good ones, a non-numeric token value among good ones, a non-numeric cache field among good ones, sidechain entries present, and a negative reading
- [X] T007 Confirm the extended `scripts/context-guard/differential.sh` reports every shape identical when run against `168edc1` with the hook still unchanged, and that its shape count grew by the number added in T006
- [X] T008 Fire the positive control on the extended harness — point `NEWHOOK` at a deliberately altered copy of `handoff/hooks/context-guard.sh` and require a non-zero exit and at least one differing shape, per section 2 of `specs/015-guard-jq-spawn-two/quickstart.md`

## Phase 3: User Story 1 — the transcript is read once, not three times (P1)

**Goal**: one parser pass returns both the reading count and the median,
replacing two parser passes and a text-count process. The starved path keeps its
single conditional re-read.

**Independent test**: process counts fall by one parser and one text counter on
both transcript shapes, and the side-by-side comparison reports every shape
identical.

- [X] T009 [US1] Replace the transcript-reading block in `handoff/hooks/context-guard.sh` — one program string used by both calls, wrapped per line in the error-tolerant form, emitting the count and the median joined by the separator already defined once in the file, invoked with all three of raw-input, raw-output and null-input
- [X] T010 [US1] Split that joined result in `handoff/hooks/context-guard.sh` with parameter expansion, never a line-reading builtin, and force a count that is not a run of digits to zero so a broken count means starved rather than satisfied
- [X] T011 [US1] Reproduce the old count's digit-prefix rule in the same program in `handoff/hooks/context-guard.sh`, so a negative reading stays out of the count and inside the median
- [X] T012 [US1] Carry every comment in the changed region of `handoff/hooks/context-guard.sh` — the three budgets, both incident dates, the floor-equals-window rule, the measured fallback cost — and add one comment naming why the error-tolerant form is load-bearing
- [X] T013 [US1] Verify with `bash -n handoff/hooks/context-guard.sh` and `shellcheck handoff/hooks/context-guard.sh`
- [X] T014 [US1] Run `scripts/context-guard/differential.sh 168edc1` and require every shape identical with exit zero
- [X] T015 [US1] Run `bash "$HOME/bats/bin/bats" --print-output-on-failure handoff/tests/context-guard.bats` and require green

## Phase 4: User Story 2 — stdin reaches the parser without a detour (P2)

**Goal**: the parser reads standard input directly; the copy into a shell
variable and the write back out are gone. The parser-unavailable branch consumes
standard input itself, so every path still leaves the caller's write complete.

**Independent test**: the process counts show one fewer input-copy process, and
a writer piping more than a pipe buffer into the guard exits zero on every path.

**Depends on**: Phase 3 only because both stories edit the same file. The two
changes are independent in substance; they are serialised so no two edits race.

- [X] T016 [US2] Move the parser availability probe in `handoff/hooks/context-guard.sh` above the point where standard input is read
- [X] T017 [US2] Add a step inside the parser-unavailable branch of `handoff/hooks/context-guard.sh` that consumes standard input before the branch exits, with a comment recording the measured writer exit of 141 that makes it necessary
- [X] T018 [US2] Remove the standard-input copy in `handoff/hooks/context-guard.sh` and let the payload extraction read standard input directly, keeping the field list, their order, their defaults and their string coercion exactly as they are
- [X] T019 [US2] Verify with `bash -n handoff/hooks/context-guard.sh` and `shellcheck handoff/hooks/context-guard.sh`
- [X] T020 [US2] Run section 4 of `specs/015-guard-jq-spawn-two/quickstart.md` and require the writer's exit status to be zero on the parser-unavailable path
- [X] T021 [US2] Run `scripts/context-guard/differential.sh 168edc1` and require every shape identical with exit zero
- [X] T022 [US2] Run `bash "$HOME/bats/bin/bats" --print-output-on-failure handoff/tests/context-guard.bats` and require green

## Phase 5: User Story 3 — the record survives the refactor (P3)

**Goal**: every dated incident and every named failure mode present before the
change is present after it.

**Independent test**: the after-side inventory matches or exceeds the before-side
inventory on every entry.

- [X] T023 [US3] Run the comment inventory in section 7 of `specs/015-guard-jq-spawn-two/quickstart.md` against `handoff/hooks/context-guard.sh` and require no entry to have fallen below its baseline count
- [X] T024 [US3] Confirm the changed `handoff/hooks/context-guard.sh` carries no word from the banned list recorded in T003, by running the shipped-surface scan in `tests/portability.bats`

## Phase 6: Polish and cross-cutting concerns

- [X] T025 Measure the after process counts by executing section 1 of `specs/015-guard-jq-spawn-two/quickstart.md` into `.delivery-kit/runs/015-guard-jq-spawn-two/proc-count-after.txt`, on both transcript shapes and all three configuration counts
- [X] ~~T026 Prove `handoff/tests/context-guard.bats` was not edited by running
  `git diff --stat 168edc1 -- handoff/tests/context-guard.bats` and requiring empty
  output~~ **STRUCK.** The owner approved editing that file at the implementer
  gate; T031 records the decision and spec FR-011 carries it. Left visible rather
  than deleted, because this list is what a resumed implementation follows: a task
  still reading "require empty output" instructs the next run to revert an
  approved change. The check that replaces it is T044's — the diff is expected
  to be non-empty, and what matters is that the test was not weakened, which is
  proven by mutation rather than by a diff being empty.
- [X] T027 Run the full house suite from the repository root and require the same plan line as the baseline in T004, with zero failures
- [X] T028 [P] Record the new shapes and both measured process-count columns in `scripts/context-guard/README.md`, stating what was measured and when
- [X] T029 [P] Add the entry to `handoff/CHANGELOG.md` under the existing unreleased heading, in its changed subsection, naming the reduction and stating what was measured rather than asserting behaviour is unchanged
- [X] T030 Carry both measured process-count columns from `.delivery-kit/runs/015-guard-jq-spawn-two/proc-count-before.txt` and `proc-count-after.txt` into the commit message, alongside the text-counter and input-copy figures, so the claim travels with the change rather than only with the specification

---

## Dependencies

```text
Phase 1 (T001-T005)   setup and baselines — T002..T005 parallel
        ↓
Phase 2 (T006-T008)   the harness, before it judges anything
        ↓
Phase 3 (T009-T015)   User Story 1 — F8, the transcript
        ↓             (serialised: same file)
Phase 4 (T016-T022)   User Story 2 — F7, stdin
        ↓
Phase 5 (T023-T024)   User Story 3 — the record
        ↓
Phase 6 (T025-T030)   measurement, suite, and the two records
```

**Story independence**: User Stories 1 and 2 are independent in substance. Either
could ship without the other, and the specification says so explicitly — if the
stdin change could not be shown safe, the transcript change ships alone. They are
ordered here only because both edit the same file, and two agents must never edit
one file in the same batch.

## Parallel opportunities

- **Phase 1**: T002, T003, T004 and T005 touch four different output files and
  read only unchanged inputs. Four at once, capped by the run's limit of three.
- **Phase 6**: T028 and T029 touch two different files and may run together.
- **Everywhere else**: serialised. Every task in Phases 3 and 4 edits or reads
  `handoff/hooks/context-guard.sh`, and Phase 2 must complete before either can
  be judged.

## Implementation strategy

The smallest shippable increment is Phase 3 alone: one parser process and one
text-count process removed per run, proven by the harness, with stdin untouched.
Phase 4 is a second, separable increment.

Neither is worth shipping without Phase 2 first. A refactor of a guard whose
failure mode is silence, verified by a harness written after the refactor, is a
refactor verified by a harness shaped to agree with it.

## Phase 7: Convergence

Appended after implementation, from an assessment of the code against the
specification. Every item here is a record that has fallen behind the work,
not a defect in the work.

- [X] T031 Record in `specs/015-guard-jq-spawn-two/spec.md` that the owner
  authorised editing `handoff/tests/context-guard.bats`, and what the edit was,
  per FR-011 and SC-005 (contradicts). The file carries 35 insertions and 3
  deletions against `168edc1`, while the requirement forbids any edit. The
  requirement stays as written and gains the decision beside it: a requirement
  silently rewritten to match what happened records nothing.
- [X] T032 Add `handoff/skills/setup/SKILL.md` to the touched files in
  `specs/015-guard-jq-spawn-two/spec.md` and `plan.md`, with the reason, per the
  plan's touch-point list (unrequested). It carries the same reading rule as the
  hook and the suite pins the two together, so it could not stay behind.
- [X] T033 Correct the source tree in `specs/015-guard-jq-spawn-two/plan.md`,
  which marks `handoff/tests/context-guard.bats` as NOT CHANGED and omits
  `handoff/skills/setup/SKILL.md` entirely (partial).

## Phase 8: Review round one

Three reviewers, run in one batch against the specification, the plan, the
tasks and the diff. Every item below was raised by a reviewer and confirmed by
re-measurement before it was acted on.

- [X] T034 Pin the setup skill's INVOCATION in `handoff/tests/context-guard.bats`,
  not only its two declarations. Moving both anchors to a variable name had
  dropped the coupling between what the skill declares and what it runs; a skill
  with matching declarations and a five-wide window inlined at the call site
  passed. Proven closed: the same mutation now goes red.
- [X] T035 Carry the all-strings usage record as an ASSERTED difference in
  `scripts/context-guard/differential.sh`, and add the expectation argument that
  makes asserting one possible. Old behaviour on that record was silence; the new
  behaviour answers. Measured 0 bytes against 556.
- [X] T036 Add `select(type == "number")` to the per-line rule in
  `handoff/hooks/context-guard.sh` and `handoff/skills/setup/SKILL.md`, so a
  string reading cannot sort after every number and inflate the median.
- [X] T037 Correct the false claim at the negative-reading shape in
  `scripts/context-guard/differential.sh`: the harness cannot see the counting
  rule, and no shape can make it.
- [X] T038 Add section 9 to `specs/015-guard-jq-spawn-two/quickstart.md`, pinning
  the counting rule by process count on a straddling transcript. Executed: the
  shipped guard spends five, the mutant four, stdout identical.
- [X] T039 Replace the positive control in section 2 of the quickstart. Its `sed`
  pattern did not match the file, so it was a no-op that tripped the harness's
  identical-files guard; and the mutation it named is one the harness cannot see.
- [X] T040 Correct `config: maxBytes tiny` in the harness, which carried a
  million-token window and was silent on both sides. It was the only pre-existing
  shape touching the fallback. It now catches the floor control, taking that
  control's reach from two shapes to three.
- [X] T041 Use `mktemp -d` for the harness's scratch root, and record in
  `scripts/context-guard/README.md` that it executes the working tree's hook
  unsandboxed, plus the two things it structurally cannot see.
- [X] T042 Remove the duplicated FR-011 paragraph in `spec.md`, a paste artefact
  from a patch script re-run after a mid-way failure.
- [X] T043 Correct "no test was weakened" in `spec.md`, record the FR-001
  exception, and record that FR-008 has no automated coverage and FR-016 is
  pinned by process count rather than by the harness.
- [X] T044 Correct three stale comments in `handoff/tests/context-guard.bats`:
  the skill holding its rule inline, a count of six sites where there are seven,
  and two skill invocations where there is now one.
- [ ] T045 DEFERRED, with the reason recorded: `is_valid_threshold` accepts a
  threshold of exactly 100, but the percentage reaches 100 only once context has
  already filled the window, so such a guard can never fire — silently, which is
  what the comment directly above the function forbids. A repository
  configuration file can also silence the guard with a very large window. Both
  are pre-existing and both are behaviour changes, so neither belongs in a phase
  whose entire proof is that behaviour did not change. They need their own seed.
