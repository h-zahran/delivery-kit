import { expect, mock, test } from 'claude-code/testing'
import { costSpark, pushSample, runOut } from './forecast'
import type { Sample } from './forecast'
import { etaOf, pruneTracks, restartSteps, todoCount, trackSteps, workingRow } from './eta'
import type { StepTrack } from './eta'
import { batchesOf, receipt, timeline } from './summary'
import { parseStep } from './progress'
import { activityRows } from './timeline'
import { cellsOf, planParts, wrapWords } from './fit'

// An engine test loads the plugin and often draws the pane; on a busy machine
// that took up to 4 s of the default 5. A real hang still fails, at 15 s.
const ENGINE = { timeoutMs: 15_000 }

const MIN = 60_000
const HOUR = 60 * MIN
const LONE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/

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

// --- F7: a forecast needs 5 minutes and a 2-point rise

test('F7: the 5-hour meter projects nothing from 35 s and one point', async () => {
  let h: Sample[] = []
  for (let t = 0; t <= 40_000; t += 5_000) h = pushSample(h, { at: t, costUsd: 0, fiveHour: t >= 35_000 ? 41 : 40 })
  expect(runOut(h, 40_000, 'fiveHour', new Date(4 * HOUR).toISOString())).toBeUndefined()
})

test('F7: the weekly meter projects nothing from 70 to 71 in 35 s', async () => {
  let h: Sample[] = []
  for (const [t, v] of [[0, 70], [30_000, 70], [35_000, 71]] as const) h = pushSample(h, { at: t, costUsd: 0, sevenDay: v })
  expect(runOut(h, 40_000, 'sevenDay', new Date(3 * 86400_000).toISOString())).toBeUndefined()
})

test('F7: a span under 5 minutes or a rise under 2 points projects nothing; both met, it projects', async () => {
  const feed = (kind: 'fiveHour' | 'sevenDay', spanMs: number, from: number, to: number) => {
    const h: Sample[] = []
    const n = 10
    for (let i = 0; i <= n; i++) h.push({ at: (spanMs * i) / n, costUsd: 0, [kind]: from + ((to - from) * i) / n })
    return runOut(h, spanMs, kind)
  }
  for (const kind of ['fiveHour', 'sevenDay'] as const) {
    expect(feed(kind, 5 * MIN - 1, 40, 50)).toBeUndefined()
    expect(feed(kind, 10 * MIN, 40, 41.9)).toBeUndefined()
    const out = feed(kind, 5 * MIN, 40, 42)
    expect(out).toBeDefined()
    // 2 points in 5 min: 58 points left at 0.4/min is 145 min.
    expect(Math.round((out?.etaMs ?? 0) / MIN)).toBe(145)
  }
})

test('F7: after a window reset only the fresh minute counts, so nothing projects', async () => {
  let h: Sample[] = []
  const end = 20 * MIN
  for (let t = 0; t <= end; t += 5_000) {
    const v = t < end - 60_000 ? 80 : t < end - 10_000 ? 0 : 1
    h = pushSample(h, { at: t, costUsd: 0, fiveHour: v })
  }
  expect(runOut(h, end, 'fiveHour', new Date(end + 5 * HOUR).toISOString())).toBeUndefined()
})

// --- S19: history kept by age, not by count; percent never rounds up to 100

test('S19: heavy spend keeps 30 minutes of history, so the sparkline has no blanks', async () => {
  let h: Sample[] = []
  let cost = 0
  // Every 7 s: 30 minutes is no whole number of steps, so no sample sits on the edge.
  let end = 0
  for (let t = 0; t <= 40 * MIN; t += 7_000) {
    cost += 0.06
    h = pushSample(h, { at: t, costUsd: cost })
    end = t
  }
  // One sample older than 30 minutes stays: it anchors the window's first delta.
  const first = h[0] as Sample
  expect(first.at).toBeLessThan(end - 30 * MIN)
  expect(first.at).toBeGreaterThan(end - 30 * MIN - 7_000)
  expect((h[1] as Sample).at).toBeGreaterThanOrEqual(end - 30 * MIN)
  expect(costSpark(h, 18, end)).not.toContain(' ')
})

