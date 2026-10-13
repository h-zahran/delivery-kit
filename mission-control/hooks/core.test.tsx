import { expect, mock, test } from 'claude-code/testing'
import type { Args, On } from 'claude-code'

// The core lane of 0.9.5: the permission wait, the ask ids beside a prompt,
// usage while idle, the main plan the card and the Spinner read, idle helpers,
// the commentator's one call, and the main loop's own plan reported and finished.

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
const ASK = 'mcp__mission-control__ask'
const startArgs = { cwd: 'E:/w', surface: 'terminal', isInteractive: true } as unknown as Args<'session.start'>
const prompt = (text: string) => ({ text, origin: { kind: 'composer' } }) as unknown as Args<'prompt.submit'>
const usageOf = (startedAt: number) => ({ startedAt, context: { window: 200_000, percent: 1, tokens: 10 }, rateLimits: [] })
const allDone = (n: number) => Array.from({ length: n }, (_, i) => ({ content: `todo ${i + 1}`, activeForm: `doing ${i + 1}`, status: 'completed' }))
const spawn = (d: string) =>
  ({ tool_use_id: `tu-${d}`, prompt: d, description: d, subagentType: 'general-purpose' }) as unknown as Args<'agent.spawn'>

// The hooks session.start leans on, answered so it runs to the end.
const sessionHooks = (on: On) => {
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('tool.register', ($, e) => ({ value: { tool: e.name } }))
  on('ui.panes', () => ({ value: [] }))
}

type WaitState = { waitSince?: number; waitTool?: string; waitId?: string }
// The last value the plugin wrote under each key, seen from beneath.
const writes = (on: On) => {
  const last: Record<string, unknown> = {}
  ;(on as unknown as (k: string, f: (_: unknown, e: { key?: string; value?: unknown }, next: (e: unknown) => unknown) => unknown) => void)(
    'state.set',
    (_, e, next) => {
      if (e.key) last[e.key] = e.value
      return next(e)
    },
  )
  return {
    main: () => (last.main ?? {}) as WaitState,
    agents: () => (last.agents ?? []) as (WaitState & { id: string })[],
  }
}

// --- L1: a dialog a settings hook answered never opened

test('core L1: a settings hook that answers the permission request opens no dialog, so nobody waits', async ($, on) => {
  const clock = mock.clock(on)
  let answer: object = { decision: { behavior: 'allow' } }
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('classic.PermissionRequest', () => answer)
  await $.turn.start({ text: 'go', turnId: 't' })
  await $.classic.PermissionRequest({ tool_name: 'Bash', tool_input: { command: 'make' } })
  await clock.advance(2000)
  const ui = await $.ui.mount(PANE)
  expect(await ui.find({ text: /NEEDS YOUR OK/ })).toBeUndefined()
  await ui.unmount()
  // Nothing answered beneath: the dialog opens and the badge shows.
  answer = {}
  await $.classic.PermissionRequest({ tool_name: 'Bash', tool_input: { command: 'make' } })
  await clock.advance(2000)
  const later = await $.ui.mount(PANE)
  expect(await later.find({ text: /NEEDS YOUR OK/ })).toBeDefined()
  await later.unmount()
})

// --- L1: the wait is the asking call's, by its tool_use_id

