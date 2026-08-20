---
name: status
description: Read a pipeline run's state file and report the phase board, the gate it is waiting on, and the exact next action. Use when someone asks where a pipeline run stands, which phase it is in, or what to do next.
---

# pipeline:status

Read-only. This skill never edits the working tree, never takes the lock
and never advances a phase — it reports.

1. Find the state files: `.delivery-kit/runs/*/progress.json`. None means
   no run has ever started in this repository — say so and stop.
2. For each run (usually one), read it through the plugin's own mechanics
   rather than a raw file read:
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/progress.sh" read <feature>`.
   A validation error is the answer, not an obstacle: report the named
   fault it prints.
3. Render the phase board: every phase in order — preflight, A, B, C, C.5,
   D, E, F, F.5, G, H, H.5, H.7, I, J, K, L, M, N, N.5, O — marked done,
   current or pending from `completed_phases` and `current_phase`.
4. Name what the run is waiting on: if `current_phase` is a gate phase (C,
   G, K, L, O) and `gates` records no answer for it, the run is parked at
   that gate — say which one, and what answering it takes.
5. End with the exact next action, copy-pastable: the resume invocation
   (`/pipeline --resume`) for a live run; nothing for a state file whose
   phase is DONE.
