# Phase 1 data model: the capability report

This feature has no database and no persisted records. Its one "entity" is the
JSON document `preflight.sh` writes to stdout, which is a machine contract read
by the orchestrator and by every test in the probe suite. Only one field
changes. No count is given here on purpose: a written one drifts the first time
a test is added, and this document's whole subject is a contract that must not
drift.

## Entity: `capabilities`

An object of booleans, one per external tool the probe looked for. Presence is
the whole meaning: the probe asks whether the tool can be found on the search
path, never whether it works.

### Before

| Field | Type | Meaning |
|---|---|---|
| `jq` | boolean, always `true` | The probe cannot emit this document without `jq`, so reaching this field proves it. |
| `gh` | boolean | The command-line client for the code host. |
| `adb` | boolean | The device bridge the mobile runtime check needs. |

### After

| Field | Type | Meaning | Change |
|---|---|---|---|
| `jq` | boolean, always `true` | unchanged | none |
| `git` | boolean | Whether `git` can be found. | **new** |
| `gh` | boolean | unchanged | none |
| `adb` | boolean | unchanged | none |

`git` is written after `jq` because the two are the run's hard requirements and
`gh`/`adb` are optional. Key order in a JSON object carries no meaning to any
consumer — every reader in the tree selects by name — so this is a choice about
how the document reads to a human, not a contract change.

### Validation rules

- **Additive only.** No field above may change its name, its type or its
  meaning. Verified by the existing suite passing unedited.
- **Boolean, never a string.** `jq -r` prints the JSON string `"true"` as a bare
  `true`, so a value comparison cannot tell the two apart. Emitting through
  `--argjson` is what produces the right type, but emitting is not a guard —
  measured on this branch: switching `git` to `--arg` shipped a string and NOT
  ONE test in the suite went red. The guard is an explicit
  `type == "boolean"` assertion, and both new tests carry one.

  `gh` and `adb` do not have that assertion and are still checked by value
  alone, so the same substitution would ship them as strings unnoticed. Adding
  it means editing tests that already exist, which SC-004 forbids in this
  change. Named here so the next change can close it.
- **Complete when a tool is absent.** An absent tool sets its field to `false`.
  It never removes the field, never truncates the document, and never causes a
  non-zero exit.

## Entity: `willSkip`

An array of `{phase, reason}` records, each naming a phase the run expects to
skip because an optional tool or a remote is missing.

**Unchanged by this feature, deliberately.** git gains no entry here. The
absent-git test pins the array's phase set to exactly `["L","M"]` — the two
entries the existing no-remote branch produces once git's absence makes the
remote unreadable — so a future git entry cannot be added without turning that
test red.

## Entity: the pre-flight decision walk

Not data. It is the ordered list of judgements in
`pipeline/skills/pipeline/SKILL.md` that the orchestrator makes from the report
above. It gains one item, numbered 11, and renumbers none.

The item's number and its firing order are deliberately different: it is
written eleventh so that items 1 through 10 keep their numbers, and its text
states that it fires before all of them. Item 10 already reads this way.

## State transitions

None. The probe is a single pure read of the machine, run once, producing one
document. Nothing in this feature has a lifecycle.
