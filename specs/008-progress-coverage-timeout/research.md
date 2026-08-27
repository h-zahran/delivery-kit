# Research: progress.sh coverage and a timeout for every suite

**Date**: 2026-08-27 · **Feature**: `008-progress-coverage-timeout`

Everything below was measured on this machine before the plan was written. No
decision here rests on reasoning where a measurement was available. Where a
measurement contradicted an expectation, the expectation is recorded beside it,
because the next reader will have the same expectation.

---

## D1 — Does the limit reach a suite when it is set in the loaded fixture file?

**This is the assumption the whole first requirement rests on.** If a limit set
in a `load`ed file did not apply, the requirement would be impossible as written
and would need a different shape entirely. It was tested first, before anything
else was designed.

**Decision**: yes. Setting the limit in the shared fixture file applies it to a
suite that loads that file.

**Evidence** — a throwaway fixture setting the limit to 2, a throwaway suite
loading it, and a test sleeping 6:

```
1..2
ok 1 fast test passes
not ok 2 slow test should be stopped by the loaded timeout # timeout after 2s
# (in test file probe.bats, line 5)
#   `@test "slow test ..." { sleep 6; }' failed due to timeout
# Terminated                 sleep 6
```

**Two facts fall out of that output and both are used later**:

- The failure line carries `# timeout after <N>s`, and the test's own name is on
  that line. This is what satisfies "the output names the test that exceeded it".
- **CORRECTED 2026-08-27, after review.** An earlier draft of this entry said
  the stop needs an external `timeout` program and would silently do nothing
  without one. Both halves were wrong, and the error was caught by reading
  bats' own source and then measuring it three ways: a shim placed first on
  `PATH` was never called, and a stripped `PATH` produced a loud refusal.
  What bats actually needs is **`ps` or `pkill`** — it implements the limit
  itself with a backgrounded sleep and a signal — and with neither it prints
  `Cannot execute timeout because neither pkill nor ps are available` and
  **exits 1**. Loud, not silent. The quickstart checks for `ps`/`pkill`
  accordingly.

**Alternatives considered**: setting the limit separately in each of the six
suites. Rejected — six copies of one value is exactly the drift the requirement
exists to remove, and the shared file is loaded by all six already.

---

## D2 — Which assignment wins: the one before `load`, or the one inside it?

The seed leaves open whether to keep or remove the existing per-suite
assignment. It is written **before** that suite's `load` line. Expectation
before measuring: "the local one is more specific, so it probably wins."
**That expectation is wrong.**

**Decision**: the fixture file's value wins over any assignment written above
the `load` line. The existing per-suite assignment is therefore dead code the
moment the shared file sets the limit, and it must be removed (FR-003).

**Evidence** — two throwaway suites, fixture set to 2, test sleeps 4:

| Suite shape | Result | Meaning |
|---|---|---|
| assignment `=30` **above** `load` | `not ok … # timeout after 2s` | the fixture won |
| assignment `=30` **below** `load` | `ok` | the local one won |

**Consequence**: keeping both would leave a line that reads like the owner of
the value and is not one. A future maintainer editing it would see no change in
behaviour and no error. That is the "one obvious owner" the seed asks for, and
the measurement — not taste — is what selects removal.

**What must not be lost with it**: that assignment carries a comment explaining
*why* a limit exists there at all — a regression reintroducing an unbounded
directory walk should get a named timeout rather than the platform's job cap.
The line goes; the reason moves to the surviving assignment (FR-004).

---

## D3 — What value?

**Decision**: **60 seconds.**

**Measured, 2026-08-27, whole suite with per-test timing:**

| Measurement | Value |
|---|---|
| Slowest single test, full run | **7916 ms** |
| Full suite, this machine | 224.6 s across 123 tests |
| Full suite, slowest hosted runner | 155 s |
| Full suite, fastest hosted runner | 17 s |

**This machine is the slowest environment available** — slower than every hosted
runner, by a factor of 1.4 against the slowest and 13 against the fastest. A
value chosen against a local measurement is therefore conservative everywhere
the suite actually runs. That is the opposite of the usual assumption and is the
reason the local number is the one used.

**Slowest test in each suite, measured in isolation:**

| Suite | Slowest test |
|---|---|
| root layout suite | 1149 ms |
| root portability suite | 6330 ms |
| handoff guard suite | 7295 ms |
| pipeline pre-flight suite | 2919 ms |
| pipeline state suite | 4551 ms |
| pipeline prose suite | 1402 ms |

**Why not simply reuse the existing 10?** Because it was only ever applied to
the fastest suite of the six. Its own slowest test is 1149 ms, so 10 seconds
gave it 8.7× margin. Applied to all six it would sit 2.7 seconds above the
handoff guard suite's slowest test and under 2.1 seconds above the slowest test
overall — on the slowest machine measured, with no allowance for a loaded
runner or a cold cache. That is a flake generator, and a flaky timeout teaches
people to ignore timeouts.

**Why 60 and not 30 or 120?**

- 60 s is **7.58×** the slowest test observed. A test would have to become more
  than seven times slower before it flaked.
- It is still **360× faster** than the platform job cap it replaces — the hazard
  the requirement exists to close is fully closed.
- 30 s gives only 3.8× margin. A hosted runner under load routinely varies by
  more than 2×, so 30 leaves too little.
- 120 s buys nothing the hazard cares about and doubles the time a real hang
  wastes.

