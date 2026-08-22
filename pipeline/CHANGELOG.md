# Changelog — pipeline

All notable changes to the `pipeline` plugin.

## [1.0.1] - 2026-08-22

### Fixed

- Phase O now says what the release gate does when `releaseCommand` is
  unset: record that there is nothing to publish, and move on.
- The N.5 runtime check now covers verification done beyond the
  configured strategy, and how to report it.
- The G implementer gate now covers the handoff package left behind
  when the gate's answer changes.
- The ground rules gain a bullet on tools the machine lacks.
- The README's example invocations use the canonical
  `/pipeline:pipeline` spelling; the short form `/pipeline` resolves to
  the same command.
- Gate descriptions now say "up to five stops": a gate with nothing to
  ask records that and moves on, and the missing-tool rule separates
  tools that stop the run from capabilities that merely degrade a
  phase.

## [1.0.0] - 2026-08-20

### Added

- The scaffold: plugin manifest, marketplace entry, and this changelog.
- State and lock mechanics (`scripts/progress.sh`), with its test suite:
  the run state file under `.delivery-kit/`, the phase alphabet and the
  validation that guards it, and a repository-wide lock. Pure JSON on
  stdout, every diagnostic on stderr.
- Pre-flight detection (`scripts/preflight.sh`), with its test suite:
  project type, base branch, working-tree state, and the capability probe
  that degrades a named phase rather than crashing one. It reports; the
  decisions stay with the skill that reads it. The suite runs against
  fixture repositories covering each project shape it recognises and the
  case where the tooling it drives is absent.
- The `/pipeline` command and the orchestrator skill behind it. The
  command is the only door in — it disables model invocation, so a
  conversation that merely mentions specs, plans or releases cannot start
  a run — and the skill carries a unit of work from its seed through
  specification, planning, implementation, review and release, stopping
  at a human gate for everything that leaves the machine or cannot be
  undone by editing a file.
- The `pipeline:status` skill: reads a run's state through the plugin's
  own mechanics and reports the phase board, the gate the run is parked
  at, and the exact next action.
- The `pipeline:spec-review` skill: audits an implementation against its
  specification through independent lenses — contract compliance,
  security, and tests — run as separate passes, so a finding from one
  lens never dilutes another's.
- The `pipeline:device-verify` skill: builds, installs and drives a
  mobile release build on one attached device, captures each screen it
  touched, and reads every capture back. The description is the
  verification; a screenshot nobody read is not one.
- The configuration reference (`docs/configuration.md`): every key with
  its default or its detection path, and the precedence that runs from
  the two configuration files through `--config` to the individual flags.
  Nothing is required, and there are deliberately no environment-variable
  overrides — the reference says so rather than leaving it to be
  discovered.
- Prose gates (`tests/prose.bats`) over the orchestrator and the command,
  pinning the promises that live only in text: the closed front door, the
  gates named with the phases they guard, the never-bend rules verbatim,
  the release gate that `--auto` never collapses, and the runtime check
  that never claims a verification it did not make.
