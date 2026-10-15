# Changelog — team

All notable changes to the `team` plugin.

## [0.1.0] - 2026-10-12

### Highlights

- A team leader writes the team's setup once, with `team:setup`.
- Each member runs `team:start` and gets the next task's `/pipeline` line,
  in each of their teams.
- `team:status` shows where every task stands, read from git and the pull
  requests.

### Added

- **The `team` plugin, with `team:setup`.** A team that runs a shared plan
  through `pipeline` writes its setup once: `team:setup` adds a `team`
  block to the repository's `.delivery-kit.json`. The block holds paths
  only: for each team, its roster file, each member's task file, and
  optionally each member's progress page, with `{member}` standing for
  the member's id. The plugin
  holds no team names and builds no branch or folder names: the project
  writes each task's branch, spec folder, seed, trailers and extra flags
  into the task file, and the plugin passes them on.
- **`scripts/team.sh`**, which reads and checks the team block, a roster
  and a task file, and names the first fault it finds. It checks shape
  only. The pipeline's pre-flight checks what a branch name, a spec
  folder or a trailer means, so those rules stay in one place.
- **`team:start`: the next task, ready to paste.** It asks each member
  once per team who they are and keeps the answers in
  `.delivery-kit/team.json`, one per team, which git must ignore; the git
  email only suggests them. A member in two teams sees each team's next
  task and picks one, or names it: `team:start <team>`. It checks the
  tree is clean, finds the next task, and prints the `/pipeline` line
  with the task's seed, branch, spec folder, trailers and flags. It never
  starts the pipeline itself, and never stashes, checks out or pulls.
- **`team:status`: status read, never stored.** Each task's status comes
  from its pull request, the pipeline's run on this machine, a `blocked`
  note, or its branch here or on `origin`, in that order, and the output
  says which source answered and which could not be read. A run the
  pipeline abandoned reads as `abandoned`, and a run at `DONE` with no
  pull request as `finished`, by the pipeline's own rule; `team:start`
  passes over both. A run whose state file cannot be read reads as
  `unreadable`, by the rule of the pipeline's pre-flight, and is named
  so the member repairs or removes it; it is never resumed. A run still
  live on this machine is resumed first, even after its pull request
  opened. The facts are read once, into files, and every task is built
  in one jq program, so a long task list neither hangs Git Bash nor
  takes minutes; `team:start` reads origin and the pull requests once
  for all teams, and `git ls-remote` gives up on an origin that does
  not answer. On request, `team:status` writes each member's progress
  page from that status.
