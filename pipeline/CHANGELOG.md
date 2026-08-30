# Changelog — pipeline

All notable changes to the `pipeline` plugin.

## [Unreleased]

### Added

- Pre-flight now probes `git` and reports it beside `jq`, `gh` and `adb`. An
  absent `git` is a STOP, not a degradation: the run names the tool, prints
  `https://git-scm.com/downloads`, records the answer and installs nothing.
  It stops because nothing survives the absence — branching, committing and
  opening a pull request are all git operations, and the probe's own base
  branch and working tree reads are git commands that, without it, quietly
  reported an empty branch and a clean tree. Naming a phase to skip would have
  named a capability nobody acts on. The stop fires before every other
  pre-flight decision, including the two that call git themselves.

### Changed

- `README.md` rewritten for a first-time reader: the twenty phases drawn as
  one map with the five gates marked, the gate table naming what each one
  shows and what collapses it, and the automation warning stated where a
  reader meets it. No phase, flag, default, or gate changed.
- The plugin manifest's description now says what the plugin does in one
  plain sentence, matching the marketplace entry.

## [1.1.0] - 2026-08-24

### Added

- Pre-flight now probes the project constitution: the probe script
  emits a new boolean for it, the probe block prints a Constitution
  line (`set`, or `not set — plan gates run against an empty
  document`), and when it is not set the run offers the spec-kit
  constitution command once — the principles are the owner's to write,
  declining is fine, and the offer is not repeated within a run.

- The implementer gate's handoff package is now a seven-part contract —
  files to provide, repository state, instructions, the derived
  forbidden list, what will bite this feature, validation before done,
  and the report-back contract — so a cheaper model receives everything
  a good handoff carries, and a new prose test pins the seven names.
  A "handoff" answer now parks the run at the implement phase with the
  lock released, and a later resume consumes the implementer's report
  before dispatching anything the report already claims.

- The `implementer` key and its `--implementer <claude|handoff|ask>`
  flag: set to `claude` or `handoff`, either one pre-answers the
  implementer gate, which records the configured answer and does not stop
  to ask. Set to `ask` the gate asks, as it does when the key is unset —
  the value exists so a later layer, a command line included, can take
  back a stop an earlier layer gave away; writing `null` in a later layer
  overrides nothing, since layers merge by silence rather than erasure —
  which holds for every key, so the command keys, having no `ask` of their
  own, can be replaced by a later layer but never returned to unset.
  With `claude` an `--auto` run then stops at no gate but clarify —
  where `releaseCommand` is unset and the constitution is already set,
  since the release gate and the pre-flight constitution offer each still
  stop a run of their own accord; where clarify also raises no questions,
  no gate stops the run at all. Read that as a claim about gates and
  nothing else. Cap breaches, a missing required tool, hard failures and
  a failed runtime check still stop it, but the gates do not — and this
  release adds a fourth cap, `maxVerifyIters`, so that caveat is wider
  now than when it was written; `docs/configuration.md` states the whole
  range. With `handoff` the run parks for the
  external report, package written and lock released. Unset means the
  gate asks, as before; an illegal value stops pre-flight by name — never
  coerced, never treated as unset. Pre-flight prints an `Implementer`
  line naming the resolved value and the layer it came from, and omits
  the line when unset.

- The `maxVerifyIters` key, default 5: the verification phase's fix loop
  runs at most that many iterations, and a breach is a conditional stop —
  the remaining failures are shown and the run asks whether to continue.
  Verification was the last unbounded loop in the product; it now has the
  shape clarification, analysis and review already had. One difference is
  deliberate: a breach waved through records the surviving failures in the
  state file and carries them outward into the commit message and the pull
  request — into the commit message alone where no pull request exists,
  because a degraded remote can leave the run without one. The state-file
  record is kept either way. Verification is the last full-suite check before
  code leaves the machine. A hard failure still stops the run outright.

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
