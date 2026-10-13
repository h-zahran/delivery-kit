import { expect, mock, test } from 'claude-code/testing'
import type { Args, On } from 'claude-code'

// The lead's wiring across the lanes (ac03d8e): which main track the
// Spinner and the main card read, the home fold in FILES, and "late" with an
// idle helper about.

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
    scroll: { offset: 0, bodyRows: 120 },
    view: {},
  },
} as const

const BAND = {
  plugin: 'mission-control',
  component: 'AbovePrompt',
  surface: 'terminal',
  props: { hasSurvey: false, isWorking: true, maxRows: 4, bodyColumns: 100, scroll: { offset: 0, bodyRows: 4 }, view: {} },
} as const

const SPINNER = {
  plugin: 'mission-control',
  component: 'Spinner',
  surface: 'terminal',
  props: { word: 'Working', message: null, suffix: '…', mode: 'thinking' },
} as const

// The engine's own Spinner, beneath the plugin: draws the message it is handed.
const engineSpinner = (on: (...a: never[]) => unknown) =>
  (on as (k: string, f: (_: unknown, e: { props: { message: string | null; word: string } }) => unknown) => void)(
    'ui.render',
    (_, e) => ({ type: 'Text', children: [e.props.message ?? e.props.word] }),
  )

const MIN = 60_000
const startArgs = { cwd: 'D:/w', surface: 'terminal', isInteractive: true } as unknown as Args<'session.start'>
const prompt = (text: string) => ({ text, origin: { kind: 'composer' } }) as unknown as Args<'prompt.submit'>
const todos = (done: number, total: number) =>
  Array.from({ length: total }, (_, i) => ({
    content: `todo ${i + 1}`,
    activeForm: `doing todo ${i + 1}`,
    status: i < done ? 'completed' : i === done ? 'in_progress' : 'pending',
  }))

// The hooks session.start leans on, answered so it runs to the end.
const sessionHooks = (on: On) => {
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('tool.register', ($, e) => ({ value: { tool: e.name } }))
  on('ui.panes', () => ({ value: [] }))
}

// --- the main track: the todo list's when there is one, else the step reports'

test('integration: with a todo list the Spinner and the main card read its ETA, without one the step track', async ($, on) => {
  const clock = mock.clock(on)
  engineSpinner(on as never)
  on('tool.call', () => ({ result: 'ok' }))
  const step = (done: number) => $.tool.call({ tool: 'mcp__mission-control__step', done, total: 4 } as never)
  const write = (list: ReturnType<typeof todos>) => $.tool.call({ tool: 'TodoWrite', todos: list } as never)
  await clock.set(1_760_000_000_000)
  // Todos at ten minutes a step: 2 of 5 done, three left, ~30m.
  await write(todos(0, 5))
  await clock.advance(10 * MIN)
  await write(todos(1, 5))
  // Step reports at a minute a step: 2 of 4 done, ~1m.
  await clock.advance(7 * MIN)
  await step(0)
  await clock.advance(MIN)
  await step(1)
  await clock.advance(MIN)
  await step(2)
  await clock.advance(MIN)
  await write(todos(2, 5))
  await clock.advance(1000)

  const spin = await $.ui.mount(SPINNER as never)
  expect(await spin.find({ text: /40% · step 3\/5 · 1s · ~30m left/ })).toBeDefined()
  expect(await spin.find({ text: /~1m left/ })).toBeUndefined()
  await spin.unmount()
  const pane = await $.ui.mount(PANE)
  expect(await pane.find({ text: /~30m left/ })).toBeDefined()
  expect(await pane.find({ text: /~1m left/ })).toBeUndefined()
  await pane.unmount()

  // The list emptied: both read the step reports again.
  await write([])
  const spin2 = await $.ui.mount(SPINNER as never)
  expect(await spin2.find({ text: /50% · step 3\/4 · 1m01s · ~1m left/ })).toBeDefined()
  await spin2.unmount()
  const pane2 = await $.ui.mount(PANE)
  expect(await pane2.find({ text: /2\/4/ })).toBeDefined()
  expect(await pane2.find({ text: /~1m left/ })).toBeDefined()
  expect(await pane2.find({ text: /~30m left/ })).toBeUndefined()
  await pane2.unmount()
})

// --- FILES: the real home is drawn as ~, the username never

// Launched from PowerShell or cmd, Windows sets USERPROFILE and no HOME.
test('integration: FILES folds USERPROFILE to ~ on Windows and never shows the username', async ($, on) => {
  mock.clock(on)
  mock.env(on, { OS: 'Windows_NT', USERPROFILE: 'C:\\Users\\zqinteg' })
  sessionHooks(on)
  on('tool.call', () => ({ result: 'ok' }))
  await $.session.start(startArgs)
  await $.tool.call({ tool: 'Edit', file_path: 'C:\\Users\\zqinteg\\proj\\a.ts', old_string: 'a', new_string: 'b' })
  await $.tool.call({ tool: 'Read', file_path: 'C:\\Users\\zqinteg\\proj\\sub\\b.ts' })
  await $.tool.call({ tool: 'Read', file_path: '/c/users/zqinteg/proj/c.ts' })
  const ui = await $.ui.mount(PANE)
  const drawn = JSON.stringify(await ui.drawn())
  expect(drawn).not.toMatch(/zqinteg/i)
  expect(await ui.find({ text: /~\\proj/ })).toBeDefined()
  expect(await ui.find({ text: /FILES 3/ })).toBeDefined()
  await ui.unmount()
})

