# Feature Specification: The guard's own configuration cannot silence it

**Feature Branch**: `017-guard-config-bounds`

**Created**: 2026-09-04

**Status**: Draft

**Input**: Phase 18 seed, `main-plan.md:1794-1980`. Deferred at Phase 17 as T045, `specs/015-guard-jq-spawn-two/tasks.md:220-226`.

## Overview

The context guard exists to interrupt a session before it runs out of room to
finish its work. It reads three settings from configuration: a window size, a
percentage of that window, and an absolute token count. Every invalid value is
already ignored, and the previously resolved value stands — the guard's stated
contract is that **no invalid value can disable it**.

Two settings break that contract while looking perfectly valid.

The two are **not symmetric**, and the difference decides the shape of this
work. The first has a correct answer that nobody disputes. The second is a
design ruling the owner has not made, and this specification deliberately does
not make it either.

## Clarifications

### Session 2026-09-04

- Q: A window size set far too large silently disarms the guard. What should happen? → A: **No change. Record the ruling.** The second defect closes as a considered non-change; the first ships alone.

  **Why**, recorded so it is not re-proposed: every candidate remedy — a ceiling, or a notice — needs a number nobody can justify, and that number catches the wrong cases. A limit that refuses 100,000,000 still admits 2,000,000, and 2,000,000 on a 200,000-capacity session disarms the guard just as completely. So a limit would block absurd values while admitting the plausible-but-wrong ones people actually type, and would buy that false assurance by reversing a position the project has already taken twice — in the closed decision that ruled the too-large case undetectable from inside, and in the documentation that records the hazard with a measurement.

- Q: Could the existing misconfiguration report be made to fire on its own, catching the too-large case without a ceiling? → A: **No — that candidate is not viable, and this was measured, not reasoned.**

  The existing report is guarded by a test that fires only when observed context EXCEEDS the configured window. A window set too large makes that condition permanently false, so the report can never see the case it was proposed to catch. Making it independent of an emission would change WHEN it can speak, never WHETHER it can detect this. Catching the too-large case would require an entirely new detector, not a change to this one. The seed listed this candidate; it is struck.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A percentage that can never arrive in time (Priority: P1)

Somebody sets the warning percentage to 100. It is a whole number, it is
positive, it is not obviously wrong, and every existing check accepts it. But
a session only reaches 100% of its window once the window is already full —
far too late for the guard's purpose, which is to interrupt while there is
still room to wrap up. In practice the guard never warns them again, and
nothing tells them so. They discover it when a session dies mid-task.

**Why this priority**: This is the guard's one forbidden failure — going quiet
without saying so. The system already states this rule in its own explanatory
text; it simply does not enforce it at the boundary.

**Independent Test**: Set the percentage to 100, run a session past the point
where the default setting would have warned, and observe whether a warning
arrives. Deliver value by itself: this story alone closes the defect.

**Acceptance Scenarios**:

1. **Given** a configuration setting the warning percentage to 100, **When** the guard resolves its settings, **Then** the value is refused and the previously resolved percentage stands — exactly as it would for any other invalid value.
2. **Given** a configuration setting the warning percentage to 99, **When** the guard resolves its settings, **Then** the value is accepted and used.
3. **Given** a configuration setting the warning percentage to 101 or more, **When** the guard resolves its settings, **Then** the value is refused, as it already is today.
4. **Given** the percentage is refused at any one of the three configuration layers, **When** the guard resolves, **Then** the refusal behaves identically at every layer — no layer is more permissive than another.

---

### User Story 2 - A shared setting that quietly disarms everybody's guard (Priority: P2)

Somebody records a window size far larger than any real one — by typo, by
copy-paste, or by guessing. Every reading then sits at a tiny percentage of
that window, so the percentage warning never arrives. Where the value lives in
a file shared with the team, one person's mistake disarms the guard for
everyone who copies the project.

**Why this priority**: The failure is the same silence as Story 1, but the
right response is genuinely contested — the whole point of the setting is that
the person configuring it knows their own limits better than the guard does.

**Independent Test**: Record an implausibly large window, run a session well
past the point where a correct window would have warned, and observe. Whether
that observation should count as a defect is the open question below.

