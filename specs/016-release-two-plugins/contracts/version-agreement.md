# Contract: version agreement

**Date**: 2026-09-03 | **Feature**: 016-release-two-plugins

The interface this repository exposes is a **plugin marketplace**: a consumer
adds `.claude-plugin/marketplace.json` and installs a named plugin at a named
version. This document states the contract that surface must satisfy, what
enforces each clause, and — the part that matters here — which clause has no
enforcement at all.

## C1 — Three records, one version

For every plugin directory `<p>` holding `<p>/.claude-plugin/plugin.json`:

```text
plugin.json .version
  == marketplace entry (selected by .name) .version
  == first changelog heading matching ^## \[X.Y.Z\] - YYYY-MM-DD$
```

**Enforced by**: `scripts/check-versions.sh`, invoked by
`tests/portability.bats` and by the `version agreement` job in CI.

**Shown able to fail**: yes. `tests/portability.bats` copies a plugin tree,
rewrites its changelog heading to `## [9.9.9] - ...`, asserts the rewrite landed,
and requires the script to refuse the tree. A separate case breaks the
marketplace leg the same way.

**This feature's obligation**: after the six edits, the script exits 0 and prints

```text
handoff: plugin=2.1.1 marketplace=2.1.1 changelog=2.1.1
pipeline: plugin=1.2.0 marketplace=1.2.0 changelog=1.2.0
```

Both halves matter. Exit 0 alone says the three agree; the printed values say
they agree on the RIGHT number. A release that stamped 1.1.1 everywhere would
satisfy the first and fail the second.

## C2 — Identity is stable

`plugin.json .name` equals its directory name, and the marketplace entry's
`source` resolves to that directory.

**Enforced by**: the same script, which checks both, and refuses an absolute or
traversing `source`.

**Why it is in this contract at all**: the release-tag gate resolves a plugin
FROM the directory name while the agreement walk resolves the entry from
`.name`. Nothing else holds those identities together, and a manifest renamed
without its directory once left every gate green while release tags silently
stopped naming the plugin.

**This feature's obligation**: change neither. Only `version` moves.

## C3 — The marketplace is walked in both directions

Directory-to-entry AND entry-to-directory, with the two counts pinned equal.

**Enforced by**: the same script, ending with an assertion that it examined at
least one plugin — because a walk over zero plugins passes having verified
nothing.

**This feature's obligation**: none directly. It adds and removes no plugin, so
both counts stay at 2. Recorded because a release is exactly when a
plugin-count change would otherwise slip past.

## C4 — A released heading is dated; an unreleased one is not

`## [Unreleased]` means "these changes are in no release". A dated version
heading means "these changes shipped in this version, on this date".

**Enforced by**: **NOTHING.**

This is the hole. `scripts/check-versions.sh` reads the changelog with `grep -m1`
against a pattern anchored to `## [X.Y.Z] - YYYY-MM-DD`. An `## [Unreleased]`
heading does not match that pattern, so it is not rejected — it is **skipped**,
and the first heading that does match is read instead. The gate therefore reports
agreement while the newest entries claim to be in no release at all.

Measured on 2026-09-03, before any edit in this feature:

```text
$ bash scripts/check-versions.sh
handoff: plugin=2.1.0 marketplace=2.1.0 changelog=2.1.0
pipeline: plugin=1.1.0 marketplace=1.1.0 changelog=1.1.0
$ echo $?
0
```

A clean pass, on the exact state this release exists to correct. Both changelogs
had carried an open heading since 2026-08-25.

**This feature's obligation**, and it is the reason FR-008 exists separately from
FR-011:

1. Verify the fold by **direct search**, never by inferring it from a green
   agreement gate.
2. Fire a **positive control** on that search — run it against a copy that still
   carries the heading and require it to report a finding — because verification
   that has only ever passed has not been shown able to fail.

**Not closed here.** Closing C4 means adding a test. The question was put to the
owner at the clarify gate on 2026-09-03 and the answer was to keep the seed's
scope: five files, nothing else. The clause is written down so the next planning
pass inherits a named gap rather than rediscovering an unnamed one.

## C5 — A release tag names a plugin and its manifest version

Tags are `<plugin>-v<version>`. CI strips the suffix, reads
`<plugin>/.claude-plugin/plugin.json`, and requires the two to match.

**Enforced by**: the `tag matches the manifest version` step, which runs on
`tags: ['**']` — deliberately not a well-formed-tag filter, because a filter
admitting only correct tags does not reject the malformed ones, it stops the
workflow running and skips the gate for exactly the tag it exists to catch.

**This feature's obligation**: none. FR-015 keeps tagging out of scope; it
follows the merge. The obligation this feature DOES carry is not to stamp a
version the tag gate would later reject — satisfied, because the tag halves will
be `1.2.0` and `2.1.1`, read from the same manifests this feature writes.

## Consumer-visible effect

| Before | After |
|---|---|
| `handoff 2.1.0`, `pipeline 1.1.0` | `handoff 2.1.1`, `pipeline 1.2.0` |
| Newest entries in both changelogs claim to be in no release | Newest entries are dated 2026-09-03 and named by version |
| No installable version contains the git pre-flight stop, or the guard's reduced process count | Both are installable and nameable |
