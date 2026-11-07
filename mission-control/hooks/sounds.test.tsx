import { mock, test, expect } from 'claude-code/testing'
import type { Engine, MockClock } from 'claude-code/testing'
import type { Args, On } from 'claude-code'

// When the "done" sound plays, and the switch that turns every sound off.
// Each test plays as Windows: the clip runs through process.run, which the
// test records. A test that expects silence then makes one sound play, so a
// recorder that hears nothing cannot pass it.

const ENGINE = { timeoutMs: 15_000 }

const spawnArgs = (description: string) =>
  ({
    tool_use_id: `tu-${description}`,
    prompt: description,
    description,
    subagentType: 'Explore',
  }) as unknown as Args<'agent.spawn'>

/** Hooks every test needs, registered before the first `$` call; returns the clips played. */
function setUp(on: On): string[] {
  const played: string[] = []
  on('env.get', () => ({ value: 'Windows_NT' }))
  on('process.run', (_$, e) => {
    played.push(e.init?.env?.MC_SOUND ?? '')
    return { value: { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('turn.start', (_$, e) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'ag-1' }))
  on('classic.Notification', () => ({}))
  on('ui.toast', () => ({ value: undefined }))
  return played
}

/** The sound starts in its own dispatch: let it run. */
async function settle(clock: MockClock): Promise<void> {
  await clock.settle()
  for (let i = 0; i < 50; i++) await Promise.resolve()
}

const done = (played: string[]) => played.filter(p => p.endsWith('sounds/done.wav')).length

type Reason = 'answer' | 'aborted' | 'error'
const end = (turnId: string, reason: Reason, agentId?: string) =>
  ({
    answer: reason === 'answer' ? 'ok' : '',
    durationMs: 61_000,
    isAborted: reason === 'aborted',
    turnId,
    reason,
    ...(agentId ? { agentId } : {}),
  }) as unknown as Args<'turn.complete'>

/** One long main turn, a minute and more, that ends for `reason`. */
async function longTurn($: Engine, clock: MockClock, id: string, reason: Reason): Promise<void> {
  await $.turn.start({ text: 'go', turnId: id })
  await clock.advance(61_000)
  await $.turn.complete(end(id, reason))
  await settle(clock)
}

test('sounds: a long main turn that answered plays "done"', ENGINE, async ($, on) => {
  const clock = mock.clock(on, { now: 1000 })
  const played = setUp(on)
  await longTurn($, clock, 't1', 'answer')
  expect(done(played)).toBe(1)
})

test('sounds: a long main turn stopped by Esc plays nothing', ENGINE, async ($, on) => {
  const clock = mock.clock(on, { now: 1000 })
  const played = setUp(on)
  await longTurn($, clock, 't1', 'aborted')
  expect(done(played)).toBe(0)
  // The recorder hears a sound: the next long turn answers.
  await clock.advance(11_000)
  await longTurn($, clock, 't2', 'answer')
  expect(done(played)).toBe(1)
})

test('sounds: a long main turn ended by an error plays nothing', ENGINE, async ($, on) => {
  const clock = mock.clock(on, { now: 1000 })
  const played = setUp(on)
  await longTurn($, clock, 't1', 'error')
  expect(done(played)).toBe(0)
  await clock.advance(11_000)
  await longTurn($, clock, 't2', 'answer')
  expect(done(played)).toBe(1)
})

test('sounds: helpers that end while the main loop works play nothing; the main end does', ENGINE, async ($, on) => {
  const clock = mock.clock(on, { now: 1000 })
  const played = setUp(on)
  await $.turn.start({ text: 'go', turnId: 'm' })
  await $.agent.spawn(spawnArgs('find auth'))
  await clock.advance(61_000)
  await $.turn.complete(end('h1', 'answer', 'ag-1'))
  await settle(clock)
  expect(done(played)).toBe(0)
  await clock.advance(11_000)
  await $.turn.complete(end('m', 'answer'))
  await settle(clock)
  expect(done(played)).toBe(1)
})

test('sounds: helpers that end with the main loop idle play "done"', ENGINE, async ($, on) => {
  const clock = mock.clock(on, { now: 1000 })
  const played = setUp(on)
  await $.agent.spawn(spawnArgs('find auth'))
  await clock.advance(5000)
  await $.turn.complete(end('h1', 'answer', 'ag-1'))
  await settle(clock)
  expect(done(played)).toBe(1)
})

// The off switch: the `sounds` option (/config). Off, no clip plays at all.
async function everySound($: Engine, clock: MockClock): Promise<void> {
  await $.classic.Notification({ message: 'Claude needs your permission', notification_type: 'permission_prompt' })
  await settle(clock)
  await longTurn($, clock, 't1', 'answer')
  await clock.advance(11_000)
  await $.agent.spawn(spawnArgs('find auth'))
  await $.turn.complete(end('h1', 'answer', 'ag-1'))
  await settle(clock)
}

test('sounds: with the sounds option off, nothing plays', { ...ENGINE, options: { sounds: false } }, async ($, on) => {
  const clock = mock.clock(on, { now: 1000 })
  const played = setUp(on)
  await everySound($, clock)
  expect(played).toEqual([])
})

test('sounds: with the sounds option on, each sound plays', { ...ENGINE, options: { sounds: true } }, async ($, on) => {
  const clock = mock.clock(on, { now: 1000 })
  const played = setUp(on)
  await everySound($, clock)
  expect(played.filter(p => p.endsWith('sounds/needs-you.wav')).length).toBe(1)
  expect(done(played)).toBe(2)
})
