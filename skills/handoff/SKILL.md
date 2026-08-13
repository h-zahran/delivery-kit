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
- Commit everything on the working branch, and push it if the repository has a
  remote. No uncommitted work may survive the session. If something is genuinely
  half-done, commit it as `wip(scope): …` — or whatever this project's commit
  convention calls work in progress — and flag it in the handoff document.
- If this run has a plan or task list, bring it up to date with what actually
  landed. The completion gate at the end of this skill fails a handoff that
  leaves it stale, and no later step revisits it.

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
  against actual git state, and report any discrepancy before proceeding. One
  discrepancy is expected and is not worth reporting: this document's own commit
  lands after its SHA is recorded, so HEAD is one commit ahead. Then the exact
  next command or action for each remaining item.

Before committing the document, verify that every file path and cross-reference
in it resolves to a real file. Stale cross-document links have cost a session
before.

Then commit it, and push if there is a remote — the next session cannot read a
document that never left this machine. That commit is docs-only, so put
`[skip ci]` in its message rather than burning a full CI run on it.

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
- Uncommitted changes, commits left unpushed where a remote exists, or an
  out-of-date plan or task list — where this project keeps one — mean the
  handoff is not done.
- If the context guard fired mid-batch, note in the document exactly which
  finding or task within the batch is the boundary.
