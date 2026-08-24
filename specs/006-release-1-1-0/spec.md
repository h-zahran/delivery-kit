# Feature Specification: release pipeline 1.1.0

**Feature Branch**: `006-release-1-1-0`

**Created**: 2026-08-24

**Status**: Draft

**Input**: Plan-of-record seed, `main-plan.md` Phase 6 — "release pipeline 1.1.0". Quoted verbatim in the run directory's `seed.md`.

## Clarifications

### Session 2026-08-24

- Q: The seed says three sites must agree, but the verification command it names (P1's jq line) can only read two of them — the changelog heading is markdown, not JSON. How should agreement be proven? → A: ONE command covering all three. Keep P1's jq line for the two JSON sites and extend the check so the changelog heading is read in the same run, yielding a single verdict over the whole acceptance criterion.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The version is stamped and the three sites agree (Priority: P1)

Somebody installing or updating the `pipeline` plugin needs one answer to "what version is this?", not three. Today three files each state a version independently — the plugin manifest, the marketplace listing, and the changelog's newest heading — and today all three say `1.0.1` while four completed features sit unreleased beneath an `[Unreleased]` heading. This story moves all three to `1.1.0` together.

**Why this priority**: it is the entire feature. Nothing else in this phase has value without it, and a partial stamp is worse than none — a marketplace that advertises a version the manifest does not carry is a broken install.

**Independent Test**: read the version out of each of the three sites and compare them. Fully testable by one command, with no dependency on any other story.

**Acceptance Scenarios**:

1. **Given** the three sites read `1.0.1`, **When** the stamp is applied, **Then** all three read `1.1.0` and a single comparison proves it.
2. **Given** the stamp is applied, **When** any one site is changed to disagree, **Then** the comparison fails rather than passing quietly.

---

### User Story 2 - The changelog closes the unreleased section (Priority: P2)

Four features — the constitution probe, the implementer handoff package, the implementer key, and the verification cap — have accumulated under `## [Unreleased]`. A reader wants to know which release contains them. This story converts that heading into a dated version heading, and changes nothing beneath it.

**Why this priority**: it is what makes the version number mean something. The stamp alone says "1.1.0 exists"; the heading says what is in it. It is P2 rather than P1 only because the version sites are what an installer reads first.

**Independent Test**: read the changelog's headings in order and confirm the newest is a dated `1.1.0` heading, and that the entries beneath it are byte-identical to what stood beneath `[Unreleased]` before.

**Acceptance Scenarios**:

1. **Given** the changelog opens with `## [Unreleased]`, **When** the heading is rewritten, **Then** the file opens with `## [1.1.0] - 2026-08-24` followed by the same entries in the same order.
2. **Given** the heading is rewritten, **When** the file's headings are listed, **Then** they read `1.1.0`, `1.0.1`, `1.0.0` — newest first, no `[Unreleased]` left behind and no second version heading introduced.
3. **Given** the rewrite, **When** the entry text beneath the heading is compared with the text before the rewrite, **Then** it is unchanged — nothing added, nothing removed, nothing reworded.

---

### User Story 3 - Nothing else moves (Priority: P3)

Whoever reviews this release needs to see at a glance that it is a version stamp and not a behaviour change riding inside one. This story is the constraint stated as an outcome: the shipped surface changes only where a version string or the one heading lives.

**Why this priority**: it protects the other two. A release commit that also edits behaviour cannot be reasoned about as a release, and this project has an existing rule that a governance or unrelated file never rides inside a feature's commit.

**Independent Test**: run the full suite and compare the count with the recorded baseline, and read the diff to confirm every changed line is a version string or the heading.

**Acceptance Scenarios**:

1. **Given** the stamp and heading are applied, **When** the full suite runs from the repository root, **Then** it reports the same counts as the baseline recorded before any edit.
2. **Given** the change, **When** the diff is read, **Then** every changed line is either a version string or the changelog heading.

---

### Edge Cases

- **The changelog gains no NEW heading.** `[Unreleased]` is REWRITTEN in place, not left standing above a fresh `1.1.0` heading. Two headings where one belongs would put the four accumulated entries under `[Unreleased]` and leave `1.1.0` empty — the exact inverse of the intent.
- **The entries beneath the heading are untouched.** The seed says "add nothing, remove nothing". A release phase that also edits release notes is no longer a release phase, and any such edit is a finding.
- **The marketplace file is at the repository root, not inside the plugin.** `.claude-plugin/marketplace.json` lists several plugins; only the entry whose name is `pipeline` moves. The `handoff` plugin's entry keeps its own version.
- **A partial stamp must fail loudly.** If any one of the three sites is missed, the agreement check reports it rather than passing on two out of three. The seed names P1's jq line for this, and that line reads only the two JSON manifests — a jq tool cannot read a markdown heading. Proving agreement with it ALONE would pass a tree whose changelog still says `[Unreleased]`, which is precisely the two-of-three failure this edge case exists to catch. Resolved at clarification: one command, three sites, one verdict.
- **The date is the release date, stated once.** `2026-08-24` appears in the heading and nowhere else; it is not derived at read time.
- **No tag is created by this run.** Tagging is a separate act the owner performs after the merge, per the seed. A run that tags would publish before the merge decision was made.
- **The suite count is a baseline comparison, not a target.** The seed states `1..121`; if the recorded baseline disagrees with that number, the BASELINE governs and the disagreement is itself reported, because a number written into a plan months earlier is not a measurement.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plugin manifest at `pipeline/.claude-plugin/plugin.json` MUST state version `1.1.0`.
- **FR-002**: The `pipeline` entry in the repository-root marketplace listing `.claude-plugin/marketplace.json` MUST state version `1.1.0`. No other plugin's entry changes.
- **FR-003**: `pipeline/CHANGELOG.md`'s `## [Unreleased]` heading MUST be REWRITTEN IN PLACE to `## [1.1.0] - 2026-08-24`. The file MUST NOT afterwards contain an `[Unreleased]` heading, and MUST NOT contain more than one `1.1.0` heading.
- **FR-004**: The content beneath that heading MUST be byte-identical before and after. No entry is added, removed, reordered or reworded.
- **FR-005**: Agreement across the three version sites MUST be provable by a SINGLE command that reads ALL THREE and yields ONE verdict. The two JSON sites are read as P1's acceptance reads them; the changelog heading is markdown and no JSON tool can see it, so the same command MUST also extract the version from the newest `## [` heading. Output is unambiguous: it reports agreement, or names the disagreeing site — never both and never neither. A check that proves two of three is a FAILED check, because the third site is the one a reader of the release notes actually sees.
- **FR-006**: The changelog's version headings MUST remain in descending order: `1.1.0`, then `1.0.1`, then `1.0.0`.
- **FR-006a**: The new heading's SHAPE MUST parse against the pattern the file already uses — `## [<major>.<minor>.<patch>] - <YYYY-MM-DD>` — and not merely equal the expected string. The seed's acceptance criteria name this separately from site agreement, and it catches a different defect: a heading that says the right version in the wrong form still breaks every tool that reads the file by pattern.
- **FR-007**: The full test suite MUST run from the repository root before the commit gate, and its result MUST be compared against the baseline recorded before any edit. Growth or shrinkage of the count is a finding.
- **FR-008**: No file outside the three named above is changed on the shipped surface. Specification artefacts under `specs/` are not a shipped surface and are exempt. In particular the orchestrator's grep-pinned prose is not touched at all by this phase, so the plan's "add near, never reword" constraint is satisfied by having nothing to reword — a fact to VERIFY in the diff, not to assume.
- **FR-010**: This phase MUST NOT add, re-queue or re-spend the prose-pin test debt. The plan's Global Constraints name P6 directly: that debt was PAID by P4 and is not to be re-opened. A new test here would also move the suite count, which FR-007 forbids.
- **FR-009**: This run MUST NOT create or push a git tag. Tagging follows the merge and is the owner's act.

### Key Entities

- **Version string**: the text `1.1.0`, appearing in two JSON files as a `version` field value and in one markdown heading. Its identity across all three is the feature.
- **Changelog heading**: a markdown heading of the shape `## [<version>] - <date>`, the newest of an ordered sequence. `[Unreleased]` is the same slot in its open state.
- **Baseline**: the recorded suite result taken before any edit in this run, against which the post-change run is classified.
- **Shipped surface**: the files a user of the plugin receives, enumerated by the `SHIPPED_*` lists in `tests/portability.bats` — the plugin manifests, `README.md`, `CHANGELOG.md`, `docs/`, `commands/` and the repository-root metadata. `specs/` is absent from those lists and is therefore NOT a shipped surface, which is why this feature's own specification artefacts are exempt from FR-008.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All three version sites read `1.1.0`, and ONE command reading all three proves it in a single verdict. Reading any single site is enough to know the release, because all three agree. A verdict covering only the two JSON sites does not satisfy this.
- **SC-002**: The changelog's three newest headings read `1.1.0` dated `2026-08-24`, then `1.0.1`, then `1.0.0`, and no `[Unreleased]` heading remains anywhere in the file.
- **SC-002a**: The new heading matches the file's existing heading pattern when tested by shape rather than by string equality — proving the file stays machine-readable, not just correct today.
- **SC-003**: The text beneath the new `1.1.0` heading is identical to the text that stood beneath `[Unreleased]` before the change — verified by comparison, not by inspection.
- **SC-004**: The full suite result after the change equals the baseline recorded before it, with zero non-TAP lines.
- **SC-005**: Every changed line on the shipped surface is a version string or the changelog heading — a reviewer can confirm the release contains no behaviour change by reading the diff alone.

## Assumptions

- **The release date is 2026-08-24**, the date this run executes. The seed writes it as `<today>`; it is resolved once, here, and written literally.
- **The version is 1.1.0 and the bump is minor, not patch.** The seed states it outright. It is the right shape regardless: four features were added and nothing was removed or broken.
- **The four accumulated entries are complete and correct as written.** They were reviewed when each feature shipped; this phase does not re-review them, and the seed forbids editing them.
- **The suite baseline is whatever this run measures before editing**, and the seed's `1..121` is the expectation against which that measurement is read — not a substitute for it.
- **No behaviour changes, so no new tests.** The suite exists to prove nothing broke, not to cover a version string. This is not a deferral and creates no debt: the plan's Global Constraints record the prose-pin debt as PAID by P4 and instruct P5 and P6 not to re-queue it.
- **The tag `pipeline-v1.1.0` is created by the owner after the merge**, outside this run, and the plan is complete when its CI is green.
