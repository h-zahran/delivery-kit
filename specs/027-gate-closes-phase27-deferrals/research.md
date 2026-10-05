# Research: the release gate closes what Phase 27 deferred

Every measurement here was taken 2026-10-05 on this machine (Git Bash,
bash 5.3.9, jq 1.8.1) at `2e5b6d7`, whose `scripts/` and `tests/` are
identical to `5a78ea4`, unless it names another place.

## R1 — No link is followed

- **Decision**: in both forms, refuse a symbolic link at every path in
  the spec's table, before any tool reads through it, with the gate's own
  message:
  1. BEFORE the `-f .claude-plugin/marketplace.json` test (`:86`):
     `[ -L .claude-plugin ]` and `[ -L .claude-plugin/marketplace.json ]`,
     so a broken link is refused as a link and not as "run me from the
     repository root" (which `-f` alone gives, measured at Phase 27 F);
  2. in the per-plugin loop, with `shown p_s "$p"` moved above them
     (at `:177` it comes after `:175`, so a message would name the plugin
     before), and before the `-f plugin.json` test: `[ -L "./$p" ]` (not
     `$dir`: `[ -L dl/ ]` is false for a link, measured at F) when
     `./$p/.claude-plugin` exists or is itself a link, then `[ -L
     "./$p/.claude-plugin" ]`, then `[ -L "./$p/.claude-plugin/plugin.json" ]`;
  3. in the reverse walk, before the `-f` test: every component of the
     normalised source, then its `.claude-plugin` and `plugin.json`.

  Link coverage is placed by hand at each read path, derived from the
  script once (the spec's table); a derived scan of every `-f`, `jq` and
  redirect path, so a future read path cannot miss its check, is left
  for a later phase (plan, Complexity Tracking).

  The reverse walk's component check runs over cumulative prefixes
  (`./a`, `./a/b`, …), built by prefix and suffix removal, and stops when
  no `/` is left, or at the first prefix that is neither a link nor
  there (`[ -e ]` after the `-L` test: below a missing directory nothing
  can be a link). Before that walk, a source of more than 64 components
  (`component_limit`) is refused, the count taken from `ed` itself
  (`t=${ed//$nsl/}` with `nsl='[!/]'`, components `${#t} + 1`): a count
  kept inside the walk never reaches 64 on a source whose second
  component is missing, because the early stop ends the walk first
  (measured at F, round 4). A fork sets the source, so the unbounded walk
  would reopen the stall `8395cf5` closed. Measured at F, rounds 3 and
  4 (bash 5.3.9 only; bash 3.2 is first measured by macOS CI, where N7
  runs): checking every prefix with no early stop took 26 s for one
  source of 1,024 components; the count from `ed` takes 1.8 ms on a
  4,091-character source, which is then refused; 2,000 entries of
  `./handoff` cost about 0.4 ms each. The walk is skipped when `ed` equals
  the source it last checked. **Limit**: a committed 64-deep real tree
  still costs 21 to 59 ms an entry here (Windows; a stat is cheaper on
  Linux), so a fork can list many entries alternating between two deep
  sources; the walk fails closed by count, and its total cost is
  recorded, not bounded, here; a top-level source is met by the forward loop first,
  so its own `.claude-plugin` and `plugin.json` checks are reached only
  by a nested source, which the tests plant.

  `[ -e ./$p/.claude-plugin ]` stats through a directory link before the
  link is refused. That one stat reads nothing and prints nothing; it is
  how the gate tells a plugin directory from any other folder.

  A top-level directory that is a link and holds no `.claude-plugin` is
  skipped, as today: the gate reads nothing in it, and a contributor's
  own linked folder (untracked) must not stop a local run.
- **Rationale**: measured at `5a78ea4`: a `plugin.json` link to a file
  outside the tree was read and its name printed; a `marketplace.json`
  link and a plugin-directory link each passed. The real tree holds no
  tracked link (`git ls-files -s`, mode 120000: 0), so R1 of the
  contract holds. A link is refused wherever it points: simpler than
  judging targets, and a wrong refusal is acceptable.
- **Alternatives**: resolve links and accept those inside the tree
  (more code, and a link can change after the check); refuse every
  top-level link (would stop a contributor's untracked linked folder).

## R2 — No line from `jq` reaches the output

- **Decision**: each file is checked once, up front, for the shape the
  later reads need, with `jq -e -s` and its standard error discarded,
  after `command -v jq` (`:89`: with `jq` missing the status would be
  127, which the rule below would call "not valid JSON"). `-s` and
  `length == 1`, because `jq -e` judges only the last of several JSON
  documents (measured at F: `{"plugins":"x"}` then a valid document
  exits 0). The filter is type-guarded (`.[0] | type == "object" and
  …` first), because a filter that errors on valid JSON of the wrong
  type exits 5, which would read as "not valid JSON" (measured at F:
  `[1,2]` and `"s"`):
  - `marketplace.json`, after an open check like Phase 27's: `.plugins`
    is an array of objects whose `name`, `source` and `version`, when
    present, are strings, and no string anywhere holds a NUL;
  - `plugin.json`, after its open check: an object whose `name` and
    `version`, when present, are strings, and no string holds a NUL. A
    missing field keeps its message from `5a78ea4` (`has no name` and
    the rest); so does `false` or `null` (`.name // ""` lets them through,
    and every later read uses `// empty`: measured at F, round 3).

  The exact filters, each run as `jq -e -s '<filter>' < <file>` with
  standard error discarded:

  ```text
  marketplace.json: if length == 0 then error else length == 1 and (.[0] | type == "object" and (.plugins | type) == "array" and all(.plugins[]; type == "object" and ((.name // "") | type) == "string" and ((.source // "") | type) == "string" and ((.version // "") | type) == "string")) and all(.. | strings; all(explode[]; . != 0)) end
  plugin.json:      if length == 0 then error else length == 1 and (.[0] | type == "object" and ((.name // "") | type) == "string" and ((.version // "") | type) == "string") and all(.. | strings; all(explode[]; . != 0)) end
  ```

  Statuses, measured at F, round 3, on exactly those filters (jq 1.8.1,
  native Windows): valid 0; `{"plugins":[]}` 0; an entry
  `{name:false, source:false}` 0; a `plugin.json` with no name 0; two
  documents 1; `[]` 1; `{}` 1; `{"plugins":"x"}` 1; `{"plugins":[1]}` 1;
  a name that is an object 1; a numeric version 1; a numeric
  `plugin.json` name 1; a NUL inside a string, written as the `\u0000`
  escape, 1; a raw NUL byte (not JSON) 5; empty 5; whitespace only 5;
  not JSON 5. Round 4 reproduced these and found the real
  `marketplace.json` and both real `plugin.json` files give 0. `error` with no message exits 5 and prints a line to
  standard error, which is discarded. A NUL matters because bash, not
  `jq`, then prints `warning: command substitution: ignored null byte in
  input` with the script's path (measured at F, round 3, for the reads
  at `:189` and `:234`).

  `jq -e` exits 1 on a false shape and 5 on text that is not JSON
  (measured, jq 1.8.1; older jq exits 2), so the gate says which: "is
  not valid JSON" for any status but 0 and 1, and "… is not a list of
  entries whose name, source and version are strings" (or the
  `plugin.json` equivalent; the exact strings are in `data-model.md`,
  which is the one source for them) for 1. A file that cannot be opened keeps
  its own message, "could not be read". Every later `jq` read discards
  its standard error and ends in `|| die` with the gate's own line, so
  even a failure the shape check did not foresee prints nothing of
  `jq`'s. That discard is a backstop: once the shape check has passed,
  no plant can make a later read fail, so it has no mutant of its own.
  Nor can the backstop stand in for `-s`: jq 1.8.1 exits 0 when an
  earlier document fails and a later one succeeds (measured at H, T006),
  so a two-document file reaches no `|| die` at all; only the shape
  check's `-s` stops it.
  With `-s` (measured at F, round 2, native jq 1.8.1): one valid
  document 0; two documents 1; `[]` 1; not JSON 5; a broken second
  document 5; CRLF line ends 0; an empty or whitespace-only file 1,
  because `-s` makes it `[]`. An empty file is not JSON, so the filter
  sends `length == 0` to `error` (status 5): "is not valid JSON". A
  missing file never reaches `jq`: the open check runs first.
