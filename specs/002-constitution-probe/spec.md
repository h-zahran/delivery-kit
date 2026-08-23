# Feature Specification: constitution — probe it, print it, offer it once

**Feature Branch**: `002-constitution-probe`

**Created**: 2026-08-22

**Status**: Draft

**Input**: User description: "Phase 2: constitution — probe it, print it, offer it once. spec-kit's constitution gates the plan phase, but a fresh init leaves an unfilled template and the pipeline never says so. Make its state visible and offer the fix."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The pre-flight report says whether a constitution exists (Priority: P1)

An operator starts a pipeline run in a repository where `specify init` ran but nobody ever wrote project principles. Today the plan phase quietly gates against an empty document. After this change, the pre-flight probe block prints a `Constitution` line — `set`, or `not set — plan gates run against an empty document` — and, when it is not set, the pipeline OFFERS to run `/speckit-constitution` once. The principles are the owner's to write: declining is fine, and the offer is not repeated within a run.

**Why this priority**: This is the visible half of the feature — the silence it removes is the reason the phase exists. This repo's own runs hit it twice (001's plan phase recorded "unfilled template, no gates derive" by hand).

**Independent Test**: Run pre-flight in a fresh-init-shaped repo: the probe block carries the `not set` line and the offer appears once. Answer no: the run proceeds and the offer never returns in that run.

**Acceptance Scenarios**:

1. **Given** a repository whose constitution is the unfilled template, **When** pre-flight renders the probe block, **Then** it contains a `Constitution` line reading `not set — plan gates run against an empty document`, and the decision list offers `/speckit-constitution` exactly once for the whole run.
2. **Given** a repository whose constitution carries real principles, **When** pre-flight renders the probe block, **Then** the `Constitution` line reads `set` and no offer is made.
3. **Given** the operator declines the offer, **When** the run continues through its phases, **Then** the offer is not repeated within that run.

---

### User Story 2 - The probe script exposes the fact as data (Priority: P2)

A script or harness consuming `pipeline/scripts/preflight.sh` output gets one new boolean, `speckit.constitutionSet`. The observable contract is pinned; the detection mechanism is the implementer's choice: a constitution file as `specify init` leaves it (unfilled template, or absent) → `false`; a constitution a human has actually written → `true`. Everything else about the script's external contract is unchanged — same flags, same keys, stdout still pure JSON.

**Why this priority**: The skill text can only print what the script emits; the boolean is the load-bearing half, but invisible without US1.

**Independent Test**: Run the script against a fresh-init-shaped fixture and read `"constitutionSet": false` from its JSON; against a fixture with written principles, `true`; `jq .` parses the whole stdout both times.

**Acceptance Scenarios**:

1. **Given** a fixture repo shaped like a fresh `specify init` (unfilled constitution template), **When** `preflight.sh` runs against it, **Then** its JSON carries `"constitutionSet": false` under `speckit`.
2. **Given** a fixture whose constitution carries real principles, **When** `preflight.sh` runs, **Then** the JSON carries `"constitutionSet": true`.
3. **Given** a repo with no constitution file at all, **When** `preflight.sh` runs, **Then** `"constitutionSet": false` — absence and the unfilled template are the same answer.
4. **Given** any of the above, **When** the output is compared to the previous contract, **Then** the same flags are accepted, all previously emitted keys are present unchanged, and stdout is pure JSON.

---

### User Story 3 - The tests exist first, and fail first (Priority: P2)

A test author finds two new bats tests appended to `pipeline/tests/preflight.bats` — no new test file — one proving `false` on a fresh-init-shaped fixture, one proving `true` once the file carries real principles. Both are SEEN RED before the script change lands: test-first, with the red run recorded.

**Why this priority**: The seed mandates test-first; the red observation is the evidence the tests test something.

**Independent Test**: Repo history / run records show both tests failing against the unmodified script, then passing after the script change; the suite grows `1..116` → `1..118`.

**Acceptance Scenarios**:

1. **Given** the two new tests and the UNMODIFIED script, **When** the focused suite runs, **Then** both new tests fail (red observed and recorded).
2. **Given** the script change, **When** the focused suite runs again, **Then** both pass, and the full house suite reports `1..118`, 0 non-TAP.

---

### Edge Cases

- Constitution file entirely absent → `false`, same as the unfilled template (US2/AC3).
- Fixtures: no new fixture directory trees with dependencies — anything under `pipeline/tests/fixtures/` is re-included wholesale by the tracked `.gitignore`, so a fixture must stay a plain file tree.
- The exact probe-line wordings are contract: `set` and `not set — plan gates run against an empty document`.
- The changelog gains `## [Unreleased]` ABOVE `## [1.0.1] …`; no version is stamped in this phase — `[Unreleased]` accumulates until the 1.1.0 release phase.
- The offer is once per RUN, not once per repository: a later fresh run in the same repo may offer again.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `pipeline/scripts/preflight.sh` MUST emit one new boolean, `speckit.constitutionSet`: `false` for a constitution file as `specify init` leaves it (unfilled template, or absent); `true` for a constitution a human has actually written. The detection mechanism is the implementer's; the observable is pinned. The external contract is otherwise unchanged — same flags, same keys, stdout still pure JSON.
- **FR-002**: Two new bats tests MUST be appended to `pipeline/tests/preflight.bats` (no new test file): one proving `false` on a fresh-init-shaped fixture, one proving `true` once the file carries real principles. Both MUST be seen red before the script change lands, and the red observation recorded.
- **FR-003**: `pipeline/skills/pipeline/SKILL.md` MUST gain, in the pre-flight probe block, a `Constitution` line (`set` / `not set — plan gates run against an empty document`), and in the pre-flight decision list: when `constitutionSet` is false, OFFER running `/speckit-constitution` once — the principles are the owner's to write, declining is fine, and the offer is not repeated within a run.- **FR-004**: `pipeline/CHANGELOG.md` MUST gain `## [Unreleased]` (created by this phase, above `## [1.0.1] …`) with an Added entry for the probe and the offer.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The two new tests pass and the full house suite reports `1..118`, 118 ok, 0 non-TAP lines.
- **SC-002**: `preflight.sh` against a fresh-init-shaped fixture prints `"constitutionSet": false`; against a written one, `true`; stdout parses as JSON both times.
- **SC-003**: All pinned strings survive: `pipeline/tests/prose.bats` reports 1..8, all ok.
- **SC-004**: The red-first evidence for both new tests is recorded in the run's artifacts before the script change lands.

## Assumptions

- No version stamp in this phase: `plugin.json` and the marketplace entry stay `1.0.1`; `## [Unreleased]` accumulates entries through the later phases until the 1.1.0 release phase stamps it.
- "Fresh-init-shaped fixture" means a plain directory tree under `pipeline/tests/fixtures/` carrying a constitution file with the template's placeholder shape; the true-case fixture carries recognizably human principles. No fixture requires installing anything.
- `preflight.sh` and `pipeline/tests/` are RELAXED vocabulary surfaces; `pipeline/CHANGELOG.md` is STRICT (hyphenated spec-tool spellings only). The SKILL.md probe-line wordings are quoted contract text.
- Global Constraints of the plan of record apply throughout; suite growth is exactly +2 (`1..116` → `1..118`) — any other movement is a finding.
