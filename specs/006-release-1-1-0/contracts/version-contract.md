# Version contract — the 1.1.0 stamp

THREE lines change, carrying FOUR pinned strings. This file pins all of them exactly,
and lists what must not move.

The two numbers differ on purpose and the difference caused a real contradiction in an
earlier draft of this file, caught at phase I: the changelog heading is ONE changed line
but TWO pinned strings, the old text and the new. Say "three lines" when counting the
diff and "four strings" when counting what is pinned; never "four lines", which the
Expected diff section at the bottom of this file directly contradicts.
Anything not written here is out of scope for this phase.

## The three version sites (exact)

### Site 1 — the plugin manifest

`pipeline/.claude-plugin/plugin.json`, the `version` field.

```
  "version": "1.0.1",      ->      "version": "1.1.0",
```

Read back with `jq -r '.version' pipeline/.claude-plugin/plugin.json` — prints `1.1.0`.

### Site 2 — the marketplace listing

`.claude-plugin/marketplace.json`, the `version` field of the entry whose `name` is
`pipeline`. **Repository root, not inside the plugin directory.**

```
      "version": "1.0.1",      ->      "version": "1.1.0",
```

Read back with
`jq -r '.plugins[]|select(.name=="pipeline").version' .claude-plugin/marketplace.json`
— prints `1.1.0`.

**The `handoff` entry in the same file keeps `2.1.0`.** It is a different plugin on a
different version line, and the plan's excluded list names any handoff change as a
separate 2.2.0 candidate. Its value is a fixture of this contract: if it moves, that
is a finding.

### Site 3 — the changelog heading

`pipeline/CHANGELOG.md`, line 5. ONE line replaced by ONE line:

```
## [Unreleased]      ->      ## [1.1.0] - 2026-08-24
```

Read back with `grep -m1 -oP '(?<=^## \[)[^\]]+' pipeline/CHANGELOG.md` — prints
`1.1.0`.

## Identity and shape

**Identity** binds the string `1.1.0` across all three sites. It is a version, not a
range: `1.1`, `v1.1.0` and `1.1.0-rc1` are all wrong. The two JSON sites carry it as a
STRING value, matching how `1.0.1` is carried today — never as a number, which is not
representable anyway.

**Shape** binds site 3 additionally. The new heading must match the pattern the file
already uses, tested as a pattern and not as a string:

```
^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$
```

Proven with BOTH controls before it was written into this contract: the existing
`## [1.0.1] - 2026-08-22` heading MATCHES, and `## [Unreleased]` does NOT. A pattern
that accepts anything is not a check.

The date is `2026-08-24`, the day this run executes, resolved once and written
literally. The seed writes it as `<today>`; it is not derived at read time.

## The content beneath site 3 — byte-identical

`pipeline/CHANGELOG.md` lines 6-55 are the four accumulated Added entries: the
constitution probe, the implementer handoff package, the implementer key, and the
verification cap. **3104 bytes, sha256 beginning `09bf16d6f4a4b59d`**, measured before
any edit.

Because exactly one line is replaced by exactly one line, those entries do not shift
line numbers. Hashing lines 6-55 after the edit and comparing to the value above proves
nothing was changed WITHIN that range.

Be exact about what it does NOT prove, because an earlier draft of this file claimed the
hash alone was a "COMPLETE proof of FR-004" and phase I showed the hole: content APPENDED
at line 56 — below the range, above the next heading — leaves lines 6-55 byte-identical
and passes. That is precisely the "add nothing" violation FR-004 forbids. The Expected
diff section below closes it, because such an entry appears there as a seventh changed
line. **The hash and the diff audit together prove FR-004; neither is complete alone.**

Add nothing, remove nothing, reorder nothing, reword nothing.

## What must NOT move

- **`handoff/**`** — untouched, including its own version and changelog.
- **The `handoff` marketplace entry** — stays `2.1.0`.
- **The orchestrator's grep-pinned prose** — `pipeline/skills/pipeline/SKILL.md` is not
  edited at all by this phase, so the plan's "add near, never reword" constraint is
  satisfied by having nothing to reword. VERIFY this in the diff; do not assume it.
- **Suite counts** — house `1..121`, prose `1..11`. Growth or shrinkage is a finding,
  and the prose-pin debt is PAID: it is not re-queued or re-spent here.
- **Every other version in the repository** — including any `1.0.1` inside test
  fixtures, which are fixtures and not statements about the shipped version.
- **Git tags** — this run creates none. `pipeline-v1.1.0` is the owner's act after the
  merge.

## Expected diff

```
 pipeline/.claude-plugin/plugin.json | 2 +-
 .claude-plugin/marketplace.json     | 2 +-
 pipeline/CHANGELOG.md               | 2 +-
 3 files changed, 3 insertions(+), 3 deletions(-)
```

Three files, three lines replaced. A fourth changed line anywhere on the shipped
surface is a finding, and the check reads the changed LINES rather than trusting the
count — three changed lines could still be the wrong three.