- **Rationale**: measured at `5a78ea4`: an entry whose `name` is an
  object printed `jq: error … object ({"::error t...) is not valid in a
  csv row`, exit 5; a `.plugins` that is a string printed `Cannot
  iterate over string ("::error ti...)`. Also measured: `jq -e` on
  `.plugins[] | select(.name == "zz")` exits 4 when nothing matches and
  5 when `.plugins` is a string, so the lookup at `:220` alone cannot
  tell "no entry" from "malformed file"; the shape check removes the
  second case before the lookup runs.
- The TRAILING test's first plant (an entry whose `name` is an object)
  is now stopped by the shape check before the `@tsv` read, so the
  errexit-around-`jq` behaviour it was written for is reached by no
  plant; that read is the backstop above. The test's comment says so.
- **Alternatives**: discard `jq`'s standard error at each read with no
  shape check (a malformed file would then read as "no entry named …");
  one real read inside `{ …; } 2>/dev/null` (a JSON error would read as
  "could not be read").

## R3 — `##[` never appears in a printed value

- **Decision** (clarified with the owner): every value is shown with
  `##[` replaced by `#?[`, wherever it is in the line. In `shown`, after
  the cut and the byte mask; and once on the walk's refusal text in
  bash, after the walk prints it, so the walk's own text does not change
  (R7). The pattern is held in a quoted variable: `[` is a pattern
  character, and Phase 27 found bash 3.2 mishandling a pattern written
  in place. Checked here on `a ##[error]b`, `###[x`, `##[##[`: none
  keeps `##[` (the replacement holds `?` before `[`, so it cannot form a
  new one). No real value or heading holds `##[`.
