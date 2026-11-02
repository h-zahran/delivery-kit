# Implementation Plan: Pre-flight asks whether git will work here, not only whether it can be found

**Branch**: `049-preflight-git-usable` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/049-preflight-git-usable/spec.md`

## Summary

`pipeline/scripts/preflight.sh` probes git twice with `command -v git`
(`have_git` at the name checks, `git_present` for the report). Both answer
"found", never "works here". The fix collapses the two into ONE classifier,
run once right after the script enters the probed folder, from three exit
codes and no message text:

1. `command -v git` fails → `absent`.
2. `git --version` fails → `broken`.
3. `git rev-parse --git-dir` succeeds → `usable`.
4. `git -c safe.directory='*' rev-parse --git-dir` succeeds → `refused-ownership`.
5. Otherwise → `no-repository`.

The report keeps `capabilities.git` (found) unchanged and adds
`capabilities.gitUsable` (boolean) and `gitReason` (string). Every name
check that uses git gates on usable, so an unusable git behaves exactly as
an absent one does today: names reported unchecked, exit 0, one complete
document. Decision 11 in the skill fires on `gitUsable` false and names the
reason; `docs/rare-paths.md` says what to print for each. Tests build a
real fixture per reason. The same pull request releases pipeline 1.7.3.

## Technical Context

**Language/Version**: bash (3.2 on the macOS runner, 5.x on Linux and Git Bash)

**Primary Dependencies**: git (any version; the ownership check exists from 2.35.2, `safe.directory=*` from 2.36); bats-core 1.11.0; jq

**Storage**: N/A

**Testing**: bats; full suite = `testCommand` (four roots); shellcheck = `analyzeCommand`

**Target Platform**: CI on ubuntu, macOS, Windows runners; local Ubuntu, git 2.53.0

**Project Type**: Claude Code plugin repository (shell scripts + tests + prose)

**Performance Goals**: at most three extra git calls at pre-flight (each a few milliseconds)

**Constraints**: every existing key keeps its value on every existing fixture; no skipped test (CI fails a skip); no new tool on `PROBE_TOOLS`; stdout stays pure JSON; no git configuration is written

**Scale/Scope**: about 15 lines of `preflight.sh`; 5 new tests in `preflight.bats`; prose changes to decision 11, the probe-block line, the read-me-first pointer, two `rare-paths.md` sections and `README.md`; their pins in `prose.bats`; a new contract; a changelog entry and two version bumps

## Constitution Check

| Principle | How this plan meets it | Status |
|---|---|---|
| I. Silence is the failure that matters | The fix ends the silent "git is fine" for a git that refuses the repository. The no-repository reason is worded so it never claims more than was measured. | PASS |
| II. Measure; never assert | The classifier's five exit-code facts were measured on git 2.53.0 before planning (research.md R1). Each mutation and its red test is recorded in `measurements.md` with date and commit. | PASS |
| III. A gate must be shown able to go red | Every new test is run against mutations of the classifier (each branch flipped, `-c safe.directory` dropped, the ownership step removed) and the red is recorded. Each fixture asserts its own precondition first (plain `git rev-parse` really fails), so a git that ignores the fixture's trigger cannot give a vacuous green. | PASS |
| IV. One implementation, many callers | The two `command -v git` probes become one classifier; `have_git` and the report both read it. A test pins that the script holds one `command -v git`. | PASS |
| V. Derive coverage; never enumerate it | The reason-set test derives both sides: the `git_reason=` values the script assigns, and the reasons "The git stop" in `docs/rare-paths.md` gives an instruction for. Every unusable reason must have one, and every named reason must be one the script assigns, so a reason added to one side alone goes red. | PASS |

Post-design re-check: PASS. No violation to justify.

## Project Structure

### Documentation (this feature)

```text
specs/049-preflight-git-usable/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/capabilities.md
├── measurements.md        # written during implementation
├── checklists/requirements.md
└── tasks.md               # /speckit-tasks
```

### Source code (repository root)

```text
pipeline/scripts/preflight.sh            # the classifier; have_git reads it
pipeline/tests/preflight.bats            # one fixture test per reason; the one-probe pin
pipeline/skills/pipeline/SKILL.md        # decision 11, probe-block git line, read-me-first pointer
pipeline/docs/rare-paths.md              # "The git stop", "The probe block without git"
pipeline/README.md                       # the git requirement paragraph
pipeline/tests/prose.bats                # pins and spans for the prose above
specs/013-preflight-git-probe/contracts/capabilities.md   # one pointer line at the top
pipeline/CHANGELOG.md                    # [1.7.3]
pipeline/.claude-plugin/plugin.json      # 1.7.3
.claude-plugin/marketplace.json          # pipeline entry 1.7.3 (sed, never jq)
```

**Structure Decision**: no new file outside the spec folder. The classifier
lives where the probe already lives.

## Pieces

1. **Probe**: classifier in `preflight.sh`, the new keys, the gate on
   `have_git`, and their tests in `preflight.bats`.
2. **Prose**: SKILL.md, rare-paths.md, README.md, their pins in
   `prose.bats`, and the pointer line in 013's contract.
3. **Release**: CHANGELOG, plugin.json, marketplace.json, `check-versions.sh`.

## Complexity Tracking

None.