test('S19: a hard cap still bounds the history', async () => {
  let h: Sample[] = []
  for (let t = 0; t < 5_000; t++) h = pushSample(h, { at: t * 100, costUsd: t })
  expect(h.length).toBeLessThanOrEqual(720)
  expect(h.length).toBeGreaterThan(120)
})

test('S19: 199 of 200 steps reads 99%, not 100%', async () => {
  const todos = Array.from({ length: 200 }, (_, i) => ({ status: i < 199 ? 'completed' : 'pending' }))
  expect(workingRow({ todos, helpers: [], now: 0 })).toMatch(/^99% · step 200\/200/)
})

// --- F11: a turn's ETA starts with the turn; one sample is rough

test('F11: one measured step never says "running long", it stays rough', async () => {
  const t0 = 1_000_000
  const todos = (d: number) => Array.from({ length: 4 }, (_, i) => ({ status: i < d ? 'completed' : 'pending' }))
  let tr = trackSteps(undefined, todoCount(todos(0)), t0)
  tr = trackSteps(tr, todoCount(todos(1)), t0 + 3_000)
  expect(etaOf(tr, t0 + 180_000)?.isLong).toBe(false)
  const row = workingRow({ todos: todos(1), mainTrack: tr, helpers: [], now: t0 + 180_000 })
  expect(row).not.toContain('running long')
  expect(row).toMatch(/\?$/)
  // A second sample makes it a measurement.
  tr = trackSteps(tr, todoCount(todos(2)), t0 + 6_000)
  expect(workingRow({ todos: todos(2), mainTrack: tr, helpers: [], now: t0 + 180_000 })).toContain('running long')
})

test('F11: a track seeded at time 0 takes no duration from it', async () => {
  const now = 1_760_000_000_000
  let tr = trackSteps(undefined, { done: 0, total: 5 }, 0)
  tr = trackSteps(tr, { done: 0, total: 5 }, now)
  tr = trackSteps(tr, { done: 1, total: 5 }, now + 1000)
  expect(tr.marks.every(m => m.perStepMs < HOUR)).toBe(true)
  const row = workingRow({ todos: [], progress: { done: 1, total: 5 }, mainTrack: tr, helpers: [], now: now + 2000 }) ?? ''
  expect(row).not.toMatch(/\d{3,}h/)
  // A time of 0 is ignored once a real track exists.
  expect(trackSteps(tr, { done: 2, total: 5 }, 0)).toBe(tr)
  // A track that only ever saw time 0 shows no time on the step.
  const zero = trackSteps(undefined, { done: 1, total: 5 }, 0)
  expect(workingRow({ todos: [], progress: { done: 1, total: 5 }, mainTrack: zero, helpers: [], now })).toBe('20% · step 2/5')
})

