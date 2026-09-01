---

description: "Task list for 013-preflight-git-probe"
---

# Tasks: Pre-flight names git

**Input**: Design documents from `/specs/013-preflight-git-probe/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md),
[research.md](./research.md), [data-model.md](./data-model.md),
[contracts/capabilities.md](./contracts/capabilities.md),
[quickstart.md](./quickstart.md)

**Tests**: Test tasks ARE included and come FIRST. SC-003 requires both new
tests to be observed failing before the probe change lands, so the order below
is load-bearing, not stylistic.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel — different files, no dependency on incomplete work
- **[Story]**: which user story the task serves
- Every task names the exact files it touches

## Path Conventions

This repository is a plugin tree, not a `src/`+`tests/` project. The paths are:

- probe script: `pipeline/scripts/preflight.sh`
- probe suite: `pipeline/tests/preflight.bats`
- orchestrator: `pipeline/skills/pipeline/SKILL.md`
- prose pins: `pipeline/tests/prose.bats`
- changelog: `pipeline/CHANGELOG.md`
- configuration page: `pipeline/docs/configuration.md`

---

## Phase 1: Setup — re-measure what the plan assumed

- [X] T001 [P] Re-measure that `pipeline/docs/configuration.md` names no
      external tool, by grepping it for `jq`, `gh`, `adb` and `git`. If the grep
      is empty, FR-011 resolves to "do not edit"; record that. If it is not
      empty, stop and re-plan — the plan's Finding C has gone stale.
- [X] T002 [P] Re-measure that `PROBE_TOOLS` in `pipeline/tests/preflight.bats`
      still reads `awk git grep head jq od`. The absent-git test is built by
      omitting `git` from that list; if the list has changed, the test must be
      built from the new list, not from this one.
- [X] T003 Record the pre-change suite count. Run the full house suite from the
      repository root, redirect stdout to a file (never a pipe — a pipe hands
      the block `tail`'s exit status and cuts the plan line), and record the
      plan line, the `ok` count and the `not ok` count. This is the number the
      acceptance delta of +2 is measured against.

---

## Phase 2: Foundational

None. This feature adds no shared infrastructure; every change is an addition
to a file that already exists.

---

## Phase 3: User Story 1 — a machine without git is told so (Priority: P1)

**Goal**: `preflight.sh` reports whether git can be found.

**Independent test**: run the probe against a search path with no git; the
report says the git capability is absent and the report is still complete.

### Tests first — both must be seen RED

- [X] T004 [US1] Append a test to `pipeline/tests/preflight.bats` asserting that
      with a search path built from the full `PROBE_TOOLS` list,
      `capabilities.git` reads `true` and the probe exits `0`. Use the existing
      `shimdir` and `probe --path` helpers; invent no new mechanism.
- [X] T005 [US1] Append a second test to `pipeline/tests/preflight.bats`
      asserting that with a search path built from `PROBE_TOOLS` **minus git**,
      `capabilities.git` reads `false`, the probe still exits `0`, stdout still
      parses, and `willSkip` holds exactly the phases `L` and `M` — the two
      entries the existing no-remote branch produces once git's absence makes
      the remote unreadable, and no entry attributable to git itself. Same file
      as T004, so this task is sequential after it, never parallel with it.
- [X] T006 [US1] Run `pipeline/tests/preflight.bats` and record BOTH new tests
      failing, quoting the failure output. A test that passes here is testing
      nothing — stop and fix it before going further. This is SC-003's evidence
      and it cannot be produced after T007.

### Then the change

- [X] T007 [US1] Edit `pipeline/scripts/preflight.sh`: add
      `git_present=false; command -v git >/dev/null 2>&1 && git_present=true`
      immediately BEFORE the existing `gh_present` line, so the three
      `command -v` probes sit together, matching the shape the `gh` and `adb`
      probes already use; then add `--argjson git "$git_present"` to the closing
      `jq -n` call and `git: $git` inside the `capabilities` object, placed
      after `jq` so the two hard requirements read first. Both edits are to one
      file and neither works without the other, so they are one task.
- [X] T008 [US1] Re-run `pipeline/tests/preflight.bats`. Both new tests now
      pass. Record the output.

---

## Phase 4: User Story 2 — existing consumers are unaffected (Priority: P1)

**Goal**: nothing that already reads the report breaks.

**Independent test**: every pre-existing test passes, unedited.

- [X] T009 [US2] Run `git diff -- pipeline/tests/preflight.bats` and confirm the
      diff is additions only — no pre-existing test line changed. An edited
      existing test would falsify SC-004 even with the suite green.
- [X] T010 [US2] Run `git diff -- pipeline/scripts/preflight.sh` and confirm no
      pre-existing key in the `jq -n` output block changed its name, its type or
      its meaning. Key order may differ; names, types and meanings may not.

---

## Phase 5: User Story 3 — the absence is a stop, not a degradation (Priority: P2)

**Goal**: the orchestrator names git and stops, before every other pre-flight
decision.

**Independent test**: read the changed orchestrator; decision item 11 exists,
states that it fires first, names the download page, and says git is never a
`willSkip` entry.

- [X] T011 [US3] Edit `pipeline/skills/pipeline/SKILL.md`: add a `git` line to
      the fenced probe block itself, immediately before the `Base branch` line —
      a reader who sees git absent then understands the empty base branch on the
      next line. Pad the label to match the block's alignment, and point the
      line at decision 11. There is precedent for calling out one capability on
      its own line: the `Remote` line already does it for `gh`. Reword no
      existing line; the block is sliced by `pipeline/tests/prose.bats` and the
      `Implementer` line inside it is pinned verbatim.
- [X] T012 [US3] Edit `pipeline/skills/pipeline/SKILL.md`: after decision item
      10 and before the `**Base branch:**` paragraph, add decision item **11**
      for `capabilities.git` false. It must say: the run stops; the item fires
      before item 1 and before every other decision on the list, and is
      numbered last only so items 1–10 keep their numbers; items 5 and 6
      themselves call git, and phases B, K and L are git operations; print
      `https://git-scm.com/downloads`; record the answer, install nothing; and
      git is a capability, never a `willSkip` entry. Same file as T011, so
      sequential after it. Renumber no existing item and reword none.

