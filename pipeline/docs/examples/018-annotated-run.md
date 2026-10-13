# An annotated run: specs/018-progress-commits-pieces

This repository builds itself with its own pipeline, and
`specs/018-progress-commits-pieces` is one small finished run. It added two
commands to the run-state helper, `progress.sh`: `commit-add` and
`piece-next`. Below is each file the run left, in the order the phases wrote
them, with what to look at. The letters are the
[phase reference](../phases.md)'s. The links work in a clone of this
repository; an installed plugin does not carry `specs/`.

## The files

1. **[spec.md](../../../specs/018-progress-commits-pieces/spec.md)**, phase B
   (specify). Its Input line names the seed: Phase 19 of this repository's
   plan file. Phase C (clarify) added the
   [Clarifications](../../../specs/018-progress-commits-pieces/spec.md#clarifications)
   section, two questions a human answered; the second narrowed the seed's
   rule for commit ids. Phase C.5 then audits the spec. Look at the Context's
   "Measured while writing this spec" paragraph, and at requirements marked
   "added at deep review" (phase I) or "added at pull-request review"
   (phase M): later phases write what they find back into the spec.
2. **[checklists/requirements.md](../../../specs/018-progress-commits-pieces/checklists/requirements.md)**,
   phase B. The spec tool's own quality checklist for the spec. Look at the
   notes at the end: two facts the seed did not carry, measured and written
   into the spec.
3. **[research.md](../../../specs/018-progress-commits-pieces/research.md)**,
   phase D (plan). Every decision rests on a dated measurement. Look for
   "Corrected at analyze": phase F's rounds fixed findings in place.
4. **[plan.md](../../../specs/018-progress-commits-pieces/plan.md)**, phase D.
   Look at the Constitution Check: D checks the plan against the project's
   constitution, principle by principle.
5. **[data-model.md](../../../specs/018-progress-commits-pieces/data-model.md)**,
   phase D. The two shapes an entry in the state file's `commits` list can
   take: the old bare id, and the new record.
6. **[contracts/progress-commands.md](../../../specs/018-progress-commits-pieces/contracts/progress-commands.md)**,
   phase D. Each command's arguments, output and refusals, word for word:
   what the tests hold the script to.
7. **[quickstart.md](../../../specs/018-progress-commits-pieces/quickstart.md)**,
   phase D. How to check the feature by hand, with the new tests run red
   against the old script first.
8. **[tasks.md](../../../specs/018-progress-commits-pieces/tasks.md)**,
   phase E (tasks), which also audits each task. Phase F checks it against
   the other files, and phase H marks each task `[X]` as it lands. Look at
   the three rules at the top that override every task, and at the file each
   task saves its output to.

## What is not here

- **The run directory**, `.delivery-kit/runs/018-progress-commits-pieces/`:
  the seed, the state file and every output the tasks saved. Git ignores it,
  so it stayed on the machine that ran the run.
- **A review guide.** This run built the commands that runs in pieces later
  used, so it came before them: it shipped as one feature commit, then one
  commit of fixes from the pull-request review. For what a run in pieces
  leaves, see [a sample review guide](review-guide.md).
