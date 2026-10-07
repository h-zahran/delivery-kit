# Contract: commit trailers

## Spellings

| Spelling | Layer | Effect |
|---|---|---|
| `commitTrailers` key | a configuration file | The team's list. A later file's list replaces an earlier one's. |
| `--trailer <token: value>` flag | the command line, repeatable | Adds one trailer after the key's. Never replaces the key. |

The orchestrator passes the resolved list to pre-flight as `--trailer <text>`, once per trailer, the key's first, on a fresh run only. Pre-flight reports `commitTrailers`, an array in the same order.

## Refusals

Each exits non-zero and names the trailer. Pre-flight's messages end `(a commit trailer)`: the value may come from the key or the flag, and the script cannot tell which. The commit subcommands refuse the same set before each commit, from every layer.

| Trailer | Message part |
|---|---|
| holds CR or LF | `holds a line break; a trailer is one line` |
| holds another control character | `holds a control character` |
| no `:` | `has no ':'; write <token>: <value>` |
| token not `^[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9]$` | `a token starts with a letter, ends with a letter or a digit, and holds letters, digits and dash only` |
| value empty or only spaces | `has an empty value` |
| token `Piece`, `Late` or `Tasks`, any letter case | `reserved for the run's own markers` |
| token `skip-checks`, `Co-authored-by`, `Signed-off-by`, or a closing keyword (`close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`), any letter case | `which acts on GitHub or names another author` |
| value holding `[skip ci]`, `[ci skip]`, `[no ci]`, `[skip actions]` or `[actions skip]`, any letter case | `asks GitHub to skip the checks` |
| value holding a closing keyword before an issue number (`fixes #12`, `closes owner/repo#3`) | `would close an issue` |

## Commits that carry the list

Every commit a `progress.sh` subcommand makes: `spec-commit` (subject unchanged), `piece-commit`, `late-commit` (J's `--record` included) and `remainder-commit` (kinds `other` and `constitution`). Not the handoff path's external commits.

## Recorded shape

`config.commitTrailers`: an array of `<token>: <value>` strings, the list pre-flight reports, in order. `config.commitTrailersFrom`: each entry's layer, in the same order, for the probe line. Missing, `null` or `[]` means no trailers.

## Mechanism

`with_trailers <message file>` in `progress.sh`, called by `commit_named` and by J's `--record` commit:

1. Read `config.commitTrailers`. Anything but an array of non-empty strings with no control character stops, naming the state file. No commit is made. The check is in the jq filter, because `jqs` strips a CR from what it prints.
2. Check each entry with `trailer_ok`, the same set pre-flight refuses. A bad one stops, naming it.
3. Copy the message to `<run dir>/trailers-msg.txt`, and commit the copy. The caller's file is never rewritten.
4. Append the lines in the script itself. When the message's last paragraph, after the subject, is all `<token>: <value>` lines, the trailers join it. Otherwise a blank line comes first. A trailer is skipped when the same line is already in that paragraph, or earlier in the list.

`git interpret-trailers` is not used (review 2, item 4). Git's `trailer.<x>.key` can rename a token past the reserved check, and `trailer.<x>.cmd` runs a command on every commit. No `trailer.*` setting reaches the lines now.

`progress.sh show-message <feature> <message file>` prints the copy step 4 makes, and commits nothing. K shows each uncommitted message this way, so the owner's answer covers every line the commit carries.

## Pinned strings

| Site | Pinned text |
|---|---|
| SKILL.md Configuration table | the whole `commitTrailers` row |
| SKILL.md Flags table | the whole `--trailer` row |
| SKILL.md probe block | the `Trailers` line |
| SKILL.md K | the sentence that K shows each uncommitted message as `show-message` prints it |
| SKILL.md **Base branch:** pointer | `commitTrailers` and `--trailer` in the list of names that send the run to the docs page |
| `pipeline/docs/configuration.md` | the bold add rule and its sentence, the reserved-token rule, the pre-flight argument, the recorded shape, the list of commits, the no-hand-trailer rule, the resume rule, the gate shows the trailers, the refused-trailer rule, the skip-ci rule; the old "does not show" sentence must not return |
| `pipeline/CHANGELOG.md` | the bold lead of the entry |
