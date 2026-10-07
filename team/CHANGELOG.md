# Changelog — team

All notable changes to the `team` plugin.

## [0.1.0] - 2026-10-07

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
  once who they are and keeps the answer in `.delivery-kit/team.json`,
  which git must ignore; the git email only suggests it. It checks the
  tree is clean, finds the next task, and prints the `/pipeline` line
  with the task's seed, branch, spec folder, trailers and flags. It never
  starts the pipeline itself, and never stashes, checks out or pulls.
- **`team:status`: status read, never stored.** Each task's status comes
  from its pull request, the pipeline's run on this machine, a `blocked`
  note, or its branch here or on `origin`, in that order, and the output
  says which source answered and which could not be read. On request it
  writes each member's progress page from that status.
