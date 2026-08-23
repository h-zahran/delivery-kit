# Research: constitution — probe it, print it, offer it once

## R1 — Detection mechanism (the seed pins the observable, not the method)

- **Decision**: `constitutionSet` is computed from
  `.specify/memory/constitution.md` alone, unconditionally (the key is
  always emitted, spec-kit present or not):
  - file absent → `false`;
  - any NUL byte in the file's first 4KB (a UTF-16/32 save, BOM or
    not) → `false`, with a named warning — unparseable bytes fail
    toward offering, never toward `set`;
  - otherwise HTML comments — single-line and multi-line — and a
    leading UTF-8 BOM are stripped first; an UNCLOSED comment is kept
    as literal text (swallowing to end-of-file read a mostly-unfilled
    template as set, the one forbidden direction — measured both
    ways), then:
  - stripped body carrying one of the shipped template's OWN tokens
    (`[PROJECT_NAME]`, `[PRINCIPLE_n_NAME]`/`_DESCRIPTION`,
    `[SECTION_n_NAME]`/`_CONTENT`, `[GOVERNANCE_RULES]`,
    `[GUIDANCE_FILE]`, `[CONSTITUTION_VERSION]`, `[RATIFICATION_DATE]`,
    `[LAST_AMENDED_DATE]` — measured from the 0.16.5 template) →
    `false`;
  - stripped body with no non-blank content → `false`;
  - otherwise → `true`.

  Comment stripping is load-bearing, not polish: the constitution
  command itself prepends a Sync Impact Report comment full of
  bracketed tokens, so an unstripped placeholder grep would read the
  command's own output as "not set" and re-offer forever (found by the
  P2 PR review; the set fixture now carries both comment shapes so the
  `true` test guards the stripping).
- **Rationale**: measured against this repo's own fresh 0.16.5 init: the
  file is exactly the placeholder template. The placeholder grep needs no
  extra dependency and no state. The alternative marker —
  `.specify/memory/.constitution-template.json` records the template's
  sha256 — was rejected as the primary mechanism: the hash file is
  version-dependent (absent on older inits) and any whitespace edit
  defeats it while leaving the document just as unfilled. The P2 PR
  review (round 3) narrowed the placeholder check to the template's
  own token list: arbitrary bracketed prose (`[RFC2119]`, a checked
  `[X]` box) now reads `true`, and a justified retained slot that is
  NOT a template token (`[OPTIONAL_REVIEW_CADENCE]`) reads `true` —
  both measured. Named residual edges, all failing toward the SAFE
  direction (a re-offer the owner can decline, never a silent `set`):
  a written constitution keeping one of the template's own tokens
  outside comments reads `false`; an ASCII `-->` inside a comment
  closes it early (HTML semantics — `--` is not legal inside real
  HTML comments either), so a Sync Impact Report line naming a
  template token can leak and read `false` — measured. A line holding
  only exotic Unicode whitespace (U+00A0, U+200B) counts as content
  and can read a content-free file `true` — accepted, no test can
  cover it while the suite pin holds.
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
