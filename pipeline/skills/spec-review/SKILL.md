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

Run all three, as independent passes — findings from one lens never
soften another's:

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

## Output

One report, findings ordered by severity, each with file:line, what is
wrong, why it matters, and how to fix it if not obvious:

- **Critical** — broken functionality, data loss, a security hole.
- **Important** — a missed or misunderstood requirement, a test that
  asserts nothing.
- **Minor** — polish; note and move on.

End with a verdict: COMPLIANT, or the list of requirements that are not.
Never say "looks good" without the requirement-by-requirement walk —
an audit that skipped the walk is an opinion, not an audit.
