import { expect, mock, test } from 'claude-code/testing'
import type { AgentInfo, On } from 'claude-code'

// An engine test loads the plugin and often draws the pane; on a busy machine
// that took up to 4 s of the default 5. A real hang still fails, at 15 s.
const ENGINE = { timeoutMs: 15_000 }

// A loop no agent.spawn announced: a forked skill (the engine lists it) or an
// engine fork, compaction or memory (no list names it). The first gets a robot
// at its first event; the second never does.

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

const STEP = 'mcp__mission-control__step'
const inFork = { agentId: 'ag-f' }
const listed: AgentInfo = { id: 'ag-f', description: 'review the diff', type: 'code-review', status: 'running' }

type Run = { id: string; description: string; type: string; model: string; status: string; toolCount: number; parentId?: string; progress?: { done: number; total: number } }
// The last value the plugin wrote under `agents`, seen from beneath.
const agentWrites = (on: On) => {
  let last: Run[] = []
  ;(on as unknown as (k: string, f: (_: unknown, e: { key?: string; value?: unknown }, next: (e: unknown) => unknown) => unknown) => void)(
    'state.set',
    (_, e, next) => {
      if (e.key === 'agents') last = e.value as Run[]
      return next(e)
    },
  )
  return () => last
}

// The engine's list, counting how often the plugin asks for it.
const agentList = (on: On, value: () => AgentInfo[]) => {
  let calls = 0
  on('agent.list', () => {
    calls++
    return { value: value() }
  })
  return () => calls
}

test('forked: a listed loop with no spawn gets a robot at its first tool call, and its end finishes it', ENGINE, async ($, on) => {
  mock.clock(on)
  const agents = agentWrites(on)
  agentList(on, () => [listed])
  on('tool.call', () => ({ result: 'ok' }))
  on('turn.complete', () => ({ text: '' }))

  await $.tool.call({ tool: 'Grep', pattern: 'login', ...inFork } as never)
  await $.tool.call({ tool: 'Read', file_path: 'D:/w/auth.ts', ...inFork } as never)

  const run = agents().find(a => a.id === 'ag-f')
  expect(run?.description).toBe('review the diff')
  expect(run?.type).toBe('code-review')
  expect(run?.status).toBe('running')
  expect(run?.toolCount).toBe(2)
  const ui = await $.ui.mount(PANE)
  expect(await ui.find({ text: /review the diff/ })).toBeDefined()
  await ui.unmount()

  await $.turn.complete({ answer: 'two findings', durationMs: 1000, isAborted: false, turnId: 't-1', agentId: 'ag-f', reason: 'answer' })
  expect(agents().find(a => a.id === 'ag-f')?.status).toBe('done')
  const after = await $.ui.mount(PANE)
  expect(await after.find({ text: /DONE/ })).toBeDefined()
  await after.unmount()
})

test('forked: an id no list names gets no robot, and the plugin asks for the list about it once', ENGINE, async ($, on) => {
  mock.clock(on)
  const agents = agentWrites(on)
  const calls = agentList(on, () => [])
  on('tool.call', () => ({ result: 'ok' }))
  on('turn.complete', () => ({ text: '' }))

  await $.tool.call({ tool: 'Read', file_path: 'D:/w/a.ts', agentId: 'compact-1' } as never)
  await $.tool.call({ tool: 'Read', file_path: 'D:/w/b.ts', agentId: 'compact-1' } as never)
  await $.turn.complete({ answer: 'summary', durationMs: 10, isAborted: false, turnId: 't-1', agentId: 'compact-1', reason: 'answer' })

  expect(agents().some(a => a.id === 'compact-1')).toBe(false)
  expect(calls()).toBe(1)
})

test('forked: an id the list names late gets its robot once 10 s have passed since the miss', ENGINE, async ($, on) => {
  const clock = mock.clock(on)
  const agents = agentWrites(on)
  let isListed = false
  const calls = agentList(on, () => (isListed ? [listed] : []))
  on('tool.call', () => ({ result: 'ok' }))

  await $.tool.call({ tool: 'Grep', pattern: 'a', ...inFork } as never)
  isListed = true
  await clock.advance(9_000)
  await $.tool.call({ tool: 'Grep', pattern: 'b', ...inFork } as never)
  expect(agents().some(a => a.id === 'ag-f')).toBe(false)
  expect(calls()).toBe(1)

  await clock.advance(1_000)
  await $.tool.call({ tool: 'Grep', pattern: 'c', ...inFork } as never)
  expect(agents().find(a => a.id === 'ag-f')?.toolCount).toBe(1)
  expect(calls()).toBe(2)
})

