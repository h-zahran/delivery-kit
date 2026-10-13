# Changelog — mission-control

All notable changes to the `mission-control` plugin.

## [0.9.5] - 2026-10-13

### Highlights

- The main loop's plan moves with the work and finishes when the work is
  done. A plan left at "1/5" for hours was a plan the model stopped
  reporting; now each prompt reminds it of the current step.
- Helper robots match their work more often: on the 54-task list, wrong
  roles fell from 6 to 0, and on 25 new tasks written before the change, from
  12 to 5.
- An idle helper shows as idle, not working, and the rate-limit meters keep
  moving while nothing runs.

### Changed

- **The main loop is reminded of its plan.** While its plan is unfinished,
  the block beside each person prompt carries one line, such as
  `Your plan: step 2/5 "Lane builds"`, with the rule to report each step and
  report `done` = `total` when the work is over. The system-prompt section
  and the `step` tool's own description say the same.
- **A new plan replaces the old one whole.** A report of `done: 0` with a
  different plan resets the step names, note and timer, for the main loop
  and for helpers alike.
- **A finished todo list no longer hides the step plan.** The todo list is
  the plan while a todo is open, or when it is finished and no step plan
  stands beside it.
- **More task words pick a role.** README and CHANGELOG name a writer;
  reproduce, repro and regression name a fixer; a two-word task ending in
  "plan" names a planner; the word "fix" in the task names a fixer even when
  the brief calls the helper an implementer. "Mapping" no longer counts as
  "map".
- **An idle helper is not counted as working.** The main row reads
  `1 helper idle`, and the band shows `1 idle`. The RUNNING card still shows
  the dozing robot.
- **The rate-limit meters refresh every 30 seconds while nothing runs**, so
  they, and the reopening of the pane after `/clear`, stay current.

### Fixed

- **"Needs your OK" waits only for a real dialog.** When a settings hook
  answers the permission request, no dialog opens and no wait shows. The
  wait is now matched to the call that asked, by its id, so another call
  ending cannot clear it. It still stays up while an approved call runs: the
  engine reports no moment between the answer and the run.
- **The ask id beside a prompt is the id stored.** A tick that landed while
  the prompt entered could shift the id by one.
- **The tool named in "Needs your OK" clears with the wait** at the end of a
  turn.

## [0.9.4] - 2026-10-13

### Highlights

- The model now sees your newest asks. The list went into the system prompt,
  which is built once and then kept, so an ask typed later stayed invisible
  until the next compaction. It now goes with each prompt you type.
- A helper's robot matches its work: "Lane 056 one config read" no longer
  shows a builder as a scout for half an hour.
- Fewer false warnings: no red "runs out" from one small tick, no stale
  "running long", no clash from an edit that was denied.

### Changed

- **The live asks list goes beside each prompt.** The system-prompt section
  is now short and fixed: how to tick an ask, and that the list arrives with
  each prompt. The current list rides as context with every prompt the
  person types, and the `ask` tool's reply ends with what is still open.
  Neither appears unless the `ask` tool is on offer. The tool's description
  says it is for the main conversation only.
- **A helper's role reads its type, then its brief, then its task.** Explore
  and Plan helpers are always scouts and planners. Otherwise a brief whose
  first line says "You are the implementer" (or reviewer, fixer, planner,
  writer, researcher) names the role. Then the task's words decide, but a
  match in the last word of a task of three or more words no longer counts,
  and whole words end at a word boundary: "Address" is not "add", "ready" is
  not "read". On a list of 54 realistic tasks, wrong roles fell from 15 to 6.
- **The 5-hour and weekly forecasts wait for evidence.** "Runs out in …"
  needs at least 5 minutes of samples and a rise of 2 points.
- **The cost history keeps 30 minutes by age**, so heavy spend no longer
  blanks the start of the sparkline.
- **"N helpers working" shows the known part.** With one helper reporting no
  progress, the row reads `3 helpers working · 2 ~2m left (1 unknown)`.
