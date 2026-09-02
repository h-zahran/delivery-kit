# Research: the guard stops counting jq, part two

**Date**: 2026-09-02
**Feature**: `015-guard-jq-spawn-two`
**Toolchain measured on**: jq-1.8.1, GNU bash 5.3.9 (x86_64-pc-cygwin), Windows 11

Every finding below was produced by running a command, not by reading a manual
page. Where a result contradicted the design that was about to be written, the
design changed. Two did.

---

## R1 — an array comprehension turns a per-line error into total silence

**Decision**: the new transcript program wraps its per-line pipeline in `( … )?`.
The `?` is load-bearing and must never be removed as noise.

**Rationale**: the current code streams — one jq invocation emits one number per
line. jq treats a runtime error on one input as an error on that input alone: it
reports it and carries on with the next. Collect the same pipeline into
`[ inputs | … ]` and the error escapes the array construction and kills the whole
program, so jq emits **nothing at all**. Every reading in the transcript is lost,
`ctx` is empty, and the guard exits silently — which the hook's own comments name
as the one direction it must never fail in.

**Measured** on a three-line transcript whose middle line carries a string where a
token count belongs:

| Form | Output | Exit |
|---|---|---|
| `jq -Rr '<pipeline>'` — today's streaming form | `100`, `300` | 0 |
| `jq -Rrn '[inputs \| (<pipeline>)]'` — no `?` | *(nothing)* | 5 |
| `jq -Rrn '[inputs \| (<pipeline>)?]'` — with `?` | `[100, 300]` | 0 |

**Alternatives considered**: `try … catch empty` — identical behaviour, more
words on a surface where every word is held to a fixed vocabulary. Rejected for
length, not for correctness. Leaving the `?` off and accepting the risk —
rejected: it converts a one-line fault into a dead guard.

---

## R2 — a reader that does not read costs the writer a signal

**Decision**: the parser-unavailable branch consumes stdin before it exits.

**Rationale**: this was the hazard the seed named and asked to have proven before
landing. It is real, it is reproducible, and it is not a theoretical concern
about pipe buffers — it fires on any payload larger than one.

**Measured**, writing a ~200 KB payload into a pipe and reading the writer's exit
status:

| Reader | Writer's exit status |
|---|---|
| exits immediately, reads nothing | **141** — killed by a broken pipe |
| consumes stdin, then exits | **0** |
| `jq` reading a single JSON object | **0** — jq reads to end of input |

Two things follow. First, jq drains stdin by itself, so on the ordinary path
nothing extra is needed and the two processes F7 removes are pure waste. Second,
the parser-unavailable path genuinely needs its own consume step: without one the
caller is signalled, and this hook's failures are supposed to be quiet, not loud.
The owner chose this design at the clarify gate; the measurement says it was the
right call rather than the cautious one.

**Alternatives considered**: relying on the payload staying under the operating
system's pipe buffer. Rejected — it is true today and is a property of the
caller, not of this hook, and the failure it buys is a guard that is off.

---

## R3 — the old reading count and a plain length disagree, and the case is reachable

**Decision**: the new count reproduces the old count exactly, with
`map(select(tostring | test("^[0-9]"))) | length`.

**Rationale**: the count that decides the fallback is currently a text search for
entries beginning with a digit. A negative value does not begin with a digit, so
it is **excluded from the count and included in the median**. A plain `length`
counts it. That is a change to the fallback decision, which the seed forbids.

**Measured** on the readings `100`, `-5`, `300`:

| Form | Result |
|---|---|
| today's text count | **2** |
| plain `length` | **3** — differs |
| `map(select(tostring \| test("^[0-9]"))) \| length` | **2** — matches |
| today's median | **100** — the negative *is* in the sorted window |

**Alternatives considered**: dropping the quirk on the grounds that a token count
cannot be negative. Rejected by the owner at the clarify gate. The A/B control
below shows the divergence is not hypothetical: it is the one shape a deliberately
naive count gets wrong, and it gets it wrong silently.

---

## R4 — the round trip through text changes nothing

**Decision**: computing the median in the same pass, instead of printing the
readings and parsing them back, is safe.

**Rationale**: today the readings are printed as text by one jq and re-parsed by
another. If that round trip normalised values, removing it would change the
median. It does not.

**Measured**: `1.5`, `9007199254740993` and `0` each survive the print-and-reparse
unchanged. An empty reading set yields a median of `0` and exit status 0 on both
the old path and the new one.

---

## R5 — `-R` is raw input, not raw output

**Decision**: the new calls are `jq -Rrn`. All three letters are required.

**Rationale**: this is recorded because the first draft of the program omitted the
`r` and the A/B harness caught it immediately. `-R` makes each input line a
string; it says nothing about output. Without `-r` the joined result comes back as
a JSON string in which the separator is written out as a six-character escape sequence rather than as the byte itself, the shell split finds no
separator byte, the whole string lands in the count, and the count is never a
number. The failure is loud in a harness and would have been silent in the hook —
`case` would force the count to zero, the fallback would fire on every run, and
the guard would still answer correctly while doing twice the work it does today.

