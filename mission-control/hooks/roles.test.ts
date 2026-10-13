import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { Args } from 'claude-code'
import { roleOf } from './roles'

// The 0.9.3 review's case list, copied as it was frozen: written before any
// variant of the role rules ran.
// ok: the roles a person would accept; 'none' = the plain look is acceptable (no role claimed).
// arch: which note sequence a helper of this kind plausibly reports (unused here).
// first: a plausible first line of the brief, in the shapes real agent templates use:
//   "You are implementing Task N: ...", "You are reviewing one task's implementation ...",
//   "You are a Senior Code Reviewer ...", "You are a ... extraction subagent.",
//   a brief that names no role at all, and "You are the implementer ...".
type Case = { d: string; type: string; ok: string[]; arch: string; first: string; verbFirst: boolean }
const gp = 'general-purpose'
const CASES: Case[] = [
  // ---- verb-first ----
  { d: 'Review register.tsx', type: gp, ok: ['inspector'], arch: 'inspector', first: 'You are the reviewer for register.tsx.', verbFirst: true },
  { d: 'Fix asks tick bug', type: gp, ok: ['fixer'], arch: 'fixer', first: 'Fix the asks tick bug: asks.ts:178 drops `by`.', verbFirst: true },
  { d: 'Build the 0.9.4 release', type: gp, ok: ['builder'], arch: 'builder', first: 'You are the release builder for mission-control 0.9.4.', verbFirst: true },
  { d: 'Implement role fix', type: gp, ok: ['builder', 'fixer'], arch: 'builder', first: 'You are implementing Task 3: role words get word ends', verbFirst: true },
  { d: 'Write CHANGELOG entry', type: gp, ok: ['writer'], arch: 'writer', first: 'Write the 0.9.4 CHANGELOG section.', verbFirst: true },
  { d: 'Research engine hook API', type: gp, ok: ['researcher'], arch: 'researcher', first: 'Research how session.end is delivered in claude-code.d.ts.', verbFirst: true },
  { d: 'Plan the 0.9.4 release', type: 'Plan', ok: ['planner'], arch: 'planner', first: 'Plan the 0.9.4 release from the merged findings.', verbFirst: true },
  { d: 'Find roleOf call sites', type: 'Explore', ok: ['scout'], arch: 'scout', first: 'Find every call site of roleOf and shadeOf.', verbFirst: true },
  { d: 'Explore filetree module', type: 'Explore', ok: ['scout'], arch: 'scout', first: 'Explore filetree.ts and report how home folding works.', verbFirst: true },
  { d: 'Audit forecast math', type: gp, ok: ['inspector'], arch: 'inspector', first: 'You are a Senior Code Reviewer with expertise in numerics.', verbFirst: true },
  { d: 'Debug chime on Windows', type: gp, ok: ['fixer'], arch: 'fixer', first: 'The chime is silent on Windows after a curly quote; debug it.', verbFirst: true },
  { d: 'Test the eta helpers', type: gp, ok: ['inspector'], arch: 'inspector', first: 'Write bats-free unit tests for eta.ts.', verbFirst: true },
  { d: 'Add session.end hook', type: gp, ok: ['builder'], arch: 'builder', first: 'You are the implementer for the session.end hook.', verbFirst: true },
  { d: 'Update README for asks', type: gp, ok: ['writer'], arch: 'writer', first: 'Update the README: say the mod adds a system-prompt section.', verbFirst: true },
  { d: 'Address review comments', type: gp, ok: ['fixer', 'builder'], arch: 'fixer', first: 'You are implementing the fixes from review round 2.', verbFirst: true },
  { d: 'Refactor summary batching', type: gp, ok: ['builder'], arch: 'builder', first: 'You are the implementer for the summary.ts refactor.', verbFirst: true },
  { d: 'Verify release tags', type: gp, ok: ['inspector'], arch: 'inspector', first: 'Verify the three release tags point at main.', verbFirst: true },
  { d: 'Port chime to Linux', type: gp, ok: ['builder'], arch: 'builder', first: 'You are implementing Task 2: Linux chime players', verbFirst: true },
  { d: 'Investigate flaky bats test', type: gp, ok: ['researcher', 'fixer'], arch: 'researcher', first: 'A bats test times out one run in five. Find out why.', verbFirst: true },
  { d: 'Draft PR description', type: gp, ok: ['writer'], arch: 'writer', first: 'Draft the PR body for 0.9.4.', verbFirst: true },
  { d: 'Check CI status', type: gp, ok: ['inspector'], arch: 'inspector', first: 'Check the CI runs for PR #88.', verbFirst: true },
  { d: 'Compare jq versions', type: gp, ok: ['researcher'], arch: 'researcher', first: 'Compare jq 1.6 and 1.7 on -b and --argjson.', verbFirst: true },
  { d: 'Set up worktree', type: gp, ok: ['builder'], arch: 'builder', first: 'Set up a worktree for lane 057 from origin/main.', verbFirst: true },
  { d: 'Read handoff docs', type: 'Explore', ok: ['scout'], arch: 'scout', first: 'Read handoff/docs and list the published pages.', verbFirst: true },
  { d: 'Ready the release branch', type: gp, ok: ['builder'], arch: 'builder', first: 'You are the release builder: ready the branch.', verbFirst: true },
  { d: 'Checkout release branch', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'Check out the release branch and bump versions.', verbFirst: true },
  { d: 'Reproduce the DST bug', type: gp, ok: ['fixer'], arch: 'fixer', first: 'Reproduce the DST touch-stamp bug on a local clock.', verbFirst: true },
  { d: 'Mutation-test the gate', type: gp, ok: ['inspector'], arch: 'inspector', first: 'You are the reviewer: mutate the gate at its edges.', verbFirst: true },
  { d: 'Second-pass review slice B', type: gp, ok: ['inspector'], arch: 'inspector-real', first: 'Second-pass review of the Claude Code function-hook mod "mission-control" 0.9.3.', verbFirst: true },
  { d: 'Summarize bin folder', type: 'Explore', ok: ['scout'], arch: 'scout', first: 'Summarize what each script in bin/ does.', verbFirst: true },
  { d: 'Re-run the full suite', type: gp, ok: ['inspector', 'none'], arch: 'inspector', first: 'Run bats tests in the FOREGROUND and report the plan line.', verbFirst: true },
  { d: 'Rebase PR branch on main', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'Rebase fix/role-words on origin/main.', verbFirst: true },
  // ---- noun-ish ----
  { d: 'Lane 056 one config read', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'You are the implementer for lane 056.', verbFirst: false },
  { d: 'Test plan', type: gp, ok: ['planner', 'writer', 'none'], arch: 'planner', first: 'Write the test plan for the asks rework.', verbFirst: false },
  { d: 'Cache cost report', type: gp, ok: ['writer', 'researcher', 'none'], arch: 'researcher', first: 'Measure cache_creation tokens per turn and report.', verbFirst: false },
  { d: 'Docs map', type: gp, ok: ['writer', 'scout', 'none'], arch: 'scout', first: 'Map every published docs page and its links.', verbFirst: false },
  { d: 'Release notes list', type: gp, ok: ['writer', 'none'], arch: 'writer', first: 'Collect the user-facing changes since 0.9.3 as release notes.', verbFirst: false },
  { d: 'Lane 012 asks tick fix', type: gp, ok: ['fixer'], arch: 'fixer', first: 'You are the implementer for lane 012.', verbFirst: false },
  { d: 'Lane 031 forecast window', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'You are the implementer for lane 031.', verbFirst: false },
  { d: 'Phase 7 deep review', type: gp, ok: ['inspector'], arch: 'inspector', first: 'You are reviewing one task\'s implementation: first whether it matches its spec.', verbFirst: false },
  { d: 'Role bug repro', type: gp, ok: ['fixer'], arch: 'fixer', first: 'Reproduce the scout-for-28-minutes role bug.', verbFirst: false },
  { d: 'Config loader port', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'You are implementing Task 4: config loader in TS', verbFirst: false },
  { d: 'Webhook retry logic', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'You are the implementer for webhook retries.', verbFirst: false },
  { d: 'Mapping layer cleanup', type: gp, ok: ['builder', 'fixer', 'none'], arch: 'builder', first: 'Clean up the mapping layer in filetree.ts.', verbFirst: false },
  { d: 'Listener teardown fix', type: gp, ok: ['fixer'], arch: 'fixer', first: 'You are the implementer for the listener teardown fix.', verbFirst: false },
  { d: 'Lane 044 lookup table', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'You are the implementer for lane 044.', verbFirst: false },
  { d: 'Error budget dashboard', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'You are implementing Task 6: error budget dashboard', verbFirst: false },
  { d: 'Design tokens migration', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'You are the implementer for the design tokens migration.', verbFirst: false },
  { d: 'Readme overhaul', type: gp, ok: ['writer', 'none'], arch: 'writer', first: 'Rewrite the README top to bottom.', verbFirst: false },
  { d: 'Address book import', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'You are implementing Task 1: address book import', verbFirst: false },
  { d: 'Debug log cleanup', type: gp, ok: ['builder', 'fixer', 'none'], arch: 'builder', first: 'Remove the leftover debug logs from register.tsx.', verbFirst: false },
  { d: 'Lane 060 test fixtures', type: gp, ok: ['inspector', 'builder', 'none'], arch: 'builder', first: 'You are the implementer for lane 060.', verbFirst: false },
  { d: 'Planner state machine', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'You are the implementer for the planner state machine.', verbFirst: false },
  { d: 'Report generator', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'You are implementing Task 5: report generator', verbFirst: false },
]

