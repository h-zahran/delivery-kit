# Research: shellcheck, and one version gate instead of two

Every finding below was measured on the development machine on
2026-08-30, not recalled. Where a measurement contradicts the seed, the
measurement wins and the contradiction is named.

---

## R1 — The runner tag is annotated, so the pin has two candidate values

**Decision**: Pin the COMMIT the tag points at, not the tag object.

**Rationale**: Asking the upstream repository for the release reference
returns two identifiers: the tag object, and the commit that tag points
at, distinguished by a peel suffix. They are different values, and the
first one the obvious query returns is the tag object.

**CORRECTED after measurement, 2026-08-30.** The first draft of this item
said only the commit could be fetched and checked out, and that the tag
object's identifier would produce something that is not a commit. That is
FALSE, and it was written from reasoning rather than from a run. Measured
against the real upstream repository: both identifiers fetch, both check
out, git peels the tag during checkout, and HEAD lands on the same commit
either way. A rationale that is wrong is worse than none, because the next
reader trusts it and stops checking.

The commit is still the right pin, for two narrower reasons that do hold:

1. After checkout, asking the working copy for its own revision returns
   the COMMIT. Any verification that compares the checked-out revision
   against the recorded pin therefore only works when the recorded pin is
   the commit.
2. A tag object's identifier hashes the tag's own metadata — its message,
   tagger and signature — as well as its target. Re-tagging the SAME code
   with a different message yields a different tag object identifier. The
   commit is the more stable name for the code, and the code is what is
   being pinned.

**Alternatives considered**: Keeping the tag and adding a verification
step that compares the checked-out revision against a recorded commit.
This also detects a retag and keeps the reference readable — but it
detects the retag AFTER fetching and trusting the code, and it leaves a
mutable reference in the fetch itself. Fetching the immutable reference
directly is stronger for the same number of lines.

**Verified, not assumed**: the fetch-and-checkout shape was run against
the real upstream repository before it was written into the workflow. The
checked-out tree reports the expected release version.

**Residual, accepted**: The pin must be re-derived by hand when the
runner is upgraded, and the comment carrying the release name must be
updated with it. Nothing enforces that pairing. It is one line, beside
the value it describes, which is the cheapest arrangement that keeps the
pin readable at all.

---

## R2 — Fetching one commit shallowly

**Decision**: Initialise an empty repository, fetch the pinned commit at
depth one, and check out the fetched head.

**Rationale**: This is the only shape that fetches an immutable
reference AND stays shallow. A shallow clone takes a branch or a tag, not
an arbitrary revision. The hosting service permits fetching an arbitrary
reachable revision by name, which is what makes the shape work.

**Alternatives considered**: A full clone followed by a checkout of the
pin. Correct, but downloads the entire history on three operating systems
for a dependency used through one entry point.

**Residual, accepted**: If the hosting service ever refuses an
arbitrary-revision fetch, this step fails loudly at the fetch rather than
degrading. That is the correct direction of failure.

---

## R3 — Caching the runner

**Decision**: Cache the fetched runner directory, keyed on the operating
system and the pinned revision.

**Rationale**: The key includes the pin, so changing the pin invalidates
the cache without anyone remembering to. The key includes the operating
system because the matrix runs three, and one cache shared across them
would restore one platform's tree onto another.

**Executable-bit concern, resolved**: A cache restore can lose an
executable bit, which would normally break a fetched tool. It cannot
break this one: the workflow invokes the runner by handing its entry
point to a shell, not by executing it directly. That was already true
before this change and is not a new dependency.

**Residual, named**: The caching action is referenced by a moving major
version, exactly the kind of reference this same change is pinning away
from for the test runner. The inconsistency is deliberate and is stated
in the workflow: first-party actions from the hosting platform are
already referenced this way in this file, and pinning one of them while
the others move would be a false tidiness. Changing that policy is a
separate decision about every action in the file, not a side effect of
this one.

---

## R4 — Where the analyser comes from

**Decision**: Use the analyser the runner image provides; install it from
the platform's package channel if it is absent; print its version in
every run.

**Rationale**: This is the shape the same workflow already uses for its
other external tool, so a reader meets one pattern rather than two. The
version print means the log records which analyser produced a verdict,
which is the difference between a reproducible red and a mystery.

**Alternatives considered**: A third-party action wrapping the analyser.
Rejected: it adds a supply-chain dependency to a repository that is in
the middle of removing one, for a tool that is a single command.