**Alternatives considered**: deriving the value at load time from a measured
baseline. Rejected — it makes the limit depend on the machine, so CI and local
would enforce different contracts, and a slow machine would quietly grant itself
a longer limit, which is the failure mode inverted.


### ADDENDUM, 2026-08-27, after review — the readings above do not reproduce

The table above records one run. Review re-measured and got materially different
numbers, so the single readings are amended here rather than rewritten above: a
dated record stays as it was written, and the correction sits beside it.

| Reading | Slowest single test | Full suite |
|---|---|---|
| Original, above | 7916 ms | 224.6 s / 123 tests |
| Review run 1 | 14,347 ms | 523.3 s / 134 tests |
| Review run 2 | 14,862 ms | 627.1 s / 134 tests |
| Re-measured later | 8001 ms | — |

**The spread is genuine, not a mistake in either reading.** The control settles
it: the fastest suite's slowest test measured 1149, 1118, 1804 and 623 ms across
those runs — a threefold swing on work that does almost nothing. The variance
lives in process spawning, which is expensive on this platform and sensitive to
load, and the handoff guard suite is the one that spawns most.

**What this changes.** The derived `7.58×` margin is wrong; against the worst
reading it is about `4×`. **What it does not change is the decision** — it
strengthens it. At the slower readings the ten-second value being removed would
not merely have run close to honest tests, it would have KILLED them: three in
review run 1, six in run 2. The comment in the shared fixture now records the
range and that consequence, rather than one number.

**Lesson recorded, because it is the second time in this run:** a single timing
reading on this machine is not a measurement, it is a sample. Anything derived
from one reading and written into a shipped comment will be falsified by the
next run.

---

## D4 — Are all nine refusal paths deterministically reachable?

**Decision**: yes, all nine, with no timing dependency and no sleeping. Each was
driven and its message captured before any test was designed around it.

| # | Refusal | How it is reached | Message names |
|---|---|---|---|
| 1 | complete an unknown phase | `phase-done` with a phase not in the list | the phase, quoted |
| 2 | plan artefact missing | `from-validate` for the phase whose rule needs the plan | the artefact, quoted |
| 3 | tasks artefact missing | `from-validate` for any phase in the tasks group | the artefact, quoted |
| 4 | no rule admits it | `from-validate` for a late phase that is neither current nor completed | the phase and all three reasons |
| 5 | no session identifier | `lock-take` with the argument omitted | what was missing |
| 6 | lost creation race | **make the lock path a directory** | the race |
| 7 | bare usage | fewer than two arguments | every legal subcommand |
| 8 | completed list is not a list | craft that key as a string | the file and the key |
| 9 | unknown recorded phase | craft that key as an unknown value | the file and the value |

**Number 6 is the only one that needed thought.** The race it names cannot be
run twice quickly enough to lose reliably. The path is reachable
deterministically instead: the guard above it tests for a regular *file*, so a
**directory** at that path passes the guard untouched and then makes the
protected write fail. Verified — exit 1, and the message printed. This is not a
simulation of the failure; it is the same branch, entered by a different door.

**Alternatives considered for number 6**: spawning two takers concurrently and
hoping one loses. Rejected — non-deterministic by construction, and a test that
passes only sometimes is worse than no test.

---

## D5 — What exactly does the state-reading contract promise, and is it true?

**Decision**: both halves are true today, and both are testable without waiting
for a particular machine.

The read path validates, then copies the state file to the data stream. So its
output is the file's bytes, and a test can create any condition it wants by
writing the file.

**Measured:**

| Claim | Result |
|---|---|
| Output is accepted whole by a strict parser | yes |
| A broken state file leaves the data stream empty | yes — **0 bytes**, the fault goes to the diagnostic stream |
| With the two-character line ending, a strict parser still accepts it | yes |
| With it, capturing through command substitution is clean | yes — value captured with no stray character |
| With it, the forbidden line-reading idiom retains the stray character | **yes — reproduced, the character is visibly retained** |

**This is why the test must construct the condition.** The condition does not
arise on every machine. A test that merely reads whatever the file happens to
contain would pass everywhere while proving nothing on most machines. Writing
the line ending deliberately is what makes the test mean something in CI.

**Alternatives considered**: asserting only that a strict parser accepts the
output. Rejected — that half would pass even if the documented trap stopped
being a trap, and the shipped document's warning would rot into a lie with no
test to notice.

---

## D6 — How does the private-vocabulary test become real?

**Decision**: taken at clarify by the owner, recorded in the spec — the folding
becomes a named function in the same suite file, called at load time with the
repository's own path and by the test with a fixture path.

**Research contribution here is only the shape constraint**: the function must
return the shipped list unchanged when the private list contributes nothing.
The current inline code achieves that by only appending when the folded result
is non-empty. A naive function that always joins would append a trailing
separator and produce an empty alternative — which the existing comment says,
correctly, would make the scan match at every position. FR-018 pins that
behaviour so the refactor cannot lose it.

**Alternatives considered**: recorded in the spec's Clarifications section, with
the owner's reasons.

---

## D7 — What is NOT researched here, and why

- **No investigation of the platform job cap.** It is cited by the existing
  comment as the hazard; nothing in this feature depends on its exact value.
- **No performance work.** The suite is slow locally and that is not this
  feature's problem to solve. It is recorded because it selects the limit.
- **No change to what the scans forbid.** This feature makes an existing scan's
  test honest; it does not touch the vocabulary, the surfaces, or the path
  shapes. The previous phase's scan covers this feature's own documents, so no
  machine-specific absolute path may appear in any file written here.
