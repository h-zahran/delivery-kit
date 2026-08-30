# Contract: the shared version-agreement implementation

The single executable both gates call. Every clause below is a promise
the script keeps, and each names how it is verified.

---

## V1 — One implementation, two callers

The version-agreement logic exists once in the repository. The test-suite
gate and the continuous-integration job each obtain their verdict by
invoking it. Neither carries a copy of the comparison logic.

**Verifiable by:** a suite test that locates the invocation in each
caller and asserts both name the same script.

---

## V2 — The parity test cannot pass on itself, and binds to the gate

The test asserting V1 does not satisfy its own assertion by matching its
own text. It does NOT do this by excluding its own line range — an
earlier draft of this clause said so and was wrong about its own
implementation. Two mechanisms do the work instead:

- The invocation anchor requires the call to BEGIN a line, and the test's
  own body holds no such line.
- The inline-copy marker is a pattern the file that defines it cannot
  contain, because that definition spells the pattern's own
  metacharacters escaped.

If either were ever wrong the result is a RED on a correct tree, never a
green on a broken one.

Separately, the invocation must be bound to the version GATE, not merely
found somewhere in the suite file. The test maps each invocation to the
enclosing test block and requires exactly one, owned by the gate.

**Verifiable by:** pointing one caller at a different path, parking the
invocation in an unrelated test, and adding a second invocation — each
observed to fail. A test that has never been observed to fail has not
been shown to test anything.

---

## V2a — The gate proves the implementation can fail

The suite gate does not assert only that the shared implementation exits
zero. It asserts that the implementation REPORTED, and it runs the
implementation against a deliberately broken fixture and requires a
non-zero exit naming the planted value.

Two breaks are used, each visible to exactly one comparison: a
marketplace version that disagrees with a manifest, and a changelog
heading that disagrees with a manifest. A single break that disagrees
with two recorded places is caught by either comparison, so deleting one
of them would leave the gate green.

Stated honestly: this exercises two of the twelve checks V3 lists. The
per-check sweep lives in the run record, because the suite's size is
fixed by the feature's own delta.

**Verifiable by:** replacing the implementation with one whose body is
`exit 0`, then with one that prints a convincing report and exits zero,
then by deleting each of the two comparisons in turn — all four observed
to redden the gate.

---

## V3 — Every existing check survives

The script performs every check the two replaced copies performed, with
no check dropped and none weakened: manifest name present; manifest
version present; manifest name equal to its directory name; a marketplace
entry existing under that name; that entry carrying a version; that
entry's source resolving to the same directory; a changelog heading in
the pinned format; manifest equal to marketplace; manifest equal to
changelog; every marketplace entry naming an existing plugin directory;
the two walks covering the same count; and at least one plugin directory
found.

**Verifiable by:** removing each checked value in turn from a scratch
copy of the tree and observing the script reject it, naming that value.

---

## V4 — Absence and disagreement are different failures

A value that is missing and a value that disagrees produce different
messages. A present entry missing a key is never read as the literal text
a query language prints for a null.

**Verifiable by:** the two mutations producing two different messages.

---

## V5 — The script names its working directory requirement

The script refuses to run, non-zero and with a named message, unless its
working directory holds the marketplace manifest. It does not guess a
root and does not walk upward looking for one.

**Verifiable by:** invoking it from a directory that holds no manifest
and observing a named refusal rather than a pass over nothing.

---

## V6 — A vacuous pass is impossible

A walk that visits no plugin directory fails. A walk that reads no
marketplace entry fails. The two counts are compared to each other, so
the walks cannot quietly cover different sets.

**Verifiable by:** running the script against a tree holding no plugin
directory and observing it fail with a message naming that condition.

---

## V7 — Identical behaviour on all three platforms

Every construct behaves identically on the three operating systems the
matrix covers. In particular, a line-reading loop strips a trailing
carriage return, because on one of those platforms the query tool's
output is text-mode and a name carrying that character matches no entry.

**Verifiable by:** the matrix passing on all three.

---

## V8 — The release-tag step is not part of this contract

The workflow's step that compares a release tag against a manifest
version is a different check with a different trigger. It is untouched by
this feature and is not folded into this script.

**Verifiable by:** a byte-level comparison of that step before and after.

---

## V9 — The existing gate keeps its name

The suite's version-agreement test keeps the name it had, so the suite's
own record of what it covers stays continuous across this change. Only
its body changes, from the logic to a call.

**Verifiable by:** the test name appearing unchanged in the suite listing.