test('core L1: another call of the same tool ending leaves the dialog shown; the asking call clears it', async ($, on) => {
  const clock = mock.clock(on)
  const st = writes(on)
  let release = () => {}
  const gate = new Promise<void>(r => (release = r))
  let reached = () => {}
  const atDialog = new Promise<void>(r => (reached = r))
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('tool.check', () => ({ decision: 'ask' }))
  on('classic.PermissionRequest', () => ({}))
  // The engine, beneath every hook: the asking call is checked, its dialog opens and holds.
  on('tool.call', async (_h, e) => {
    if (e.tool_use_id === 'tu-ask') {
      await $.tool.check({ tool: 'Bash', input: { command: 'git push' }, tool_use_id: 'tu-ask' } as never)
      await $.classic.PermissionRequest({ tool_name: 'Bash', tool_input: { command: 'git push' } })
      reached()
      await gate
    }
    return { result: 'ok' }
  })
  await $.turn.start({ text: 'go', turnId: 't' })
  const asking = $.tool.call({ tool: 'Bash', command: 'git push', description: 'push', tool_use_id: 'tu-ask' } as never)
  await atDialog
  expect(st.main().waitId).toBe('tu-ask')
  // A second Bash, allowed by a rule, ends while the dialog is open.
  await $.tool.call({ tool: 'Bash', command: 'ls', description: 'list', tool_use_id: 'tu-quick' } as never)
  await clock.advance(2000)
  const ui = await $.ui.mount(PANE)
  expect(await ui.find({ text: /NEEDS YOUR OK/ })).toBeDefined()
  await ui.unmount()
  release()
  await asking
  const after = await $.ui.mount(PANE)
  expect(await after.find({ text: /NEEDS YOUR OK/ })).toBeUndefined()
  await after.unmount()
  expect(st.main().waitId).toBeUndefined()
})

// --- L2: the id beside the prompt is the id stored

test('core L2: an ask the model adds while the prompt enters keeps the person\'s id as shown', async ($, on) => {
  mock.clock(on)
  const seen: string[] = []
  on('tool.list', () => ({ value: [{ name: 'Read', description: 'r', mcp: false }, { name: ASK, description: 'a', mcp: true }] }))
  on('tool.call', () => ({ result: 'ok' }))
  on('prompt.submit', async (_h, e) => {
    seen.push((e.context ?? []).join('\n'))
    // The model's add lands while the prompt is still entering.
    await $.tool.call({ tool: ASK, add: 'check the cache first' } as never)
    return { text: e.text }
  })
  await $.prompt.submit(prompt('fix the login bug on the settings page'))
  expect(seen[0]).toContain('a1 "fix the login bug on the settings page"')
  const ui = await $.ui.mount(PANE)
  expect(await ui.find({ text: /a1\s+fix the login bug/ })).toBeDefined()
  expect(await ui.find({ text: /a2\s+check the cache first/ })).toBeDefined()
  await ui.unmount()
})

test('core L2: a dropped prompt stores nothing and leaves an ask already open alone', async ($, on) => {
  mock.clock(on)
  let isDrop = false
  on('prompt.submit', ($, e) => (isDrop ? { drop: 'not now' } : { text: e.text }))
  await $.prompt.submit(prompt('fix the login bug on the settings page'))
  isDrop = true
  // The same text again: no new ask, and the drop takes nothing away.
  await $.prompt.submit(prompt('fix the login bug on the settings page')).catch(() => undefined)
  await $.prompt.submit(prompt('add a dark theme toggle')).catch(() => undefined)
  const ui = await $.ui.mount(PANE)
  expect(await ui.find({ text: /a1\s+fix the login bug/ })).toBeDefined()
  expect(await ui.find({ text: /dark theme/ })).toBeUndefined()
  expect(await ui.find({ text: /REQUESTS 1/ })).toBeDefined()
  await ui.unmount()
})

// --- L3: an idle clock still reads usage, every 30 s

test('core L3: an idle clock reads usage every 30 s, so /clear is seen with nothing running', async ($, on) => {
  const clock = mock.clock(on)
  sessionHooks(on)
  let startedAt = 5
  let reads = 0
  let opened = 0
  on('session.usage', () => {
    reads++
    return { value: usageOf(startedAt) }
  })
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text key="engine-band">engine</Text>
  })
  on('ui.open', () => {
    opened++
    return { value: { isPlaced: true } }
  })
  await $.session.start(startArgs)
  const band = await $.ui.mount({ ...BAND, viewport: { columns: 100, rows: 40, isFullscreen: true } } as never)
  await band.unmount()
  await clock.advance(1000)
  expect(opened).toBe(1)
  const settled = reads
  await clock.advance(28_000)
  expect(reads).toBe(settled)
  // /clear while idle: the next 30 s beat sees the new start; the pane may open itself again.
  startedAt = 9_000
  await clock.advance(1000)
  expect(reads).toBe(settled + 1)
  const band2 = await $.ui.mount({ ...BAND, viewport: { columns: 100, rows: 40, isFullscreen: true } } as never)
  await band2.unmount()
  await clock.advance(1000)
  expect(opened).toBe(2)
})

