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
consumes its whole standard input on **every** path it can take, including the
path where the parser is unavailable and the hook exits early. It relied on this
before by accident — the copy step read everything. It now does so on purpose,
because a path that stops reading costs the caller a broken-pipe signal.
Measured: a reader that exits without reading leaves the writer at exit 141.

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

**Byte-identical before and after this change, for every input.** That is the
contract this feature is measured against, not a summary of it.

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
