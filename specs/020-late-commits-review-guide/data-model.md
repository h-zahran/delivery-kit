# Data model: what the new prose tells the orchestrator to write

The orchestrator writes the run state file
(`.delivery-kit/runs/<feature>/progress.json`) through `progress.sh`
subcommands and, for keys no subcommand covers, whole-file with `jq` followed
by `validate`. This feature adds no subcommand and no script change (research
R4). Everything below is written by prose this feature adds.

## `commits[]` — one entry per commit, via `commit-add`

Shape fixed by `progress.sh` (`sha`, `kind`, `piece`, `tasks`, `files`).
`commit-add` appends, so array order is recording order, NOT commit order: the
review guide takes its order from `git rev-list --reverse <base>..HEAD` and
joins each sha to its entry (research R9).

| Kind | Written by | `piece` | `tasks` | `files` |
|---|---|---|---|---|
| `spec` | H (Phase 20, unchanged) | empty | empty | the spec directory's paths |
| `piece` | H (Phase 20, unchanged) | heading | task IDs | the piece's paths |
| `converge` | H.5 | the appended heading, as `piece-next` prints it (converge writes `Phase N: Convergence`) | the appended task IDs | H.5's paths |
| `simplify` | H.7 | empty | empty | H.7's paths |
| `review` | I | empty | empty | I's paths |
| `tests` | J | empty | empty | J's paths, or none for J's empty commit |
| `other` | K (the remainder); L and DONE (any commit in `<base>..HEAD` not yet recorded that carries no `Piece:` or `Late:` line and is not the spec commit — M's and N's) | empty | empty | the commit's paths |
| `constitution` | K (a constitution written at pre-flight) | empty | empty | the constitution path |

Rules: only `tests` may have no files; a `converge` or `piece` heading is
never offered again by `piece-next`. The one write to `commits` outside
`commit-add` is V6's removal of stale entries, whole-file with `jq` then
`validate`, on the owner's answer.

## `measurements.lateBefore` — a late phase's before list

`{ "phase": "<H.5|H.7|I|J>", "paths": [ … ] }`. Written when a late phase
starts unless it already names that phase (a resumed phase keeps its saved
list). The late commit's paths are those `git status --porcelain=v1 -z
--untracked-files=all --no-renames` lists when the phase ends and that are
absent from `paths`; never a path under `.delivery-kit/`.

## `gates` — new entries

| Key | Written by | Value |
|---|---|---|
| `gates.K` | K | `list`: whether `<base>..HEAD` held a commit when K first started (K12); `answer`: K's answer (`auto` when `--auto` collapsed K), the only field a re-entry reads as answered; `nothingToCommit: true` when nothing was left (K4); `oddPaths`: the paths K stopped for (K5); `unshowable`: any commit it could not show (K10) |
| `gates.L` | L | the answer; `staleRemoved`: the `commits` entries removed on the owner's answer (V6), with their shas |
| `gates["H.5"]`, `gates["H.7"]`, `gates.I`, `gates.J` | a late phase whose commit a hook rejected | a failure entry: the phase, the hook's output redacted (the fact and its location, never the value) |
| `gates.trackedState` | Resume | the confirmation and when it was given; never read to suppress a later stop (research R14) |
| `gates.G` | G, on a resume into an unfinished G whose `gates.G` is a plain string | becomes `{ "answer": <the string>, "reviewMode": "commits"|"pauses" }` |

`gates.J` keeps what it holds today (the waved-through failures and the
answer); the failure entry sits beside them.

## Commit messages

- A late commit: `commitStyle`, names the phase, and a line of its own
  `Late: <phase letter>` (research R12). H.5's also carries
  `Piece: <heading>` for the appended phase, so H's crash scan finds it.
- J's empty commit: `commitStyle`, the waved-through failures, redacted, plus
  `Late: J`.
- K's remainder: `commitStyle`, as today.

## The review guide (derived, never stored)

Built at L and again at DONE, after recording any unrecorded commit in
`<base>..HEAD` as `other` (V3). Run as
`jq -r --argjson shas "$(git rev-list --reverse <base>..HEAD | jq -R . | jq -s .)" -f guide.jq <state file>`
— the program is written to a file, never typed inline (heredocs through the
agent's shell tool are not byte-safe):

```jq
# Input: the run state file. $shas: `git rev-list --reverse <base>..HEAD`
# as a JSON array. One row per commit on the branch, in branch order, joined
# to its `commits` entry by sha. A sha with no entry, an entry whose sha is not
# on the branch, or a piece name or path holding a carriage return or a line
# feed is an error; the orchestrator records unrecorded commits first (V3) and
# stops on a stale entry (V6) before running this. A piece name or path is a
# code span fenced by one more backtick than its longest run of backticks.
def code: if . == "" then ""
  else ((([match("`+"; "g") | .length] | max) // 0) + 1) as $n
  | ("`" * $n) as $f
  | if test("^`|`$") then $f + " " + . + " " + $f else $f + . + $f end end;
([.commits[]?.sha] - $shas) as $stale
| if ($stale | length) > 0 then error("entries not on the branch: \($stale | join(" "))") else . end
| ($shas - [.commits[]?.sha]) as $missing
| if ($missing | length) > 0 then error("commits not recorded: \($missing | join(" "))") else . end
| [.commits[]? | (.piece // ""), (.files // [])[] | select(test("[\r\n]"))] as $bad
| if ($bad | length) > 0 then error("a cell holds a line break: \($bad | map(@json) | join(" "))") else . end
| .commits as $c
| "Read this branch commit by commit, top to bottom: each row is one commit, oldest first.",
  "",
  "| Commit | Kind | Piece | Task IDs | Files |",
  "|---|---|---|---|---|",
  ($shas[] as $s
   | ([$c[] | select(.sha == $s)] | first) as $e
   | [$e.sha[0:7], $e.kind, (($e.piece // "") | code), (($e.tasks // []) | join(",")),
      (if (($e.files // []) | length) == 0 then "(no files: empty commit)" else ($e.files | map(code) | join(", ")) end)]
   | map(gsub("\\|"; "\\|"))
   | "| " + join(" | ") + " |")
```

Measured 2026-09-30 against a state file written only by `progress.sh
commit-add` (whose `tasks` is a list): rows in `rev-list` order whichever order
the shas came in; a `|` in a piece name or path escaped as `\|`, keeping five
columns; a piece name or path shown as a code span fenced by one more backtick than
its longest run (a path holding one backtick came out fenced by two); a cell holding a
line break refused with its own message (exit 5; re-measured at I, round 2);
an empty `tests` commit shown as `(no files: empty commit)`; a stale
entry and an unrecorded sha each exit 5 with their own message and print no
table. The caller checks the exit status and discards the output on failure.

Every row is printed — never truncated.