// --- L4: a finished todo list gives way to the step plan

test('core L4: with the todo list all done, the card and the Spinner show the step plan and its time left', async ($, on) => {
  const clock = mock.clock(on)
  engineSpinner(on as never)
  on('tool.call', () => ({ result: 'ok' }))
  const step = (done: number) =>
    $.tool.call({ tool: 'mcp__mission-control__step', done, total: 4, steps: ['plan', 'build', 'test', 'ship'] } as never)
  await clock.set(1_760_000_000_000)
  await $.tool.call({ tool: 'TodoWrite', todos: allDone(3) } as never)
  await step(0)
  await clock.advance(MIN)
  await step(1)
  await clock.advance(MIN)
  await step(2)
  await clock.advance(1000)
  const spin = await $.ui.mount(SPINNER as never)
  expect(await spin.find({ text: /50% · step 3\/4 · 1s · ~2m left/ })).toBeDefined()
  await spin.unmount()
  const ui = await $.ui.mount(PANE)
  expect(await ui.find({ text: /2\/4/ })).toBeDefined()
  expect(await ui.find({ text: /3\/3/ })).toBeUndefined()
  expect(await ui.find({ text: /~2m left/ })).toBeDefined()
  expect(await ui.find({ text: /test/ })).toBeDefined()
  await ui.unmount()
  // A todo list still open keeps its place.
  await $.tool.call({ tool: 'TodoWrite', todos: [...allDone(2), { content: 'last', activeForm: 'doing last', status: 'in_progress' }] } as never)
  const open = await $.ui.mount(PANE)
  expect(await open.find({ text: /2\/3/ })).toBeDefined()
  expect(await open.find({ text: /2\/4/ })).toBeUndefined()
  await open.unmount()
})

// --- L5: a turn's end clears the whole wait

test('core L5: a turn\'s end clears the waiting tool with the wait, main\'s and a helper\'s', async ($, on) => {
  const clock = mock.clock(on)
  const st = writes(on)
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  on('classic.PermissionRequest', () => ({}))
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'ag-1' }))
  await $.turn.start({ text: 'go', turnId: 't' })
  await $.agent.spawn(spawn('fix it'))
  await $.classic.PermissionRequest({ tool_name: 'Bash', tool_input: { command: 'make' } })
  await $.classic.PermissionRequest({ tool_name: 'Write', tool_input: { file_path: 'E:/w/a' }, agent_id: 'ag-1' } as never)
  await clock.advance(2000)
  expect(st.main().waitTool).toBe('Bash')
  expect(st.agents()[0]?.waitTool).toBe('Write')
  await $.turn.complete({ answer: '', durationMs: 1, isAborted: true, turnId: 'ag-1', agentId: 'ag-1', reason: 'aborted' })
  await $.turn.complete({ answer: '', durationMs: 1, isAborted: true, turnId: 't', reason: 'aborted' })
  const m = st.main()
  expect([m.waitSince, m.waitTool]).toEqual([undefined, undefined])
  const a = st.agents()[0]
  expect([a?.waitSince, a?.waitTool]).toEqual([undefined, undefined])
})

// --- L6: an idle helper is not working

