# Contributing

Keeping private notes in your clone? Read [Maintainers](#maintainers) before
your first `git add`.

## Trying a change in Claude Code

Load your working copy for one session, without installing it. From the
repository root:

```
claude --plugin-dir ./handoff --plugin-dir ./pipeline
```

`--plugin-dir` loads a plugin from a directory for that session only. It
replaces an installed plugin of the same name for that session, so you do
not need to uninstall or disable yours. After an edit, run `/reload-plugins`
in the session to load the change. Check the manifests before you open a
pull request:

```
claude plugin validate .
claude plugin validate ./handoff
claude plugin validate ./pipeline
```

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

A feature quickstart that has to prove the suite passed saves the run's
output and calls `bash scripts/check-suite.sh <expected> <tap-file>` rather
than writing its own check. The script compares the plan line with the `ok`
count and refuses a skipped test, a `not ok` and any stray line, each by
name. Hand-written copies of that check drifted apart — some counted skips
and some did not — which is why quickstarts now share one: the script hands
the file to `pipeline/scripts/progress.sh tap-check`, the rules the
pipeline's own suite records are judged by. (CI's shard step reads its own
TAP with checks of its own.)

A quickstart run inside a pipeline run need not run the suite again when
`bash pipeline/scripts/progress.sh suite-lookup <feature>` exits 0 and its
second line starts `1..<expected>,`: the run's test command already passed on
these exact files — and, under the default `suiteReuse` of `commit`, on the
same commit and index. Quote both lines in place of the check. The quickstart
records nothing itself — a record names the run's test command, and only a
run of that command, bracketed by `suite-key` and `suite-record`, may stand
for it.

Expect all tests to pass on Linux, macOS, and Windows under Git Bash. CI runs
all three; a change that passes on only one is not finished.

### bash 3.2 without a Mac

macOS runs the suites under its own bash 3.2: no `mapfile`, no `${var,,}`, no
`declare -A`. A change can pass on Linux and Windows and go red only there. A
container gives you that bash. Run this from the root of a clone, not a linked
worktree: a worktree's `.git` file points outside the container, and git in it
cannot follow.

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W 2>/dev/null || pwd):/repo" -w /repo bash:3.2 bash -c '
  apk add --no-cache -q git jq coreutils grep sed gawk findutils diffutils &&
  ln -s /usr/local/bin/bash /bin/bash &&
  git config --global --add safe.directory "*" &&
  git -c advice.detachedHead=false clone -q --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core.git /opt/bats &&
  bash --version | head -n 1 &&
  bash /opt/bats/bin/bats -r --print-output-on-failure "$@"' _ tests handoff/tests pipeline/tests
```

Name fewer suites at the end to run part of it. The image keeps its bash in
`/usr/local/bin`, so the link gives a `#!/bin/bash` script the same 3.2 that
macOS does. `MSYS_NO_PATHCONV=1` and `pwd -W` are for Git Bash on Windows;
elsewhere they change nothing.

It catches bash 3.2 faults. It does not catch BSD-tool faults: the container's
tools are GNU, or busybox where none is installed, not macOS's BSD `sed`,
`grep` and `awk`, so those still show only on CI's macOS shard.

Two reds come from the container, not from your change; both also fail on a
tree CI passes. `a constitution saved in an unreadable encoding warns and
reads as not set` in `pipeline/tests/preflight.bats` fails every run. The
branch-name tests there that check letter case, `feature branch: a name that
exists here or on origin, in any letter case, ...` and `spec folder: without
--feature-branch, ...`, fail about one run in three when the repository is
mounted from a Windows folder, likely because that folder ignores letter
case.

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
appears anywhere a user reads or installs. The vocabulary is names from the
project the plugins were extracted from: none of them may appear in a shipped
file, so the plugins stay usable by anyone. That surface spans a tree per
plugin plus the repository root, and which tree a file belongs in is the
first thing to get right when you add one:

- The `handoff` plugin's surface lives under `handoff/` — `handoff/hooks/`,
  `handoff/scripts/`, `handoff/skills/`, `handoff/README.md`, `handoff/CHANGELOG.md`,
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
  `tests/gate.bats` and the `version` job in
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
- **The analyser version that governs is CI's, not yours.** The job installs a
  pinned shellcheck release (`SHELLCHECK_VERSION` in that job, currently
  v0.11.0), verifies its checksum, and refuses to analyse under any other
  version. It used to take whatever the runner image carried. Measured: the
  image shipped an older release than a developer machine had, and the older
  one reported a check the newer one does not have at all, so a local green
  did not imply a green gate. Install the pinned release locally before
  concluding anything from a local run. Then run what the job runs, from the
  repository root, in bash 4.4 or later (`mapfile -d` needs it, and macOS's
  own bash 3.2 has no `mapfile` at all):

  ```bash
  mapfile -d '' files < <(git ls-files -z -- '*.sh' '*.bash' ':(exclude).specify/')
  shellcheck --norc -f gcc -- "${files[@]}"
  ```

  `tests/readme.bats` holds these two lines equal to the job's, so they move
  together.