- **Measurement** (FR-003): the P test prints five probe lines through
  file descriptor 3, which bats writes to the CI log as they are, only
  when `GITHUB_ACTIONS` is `true`: `##[` at a line's start, `##[`
  mid-line (`# x ##[…`, a comment to bats), and `::warning::` as a
  control the runner is known to act on; and `##[group]` with
  `##[endgroup]`, because `##[` is the form the runner writes into its
  own logs and the log viewer folds a group, which no annotation shows.
  Both the annotations and the rendered log are recorded. Locally the
  probe prints nothing: its `::warning::` line is not TAP (bats reads a
  `#` line as a comment), and `scripts/check-suite.sh` refuses a
  non-TAP line (measured at F); CI does not run that check
  (`.github/workflows/ci.yml` runs bats directly). The first pull request run is read for
  annotations (`gh api` on each test job's check run), and what the
  runner did with each line is recorded here, with the run id. The probe
  is then removed by the first commit after that run, before merge.
  Result: (recorded at M).
- **Alternatives**: measure before H on a pushed probe branch (a push
  before gate L); mask only at a line's start (wrong if the runner acts
  mid-line, which is not yet known).

## R4 — Inherited shell options

- **Decision**: the gate's first command, at line 2 directly after the
  `#!` line and before the header comments, turns off `xtrace`,
  `verbose`, `noglob` and `keyword`. Placed lower, `verbose` echoed every
  comment line above it (measured at F).
