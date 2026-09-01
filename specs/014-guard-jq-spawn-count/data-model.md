# Phase 1 data model: the two extraction shapes

No database, no persisted records. The "entities" here are two in-memory
extractions, each turning one JSON source into four shell variables. Only *how*
they are produced changes; *what* they hold must not.

## Entity: the payload extraction

**Source**: the JSON object the hook receives on stdin, held in `$input`.

| Variable | JSON field | Default when absent | Consumed by |
|---|---|---|---|
| agent identifier | `.agent_id` | empty | the subagent early exit |
| transcript path | `.transcript_path` | empty | the existence check, then the reading |
| session identifier | `.session_id` | `unknown` | the once-per-bucket flag |
| working directory | `.cwd` | empty, then falls back to `$PWD` | locating the repository configuration |

### Before

Four `jq` invocations, each with its own `// ` default, each captured through
command substitution. Spread across the file: the agent identifier inside an
`if` at `:89`, two assignments at `:93`–`:94`, and the working directory at
`:104` after an unrelated comment block.

### After

One `jq` invocation, the four values joined by the unit separator, captured
through command substitution and split with **parameter expansion**. Placed
once, before the subagent check.

The split is deliberately not `read`. A JSON string value may contain a
newline, and `read` stops at the first one: it would keep a prefix and drop
every field after it. Parameter expansion splits on the separator byte alone
and leaves an embedded newline inside its own field, which is what the
per-field `$()` did. This is measured, not argued — see the validation rule
below, and the differential recorded in the changelog entry.

### Validation rules

- **Every default is preserved exactly**, including the `unknown` placeholder,
  which moves from the shell into the jq program.
- **Empty values must survive in every position, including the first.** The
  agent identifier is empty in the ordinary case, so this is the common path,
  not an edge case.
- **One field of an unexpected type must not abort the extraction.** Enforced by
  `map(tostring)` before the join, the same guard the configuration program
  already carried. `join` errors on a non-string, an erroring `jq` yields an
  empty payload, and an empty payload gives an empty transcript and a guard that
  exits silently — the one direction this hook must never fail in. Measured with
  a `cwd` that is an object; the payload program shipped without this and did
  exactly that.
- **jq's own trailing line ending must not reach any variable.** Enforced by
  the capture: `jq` emits `\r\n` on this platform, and `$()` under MSYS2 bash
  strips the trailing carriage return along with the newline. Measured.

  Read that rule for exactly what it says, because an earlier wording claimed
  more and was wrong. It is **not** a guarantee that no carriage return reaches
  any variable: a value that itself contains a newline arrives as `\r\n` in the
  middle of its own field, and it did so before this change too. Nor is "the
  output is one line" a property of the program — it is an assumption about the
  data, and a value containing a newline breaks it. What the program actually
  enforces is that the split does not depend on the line count at all.
- **The working-directory fallback to `$PWD` stays in the shell**, not in the
  jq program: `$PWD` is a shell fact, and moving it would change what the
  fallback means.

## Entity: the configuration extraction

**Source**: an optional JSON file. Two are read in precedence order, and each
key inside is independently optional.

| Variable | JSON field | Validated by |
|---|---|---|
| window | `.contextGuard.windowTokens` | positive integer |
| threshold percentage | `.contextGuard.thresholdPct` | valid threshold, with an upper bound |
| threshold tokens | `.contextGuard.thresholdTokens` | positive integer, no upper bound |
| byte cap | `.contextGuard.maxBytes` | positive integer |

### Before

Four `jq` invocations per file, after an early return that costs nothing when
the file is absent.

### After

One `jq` invocation per file, after the same early return. Values are passed
through `tostring` before joining.

### Validation rules

- **The early return stays first.** An absent file must still cost zero
  processes; it is what makes the count vary by path.
- **All validation stays in the shell, unchanged.** Nothing moves into jq except
  the extraction and the empty default.
- **A value that is rejected today is rejected after** — including one written
  with a leading zero, whose rejection the file explains at length and whose
  reasoning must survive.
- **An absent key must leave its own slot empty, not shift the others.** This is
  the rule the naive design breaks, and the breakage passes validation: every
  value here is a positive integer, so a value landing in the wrong slot is
  installed rather than rejected.

## Entity: the process count

Not data the program holds — data *about* the program, and the thing being
reduced.

| Configuration files present | Whole run, before | Whole run, after | Slice before the transcript, before | Slice, after |
|---|---|---|---|---|
| 0 | 8 | 5 | 5 | 2 |
| 1 | 12 | 6 | 9 | 3 |
| 2 | 16 | 7 | 13 | 4 |

The seed states the two right-hand columns and states them correctly. The
constant three-process difference between the pairs is the transcript reading —
two content passes and one median — which this change does not touch, so both
columns fall by the same amount.

Every number above is the **non-firing** path — the one that runs after almost
every tool call, and the one the seed also quotes. A run that actually fires
spends one more on the emission that writes the blocking instruction: measured,
6 rather than 5 with no configuration file. That call is the output itself and
is not reducible.

Every number is measured by counting invocations with a shim, never inferred
from reading the source. The availability check survives in every row and is not
removed to improve the figure. The shim records one token per invocation, not
per line: two of the jq programs span several lines, and a line-counting shim
reports nearly double.

## State transitions

None. Both extractions are single reads with no lifecycle. The hook runs, reads,
decides and exits.
