# Package contract — the seven parts, and what stays byte-identical

## The seven part names (quoted contract; the prose test's fixed strings)

1. `Files to provide`
2. `Repository state`
3. `Instructions`
4. `Forbidden list`
5. `What will bite this feature`
6. `Validation before "done"` (straight quotes)
7. `Report-back contract`

All seven appear by name in the **G — implementer gate** section of
`pipeline/skills/pipeline/SKILL.md`. Shape WAS the implementer's
choice; R1 chose the compact bolded list and the reviews bound the
test to it — the names and that bullet form are now both the pin.

## Each part's content (what the G section must specify)

| Part | Content the package carries |
|---|---|
| Files to provide | A table of the spec artefacts — spec, plan, tasks, research, contracts, quickstart, data-model where present — with absolute paths, each verified to exist before the package is written; the verification is stated in the package |
| Repository state | Branch (checked out), tree state, the verbatim F.5 test baselines, plus the analyzer baseline where one exists; the package instructs its reader to reconcile these claims against actual git state before touching anything, stopping on mismatch |
| Instructions | Task order and phase groupings from the tasks file; `[P]`-marked tasks in the same phase may run concurrently, capped by `maxParallelAgents` with never two tasks on one file (the package carries the cap's value — its reader cannot see the orchestrator document); mark each completed task `[X]`; never restructure spec.md, plan.md or tasks.md; the per-phase verification command, drawn from `testCommand` and the tasks file's own checkpoints (`verifyCommand`, where set, belongs to the forbidden list — a required-vs-forbidden collision is reported in the package, never resolved silently); and the stop rule: a red the packaged F.5 baseline does not carry is a full stop — report it, never mark `[X]` past it — while an inherited red is reported, never owned |
| Forbidden list | Derived, as the existing G sentence already specifies — and the derivation carries the never-bend destructive-git rule (`git reset --hard`, `git clean`, `git checkout --` on tracked files) and ADDS `git stash` beside it (the table itself holds three verbs; stash is this contract's addition — it hides work as surely as the others discard it): the package's reader inherits all four without seeing the orchestrator's table |
| What will bite this feature | The run's accumulated non-obvious knowledge, derived from clarify answers, research-file decisions, and mid-run recorded discoveries — each item names its source; empty is allowed but stated as empty |
| Validation before "done" | A checklist with the exact commands and the baseline numbers |
| Report-back contract | The implementer keeps a visible todo board while working, leaves work uncommitted, and reports: status, files touched, test output verbatim, and anything it could not do |

Redaction binds every part: where a source holds a credential, an
endpoint or a token, the package carries the fact and its location,
never the value (added by the P3 deep review).

The park (added by the PR review, spec FR-004): a "handoff" answer
records the gate answer in `gates` and the package path in
`artifacts`, runs `phase-done <feature> G` then
`phase-start <feature> H`, releases the lock, and stops — so a plain
`--resume` re-enters H rather than re-asking the G gate. The resume
consumes the report per the Report-back contract BEFORE any dispatch:
verify each claimed `[X]` against the uncommitted diff, run the full
verification once over the claimed-complete work, take over the
could-not-do list, dispatch only unclaimed tasks.

## What stays byte-identical (the add-near pins)

Every pre-existing sentence of the G section, three called out:

- The derived-forbidden-list sentence ("The package's forbidden list is
  DERIVED, not hardcoded: …").
- The P1 VOID sentence ("If the gate's answer later changes, delete the
  written package file (or stamp it VOID at the top) …") and its
  follow-on paragraph.
- "`--auto` never collapses this gate: it spends money."

## The test

One new `@test` appended to `pipeline/tests/prose.bats` (no new file).

### Mechanics (final shape, after the deep review and three PR-review rounds)

The test:

1. Slices the G section (awk between the G and H headings), then
   asserts the slice OPENS on the G heading, TERMINATES on the H
   heading (a reworded H anchor cannot silently extend the slice to
   end-of-file), and contains no other heading-shaped line — neither
   bold-led `**…**` lines nor Markdown `#` headings — with a
   diagnostic that prints any offender rather than blaming the
   anchors.
2. Greps the slice for the bolded bullet form `- **<name>**` of each
   of the seven names.
3. Flattens the slice's whitespace (`tr '\n' ' '`, squeezed) and pins
   WHOLE sentences against the flat text — wrap-independent and
   seam-free, after measured mutants showed fragment islands left the
   words between them unguarded and wrap-cut fragments broke on
   cosmetic reflow: the full derived-forbidden-list sentence (from
   "forbidden list is DERIVED…" through "…found in the tasks file."),
   the `--auto` gate sentence, the VOID sentence from "answer later
   changes…" (the leading context defeats prefix polarity inversion),
   and the park sentence's opening (`A "handoff" answer parks the run
   at H:`).

Counts: prose `1..8` → `1..9`; house suite `1..118` → `1..119`; growth
exactly +1.
Counts: prose `1..8` → `1..9`; house suite `1..118` → `1..119`; growth
exactly +1.
