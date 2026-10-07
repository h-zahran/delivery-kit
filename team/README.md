# team

Runs a team's plan through the `pipeline` plugin. The team leader writes the
setup once. Each member then starts their next task with one command, and the
team's progress is kept where the team leader can read it.

This version holds `team:setup` and the file formats. Starting a task and
reporting progress come in the next versions.

## What you need

- The `pipeline` plugin, installed in the same Claude Code.
- `jq` on your `PATH`.
- Three kinds of file in your repository, which your project writes: a roster
  for each team, and a task file for each member. See
  [the configuration page](docs/configuration.md) for their formats.

## Set up a team

Run `team:setup` in the repository. It asks, one question at a time:

1. the team's key, a short name such as `alpha`;
2. where the team's roster file is;
3. where each member's task file is, with `{member}` for the member's id;
4. where each member's progress file goes, with `{member}` again;
5. optionally, where a readable copy of the progress goes.

It writes the answers into the `team` block of the repository's
`.delivery-kit.json`, keeps every other key, checks the result, and shows you
the change. It never commits. Commit the file yourself, so the whole team
shares one setup.

## Why the plugin builds no names

Every team names its branches and folders its own way. The plugin does not
guess. Your project writes each task's branch, spec folder, seed text,
commit trailers and extra pipeline flags into the task file. The plugin
reads them and passes them to `pipeline` as they are. The pipeline's
pre-flight checks each one.