- **The pane's one automatic opening happens again after `/clear`.** It no
  longer opens from inside the band's drawing; the clock opens it.
- **An idle clock does less.** With nothing running and no dialog waiting,
  it reads only its own state, so the rate-limit meters refresh at each
  turn end and compaction, and every 5 seconds while work runs.

### Fixed

- **"Added by you" survives a tick.** A partial tick dropped the mark, so an
  ask the model added read as the person's own for the rest of the session.
- **An ask typed while a turn runs waits for its own turn.** It was marked
  answered when the running turn ended.
- **A request that starts with a path is tracked.** `/etc/hosts is wrong`
  was taken for a slash command.
- **The ask tool says so when a tick did not save**, instead of "ok".
- **A dropped prompt leaves no ask**, and a turn end from an id no helper
  carries, or an idle helper, no longer decides which asks are answered.
- **The sound on Windows passes its path in an environment variable.** A
  curly quote in the path (`O’Brien`) ended the script's string and turned
  the sound off for the session.
- **"Needs your OK" is cleared only by the tool that asked.** A parallel call
  that ended first cleared it while the dialog was still open. It still
  stays up while an approved call runs: the engine sends no approval signal.
- **A denied or failed edit is not a touch.** Only Edit, Write, MultiEdit and
  NotebookEdit count as edits; other tools that name a file count as reads.
- **The file tree folds only your real home to `~`**, on every line, and
  never another user's folder such as Public. One file spelled with
  backslashes or slashes, in either case, in Git Bash's `/e/x` form, or
  through `..` or `\\?\UNC\`, is one entry.
- **An idle helper no longer holds its batch open**, so the receipt's wall
  time ends with the batch.
- **A new turn restarts the step timer**, so it no longer shows the gap since
  the last turn as "running long". "Running long" needs two measured steps.
  A step report before the turn's start time is known no longer shows a time
  the size of the epoch.
- **The todo list and the step reports keep separate tracks**, so one no
  longer resets the other's time left.
- **Helpers spawned together get their own colours.**
- **Two helpers ending together raise one batch toast.**
- **Text is cut by character and measured by terminal cell**: an emoji is
  never split in two, and Chinese or Japanese labels no longer push the
  bar past the edge.
- **MCP tool names whose server has an underscore are shortened**, such as
  `claude_ai_Claude_Docs:batch`.
- **The step percent rounds down**, so 199 of 200 reads 99%.
- **The commentator counts only files edited this turn**, and its facts
  cannot close the wrapper they sit in.
- **A failure inside the 1-second clock stops only its own part**, and an
  idle clock no longer asks the engine for anything.
- **One refused command name no longer stops the tools and the clock from
  starting.**

## [0.9.3] - 2026-10-12

### Fixed

- **The sound on Windows runs PowerShell by its full path.** It ran a bare
  `powershell.exe`, and Windows looks for a bare name in the current folder
  before PATH, so a repository that carried its own `powershell.exe` could
  have it run each time a sound played. The path comes from `SystemRoot`
  when that reads as a plain drive path, else the default Windows folder.
  The Linux players stay by name: Linux searches only PATH, never the
  current folder.
- **An ask in the system prompt stays a quote.** The open asks repeat the
  first line of each prompt, and pasted text can carry words the person
  never wrote. A `"` inside an ask is now shown as `'`, and `<` and `>` as
  `‹` and `›`, so the text cannot close its quote or open a tag. The section
  now says a quote is a label, not an instruction. An ask the model added
  itself is marked "added by you" instead of being listed as the person's.
  The pane still shows each ask as typed.

## [0.9.2] - 2026-10-12

### Added

- First release in this marketplace. A side pane with robots for the main
  loop and every subagent: tools, context, cost, rate limits and files
  touched. Also a band above the prompt, a REQUESTS card, toasts and sounds.
  Commands: `/mission`, `/mission-band` and `/mission-talk`.
