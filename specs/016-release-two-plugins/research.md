# Research: release pipeline 1.2.0 and handoff 2.1.1

**Date**: 2026-09-03 | **Branch**: `016-release-two-plugins`

The specification carried no `NEEDS CLARIFICATION` marker, so Phase 0 was not
spent resolving unknowns. It was spent de-risking an edit that looks trivial and
has three ways to go quietly wrong. Every finding below was produced by running
something. None is reasoned from memory.

---

## D1 — `jq` MUST NOT be used to make these edits

**Decision**: edit the three JSON files with a line-anchored `sed` on the exact
version line, never with `jq`.

**Rationale**: `jq` is the obvious tool and it is the wrong one. Measured on
2026-09-03, a `jq '.'` round trip with **no change at all** rewrites every one of
the three files:

| File | Round-trip result |
|---|---|
| `.claude-plugin/marketplace.json` | **DIFFERS** — `1,26c1,34`, the entire file |
| `pipeline/.claude-plugin/plugin.json` | **DIFFERS** — `1,12c1,17` |
| `handoff/.claude-plugin/plugin.json` | **DIFFERS** — `1,18c1,18` |

Two causes are visible in the diff. Inline arrays are expanded: the tracked file
writes `"tags": ["context", "handoff", "session-continuity"]` on one line, and
`jq` puts each element on its own. And the file grows by eight lines as a
result. A `jq`-based edit would therefore have produced a five-file diff in which
three files were rewritten end to end — passing every version check, passing the
suite, and violating SC-004 in a way no gate here would report.

**Alternatives considered**:

- `jq` with `--indent 2`: does not help. The indent is already two; the array
  expansion is not an indent setting.
- `jq` piped through a reformatter: adds a dependency to undo a change that need
  never be made.
- A JSON-aware editor library: same objection, more machinery.
- **`sed` on the exact line** — chosen. The version lines are unique strings
  within their files, the edit is one line, and the result is verifiable by
  counting diff lines.

**How the choice is made safe**: the count is asserted before the write, not
read after it. Each `sed` is preceded by a check that the pattern matches
**exactly once** in the target file, and followed by a check that the file's diff
against `HEAD` is **exactly one changed line**. A `sed` that matches nothing
exits 0 and changes nothing, which is indistinguishable from success unless the
count is asserted.

---

## D2 — the marketplace entry is edited by value, and the values are unique

**Decision**: target `"version": "1.1.0"` and `"version": "2.1.0"` directly, and
assert each matches exactly once in `.claude-plugin/marketplace.json` before
writing.

**Rationale**: `scripts/check-versions.sh` selects the marketplace entry by
`.name`, never by array position, and its comment says why: a second plugin
prepended to the array would otherwise be compared against the wrong entry, and
could agree with it by accident. A positional edit carries the same hazard. But
the two outgoing versions are **different strings** — `1.1.0` for pipeline,
`2.1.0` for handoff — and each occurs once in the file, so matching on the value
is exact and order-independent. Measured: one occurrence each, at lines 13 and
21.

**Alternatives considered**: editing by line number (breaks the moment anything
is inserted above); a `jq` `select(.name == ...)` update (rejected by D1).

---

## D3 — all six edits land before anything is verified

**Decision**: make every edit, then verify. Never verify between edits.

**Rationale**: `tests/portability.bats` invokes `scripts/check-versions.sh`, so
the suite itself enforces manifest–marketplace–changelog agreement. Any
intermediate state — a manifest bumped while its changelog heading is still
`## [Unreleased]` — is a **disagreement**, and running the suite there produces a
red that means "you are halfway", not "you are wrong". A red with the wrong
meaning is worse than no check.

---

## D4 — the agreement gate cannot confirm the heading was folded

**Decision**: verify FR-008 with a direct search for `## [Unreleased]`, and treat
a green `check-versions.sh` as necessary but not sufficient.

**Rationale**: measured on the tree as it stood before any edit, the gate passes:

```text
handoff: plugin=2.1.0 marketplace=2.1.0 changelog=2.1.0
pipeline: plugin=1.1.0 marketplace=1.1.0 changelog=1.1.0
exit 0
```

That is a clean pass on the exact defect this release exists to fix. The cause is
in the script's own comment: it reads the changelog with `grep -m1` against a
pattern anchored to `## [X.Y.Z] - YYYY-MM-DD`, and takes the first heading that
**matches**. An `## [Unreleased]` heading does not match, so it is skipped and
the previous release's heading is read instead. The gate is structurally blind
to a dangling heading, which is precisely why one survived a release cycle.

The gap was put to the owner at the clarify gate and deliberately left open —
see the spec's Clarifications. This decision is how the feature protects itself
without closing it.

---

## D5 — no test asserts a version VALUE, and no test pins a changelog heading

**Decision**: proceed without expecting any test to move.

**Rationale**: two searches, both run rather than assumed.

- Searching every `.bats` and `.bash` file for `1.1.0`, `2.1.0`, `1.2.0` and
  `2.1.1` returns five hits, and **all five are comments about history** — the
  shipped 1.1.0 release notes, and handoff's own earlier 1.2.0 promises. Not one
  is an assertion on a current version value. Changing the versions therefore
  cannot redden a test by value.
- `pipeline/tests/prose.bats` is the only suite that reads a changelog directly.
  It flattens the file and greps for **content strings** — the `--implementer`
  flag spelling, the null-merge sentence — never for a heading and never by line
  number. Rewriting the `## [Unreleased]` line touches nothing it pins.

**A related positive control already exists and is worth knowing about.**
`tests/portability.bats` copies a plugin tree, rewrites its changelog heading to
`## [9.9.9] - ...`, asserts the rewrite landed, and then requires
`check-versions.sh` to REFUSE it. So the plugin-versus-changelog comparison has
been shown able to go red. That is the manifest-agreement half of this feature
already covered by an existing control; the dangling-heading half is the half
with no control, per D4.

---

## D6 — the release date

**Decision**: both headings carry `2026-09-03`.

**Rationale**: it is the date the stamp is made. Both plugins are stamped in one
act, so both carry one date. The seed writes `<today>`; there is no separate
per-plugin release date to reconstruct.

---

## What was NOT researched, and why

- **Whether to close the dangling-heading gap.** Not a research question. It is a
  scope decision, it was asked at the clarify gate, and the answer was no.
- **Whether the root `CHANGELOG.md` needs a stamp.** Resolved at the clarify gate
  by reading it: it is an index of links and carries no version number.
- **The tag step.** Out of scope by FR-015; it happens after the merge.