---

## R6 — the whole readings block, old against new, across thirteen shapes

**Decision**: the design below is adopted.

**Measured**: the old block and the new block were run side by side over thirteen
transcript shapes, comparing both the fallback count and the resulting median.

| Shape | old count/median | new count/median | |
|---|---|---|---|
| empty file | 0 / 0 | 0 / 0 | same |
| one reading | 1 / 100 | 1 / 100 | same |
| fourteen readings | 14 / 80 | 14 / 80 | same |
| fifteen readings | 15 / 80 | 15 / 80 | same |
| sixteen readings | 16 / 90 | 16 / 90 | same |
| twenty readings | 20 / 130 | 20 / 130 | same |
| all three token fields present | 40 / 169 | 40 / 169 | same |
| unparseable line among good ones | 2 / 300 | 2 / 300 | same |
| string token count among good ones | 2 / 300 | 2 / 300 | same |
| string cache field among good ones | 1 / 300 | 1 / 300 | same |
| sidechain entry present | 1 / 100 | 1 / 100 | same |
| negative reading present | 2 / 100 | 2 / 100 | same |
| no usage field at all | 0 / 0 | 0 / 0 | same |

**Positive control**: the same harness, with the count replaced by a plain
`length`, reports **one** differing shape — the negative one, `2/100` against
`3/100`. The harness is therefore capable of printing something other than
"all same", which a run of zeroes on its own does not establish.

---

## R7 — the count can now fail in a way the old one could not

**Decision**: a count that is not a run of digits is forced to zero before the
comparison, so an unreadable answer means *starved*, never *satisfied*.

**Rationale**: the old count came from a text search, which always produced a
number. The new count is one field of a joined string, and an empty or malformed
answer would make the shell comparison error out and evaluate false — which skips
the uncapped re-read. Skipping it is the exact behaviour the 2026-08-07 incident
was fixed by adding. The direction of the default is the whole point: a broken
count must fall back, not press on.

The case is not reachable through the differential harness — the guard already
refuses a transcript that is not a regular file, and `jq -n` emits its result even
on empty input — so this is a default chosen by argument rather than by
measurement, and it is recorded as such rather than dressed up as a finding.

---

## R8 — no version floor is at risk

`inputs`, `try`/`?`, `test` and `tostring` are all present in jq 1.5 and later.
The repository pins no jq version anywhere; its continuous integration installs
jq fresh on three operating systems and only checks that `jq --version` answers.
Nothing in this change moves that floor.

---

## Corrections, added 2026-09-02 after review

This document records what was measured BEFORE implementation, and the dated
findings above are left exactly as they were taken — a measurement is not made
wrong by a later one. Two of them were superseded, and a reader who stops at R8
will draw the wrong conclusion, so the corrections are recorded here rather than
written over them.

- **R3 and R8 both name `test("^[0-9]")`, which the shipped hook no longer uses.**
  R8 concluded "no version floor is at risk" and listed `test` among the builtins
  available since jq 1.5. That reasoning was about a VERSION, and review pointed
  out the real exposure is a FEATURE: `test` needs a jq built with its regular
  expression library, and the availability probe runs `jq --version`, which cannot
  detect a missing feature. A compile error there yields an empty summary, a count
  of zero, a fallback, and a silent guard. The rule shipped is
  `tostring | startswith("-") | not`, which needs nothing. R3's conclusion — that
  the count must reproduce the old digit-prefix rule — is unchanged and still
  correct; only its spelling moved.
- **R6's thirteen-shape table was the block-level comparison, not the shipped
  harness.** The harness has since grown and diverged deliberately on three
  shapes. Its current state is the thing to read; this table is the state of the
  argument on the day it was made.

## Adopted design

One string, defined once, used by both calls so they cannot drift:

```
[ inputs
  | ( fromjson?
      | select(.isSidechain != true)
      | select(.message.usage.input_tokens != null)
      | .message.usage
      | (.input_tokens + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))
    )? ]
| [ (map(select(tostring | test("^[0-9]"))) | length)
  , (.[-15:] | sort | .[(length/2 | floor)] // 0)
  ]
| map(tostring) | join($US)
```

Called as `jq -Rrn --arg US "$US" "$READINGS_JQ"`, split with parameter
expansion on the separator that is already defined once in this file, count
forced to zero when it is not a run of digits, fallback unchanged.

Process ledger per non-firing run, to be confirmed by measurement at
implementation time rather than assumed here:

| | today | after |
|---|---|---|
| parser processes, ordinary transcript | 4 / 5 / 6 | 3 / 4 / 5 |
| parser processes, starved transcript | 5 / 6 / 7 | 4 / 5 / 6 |
| text-count processes | 1 | 0 |
| stdin-copy processes | 1 | 0 (1 only on the parser-unavailable path) |

The three columns are for zero, one and two configuration files present.