**Status**: **RULED — no change.** Decided 2026-09-04; see Clarifications. This
story ships as a recorded decision, not as code.

**Acceptance Scenarios**:

1. **Given** an implausibly large window is configured, **When** the guard resolves its settings, **Then** the value is accepted and used, exactly as today. This behaviour is deliberate and is not a defect to be fixed later by accident.
2. **Given** this feature ships, **When** somebody next reads the deferral that raised this defect, **Then** they find the ruling and its reasoning there, and reopening the question is a deliberate act.
3. **Given** an implementation adds a ceiling or a notice for the window, **When** it is reviewed, **Then** it is rejected as out of scope — the absence is the decision.

---

### User Story 3 - The written rule and the enforced rule agree (Priority: P3)

Somebody reads the documentation to find out which values are allowed. Today
the documentation and the guard's own explanatory text both say values "above
100" are refused. After Story 1 that sentence is wrong by one value — the very
value the change is about.

**Why this priority**: A rule stated one way and enforced another is how the
defect in Story 1 survived in the first place. No automated check covers this
wording, so it can only be closed deliberately.

**Independent Test**: Read every place the rule is stated and compare each to
the enforced behaviour.

**Acceptance Scenarios**:

1. **Given** Story 1 has shipped, **When** any statement of the threshold rule is read, **Then** it describes refusing 100 and above.
2. **Given** a reader follows the documented rule to pick a value, **When** they apply it, **Then** the guard accepts it.

### Edge Cases

- **The boundary values themselves**: 99 accepted, 100 refused, 101 refused. Today only values well above the boundary are exercised, so the boundary is unpinned in both directions.
- **A refusal that reverts to a value that also warns late**: refusing 100 hands back whatever the layer beneath resolved to. That is the existing contract for every invalid value and is not changed here.
- **A test whose premise the fix removes**: at least one existing test deliberately sets the percentage to 100 to make the percentage warning unreachable, proving a different warning fired. After the fix that setting is refused, the value falls back to the default, and the test still passes — for a reason its own description no longer states. A test that passes for an unstated reason is a silent failure and must be corrected as part of this work, not tidied afterwards.
- **The internal reasoning that depends on the old boundary**: the guard's own notes explain why one report can ride on an existing warning rather than needing one of its own, and that explanation cites the old boundary. The reasoning still holds after the change and in fact holds more strongly, but the text no longer matches the code.
- **A window exactly equal to a reading**: unchanged by this work; already handled deliberately.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST refuse a warning percentage of 100 or above, and keep the previously resolved value, exactly as it does for any other invalid value.
- **FR-002**: The refusal MUST apply identically at every configuration layer — the person's own settings, the project's shared settings, and the environment. No layer may be more permissive than another.
- **FR-003**: The system MUST continue to accept every warning percentage from 1 to 99 inclusive.
- **FR-004**: No configuration value other than a warning percentage of exactly 100 may behave differently before and after this change. Every other setting, and every other value of this setting, MUST be unaffected.
- **FR-005**: Every statement of the threshold rule that the project publishes or keeps beside the code MUST describe the rule actually enforced. No automated check covers this wording, so each occurrence MUST be located and confirmed deliberately.
- **FR-006**: Any existing test whose stated mechanism depends on a warning percentage of 100 being accepted MUST be corrected so that its description is true of what it now exercises. **Its defect is a false explanation, not a false assertion** — the assertion holds before and after, which is precisely why the explanation going stale is invisible. Correcting the explanation is therefore the deliverable, and **no attempt may be made to show the correction "load-bearing" by reverting it**: that was measured on 2026-09-04 and cannot succeed, because the value falls back to a default that leaves the assertion true. Manufacturing such a proof would be fabrication. The burden of proving the change instead sits on FR-007's first-refused-value test.
- **FR-007**: The boundary MUST be pinned in both directions by tests: the first refused value and the last accepted value.
- **FR-008**: The system MUST NOT bound the configured window size, at any configuration layer. This is a **ruled non-change**, decided 2026-09-04 and recorded in Clarifications above with its reasoning. No ceiling, no notice, and no new detector is in scope. An implementation that adds one has exceeded this specification, not improved it.
- **FR-009**: The change in behaviour MUST be demonstrated by comparing the old and new behaviour across a range of configuration and session shapes, showing that exactly the intended shapes differ and no others. A comparison reporting no difference at all MUST be treated as a failed demonstration, not a clean one.
- **FR-010**: The ruling on FR-008 MUST be recorded where the next person to notice the defect will find it — beside the deferral that raised it, so that reopening the question is a deliberate act rather than a rediscovery. Recording it is a deliverable of this feature, not a note about it.