test('forked: two calls at once from a new loop make one robot that counts both, from one look at the list', ENGINE, async ($, on) => {
  mock.clock(on)
  const agents = agentWrites(on)
  const calls = agentList(on, () => [listed])
  on('tool.call', () => ({ result: 'ok' }))

  await Promise.all([
    $.tool.call({ tool: 'Grep', pattern: 'a', tool_use_id: 'tu-a', ...inFork } as never),
    $.tool.call({ tool: 'Grep', pattern: 'b', tool_use_id: 'tu-b', ...inFork } as never),
  ])

  const runs = agents().filter(a => a.id === 'ag-f')
  expect(runs.length).toBe(1)
  expect(runs[0]?.toolCount).toBe(2)
  expect(calls()).toBe(1)
})

test('forked: a spawn that lands while a join looks keeps its own robot', ENGINE, async ($, on) => {
  mock.clock(on)
  const agents = agentWrites(on)
  let release = () => {}
  const gate = new Promise<void>(r => (release = r))
  let looking = () => {}
  const isLooking = new Promise<void>(r => (looking = r))
  on('agent.list', async () => {
    looking()
    await gate
    return { value: [{ id: 'ag-1', description: 'seen by the list', type: 'general-purpose', status: 'running' }] }
  })
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'ag-1' }))
  on('tool.call', () => ({ result: 'ok' }))

  // The helper's first call arrives before its spawn wrote the robot.
  const early = $.tool.call({ tool: 'Grep', pattern: 'x', agentId: 'ag-1' } as never)
  await isLooking
  await $.agent.spawn({ tool_use_id: 'tu-s', prompt: 'look', description: 'look around', subagentType: 'Explore' } as never)
  release()
  await early

  const runs = agents().filter(a => a.id === 'ag-1')
  expect(runs.length).toBe(1)
  expect(runs[0]?.description).toBe('look around')
  expect(runs[0]?.type).toBe('Explore')
})

test('forked: a step report as the first call makes the robot and keeps the plan', ENGINE, async ($, on) => {
  mock.clock(on)
  const agents = agentWrites(on)
  agentList(on, () => [listed])

  await $.tool.call({ tool: STEP, done: 1, total: 3, ...inFork } as never)

  const run = agents().find(a => a.id === 'ag-f')
  expect(run?.description).toBe('review the diff')
  expect(run?.progress?.done).toBe(1)
  expect(run?.progress?.total).toBe(3)
})

test('forked: a model step as the first event makes the robot with that step\'s model', ENGINE, async ($, on) => {
  mock.clock(on)
  const agents = agentWrites(on)
  agentList(on, () => [listed])
  on('turn.step', async function* (_, e) {
    return {
      turnId: e.turnId,
      index: e.index,
      answer: '',
      toolUses: [],
      stopReason: 'end_turn',
      usage: { model: 'claude-sonnet-5-5', input_tokens: 1000, output_tokens: 10 },
    } as never
  })

  const stream = $.turn.step({ turnId: 't-1', index: 0, model: 'claude-sonnet-5-5', messageCount: 1, ...inFork })
  for await (const _ of stream) {
    // No chunks: the step answers with its result alone.
  }
  await stream.result

  const run = agents().find(a => a.id === 'ag-f')
  expect(run?.description).toBe('review the diff')
  expect(run?.model).toBe('claude-sonnet-5-5')
})

test('forked: a loop whose one model step failed, with no usage, still shows, as failed', ENGINE, async ($, on) => {
  mock.clock(on)
  const agents = agentWrites(on)
  agentList(on, () => [listed])
  on('turn.step', async function* (_, e) {
    return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null } as never
  })
  on('turn.complete', () => ({ text: '' }))

  const stream = $.turn.step({ turnId: 't-1', index: 0, model: 'claude-sonnet-5-5', messageCount: 1, ...inFork })
  for await (const _ of stream) {
    // No chunks: the step answers with its result alone.
  }
  await stream.result
  await $.turn.complete({ answer: '', durationMs: 10, isAborted: false, turnId: 't-1', agentId: 'ag-f', reason: 'error' } as never)

  expect(agents().find(a => a.id === 'ag-f')?.status).toBe('failed')
})

test('forked: a spawned helper is still made by its spawn, and its calls ask for no list', ENGINE, async ($, on) => {
  mock.clock(on)
  const agents = agentWrites(on)
  const calls = agentList(on, () => [])
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'ag-1' }))
  on('tool.call', () => ({ result: 'ok' }))

  await $.agent.spawn({ tool_use_id: 'tu-s', prompt: 'look', description: 'look around', subagentType: 'Explore' } as never)
  await $.tool.call({ tool: 'Grep', pattern: 'x', agentId: 'ag-1' } as never)

  expect(agents().find(a => a.id === 'ag-1')?.toolCount).toBe(1)
  expect(calls()).toBe(0)
})
