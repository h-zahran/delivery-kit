# Contracts: the commands this feature changes

Stdout carries the answer. Stderr carries the reason. Tests assert the exact status.

## `progress.sh suite-base <feature> start`

| Status | Meaning | Stdout |
|---|---|---|
| 0 | Started | `base suite started on commit <id> (process <pid>), command <json>`, then `, from <json>` when `config.testCommandFrom` is recorded; both JSON values in ASCII, as `jq -a` prints them |
| 0 | Started before | `base suite already started on commit <id>` |
| 0 | Legally not started | `base suite not started: <reason>`: abandoned; `suiteReuse` off or another value; a green result recorded; a spec file at the top level, under the state directory or outside the repository; a hidden index entry; an unmerged path, a submodule or a nested repository; HEAD with no commit; `TMPDIR` inside the tree; base files that differ |
| 1 | A check could not be made | nothing; the reason on stderr |
| 3 | The run's record cannot serve the start | `base suite not started: config.testCommand is not recorded as a string in <file>`, or `base suite not started: artifacts.spec in <file> names no spec file that exists` |

Status 3 starts nothing and makes no folder. Run again after the record is fixed, and it starts.

## `progress.sh branch-cut <feature>`

Reads `branch` and `baseBranch` from the state file. Takes no other argument.

| Case | Status | Stdout | Effect |
|---|---|---|---|
| Branch absent | 0 | `branch <name> cut from <base>` | `git checkout -b`; uncommitted work stays |
| HEAD on the branch | 0 | `already on branch <name>` | none |
| Branch exists, HEAD elsewhere, base is its ancestor | 0 | `switched to branch <name>` | `git checkout`; uncommitted work stays, or git refuses |
| Branch exists, base is not its ancestor | 1 | nothing | none; stderr names both and the `git checkout` command |
| Empty or illegal name in the state file; a branch equal to the base; base absent when it is needed; git refuses | 1 | nothing | none |
| A hook fails after the checkout succeeds | 1 | nothing | HEAD on the branch; stderr says so, and a second run says `already on branch <name>` |
| Abandoned run | 1 | nothing | none |

It never deletes a branch, moves a branch's commit or discards work.

## `progress.sh state-set <feature> <key> [<sub-key>] --json-file <path>`

Stores the file's one JSON document. All key, type and `gates.pending` checks are the inline form's.

Refused, status 1, nothing written, no content printed: a missing file, a folder, an unreadable file, an empty file, two or more documents, bad JSON.

The inline form does not change.

## `preflight.sh --values-file <path>`

The file is one JSON object: `{"commitTrailers": ["<token>: <value>"], "baseBranchOverride": "<name>", "baseBranch": "<name>", "projectType": "web"}`. Every key is optional. `projectType` is `web`, `mobile-android` or `other`, from any source.

- Trailers: the file's first, then each `--trailer`, whatever the command-line order. Each goes through `trailer-check.sh`.
- Override and the rest: a typed flag beats the file's value. A file value gets the same checks as the flag, and a refusal names the key it came from.
- Refused, status 1, naming the path and printing no value: a missing file, a folder, an unreadable file, anything but one JSON object, an unknown key, a wrong type.

## `prose_slice <file> <open> <close> <form> <name> [<declared-line>...]`

| Form | Returns |
|---|---|
| `raw`, `flat` | As today: the closing line included |
| `raw-inside`, `flat-inside` | The same slice without its closing line |

All guards run on the whole slice in every form. An inside form that leaves nothing is refused: `prose_slice [<name>]: nothing is left inside the region once its closing line is dropped`.

## The probe block

One line, on every fresh run and every re-entry, between `Base branch` and `Branch`:

```
Test command : <JSON-quoted command>  (from <layer>)
```

JSON-quoted in ASCII, as `jq -a` prints it.

or, when nothing resolves:

```
Test command : none resolved — B stops and asks
```

`<layer>` is `~/.delivery-kit.json`, the repository's `.delivery-kit.json`, `--config`, `project type`, or, on a value given at B's stop, `the owner, at B's stop`.
