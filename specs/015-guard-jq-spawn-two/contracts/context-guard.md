# Contract: `handoff/hooks/context-guard.sh`

**Feature**: `015-guard-jq-spawn-two`
**Date**: 2026-09-02

The hook is invoked by Claude Code after every tool call. It has no callers
inside this repository, so this is the whole of its public surface. Everything
listed as **unchanged** is what the side-by-side comparison exists to prove;
everything listed as **changed** is what this feature is.

---

## Invocation

| | |
|---|---|
| Called as | `bash handoff/hooks/context-guard.sh` |
| Arguments | none, ever |
| Standard input | one JSON object, written by the caller |
| Timeout | 30 seconds, set in the hook manifest, sized for the uncapped re-read |

---

## Standard input — unchanged

A single JSON object. Every field is optional; see
[data-model.md](../data-model.md) for the four fields read and their defaults.

**New guarantee, and the only change to this side of the contract**: the hook
consumes its whole standard input on **every** path it can take. It relied on
that before by accident — the copy step read everything — and now does it on
purpose, because a path that stops reading costs the caller a broken-pipe
signal. Measured: a reader that exits without reading leaves the writer at exit
141, one that consumes leaves it at 0.

**Every path means two, and the second was found by review after the first
shipped.** The obvious one is the parser being unavailable, where the hook
never runs it at all. The other is the parser running and FAILING: jq reads to
end of input only while the input keeps parsing, so a payload malformed at its
first token makes it abort having read one buffer, and the caller writing the
rest is killed. Measured on a 300KB payload beginning `{not json`: writer exit
141 with the guard as first shipped, 0 with the pre-change hook, 0 now.

Neither rig could see it. The comparison harness compares the hook's own stdout
and exit status, never the writer's, and its malformed-payload shape is nine
bytes — small enough to sit in the pipe buffer, where a reader that never reads
costs nothing. The check that covers it is section 4 of the quickstart.

---

## Standard output — unchanged

Either nothing, or exactly one line of JSON.

| Situation | Output |
|---|---|
| Below the threshold, or any early exit | nothing |
| At or above the threshold, first time in this 5% bucket | one JSON object carrying the blocking instruction |
| At or above the threshold, already warned in this bucket | nothing |
| Parser unavailable, first time on this machine | one JSON object carrying the install hint |
| Parser unavailable, hint already shown | nothing |

**Byte-identical before and after this change, for every input that carries no
junk reading.** That is the contract this feature is measured against, not a
summary of it.

This paragraph read "for every input" until three inputs were measured that
prove otherwise, and this file was the last record to be corrected — it was not
touched by the sweep that fixed the others, which is how a contract ends up the
most confident and least accurate document in a change. The three are named at
spec FR-001. All arise from one root: jq's `+` concatenates strings, so a usage
record whose three token fields are all strings yields a string reading, and the
old code either collapsed on it, re-parsed it into an inflated median, or
counted it toward the fifteen-reading floor. Each divergence is a correction,
and the comparison harness ASSERTS each rather than excusing it.

---

## Exit status — unchanged

Always `0`. The hook never blocks a tool call by its status; when it wants to
say something it says it on standard output. A non-zero status from this hook
would be a defect.

---

## Standard error — unchanged in principle

Not part of the contract and not compared by the harness. Both the old and the
new transcript reads discard the parser's diagnostics.

One new possibility is closed rather than accepted: the new count could in
principle be non-numeric, which would make the shell comparison complain. It is
forced to zero first — which also makes the fallback fire, the safe direction.

---

## Side effects — unchanged

| Effect | Detail |
|---|---|
| Reads | the transcript named in the payload; up to two configuration files |
| Writes | one flag file per session under the temporary directory, holding the last bucket warned |
| Writes | one flag file per machine under the temporary directory, marking that the install hint has been shown |
| Never writes | anything under the repository, the home directory, or the transcript |

The flag file's location — the temporary directory, **not** the home directory —
is why any comparison harness must isolate the home directory and all three
temporary-directory settings separately for each side of each shape.

---

## Process budget — CHANGED

This is the only observable the feature moves on purpose. Counted per non-firing
run, for zero, one and two configuration files present.

| | before | after |
|---|---|---|
| parser processes, ordinary transcript | 4 / 5 / 6 | 3 / 4 / 5 |
| parser processes, starved transcript | 5 / 6 / 7 | 4 / 5 / 6 |
| text-count processes | 1 | 0 |
| stdin-copy processes | 1 | 0 |

A firing run spends one more parser process than the figures above, on the
emission itself. That is true before and after.

**One honest note about the copy count.** The figure above is for the copy of
standard input, which is the process this feature removes. The hook starts a
second process of the same kind further down, to read the warning flag; that one
is untouched and out of scope, so a total count of these processes falls from
two to one rather than to zero. Replacing the second one needs no process at
all, but it is neither of this feature's two requirements and is not done here.

---

## Invariants this change must not break

1. The four payload fields are extracted in one parser call, joined by a
   separator defined once in the file, split by parameter expansion.
2. The separator is not a tab.
3. Every extracted field is coerced to a string before joining.
4. The transcript program is one string, used by both the capped and the
   uncapped call, so the two cannot drift.
5. A single unreadable transcript line never empties the whole read.
6. A count below fifteen always takes the uncapped re-read.
7. The median is of the last fifteen readings, sorted, middle index rounded
   down, zero when empty.
8. The floor of fifteen equals the median window of fifteen.
9. Every dated incident and named failure mode in the file's comments survives.
