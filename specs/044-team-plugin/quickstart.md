# Quickstart: verify the team plugin

## 1. The suites

```bash
bash "$HOME/bats/bin/bats" -r --print-output-on-failure tests handoff/tests pipeline/tests team/tests
bash scripts/check-versions.sh
```

## 2. The positive controls

Each mutation runs in a throw-away copy, with the new files marked intent-to-add. Each is first checked to have landed exactly once. Red means bats exited non-zero and ran at least one test.

| # | File | What is broken | Tests that go red |
|---|---|---|---|
| 1–13 | `team/scripts/team.sh` | each `config` check: team key, unknown key, missing key, non-string, the five path checks, roster `{member}`, member-path `{member}`, no `team` object, invalid JSON | the matching `config:` test |
| 14–19 | `team/scripts/team.sh` | each `roster` check: no list, empty, no name, bad id, duplicate id, `emails` default | the matching `roster:` test |
| 20–29 | `team/scripts/team.sh` | each `tasks` check: member in roster, `{member}` replaced, no list, branch, specDir, seed, trailers, flags, duplicate id, defaults | the matching `tasks:` test |
| 30–35 | `team/skills/setup/SKILL.md` | each pinned rule | team:setup states what it writes, and what it never does |
| 36–39 | `team/docs/configuration.md` | each pinned rule | the configuration page states where the block lives and what is checked |
| 40 | `team/CHANGELOG.md` | the entry's lead | the changelog keeps its entry's lead |
| 41–42 | `.github/workflows/ci.yml`, `CONTRIBUTING.md` | drop `team/tests` | CI and the contributing guide run every suite in the repository |
| 43–45 | `CHANGELOG.md`, `README.md` | drop the index line, the install line, the link | every plugin is indexed and installable from the root documents |
| 46 | `tests/portability.bats` | drop `SHIPPED_TEAM` from `SHIPPED` | every plugin directory owns a non-empty shipped-surface list |
| 47 | `.claude-plugin/marketplace.json` | the entry's version | the version-agreement tests |

## 3. Record

| Date | System | Suite | Mutations |
|---|---|---|---|
| 2026-10-07 | Linux | `1..314`, all `ok` | 47 of 47 landed and went red |

The first round counted 14 mutations green. The cause was in the tests: the case loops read their list on fd 3, which bats uses for its own report, so a failing case printed nothing and bats ran "0 instead of 1" tests. The loops now read on fd 4, and the runner now judges red by bats' exit status, not by finding a `not ok` line. Two more did not land at first: their text crossed a line break. All were rerun.
