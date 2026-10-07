# Changelog — team

All notable changes to the `team` plugin.

## [0.1.0] - 2026-10-07

### Added

- **The `team` plugin, with `team:setup`.** A team that runs a shared plan
  through `pipeline` writes its setup once: `team:setup` adds a `team`
  block to the repository's `.delivery-kit.json`. The block holds paths
  only: for each team, its roster file, and each member's task file and
  progress file, with `{member}` standing for the member's id. The plugin
  holds no team names and builds no branch or folder names: the project
  writes each task's branch, spec folder, seed, trailers and extra flags
  into the task file, and the plugin passes them on.
- **`scripts/team.sh`**, which reads and checks the team block, a roster
  and a task file, and names the first fault it finds. It checks shape
  only. The pipeline's pre-flight checks what a branch name, a spec
  folder or a trailer means, so those rules stay in one place.
