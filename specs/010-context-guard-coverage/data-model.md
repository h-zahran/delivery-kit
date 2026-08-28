# Data model — payloads, fixtures and the observable surface

**Feature**: `010-context-guard-coverage` · **Phase**: D

This feature adds no runtime data structure. Its "data" is of three kinds: the
**payload shapes** that steer the guard down each untested path, the **rig** that
makes the outcome predictable, and the **observables** the tests read back.

Every shape below was built and driven before this document was written. The
result columns are what was observed.

---

## Part 1 — The observable surface

The guard has exactly three observables, and **exit status is not one of them
in any useful sense**: it exits 0 on nearly every path, including every path
under test here.

| Observable | What it carries | Read by |
|---|---|---|
| the data stream | one JSON decision object when the guard warns; **nothing at all** when it does not | every test |
| the reason text inside it | which threshold fired, worded differently for each | FR-007, FR-008 |
| the flag files in the flag directory | one per session, named for the session identifier | FR-004, FR-006 |

### The two reason wordings are the discriminator

The two firing paths word themselves differently. One says the context is at a
**percentage of the window**; the other says it is at a **token count past a
token threshold**. That difference is what lets a test say *which* threshold
fired rather than merely that something did.

### The flag filename carries the session identifier

`ctx-warned-<identifier>`. When the payload supplies no identifier the guard
substitutes the literal placeholder, and the file is named
**`ctx-warned-unknown`**. That filename is the only externally visible proof the
substitution happened, and it is what FR-006 asserts.

---

## Part 2 — The rig

Shared by every test, and chosen so each outcome is decided by the one setting
under test:

| Element | Value | Why |
|---|---|---|
| transcript | **20 readings of 90,000 tokens** | the median is 90,000 with no ambiguity; 20 clears the fifteen-reading floor so no fallback path is involved |
| window | **100,000** | puts the context at **90%** |
| flag directory | a per-test temporary path | the guard reads it from the environment; a shared one would leak state between tests |

90% is comfortably above every threshold meant to fire and comfortably below
every threshold meant not to. Nothing in these tests turns on a boundary.

---

## Part 3 — The seven payload shapes

### FR-001 — the working-directory fallback

| | Payload | Run from | Observed |
|---|---|---|---|
| positive | transcript + identifier, **no working directory** | a directory holding configuration | **warned** |
| control | the same payload | a directory holding **no** configuration | **silent** |

**The transcript must be valid.** Omitting the working directory *and* the
transcript kills the payload at the earlier gate, where the guard exits silently
— and a test asserting only silence would pass for that wrong reason. This is
why no existing test reaches this path: the shared payload builder always
supplies a working directory, and the payloads that omit one also omit a usable
transcript.

### FR-002 — discovery at the repository root

| | Working directory | Repository | Observed |
|---|---|---|---|
| positive | `<repo>/sub/deeper` | initialised, configuration at its root | **warned** |
| control | `<dir>/sub` | **none** | **silent** |

**Two levels deep, not one.** One level is explainable by a plain
parent-directory look; two is not. The control removes the repository entirely,
which is the only thing that can answer the question the guard asks.

### FR-004 — the seven-day sweep

| Flag file | Age | After a run that **warned** |
|---|---|---|
| an aged flag | 2020-01-01 | **removed** |
| an eight-day flag | 8 days | **removed** |
| a seven-day flag | 7 days | **kept** |
| a `dk-window-warned-*` flag | 2020-01-01 | **removed** |
| the global `dk-jq-hint` | 2020-01-01 | **removed** |
| an aged file none of the patterns name | 2020-01-01 | **kept** |
| an aged DIRECTORY a pattern does name | 2020-01-01 | **kept** |
| a fresh flag | seconds | **kept** |

**The run must warn**, because the sweep sits past the firing decision. And both
files are required: removal alone would also be satisfied by anything that
cleared the directory, so the fresh file surviving is what shows the *age filter*
acted.

Ageing is done by setting the file's timestamp back, not by waiting.

### FR-005 — a transcript that yields no readings

A file that **exists** and parses to nothing usable — a plain-text line, and a
JSON object carrying no usage. Observed: **exit 0, no output.**

The file must exist. A missing one dies at the gate, which is a different path
already covered.

### FR-006 — a payload with no session identifier

Payload carries a transcript and a working directory, **no identifier**.
Observed: **warned**, and the flag file was named **`ctx-warned-unknown`**.

Assert the filename. Asserting only that it warned would pass even if the
substitution were removed and the guard crashed into a differently-named file.

### FR-007 — the proportional threshold

| Setting | Observed |
|---|---|
| 99% | **silent** |
| 1% | **warned**, reason worded as a percentage of the window |

### FR-008 — the absolute threshold

| Setting | Proportional pinned at | Observed |
|---|---|---|
| 999,999 tokens | 99% | **silent** |
| 50,000 tokens | 99% | **warned**, reason worded as a token count past a token threshold |

**Pinning the proportional threshold at 99% is what makes this test about the
absolute one.** At its default it fires first at 90%, and the test would go
green with the absolute setting doing nothing whatever.

---

## Part 4 — The conversion targets

| Target | Sites | Converted? |
|---|---|---|
| the repository configuration file, guard key only | 22 | yes |
| the **user** configuration file | **4** | yes — only possible because the helper takes a path |
| the repository file, **also carrying a `profile` key** | 1 | **no** |
| a patch file | 1 | **no** |
| an existing-configuration file | 1 | **no** |
| **total** | **29** | **26 converted, 3 stay** |

**Nineteen distinct bodies** across the convertible sites. Several are deliberately
invalid — a leading-zero number, a zero window, an out-of-range threshold —
because they exercise the validator. The helper writes the body **verbatim**; a
helper that rebuilt it would repair exactly the inputs those tests exist to
reject.

**One site builds its body by substitution.** Because the body is a string
parameter, the caller interpolates before calling and no exception is needed.

### Why the three exceptions stay

Each carries a top-level key the guard does not own, or writes a file that is not
a configuration file. The existing-configuration site writes **three top-level
keys**, two of them foreign — an unrelated tool's key and a deliberately unknown
future key — and those keys *are* the assertion that a merge preserves what it
does not own. A third site writes the repository configuration file but its
object also carries a `profile` key.

**Two were found by reading the targets; the third only by running the
conversion and asserting its counts.** A conversion built on the first reading
would have flattened a foreign key out of a fixture.

### The byte-cap idiom

**Four** call sites. Stated as four rather than implied to be many. Extracted for
naming, and because the trailing-whitespace strip in it is load-bearing on this
platform and easy to drop when copied by hand.

---

## Part 5 — What is *not* added

**No tracked fixture files.** Every one of the seven tests builds what it needs
inside its own temporary directory. That matters here more than it did in Phase
9: `handoff/tests/` is a registered **strict**-vocabulary surface, and a term
pasted into a tracked fixture there reaches every install. Nothing new enters
that surface except the test code itself, which the same scan covers.
