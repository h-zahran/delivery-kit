# Phase 0 research: the context guard stops counting jq

Everything here was measured on 2026-09-01 against `main` = `45e6b12`, on
Windows under Git Bash with `jq-1.8.1` from the user's package manager.
Re-measure before trusting a line: a recorded measurement is evidence of what
was true when it was taken.

The two probe scripts that produced these numbers are reproduced in
[quickstart.md](./quickstart.md) so anyone can re-run them.

## Decision 1 — the seed's `@tsv` spelling is rejected, on evidence

**Decision**: emit one line with the fields joined by the **unit separator**
(`\u001f`, written as a jq escape) and split it with `IFS=$'\037' read -r`.
Do **not** use `@tsv` with `IFS=$'\t' read`.

> **Amended 2026-09-01, during phase M.** Two *spellings* in this decision were
> superseded after review; the decision itself — unit separator, not tab — was
> not, and everything below still holds. The separator is no longer written a
> second time as a jq unicode escape inside each program: it is defined once as
> `US=$'\037'` and handed to jq with `--arg`, so one definition cannot
> desynchronise from another and no escape appears in the jq source at all. And
> the split is no longer `IFS=$'\037' read -r`, which shipped in `765ce87` and
> was measured broken; it is parameter expansion. See the "Superseded in part"
> note under Decision 2.

**Rationale**: tab is an *IFS-whitespace* character. When IFS contains only
whitespace characters, the shell collapses runs of them and strips leading and
trailing ones. An empty field therefore does not survive.

Measured, splitting a payload four ways:

| Payload | Today | `@tsv` + `IFS=$'\t' read` | unit separator |
|---|---|---|---|
| main session (no `agent_id`) | `agent=[]` `transcript=[/t]` `session=[s]` `cwd=[/c]` | `agent=[/t]` `transcript=[s]` `session=[/c]` `cwd=[]` | `agent=[]` `transcript=[/t]` `session=[s]` `cwd=[/c]` |
| subagent (`agent_id` present) | `agent=[a1]` … | `agent=[a1]` … | `agent=[a1]` … |

**The consequence is not cosmetic.** The hook's first act is:

```
if [ -n "<agent_id>" ]; then exit 0; fi
```

With the naive split, `agent_id` in the main session reads as the transcript
path, which is non-empty. Measured verdicts:

| Payload | today | naive | candidate |
|---|---|---|---|
| main session | continue | **EXIT 0 — treated as a subagent** | continue |
| subagent | exit 0 | exit 0 | exit 0 |

So the guard would silently never fire again in the main session. The file's own
comment at that branch says a check that fails toward silence in the main
session *"would fail toward silence in the MAIN session, which is the one
direction this hook must never fail in."* The naive refactor does exactly that.

**Alternatives considered:**

- *`@tsv` with a sentinel trailing field.* Fixes the trailing case, not the
  leading one. The leading one is the one that matters.
- *Newline-separated output, one `read` per line.* Defeated by Decision 2.
- *`@sh` output plus `eval`.* Correct, but introduces `eval` into a security-
  adjacent hook to save nothing over the separator approach.

## Decision 2 — one line, not several, because jq emits CRLF here

**Decision**: the single jq call must produce **one line**, captured with
command substitution.

**Rationale**: measured on this machine, `jq -r` output carries `\r\n`:

```
$ printf '%s' "$J" | jq -r '.transcript_path' | cat -A
/t^M$
```

Command substitution strips the trailing carriage return along with the
newline, so `v=$(… | jq -r …)` is clean — which is why the *current* per-field
code has never had this problem. `read` does **not** strip it. A design that
emits four lines and reads them one at a time would put a stray carriage return
on three of the four values.

Verified on the chosen design: the last field, after `$()` capture and an
`IFS=$'\037' read`, contains no `^M`.

This is a second, independent reason for the single-line separator design. Even
if tab were safe, multi-line would not be.

### Superseded in part, 2026-09-01, during phase M

The reasoning above stands; the **splitter** named in it does not. This note is
appended rather than folded in, because the finding is only legible against the
decision that produced it.