test('core L6: an idle helper reads idle, never working, in the pane and on the band', async ($, on) => {
  const clock = mock.clock(on)
  let status: 'running' | 'idle' = 'running'
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'ag-1' }))
  on('agent.list', () => ({ value: [{ id: 'ag-1', description: 'wait for mail', type: 'teammate', status }] }))
  sessionHooks(on)
  await $.session.start(startArgs)
  await $.agent.spawn(spawn('wait for mail'))
  const busy = await $.ui.mount(PANE)
  expect(await busy.find({ text: /idle · 1 helper working/ })).toBeDefined()
  await busy.unmount()
  status = 'idle'
  await clock.advance(6000)
  const ui = await $.ui.mount(PANE)
  expect(await ui.find({ text: /working/ })).toBeUndefined()
  expect(await ui.find({ text: /1 helper idle/ })).toBeDefined()
  // The dozing robot stays.
  expect(await ui.find({ key: 'x-ag-1' })).toBeDefined()
  await ui.unmount()
  const band = await $.ui.mount(BAND)
  expect(await band.find({ text: /all done/ })).toBeUndefined()
  expect(await band.find({ text: /1 idle/ })).toBeDefined()
  await band.unmount()
})

// --- L7: the commentator: talk.ts builds the request and reads the line, the module makes the call

test('core L7: a turn\'s end with the commentator on draws the one line the model wrote', async ($, on) => {
  const clock = mock.clock(on)
  const asked: string[] = []
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  on('tool.call', () => ({ result: 'ok' }))
  on('model.complete', (_$, e) => {
    asked.push((e as { prompt?: string }).prompt ?? '')
    return { value: { isAnswered: true, text: '"What a read of the config!"\nmore' } } as never
  })
  await $.command.run({ command: 'mission-talk', args: 'on' } as unknown as Args<'command.run'>)
  await $.turn.start({ text: 'go', turnId: 't' })
  await $.tool.call({ tool: 'Read', file_path: 'E:/w/config.ts' })
  await $.turn.complete({ answer: 'done', durationMs: 1000, isAborted: false, turnId: 't', reason: 'answer' })
  await clock.advance(10)
  expect(asked.length).toBe(1)
  expect(asked[0]).toContain('Read×1')
  const ui = await $.ui.mount(PANE)
  expect(await ui.find({ text: /What a read of the config!/ })).toBeDefined()
  await ui.unmount()
})


// --- L8: the main loop's own plan is reported as it goes and finished when the work is

const STEP = 'mcp__mission-control__step'
const RULE = `Report each step of your plan with ${STEP} as it finishes; report done = total when the work is over.`
const composeArgs = (tools: string[]) =>
  ({ model: 'claude-opus-5-5', promptModel: 'claude-opus-5-5', surfaces: [], tools, outputStyle: null, traits: [] }) as unknown as Args<'prompt.compose'>
const reportStep = ($: { tool: { call: (e: never) => Promise<unknown> } }, e: Record<string, unknown>) =>
  $.tool.call({ tool: STEP, ...e } as never)

test('core L8: an unfinished main plan rides beside the person\'s prompt with the rule, quoted, only with the step tool offered', async ($, on) => {
  mock.clock(on)
  const seen: string[] = []
  let offered = [ASK, STEP]
  on('tool.list', () => ({ value: offered.map(name => ({ name, description: 'x', mcp: true })) }))
  on('tool.call', () => ({ result: 'ok' }))
  on('prompt.submit', (_h, e) => {
    seen.push((e.context ?? []).join('\n'))
    return { text: e.text }
  })
  await reportStep($, { done: 1, steps: ['plan', 'Lane "builds"', 'c', 'd', 'e'] })
  await $.prompt.submit(prompt('fix the login bug on the settings page'))
  expect(seen[0]).toContain('a1 "fix the login bug on the settings page"')
  expect(seen[0]).toContain(`\nYour plan: step 2/5 "Lane 'builds'". ${RULE}`)
  // No ask tool: the plan line alone.
  offered = [STEP]
  await $.prompt.submit(prompt('add a dark theme toggle'))
  expect(seen[1]).toBe(`Your plan: step 2/5 "Lane 'builds'". ${RULE}`)
  // No step tool: no plan line.
  offered = [ASK]
  await $.prompt.submit(prompt('rename the settings page'))
  expect(seen[2]).not.toContain('Your plan')
  // A finished plan: nothing to nudge.
  offered = [ASK, STEP]
  await reportStep($, { done: 5 })
  await $.prompt.submit(prompt('write the release notes'))
  expect(seen[3]).not.toContain('Your plan')
  expect(seen[3]).toContain('a4 "write the release notes"')
})

