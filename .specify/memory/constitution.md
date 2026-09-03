<!--
SYNC IMPACT REPORT
Version change: (unfilled template) -> 1.0.0
Bump rationale: initial ratification. Every placeholder in the resolved
  constitution-template scaffold is now filled with concrete, project-derived
  text. There is no prior version to be backward incompatible with, so the
  MAJOR/MINOR/PATCH rules do not apply to this first write; 1.0.0 is the
  adoption baseline that later amendments increment from.

Modified principles: none renamed — all five are new.
Added sections:
  - Core Principles I-V
  - "What ships, and what is scanned"
  - "Development workflow"
  - Governance
Removed sections: none.

Placeholders resolved:
  PROJECT_NAME, PRINCIPLE_1..5_NAME, PRINCIPLE_1..5_DESCRIPTION,
  SECTION_2_NAME, SECTION_2_CONTENT, SECTION_3_NAME, SECTION_3_CONTENT,
  GOVERNANCE_RULES, CONSTITUTION_VERSION, RATIFICATION_DATE,
  LAST_AMENDED_DATE. No bracket token remains.

DEFERRED PROPAGATION — read this before assuming the templates agree.
  This file was written during a release feature whose stated constraint is
  "six version strings and two headings, nothing else", so the usual
  sync-impact edits into .specify/templates/ were NOT made. Exactly one file
  was written: this one. A later pass should consider propagating:
    - plan-template.md's Constitution Check gate: it currently has no
      project-specific gate items. Principles I, II and III are the three a
      plan can be checked against mechanically, and they are the ones a plan
      most often violates by omission.
    - spec-template.md: nothing required. Its quality checklist already covers
      testability, which is what Principle II needs from a spec.
    - tasks-template.md: consider a standing task shape for Principle III — a
      new gate ships with the positive control that makes it fail.
  Nothing in this file depends on that propagation. It is recorded so the next
  pass inherits it rather than rediscovering it.
-->

# delivery-kit Constitution

## Core Principles

### I. Silence is the failure that matters (NON-NEGOTIABLE)

A check that cannot speak is worse than one that fails loudly. A red is
information; a check that quietly did not run is a lie told in the voice of a
verdict. Every gate MUST fail rather than vanish, and MUST refuse to pass
vacuously — a walk over zero items reports zero problems and has verified
nothing.

This is not an abstraction. Four places in this repository exist only because
of it. The release-tag gate in `.github/workflows/ci.yml` triggers on
`tags: ['**']` rather than a well-formed filter, because a filter admitting
only correct tags does not reject the malformed ones — it stops the workflow
running at all, and skips the gate for exactly the tag it was written to catch.
`scripts/check-versions.sh` ends by asserting it examined at least one plugin,
because a loop over zero plugins passes having checked nothing, and it pins its
two directional walks to each other so they cannot silently cover different
sets. The shell-analysis job exits non-zero when its own file discovery matches
nothing, and says so in those words. And the context guard parses its transcript
line by line rather than slurping it, because a single torn line aborts a
whole-file parse and leaves the guard silently disabled — which is the one
direction the hook's own comments forbid it to fail in.

Prefer a wrong-looking red over a right-looking green. When the two are
available, choose the failure that names itself.

### II. Measure; never assert

A claim about behaviour MUST be produced by running something, and reported with
the date it was run and the baseline it was run against. "Behaviour is
unchanged" is not a sentence anyone may write here without a differential that
says so.

The discipline has a shape. Exact figures live in ONE dated table, described as
a record of one run rather than a claim about the current file; prose elsewhere
names the command to count with and carries no total of its own. A divergence
that has been examined and kept is ASSERTED by the harness, so that quietly
repairing it goes red — the direction nobody watches. Leaving such a shape out
lies by omission, and leaving the harness permanently red trains a reader to
skim past the one line that matters.

The cost of the alternative is on record. A refactor whose whole claim was
"identical behaviour" turned out to change what the guard answers on three
separate transcript shapes, in two opposite directions, and the sentence
describing it was wrong twice before the harness was ever wrong once.

### III. A gate must be shown able to go red

A check that has only ever passed has not been shown capable of failing. Every
new gate MUST ship with a positive control that makes it fail on purpose, and
the control MUST be run, not merely written.

A positive control proves one direction only — that a check CAN go red, never
that it goes red ONLY when it should. Both directions need thought, and the
second is the one that gets skipped.

A mutation MUST be verified to have landed before its red or green is believed.
`scripts/context-guard/field-order-mutation.sh` encodes three failures that each
produced convincing false evidence first: it refuses to run in the main
checkout, because an earlier version's orphaned process went on mutating a
tracked file after its wrapper was killed; it requires every mutant to pass a
syntax check, because a splice that dropped a newline made every mutant an
unparseable script and the resulting all-red table read as a flawless sweep of
catches; and it reports a mutation that changed nothing as NO-OP rather than as
a pass, because a mutation that did not land is a silent false green.

### IV. One implementation, many callers

Logic duplicated across two callers and kept in step by hand WILL drift, and the
drift is invisible until it matters. Where two callers need the same rule, they
MUST invoke one file, and a test MUST pin that neither has grown an inline copy
beside the call.

