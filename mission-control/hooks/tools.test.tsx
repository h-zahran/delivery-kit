import { expect, mock, test } from 'claude-code/testing'
import type { Args } from 'claude-code'
import { playersFor } from './chime'
import { normPath, pathKey, treeLines } from './filetree'

// An engine test loads the plugin and often draws the pane; on a busy machine
// that took up to 4 s of the default 5. A real hang still fails, at 15 s.
const ENGINE = { timeoutMs: 15_000 }

const PANE = {
  plugin: 'mission-control',
  component: 'Pane',
  requestId: 'mission-control',
  props: {
    title: 'Mission Control',
    isFocused: false,
    bodyColumns: 70,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 80 },
    view: {},
  },
} as const

const BAND = {
  plugin: 'mission-control',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: true, maxRows: 4, bodyColumns: 100, scroll: { offset: 0, bodyRows: 4 }, view: {} },
} as const

const ok = { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
const startArgs = { cwd: 'D:/w', surface: 'terminal', isInteractive: true } as unknown as Args<'session.start'>
const usageOf = (startedAt: number) => ({ startedAt, context: { window: 200_000, percent: 1, tokens: 10 }, rateLimits: [] })

// --- F4: the sound's path travels in the environment, never inside the script

test('tools: chime on Windows passes the path as MC_SOUND to a fixed script', async () => {
  const path = 'C:/Users/O\u2019Brien/it\'s/sounds/done.wav'
  const [win] = playersFor('windows', path)
  expect(win!.argv[0]).toBe('C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe')
  expect(win!.argv[win!.argv.length - 1]).toBe('(New-Object System.Media.SoundPlayer $env:MC_SOUND).PlaySync()')
  expect(win!.argv.join(' ')).not.toContain('Brien')
  expect(win!.env).toEqual({ MC_SOUND: path })
  // Linux: the players and their argv as before, no environment.
  expect(playersFor('linux', '/m/done.wav')).toEqual([
    { argv: ['paplay', '/m/done.wav'] },
    { argv: ['pw-play', '/m/done.wav'] },
    { argv: ['aplay', '-q', '/m/done.wav'] },
  ])
})

test('tools: the engine runs PowerShell with MC_SOUND set and the script fixed', ENGINE, async ($, on) => {
  mock.clock(on)
  mock.env(on, { OS: 'Windows_NT' })
  const runs: { argv: string[]; env?: Record<string, string> }[] = []
  on('process.run', (_$, e) => {
    runs.push({ argv: [...e.argv], env: e.init?.env })
    return { value: ok }
  })
  on('classic.Notification', () => ({}))
  await $.classic.Notification({ message: 'Claude needs your permission', notification_type: 'permission_prompt' })
  for (let i = 0; i < 50 && runs.length === 0; i++) await Promise.resolve()
  expect(runs.length).toBe(1)
  expect(runs[0]!.argv[runs[0]!.argv.length - 1]).toBe('(New-Object System.Media.SoundPlayer $env:MC_SOUND).PlaySync()')
  expect(runs[0]!.env?.MC_SOUND ?? '').toMatch(/sounds\/needs-you\.wav$/)
})

// --- S13: the real home folds to ~ in every line, nobody else's

test('tools: treeLines folds the real home in every line, and only it', async () => {
  const now = 10_000_000
  const names = (files: Parameters<typeof treeLines>[0], home?: string) =>
    treeLines(files, 60, { now, ...(home ? { home } : {}) }).map(l => l.name)
  const mixed = names(
    [
      { path: 'C:\\Users\\hzahran\\proj\\a.ts', kind: 'edit', at: now },
      { path: 'C:\\tmp\\b.ts', kind: 'read', at: now },
    ],
    'C:\\Users\\hzahran',
  )
  expect(mixed.join('|')).not.toMatch(/hzahran/i)
  expect(mixed.some(n => n.startsWith('~'))).toBe(true)
  // The case of the drive and the folders does not matter on Windows.
  expect(names([{ path: 'c:/users/HZAHRAN/proj/a.ts', kind: 'edit', at: now }], 'C:\\Users\\hzahran')[0]).toBe('~\\proj')
  // Another person's folder, or Public, keeps its name.
  expect(names([{ path: 'C:\\Users\\Public\\Documents\\x.txt', kind: 'read', at: now }], 'C:\\Users\\hzahran')[0]).toBe(
    'C:\\Users\\Public\\Documents',
  )
  expect(names([{ path: 'C:\\Users\\Public\\Documents\\x.txt', kind: 'read', at: now }])[0]).toBe('C:\\Users\\Public\\Documents')
  // POSIX homes, case-sensitive.
  expect(names([{ path: '/home/me/src/a.ts', kind: 'edit', at: now }], '/home/me')[0]).toBe('~/src')
  expect(names([{ path: '/home/Me/src/a.ts', kind: 'edit', at: now }], '/home/me')[0]).toBe('/home/Me/src')
  // A path that only starts with the same letters is not under home.
  expect(names([{ path: 'C:\\Users\\hzahran2\\a.ts', kind: 'edit', at: now }], 'C:\\Users\\hzahran')[0]).toBe(
    'C:\\Users\\hzahran2',
  )
  // The full path stays real for whoever reads it.
  const l = treeLines([{ path: 'C:\\Users\\hzahran\\proj\\a.ts', kind: 'edit', at: now }], 60, { now, home: 'C:\\Users\\hzahran' })
  expect(l.find(x => !x.isDir)?.path).toBe('C:\\Users\\hzahran\\proj\\a.ts')
})

// --- S14: one file, one entry, however the path was spelled

test('tools: paths normalise: \\\\?\\UNC, .., Git Bash drives, case on Windows', async () => {
  expect(normPath('\\\\?\\UNC\\srv\\share\\x.ts')).toBe('\\\\srv\\share\\x.ts')
  expect(normPath('\\\\?\\C:\\a\\b.ts')).toBe('C:\\a\\b.ts')
  expect(normPath('E:\\a\\..\\b\\.\\f.ts')).toBe('E:\\b\\f.ts')
  expect(normPath('e:/a/b.ts')).toBe('E:\\a\\b.ts')
  expect(normPath('/srv/app/../lib/x.ts')).toBe('/srv/lib/x.ts')
  expect(normPath('/e/Github/a.ts', { drives: true })).toBe('E:\\Github\\a.ts')
  expect(normPath('/e/Github/a.ts')).toBe('/e/Github/a.ts')
  expect(normPath('/dev/null', { drives: true })).toBe('/dev/null')
  expect(pathKey('E:\\G\\A.ts')).toBe(pathKey('e:/g/a.ts'))
  expect(pathKey('/e/g/a.ts', { drives: true })).toBe(pathKey('E:\\G\\a.ts'))
  expect(pathKey('/srv/A.ts')).not.toBe(pathKey('/srv/a.ts'))
  const now = 1000
  const tree = treeLines(
    [
      { path: '/e/Github/a.ts', kind: 'edit', at: now, owner: 'main', editors: ['main'] },
      { path: 'E:\\Github\\a.ts', kind: 'edit', at: now, owner: 'ag-1', editors: ['ag-1'] },
      { path: 'E:\\x\\..\\Github\\a.ts', kind: 'edit', at: now, owner: 'ag-1', editors: ['ag-1'] },
    ],
    60,
    { now, drives: true },
  )
  const files = tree.filter(l => !l.isDir)
  expect(files.length).toBe(1)
  expect(files[0]!.clash).toBe(true)
})

// --- F9: a touch counts only when the call went through; only edit tools edit

test('tools: a denied or failed edit is not a touch; a non-edit tool reads', ENGINE, async ($, on) => {
  mock.clock(on)
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'ag-1' }))
  on('tool.call', ($, e) =>
    field(e, 'file_path').includes('denied')
      ? { deny: 'no' }
      : field(e, 'file_path').includes('broken')
        ? { result: 'old_string not found', isError: true }
        : { result: 'ok' },
  )
  await $.tool.call({ tool: 'Edit', file_path: 'D:/w/denied.ts', old_string: 'a', new_string: 'b' })
  await $.tool.call({ tool: 'Write', file_path: 'D:/w/broken.ts', content: 'x' } as never)
  const none = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await none.find({ text: /nothing touched yet/ })).toBeDefined()
  await none.unmount()

  // A tool outside the edit list that names a file only reads it: no clash with main's edit.
  await $.agent.spawn({ tool_use_id: 'tu-1', prompt: 'look', description: 'look', subagentType: 'Explore' } as unknown as Args<'agent.spawn'>)
  await $.tool.call({ tool: 'Edit', file_path: 'D:/w/a.ts', old_string: 'a', new_string: 'b' })
  await $.tool.call({ tool: 'mcp__lint__check', file_path: 'D:/w/a.ts', agentId: 'ag-1' } as never)
  await $.tool.call({ tool: 'mcp__lint__check', file_path: 'D:/w/b.ts', agentId: 'ag-1' } as never)
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ text: /1 edit · 1 read/ })).toBeDefined()
  expect(await ui.find({ text: /! a\.ts/ })).toBeUndefined()
  await ui.unmount()
})

