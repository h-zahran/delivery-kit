# Research: the implementer handoff package, upgraded

## R1 — Shape of the seven-part specification (the spec leaves it to the implementer)

- **Decision**: a compact Markdown list inside the G section, one item
  per part, each item opening with the part's bolded name followed by a
  dash and its content requirements. (Placement amended by H.7
  simplify: the list sits directly after the `--auto` gate sentence and
  before the VOID cleanup paragraphs, so "derived, as specified above"
  stays adjacent to the sentence it references — see the tasks-file
  H.7 note.)
- **Rationale**: the orchestrator already renders contract-ish shapes as
  lists and blocks (the probe block, the decision list, the gates
  table); a list keeps each name on its own greppable line, which keeps
  the prose test a plain fixed-string gate; prose would bury seven names
  in flowing text and invite rewording during future edits.
- **Alternatives considered**: a prose paragraph (harder to pin, easier
  to erode); a table (columns force content into cells — the parts have
  unequal depth); a separate reference file (rejected: the spec requires
  the specification IN the G section, and a second file is a second
  place to drift).

## R2 — Canonical part-name spellings (the test's fixed strings)

- **Decision**: the seven names, exactly as the plan of record spells
  them: `Files to provide`, `Repository state`, `Instructions`,
  `Forbidden list`, `What will bite this feature`,
  `Validation before "done"` (straight quotes), `Report-back contract`.
- **Rationale**: the seed names them; the test pins names, not shape, so
  the spellings are the contract. Straight quotes in
  `Validation before "done"` match the plan file's own bytes — a
  typographic-quote "improvement" would silently unpin the string.
- **Alternatives considered**: shortened names (rejected: the pin should
  match what a package author reads in the section); numbered parts
  (rejected: numbering invites renumbering, the P2 lesson).

## R3 — Test strategy: red-first for free, then mutation

- **Decision**: append the new prose test FIRST (one `@test` with seven
  `grep -qF` assertions against `pipeline/skills/pipeline/SKILL.md`,
  matching the file's existing style). With the G section unmodified,
  the test fails — that run is the recorded red. Then edit SKILL.md;
  the test passes. Then the mutation check: remove ONE part name via a
  targeted edit, run the focused test, observe red, restore the exact
  text, observe green. Both observations recorded in tasks.md
  Completion notes (SC-004).
- **Rationale**: the append-first order gives the red observation
  without scaffolding; the mutation check proves the test binds to each
  name rather than passing on a stale grep. Restore is a byte-exact
  re-insertion — never `git checkout --` (a never-bend rule).
- **Alternatives considered**: mutation on a copied file with a path
  override (rejected: prose.bats resolves the real path; adding an
  override would change shipped test plumbing for a one-time check).

## R4 — Where "What will bite this feature" content comes from

- **Decision**: the G text names the three sources the package derives
  it from: clarify answers recorded at C, decisions in the feature's
  research file, and anything discovered mid-run and recorded in the
  run's artifacts — each item in the package names its source; an empty
  list is stated as empty.
- **Rationale**: the seed mandates source-naming; the three sources are
  exactly where this pipeline records non-obvious knowledge (gates,
  research.md, completion notes), so the package assembles from records
  rather than memory.
- **Alternatives considered**: free-form "gotchas" (rejected: unsourced
  claims are what the report-back contract exists to prevent).

## R5 — Changelog wording (STRICT surface)

- **Decision**: the Added entry describes the upgraded package contract
  in plain words ("the implementer gate's handoff package now carries a
  seven-part contract…") and does not name banned spellings — the P2
  precedent for the same file.
- **Rationale**: `pipeline/CHANGELOG.md` sits on the STRICT vocabulary
  surface scanned word-bounded by the portability gate; hyphenated
  "spec-kit" spellings are the only safe way to reference the tool and
  are not needed here at all.
- **Alternatives considered**: none serious — the gate is a test.
