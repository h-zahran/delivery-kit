# The handoff package

Phase G's "handoff" answer writes a package into the run directory,
`.delivery-kit/runs/<feature>/`, for a cheaper model to implement from. The
pipeline skill reads this page before it writes one. The package's
forbidden list is derived as phase G describes in the skill.

The package carries seven parts, each present by name:

- **Files to provide** — a table of the spec artefacts (spec, plan,
  tasks, research, contracts, quickstart, data-model where present)
  with absolute paths, each verified to exist before the package is
  written, as the package states.
- **Repository state** — the branch (checked out), the tree state, and
  the verbatim baselines recorded at F.5 (test counts), plus the
  analyzer baseline where one exists — so any new failure is provably
  the implementer's. The package tells its reader to reconcile these
  claims with the git state before touching anything, and to stop on a
  mismatch.
- **Instructions** — task order and phase groupings from the tasks
  file; `[P]`-marked tasks in the same phase may run concurrently,
  capped by `maxParallelAgents`, never two on one file (the package
  carries the cap's value — its reader cannot see this document); mark
  each completed task `[X]`; never restructure spec.md, plan.md or
  tasks.md; the per-phase verification command, drawn from
  `testCommand` and the tasks file's own checkpoints (`verifyCommand`,
  where set, belongs to the forbidden list — a collision between a
  required command and a forbidden string is reported in the package,
  never resolved silently); and the stop rule: a red the packaged F.5
  baseline does not carry is a full stop — report it, never mark `[X]`
  past it — while an inherited red is reported, never owned.
- **Forbidden list** — derived, as phase G of the skill specifies, plus the
  destructive-git rule below.
- **What will bite this feature** — the run's accumulated non-obvious
  knowledge, derived from the clarify answers recorded at C, the
  decisions in the feature's research file, and anything discovered
  mid-run and recorded in the run's artefacts — each item names its
  source. Empty is allowed but must be stated as empty.
- **Validation before "done"** — a checklist with the exact commands
  and the baseline numbers.
- **Report-back contract** — the implementer keeps a visible todo board
  while working, leaves work uncommitted, and reports: status, files
  touched, test output verbatim, and anything it could not do.

Redaction binds every part: where a source holds a credential, an
endpoint or a token, the package carries the fact and its location,
never the value. And the derivation carries the never-bend table's
destructive-git rule — no `git reset --hard`, no `git clean`, no
`git checkout --` on tracked files — and adds a fourth imperative of
its own: no `git stash`. Stash hides work as surely as the others
discard it; the prohibition binds the package's reader and this
orchestrator alike, resumed trees included, and an uncommitted tree
is the one place with no recovery point.
