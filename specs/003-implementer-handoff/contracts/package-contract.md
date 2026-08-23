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
`pipeline/skills/pipeline/SKILL.md`. Shape is the implementer's choice
(research R1 chose a compact list); the names are not.

## Each part's content (what the G section must specify)

| Part | Content the package carries |
|---|---|
| Files to provide | A table of the spec artefacts — spec, plan, tasks, research, contracts, quickstart, data-model where present — with absolute paths, each verified to exist before the package is written; the verification is stated in the package |
| Repository state | Branch (checked out), tree state, the verbatim F.5 test baselines, plus the analyzer baseline where one exists |
| Instructions | Task order and phase groupings from the tasks file; `[P]`-marked tasks in the same phase may run concurrently, capped by `maxParallelAgents` with never two tasks on one file (the package carries the cap's value — its reader cannot see the orchestrator document); mark each completed task `[X]`; never restructure spec.md, plan.md or tasks.md; the per-phase verification command |
| Forbidden list | Derived, as the existing G sentence already specifies — and the derivation carries the never-bend destructive-git rule (`git reset --hard`, `git clean`, `git checkout --` on tracked files, `git stash`): the package's reader inherits it without seeing the orchestrator's table |
| What will bite this feature | The run's accumulated non-obvious knowledge, derived from clarify answers, research-file decisions, and mid-run recorded discoveries — each item names its source; empty is allowed but stated as empty |
| Validation before "done" | A checklist with the exact commands and the baseline numbers |
| Report-back contract | The implementer keeps a visible todo board while working, leaves work uncommitted, and reports: status, files touched, test output verbatim, and anything it could not do |

Redaction binds every part: where a source holds a credential, an
endpoint or a token, the package carries the fact and its location,
never the value (added by the P3 deep review).

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
Mechanics, tightened by the P3 deep review: the test slices the G
section (between the G and H headings) and greps the SLICE for the
bolded bullet form `- **<name>**` of each of the seven names — so a
relocation out of G, or a generic word like `Instructions` appearing
elsewhere in the document, cannot keep it green. The same test pins
three byte-identity fragments inside the slice: the derived-list
sentence's opening, the `--auto` gate sentence, and the VOID fragment.
Counts: prose `1..8` → `1..9`; house suite `1..118` → `1..119`; growth
exactly +1.
