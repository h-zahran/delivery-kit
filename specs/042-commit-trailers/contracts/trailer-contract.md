# Contract: commit trailers

## Spellings

| Spelling | Layer | Effect |
|---|---|---|
| `commitTrailers` key | a configuration file | The team's list. A later file's list replaces an earlier one's. |
| `--trailer <token: value>` flag | the command line, repeatable | Adds one trailer after the key's. Never replaces the key. |

The orchestrator passes the resolved list to pre-flight as `--trailer <text>`, once per trailer, the key's first, on a fresh run only. Pre-flight reports `commitTrailers`, an array in the same order.

## Refusals

The rule is one file, `pipeline/scripts/trailer-check.sh`, which takes the trailer as a JSON string. Pre-flight runs it on each trailer, and `with_trailers` runs it on each recorded trailer before every commit, so the two can never disagree (constitution, principle IV; review 3 found two hand-kept copies that already differed on U+0085). A test pins that both run the file and that neither holds a copy.

Each refusal exits non-zero and names the trailer: quoted, or as JSON when it holds a control character or a character from `scripts/hidden-chars.sh`, each C1 or hidden character as its `\u` escape (a surrogate pair above U+FFFF), so none reaches a terminal (review 3, blocking 1). Pre-flight's messages end `(a commit trailer)`: the value may come from the key or the flag, and the script cannot tell which. `progress.sh` frames the same text as `the recorded trailer … — no commit is made`.

| Trailer | Message part |
|---|---|
| holds CR or LF | `holds a line break; a trailer is one line` |
| holds another control character, in Unicode's sense: C0, DEL and the C1 range U+0080-U+009F (NEL among them), read by jq | `holds a control character` |
| holds a character from `HIDDEN_CHARS` in `scripts/hidden-chars.sh`, the one list `progress.sh` checks questions against: bidi, invisible and zero-width characters, variation selectors, the tag plane, the byte-order mark (review 3, blocking 1) | `holds a character that can disguise text in a terminal` |
| no `:` | `has no ':'; write <token>: <value>` |
| token not `^[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9]$` | `a token starts with a letter, ends with a letter or a digit, and holds letters, digits and dash only` |
| value empty or only spaces | `has an empty value` |
| token `Piece`, `Late` or `Tasks`, any letter case | `reserved for the run's own markers` |
| token `skip-checks`, `Co-authored-by`, `Signed-off-by`, `On-behalf-of`, or a closing keyword (`close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`), any letter case | `which acts on GitHub or names another author` |
| value holding `[skip ci]`, `[ci skip]`, `[no ci]`, `[skip actions]` or `[actions skip]`, any letter case | `asks GitHub to skip the checks` |
| a closing keyword anywhere in the trailer, the token included (`Will-Fix: #1`), at a word boundary, before an issue written `#12`, `owner/repo#3`, `GH-1` or as the issue's URL, with or without a `:` or a space between, any letter case (review 3, blocking 2) | `would close an issue` |
| holds `'`, `$` or a backtick: the run types the list into a shell command, `state-set … '<json array>'` (review 4, non-blocking 6) | `holds a quote ('), a dollar sign or a backtick; a trailer is typed into a shell command` |
| holds `##[` anywhere, which a GitHub runner reads as a workflow command (`specs/027-gate-closes-phase27-deferrals/research.md` R3) (review 4, minor) | `holds '##[', which a workflow log reads as a command` |

## Commits that carry the list

Every commit a `progress.sh` subcommand makes: `spec-commit` (subject unchanged), `piece-commit`, `late-commit` (J's `--record` included) and `remainder-commit` (kinds `other` and `constitution`). Not the handoff path's external commits.

## Recorded shape

`config.commitTrailers`: an array of `<token>: <value>` strings, the list pre-flight reports, in order. `config.commitTrailersFrom`: each entry's layer, in the same order, for the probe line. Missing, `null` or `[]` means no trailers.

## Mechanism

`with_trailers <message file>` in `progress.sh`, called by `commit_named` and by J's `--record` commit:

1. Read `config.commitTrailers`. Anything but an array of non-empty strings stops, naming the state file. No commit is made.
2. Pass each entry, as JSON, to `trailer-check.sh`. JSON, because `jqs` strips a CR and a shell argument cannot hold NUL. A bad one stops, naming it.
3. Copy the message to a file of this call's own, `mktemp "<run dir>/trailers-msg.XXXXXX"` (the check's error file is `trailer-check.XXXXXX` there, and `show-message --record`'s message `show-record-msg.XXXXXX`), and commit the copy. The caller's file is never rewritten, and the EXIT trap removes each file the call made, never one a name inherited from the environment points at (review 3, item 7; review 4, minor).
4. Append the lines in the script itself. When the message's last paragraph, after the subject, is all `<token>: <value>` lines, the trailers join it. Otherwise a blank line comes first. A trailer is skipped when the same line is already in that paragraph, or earlier in the list.

`git interpret-trailers` is not used (review 2, item 4). Git's `trailer.<x>.key` can rename a token past the reserved check, and `trailer.<x>.cmd` runs a command on every commit. No `trailer.*` setting reaches the lines now.

`progress.sh show-message <feature> <message file>` prints the copy step 4 makes, and commits nothing. With `--record` it prints J's empty record commit, built by the same `j_record_msg` that `late-commit J --record` uses. K shows each uncommitted message this way, so the owner's answer covers every line the commit carries.

## Pinned strings

| Site | Pinned text |
|---|---|
| SKILL.md Configuration table | the whole `commitTrailers` row |
| SKILL.md Flags table | the whole `--trailer` row |
| SKILL.md probe block | the `Trailers` line |
| SKILL.md K | the sentence that K shows each uncommitted message as `show-message` prints it, `--record` for J's record commit |
| `pipeline/scripts/preflight.sh`, `pipeline/scripts/progress.sh` | each runs `trailer-check.sh`, and neither holds a copy of the rule (`prose.bats`, "the trailer rule lives in one file, and both callers run it") |
| SKILL.md **Base branch:** pointer | `commitTrailers` and `--trailer` in the list of names that send the run to the docs page |
| `pipeline/docs/configuration.md` | the bold add rule and its sentence, the reserved-token rule, the pre-flight argument, the recorded shape, the list of commits, the no-hand-trailer rule, the resume rule, the gate shows the trailers, the refused-trailer rule, the skip-ci rule, the one-file sentence; the old "does not show" sentence must not return |
| `pipeline/CHANGELOG.md` | the bold lead of the entry |