- **Measured** on the real tree, every option `SHELLOPTS` can switch on
  (it can only switch options on):

  | Option | Exit | Standard output | Standard error |
  |---|---|---|---|
  | `xtrace` | 0 | same | 284 trace lines, every value uncut |
  | `verbose` | 0 | same | 489 lines: the script's text |
  | `noglob` | 1 | none | 1 line: the plugin loop found `*/` literally |
  | `keyword` | 1 | none | 1 line |
  | `noexec` | 0 | none | none: nothing runs |
  | `onecmd` | 0 | none | none: nothing runs |
  | `allexport`, `noclobber`, `nounset`, `errtrace`, `functrace`, `physical`, `privileged`, `history`, `histexpand`, `ignoreeof`, `monitor`, `notify`, `vi`, `emacs` | 0 | same | none |
  | `posix`, `errexit`, `pipefail`, `braceexpand`, `hashall`, `interactive-comments`, `igncr`, `nolog` (measured at F) | 0 | same | none |

  `BASHOPTS` (the `shopt` options, read from the environment from bash
  4.1) was measured at F for 16 options: each exit 0, same output on the
  real tree. It is recorded, not acted on.

  Measured at F, round 3, on a copy of the gate with that line at line
  2, both forms, from the repository root (Git Bash, bash 5.3.9 only;
  bash 3.2 on macOS and Linux bash are first measured by CI, where O1
  runs on each job): standard error exactly `+ set +o xtrace +o verbose
  +o noglob +o keyword` for `xtrace`, exactly the `#!` line and that line
  for `verbose` (no CR: `.gitattributes` keeps `*.sh` LF), and nothing
  for `noglob` and `keyword`; exit and standard output unchanged.

  With `set +o xtrace +o verbose +o noglob +o keyword` as the first
  command: `verbose` still echoes the `#!` line and that line (bash
  prints a line before running it), and `xtrace` traces that one
  command; no value appears. FR-006 says so.
- **Limit (FR-007)**: `noexec` and `onecmd` make the gate exit 0
  having printed nothing, and no line of the gate can stop that: none
  runs (a first-line `set +o onecmd` printed nothing). `BASH_ENV` runs a
  caller's file before the first line. All three are set only by the
  caller, never by a fork's files, and a caller who sets them controls
  the shell already; CI and the suite set none. The owner ruled
  `BASH_ENV` a recorded limit (clarification, 2026-10-05); `noexec` and
  `onecmd` follow the same reasoning, and the owner confirmed them as
  limits at gate G (2026-10-06). Partly caught already: the suite's version-agreement
  test asserts a report line (`*plugin=*`), so the suite would go red
  under `noexec`; CI's version job would not.
- **Alternatives**: re-run the gate under `env -i` from its own first
  line (it would still have run under `noexec`; and it changes how both
  callers see the environment); a caller-side check that the report
  line appeared. That check is possible: the suite has one already, and
  a CI step asserting `plugin=` in the version job's output need not
  break the one-script test, as long as `ci.yml` keeps exactly one
  `bash <x>.sh` line. It was the fallback had the owner not accepted `noexec` and
  `onecmd` as limits at gate G; the owner accepted them, so it is not
  built.

## R5 — No process per marketplace entry

- **Decision**: `norm_source <name> <value>` sets the named variable with
  `printf -v`, as `shown` does; both walks call it without `$( )`.
- **Measured** on the seed's fixture (the first plugin plus N entries
  sourced at it), same machine, same run, in a prototype: N = 400 took
  14.9 s with the subshell and 1.6 s without; N = 0 took 1.5 s and 2.1 s
  (this machine varies by a second between runs). T008 measures again on
  the final code and writes both figures here: on the seed's fixture
  (the first plugin plus 400 entries), the gate before T008 and after,
  alternating in one run, three rounds (`$RUN/t008-cost.txt`, Windows,
  `MINGW64_NT-10.0-26200`): before 9.0, 11.4 and 9.1 s, after 1.3, 2.1
  and 1.3 s; with no extra entry, before 1.2, 2.1 and 1.1 s, after 1.1,
  1.3 and 1.1 s. So about 20 ms an entry before and under 1 ms after.
  The 2,000-entry fixture C1 uses took 2.4 and 2.5 s after.