test('tools: one file spelled three ways is one entry, and two editors clash', ENGINE, async ($, on) => {
  mock.clock(on)
  on('session.start', () => ({ cwd: 'D:/w' }))
  mock.env(on, { OS: 'Windows_NT' })
  on('tool.call', () => ({ result: 'ok' }))
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'ag-1' }))
  await $.session.start(startArgs).catch(() => undefined)
  await $.agent.spawn({ tool_use_id: 'tu-1', prompt: 'fix', description: 'fix', subagentType: 'general-purpose' } as unknown as Args<'agent.spawn'>)
  await $.tool.call({ tool: 'Edit', file_path: 'E:\\w\\a.ts', old_string: 'a', new_string: 'b' })
  await $.tool.call({ tool: 'Edit', file_path: 'e:/w/x/../a.ts', old_string: 'a', new_string: 'b', agentId: 'ag-1' } as never)
  await $.tool.call({ tool: 'Read', file_path: '/e/w/A.ts' })
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ text: /1 edit · 0 read/ })).toBeDefined()
  expect(await ui.find({ text: /! a\.ts/ })).toBeDefined()
  await ui.unmount()
})

// --- F8: another call's end does not clear the dialog it did not open

test('tools: a parallel call ending leaves "needs your OK"; the asking tool clears it', ENGINE, async ($, on) => {
  const clock = mock.clock(on)
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('classic.PermissionRequest', () => ({}))
  on('tool.call', () => ({ result: 'ok' }))
  await $.turn.start({ text: 'go', turnId: 't-main' })
  await $.classic.PermissionRequest({ tool_name: 'Bash', tool_input: { command: 'git push' } })
  await $.tool.call({ tool: 'Read', file_path: 'D:/w/a.ts' })
  await clock.advance(2000)
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ text: /NEEDS YOUR OK/ })).toBeDefined()
  await ui.unmount()
  await $.tool.call({ tool: 'Bash', command: 'git push', description: 'push' })
  const after = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await after.find({ text: /NEEDS YOUR OK/ })).toBeUndefined()
  await after.unmount()
})

