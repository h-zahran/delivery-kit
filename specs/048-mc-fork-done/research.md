# Research: A forked skill's robot moves to DONE when its work is over

## R1. What the engine reports

The 2.1.316 types (`AgentStatus`): `pending` (not started), `running` a turn,
`waiting` (held: on background work it owns, a plan's approval, an Agent
call), `idle` (between turns, until a message wakes it), or ended:
`completed`, `failed`, `killed` — "a message may yet resume one, under the
same id". `$.agent.list()` names a forked skill (no `agent.spawn`); the pane
showed returned `/code-review` forks as "resting…", which only `idle` produces.

## R2. The path that goes wrong (read in `register.tsx` at `f569e9f`)

1. The fork's end fires `turn.complete` with its `agentId`; the hook sets the
   run `done` with `endedAt`.
2. `reconcile()` runs every 5 s while something is live or recently done.
   `isRecentDone` holds from 5 s to 30 min after the end, and `isRevived`
   treats a listed `running`, `idle`, `waiting` or `pending` as a revival: the
   run is set back to `running`.
3. On the next pass the listed `idle` differs from `running`; `mapStatus('idle')`
   is `idle`; the pane draws it under RUNNING with "resting…".

Where `turn.complete` was not seen, step 2 is skipped and step 3 alone leaves it
idle.

## R3. The fix

- **Decision**: store `forked?: boolean` on `AgentRun`, set by `addRun` when the
  run joined from the list (`isJoin`). A single function decides the status a
  listed value means for a run: for a forked run, `idle` means `done`; all other
  values as `mapStatus` today. `isRevived` does not count `idle` for a forked
  run. `reconcile` uses the same function in its change check and its write,
  and gives a run it ends this way an `endedAt` and settled tools, as it does
  for any end.
- **Rationale**: the fork's task is over when it goes idle; a teammate or a
  waiting subagent will work again by itself, so its idle stays live. A stored
  flag survives a reload (`$.state` stays across reloads; module variables do
  not), so FR-005 holds; a run an older version stored has no flag and keeps
  today's behaviour.
- **Alternatives considered**: treating every idle helper as done (hides
  teammates and helpers waiting on background jobs — rejected by FR-003); a
  module-level set of forked ids (lost on reload); a timeout on idle (guesses).

## R4. Batch end, counts, band

They read `status`. A fork that ends in `reconcile` rather than in
`turn.complete` must raise the same batch-end toast and sound if it was the last
running helper; the plan checks whether `reconcile` does that today for a
listed `completed`, and does the same for a fork's idle (or records that it
does not, as today).

## R5. The release

`mission-control/.claude-plugin/plugin.json` and the mission-control entry in
`.claude-plugin/marketplace.json` (edited with `sed`) to `0.9.7`; the changelog's
`## [Unreleased]` becomes `## [0.9.7] - <date>`; `bash scripts/check-versions.sh`
agrees. After the merge the tag `mission-control-v0.9.7` goes on the commit on
`origin/main` that holds the whole fix (the tip, if review fixes land after the
release commit — as run 2 found), and CI's tag step must read `success`.
