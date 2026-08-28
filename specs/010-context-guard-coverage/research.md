# Research — context-guard.sh coverage and a config fixture helper

**Feature**: `010-context-guard-coverage` · **Phase**: D · **Date**: 2026-08-28

Everything below was **driven and observed** against the real hook. It exists so
no later phase re-measures any of it. Every behaviour was measured **with a
control that fires the other way**, because a guard that warns is easy to
produce by accident and a silent one is indistinguishable from not running.

Per FR-018, nothing here is anchored to a line number.

---

## 1. The hook's decision chain, as measured

The tests below only make sense against the real order of events:

1. If the data tool is missing, print a hint once and exit.
2. If the payload carries an agent identifier, exit — this is a subagent.
3. Read the transcript path and the session identifier. **A missing session
   identifier becomes the literal placeholder `unknown`.**
4. **The gate:** the transcript must be non-empty *and* an existing file, or
   exit. This is the gate a careless payload dies at.
5. Read the working directory; **if absent, fall back to the process's own.**
6. Look for configuration beside it; **if not there, ask git for the repository
   root and look there.**
7. Apply configuration, then the environment, in that order.
8. Take readings; if the median is zero or empty, exit.
9. Compute a percentage and a five-wide bucket.
10. Fire if the absolute threshold is met **or** the proportional one is.
11. Fire only if this bucket is higher than the last recorded one.
12. Write the flag file — **and only then sweep flags older than seven days.**

**Step 12 is the finding that shapes one whole test.** The sweep is not
housekeeping that runs on every invocation: it runs **after a warning has
fired**. A test that ages a flag file and then runs the guard *without* driving
it past a threshold will observe nothing and conclude the sweep is broken —
or, worse, assert "nothing happened" and pass for the wrong reason.

## 2. The measurement rig

A transcript of **20 readings of 90,000 tokens** (so the median is 90,000), a
window of 100,000, and the flag directory pointed at a scratch path. That gives
90% — comfortably above any threshold under test and comfortably below none, so
each test's outcome is decided by the setting it is testing and nothing else.

The reading format is the one the shared payload helpers already produce.

---

## 3. Every behaviour, measured

### FR-001 — the working-directory fallback

| Run | Working directory in payload | Where the guard was run from | Result |
|---|---|---|---|
| positive | **absent** | a directory holding configuration | **warned** |
| control | **absent** | a directory holding no configuration | **silent** |

The pair is the whole proof. The positive alone would be satisfied by the guard
finding configuration anywhere; the control shows the configuration it found was
the one beside the process's own directory.

**Reaching the step is proven by the warning itself.** A payload that died at
the gate exits silently, so a warning cannot be produced without having passed
the gate, read the working directory, resolved the fallback and read the file.
That is what discharges FR-003 for this test — no separate assertion is needed,
and this is worth stating because a reader may reasonably expect one.

**Why no existing test reaches it:** the shared payload builder always supplies
a working directory. Payloads that omit one in the suite today also omit a
usable transcript, so they die at the gate two steps earlier.

### FR-002 — discovery at the repository root

| Run | Working directory | Repository | Result |
|---|---|---|---|
| positive | `<repo>/sub/deeper` | initialised, configuration at its root | **warned** |
| control | `<dir>/sub` | **not a repository** | **silent** |

Two levels deep on purpose: one level could be explained by a parent-directory
search rather than by asking git. The control removes the repository, which is
the only thing that can answer.

### FR-004 — the seven-day sweep

| Flag file | Age | After a run that **warned** |
|---|---|---|
| an old flag | 30 days | **removed** |
| a fresh flag | seconds | **kept** |

**The shipped fixture is wider than this measurement.** The two rows above
record what was driven at Phase D and are left as they were driven. Review
showed the pair they describe cannot tell `-mtime +7` from `+3` through `+6`,
so the test now straddles the boundary with files just inside and just outside
it, stamped from EPOCH seconds rather than wall clock — a wall-clock stamp is
an hour short across a daylight-saving shift, and the outer file then survives.
It also covers all three swept name patterns on both sides, the file-type
filter and the depth limit.

Both halves are required. Removal alone would also be satisfied by something
deleting the whole directory; the fresh file surviving is what shows the age
filter is the thing that acted.

**The run must warn.** Measured: the sweep sits after the firing decision.

### FR-005 — a transcript that yields no readings