// A held-out list for 0.9.5, same shape, written and frozen before any 0.9.5
// variant of the rules ran: a change to the rules is kept only if it lowers
// the count above and does not raise this one. Some pass today, and some put
// a rule word where its role is wrong ("Patch notes", "Regression tests").
const HELD_OUT: Case[] = [
  // ---- verb-first ----
  { d: 'Fix flaky timeline test', type: gp, ok: ['fixer', 'inspector'], arch: 'fixer', first: 'You are the implementer for the flaky timeline test fix.', verbFirst: true },
  { d: 'Update CHANGELOG for 0.9.5', type: gp, ok: ['writer'], arch: 'writer', first: 'Update CHANGELOG.md with the 0.9.5 section.', verbFirst: true },
  { d: 'Map the hook events', type: gp, ok: ['scout', 'researcher'], arch: 'scout', first: 'List every hook event the mod registers and where.', verbFirst: true },
  { d: 'Reproduce flaky CI on macOS', type: gp, ok: ['fixer', 'researcher', 'inspector'], arch: 'fixer', first: 'A test fails on macOS CI only; reproduce it locally.', verbFirst: true },
  { d: 'Review the API docs', type: gp, ok: ['inspector', 'writer'], arch: 'inspector', first: 'You are the reviewer for the API reference pages.', verbFirst: true },
  { d: 'Write the bats tests for chime', type: gp, ok: ['inspector', 'builder'], arch: 'builder', first: 'Write bats tests for the chime players.', verbFirst: true },
  { d: 'Port tests to bun', type: gp, ok: ['builder', 'inspector'], arch: 'builder', first: 'You are implementing Task 4: move the tests to bun', verbFirst: true },
  { d: 'Bisect the slow startup', type: gp, ok: ['fixer', 'researcher', 'none'], arch: 'researcher', first: 'Startup went from 1 s to 4 s between 0.9.2 and 0.9.4; bisect it.', verbFirst: true },
  { d: 'Tidy the docs folder', type: gp, ok: ['writer', 'builder', 'none'], arch: 'writer', first: 'Move stale pages out of docs/ and fix the links.', verbFirst: true },
  { d: 'Look up TIRED_PCT uses', type: gp, ok: ['scout'], arch: 'scout', first: 'Find every place TIRED_PCT is read.', verbFirst: true },
  { d: 'Study the spawn payload', type: gp, ok: ['researcher', 'scout'], arch: 'researcher', first: 'Study what agent.spawn hands the hook, field by field.', verbFirst: true },
  { d: 'Clean up stale worktrees', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'Remove the merged worktrees under the repo parent.', verbFirst: true },
  // ---- noun-ish ----
  { d: 'Changelog for 0.9.5', type: gp, ok: ['writer'], arch: 'writer', first: 'Collect the merged PR titles into the CHANGELOG.', verbFirst: false },
  { d: 'Regression in eta rounding', type: gp, ok: ['fixer'], arch: 'fixer', first: 'The eta shows 0 min for a long run since 0.9.4; find and fix it.', verbFirst: false },
  { d: 'Regression tests for asks', type: gp, ok: ['inspector', 'builder'], arch: 'builder', first: 'You are implementing Task 2: regression tests for asks.ts', verbFirst: false },
  { d: 'Docs site build fix', type: gp, ok: ['fixer'], arch: 'fixer', first: 'You are the implementer for the docs site build fix.', verbFirst: false },
  { d: 'Release plan', type: gp, ok: ['planner', 'none'], arch: 'planner', first: 'Lay out the steps for the 0.9.5 release.', verbFirst: false },
  { d: 'Pricing plan', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'Add a pricing plan page to the site.', verbFirst: false },
  { d: 'README link checker', type: gp, ok: ['builder', 'inspector', 'none'], arch: 'builder', first: 'Add a CI step that checks every README link.', verbFirst: false },
  { d: 'README install section', type: gp, ok: ['writer'], arch: 'writer', first: 'Rewrite the install section of the README for Windows users.', verbFirst: false },
  { d: 'Summary panel crash fix', type: gp, ok: ['fixer'], arch: 'fixer', first: 'You are the implementer for lane 071.', verbFirst: false },
  { d: 'Error message wording', type: gp, ok: ['writer', 'none'], arch: 'writer', first: 'Reword the error messages in forecast.ts in plain English.', verbFirst: false },
  { d: 'Patch notes', type: gp, ok: ['writer', 'none'], arch: 'writer', first: 'Turn the merged PRs into patch notes for the release page.', verbFirst: false },
  { d: 'Reproducible builds', type: gp, ok: ['builder', 'none'], arch: 'builder', first: 'Make the release tarball byte-identical across runs.', verbFirst: false },
  { d: 'Mapping table tests', type: gp, ok: ['inspector', 'builder', 'none'], arch: 'builder', first: 'You are the implementer for lane 080.', verbFirst: false },
]