### Key Entities

- **Warning percentage**: the share of the session's capacity at which the first warning fires. Whole number. Meaningful only below the point at which capacity is already exhausted.
- **Window size**: the session's total capacity, as configured. The guard cannot determine this for itself, which is why it is configurable at all.
- **Configuration layer**: one of three places a setting may come from — the person's own settings, the project's shared settings, and the environment — resolved in that order, each overriding the one before, with any invalid value leaving the earlier result standing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With the warning percentage set to 100, the guard warns at the same point it would with no setting at all. Today it does not warn at all until capacity is already exhausted.
- **SC-002**: Every one of the boundary values 99, 100 and 101 produces the documented outcome, and each is covered by a test — but the three carry **different burdens of proof**, and conflating them would fake evidence:
  - **100** is the change. Its test MUST be shown failing against the unchanged system first. Measured 2026-09-04: with this value set and readings at half the window, the unchanged guard warns **not at all**, so the test moves from silent to speaking.
  - **99** must keep working, so its test passes before and after. It CANNOT be shown to fail against the unchanged system, and must not be claimed to. Its proof is a deliberate mutation of the boundary that turns it red, with the mutation verified to have landed before its result is believed.
  - **101** already behaves correctly and is already covered. It needs no new test; adding one would duplicate existing coverage.
- **SC-003**: The project's full test suite grows by the number of tests this work adds, and passes with no failures. A count that has not moved is itself a finding.
- **SC-004**: Every published statement of the threshold rule matches the enforced rule, confirmed at every occurrence rather than by a passing test run.
- **SC-005**: A before-and-after comparison across configuration and session shapes reports zero unexpected differences and at least one expected difference.
- **SC-006**: No pre-existing test is weakened or removed to accommodate the change, and no test passes for a reason its own description does not state.
- **SC-007**: The ruling on the window size is recorded beside the deferral that raised it, and a reader arriving at that deferral reaches the reasoning without leaving the repository.
- **SC-008**: The configured window size behaves identically before and after this work, at every layer and for every value. Any difference here is a scope breach, not an improvement.

## Assumptions

- The existing contract for invalid values — ignore the value, keep the previously resolved one, never disable the guard — is correct and is extended rather than revised.
- Refusing 100 is uncontested and needed no ruling. The window size did, it was ruled on 2026-09-04, and the answer was no change. This asymmetry is why the two defects were specified together and ship as one code change plus one recorded decision.
- The person who configures a window size knows their own limits better than the system can determine them. This assumption is what carried the FR-008 ruling: a limit chosen by the system would refuse absurd values while admitting the plausible-but-wrong ones that actually cause the failure.
- Changing the shipped default, and determining the limit automatically, are both already ruled out by a prior decision and are out of scope here.
- The guard's explanatory notes are part of the record, not decoration: where a note explains why something is safe, the note moves with the code it explains.
- No automated check currently covers the wording of the threshold rule. FR-005 therefore cannot be discharged by a green test run.

## Routed to planning, not dropped

These three came from the seed and are deliberately absent from the
requirements above, because each names a tool, a file or a process rather than
a behaviour. They are recorded here so that their absence is a routing decision
and not a loss. The plan MUST carry all three.

- **Static analysis must stay clean**, run the way the project's automation runs it. Note for the plan: the automation's analyser is OLDER than a typical local one and reports MORE, so a local pass does not predict it.
- **The release stamp must be decided deliberately.** This change alters what an existing configuration does — a setting that was accepted before is now refused and falls back to the default. Whether that makes the next release a patch or a minor is the release phase's call, but it must be raised there rather than discovered there.
- **Changelog routing.** This work touches one of the two shipped components. Both currently have an open unreleased section, which makes filing under the wrong one easy and silent.