// --- S10: TodoWrite keeps its own track; the step tool keeps main's

test('tools: a TodoWrite does not wipe the step reports\' time left', ENGINE, async ($, on) => {
  const clock = mock.clock(on)
  on('tool.call', () => ({ result: 'ok' }))
  const step = (done: number) => $.tool.call({ tool: 'mcp__mission-control__step', done, total: 4 } as never)
  await step(0)
  await clock.advance(60_000)
  await step(1)
  await clock.advance(60_000)
  await step(2)
  // An empty todo list: the pane still draws the step plan, with its time left.
  await $.tool.call({ tool: 'TodoWrite', todos: [] })
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ text: /2\/4/ })).toBeDefined()
  expect(await ui.find({ text: /~2m left/ })).toBeDefined()
  await ui.unmount()
})

// --- S6 / S7: the clock and the band never throw, and one failed register stops nothing

test('tools: one failed command.register still registers the tools and starts the clock', ENGINE, async ($, on) => {
  const clock = mock.clock(on)
  on('session.start', () => ({ cwd: 'D:/w' }))
  const tools: string[] = []
  let opened = 0
  on('command.register', () => {
    throw new Error('no commands here')
  })
  on('tool.register', (_$, e) => {
    tools.push(e.name)
    return { value: undefined } as never
  })
  on('session.usage', () => ({ value: usageOf(5) }))
  on('ui.panes', () => ({ value: [] }))
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text key="engine-band">engine</Text>
  })
  on('ui.open', () => {
    opened++
    return { value: { isPlaced: true } }
  })
  await $.session.start(startArgs).catch(() => undefined)
  expect(tools.length).toBe(2)
  // The band asks for the pane; the clock opens it, outside the drawing.
  const band = await $.ui.mount({ ...BAND, surface: 'terminal', viewport: { columns: 100, rows: 40, isFullscreen: true } } as never)
  await band.unmount()
  expect(opened).toBe(0)
  await clock.advance(1000)
  expect(opened).toBe(1)
  // Once per session: the next fullscreen band asks for nothing more.
  const again = await $.ui.mount({ ...BAND, surface: 'terminal', viewport: { columns: 100, rows: 40, isFullscreen: true } } as never)
  await again.unmount()
  await clock.advance(5000)
  expect(opened).toBe(1)
})

