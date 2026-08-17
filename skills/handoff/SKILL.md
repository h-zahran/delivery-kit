---
name: handoff
description: Use when the context guard hook fires, when the user says "hand off", "continue in a new session", or "stop after batch X and hand off" — makes the work durable, writes a standardised handoff document, and prints the exact resume prompt so the next session continues with zero re-discovery.
---

# Handoff — end this session cleanly, resume in a fresh one

The goal: the next session should reach full working speed from ONE file read.
Never start new work after this skill is invoked.

## Where the document goes

Read `.delivery-kit.json` from the repository root if it exists. `handoff.docsDir`
sets the directory; the default is `docs/handoffs`. The environment variable
`DELIVERY_KIT_HANDOFF_DIR` overrides both. Below, `<docsDir>` means whichever
of those applies.

## Checklist (create a todo per item)

### 1. Land the current step

- Finish only the atomic step in progress — a file edit, a test run, not a batch.
- **Do not commit. Do not push. Do not stage anything.** Leave the working tree
  exactly as the developer had it. Git history and shared branches are theirs,
  and a handoff is not a licence to write to either: the commit message would be
  yours rather than theirs, a push is outward-facing and hard to undo, and this
  skill is normally invoked by a hook firing — so neither would have been asked
  for. Earlier versions of this skill required both, and that was the wrong call.
- Instead, **make the uncommitted state legible** in the document you are about
  to write, so nothing is lost by being unrecorded rather than by being
  uncommitted. Run `git status --porcelain` and `git diff --stat`, and record in
  the State section every modified, added and untracked path, plus which of them
  are the work in progress as against pre-existing noise. A path you leave out is
  a path the next session does not know to look at.
- Say plainly that the work is uncommitted, and that `git clean`, `git checkout`
  or `git stash` will discard it. Then print the commands the developer can run
  if they want it committed, and leave the choice with them:

  ```bash
  git add -- <the paths you listed>          # never -A; you do not know what else is there
  git commit -m "wip(<scope>): <what landed>"
  git push                                   # only if they want it on the remote
  ```

- If this run has a plan or task list, bring it up to date with what actually
  landed. The completion gate at the end of this skill fails a handoff that
  leaves it stale, and no later step revisits it. Editing that file is in scope —
  it is part of writing the handoff, not a commit.

### 2. Write the handoff document

Path: `<docsDir>/<YYYY-MM-DD>-<topic>-SESSION-HANDOFF.md`, where `<topic>` is a
short slug naming what this run is about.

One live handoff per run, so it is normally unambiguous which one to read. If
this run already has a handoff — the file named in the resume line you were
given, or failing that the most recent file in `<docsDir>` matching this run's
topic and branch — overwrite it where it is rather than starting a new file
under today's date, so a run spanning midnight does not leave two. If you cannot
identify one as this run's, write a new file: leaving a duplicate is recoverable,
overwriting another run's handoff is not.

Required sections:

- **Branch & SHA** — working branch, last commit SHA, pull-request number and CI
  status at handoff time.
- **Goal & done-condition** — what the whole run is for, and how we know it is
  finished.
- **State** — a table of batches or tasks: done (with commit SHAs and PR
  numbers), in progress (the exact next action), remaining.
- **Uncommitted work** — the `git status --porcelain` and `git diff --stat` output
  from step 1, with each path marked as this run's work or as pre-existing. This
  section is what replaces the commit an earlier version of this skill made: the
  work is durable because it is *recorded*, not because it was written to history.
  If the tree is clean, say so — an absent section reads as an omission.
- **Verification state** — last full test count, static-analysis baseline, CI
  status, runtime verification done or pending.
- **Blocked** — items that cannot proceed, each with its specific blocker
  (billing, a missing secret, a permission, waiting on the user). Never silently
  drop a blocked item.
- **Gotchas discovered this session** — anything the next session must know that
  is not recoverable from the code or from git history: workarounds, dead ends
  already tried, decisions taken and why.
- **Deployments pending** — migrations, function deploys, store or registry
  uploads NOT yet applied.
- **Resume protocol** — numbered steps the next session executes first. Step 1 is
  always: reconcile this document's claims — branch, SHA, PR and CI state —
  against actual git state, and report any discrepancy before proceeding. **HEAD
  should match the SHA recorded here exactly**, because this skill commits
  nothing — a HEAD ahead of it means someone else committed, which is worth
  reporting rather than waving through. The working tree should still be dirty in
  exactly the way the Uncommitted work section describes; if it is clean, ask
  before assuming the work was committed rather than discarded. Then the exact
  next command or action for each remaining item.

Before you finish the document, verify that every file path and cross-reference
in it resolves to a real file. Stale cross-document links have cost a session
before.

**Then save it and stop. Do not commit it and do not push it.** The document is
durable because it is on disk, and the next session reads it from disk. Tell the
developer the path, and include the document itself in the `git add` line you
print in step 1, so a developer who does want a commit gets the work and the
record in one.

### 3. Persist durable knowledge

If facts were learned this session that are not derivable from the code or from
git history, persist them wherever this project keeps durable knowledge, and
update that store's index so the next session finds them. If the project keeps
no such store, do not invent one: the Gotchas section of the document you just
wrote is the store, and recording them there is enough.

### 4. Print the resume prompt and stop

End the final message with exactly this block, with the placeholder replaced by
the real path of the document you just wrote, so the user can copy and paste it:

```
Resume with:
Read <path-to-handoff-document> and continue from it. Follow the Resume protocol.
```

The wording never varies; only the path does. A block still containing the
placeholder has not been substituted and is useless to the person receiving it —
read it back before you send it.

Then STOP. Do not begin new batches, reviews, or "quick" extras.

## Hard rules

- Handoff quality is measured by what the next session does NOT have to
  rediscover.
- **This skill never writes to git.** No commit, no push, no `git add`, no stash,
  no branch, no tag. If you are about to run a git command that changes anything,
  you have left the skill. Reading git state is expected and required.
- **Unrecorded** changes mean the handoff is not done — as does an out-of-date
  plan or task list, where this project keeps one. Uncommitted changes are fine
  and are the normal outcome; changes the document does not mention are the
  defect, because those are the ones the next session cannot find.
- If the context guard fired mid-batch, note in the document exactly which
  finding or task within the batch is the boundary.
