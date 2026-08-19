# Contributing

## Running the tests

The suites are [bats](https://github.com/bats-core/bats-core) and need `jq`.

```bash
git clone --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core.git "$HOME/bats"
bash "$HOME/bats/bin/bats" -r tests handoff/tests
```

Name both paths. The suites sit in two directories now, and passing only
`tests` runs the repository's own suite, silently skips the plugin's, and
reports green — which is the failure this project exists to prevent, arriving
by way of its own contributing guide.

Expect all tests to pass on Linux, macOS, and Windows under Git Bash. CI runs
all three; a change that passes on only one is not finished.

## What the tests protect

`handoff/tests/context-guard.bats` covers the hook's behaviour. Two cases are
load bearing beyond their size:

- **One inflated entry among five** encodes a production incident from
  2026-08-07 in which a last-reading implementation fired the guard at 45% while
  the session was at 24%. Do not "simplify" the median away.
- **A malformed transcript line** encodes the reason the transcript is parsed
  per line rather than slurped: `jq -s` aborts the whole parse on one torn line
  and leaves the guard silently disabled.

`tests/portability.bats` fails the build if project-specific vocabulary, an
absolute local path, or the name of a tool this project does not depend on
appears anywhere a user reads or installs. That surface spans two trees, and
which tree a file belongs in is the first thing to get right when you add one:

- The plugin's surface lives under `handoff/` — `handoff/hooks/`,
  `handoff/skills/`, `handoff/README.md`, `handoff/CHANGELOG.md`,
  `handoff/docs/` and `handoff/.claude-plugin/`. This is what a user installs.
- The repository's own surface stays at the root — `README.md`, this file,
  `CHANGELOG.md`, `CODE_OF_CONDUCT.md`, `LICENSE`, `.claude-plugin/`,
  `.gitignore`, `.gitattributes` and `.github/`. This is what a user reads
  before deciding to install anything. The root `CHANGELOG.md` is an index
  pointing at each plugin's changelog, not a release history of its own.

Three variables in that file hold the exact lists: `SHIPPED_HANDOFF` for the
first, `SHIPPED_ROOT` for the second, and `SHIPPED` as their union, which is
what the scans walk. Register a new document in whichever of the first two
owns the tree it lives in — not in `SHIPPED`, which is only the union and gets
rewritten whenever a tree is added, so an entry parked there is one refactor
from being dropped. An unregistered file is an unscanned one.

This plugin was extracted from a specific codebase, and re-importing that
codebase's vocabulary one pull request at a time is the most likely way it
becomes unusable for everyone else.

## Conventions

- Conventional commit messages: `feat:`, `fix:`, `test:`, `docs:`, `chore:`, `ci:`.
- LF line endings, enforced by `.gitattributes`. A `.sh` file with CRLF does not
  execute under Git Bash.
- New hook behaviour arrives test-first.
- Each plugin keeps its own `CHANGELOG.md`; the root one is only an index. A
  plugin's `.claude-plugin/plugin.json` version, the version of the marketplace
  entry whose `name` matches that manifest, and the newest heading in that
  plugin's own changelog must agree. Both gates — the version test in
  `tests/portability.bats` and the `version` job in `.github/workflows/ci.yml` —
  loop over every top-level directory holding a `.claude-plugin/plugin.json` and
  pick the marketplace entry by name rather than by position, so a plugin added
  later is covered without either gate being edited, and neither can be fooled
  by a reordered array. Both loops are `for dir in */`, so a plugin nested
  deeper than the root is not covered by either — keep plugin directories at
  the top level. One shared changelog would have made "the newest heading" a
  question about which plugin released last.
- Changelog headings are `## [X.Y.Z] - YYYY-MM-DD`. Both gates parse that shape,
  date included.
- Release tags are `<plugin>-v<version>`, for example `handoff-v2.0.0`. A bare
  `v1.2.3` names no manifest to check against, so CI rejects it.

## Scope

v1 is the context guard and the handoff skill, for Claude Code. Proposals that
add a pipeline orchestrator, shipping automation, or another harness are not
rejected on merit — they are sequenced later. Open an issue before building one.
