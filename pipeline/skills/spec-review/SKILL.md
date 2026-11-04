---
name: spec-review
description: Audit an implementation against its specification with three independent lenses — contract compliance, security, and tests. Use when a feature claims to be done and someone wants to know whether the spec agrees, or when the pipeline's deep-review phase runs.
---

# pipeline:spec-review

Read-only. This skill reviews; it never edits the working tree, and it
never fixes what it finds — findings go to the caller.

## Inputs

Ask for what is missing rather than guessing: the specification, the
plan and tasks files if they exist, and the change under review (a
branch range, a diff, or a directory). When invoked by the pipeline,
all four arrive in the invocation.

## The three lenses

Run all three as independent reviewers: three agents, one per lens,
dispatched together in one message, each given the same inputs and none
shown another's findings. That is what the pipeline's "three reviewers
in one message" means: together in time, independent in judgement.
Where agents cannot be dispatched, run the lenses one at a time, each
written down in full before the next begins, and never revise an
earlier lens's findings. Either way, findings from one lens never
soften another's, and no lens is skipped because another found nothing:

1. **Contract compliance.** Walk the specification requirement by
   requirement. For each: point at the code that implements it
   (file:line), or record it as MISSING. Then walk the diff the other
   way: anything implemented that no requirement asks for is EXTRA.
   Wrong-shape implementations (the right feature built the wrong way)
   are MISUNDERSTOOD.
2. **Security.** Inputs that reach a shell, a query, a path, or a
   network call without validation; secrets in code or logs; permissions
   widened; injection surfaces opened by the change.
3. **Tests.** Do the new tests verify behaviour, not mocks? Does every
   new requirement have a covering test? Would each test fail if its
   feature were broken (name the mutation that proves it)?

## The fault harness

A fault script breaks the code on purpose and checks that a test goes red.
Its mechanics are the harness: the throwaway copy, the test runner's path,
and the facts that make it run. The faults are what it tries. In a pipeline
run there is one harness, at `.delivery-kit/runs/<feature>/fault-harness.sh`,
and each brief names `<feature>`. With no run directory, this section does
not apply.

- The first actor that needs to plant a fault saves the harness there, with
  the facts it needed at the top, by writing a temporary file and renaming it.
  A later actor reuses and extends it, and never builds another. This binds
  phases H and J, and I's reviewers and fix step. Among agents running at
  once, the brief names the one that owns the file, and only it writes or
  repairs it. In phase I that is the tests reviewer.
- In phase I only the tests reviewer may create the harness. Another reviewer
  uses it if it exists, or else names the fault in its finding. I's fix step
  runs a fault named that way through the harness before it accepts or
  declines the finding.
- The tests reviewer writes its own faults to
  `.delivery-kit/runs/<feature>/faults-tests.txt` BEFORE it reads the harness.
  The harness shares mechanics, never a fault list, so judgement stays
  independent.
- Run every fault the work needs. Nothing caps the number of faults, and no
  lens is dropped because a harness exists.
- A harness works only on a throwaway copy, and runs from inside it. It never
  edits the working tree and never writes to git in the repository. A reviewer
  writes only in the run directory and in a temporary folder of its own.
- Each actor runs the harness once with no fault, and again after the harness
  or the tree changes. That run must stay green: a copy that cannot start its
  tests makes every fault read as caught.
- A harness reports a fault that changed no byte as a fault that did not land,
  never as a test that stayed green. A fault counts as caught only when the
  output shows the failing test's own `not ok` line.
- Before writing anything under the run directory for this, or running a
  harness or a faults file, read what is there, and from the repository's top
  run `git ls-files -- ':(literal,icase).delivery-kit'`. Only exit 0 with empty
  output lets it go on: a tracked file, link or submodule can bring a file to
  that path that git calls untracked. On any other answer, do not use that
  path, and say so. The first actor then keeps the harness in a temporary
  folder of its own, its report names the folder, and the rules above hold.
- A harness that breaks is repaired in place, and the fact that broke it is
  added at its top.

## Output

One report, in a form the caller can parse. Every finding is one line,
its four fields in this order, separated by ` | `:

`SEVERITY | lens | file:line | finding`

- SEVERITY is one of CRITICAL, HIGH, MEDIUM or LOW, in capitals: the
  words the pipeline counts its findings by.
- lens is `contract`, `security` or `tests`, the lens that found it.
- file:line is where the fault is. A MISSING requirement has no code to
  point at: give the specification's file and the requirement's line.
- finding is the rest of the line: what is wrong, why it matters, and
  how to fix it if not obvious. A contract finding starts with MISSING,
  EXTRA or MISUNDERSTOOD.

The severities:

- **CRITICAL** — broken functionality, data loss, a security hole.
- **HIGH** — a missed or misunderstood requirement, a test that asserts
  nothing.
- **MEDIUM** — a fault that does not break the feature today: an
  unvalidated edge, a test that misses a branch, a harmless EXTRA.
- **LOW** — polish; note and move on.

Order the lines by severity, CRITICAL first. After them, one count line,
every severity named even at zero:
`Findings: CRITICAL <n>, HIGH <n>, MEDIUM <n>, LOW <n>`.

End with a verdict: COMPLIANT, or the list of requirements that are not.
Never say "looks good" without the requirement-by-requirement walk —
an audit that skipped the walk is an opinion, not an audit.