const roleIdOf = (d: string, type: string, prompt?: string): string => roleOf(d, type, prompt)?.id ?? 'none'

test('roles: the frozen case list reads no mission wrong', async () => {
  const wrong = CASES.filter(c => !c.ok.includes(roleIdOf(c.d, c.type, c.first))).map(
    c => `${c.d} [${c.type}] -> ${roleIdOf(c.d, c.type, c.first)}`,
  )
  expect(`${wrong.length} wrong:\n${wrong.join('\n')}`).toMatch(/^0 wrong/)
})

test('roles: the held-out case list reads at most 5 missions wrong', async () => {
  const wrong = HELD_OUT.filter(c => !c.ok.includes(roleIdOf(c.d, c.type, c.first))).map(
    c => `${c.d} [${c.type}] -> ${roleIdOf(c.d, c.type, c.first)}`,
  )
  expect(`${wrong.length} wrong:\n${wrong.join('\n')}`).toMatch(/^[0-5] wrong/)
})

test('roles: the owner case is never a scout, with or without its brief', async () => {
  const own = CASES.find(c => c.d === 'Lane 056 one config read')!
  expect(roleIdOf(own.d, gp)).not.toBe('scout')
  expect(roleIdOf(own.d, gp, own.first)).not.toBe('scout')
  expect(roleIdOf(own.d, gp, own.first)).toBe('builder')
})