---

## Phase 6: Polish and cross-cutting

- [X] T013 [P] Add an `### Added` entry to `pipeline/CHANGELOG.md` under the
      existing `## [Unreleased]` heading, naming both the git probe and the
      stop, and saying why it is a stop rather than a skip. This file is a
      STRICT vocabulary surface: write "spec tool", never the tool's package
      name, and state no count that a later change falsifies.
- [X] T014 [P] Act on T001's measurement: if `pipeline/docs/configuration.md`
      enumerates no capability, leave it untouched and say so. Do not edit it
      on the plan's say-so alone.
- [X] T015 Run `pipeline/tests/prose.bats`. Green proves no pinned string was
      reworded by T011 or T012.
- [X] T016 Analyse the changed script the way CI does:
      `shellcheck --norc -f gcc -- pipeline/scripts/preflight.sh`. Note that CI
      runs an OLDER analyser than this machine and the older one reports more,
      so a local green is evidence, not proof — CI is the arbiter.
- [X] T017 Run the full house suite from the repository root, redirecting to a
      file. Expect exactly three more tests than T003 recorded, `not ok` count
      `0`, `0` non-TAP lines, and exit `0`. (Was two. Raised by the owner at the
      review cap — see T019.)
- [X] T018 Execute [quickstart.md](./quickstart.md) — run every block in it,
      do not read it. A block that reads fine and does not run is the defect
      this task exists to catch.

---

---

## Phase 7: Convergence — added at the review cap, on the owner's instruction

Three review rounds each independently found that the feature's own behaviour
was guarded by nothing: decision item 11 and the `git` probe-block line could be
deleted with every suite green. Closing it needs a third new test, which the
seed's stated acceptance forbade. The pipeline stopped at the review cap and
asked; the owner chose the guard over the count.

- [X] T019 Add one test to `pipeline/tests/prose.bats` pinning the git stop in
      all three regions it lives in — the probe block, the region holding the
      not-read rule, and the decision walk. Slice each region rather than
      grepping the file, because a file-wide pin is satisfied by text pasted
      into an appendix; that exact defeat is recorded in the suite already. Pin
      through the operative clause, never the heading alone. Then MEASURE the
      pin's reach with mutations at its edges — do not trust its green — and
      confirm each mutation landed before believing the red it produces.

## Dependencies

```text
T001, T002  (parallel)
   ↓
T003  baseline count
   ↓
T004 → T005 → T006 (RED proof)  ← same file, strictly sequential
   ↓
T007 (the probe)
   ↓
T008 (GREEN)
   ↓
T009, T010  (parallel — different files, read-only)
   ↓
T011 → T012  ← same file, strictly sequential
   ↓
T013, T014  (parallel — different files)
   ↓
T015, T016  (parallel — different commands)
   ↓
T017 → T018
```

**The one ordering that cannot be relaxed**: T006 before T007. The RED proof is
unobtainable once the probe lands, and SC-003 requires it.

## Parallel opportunities

| Batch | Tasks | Why safe |
|---|---|---|
| A | T001, T002 | two read-only greps of two different files |
| B | T009, T010 | two read-only diffs of two different files |
| C | T013, T014 | changelog and configuration page are different files |
| D | T015, T016 | two different commands, neither writes |

Everything else is serialised. T004/T005 and T011/T012 each edit one shared
file and must never run concurrently.

## Implementation strategy

There is no MVP split worth making — the feature is one probe and one decision,
and User Story 1 alone would ship a named capability nobody acts on, which is
the exact failure the seed calls out. Do all three stories.

Suggested order: Phase 1 → 3 → 4 → 5 → 6, exactly as numbered.