`IFS=$'\037' read` shipped in `765ce87` and phase M's review found it broken.
`read` stops at the first newline, and a JSON string value may legally contain
one — so `read` kept a prefix and silently dropped every field after it.
Measured: a `windowTokens` of `"5\n999999"` lost `thresholdPct`,
`thresholdTokens` and `maxBytes` outright, and the hook applied the default 45%
where the pre-change hook applied the configured 50%.

Note what this does to the verification two paragraphs up. "The last field
contains no `^M`" was true of the *sample*, and it generalised no further:
a carriage return does reach a variable whenever a value contains a newline,
because jq writes that newline as `\r\n` **inside** the field. The property
`$()` actually enforces is narrower — it strips jq's own trailing line ending,
nothing more. Both were re-measured on 2026-09-01.

The splitter is now parameter expansion (`${var%%…}` / `${var#…}`), which cuts
on the separator byte alone and leaves an embedded newline inside its own
field — restoring exactly what the per-field `$()` did. Equivalence was
re-proved with a differential harness: the pre-change hook against the fixed
hook over 26 payload and configuration shapes, comparing stdout and exit code.
26 identical, 0 different. See
[contracts/extraction.md](./contracts/extraction.md), "Two hazards the join
creates".

## Decision 3 — the configuration split has the same bug, and it is worse

**Decision**: `read_config` uses the same separator scheme.

**Rationale**: the payload bug kills the guard loudly-ish — it stops working
entirely, which somebody eventually notices. The configuration bug is quieter.

Measured, with a configuration file where `thresholdPct` is absent (an entirely
supported shape — every key is optional):

| | `windowTokens` | `thresholdPct` | `thresholdTokens` | `maxBytes` |
|---|---|---|---|---|
| today | `1000000` | *(empty)* | `650000` | `9999` |
| naive `@tsv` | `1000000` | `650000` | **`9999`** | *(empty)* |
| candidate | `1000000` | *(empty)* | `650000` | `9999` |

Every value is a positive integer, so **the shifted values still pass
validation.** `is_positive_int 9999` is true, so `THRESHOLD_TOKENS` would be
installed as `9999` instead of `650000` — a guard that fires at ten thousand
tokens instead of six hundred and fifty thousand.

No error. No message. No failing test. The shifted `thresholdPct` of `650000`
happens to be rejected by the upper bound in `is_valid_threshold`, which is luck
rather than design, and it is the only reason the damage stops at one field.

## Decision 4 — `tostring` on the configuration values

**Decision**: apply `. // "" | tostring` to each configuration value before
joining.

**Rationale**: the configuration values are JSON *numbers*, not strings.
Measured on jq 1.8.1, `join` handles numbers without help:

```
$ echo '{"a":1,"b":2}' | jq -r '[.a,.b] | join("-")'      -> 1-2
$ echo '{"a":1,"b":2}' | jq -r '[.a,.b] | map(tostring) | join("-")' -> 1-2
```

Identical here. `tostring` is kept anyway because CI runs a different jq than
this machine does, and this repository has already been bitten by exactly that
class of difference — see the shellcheck version gap, where CI's older analyser
reported more than the local one. One token of jq buys out the version
question; verifying jq's `join` semantics across every version CI might use
does not.

Note the interaction with `false`: `false // ""` yields `""`, so a configuration
value of `false` becomes empty and is rejected. That matches today exactly —
`jq -r '.x // empty'` also treats `false` as absent — so it is preservation, not
a new behaviour.

## Decision 5 — the availability check stays inside the budget

**Decision**: the `jq --version` check that runs before anything else is not
removed, and the 2/3/4 target is understood to include it.

**Rationale**: it is the reason the hook can report "jq is missing" as a named
failure rather than dying silently, and the seed's constraints require every
named failure to stay loud. Removing it would hit the number by deleting a
feature.

## Finding A — where the spawns actually are

Read out of the file rather than taken from the seed:

