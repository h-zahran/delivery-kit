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

Deliberately NOT listed as a consumer: the run's state file. `progress.sh init`
creates an empty `capabilities` key and nothing in the script ever writes to
it, and no shipped instruction tells the orchestrator to fill it — the
non-empty objects seen in real run files were written by hand during a run.
Saying otherwise here would promise a mechanism that does not exist. Related,
and conceded in the orchestrator's own text: decision 11's "record the answer"
cannot reach a state file on a fresh run at all, because the file is created in
phase B and the stop precedes it.

## Downstream note

With git absent, other reported fields degrade as a consequence. They are named
rather than counted, because a count in prose drifts:

- `baseBranch` reads empty, or the configured value when one was passed.
- `baseBranchSource` reads `current branch` — asserting a route that was never
  taken — or `configured` when a base branch was passed.
- `remote.kind` reads `none`, as though a remote had been looked for and not
  found. It was not looked for.
- `tree.dirty` reads `false`, as though a tree had been examined.

Every one of these was already the behaviour before this change, and none of
them is fixed by it: correcting them would change an existing field's type or
meaning, which this contract forbids. Two things are different now. The report
names the cause, in `capabilities.git`. And the orchestrator is instructed to
print those lines as *not read* rather than as values, so a reader is no longer
told a clean tree exists when nothing looked.
