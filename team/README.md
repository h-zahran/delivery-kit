# team

Runs a team's plan through the `pipeline` plugin. The team leader writes the
setup once. Each member then starts their next task with one command, and the
team's progress is kept where the team leader can read it.

| Skill | Who runs it | What it does |
|---|---|---|
| `team:setup` | the team leader, once | Writes the team block in the repository's `.delivery-kit.json`. |
| `team:start` | each member, for each task | Finds the member's next task and prints the `/pipeline` line to paste. |
| `team:status` | anyone | Shows where each task stands, read from git and the pull requests. Writes the progress page when asked. |

## What you need

- The `pipeline` plugin, installed in the same Claude Code.
- `jq` on your `PATH`.
- Two kinds of file in your repository, which your project writes: a roster
  for each team, and a task file for each member. See
  [the configuration page](docs/configuration.md) for their formats.
- `gh`, signed in, for `team:status` to see pull requests. Without it, a
  merged task never shows as done, and the output says so.

## Set up a team

Run `team:setup` in the repository. It asks, one question at a time:

1. the team's key, a short name such as `alpha`;
2. where the team's roster file is;
3. where each member's task file is, with `{member}` for the member's id;
4. optionally, where each member's readable progress page goes, with
   `{member}` again.

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

## Start a task

Run `team:start`. The first time, it asks for your team and your id, and
suggests the id that matches your git email. It never decides that for
you. Then it checks the working tree is clean, finds your next task, and
prints one line:

```
/pipeline "<the task's seed>" --branch <branch> --spec-dir <folder> --trailer "<trailer>" <flags>
```

Paste it. The skill never starts the pipeline itself: the pipeline
commits and pushes, so a person types it. When a task of yours is already
in progress on this machine, it prints `/pipeline --resume` instead.

## See where the work stands

Run `team:status`. Status is read from git and the pull requests each
time, never stored, so it cannot drift from what is really there. Ask it
to update the progress page, and it writes each member's page for you to
commit.
