# Contributing

## Running the tests

The suites are [bats](https://github.com/bats-core/bats-core) and need `jq`.

```bash
git clone --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core.git "$HOME/bats"
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests
```

The tag above is the readable one, and it is deliberately NOT the commit
the workflow pins. CI fetches an immutable commit, because an upstream
retag would otherwise change the third-party code an automated gate
executes and reports on. A local clone is your own machine and your own
eyes, so it keeps the readable reference. Carrying the commit here too
would create exactly the hand-maintained pair the version check just had
removed; the pin lives in one place, `.github/workflows/ci.yml`, with the
release name beside it.

Name every suite path. The suites sit in more than one directory, and
passing only `tests` runs the repository's own suite, silently skips the
plugins', and reports green — which is the failure this project exists to
prevent, arriving by way of its own contributing guide.

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
appears anywhere a user reads or installs. That surface spans a tree per
plugin plus the repository root, and which tree a file belongs in is the
first thing to get right when you add one:

- The `handoff` plugin's surface lives under `handoff/` — `handoff/hooks/`,
  `handoff/skills/`, `handoff/README.md`, `handoff/CHANGELOG.md`,
  `handoff/docs/`, `handoff/tests/` and `handoff/.claude-plugin/`. This is
  what a user installs.
- The `pipeline` plugin's read-or-install surface lives under `pipeline/` —
  `pipeline/README.md`, `pipeline/CHANGELOG.md`, `pipeline/commands/`,
  `pipeline/docs/` and `pipeline/.claude-plugin/`. Its executable tree —
  `pipeline/skills/`, `pipeline/scripts/` and `pipeline/tests/` — is
  scanned too, under the relaxed vocabulary `tests/portability.bats`
  describes: a detector, and a suite that asserts a detector's output, must
  be allowed to write the strings they detect.
- The repository's own surface stays at the root — `README.md`, this file,
  `CHANGELOG.md`, `CODE_OF_CONDUCT.md`, `LICENSE`, `.claude-plugin/`,
  `.gitignore`, `.gitattributes` and `.github/`. This is what a user reads
  before deciding to install anything. The root `CHANGELOG.md` is an index
  pointing at each plugin's changelog, not a release history of its own.

One variable per plugin tree in that file holds the exact list —
`SHIPPED_HANDOFF`, `SHIPPED_PIPELINE` — with `SHIPPED_ROOT` for the
repository's own surface and `SHIPPED` as their union, which is what the
strict scans walk. Register a new document in whichever list owns the tree it
lives in — not in `SHIPPED`, which is only the union and gets rewritten
whenever a tree is added, so an entry parked there is one refactor from being
dropped. An unregistered file is an unscanned one.

Fixture trees under a plugin's `tests/fixtures/` are re-included through
the tracked `.gitignore` and scanned by the relaxed test like the rest
of the suite — and that re-inclusion is total, so a fixture must never
grow a dependency tree or anything else an ignore rule would normally
catch. When a prose file ships outside a skills directory, it joins the
link test's list in the same commit; skills need no list edit — their
`SKILL.md` files are discovered by glob.

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
  plugin's own changelog must agree. That check lives in exactly ONE place —
  `scripts/check-versions.sh` — and both gates call it: the version test in
  `tests/portability.bats` and the `version` job in
  `.github/workflows/ci.yml`. It used to live in both of them, kept in step by
  hand, and it drifted — an unanchored regex in one accepted a changelog
  heading the other refused, and nothing noticed until a release. A separate
  test now pins that the two callers name one script AND that neither has
  regrown a copy beside the call, so the pair cannot come back quietly.
  The check loops over every top-level directory holding a
  `.claude-plugin/plugin.json` and picks the marketplace entry by name rather
  than by position, so a plugin added later is covered without any gate being
  edited, and it cannot be fooled by a reordered array. The loop is
  `for dir in */`, so a plugin nested deeper than the root is not covered —
  keep plugin directories at the top level. One shared changelog would have
  made "the newest heading" a question about which plugin released last.
- Changelog headings are `## [X.Y.Z] - YYYY-MM-DD`. The shared check parses
  that shape, date included, anchored at both ends.
- Shell files are statically analysed on every pull request by the
  `shell-analysis` job in `.github/workflows/ci.yml`. The job discovers what it
  reads rather than carrying a list, so a shell file you add is analysed the
  day it lands. What is excluded, and why, is written into the job itself —
  read it there rather than looking for a second copy here.
- Release tags are `<plugin>-v<version>`, for example `handoff-v2.0.0`. A bare
  `v1.2.3` names no manifest to check against, so CI rejects it.

## Scope

The marketplace ships the context guard and handoff workflow, and the
pipeline that drives one unit of work from specification through release,
for Claude Code. Proposals that add another harness, or automation beyond
what the pipeline's phases already run, are not rejected on merit — they
are sequenced later. Open an issue before building one.
