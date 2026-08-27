# Data Model: progress.sh coverage and a timeout for every suite

**Date**: 2026-08-27 · **Feature**: `008-progress-coverage-timeout`

This feature stores nothing and defines no new record. What follows is the model
of the things it acts on: what each is, what it is allowed to be, and the rule
that must hold after the change. "Validation rule" here means a property a test
asserts, not a runtime check.

---

## E1 — The suite set

**What it is**: six bats suites. Two live at the repository root; four live
under the two plugins.

**Attributes**

| Suite | Where | How it loads the fixture |
|---|---|---|
| layout | root | by bare name |
| portability | root | by bare name |
| context guard | handoff plugin | by relative path |
| pre-flight | pipeline plugin | by relative path |
| state | pipeline plugin | by relative path |
| prose | pipeline plugin | by relative path |

**Relationships**: every one of the six loads the single shared fixture file.
That is the whole reason the fixture file is the right home for a setting that
must reach all six.

**Validation rules**

- **R1.1** — the count of suites loading the fixture file equals the count of
  suites. Derived by enumerating suite files and checking each for a load line,
  never by writing "six" into a test. A seventh suite that forgets the load must
  make this red, which a hard-coded number cannot do.
- **R1.2** — after the change, exactly one assignment of the limit exists across
  the whole tracked tree.

---

## E2 — The per-test limit

**What it is**: a value bats reads to decide how long any single test may run
before it is stopped and named.

**Attributes**

| Attribute | Value | Source |
|---|---|---|
| Home | the shared fixture file | FR-001 |
| Value | 60 seconds | research D3 |
| Margin over the slowest measured test | 7.58× | research D3 |
| Speed-up against the hazard it replaces | 360× | research D3 |
| External requirement | a `timeout` program on the path | research D1 |

**State transitions**: none. It is set once, at load.

**Validation rules**

- **R2.1** — the value exceeds the slowest existing test on the slowest
  environment measured, with the margin stated in a document, not implied.
- **R2.2** — an over-long test is stopped, and the output names that test.
- **R2.3** — with the limit in place, every existing test still passes. A limit
  that reddens honest work has replaced one problem with a worse one.
- **R2.4** — the reason the limit exists survives in the surviving assignment's
  own comment. A guard whose stated reason is deleted becomes a magic number at
  the first person who did not write it.

---

## E3 — The state script's output streams

**What it is**: the read path validates, then copies the state file to the data
stream. Diagnostics go to the other stream.

**Attributes**

| Attribute | Rule |
|---|---|
| Data stream, valid state | the file's bytes, accepted whole by a strict parser |
| Data stream, invalid state | empty — measured at **0 bytes** |
| Diagnostic stream, invalid state | the named fault |
| Exit status, invalid state | non-zero |

**Validation rules**

- **R3.1** — a strict parser accepts the whole data stream, with nothing else on
  it.
- **R3.2** — an invalid state file puts nothing on the data stream. A caller
  parsing that stream must see nothing rather than half a message.
- **R3.3** — with the two-character line ending present, a strict parser still
  accepts the output and command substitution still captures cleanly.
- **R3.4** — with it present, the line-reading idiom the shipped document
  forbids retains the stray character. The test constructs the condition; it
  never waits for a machine that exhibits it.

---

## E4 — A refusal

**What it is**: the state script's way of stopping. A refusal is a pair: a
non-zero exit **and** a message naming what was wrong.

**Attributes**: each refusal names one of — a phase, an artefact, a missing
argument, a state file and one of its keys, or the full list of legal
subcommands.

**Validation rules**

- **R4.1** — the exit is non-zero.
- **R4.2** — the message names the specific thing that was wrong. **This is the
  property under test.** A test asserting only R4.1 passes with the message
  emptied, which is the regression that matters: a person meeting a refusal is
  already in trouble, and a bare failure costs them the search.
- **R4.3** — each of the nine goes red when the naming it asserts is changed to
  name something else. Proven per test, not argued once for all nine.
- **R4.4** — no refusal test sleeps, races, or depends on timing. All nine
  triggers are deterministic; research D4 records each.

**The one that is not what it looks like**: the creation race. Its message names
a race, but the test does not run one. The guard above the protected write tests
for a regular *file*, so a **directory** at that path passes the guard untouched
and makes the write fail — the same branch, entered by a different door. This is
recorded here and in the test itself, because a reader who assumes the test
races will "fix" it into something non-deterministic.

---

## E5 — The private vocabulary and its folding

**What it is**: an optional, untracked list of extra forbidden terms, folded
into the shipped list when the file is present. Private by definition, so a
public build never exercises the folding unless a test does so deliberately.

**Attributes**

| Attribute | Rule |
|---|---|
| Input | a file of terms, one per line, possibly with blank lines |
| Blank lines | stripped before joining |
| Output when the list contributes nothing | the shipped list, **unchanged** |
| Output otherwise | the shipped list, then the folded terms |

**Validation rules**

- **R5.1** — the folding exists in exactly one place, and both the load-time
  caller and the test run that one place. This is what makes breaking it
  visible.
- **R5.2** — an absent, empty, or all-blank private list returns the shipped
  list unchanged: no trailing separator, no empty alternative. An empty
  alternative matches at every position, which turns the scan into something
  that fires on everything — loudly, but for a reason unrelated to a leak.
- **R5.3** — breaking the one copy turns the test red. Demonstrated, not argued.
- **R5.4** — the three behaviours already checked still are: the extra term
  matches, a blank line produces no empty alternative, and the shipped terms
  still match alongside it.
- **R5.5** — the suite's test count is unchanged. One test in, one test out.
- **R5.6** — the test neither requires nor creates a private list at the
  repository root. It supplies its own, in its own scratch directory.

---

## Cross-cutting rules

- **X1** — no file this feature writes contains a machine-specific absolute
  path, in any spelling. The previous phase's tracked-tree scan covers this
  feature's own documents, so a violation here reddens that scan.
- **X2** — no shipped script is modified. Every changed file is under a test
  tree; a diff confined to those trees is the proof.
- **X3** — no changelog file is modified.
- **X4** — every count asserted about the suite is a target the run is measured
  against, stated in the spec and this plan. No count is written into a shipped
  file, where the next change would falsify it silently.