test('core L8: the fixed section says the plan rule where the step tool is offered', async ($, on) => {
  mock.clock(on)
  on('prompt.compose', () => ({ sections: [{ id: 'core', text: 'core', scope: 'shared' as const }] }))
  const sectionOf = async (tools: string[]) =>
    (await $.prompt.compose(composeArgs(tools))).sections.find(s => s.id === 'mission-control:asks')?.text
  const asksOnly = await sectionOf(['Read', ASK])
  expect(asksOnly).toBeDefined()
  expect(asksOnly).not.toContain(STEP)
  expect(await sectionOf(['Read', ASK, STEP])).toBe(`${asksOnly} ${RULE}`)
  expect(await sectionOf(['Read', STEP])).toBe(RULE)
  expect(await sectionOf(['Read'])).toBeUndefined()
})

test('core L8: a plan reported done = total shows finished, then clears at the next turn', async ($, on) => {
  mock.clock(on)
  engineSpinner(on as never)
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  on('tool.call', () => ({ result: 'ok' }))
  await $.turn.start({ text: 'go', turnId: 't1' })
  await reportStep($, { done: 0, steps: ['plan', 'build', 'ship'] })
  await reportStep($, { done: 3 })
  const ui = await $.ui.mount(PANE)
  expect(await ui.find({ text: /3\/3/ })).toBeDefined()
  await ui.unmount()
  // A finished plan holds no step for the Spinner.
  const spin = await $.ui.mount(SPINNER as never)
  expect(await spin.find({ text: /step \d/ })).toBeUndefined()
  await spin.unmount()
  await $.turn.complete({ answer: 'ok', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })
  await $.turn.start({ text: 'next', turnId: 't2' })
  const after = await $.ui.mount(PANE)
  expect(await after.find({ text: /3\/3/ })).toBeUndefined()
  expect(await after.find({ text: /ship/ })).toBeUndefined()
  await after.unmount()
})

test('core L8: a new plan replaces the old one whole; the same plan sent again stays', async ($, on) => {
  const clock = mock.clock(on)
  on('tool.call', () => ({ result: 'ok' }))
  const card = async (re: RegExp) => {
    const ui = await $.ui.mount(PANE)
    const isShown = (await ui.find({ text: re })) !== undefined
    await ui.unmount()
    return isShown
  }
  await reportStep($, { done: 0, steps: ['scan', 'Lane builds', 'merge', 'test', 'ship'] })
  // The same plan again at step 0, by its count: the names stay.
  await reportStep($, { done: 0, total: 5 })
  expect(await card(/0\/5 · scan/)).toBe(true)
  await clock.advance(MIN)
  await reportStep($, { done: 1, note: 'lanes now' })
  expect(await card(/1\/5 · lanes now/)).toBe(true)
  // A new plan of the same length, named or not: none of the old names or notes.
  await reportStep($, { done: 0, total: 5 })
  expect(await card(/0\/5/)).toBe(true)
  expect(await card(/scan|Lane builds|lanes now/)).toBe(false)
  // A new plan with its own names, at step 0 over one still at step 0.
  await reportStep($, { done: 0, steps: ['alpha', 'beta', 'gamma', 'delta', 'omega'] })
  expect(await card(/0\/5 · alpha/)).toBe(true)
  await reportStep($, { done: 0, steps: ['one', 'two', 'three', 'four', 'five'] })
  expect(await card(/0\/5 · one/)).toBe(true)
  expect(await card(/alpha/)).toBe(false)
})