test('roles: whole words end at a word boundary, stems stay open', async () => {
  // "add" is not "Address", "read" is not "ready".
  expect(roleIdOf('Address review comments', gp)).not.toBe('builder')
  expect(roleIdOf('Get ready for release', gp)).not.toBe('scout')
  // Stems still take their endings.
  expect(roleIdOf('Create config', gp)).toBe('builder')
  expect(roleIdOf('Adding tests', gp)).toBe('builder')
})

test('roles: Explore and Plan types win over the words', async () => {
  expect(roleIdOf('Debug the finder', 'Explore')).toBe('scout')
  expect(roleIdOf('Fix the plan', 'Plan', 'You are the implementer.')).toBe('planner')
})

test('roles: the brief\'s "You are" line names the role, within four words', async () => {
  expect(roleIdOf('Lane 9', gp, '\nYou are the release builder: ready the branch.')).toBe('builder')
  expect(roleIdOf('Lane 9', gp, 'You are a Senior Code Reviewer with expertise.')).toBe('inspector')
  expect(roleIdOf('Lane 9', gp, 'You are the one who will later fix it.')).toBe('none')
  // Not the first line: the description decides.
  expect(roleIdOf('Fix lane 9', gp, 'Context first.\nYou are the implementer.')).toBe('fixer')
})

test('roles: the last word of a longer description does not pick the role', async () => {
  expect(roleIdOf('Config loader port', gp)).toBe('none')
  expect(roleIdOf('Port the config loader', gp)).toBe('builder')
  // Two words are too few to tell a noun from a verb: the last one still counts.
  expect(roleIdOf('Docs map', gp)).toBe('writer')
})