test('F11: a new turn restarts the time on the current step and keeps the plan', ENGINE, async ($, on) => {
  const clock = mock.clock(on)
  engineSpinner(on as never)
  await clock.set(1_760_000_000_000)
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  // The main loop's step reports (tracks.main); two steps of a minute each.
  const step = (done: number) => $.tool.call({ tool: 'mcp__mission-control__step', done, total: 4 } as never)
  await $.turn.start({ text: 'go', turnId: 't1' })
  await step(0)
  await clock.advance(60_000)
  await step(1)
  await clock.advance(60_000)
  await step(2)
  await $.turn.complete({ answer: 'ok', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' } as never)
  await clock.advance(2 * HOUR)
  await $.turn.start({ text: 'more', turnId: 't2' })
  const ui = await $.ui.mount(SPINNER as never)
  expect(await ui.find({ text: /50% · step 3\/4 · 0s/ })).toBeDefined()
  expect(await ui.find({ text: /running long/ })).toBeUndefined()
  expect(await ui.find({ text: /2h00m/ })).toBeUndefined()
  // The measured steps survived the turn: the ETA keeps their pace.
  expect(await ui.find({ text: /~2m left/ })).toBeDefined()
  await ui.unmount()
})

test('F11: the main loop step tool before any turn seeds at the call, not at 0', ENGINE, async ($, on) => {
  const clock = mock.clock(on)
  engineSpinner(on as never)
  await clock.set(1_760_000_000_000)
  await $.tool.call({ tool: 'mcp__mission-control__step', done: 0, total: 5 } as never)
  await clock.advance(60_000)
  await $.tool.call({ tool: 'mcp__mission-control__step', done: 1, total: 5 } as never)
  await clock.advance(1_000)
  const ui = await $.ui.mount(SPINNER as never)
  expect(await ui.find({ text: /20% · step 2\/5 · 1s/ })).toBeDefined()
  expect(await ui.find({ text: /\d{3,}h/ })).toBeUndefined()
  await ui.unmount()
})

test('F11: a turn start restarts both main tracks, keeps their marks, and leaves helpers alone', async () => {
  const mark = { at: 50, n: 1, perStepMs: 40 }
  const tr: StepTrack = { startedAt: 10, lastAt: 50, done: 1, total: 3, marks: [mark] }
  const out = restartSteps({ main: tr, 'main:todos': tr, 'ag-1': tr }, 9_000)
  expect(out.main).toEqual({ ...tr, lastAt: 9_000 })
  expect(out['main:todos']).toEqual({ ...tr, lastAt: 9_000 })
  expect(out['ag-1']).toBe(tr)
  const helpers = { 'ag-1': tr }
  expect(restartSteps(helpers, 9_000)).toBe(helpers)
})

// --- C2: helpers with no progress do not hide the others' ETA

test('C2: the known helpers keep their ETA, the rest are counted as unknown', async () => {
  const t0 = 1_000_000
  let a = trackSteps(undefined, { done: 0, total: 4 }, t0)
  a = trackSteps(a, { done: 2, total: 4 }, t0 + 60_000)
  let b = trackSteps(undefined, { done: 0, total: 6 }, t0)
  b = trackSteps(b, { done: 3, total: 6 }, t0 + 90_000)
  const row = workingRow({
    todos: [],
    helpers: [{ status: 'running', track: a }, { status: 'running', track: b }, { status: 'running' }],
    now: t0 + 90_000,
  })
  expect(row).toBe('3 helpers working · 2 ~2m left (1 unknown)')
  // Every helper known: the plain ETA, as before.
  expect(workingRow({ todos: [], helpers: [{ status: 'running', track: b }], now: t0 + 90_000 })).toBe('1 helper working · ~2m left')
  // None known: just the count.
  expect(workingRow({ todos: [], helpers: [{ status: 'running' }, { status: 'running' }], now: t0 })).toBe('2 helpers working')
})

// --- S20: tracks follow the agent list

test('S20: tracks of agents no longer listed are dropped, main stays', async () => {
  const tr: StepTrack = { startedAt: 1, lastAt: 1, done: 0, total: 3, marks: [] }
  const all = { main: tr, 'main:todos': tr, a: tr, b: tr, c: tr }
  expect(Object.keys(pruneTracks(all, ['a', 'c'])).sort()).toEqual(['a', 'c', 'main', 'main:todos'])
  // Nothing to drop: the same object, so an atom update can skip the write.
  const kept = { main: tr, a: tr }
  expect(pruneTracks(kept, ['a', 'b'])).toBe(kept)
})

// --- F10: an idle helper does not hold its batch open

test('F10: an idle helper ends at its last activity, so a later helper starts a new batch', async () => {
  const idle = {
    id: 'a', status: 'idle' as const, startedAt: 0, costUsd: 0.1, toolCount: 1,
    tools: [{ startedAt: 10_000, endedAt: 120_000 }],
  }
  const later = { id: 'b', status: 'done' as const, startedAt: 2 * HOUR, endedAt: 2 * HOUR + 60_000, costUsd: 0.2, toolCount: 1 }
  const now = 2 * HOUR + 61_000
  const bs = batchesOf([idle, later], now)
  expect(bs.map(b => b.ids)).toEqual([['a'], ['b']])
  expect(bs[0]?.endedAt).toBe(120_000)
  expect(receipt(bs[0]!)).toContain('2:00 wall')
  // The idle helper's bar stops where its work stopped.
  const two = { ...later, id: 'c', startedAt: 0, endedAt: 240_000 }
  const [b] = batchesOf([idle, two], now)
  const bars = timeline(b!, [idle, two], 10, now)
  expect(bars.find(r => r.id === 'a')?.bar).toBe('━━━━━     ')
})

test('F10: an idle helper with no tools ends where it started; a running one stays open', async () => {
  const idle = { id: 'a', status: 'idle' as const, startedAt: 5_000, costUsd: 0, toolCount: 0 }
  const [b] = batchesOf([idle], HOUR)
  expect(b?.endedAt).toBe(5_000)
  const run = { id: 'r', status: 'running' as const, startedAt: 5_000, costUsd: 0, toolCount: 0 }
  expect(batchesOf([run], HOUR)[0]?.endedAt).toBeUndefined()
})

// --- S1: notes cut by code point

test('S1: a note cut at its limit never splits an emoji', async () => {
  const s = parseStep({ done: 1, note: 'a'.repeat(38) + '😀😀 tail', steps: ['b'.repeat(22) + '😀 more'] })
  expect(LONE.test(s?.note ?? '')).toBe(false)
  expect(LONE.test(s?.steps?.[0] ?? '')).toBe(false)
  expect(s?.note?.endsWith('…')).toBe(true)
  expect(Array.from(s?.note ?? '').length).toBeLessThanOrEqual(40)
})

// --- S2: widths in terminal cells

test('S2: wide characters count 2 cells, combining marks and joiners 0', async () => {
  expect(cellsOf('项目')).toBe(4)
  expect(cellsOf('ｱＡ')).toBe(3)
  expect(cellsOf('e\u0301')).toBe(1)
  expect(cellsOf('😀')).toBe(2)
  expect(cellsOf('👨\u200D👩\u200D👧')).toBe(2)
  // Every glyph the pane draws stays one cell.
  expect(cellsOf('■□▣●○◉━╸╺✓✗•…⠋')).toBe(14)
})

test('S2: an activity label is exactly its width in cells', async () => {
  const rows = [
    { id: '1', tool: 'Read', label: 'D:/项目/配置文件读取器.ts', owner: 'main', status: 'ok' as const, startedAt: 0, endedAt: 5000 },
    { id: '2', tool: 'Read', label: 'D:/项目', owner: 'main', status: 'ok' as const, startedAt: 0, endedAt: 4000 },
    { id: '3', tool: 'Read', label: 'D:/a项', owner: 'main', status: 'ok' as const, startedAt: 0, endedAt: 3000 },
  ]
  for (const w of [20, 13, 12]) for (const r of activityRows(rows, 10_000, w, 8)) expect(cellsOf(r.label)).toBe(w)
})

test('S2: the plan row and wrapped words fit their width in cells', async () => {
  // 20..26 put the cut on a space, a wide character's middle, and past it.
  for (let w = 20; w <= 26; w++) {
    const parts = planParts(['实现设计', '运行测试', '发布版本'], 1, w)
    expect(parts.reduce((n, p) => n + cellsOf(p.text), 0)).toBeLessThanOrEqual(w)
  }
  for (const line of wrapWords('配置文件读取器 实现设计和运行测试', 6, 9)) expect(cellsOf(line)).toBeLessThanOrEqual(6)
  // A width of one still ends: a wide character takes its own line.
  expect(wrapWords('项目', 1, 9).length).toBe(2)
})

// --- S3: MCP server names with underscores

test('S3: an MCP tool shows as server:tool even when the server name has underscores', async () => {
  const row = (tool: string) => ({ id: tool, tool, label: '', owner: 'main', status: 'ok' as const, startedAt: 0, endedAt: 5000 })
  const [a, b, c] = activityRows(
    [row('mcp__claude_ai_Claude_Docs__batch'), row('mcp__plugin_RevenueCat_RevenueCat__create-app'), row('mcp__mission-control__step')],
    10_000, 40, 8,
  )
  expect(a?.label.trim()).toBe('claude_ai_Claude_Docs:batch')
  expect(b?.label.trim()).toBe('plugin_RevenueCat_RevenueCat:create-app')
  expect(c?.label.trim()).toBe('mission-control:step')
})