A file that exists and parses to nothing usable — a plain-text line and a JSON
object with no usage — produced **exit 0 and no output**.

This is a silent success, so **exit status proves nothing on its own**: the
guard exits 0 on almost every path. The assertion has to be that the output is
empty *and* that the run got far enough to have produced output had there been
readings, which the rig's other cases establish by contrast.

### FR-006 — a payload with no session identifier

The guard warned normally, and — the observable that makes this testable — it
wrote its flag file as **`ctx-warned-unknown`**.

That filename is the placeholder made visible. Without it this test could only
assert "did not crash", which is nearly unfalsifiable. **Assert the flag file's
name.**

### FR-007 — the proportional threshold override

| Setting | Result |
|---|---|
| threshold 99% (context is at 90%) | **silent** |
| threshold 1% | **warned** |

### FR-008 — the absolute threshold override

| Setting | Result |
|---|---|
| 999,999 tokens, proportional pinned at 99% | **silent** |
| 50,000 tokens, proportional pinned at 99% | **warned** |

**Pinning the proportional threshold at 99% is what makes this test about the
absolute one.** Left at its default the proportional threshold would fire first
at 90%, and the test would pass with the absolute setting doing nothing at all.

**And the two paths are distinguishable in the message.** The proportional path
says the context is at a percentage *of the window*; the absolute path says it
is at a token count *past a token threshold*. Asserting on that difference
proves which threshold fired, not merely that something did.

---

## 4. Why the existing four-variable test is not coverage

The suite has a test that extracts a snippet from a documentation file and
counts the environment variable names it mentions. It proves the documentation
lists four names. It runs the guard not at all.

It is a real test of a real thing and must not be removed. It simply is not
evidence about either override, and FR-009 says so.

---

## 5. The conversion targets, measured

| Target | Sites | Convertible? |
|---|---|---|
| the repository configuration file, guard key only | 22 | yes |
| the user configuration file | 4 | yes |
| the repository file **also carrying a `profile` key** | 1 | **no** |
| a patch file — the seed names this one | 1 | **no** |
| an existing-configuration file — **the seed does not** | 1 | **no** |
| **total** | **29** | **26 convert** |

The byte-cap idiom has **four** call sites.

### The three exceptions stay as they are

Read before deciding. The existing-configuration site writes **three top-level
keys**, two of which the guard does not own — an unrelated tool's key and a
deliberately unknown future key — and those keys *are* the assertion that a
merge preserves what it does not own. A helper able to express that is a
JSON-writing helper, not a configuration helper.

So: the helper takes a path, **twenty-six convert, and three keep their literal
writes**. The path parameter earns its place by letting them be *left alone*
rather than special-cased.

**The third was found only by running the conversion.** Reading the targets
found two; a site writing the repository configuration file whose object also
carries a `profile` key belonging to another tool looks ordinary by target and
is not convertible by shape. The conversion script asserts its counts and
refuses to write unless all three match, which is what surfaced it.

---

## 6. The seed's line references, re-derived

Recorded in full in the specification. Summary: **five accurate, three stale**,
and the worst stale one drifted because **Phase 9 — the phase immediately before
this one — added 46 lines to the file the seed cites**. The rule that catches
this is the campaign's own, and it caught it.

---

## 7. Decisions this research settles

| Decision | Chosen | Rejected, and why |
|---|---|---|
| How to reach the fallback | Omit the working directory but keep a **valid transcript** | A payload missing both dies at the gate and passes for the wrong reason |
| How to prove the fallback was used | A control run from a directory with no configuration | The positive alone is satisfied by finding configuration anywhere |
| How deep the subdirectory | **Two** levels | One level is explainable by a parent search rather than by asking git |
| How to test the sweep | Drive the guard to **warn**, then check the files | The sweep runs after the firing decision; a non-warning run sweeps nothing |
| What the sweep asserts | Old file gone **and fresh file kept** | Removal alone is satisfied by anything that clears the directory |
| What the missing-identifier test asserts | The flag file is named `ctx-warned-unknown` | "Did not crash" is nearly unfalsifiable |
| How to isolate the absolute threshold | Pin the proportional one at 99% | At its default it fires first and the absolute setting does nothing |
| What the override tests assert | The **wording difference** between the two messages | "Something warned" does not say which threshold fired |
| The **three** exception sites | Left unconverted | One writes keys the guard does not own, and those keys are the assertion |

## 8. Open items

**None.** All seven behaviours were driven, each with a control.