test('roles: the files and steps of the work name it: readme a writer, a repro a fixer', async () => {
  expect(roleIdOf('Update README for asks', gp)).toBe('writer')
  expect(roleIdOf('Fill in the CHANGELOG section', gp)).toBe('writer')
  expect(roleIdOf('Reproduce the DST bug', gp)).toBe('fixer')
  expect(roleIdOf('Repro the hang', gp)).toBe('fixer')
  expect(roleIdOf('Regression in eta', gp)).toBe('fixer')
  // "Reproducible" is not a repro.
  expect(roleIdOf('Reproducible builds', gp)).not.toBe('fixer')
})

test('roles: "mapping" is not "map"', async () => {
  expect(roleIdOf('Mapping layer cleanup', gp)).toBe('none')
  expect(roleIdOf('Map the hook events', gp)).toBe('scout')
  expect(roleIdOf('Mapped files', gp)).toBe('scout')
})

test('roles: of two words, a last "plan" is the thing made', async () => {
  expect(roleIdOf('Test plan', gp)).toBe('planner')
  expect(roleIdOf('Migration plans', gp)).toBe('planner')
  // Longer: the first word still leads.
  expect(roleIdOf('Review the plan', gp)).toBe('inspector')
  expect(roleIdOf('Test plan review', gp)).toBe('inspector')
})

test('roles: a fix is a fixer\'s, even when the brief says implementer', async () => {
  expect(roleIdOf('Listener teardown fix', gp, 'You are the implementer for the listener teardown fix.')).toBe('fixer')
  expect(roleIdOf('Fix flaky test', gp, 'You are implementing Task 3: flaky test')).toBe('fixer')
  // Only over a builder: a reviewer of a fix still reviews.
  expect(roleIdOf('Review the fix', gp, 'You are the reviewer for PR 9.')).toBe('inspector')
  // A whole word: a prefix or a fixture is no fix.
  expect(roleIdOf('Prefix cache', gp, 'You are the implementer for lane 9.')).toBe('builder')
  expect(roleIdOf('Fixture loader', gp, 'You are the implementer for lane 9.')).toBe('builder')
})

// The pane, mounted as mission.test.tsx mounts it.
const PANE = {
  plugin: 'mission-control',
  component: 'Pane',
  requestId: 'mission-control',
  surface: 'terminal',
  props: {
    title: 'Mission Control',
    isFocused: false,
    bodyColumns: 70,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 60 },
    view: {},
  },
} as const

// The bold role name on each robot's card, in its helper's color.
const roleNames = async ($: Engine, role: string) => {
  const ui = await $.ui.mount(PANE)
  const names = await ui.findAll({ type: 'Text', text: new RegExp(`^${role}$`) })
  await ui.unmount()
  return names.filter(t => t.props.bold)
}

test('roles: a spawn reads its role from the brief\'s first line', async ($, on) => {
  mock.clock(on)
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'ag-1' }))
  await $.agent.spawn({
    tool_use_id: 'tu-1',
    prompt: 'You are the implementer for lane 056.\nRead the config once.',
    description: 'Lane 056 one config',
    subagentType: gp,
  } as unknown as Args<'agent.spawn'>)
  expect(await roleNames($, 'builder')).toHaveLength(1)
})

test('roles: two helpers of one role spawned together get different shades', async ($, on) => {
  mock.clock(on)
  let n = 0
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: `ag-${++n}` }))
  const spawn = (description: string) =>
    $.agent.spawn({ tool_use_id: `tu-${description}`, prompt: description, description, subagentType: gp } as unknown as Args<'agent.spawn'>)
  await Promise.all([spawn('Fix the login bug'), spawn('Fix the logout bug')])
  const colors = (await roleNames($, 'fixer')).map(t => t.props.color)
  expect(colors).toHaveLength(2)
  expect(colors[0]).not.toBe(colors[1])
})

test('roles: two plain helpers spawned together get different colors', async ($, on) => {
  mock.clock(on)
  let n = 0
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: `ag-${++n}` }))
  const spawn = (description: string) =>
    $.agent.spawn({ tool_use_id: `tu-${description}`, prompt: description, description, subagentType: gp } as unknown as Args<'agent.spawn'>)
  await Promise.all([spawn('Do one thing'), spawn('Do another thing')])
  const ui = await $.ui.mount(PANE)
  // No role: the robot's body takes the helper's own color.
  const bodies = await Promise.all(['ag-1', 'ag-2'].map(id => ui.find({ type: 'Client', key: `r-${id}-c` })))
  await ui.unmount()
  const colors = bodies.map(b => (b?.props.props as { colors: string[][] } | undefined)?.colors[0]?.[0])
  expect(colors[0]).toBeDefined()
  expect(colors[0]).not.toBe(colors[1])
})