// No USERPROFILE, only Git Bash's HOME: its /c/ spelling still names the drive.
test('integration: FILES folds a Git Bash HOME to ~ on Windows', async ($, on) => {
  mock.clock(on)
  mock.env(on, { OS: 'Windows_NT', HOME: '/c/users/zqbash' })
  sessionHooks(on)
  on('tool.call', () => ({ result: 'ok' }))
  await $.session.start(startArgs)
  await $.tool.call({ tool: 'Edit', file_path: 'C:\\Users\\zqbash\\proj\\a.ts', old_string: 'a', new_string: 'b' })
  await $.tool.call({ tool: 'Read', file_path: 'C:\\Users\\zqbash\\proj\\sub\\b.ts' })
  const ui = await $.ui.mount(PANE)
  const drawn = JSON.stringify(await ui.drawn())
  expect(drawn).not.toMatch(/zqbash/i)
  expect(await ui.find({ text: /~\\proj/ })).toBeDefined()
  await ui.unmount()
})

test('integration: FILES folds HOME to ~ off Windows and never shows the username', async ($, on) => {
  mock.clock(on)
  mock.env(on, { HOME: '/home/zqposix', USERPROFILE: 'C:\\Users\\zqother' })
  sessionHooks(on)
  on('tool.call', () => ({ result: 'ok' }))
  await $.session.start(startArgs)
  await $.tool.call({ tool: 'Edit', file_path: '/home/zqposix/proj/a.ts', old_string: 'a', new_string: 'b' })
  await $.tool.call({ tool: 'Read', file_path: '/home/zqposix/proj/sub/b.ts' })
  const ui = await $.ui.mount(PANE)
  const drawn = JSON.stringify(await ui.drawn())
  expect(drawn).not.toMatch(/zqposix/i)
  expect(await ui.find({ text: /~\/proj/ })).toBeDefined()
  await ui.unmount()
})

// --- "late": an idle helper may wait for good, so it does not hide an open ask

test('integration: an idle helper does not stop an open ask from showing late; a running one does', async ($, on) => {
  const clock = mock.clock(on)
  let status: 'running' | 'idle' = 'running'
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'ag-1' }))
  on('agent.list', () => ({ value: [{ id: 'ag-1', description: 'wait for mail', type: 'teammate', status }] }))
  on('prompt.submit', ($, e) => ({ text: e.text }))
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  sessionHooks(on)
  await $.session.start(startArgs)
  await $.agent.spawn({ tool_use_id: 'tu-1', prompt: 'wait for mail', description: 'wait for mail', subagentType: 'general-purpose' } as unknown as Args<'agent.spawn'>)
  await $.prompt.submit(prompt('fix the login bug on the settings page'))
  await $.turn.start({ text: 'fix the login bug on the settings page', turnId: 'm' })
  await clock.advance(1000)
  // Main stopped short: the ask stays open (only an answer turns it answered).
  await $.turn.complete({ answer: '', durationMs: 1, isAborted: true, turnId: 'm', reason: 'aborted' })

  // The helper still runs: it may yet do the work, so the ask is not late.
  await clock.advance(6000)
  const busy = await $.ui.mount(PANE)
  expect(await busy.find({ text: /1 open/ })).toBeDefined()
  expect(await busy.find({ text: /late/ })).toBeUndefined()
  await busy.unmount()

  // The engine's list says idle: the ask is late, in the pane and on the band.
  status = 'idle'
  await clock.advance(6000)
  const idle = await $.ui.mount(PANE)
  expect(await idle.find({ text: /1 open · ! 1 late/ })).toBeDefined()
  await idle.unmount()
  const band = await $.ui.mount(BAND)
  expect(await band.find({ text: /! 1 request open/ })).toBeDefined()
  await band.unmount()
})

// --- a refused write in a Button's press is caught, never a rejected press

test('integration: a refused view write rejects no press, on the band or in the pane', async ($, on) => {
  mock.clock(on)
  let n = 0
  let isRefused = false
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: `ag-${++n}` }))
  on('turn.complete', () => ({ text: '' }))
  on('state.set', ($, e, next) => (isRefused && (e as { key?: string }).key === 'view' ? { deny: 'store down' } : next(e)))
  const spawn = (d: string) =>
    $.agent.spawn({ tool_use_id: `tu-${d}`, prompt: d, description: d, subagentType: 'general-purpose' } as unknown as Args<'agent.spawn'>)
  await spawn('look around')
  await spawn('write the page')
  await $.turn.complete({ answer: 'ok', durationMs: 1, isAborted: false, turnId: 'h2', agentId: 'ag-2', reason: 'answer' })
  isRefused = true
  const pressed = async (ui: { press: (t: { key: string }) => Promise<unknown> }, key: string) => {
    try {
      await ui.press({ key })
      return 'ok'
    } catch (err) {
      return `${key}: ${String(err)}`
    }
  }
  const band = await $.ui.mount(BAND)
  expect(await pressed(band, 'mc-hide')).toBe('ok')
  await band.unmount()
  const pane = await $.ui.mount(PANE)
  for (const key of ['x-main', 'x-ag-1', 'fold-done']) {
    expect(await pane.find({ key })).toBeDefined()
    expect(await pressed(pane, key)).toBe('ok')
  }
  await pane.unmount()
})
