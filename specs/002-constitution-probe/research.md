# Research: constitution — probe it, print it, offer it once

## R1 — Detection mechanism (the seed pins the observable, not the method)

- **Decision**: `constitutionSet` is computed from
  `.specify/memory/constitution.md` alone, unconditionally (the key is
  always emitted, spec-kit present or not):
  - file absent → `false`;
  - file present but carrying template placeholder tokens (regex
    `\[[A-Z][A-Z0-9_]*\]`, the `[PROJECT_NAME]` / `[PRINCIPLE_1_NAME]`
    shape a fresh `specify init` writes) → `false`;
  - file present with no non-blank, non-comment content → `false`;
  - otherwise → `true`.
- **Rationale**: measured against this repo's own fresh 0.16.5 init: the
  file is exactly the placeholder template. The placeholder grep needs no
  extra dependency and no state. The alternative marker —
  `.specify/memory/.constitution-template.json` records the template's
  sha256 — was rejected as the primary mechanism: the hash file is
  version-dependent (absent on older inits) and any whitespace edit
  defeats it while leaving the document just as unfilled. A human
  constitution containing any bracketed token that starts with a
  capital letter — `[LIKE_THIS]`, but also `[RFC2119]` or a checked
  `[X]` Markdown checkbox — is the known false-negative; accepted and
  recorded. The comment check is line-scoped: a file whose only content
  is a multi-line `<!-- … -->` block reads as `true` — the accepted
  false positive (the real 0.16.5 template's comments are all
  single-line).
- **Alternatives considered**: sha256 comparison against
  `.constitution-template.json` (rejected as primary — brittle, version
  dependent; the placeholder grep subsumes it); byte-size heuristics
  (rejected: arbitrary); parsing headings for "filledness" (rejected:
  over-modeling a free-form document).

## R2 — Fixture strategy

- **Decision**: two NEW plain-file fixture trees,
  `pipeline/tests/fixtures/constitution-unset/` (a `.specify/memory/constitution.md`
  in template-placeholder shape, plus the minimal `.specify` shape the
  existing fixtures carry) and `…/constitution-set/` (same shape, a
  short real constitution: named principles, no placeholders). Existing
  fixtures are NOT modified — the four current trees back other tests'
  assertions, and adding a constitution to them would change what those
  fixtures assert.
- **Rationale**: the tracked `.gitignore` re-includes
  `pipeline/tests/fixtures/**` wholesale, so plain files just work; the
  seed forbids dependent trees, and these carry none.
- **Alternatives considered**: reusing the `other` fixture with a
  constitution added (rejected: shared-fixture mutation risks the tests
  that already read it); creating the files inside the test with mktemp
  (rejected: the suite's convention is on-disk fixtures, and a fixture
  git cannot see is the exact failure the `.gitignore` comment warns
  about).

## R3 — Red-first evidence

- **Decision**: H appends the two tests FIRST, runs the focused suite,
  and records the two failures verbatim in the run's artifacts
  (SC-004); only then edits the script. The red run is proof the tests
  bind to the new key rather than passing vacuously.
- **Rationale**: the seed mandates "both seen red before the script
  change lands"; the house habit (prove a mutation landed) demands the
  echo of the red output, not a claim.

## R4 — Offer mechanics ("once per run")

- **Decision**: the offer lives in the orchestrator's pre-flight
  decision list as prose; "not repeated within a run" is recorded by
  the run state (`gates` key gets the answer when the offer is made).
  Declining writes the decline; a resume reads it and does not re-offer.
- **Rationale**: matches how every other gate answer is recorded, and
  the state file is the run's memory across resumes.
