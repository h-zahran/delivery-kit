# Phase 0 Research: the machine path leaves the repository

All findings below are measurements taken on 2026-08-26 at commit `b819a4c`,
on Windows 11 under Git Bash. Nothing here is reasoned from documentation.

**Document constraint (FR-021):** this file is tracked and sits inside the
surface the feature scans. It therefore never writes a banned shape joined —
including the *pattern* spellings, because the escaped drive-root pattern
contains the drive-root shape as a substring. The literal spellings live in
exactly one place: the test file. This document points at them.

---

## R1 — `git grep` cannot carry the fail-loud idiom. Use `git ls-files` + `grep`.

**Decision:** enumerate the surface with `git ls-files`, then scan the
resulting file list with plain `grep`. Do NOT use `git grep`.

**Measured:**

| command | exit |
|---|---|
| `git grep -q <present> -- tests/` | 0 |
| `git grep -q <absent> -- .` | 1 |
| `git grep -q x -- 'no/such/path'` | **1** |
| `grep -nE zzz present.txt MISSING.txt` | **2** |
| `grep -nE zzz present.txt` | 1 |

**Rationale:** the whole suite rests on the distinction between "looked and
found nothing" (exit 1) and "could not look" (exit 2). `tests/portability.bats`
states it at `:116-122` and asserts `-eq 1` everywhere for exactly this reason.
`git grep` collapses both onto 1 — a renamed or vanished operand reads as a
clean repository. A scan built on it would satisfy FR-011's words while
violating its purpose, and would do so invisibly.

`grep` over an explicit file list keeps the 2. That is the mechanism FR-011
requires.

**Alternatives considered:** `git grep` with a separate assertion that the
match count is zero — rejected, because it still cannot distinguish a
disappeared surface from a clean one, and adds a second thing to keep in step.
`git grep` plus a file-count guard — rejected for the same reason; the guard
proves the enumeration worked, not that the scan read the files.

---

## R2 — The empty-operand hazard is real and already documented here

**Decision:** assert the enumerated file list is non-empty BEFORE scanning, and
fail loudly if it is not.

**Rationale:** `grep -E <pattern>` with no file operands reads standard input.
Inside `bats` that is not a hang so much as a silent pass on nothing. This is
the sibling of a hazard the suite already records at `tests/portability.bats:62-69`
for `grep -r` with no path operand, where the failure mode is a silent rescan of
the working directory. Either way the check reports on a surface it never read.

**Measured:** the enumeration returns **132** tracked files outside root
`tests/`, and **3** inside it (`helper.bash`, `layout.bats`, `portability.bats`).
A guard asserting "at least one file" would pass on a single stray file; the
guard should assert a plausible floor and say what it counted.

---

## R3 — The existing pattern is correct. My first measurement of it was not.

**Decision:** the four existing shapes are sound and are the right basis. Copy
their spelling; do not re-derive it.

**Measured, twice, with opposite results — and the second is the true one:**

| how the pattern reached `grep` | drive-root | home-prefix | Windows-users | projects-prefix |
|---|---|---|---|---|
| via a shell heredoc written through the agent harness | 0 | 0 | 0 | 0 |
| via an exact-bytes file write | **1** | **1** | **1** | **1** |

Ground truth: the live suite's own controls
(`the leak scanners actually fire on a known-bad fixture`,
`an encoded project directory is still caught after the narrowing`) both pass.
The pattern works. The heredoc route silently ate one backslash level and
reported every branch dead.

**This is the single most important operational finding in this feature.**
A check that has "stopped matching entirely" is indistinguishable from a clean
tree, and here the *measurement of the check* failed exactly that way. The
suite's own comment at `:470-474` says the same thing about narrowing versus
deleting a pattern.

**How to apply, binding on the implementer:**

1. Write the pattern line with a file-writing tool that emits exact bytes.
   Never through a shell heredoc, never through an inline shell argument.
2. Immediately prove what landed: `sed -n '<line>p' <file> | cat -A` and read
   the backslashes on screen before trusting any result.
3. Then run the positive control. Only a control that MUST match, and does,
   licenses belief in a scan that reports nothing.

Inside a `.bats` file there is no argv boundary, so the in-file spelling is
safe and portable — that is why the existing pattern has worked for months.
The hazard belongs to the authoring route, not to the suite.

---

## R4 — Two lists, cross-referenced, per the C-gate clarification

**Decision:** the new tree-wide scan gets its own pattern variable. The existing
one is not touched (FR-022, FR-023).

**Rationale:** they cover different surfaces and need different tightness. The
existing one scans what a stranger installs and matches the home prefix
unconditionally; the new one scans the whole tracked tree and requires a name
character after that prefix, so the three deliberate elided references survive
(FR-008, FR-014). Narrowing the shared list would change what a shipped gate
catches, as a side effect of a scrub.

**Accepted cost:** two hand-maintained lists. Mitigated by a comment in each
naming the other, and recorded in the spec under accepted risks rather than
left to be discovered.

---

## R5 — Portability constraints, and what they rule out

**Decision:** word boundaries from `-w` if any are needed, never the GNU escape;
no `grep -P`; no process substitution in the assertion path.

**Rationale:** continuous integration runs the suite on three operating systems,
one of which ships BSD `grep`. `tests/portability.bats:123-129` already records
that the GNU word-boundary escape either errors (exit 2) or is read as a literal
there, and that both outcomes previously read as a clean repository under a
looser assertion.

**Measured on this machine:** no tracked filename contains a space, so a
word-split file list is safe today. That is a property of the tree, not a
guarantee — the implementer should prefer a null-delimited enumeration if it
costs nothing, and must not add a filename with a space in this feature.

**Cannot mix `-F` and `-E` in one `grep` call.** Since the in-file spelling is
safe (R3), one `-E` alternation covering all four shapes is the simplest correct
form and matches the existing house idiom. The `-F`-per-shape technique is for
interactive verification from the agent harness, where the argv boundary bites;
it is not needed inside the suite.

---

## R6 — What the scan must NOT be allowed to become

**Decision:** the scan asserts `-eq 1`, never `-ne 0`, and never a count
comparison alone.

**Rationale:** `-ne 0` accepts exit 2, which is the whole failure this feature
exists to prevent — `tests/portability.bats:116-122` records that a rename of a
scanned directory would otherwise switch the scan off with the suite green. A
bare count comparison has the same defect one layer up: a scan that errored
produces no lines, and "no lines" and "no matches" are the same number.

---

## Resolved unknowns

Every item the plan template would mark NEEDS CLARIFICATION is resolved above
or was answered at the C gate. Nothing is outstanding.

| Unknown | Resolved by |
|---|---|
| Which tool enumerates and scans the surface | R1 |
| How an empty or broken surface is caught | R2, R6 |
| Whether the existing pattern spelling is trustworthy | R3 |
| Whether one list or two | C-gate clarification, R4 |
| Which constructs are safe on all three platforms | R5 |
| How the author avoids writing a false-green pattern | R3 |
