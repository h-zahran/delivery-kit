# Research: pipeline 1.0.1 — release-day truth and door polish

## R1 — How to measure whether the short form `/pipeline` resolves (FR-005)

- **Decision**: Measure in THIS live session, at implementation time, with one
  user keystroke: the owner types `/pipeline` (bare) once. Two observable
  outcomes, both safe for the live run:
  - It RESOLVES: the harness delivers a command invocation (a command-message
    for the pipeline front door). The orchestrator — this session — receives it,
    recognizes it as the measurement, answers its own resume prompt by
    continuing the live run, and records "resolves".
  - It DOES NOT resolve: the text arrives as a plain user message reading
    `/pipeline` (or the harness reports an unknown command). Recorded as
    "does not resolve in this harness".
  If neither observation can be made cleanly, the result is INDETERMINATE and
  the README carries no short-form claim at all — the seed says silence is the
  correct output for an unproven claim.
- **Rationale**: Only the field observation counts. The plan of record
  (gotcha #1 and requirement 5) forbids assuming; only `/pipeline:pipeline`
  has ever been observed to resolve. The measurement is same-session, so the
  run's lock is never contested and the state file already records the phase
  to re-enter.
- **Alternatives considered**: Reading Claude Code plugin-command documentation
  (rejected: docs describe intent, not this installed harness's behavior);
  probing the installed cache for command registration files (rejected: proves
  the file exists, not that the spelling resolves); skipping the measurement
  and hedging in the README (rejected: the requirement demands a measured
  sentence or none).
- **Outcome (recorded 2026-08-21, quoted from the run state file so a
  clone carries the record)**: "resolves — measured 2026-08-21 in this
  live session: bare /pipeline delivered the pipeline:pipeline command
  invocation (empty seed) in Claude Code with the plugin installed."
  The measurement covers the BARE form only; the README sentence is
  scoped to "typed bare" accordingly. Whether arguments forward through
  the short form was not measured, and no shipped sentence claims it.

## R2 — Insertion points for the four orchestrator sentences (FR-001..FR-004)

- **Decision**: Locate each anchor in `pipeline/skills/pipeline/SKILL.md` at
  implementation time by exact grep, and insert AFTER the anchor, touching no
  existing byte:
  - FR-001: the **O — release** paragraph's final sentence (anchor: "never
    under `--auto` alone.").
  - FR-002: the N.5 sentence ending "then continue." (anchor: "then
    continue."); the pinned "It never reports verification it did not do"
    follows and must remain byte-identical.
  - FR-003: the **G — implementer gate** paragraph (anchor: its final
    sentence, "it spends money.", which is itself pin-adjacent — the pinned
    string "`--auto` never collapses" text must survive).
  - FR-004: the **Ground rules** bulleted list (append one bullet after the
    last existing bullet, matching list style).
- **Rationale**: "Add near, never reword" is the Global Constraint; grep-first
  placement proves the anchor exists before any edit, and the prose pin suite
  (`prose.bats`, 1..8) is the empirical gate that nothing pinned moved.
- **Alternatives considered**: Rewriting paragraphs for flow (forbidden:
  reword risk on pinned strings); inserting before the anchor (rejected: the
  seed specifies "after its final sentence" / "after the sentence ending").

## R3 — Changelog and stamp mechanics (FR-006)

- **Decision**: Insert `## [1.0.1] - <ship day>` (shipped 2026-08-22
  after the calendar rolled at the commit gate) directly above
  `## [1.0.0] …` in `pipeline/CHANGELOG.md`, entries
  under a `### Fixed`/`### Changed` shape matching the file's existing style,
  count-free. Stamp `pipeline/.claude-plugin/plugin.json` and the pipeline
  entry of `.claude-plugin/marketplace.json` with jq-verified edits.
- **Rationale**: two suite gates parse the heading shape
  `## [X.Y.Z] - YYYY-MM-DD` (exactly one space each side of the
  hyphen); the acceptance jq line is pinned in the seed.
- **Alternatives considered**: An `## [Unreleased]` intermediate (rejected:
  the plan of record gives 1.0.1 its own immediate stamp in this phase;
  `[Unreleased]` first appears in Phase 2).

## R4 — README "How it runs" surface rules (FR-005)

- **Decision**: All three example invocations become `/pipeline:pipeline …`
  (the only spelling observed to resolve). The short-form sentence is written
  only from R1's recorded result. STRICT surface: hyphenated spec-tool
  spellings only, banned word list per Global Constraints.
- **Rationale**: The README is the front door; a wrong example fails every
  new user at the first keystroke.
- **Alternatives considered**: none viable — the requirement pins both the
  canonical spelling and the measure-first rule.