| Site | Line | Count |
|---|---|---|
| availability check | `:55` | 1, always |
| `agent_id` | `:89` | 1, always |
| `transcript_path` | `:93` | 1, always |
| `session_id` | `:94` | 1, always |
| `cwd` | `:104` | 1, always |
| `read_config` × 4 fields | `:134`–`:137` | 4 **per file that exists** |

Called at `:163` (`$HOME/.delivery-kit.json`) and `:164` (the repository file).
So 5 + 4 × *(files present)* = **5 / 9 / 13**, matching the seed.

After: 1 + 1 + 1 × *(files present)* = **2 / 3 / 4**.

## Finding A2 — the seed's 5/9/13 is a SLICE, not the whole run

Measured with a counting shim on 2026-09-01, running the hook once end to end
with a real transcript:

| Configuration files | Whole run | Of which, before the transcript is read |
|---|---|---|
| 0 | **8** | **5** |
| 1 | **12** | **9** |
| 2 | **16** | **13** |

The seed's figures are the right-hand column, and they are exactly right. The
extra three on every path are the transcript reading itself, logged verbatim:
two `-Rr fromjson?` passes — the byte-capped attempt and its `tail -n` fallback —
and one `-rs` median. **None of those three is touched by this change**, so both
columns fall by the same amount:

| Configuration files | Whole run, after | Slice, after |
|---|---|---|
| 0 | 5 | 2 |
| 1 | 6 | 3 |
| 2 | 7 | 4 |

**All of these are the NON-FIRING path**, which is the one that matters because
it is what runs after almost every tool call. When the guard actually fires it
spends one more — the emission that writes the blocking instruction — so the
zero-configuration run is 6 rather than 5, measured. The seed frames its numbers
the same way ("the full non-firing path"), and the extra call is not removable:
it *is* the output.

Record **both** columns. The slice is what the seed asked for; the whole-run
figure is what an operator actually pays per tool call, and quoting only the
flattering one would be the kind of half-truth this repository's constraints
exist to prevent.

## Finding A3 — a counting shim must count invocations, not lines

A first attempt logged each invocation's arguments and counted the file's lines.
It reported 16 and 24 instead of 8 and 16, because the two transcript-reading
programs are **multi-line jq programs** and a line-per-line log records one line
per program line.

The fix is one line per invocation regardless of the program's shape — the shim
appends a fixed token, not the arguments. Keep the argument log as a separate
diagnostic for decomposing the count; never use it as the count.

This matters beyond this run: a measurement that silently double-counts is worth
less than no measurement, and both numbers looked plausible.

## Finding B — the early return is what makes the count vary

`read_config` begins `[ -f "$1" ] || return 0`. That line is why an absent file
costs nothing, and why the count is 5/9/13 rather than a flat 13. It is listed
in the seed as a requirement to preserve; it also happens to be load-bearing for
the measurement itself.

## Finding C — the hook is bash, and already avoids bashisms

Shebang is `#!/usr/bin/env bash`, but a scan finds no `mapfile`, no `readarray`,
no `[[ ]]` and no `local`. The file is written in portable shell despite being
run by bash.

`$'\037'` is a bashism (`$'…'` is not POSIX). It is used because the
alternative is a literal control byte in the source, which is worse: invisible
in diffs and easy to destroy with a careless editor. Worth stating in the plan
so the choice is deliberate rather than accidental drift.

> **Amended 2026-09-01, during phase M.** This finding originally added that
> "`read -r` with a custom IFS is otherwise portable". Portable it may be, but
> it is not correct here: `read` stops at the first newline and truncates any
> value containing one. The split is parameter expansion, which is a second
> bashism and is the one the shipped code uses. See Decision 2's "Superseded in
> part" note.

## Finding D — the "do not edit the hook suite" rule is the real tripwire

The seed forbids editing `handoff/tests/context-guard.bats`, and says a test
needing a change proves the behaviour changed.

That rule is what would have caught the naive split — the suite covers the
main-session path, so a guard that started exiting early would go red, and the
only way to make it green again would be to edit the test. Credit where due: the
seed's constraint is better than its suggested spelling.

It follows that the suite must be run **before** the refactor as well as after,
which the acceptance criteria already require. A green afterwards only means
something against a green before.