**Residual, accepted and stated**: The analyser's version is the runner
image's, so an image upgrade can turn the job red on code that has not
changed. Pinning the analyser is out of this feature's scope. The version
print is what makes such a red diagnosable in one look.

---

## R5 — What the analyser actually finds today

**Measured**, over the four first-party shell files:

- Exactly one finding, in the shared test helper: a variable assigned and
  never read within its own file.
- The reader is the test runner, which consumes that variable from the
  environment of the file it loads. The analyser cannot see a reader
  outside the file.

**Decision**: Suppress it at its own line, naming the reader.

**Rationale**: The variable is used. Exporting it would silence the tool
honestly but would change what child processes inherit — a behaviour
change to test plumbing, made for a cosmetic reason. The spec forbids
that.

**Consequence for the workflow**: There is no job-level suppression list
at all. That is the strongest form of "short and explicit".

---

## R6 — The vendored scaffold

**Measured**: The vendored scaffold directory holds six shell files,
roughly one and a half thousand lines, and produces around ten finding
lines across four distinct identifiers. It already carries the
repository's only pre-existing suppression directive.

**Decision**: Out of the analysed set, excluded by pathspec, with the
reason written into the workflow.

**Rationale**: It is not authored here and is regenerated by re-running
its upstream tool, so a fix made to it is discarded on the next upgrade.
Fixing code that will be overwritten is work that produces nothing.

**Alternatives considered**: Including it and suppressing the ten
findings — a long suppression list on files nobody here maintains.
Including it as warnings only — a signal nobody is required to act on,
which is noise.

---

## R7 — Test suites written for the test runner

**Measured**, over the six tracked suite files: the analyser does read
them, and reports fifty-five findings. The distribution matters more than
the count: over half are reports about single quotes preventing
expansion, which is exactly what a pattern fixture wants; several are
unquoted expansions in the leak scanners, where word splitting is the
mechanism, not a mistake.

**Decision**: Out of the analysed set for this feature.

**Rationale**: The seed scopes this phase to shell files and names four.
Bringing in fifty-five findings, most of which resolve to suppressions on
deliberate constructs, is a separate piece of work with its own budget
and its own review. Leaving the boundary unexplained is what would be
wrong; the measurement is written into the workflow so the next reader
inherits the reason rather than the mystery.

**Guard against a mistaken reading**: an earlier probe suggested the
analyser ignored these files entirely. It does not — that probe used a
sample the analyser correctly finds nothing wrong with, and a real
positive control was run afterwards to prove the analyser reports what it
should. Never trust a green from a control that was never proven to
fire.

---

## R8 — The discovery rule

**Decision**: Ask git for tracked files matching the shell extensions,
excluding the vendored directory by pathspec.

**Measured**: The rule yields exactly the four first-party files today.
Widening the exclusion to everything yields nothing, so the empty case is
reachable and the guard against it is testable rather than theoretical.

**Rationale**: A hand-written list of four filenames goes stale the
moment a fifth lands — and this very feature adds one. Discovery covers
it on the day it arrives. This repository has already recorded the
lesson: derive coverage checks, never enumerate them.

**Residual, named**: A second vendored tree arriving later is admitted
automatically. The exclusion is written as a rule about vendored
scaffold, so extending it is a visible one-line edit rather than a silent
omission.

---

## R9 — Prose this change deletes

**Checked before editing**: The workflow's comment describing the two
gates as a hand-maintained pair is not pinned by any test in the suite,
and no contract file asserts it. One superficially similar string exists
in an unrelated contract, and it is about a different pair — two path
denylists, not the two version gates.

**Consequence**: The comment can be replaced by one describing the new
arrangement. If it had been pinned, the pin would have had to move in the
same commit.

---

## R10 — Line endings

**Checked**: The repository already declares line-ending normalisation
for shell extensions in its attributes file. A new script inherits it
with no change. This matters because the shared script runs under a shell
on a platform whose checkout would otherwise convert it, and a carriage
return in a shell script produces a failure that names nothing useful.

---

## R11 — Stale references in the seed

The seed's line numbers into the workflow and the suite have shifted, and
one of its line counts is stale: the shared test helper has roughly
tripled since the seed was written. Every construct was located by
content instead. The file identities in the seed are all still correct.

---

## R12 — A trap the parity test must avoid

A test that searches the suite file for the shared script's path will
match its own assertion text and pass on itself. The existing test that
polices the runner invocation line is the working template for avoiding
this: anchor on the shape of the line being policed, strip trailing
comments before inspecting, and prove the test can fail by pointing one
caller at a wrong path in a scratch copy before trusting its green.
