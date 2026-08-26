# Contract: the tree-wide machine-path scan

The observable contract of the two checks this feature adds. Written so an
auditor can verify it from outside, without reading the implementation.

**Document constraint (FR-021):** no banned shape appears joined in this file.
The single authoritative spelling of every pattern is the variable in
`tests/portability.bats`. This contract constrains behaviour, not spelling.

---

## C1 — The scanned surface

**Every tracked file in the repository, except those under root `tests/`.**

- Untracked files are out of scope. The property being protected is what the
  repository publishes.
- Root `tests/` is excluded **by construction, not by exemption**: it holds the
  denylists themselves and the known-bad fixtures the scanners are fired at. A
  scan covering it fails on its own contents. Re-measured 2026-08-26 after the
  guard landed: **eight** lines in that tree match — the two path denylists
  themselves, and six synthetic fixtures the scanners are fired at. Four of the
  eight were added by this feature. None can be removed without disabling the
  check it serves. An earlier draft of this contract said "exactly two"; that
  was the count before this feature added its own control fixtures, and it is
  corrected here rather than quietly.
- The exclusion carries no permission. An account name is forbidden there too
  (FR-001); nothing scans for it, so nothing must put one there.

**Verifiable by:** adding a tracked file anywhere outside root `tests/` that
carries a banned shape, and observing the suite fail.

---

## C2 — The four shapes

The scan matches a line that contains any of:

1. **Drive root** — a Windows drive letter, a colon, a backslash.
2. **Windows users prefix** — a Windows drive letter, a colon, a backslash,
   `Users`, a backslash.
3. **Git-Bash home prefix followed by a name character** — the POSIX-style
   mount of that same users directory, and then one character from
   `[A-Za-z0-9_]`.
4. **Agent-projects prefix followed by a name character** — the per-machine
   agent project directory, and then one character from `[A-Za-z0-9-]`.

Shapes 1, 2 and 4 are spelled exactly as the existing denylist spells them.
Shape 3 is the existing shape plus the trailing character class; that class is
the entire difference between the two lists.

**Verifiable by:** the positive control (C5), and by C3.

---

## C3 — Deliberate elided references do not match

A line that names a banned prefix with the identifying portion replaced by an
ellipsis MUST NOT match.

Three such lines exist and are load-bearing documentation; one of them is the
recorded deferral of this very sweep. They are listed in the specification at
FR-008.

**Verifiable by:** running the suite with those three lines present and
unmodified, and observing it pass. They are in the scanned surface, so this is
not a hypothetical — the suite proves it on every run.

---

## C4 — Exit status is the assertion

| Observed | Meaning | Result |
|---|---|---|
| 0 | A banned shape is present | **FAIL** |
| 1 | The surface was read and is clean | **PASS** |
| 2 | Could not look — renamed operand, unreadable file, rejected expression | **FAIL** |

`-ne 0` is forbidden: it maps exit 2 onto pass, which is how a renamed
directory switches a scan off with the suite green. A bare match-count
comparison is forbidden for the same reason one layer up — a scan that errored
produces no lines, and "no lines" and "no matches" are the same number.

**Verifiable by:** renaming or removing a scanned path and observing the check
fail rather than pass.

---

## C5 — The control shares the scan's expression

A second check fires **the same variable** at a fixture that must match, and
asserts that it does.

- Same variable, not a copy and not a re-spelling. A control that exercises a
  different expression proves nothing about the scan.
- The fixture is synthetic. A real machine path has no business in a committed
  file, and a fabricated one demonstrates the point identically.
- The control's comment MUST state what it proves and what it does not: that
  the scan is **capable** of failing — never that the scan fails only when it
  should.

**Verifiable by:** breaking the shared expression and observing the control go
red, not just the scan.

---

## C6 — The surface is proven non-empty before it is read

The enumeration MUST be checked for emptiness first, and the check MUST report
what it counted.

An empty operand list turns the scan into a read of standard input, which
reports cleanly on nothing at all. This is the sibling of a hazard the suite
already records for a recursive scan given no path operand.

**Verifiable by:** forcing the enumeration to return nothing and observing the
check fail with a message naming the problem.

---

## C7 — The existing denylist is untouched

The existing path denylist and every check that reads it behave identically
before and after this feature.

The two lists are deliberately separate (C-gate clarification). Each carries a
comment naming the other, stating that they are separate on purpose, that they
cover different surfaces, and that changing one is a prompt to consider the
other. Neither comment may claim they are kept in step automatically, because
nothing does that.

**Verifiable by:** a byte-level comparison of the existing denylist line before
and after, and by the existing path checks still passing unchanged.

---

## C8 — Portability

Every construct behaves identically on the three platforms continuous
integration runs. In particular: word boundaries come from `-w` and never from
the GNU escape, which on one of those platforms either errors or is read as a
literal — and both outcomes previously read as a clean repository.

**Verifiable by:** the continuous integration matrix passing on all three.