- **CI pins its other tools too.** CI pins jq 1.8.2 and verifies its
  checksum; use the same release locally. CI pins actionlint 1.7.12, which
  lints the workflow file and runs the shell in its inline `run:` steps
  through the pinned shellcheck. CI runs one suite root per shard, but a
  local run still names every suite path, as
  [Running the tests](#running-the-tests) says.
- Release tags are `<plugin>-v<version>`, for example `handoff-v2.0.0`. A bare
  `v1.2.3` names no manifest to check against, so CI rejects it.
- **A release follows one order.** `scripts/release.sh` makes the edits; it
  never commits, tags or pushes.
  1. On a branch from `main`, with a clean tree, run
     `bash scripts/release.sh <plugin> <version>` from the repository root.
     It refuses unless the plugin is in the marketplace and the version is
     `MAJOR.MINOR.PATCH` and higher than the current one. It sets the version
     in `.claude-plugin/marketplace.json` and in
     `<plugin>/.claude-plugin/plugin.json`, turns the plugin's one
     `## [Unreleased]` heading into `## [<version>] - <today>`, and runs
     `scripts/check-versions.sh --released <plugin>`. If that gate refuses,
     the three files are put back as they were.
  2. Read `git diff`, then commit the three files the script names. To
     release both plugins, commit the first before running it for the
     second: it refuses a tree that is not clean.
  3. Push the branch, open a pull request, and merge it once CI is green.
  4. Run `git fetch origin` and check that `origin/main` is the release
     commit: a rebase merge gives it a new id. Tag that commit,
     `git tag <plugin>-v<version> origin/main`, and push the tag.
  5. In the tag's CI run, open the `version agreement` job and read the step
     "tag matches the manifest version". It must say success. It is skipped
     on every other run, so the job's green alone proves nothing.

  CI never runs the script; `tests/release.bats` runs it on a copy of the
  release files.

  Each release section opens with a `### Highlights` subsection: two or three
  short lines saying what a user gets, written under `## [Unreleased]` before
  step 1. A level-3 heading is invisible to the gate, and sections released
  before this rule keep the shape they shipped with.

## Maintainers

### After cloning

The maintainer keeps a private archive in `docs/` inside the clone. If you
keep private notes in yours, do this before your first `git add`:

```
git clone <url> delivery-kit && cd delivery-kit
printf '%s\n' '/.claude/' '/docs/' '/.delivery-kit/' >> .git/info/exclude
git check-ignore -v docs/ .claude/ .delivery-kit/
git check-ignore -v pipeline/docs/ handoff/docs/ || echo 'correct: plugin docs are NOT ignored'
```

**The third command must name `.git/info/exclude` for all three paths.** If it
prints nothing, or names `.gitignore` instead, the lines did not land and you
should not trust the tree yet.

**The fourth command must print that line.** If it names an exclude rule
instead, the patterns are not anchored and both plugins' shipped `docs/`
directories are being ignored.

**The leading slashes are load bearing.** A pattern without one matches a
directory of that name at *any* depth, so a bare `docs/` silently ignores
`pipeline/docs/` and `handoff/docs/` — two published surfaces — as well as the
private archive it was aimed at. Measured on 2026-09-03: a new page added under
`pipeline/docs/` was skipped by `git add -A` with no message at all, and the
only symptom was a link to it failing to resolve. A leading slash anchors the
pattern to the repository root, which is the only place these three exist.

A fresh clone carries `.gitignore`, which is tracked and published. It does
**not** carry `.git/info/exclude`, which is per-clone and travels with nobody.
Until those lines exist, `docs/` is ignored by nothing at all — in a public
repository — and a single `git add -A` from any tool or session publishes
whatever is in it. That is a measured near-miss, recorded in the exclude file
itself on 2026-08-25.

These three are named here on purpose and the private tool directories are not:
`docs/`, `.claude/` and `.delivery-kit/` are generic directory names, so writing
them in a published file discloses nothing. The patterns live in
`.git/info/exclude` rather than in `.gitignore` precisely because some of the
things listed there would disclose a private toolchain by name, and this
instruction does not defeat that.

One caveat worth knowing: an exclude pattern never applies to a path that is
already tracked. These lines stop new files appearing; they do nothing about
anything already in the index.

## Scope

The marketplace ships the context guard and handoff workflow, and the
pipeline that drives one unit of work from specification through release,
for Claude Code. Proposals that add another harness, or automation beyond
what the pipeline's phases already run, are not rejected on merit — they
are sequenced later. Open an issue before building one.
