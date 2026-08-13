# Contributing

## Running the tests

The suites are [bats](https://github.com/bats-core/bats-core) and need `jq`.

```bash
git clone --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core.git "$HOME/bats"
bash "$HOME/bats/bin/bats" tests
```

Expect all tests to pass on Linux, macOS, and Windows under Git Bash. CI runs
all three; a change that passes on only one is not finished.

## What the tests protect

`tests/context-guard.bats` covers the hook's behaviour. Two cases are load
bearing beyond their size:

- **One inflated entry among five** encodes a production incident from
  2026-08-07 in which a last-reading implementation fired the guard at 45% while
  the session was at 24%. Do not "simplify" the median away.
- **A malformed transcript line** encodes the reason the transcript is parsed
  per line rather than slurped: `jq -s` aborts the whole parse on one torn line
  and leaves the guard silently disabled.

`tests/portability.bats` fails the build if project-specific vocabulary, an
absolute local path, or the name of a tool this project does not depend on
appears anywhere a user reads or installs — `hooks/`, `skills/`, the three
`docs/*.md`, this file, `CHANGELOG.md`, `README.md` and `.claude-plugin/`. The
exact list is the `SHIPPED` variable in that file; add to it when you add a
document, because an unregistered file is an unscanned one.

This plugin was extracted from a specific codebase, and re-importing that
codebase's vocabulary one pull request at a time is the most likely way it
becomes unusable for everyone else.

## Conventions

- Conventional commit messages: `feat:`, `fix:`, `test:`, `docs:`, `chore:`, `ci:`.
- LF line endings, enforced by `.gitattributes`. A `.sh` file with CRLF does not
  execute under Git Bash.
- New hook behaviour arrives test-first.
- `.claude-plugin/plugin.json`, the marketplace entry's version, and the newest
  `CHANGELOG.md` heading must agree. CI checks this.

## Scope

v1 is the context guard and the handoff skill, for Claude Code. Proposals that
add a pipeline orchestrator, shipping automation, or another harness are not
rejected on merit — they are sequenced later. Open an issue before building one.