test('tools: /clear starts a new session, so the pane opens itself once more', ENGINE, async ($, on) => {
  const clock = mock.clock(on)
  on('session.start', () => ({ cwd: 'D:/w' }))
  let startedAt = 5
  let opened = 0
  on('turn.complete', () => ({ text: '' }))
  on('session.usage', () => ({ value: usageOf(startedAt) }))
  on('ui.panes', () => ({ value: [] }))
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text key="engine-band">engine</Text>
  })
  on('ui.open', () => {
    opened++
    return { value: { isPlaced: true } }
  })
  await $.session.start(startArgs).catch(() => undefined)
  const band = await $.ui.mount({ ...BAND, surface: 'terminal', viewport: { columns: 100, rows: 40, isFullscreen: true } } as never)
  await band.unmount()
  await clock.advance(1000)
  expect(opened).toBe(1)
  startedAt = 9_000
  // A turn's end reads usage, and sees the new session's start.
  await $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 'm', reason: 'answer' })
  const band2 = await $.ui.mount({ ...BAND, surface: 'terminal', viewport: { columns: 100, rows: 40, isFullscreen: true } } as never)
  await band2.unmount()
  await clock.advance(1000)
  expect(opened).toBe(2)
})

test('tools: a failing engine call inside the clock stops only its own part', ENGINE, async ($, on) => {
  const clock = mock.clock(on)
  on('session.start', () => ({ cwd: 'D:/w' }))
  let reads = 0
  on('ui.panes', () => {
    throw new Error('panes gone')
  })
  on('session.usage', () => {
    reads++
    return { value: usageOf(5) }
  })
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  await $.session.start(startArgs).catch(() => undefined)
  await $.turn.start({ text: 'go', turnId: 't-main' })
  const before = reads
  // Usage is read every 5 s while something works, even with the pane list failing.
  await clock.advance(5000)
  expect(reads).toBeGreaterThan(before)
})

test('tools: an idle clock asks for no pane list and reads usage only every 30 s; a wait that ended is still cleared', ENGINE, async ($, on) => {
  const clock = mock.clock(on)
  on('session.start', () => ({ cwd: 'D:/w' }))
  let panes = 0
  let reads = 0
  on('ui.panes', () => {
    panes++
    return { value: [] }
  })
  on('session.usage', () => {
    reads++
    return { value: usageOf(5) }
  })
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'ag-1' }))
  on('classic.PermissionRequest', () => ({}))
  on('turn.complete', () => ({ text: '' }))
  await $.session.start(startArgs).catch(() => undefined)
  // The first beat writes the wait count once; after that, nothing runs: no pane list,
  // and usage only at the 30th beat (the limit meters and /clear stay current).
  await clock.advance(1000)
  const settled = panes
  const settledReads = reads
  await clock.advance(3000)
  expect(panes).toBe(settled)
  expect(reads).toBe(settledReads)
  await clock.advance(26_000)
  expect(panes).toBe(settled)
  expect(reads).toBe(settledReads + 1)

  await $.agent.spawn({ tool_use_id: 'tu-1', prompt: 'fix', description: 'fix', subagentType: 'general-purpose' } as unknown as Args<'agent.spawn'>)
  await $.classic.PermissionRequest({ tool_name: 'Bash', tool_input: { command: 'git push' }, agent_id: 'ag-1' } as never)
  await clock.advance(3000)
  const band = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await band.find({ text: /1 needs you/ })).toBeDefined()
  await band.unmount()
  await $.turn.complete({ answer: 'ok', durationMs: 1, isAborted: false, turnId: 'ag-1', agentId: 'ag-1', reason: 'answer' })
  await clock.advance(1000)
  const after = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await after.find({ text: /needs you/ })).toBeUndefined()
  await after.unmount()
})

function field(e: unknown, k: string): string {
  const v = (e as Record<string, unknown>)[k]
  return typeof v === 'string' ? v : ''
}
