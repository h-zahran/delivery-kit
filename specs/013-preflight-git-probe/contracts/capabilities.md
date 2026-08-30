# Contract: the pre-flight probe's stdout

`pipeline/scripts/preflight.sh` is a command-line program whose stdout is a
machine contract. This document states the part of that contract this feature
changes, and the parts it must not.

## Invocation

```
bash pipeline/scripts/preflight.sh [--dir <path>] [--project-type <type>] [--base-branch <name>]
```

## Guarantees that must survive this change

1. **Stdout is pure JSON.** One document, nothing else. Every diagnostic goes
   to stderr. A single stray line on stdout breaks every consumer, and the
   suite parses stdout with `jq` in every test.
2. **Reporting is not failing.** The probe exits `0` when a capability is
   missing. The suite states this in a test name:
   *"the no-speckit fixture reports the tool absent, exit 0 — reporting is not
   failing"*.
3. **Existing keys are immutable.** No key changes its name, its type or its
   meaning. New keys may be added.
4. **The document is always complete.** A missing tool produces a `false`
   field, never a truncated document and never an omitted key.

## The change

`capabilities` gains one boolean member:

```json
{
  "capabilities": { "jq": true, "git": true, "gh": false, "adb": true }
}
```

| Member | Type | `true` when | `false` when |
|---|---|---|---|
| `git` | boolean | `command -v git` succeeds | `command -v git` fails |

Nothing else in the document changes.

## What the probe does NOT promise about git

- **It does not promise git works.** The probe asks only whether git can be
  found. A git that is present but broken reports `true`, and the pre-flight
  stop is not claimed to cover that case.
- **It does not announce a skip.** `willSkip` gains no entry for git. Skipping
  is for a phase the run can do without; there is no such phase here.
- **It does not stop the run itself.** The stop is the orchestrator's decision,
  taken from this report. See `pipeline/skills/pipeline/SKILL.md`, pre-flight
  decision item 11.

## Consumers, and what each reads

| Consumer | Reads | Effect of this change |
|---|---|---|
| `pipeline/skills/pipeline/SKILL.md` pre-flight | the whole document | renders `git` on the `Available` or `Missing` line; stops on `false` |
| `pipeline/tests/preflight.bats` | every key, per test | two new tests read `capabilities.git`; no existing test is edited |
| the run's state file | capabilities, recorded at pre-flight | records `git` alongside the others |

## Downstream note

With git absent, three other reported fields degrade as a consequence, and this
is expected rather than a defect:

- `baseBranch` reads empty (or the configured value, when one was passed).
- `remote.kind` reads `none`, because the remote cannot be read.
- `tree.dirty` reads `false`, because the tree cannot be read.

These were already the behaviour before this change. The difference is that the
report now names the cause, so a reader is no longer told a clean tree exists
when nothing looked.
