# Contract: `commit-add` and `piece-next`

Both are subcommands of `pipeline/scripts/progress.sh`, called from the
repository root. Both inherit the script's contract (`progress.sh:4-7`):
results on stdout, every diagnostic on stderr, prefixed `progress.sh: `.

## `progress.sh commit-add <feature> <kind> <sha> <piece> <tasks> [<file>...]`

| Argument | Meaning |
|---|---|
| `<feature>` | the run's feature name (`NNN-slug`); same shape rule as every command |
| `<kind>` | one of `spec piece converge simplify review tests constitution other` |
| `<sha>` | the full 40-character lowercase commit id |
| `<piece>` | the piece heading text as `piece-next` printed it; `""` when not a piece |
| `<tasks>` | task ids, comma-separated; `""` for none |
| `<file>...` | the exact paths the commit changed; none only for `tests` |

**stdout:** nothing. **Exit 0** when an entry was appended, or when an
identical entry was already recorded (no write).

**Exit 1, state file unchanged**, with a stderr message containing the quoted
phrase, when:

| Condition | Message contains |
|---|---|
| the feature given, but fewer than four arguments after it | `commit-add needs` |
| kind contains anything but lowercase letters, or is not legal | `unknown kind` |
| sha empty | `needs a commit id` (worded `the entry needs a commit id`, so it never contains the argument-count fragment) |
| an empty path in the file list | `empty path` |
| an empty task id in the task list | `empty task id` |
| sha not 40 lowercase hex | `not a full commit id` |
| sha recorded with different details | `already recorded with different details` |
| sha claimed by an old-style entry | `already recorded by an old-style entry` |
| no valid state file | `no state file` (from `validate`) |
| kind `piece` with empty piece name | `needs a piece name` |
| kind `piece` with empty task list | `needs its task ids` |
| piece name holds CR, LF or U+001F | `piece name holds a control character` |
| empty file list, kind not `tests` | `needs the files it changed` |

With NO argument after the command, the helper's existing usage error fires
before `commit-add` runs; that case is the usage line's, not this table's.

The `unknown kind` message lists the legal kinds. The file list is handed to
jq after `--args --`, so a path starting with `-` is data, not an option.
Paths are passed relative, as git shows them — Git Bash on Windows rewrites
an argument that looks like an absolute POSIX path before a native jq sees it.

## `progress.sh piece-next <feature>`

**stdout, when a piece remains:** exactly two lines —

```
<heading text after "## ", verbatim, no CR>
<task ids, comma-separated, no CR>
```

**stdout, when every piece is recorded:** nothing. **Exit 0** in both cases.

**Exit 1** with a stderr message containing the quoted phrase, when:

| Condition | Message contains |
|---|---|
| no valid state file | `no state file` (from `validate`) |
| no `artifacts.tasks` recorded | `records no tasks file` |
| tasks file missing | `tasks file not found` |
| no piece in the tasks file | `no piece` |
| the next piece's heading holds U+001F, a NUL, or a CR left after its one trailing CR is removed | `heading holds a control character` |

`piece-next` never writes a file.

## Usage line

`progress.sh` with too few arguments prints a usage line naming every command,
including `commit-add` and `piece-next`, and exits 1.
