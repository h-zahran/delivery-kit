# Data Model: release pipeline 1.2.0 and handoff 2.1.1

**Date**: 2026-09-03

There is no database and no runtime data. The "model" here is the set of places
a plugin version is recorded, the rules binding them, and the one transition
this feature performs. Every line below was read from the tree on 2026-09-03,
not recalled.

## Entities

### PluginManifest

**Where**: `<plugin>/.claude-plugin/plugin.json`

| Field | Type | Role in this feature |
|---|---|---|
| `name` | string | Identity. MUST equal the directory name — the release-tag gate resolves a plugin FROM the directory while the agreement gate resolves the marketplace entry from `.name`, and nothing else holds those two identities together. **Not changed here.** |
| `version` | string | The value this feature changes. |

Current state, exact:

```text
pipeline/.claude-plugin/plugin.json:4:  "version": "1.1.0",
handoff/.claude-plugin/plugin.json:4:  "version": "2.1.0",
```

Indentation is **two spaces**. This differs from the marketplace entry and the
edit patterns must respect it.

---

### MarketplaceEntry

**Where**: one object in the `plugins` array of `.claude-plugin/marketplace.json`

| Field | Type | Role in this feature |
|---|---|---|
| `name` | string | The key. Entries are selected by name, **never by array position** — a plugin prepended to the array would otherwise be compared against the wrong entry and could agree with it by accident. **Not changed here.** |
| `version` | string | The value this feature changes. |
| `source` | string | The path an installer follows to find the manifest. Read by nothing else in the repository, which is why an entry naming the wrong directory once passed every other check for the life of two commits. **Not changed here.** |

Current state, exact:

```text
.claude-plugin/marketplace.json:13:      "version": "2.1.0",     # the handoff entry
.claude-plugin/marketplace.json:21:      "version": "1.1.0",     # the pipeline entry
```

Indentation is **six spaces**. Both values are unique within the file — verified,
one occurrence each — so a value-anchored edit is exact and order-independent.

---

### Changelog

**Where**: `<plugin>/CHANGELOG.md`

Not a record with fields, but a sequence of headings with content beneath each.
Two properties matter.

| Property | Rule |
|---|---|
| Heading format | The version-bearing heading MUST match `^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$`, **trailing anchor included**. An unanchored version of this pattern once accepted a heading carrying a trailing parenthetical in one of two hand-kept copies while the other refused it; that divergence is why the check now lives in one file. |
| Which heading is read | The **first heading that MATCHES**, found with `grep -m1` — not the first heading in the file. |

That second rule is the whole reason this feature exists in the shape it does.
`## [Unreleased]` does not match, so it is skipped and an older release's heading
is read in its place.

Current state, exact:

```text
pipeline/CHANGELOG.md:5:## [Unreleased]
handoff/CHANGELOG.md:7:## [Unreleased]
```

## Relationships and the invariant

For each plugin, three records hold one version and MUST agree:

```text
                 plugin.json .version
                        |
                        | equal
                        v
   marketplace entry .version  ==  changelog first-matching heading
```

`scripts/check-versions.sh` enforces this, in both directions, and pins the two
directional counts to each other so the walks cannot cover different sets.

**The invariant has a hole, and this feature must work around it rather than
through it.** The changelog leg is satisfied by ANY matching heading, so an
`## [Unreleased]` heading sitting above a matching one is invisible. Measured
before any edit: all three legs agree for both plugins, and the tree is
nonetheless in the state this release exists to fix.

## State transition

Exactly one transition, applied to both plugins in a single act:

```text
  BEFORE                                   AFTER
  ------                                   -----
  pipeline  manifest      1.1.0     ->     1.2.0
  pipeline  marketplace   1.1.0     ->     1.2.0
  pipeline  changelog     ## [Unreleased]  ->  ## [1.2.0] - 2026-09-03
                          (gate read 1.1.0 from an older heading)

  handoff   manifest      2.1.0     ->     2.1.1
  handoff   marketplace   2.1.0     ->     2.1.1
  handoff   changelog     ## [Unreleased]  ->  ## [2.1.1] - 2026-09-03
                          (gate read 2.1.0 from an older heading)
```

**The transition is not atomic and the intermediate states are invalid.** Any
partial application leaves at least one plugin's three records disagreeing, and
the suite invokes the agreement script, so a suite run mid-transition goes red
with the meaning "halfway", not "wrong". All six writes complete before anything
is verified.

## Validation rules

| Rule | Source | How checked |
|---|---|---|
| Three records agree, per plugin | `scripts/check-versions.sh` | run it; exit 0 and two printed triples |
| Heading matches the anchored pattern | **nothing** | The script does NOT enforce this. A non-matching heading is SKIPPED by its `grep -m1`, not rejected, so it reads an older release's heading and reports agreement. It dies naming the format only when NO heading in the file matches. Checked here by T017 instead. |
| No `## [Unreleased]` remains | this feature only | direct search — the script CANNOT see this |
| Content beneath each heading unchanged | FR-007 | compare the range below the heading against the merge base `c2259d5`, never against `HEAD` — after the release commits, `HEAD` carries no `## [Unreleased]` heading and the check goes falsely red |
| Exactly five STAMP files changed | FR-010 | count the diff against the merge base excluding BOTH `.specify` and `specs` — the branch changes fourteen tracked paths in total: five stamps, the constitution, and this feature's own eight artefacts |
| Manifest `name` still equals its directory | `check-versions.sh` | unchanged by this feature; the script asserts it anyway |

## Out of model

- The git tag. It encodes the same version a fourth time, as
  `<plugin>-v<version>`, and CI compares it against the manifest — but only on a
  tag push, after this feature's merge. FR-015 keeps it out.
- The root `CHANGELOG.md`. An index of links to the two plugin changelogs. It
  records no version and is not part of this model.