A comment asking maintainers to edit a pair together is exactly what was in
place when this repository's pair drifted: an unanchored regex in one copy
accepted a changelog heading the other rejected, and nobody saw it until a
release. `scripts/check-versions.sh` is that pair collapsed into one
implementation, and `tests/portability.bats` pins that both callers name it — so
a hand-written copy cannot quietly return.

One implementation is the only arrangement that cannot drift. A rule written
twice is a rule that will eventually be two rules.

### V. Derive coverage; never enumerate it

A hand-written list of what to check, and a number written into prose, both go
stale in the direction that hurts — and the entry they omit is reliably the
interesting one. Coverage MUST be derived by walking the tree. Where two views
of the same set exist, both MUST be walked and their counts pinned equal.

`scripts/check-versions.sh` walks directory-to-entry AND entry-to-directory,
because the first walk alone never visits a marketplace entry whose directory is
missing — a retired plugin's leftover entry, or an entry landed ahead of its
directory — and advertises a broken install while every other check calls it
agreement. The shell-analysis job discovers its files with `git ls-files` rather
than naming them. The shipped-surface lists register DIRECTORIES, not files, so
that a new document in a registered tree is scanned the day it lands.

The counter-evidence is unambiguous. One written total in a plugin changelog
went stale four separate times across three sessions, and on every occasion the
shape it omitted was one asserted to differ — the single most load-bearing
entry in the set. Carrying no total does not save a LIST, either: the same
paragraph, stripped of its number, went on naming fifteen items when there were
sixteen.

## What ships, and what is scanned

This repository publishes two plugins from one tree, and there are three
surfaces. Which tree a file belongs to is the first thing to get right when
adding one: the `handoff` plugin's surface lives under `handoff/`, the
`pipeline` plugin's under `pipeline/`, and the repository's own at the root —
what a reader sees before deciding to install anything.

**An unregistered file is an unscanned file.** Registration is by directory, per
Principle V, so a new document in a registered tree is covered on arrival.

`tests/portability.bats` fails the build when project-specific vocabulary, an
absolute local path, or the name of a tool this project does not depend on
appears anywhere a user reads or installs. This is a privacy boundary, not a
style rule: these plugins were extracted from a specific private codebase, and
the tests exist so that codebase cannot be re-imported by accident into a public
repository. Detectors, and the suites that assert on a detector's output, MUST
be allowed to write the strings they detect — that exemption is stated in the
suite under a named relaxed vocabulary, never applied silently.

Changelogs are immutable history. An entry that was true when written is not
edited to match a later state; a later state gets a later entry. The corollary
is a deadline: a release stamps a version heading and freezes everything beneath
it, so text under an open heading MUST be corrected BEFORE that stamp, and the
release phase is the last moment it can be.

## Development workflow

**The suite runs from the repository root and names every suite path.** Passing
only the root `tests` directory runs the repository's own suite, silently skips
both plugins' suites, and reports green — the exact failure this project exists
to prevent, arriving by way of its own instructions. A test can pass in a
worktree and fail at the root; the root is the verdict.

**Three operating systems, or it is not finished.** A change green on one is not
finished. And the runner's toolchain is not the contributor's: CI ships an older
shell analyser that reports MORE findings than a current local copy, so a local
green does not predict CI, and the same asymmetry holds for platform differences
in the standard tools.

**Nothing leaves the machine without a human answering a gate.** The pipeline
opens a pull request and stops; it never merges, because merging is a decision
about shared history. No force-push in any spelling. No staging by wildcard —
every committed path is named, because a wildcard is how an unrelated file, a
secret, or another session's work gets committed. No skipping a hook. No branch
deletion. No rewriting a commit that has been pushed. No destructive git command
against tracked files, and no stash: an uncommitted tree is the one place with
no recovery point.

**The CI workflow references no secret, no token and no publish step.** That
absence is a security property to preserve, not a gap to fill. Adding a
publishing step is an owner decision about that invariant, not a defect fix.

## Governance

This constitution supersedes convention and habit. Where a practice and a
principle disagree, the principle wins or the principle is amended — not
quietly ignored.

**Amendments are their own commit.** A governance change never rides inside a
feature's commit, and never inside a release. An amendment states what changed,
why, and what it obsoletes.

**Versioning.** This document uses MAJOR.MINOR.PATCH. MAJOR for a principle
removed or redefined in a backward-incompatible way; MINOR for a principle or
section added, or guidance materially expanded; PATCH for clarification and
wording. The version, ratification date and last-amended date at the foot of
this file are the record.

**Departures are named, never silent.** A principle may be departed from when
the work requires it, on one condition: the departure is stated and its reason
recorded in the run's artefacts, where a reviewer will meet it. A silent
exception is the failure mode every principle above exists to close, so an
unrecorded departure is a worse defect than the thing it was trying to avoid.

**Compliance is checked twice**: at the specification quality gate, where a
requirement that cannot be tested is caught before anyone builds against it, and
at deep review, where the implementation is read against the specification by
reviewers who did not write it.

Runtime development guidance lives in `CONTRIBUTING.md` and in each plugin's
`README.md`. This document says what must hold; those say how to do it here.

**Version**: 1.0.0 | **Ratified**: 2026-09-03 | **Last Amended**: 2026-09-03
