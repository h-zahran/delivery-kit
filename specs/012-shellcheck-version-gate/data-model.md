# Data Model: shellcheck, and one version gate instead of two

This feature stores nothing. The entities below are the values its two
checks read and the shapes they must hold. Every one is derived from a
tracked file at the moment a check runs.

---

## Version stamp

One plugin's version, recorded in three places that must agree.

| Field | Source | Rule |
|---|---|---|
| `plugin_dir` | a top-level directory containing a plugin manifest | Discovered by walking top-level directories; a directory without a manifest is not a plugin and is skipped |
| `manifest_name` | the plugin manifest's name field | MUST be non-empty; MUST equal `plugin_dir` |
| `manifest_version` | the plugin manifest's version field | MUST be non-empty |
| `marketplace_version` | the marketplace entry selected BY NAME | MUST exist; MUST be non-empty; MUST equal `manifest_version` |
| `marketplace_source` | the same entry's source field | MUST be non-empty; MUST resolve to `plugin_dir` after normalising a leading current-directory prefix and a trailing separator |
| `changelog_version` | the first changelog heading matching the pinned format | The heading MUST match the pinned format anchored at both ends; the version extracted from it MUST equal `manifest_version` |

**Identity rule**: the manifest name and the directory name are one
identity. Nothing else holds them together, and the release tag gate
resolves a plugin from the directory while this walk resolves the
marketplace entry from the manifest name. If they diverge, the two gates
key on different things.

**Selection rule**: a marketplace entry is selected by name, never by
position. A second plugin prepended to the list would otherwise be
compared against the wrong entry, and could agree with it by accident.

**Absence versus disagreement**: these are two different defects with two
different fixes and MUST produce two different messages. A present entry
missing a key must not be read as the literal text a query language
prints for a null, because that text is non-empty and would send a reader
to compare two version numbers when one of them does not exist.

---

## Reverse walk

The forward walk goes directory to entry, so an entry whose directory is
missing is never visited.

| Field | Rule |
|---|---|
| `entry_name` | every name in the marketplace list, read one per line |
| `entry_source` | that entry's source; MUST name a directory that holds a plugin manifest |
| `entries_count` | MUST equal the forward walk's count of plugin directories |

**Carriage-return rule**: on one platform the query tool's output is
text-mode and every line it prints ends with a carriage return. Command
substitution strips it; a line-reading loop does not. A name carrying a
stray carriage return matches no entry, so a walk that reads lines MUST
strip it. This is a no-op on the other two platforms and the difference
between green and a false red on the third.

**Non-empty rule**: a walk over zero plugins passes having verified
nothing. Both walks MUST assert they found work to do.

---

## Analysed file set

The set of files the static analysis reads.

| Field | Rule |
|---|---|
| `candidates` | tracked files whose name ends in a shell extension |
| `exclusions` | the vendored scaffold directory, removed by pathspec |
| `analysed` | `candidates` minus `exclusions` |

**Non-empty rule**: `analysed` empty is a failure, not a pass. A
discovery that has broken produces the same result as a clean tree.

**Growth rule**: a shell file added later at any tracked path outside the
exclusions joins `analysed` with no file edited to admit it. This is the
property the set exists to have.

**Separator rule**: the set is carried between the producing command and
the consuming command in a form that survives a path containing a space.

---

## Finding

One report the analyser produces.

| Field | Rule |
|---|---|
| `file`, `line`, `identifier`, `message` | printed as the analyser produces them, so a red is diagnosable from the log alone |
| disposition | exactly one of: fixed in source, or suppressed at its own line with a written reason |

**Suppression rule**: a suppression with no reason MUST NOT exist. A
suppression MUST sit at the line it silences, in the file that owns it,
not in a job-level list, unless a job-level entry is the only place the
finding can be addressed.

---

## Runner pin

The immutable reference to the third-party test runner.

| Field | Rule |
|---|---|
| `revision` | the commit the release reference points AT, not the release object's own identifier; both resolve, but only the commit is what a checked-out copy reports as its own revision, and only the commit is stable across a re-tag of the same code |
| `release_name` | the human-readable release name, carried in a comment beside the revision so the pin stays readable |
| `cache_key` | derived from the operating system and `revision`, so changing the pin misses the cache |