- **Test**: the walk plant runs 2,000 extra entries under `timeout 15`.
  With a process per entry, at the 20 to 37 ms an entry measured here
  (seed, and above), that is 40 s or more; without, a few seconds (measured
  at T008: 2.4 and 2.5 s on the 2,000-entry fixture, Windows). A mutant that restores the subshell goes red here; on a
  runner where a process is cheap it may not, and the test says which
  system it ran on.

## R6 — The tests check what they claim

- **P0** (FR-009): the scan also reports `printf -v` into a name ending
  `_s`, `read` into one, `for` over one, a `$(` that is not `$((`
  inside a `die` message, and continues a `die` line that ends in `\`
  onto the next. Its control plants one line of each shape and must
  name each exactly.
- **K3** (FR-010): the quote-marker plant takes the room under the size
  limit, as now, and its only floor is the rule under test: the line
  must be longer than the line limit. The fixed 50,000-pair floor goes.
  It broke at 153,948 bytes of copied changelog (262,144 − 8,192 −
  100,004); the new floor breaks
  only when the copy leaves less than the plant's margin and a
  1,001-byte line under the limit. The margin is cut from 8,192 bytes to
  64, so that is a copy over about 261,000 bytes, where today it breaks
  at 153,948. Corrected at F, which found the first wording ("only when
  the size rule refuses first") false, and then that the 8,192-byte
  margin left a 9 KB band.
- **gate_safe** (FR-011): removes only the gate's own text that holds an
  em dash, ` — this tree is NOT released`, before it checks; any other
  em dash fails it, and so does a line holding `##[` (the contract's
  "printed safely", so every N and J plant checks it too, not only X1).
  In its control, `ok — ok` moves to the must-fail list, the suffix is
  the must-pass case, and `a — b` and `x ##[y` join the must-fail list.

## R7 — Nothing else moves

- The walk's awk text is not touched; R3's `##[` mask runs on its output
  in bash. The quickstart's R2 check proves the sha256 is unchanged
  (`24c123b1…14896`), so the Phase 26 proof stands.
- Both forms on the real tree print as at `5a78ea4` (quickstart R1).

## R8 — Tests and their count

- One new test, "the gate follows no link, and keeps its own shell
  options", in this order: N7 (no link needed, so an older gate's first
  red is N7 on every system), N1 in both forms, N2-N4 in the default
  form only (no link or component check reads anything the form sets:
  the forward loop's run before anything form-dependent, which N1 shows,
  and the reverse walk's after a release-form changelog walk the fixture
  passes), then the `SHELLOPTS` plants (R4),
  then N6 (Linux and macOS only), and its `# nolinks:` line through file descriptor 3
  saying whether this system made links, as L1 does. Every other plant
  goes into an existing test: the `jq` shapes and the 2,000-entry walk
  into the TRAILING test; `##[` and the P0 changes into the P test; K3
  into the K test. The suite reads `1..252`.
- Times on this machine before the change are in Phase 27's records;
  T010 times every changed test on the final code, because each gate
  run now starts one or two more `jq`. A test over 30 s has its runs
  reduced.

## R9 — Portability

- Bash 3.2: `printf -v`, `[ -L ]`, `[[ =~ ]]` and quoted patterns in
  `${s//"$v"/…}` exist there; no `\/` inside a pattern substitution.
- `jq -e` exit status: 1 for false; a parse error 5 on jq 1.8.1
  (measured). That a parse error is 2 on jq 1.6 is from its
  documentation, not measured. The gate tests for 1 and treats every
  other non-zero status as "not valid JSON", which holds for either.
- Links: all three runners made links in Phase 27 (`# links: made`).
