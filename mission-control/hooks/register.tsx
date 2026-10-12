import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, RenderChildren } from 'claude-code'

import type { AgentRun, Ask, Compaction, FileTouch, MainLoop, RunStatus, Todo, ToolRow, Usage, View } from '../types'

import { burnPerHour, costSpark, fmtEta, pushSample, runOut } from './forecast'
import { applyStep, parseStep, stepToolArgs, stepToolFullName, withHint } from './progress'
import { batchesOf, receipt, timeline } from './summary'
import { applyAskCall, askToolArgs, composeSection, fromPerson, markAnswered, newAsk, parseAskCall, shownAsk } from './asks'
import { planParts, shortNames, wrapWords } from './fit'
import { lookOf, roleById, roleOf, sayOf, shadeOf } from './roles'
import type { PlanTone } from './fit'
import { isLongTurn, isNeedsYou, platformOf, playersFor, SOUND_ASSETS } from './chime'
import type { Platform, SoundKind } from './chime'
import { batchEnded, etaOf, etaPart, rollCall, todoCount, trackSteps, workingRow } from './eta'
import { treeLines } from './filetree'
import { arcs, cleanLine, COMMENT_REQUEST, COMMENT_SYSTEM, commentPrompt, isQuiet, msgOf, pushMsg, pushTalk, turnDigest } from './talk'
import type { Digest } from './talk'
import { activityRows, kindCounts, squares } from './timeline'

import { clipOf, frameAt, spinClip } from './anim'
import { tintHex } from './robots'
import type { State, Tint } from './robots'

const agents = atom({ plugin: 'mission-control', key: 'agents' } as const, [])
const main = atom({ plugin: 'mission-control', key: 'main' } as const, {
  isBusy: false,
  turnStartedAt: 0,
  toolCount: 0,
  tools: [],
  todos: [],
})
const files = atom({ plugin: 'mission-control', key: 'files' } as const, [])
const usage = atom({ plugin: 'mission-control', key: 'usage' } as const, {
  startedAt: 0,
  ctxPercent: 0,
  costUsd: 0,
})
const view = atom({ plugin: 'mission-control', key: 'view' } as const, {
  expanded: '',
  isBandHidden: false,
})
const tick = atom({ plugin: 'mission-control', key: 'tick' } as const, 0)
const seq = atom({ plugin: 'mission-control', key: 'seq' } as const, 0)
const waitN = atom({ plugin: 'mission-control', key: 'waitN' } as const, 0)
const hist = atom({ plugin: 'mission-control', key: 'hist' } as const, [])
const compactions = atom({ plugin: 'mission-control', key: 'compactions' } as const, [])
const asks = atom({ plugin: 'mission-control', key: 'asks' } as const, [])
const tracks = atom({ plugin: 'mission-control', key: 'tracks' } as const, {})
const talkOn = atom({ plugin: 'mission-control', key: 'talkOn' } as const, false)
const talk = atom({ plugin: 'mission-control', key: 'talk' } as const, [])
const msgs = atom({ plugin: 'mission-control', key: 'msgs' } as const, [])
const milestone = atom({ plugin: 'mission-control', key: 'milestone' } as const, 0)

const PLUGIN = 'mission-control'
const PANE = 'mission-control'
// The tool a subagent calls to report its own progress.
const STEP = stepToolFullName(PLUGIN)
const STEP_MATCH = /^mcp__mission-control__step$/
const ASK_MATCH = /^mcp__mission-control__ask$/
// Running helpers drawn as full cards; the rest fold to one line.
const FULL_CARDS = 6
// The engine's own plumbing: never a tool row.
const HIDDEN_TOOLS = /^SubagentHandback$/
// Agents whose tools are an allowlist never see the step tool: no hint for them.
const NO_HINT = /^(statusline-setup|claude-code-guide|impeccable:|codex:)/
const TITLE = 'Mission Control'
const WIDTH = 56
const KEEP_TOOLS = 40
const KEEP_FILES = 30
const KEEP_AGENTS = 60
// A dialog the person answers at once is not worth a flash of "needs you".
const WAIT_SHOWN_MS = 1500
// The robot column: 7 cells of robot and a gap of 2.
const ROBOT_W = 9

// --- palette: status is ok/warn/bad only, identity is agent colors only,
// money is money only, time and pace are pace only; the rest is grey

const C = {
  fg: '#e6e9f2',
  fg2: '#a9b1d6',
  muted: '#737a94',
  faint: '#4a4f63',
  frame: '#5a5f73',
  brand: '#b48cff',
  run: '#4fd6e8',
  ok: '#5fd38d',
  warn: '#f5c542',
  bad: '#ff6b6b',
  money: '#e5c07b',
  moneyDim: '#8f7a4e',
  pace: '#6ea8ff',
  edit: '#ff9f43',
  ink: '#1a1b26',
  // Older names, kept for the hooks above the drawing.
  main: '#b48cff',
  done: '#5fd38d',
  fail: '#ff6b6b',
  gold: '#f5c542',
  meta: '#a9b1d6',
}

const ctxColor = (pct: number): string => (pct >= 85 ? C.bad : pct >= 60 ? C.warn : C.ok)

// Each new agent takes the next color, so two of one type still differ.
const AGENT_COLORS = ['#4fd6e8', '#8ab4ff', '#f78fb3', '#7ee0c3', '#c3a6ff', '#9ee86f', '#ffb3c7']

const hash = (s: string): number => [...s].reduce((h, ch) => (h * 31 + ch.charCodeAt(0)) | 0, 7) >>> 0

const SPIN = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
const SPARK = ['▁', '▂', '▃', '▄', '▅', '▆', '▇']

// --- formatting

const basename = (p: string): string => p.split(/[\\/]/).filter(Boolean).pop() ?? p

const field = (e: unknown, k: string): string => {
  const v = (e as Record<string, unknown>)[k]
  return typeof v === 'string' ? v : ''
}

const firstLine = (s: string, max = 60): string => (s.split('\n').find(l => l.trim()) ?? '').trim().slice(0, max)

function labelOf(e: unknown, tool: string): string {
  const path = field(e, 'file_path') || field(e, 'notebook_path')
  if (path) return basename(path)
  if (tool === 'Bash' || tool === 'PowerShell') return firstLine(field(e, 'command'))
  if (tool === 'Grep' || tool === 'Glob') return field(e, 'pattern')
  if (tool === 'Agent') return field(e, 'description')
  if (tool === 'WebFetch') return field(e, 'url')
  if (tool === 'WebSearch') return field(e, 'query')
  return ''
}

const shortTool = (tool: string): string => tool.replace(/^mcp__([^_]+)__/, '$1:')

const fmtTime = (ms: number): string => {
  const s = Math.max(0, Math.floor(ms / 1000))
  if (s < 60) return `0:${String(s).padStart(2, '0')}`
  const m = Math.floor(s / 60)
  if (m < 60) return `${m}:${String(s % 60).padStart(2, '0')}`
  return `${Math.floor(m / 60)}h${String(m % 60).padStart(2, '0')}`
}

const fmtAge = (ms: number): string => {
  const m = Math.floor(Math.max(0, ms) / 60000)
  if (m < 1) return 'now'
  if (m < 60) return `${m}m`
  return `${Math.floor(m / 60)}h`
}

// How long until a limit window resets, from its ISO time.
const fmtReset = (iso: string | undefined, now: number): string => {
  if (!iso) return ''
  const at = Date.parse(iso)
  if (Number.isNaN(at)) return ''
  const m = Math.max(0, Math.round((at - now) / 60000))
  if (m < 60) return `${m}m`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h${String(m % 60).padStart(2, '0')}`
  return `${Math.floor(h / 24)}d${h % 24}h`
}

const fmtTokens = (n: number): string =>
  n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${Math.round(n / 1e3)}k` : `${Math.round(n)}`

const fmtCost = (usd: number): string => `$${usd < 10 ? usd.toFixed(2) : usd.toFixed(1)}`

const bar = (pct: number, width: number, full = '━', empty = '╍'): string => {
  const n = Math.round((width * Math.min(100, Math.max(0, pct))) / 100)
  return full.repeat(n) + empty.repeat(Math.max(0, width - n))
}

const spark = (values: number[], width: number, top = 100): string => {
  const cells = values.slice(-width).map(v => SPARK[Math.min(SPARK.length - 1, Math.floor((v / top) * SPARK.length))])
  return cells.join('').padEnd(width, ' ')
}

const modelName = (id: string): string => {
  const m = /(fable|mythos|opus|sonnet|haiku)-(\d+)(?:-(\d{1,2})(?!\d))?/i.exec(id)
  if (!m) return id.replace(/^claude-/, '') || '—'
  const [, family = '', major = '', minor] = m
  return `${family.charAt(0).toUpperCase()}${family.slice(1).toLowerCase()} ${major}${minor ? '.' + minor : ''}`
}

// --- rough per-subagent cost: $ per million tokens [input, output, cache read, cache write]

const PRICES: [RegExp, [number, number, number, number]][] = [
  [/fable|mythos/, [10, 50, 0.25, 12.5]],
  [/opus-5/, [4, 20, 0.2, 5]],
  [/opus/, [5, 25, 0.5, 6.25]],
  [/sonnet/, [2, 10, 0.2, 2.5]],
  [/haiku/, [1, 5, 0.1, 1.25]],
]

type TokenUsage = {
  input_tokens?: number
  output_tokens?: number
  cache_read_input_tokens?: number
  cache_creation_input_tokens?: number
}

const costOf = (model: string, u: TokenUsage): number => {
  const [i, o, r, w] = PRICES.find(([re]) => re.test(model.toLowerCase()))?.[1] ?? [4, 20, 0.2, 5]
  return (
    ((u.input_tokens ?? 0) * i +
      (u.output_tokens ?? 0) * o +
      (u.cache_read_input_tokens ?? 0) * r +
      (u.cache_creation_input_tokens ?? 0) * w) /
    1e6
  )
}

// Context windows by model; `[1m]` ids and current Opus and Sonnet take a million.
const windowOf = (model: string): number =>
  /\[1m\]|fable|mythos|opus-5|sonnet-5/i.test(model) ? 1_000_000 : 200_000

// --- state helpers

// Bookkeeping must never stop a tool or an agent: a failed write is dropped.
const safe = async (work: () => Promise<unknown>): Promise<void> => {
  try {
    await work()
  } catch {
    // The pane misses one update; the session goes on.
  }
}

const pushTool = (list: ToolRow[], row: ToolRow): ToolRow[] => [...list, row].slice(-KEEP_TOOLS)

const settleTool = (list: ToolRow[], id: string, isError: boolean, at: number, error?: string): ToolRow[] =>
  list.map(r => (r.id === id ? { ...r, status: isError ? 'err' : 'ok', endedAt: at, error } : r))

// A loop that ended leaves no tool spinning.
const settleAll = (list: ToolRow[], at: number): ToolRow[] =>
  list.map(r => (r.status === 'run' ? { ...r, status: 'err', endedAt: at, error: 'stopped' } : r))

// Running agents stay; the oldest finished ones go first.
const trimAgents = (list: AgentRun[]): AgentRun[] => {
  let extra = list.length - KEEP_AGENTS
  if (extra <= 0) return list
  return list.filter(a => {
    if (extra > 0 && a.status !== 'running') {
      extra--
      return false
    }
    return true
  })
}

const sameUsage = (a: Usage, b: Usage): boolean =>
  a.startedAt === b.startedAt &&
  a.ctxPercent === b.ctxPercent &&
  Math.abs(a.costUsd - b.costUsd) < 0.005 &&
  a.fiveHour === b.fiveHour &&
  a.sevenDay === b.sevenDay &&
  a.fiveReset === b.fiveReset &&
  a.sevenReset === b.sevenReset

async function refreshUsage($: EngineInterface): Promise<void> {
  try {
    const u = await $.session.usage()
    const rate = (kind: string) => u.rateLimits.find(r => r.kind === kind)
    const next: Usage = {
      startedAt: u.startedAt,
      ctxPercent: Math.round(u.context.percent ?? 0),
      ctxTokens: u.context.tokens,
      costUsd: u.cost?.usd ?? 0,
      fiveHour: rate('five_hour')?.percentUsed,
      sevenDay: rate('seven_day')?.percentUsed,
      fiveReset: rate('five_hour')?.resetsAt,
      sevenReset: rate('seven_day')?.resetsAt,
    }
    const at = await $.clock.now()
    const prev = await read($, hist)
    const grown = pushSample(prev, { at, costUsd: next.costUsd, fiveHour: next.fiveHour, sevenDay: next.sevenDay })
    if (grown !== prev) await update($, hist, () => grown)
    // Write only a change: each write redraws the pane and the band.
    if (sameUsage(await read($, usage), next) && (await read($, usage)).ctxTokens === next.ctxTokens) return
    await update($, usage, () => next)
  } catch {
    // No figures yet: keep the last ones.
  }
}

// The engine's own list settles agents whose end no event of ours saw.
// A helper whose turn ended can still run: it waits on its own background job
// and starts a new turn when that ends. The engine's list says so; the pane follows.
const isLive = (s: RunStatus): boolean => s === 'running' || s === 'idle'
const REVIVE_AFTER_MS = 5_000
const REVIVE_WITHIN_MS = 30 * 60_000
const isRecentDone = (a: AgentRun, at: number): boolean =>
  a.status === 'done' && a.endedAt !== undefined && at - a.endedAt > REVIVE_AFTER_MS && at - a.endedAt < REVIVE_WITHIN_MS

async function reconcile($: EngineInterface): Promise<void> {
  const list = await read($, agents)
  const at = await $.clock.now()
  if (!list.some(a => isLive(a.status) || isRecentDone(a, at))) return
  const live = await $.agent.list()
  const byId = new Map(live.map(a => [a.id, a.status]))
  const isRevived = (a: AgentRun, s: string | undefined) =>
    s !== undefined && isRecentDone(a, at) && (s === 'running' || s === 'idle' || s === 'waiting' || s === 'pending')
  const changed = list.some(a => {
    const s = byId.get(a.id)
    return (s !== undefined && mapStatus(s) !== a.status && isLive(a.status)) || isRevived(a, s)
  })
  if (!changed) return
  await update($, agents, all =>
    all.map(a => {
      const s = byId.get(a.id)
      if (isRevived(a, s)) return { ...a, status: 'running' as RunStatus, endedAt: undefined }
      if (s === undefined || !isLive(a.status)) return a
      const status = mapStatus(s)
      if (status === a.status) return a
      const isOver = status === 'done' || status === 'failed'
      return {
        ...a,
        status,
        endReason: s === 'killed' ? 'killed' : a.endReason,
        endedAt: isOver ? (a.endedAt ?? at) : undefined,
        tools: isOver ? settleAll(a.tools, at) : a.tools,
        waitSince: isOver ? undefined : a.waitSince,
      }
    }),
  )
}

const mapStatus = (s: string): RunStatus =>
  s === 'completed' ? 'done' : s === 'failed' || s === 'killed' ? 'failed' : s === 'idle' ? 'idle' : 'running'

async function openPane($: EngineInterface, focus: boolean): Promise<boolean> {
  await refreshUsage($)
  const opened = await $.ui.open({
    id: PANE,
    title: TITLE,
    columns: WIDTH,
    closeOnEscape: true,
    ...(focus ? { focus: true as const } : {}),
  })
  if (!opened.isPlaced) $.ui.toast(`Mission Control waits for room: ${opened.reason}`)
  return opened.isPlaced
}

async function togglePane($: EngineInterface): Promise<boolean> {
  const isOpen = (await $.ui.panes()).some(p => p.id === PANE)
  if (isOpen) {
    await $.ui.close({ id: PANE })
    return false
  }
  await openPane($, true)
  return true
}

// Which robot state an agent shows.
function stateOf(a: { status: RunStatus; waitSince?: number; tools: ToolRow[] }, now: number): State {
  if (a.status === 'done') return 'done'
  if (a.status === 'failed') return 'failed'
  if (a.status === 'idle') return 'idle'
  if (a.waitSince !== undefined && now - a.waitSince > WAIT_SHOWN_MS) return 'wait'
  const last = a.tools[a.tools.length - 1]
  // Between tool calls the model is thinking.
  return !last || last.status !== 'run' ? 'think' : 'work'
}

// A line's color: tints mark status and main's crown; the rest is the agent's body color.
function lineColor(tint: Tint, body: string, isMain: boolean): string {
  if (tint === 'accent') return isMain ? C.gold : body
  return tintHex(tint, body, body, { ok: C.done, warn: C.gold, bad: C.fail, bg: '#1e1e2e' })
}

let autoOpened = false
// When the last batch's toast was shown: the next toast counts only newer helpers.
let lastBatchEndAt = 0

// One cheap Haiku line about the turn, or undefined; never throws.
async function commentate($: EngineInterface, d: Digest): Promise<string | undefined> {
  if (isQuiet(d)) return undefined
  try {
    const r = await $.model.complete({ ...COMMENT_REQUEST, system: COMMENT_SYSTEM, prompt: commentPrompt(d) })
    return r.isAnswered ? cleanLine(r.text) : undefined
  } catch {
    return undefined
  }
}

// A short Windows sound ($.audio plays nothing on a Windows terminal): fire and
// forget, at most one per 10 s, off for good on another system or without powershell.
// When each sound last played: each one at most once per 10 s.
const chimeAt: Record<SoundKind, number> = { done: Number.NEGATIVE_INFINITY, needsYou: Number.NEGATIVE_INFINITY }
let chimePlatform: Platform | undefined
// Linux: the first player that worked, so the next sound tries it first.
let chimePlayer = 0
// One of the mod's own clips, each at most once per 10 s; never throws, never waits.
// A system with no way to play it ('none', or no Linux player) stays quiet.
function playChime($: EngineInterface, at: number, kind: SoundKind = 'done'): void {
  if (chimePlatform === 'none' || at - chimeAt[kind] < 10_000) return
  chimeAt[kind] = at
  const asset = SOUND_ASSETS[kind]
  void (async () => {
    if (chimePlatform === undefined) {
      const os = await $.env.get('OS')
      const uname =
        os === 'Windows_NT'
          ? undefined
          : await $.process
              .run(['uname', '-s'], { timeoutMs: 3000 })
              .then(r => r.stdout)
              .catch(() => undefined)
      chimePlatform = platformOf(os, uname)
    }
    if (chimePlatform === 'mac') {
      await $.audio.play({ asset })
      return
    }
    const systemRoot = chimePlatform === 'windows' ? await $.env.get('SystemRoot') : undefined
    const players = playersFor(chimePlatform, `${$.plugin.root}/${asset}`, systemRoot)
    for (let k = 0; k < players.length; k++) {
      const i = (chimePlayer + k) % players.length
      try {
        const r = await $.process.run(players[i]!, { timeoutMs: 10_000 })
        if (r.exitCode === 0) {
          chimePlayer = i
          return
        }
      } catch (err) {
        // A timeout or another plugin's deny skips this one; a missing player tries the next.
        if (!/ENOENT|not found|cannot start/i.test(String(err))) return
      }
    }
    if (chimePlatform === 'linux' || chimePlatform === 'windows') chimePlatform = 'none'
  })().catch(() => undefined)
}

// A reload keeps the session's state in the shape an older version wrote: fill what it lacks.
async function migrate($: EngineInterface): Promise<void> {
  const fixTools = (rows: ToolRow[] | undefined, at: number): ToolRow[] =>
    (rows ?? []).map(r => ({ ...r, startedAt: r.startedAt ?? at }))
  await safe(() =>
    update($, main, m => ({ ...m, todos: m.todos ?? [], tools: fixTools(m.tools, m.turnStartedAt ?? 0) })),
  )
  await safe(() =>
    update($, agents, list =>
      list.map(a => ({
        ...a,
        ctxHist: a.ctxHist ?? [],
        color: a.color || C.run,
        tools: fixTools(a.tools, a.startedAt ?? 0),
      })),
    ),
  )
  await safe(() =>
    update($, files, list => list.map(f => ({ ...f, editors: f.editors ?? [], owner: f.owner ?? 'main' }))),
  )
}

export const register: Register = on => {
  // Claude Code needs the person (a permission, a question): the "ding-dong".
  on('classic.Notification', async ($, e, next) => {
    if (isNeedsYou(e.notification_type)) playChime($, await $.clock.now(), 'needsYou')
    return next(e)
  })

  on('session.start', async ($, e, next) => {
    const started = await next(e)
    await $.command.register({
      name: 'mission',
      description: 'Show or hide Mission Control: the robots, their tools, context, cost and limits',
    })
    await $.command.register({
      name: 'mission-band',
      description: 'Show the Mission Control band above the prompt again',
    })
    await migrate($)
    await safe(() => $.tool.register(stepToolArgs))
    await safe(() => $.tool.register(askToolArgs))
    await $.command.register({
      name: 'mission-talk',
      description: 'Commentator on/off: one short Haiku line after each turn (uses a little of your plan)',
    })
    await refreshUsage($)

    // Animation ticks only while something works; usage and the agent list every 5 s.
    let beat = 0
    // Robots animate on their own (robot-clip.ts); this clock moves the
    // timers once a second, and only while something works and the pane shows.
    $.clock.every(1000, () => {
      void (async () => {
        beat++
        const m = await read($, main)
        const list = await read($, agents)
        const now = await $.clock.now()
        const isWorking = m.isBusy || list.some(a => a.status === 'running')
        const w = list.filter(a => stateOf(a, now) === 'wait').length + (stateOf({ status: m.isBusy ? 'running' : 'idle', waitSince: m.waitSince, tools: m.tools }, now) === 'wait' ? 1 : 0)
        if (w !== (await read($, waitN))) await update($, waitN, () => w)
        const isShown = (await $.ui.panes()).some(p => p.id === PANE && p.isShown && p.isPlaced)
        if (isWorking && isShown) await update($, tick, t => t + 1)
        if (beat % 5 === 0) {
          await refreshUsage($)
          await safe(() => reconcile($))
        }
      })()
    })
    return started
  })

  on('command.run', { command: 'mission-band' }, async $ => {
    await update($, view, prev => ({ ...prev, isBandHidden: false }))
    const list = await read($, agents)
    return {
      text: list.length
        ? `Mission Control band shown (${list.length} helpers this session). Its ✕ hides it.`
        : 'Mission Control band is on. It shows once a helper starts.',
    }
  })

  on('command.run', { command: 'mission-talk' }, async ($, e) => {
    const arg = (e.args ?? '').trim()
    const isOn = arg === 'on' ? true : arg === 'off' ? false : !(await read($, talkOn))
    await update($, talkOn, () => isOn)
    return { text: isOn ? 'Commentator on: one Haiku line after each turn.' : 'Commentator off.' }
  })

  // Each request the person types becomes an ask; recorded before the turn's first prompt is built.
  on('prompt.submit', async ($, e, next) => {
    const at = await $.clock.now()
    if (fromPerson(e.origin)) await safe(() => update($, asks, list => newAsk(list, e.text, at)))
    return next(e)
  })

  // The open asks, in two short sentences at the end of the system prompt; none when nothing is open.
  on('prompt.compose', async ($, e, next) => {
    const result = await next(e)
    const text = composeSection(await read($, asks))
    return text ? { sections: [...result.sections, { id: 'mission-control:asks', text, scope: 'session' as const }] } : result
  })

  on('command.run', { command: 'mission' }, async $ => {
    const isOpen = await togglePane($)
    return { text: isOpen ? 'Mission Control opened. Esc hands the keys back.' : 'Mission Control closed.' }
  })

  on('turn.start', async ($, e, next) => {
    const at = await $.clock.now()
    await update($, main, m => ({
      ...m,
      isBusy: true,
      turnStartedAt: at,
      progress: m.progress?.total && m.progress.done >= m.progress.total ? undefined : m.progress,
    }))
    return next(e)
  })

  // A permission dialog for the person: the robot waits until the call settles.
  on('classic.PermissionRequest', async ($, e, next) => {
    const at = await $.clock.now()
    const owner = e.agent_id
    await safe(() =>
      owner
        ? update($, agents, list =>
            list.map(a => (a.id === owner ? { ...a, waitSince: at, waitTool: e.tool_name } : a)),
          )
        : update($, main, m => ({ ...m, waitSince: at, waitTool: e.tool_name })),
    )
    return next(e)
  }).catch(($, e, next) => next(e))

  // A subagent's progress report: answered here, never a tool row. Registered
  // before the catch-all below, so it sits outside it.
  on('tool.call', { tool: STEP_MATCH }, async ($, e) => {
    const step = parseStep(e)
    if (!step) return { result: 'ignored: `done` must be a number' }
    const at = await $.clock.now()
    const owner = e.agentId
    if (!owner) {
      await safe(() => update($, main, m => ({ ...m, progress: applyStep(m.progress, step, at) })))
      const m = await read($, main)
      const total = m.progress?.total
      if (total) {
        await safe(() =>
          update($, tracks, t => ({
            ...t,
            main: trackSteps(t.main ?? trackSteps(undefined, { done: 0, total }, m.turnStartedAt), { done: m.progress?.done ?? 0, total }, at),
          })),
        )
      }
      return { result: 'ok' }
    }
    await safe(() =>
      update($, agents, list => list.map(a => (a.id === owner ? { ...a, progress: applyStep(a.progress, step, at) } : a))),
    )
    const a = (await read($, agents)).find(x => x.id === owner)
    const total = a?.progress?.total
    if (a && total) {
      await safe(() =>
        update($, tracks, t => {
          const prev = t[owner] ?? trackSteps(undefined, { done: 0, total }, a.startedAt)
          return { ...t, [owner]: trackSteps(prev, { done: a.progress?.done ?? 0, total }, at) }
        }),
      )
    }
    return { result: 'ok' }
  }).catch(() => ({ result: 'ok' }))

  // The main loop ticks the person's asks: answered here, never a tool row.
  on('tool.call', { tool: ASK_MATCH }, async ($, e) => {
    if (e.agentId) return { result: 'ignored: only the main loop ticks asks' }
    const call = parseAskCall(e)
    if (!call) return { result: 'ignored: give id + status + proof, or add' }
    const at = await $.clock.now()
    let reply = 'ok'
    await update($, asks, list => {
      const r = applyAskCall(list, call, at)
      reply = r.reply
      return r.list
    })
    return { result: reply }
  }).catch(() => ({ result: 'ok' }))

  // Every tool call, in the main loop or any subagent's.
  on('tool.call', async ($, e, next) => {
    if (HIDDEN_TOOLS.test(e.tool)) return next(e)
    const at = await $.clock.now()
    const id = e.tool_use_id ?? `${e.tool}-${at}`
    const row: ToolRow = { id, tool: e.tool, label: labelOf(e, e.tool), status: 'run', startedAt: at }
    const owner = e.agentId

    await safe(async () => {
      if (owner) {
        await update($, agents, list =>
          list.map(a =>
            a.id === owner
              ? {
                  ...a,
                  status: a.status === 'idle' || a.status === 'done' ? 'running' : a.status,
                  endedAt: a.status === 'done' ? undefined : a.endedAt,
                  toolCount: a.toolCount + 1,
                  tools: pushTool(a.tools, row),
                }
              : a,
          ),
        )
      } else {
        const todos = e.tool === 'TodoWrite' ? todosOf(e) : undefined
        await update($, main, m => ({
          ...m,
          toolCount: m.toolCount + 1,
          tools: pushTool(m.tools, row),
          ...(todos ? { todos } : {}),
        }))
        if (todos) await update($, tracks, t => ({ ...t, main: trackSteps(t.main, todoCount(todos), at) }))
      }

      const path = field(e, 'file_path') || field(e, 'notebook_path')
      if (path) {
        const kind: FileTouch['kind'] = e.tool === 'Read' ? 'read' : 'edit'
        const who = owner ?? 'main'
        await update($, files, list => {
          const old = list.find(f => f.path === path)
          const editors = old?.editors ?? []
          const touch: FileTouch = {
            path,
            kind: old?.kind === 'edit' ? 'edit' : kind,
            at,
            owner: who,
            editors: kind === 'edit' && !editors.includes(who) ? [...editors, who] : editors,
          }
          return [touch, ...list.filter(f => f.path !== path)].slice(0, KEEP_FILES)
        })
      }
    })

    // Every 50 tool calls across all loops: a toast.
    await safe(async () => {
      const total = (await read($, main)).toolCount + (await read($, agents)).reduce((n, a) => n + a.toolCount, 0)
      const mark = Math.floor(total / 50) * 50
      if (mark > 0 && mark > (await read($, milestone))) {
        await update($, milestone, () => mark)
        $.ui.toast(`${mark} tool calls this session`)
      }
    })

    let isError = true
    let error: string | undefined
    try {
      const result = await next(e)
      isError = result.deny !== undefined || result.isError === true
      if (isError) error = firstLine(result.deny ?? (typeof result.text === 'string' ? result.text : ''), 80) || 'failed'
      return result
    } finally {
      const end = await $.clock.now()
      await safe(() =>
        owner
          ? update($, agents, list =>
              list.map(a =>
                a.id === owner
                  ? { ...a, tools: settleTool(a.tools, id, isError, end, error), waitSince: undefined }
                  : a,
              ),
            )
          : update($, main, m => ({
              ...m,
              tools: settleTool(m.tools, id, isError, end, error),
              waitSince: undefined,
            })),
      )
    }
  }).catch(($, e, next) => next(e))

  on('agent.spawn', async ($, e, next) => {
    // Ask the subagent to report its steps; a workflow's agent keeps its prompt as written.
    const isHinted = !e.workflow && !NO_HINT.test(e.subagentType)
    const started = await next(isHinted ? { ...e, prompt: withHint(e.prompt, PLUGIN) } : e)
    if (started.deny !== undefined || !started.agentId) return started
    const agentId = started.agentId
    await safe(async () => {
      const at = await $.clock.now()
      const n = await read($, seq)
      await update($, seq, v => v + 1)
      const role = roleOf(e.description, e.subagentType)
      const mates = role ? (await read($, agents)).filter(a => a.role === role.id).length : 0
      const run: AgentRun = {
        id: agentId,
        parentId: e.parentAgentId,
        type: e.subagentType,
        description: e.description,
        model: started.model,
        color: role ? shadeOf(role, mates) : (AGENT_COLORS[n % AGENT_COLORS.length] ?? C.run),
        ...(role ? { role: role.id } : {}),
        status: 'running',
        startedAt: at,
        ctxTokens: 0,
        ctxMax: windowOf(started.model),
        ctxHist: [],
        costUsd: 0,
        toolCount: 0,
        tools: [],
      }
      await update($, agents, list => trimAgents([...list.filter(a => a.id !== run.id), run]))
    })
    return started
  }).catch(($, e, next) => next(e))

  // Each model request: a subagent's context fill and rough cost, the main loop's model.
  on('turn.step', async function* ($, e, next) {
    const result = yield* next(e)
    const owner = e.agentId
    const u = result.usage
    const model = u?.model || e.model
    const effort = typeof e.effort === 'string' ? e.effort : undefined
    if (!owner) {
      await safe(() => update($, main, m => ({ ...m, model, effort: effort ?? m.effort })))
      return result
    }
    if (!u) return result
    const ctx = (u.input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0)
    await safe(() =>
      update($, agents, list =>
        list.map(a => {
          if (a.id !== owner) return a
          const ctxMax = windowOf(model)
          return {
            ...a,
            model,
            effort: effort ?? a.effort,
            status: a.status === 'idle' || a.status === 'done' ? 'running' : a.status,
            endedAt: a.status === 'done' ? undefined : a.endedAt,
            ctxTokens: ctx,
            ctxMax,
            ctxHist: [...a.ctxHist, Math.round((ctx / ctxMax) * 100)].slice(-10),
            costUsd: a.costUsd + costOf(model, u),
            lastStop: result.stopReason ?? a.lastStop,
          }
        }),
      ),
    )
    return result
  })

  // A compaction of the main context: the header notes it under the ctx bar.
  on('session.compact', async ($, e, next) => {
    const result = await next(e)
    if (result.skip !== undefined || e.trigger === 'precompute' || e.agentId) return result
    const at = await $.clock.now()
    const row: Compaction = {
      at,
      trigger: e.trigger,
      tokensBefore: result.tokensBefore,
      tokensAfter: result.tokensAfter,
    }
    await safe(() => update($, compactions, list => [...list, row].slice(-20)))
    await refreshUsage($)
    return result
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const at = await $.clock.now()
    const before = await read($, agents)
    if (e.agentId) {
      const owner = e.agentId
      await safe(() =>
        update($, agents, list =>
          list.map(a => {
            if (a.id !== owner) return a
            const isFull = a.lastStop === 'model_context_window_exceeded' || a.lastStop === 'max_tokens'
            const endReason =
              e.reason === 'answer'
                ? undefined
                : e.reason === 'aborted'
                  ? 'stopped'
                  : e.reason === 'refusal'
                    ? 'refused'
                    : isFull
                      ? 'ctx full'
                      : 'error'
            return {
              ...a,
              status: (e.reason === 'answer' ? 'done' : 'failed') as RunStatus,
              endReason,
              answer: firstLine(e.answer, 120) || a.answer,
              endedAt: at,
              tools: settleAll(a.tools, at),
              waitSince: undefined,
            }
          }),
        ),
      )
    } else {
      await safe(() =>
        update($, main, m => ({ ...m, isBusy: false, turnEndedAt: at, tools: settleAll(m.tools, at), waitSince: undefined })),
      )
    }
    await refreshUsage($)

    // A batch of helpers ended: a toast that sums it up, and a chime. A long main turn: a chime.
    const after = await read($, agents)

    // The work is over (main answered, no helper left): open asks it never ticked turn "answered".
    const mEnd = await read($, main)
    const isAllDone = !mEnd.isBusy && !after.some(a => a.status === 'running' || a.status === 'idle')
    if (isAllDone && (e.agentId || e.reason === 'answer'))
      await safe(() => update($, asks, list => markAnswered(list, mEnd.turnEndedAt ?? 0)))
    if (e.agentId && batchEnded(before, after)) {
      // Only the batch that just ended: after a reload lastBatchEndAt starts at 0.
      const lastIds = batchesOf(after, at).at(-1)?.ids ?? []
      const text = rollCall(
        after
          .filter(a => lastIds.includes(a.id))
          .map(a => ({ ...a, name: a.role ?? (a.description.split(/\s+/).slice(0, 2).join(' ') || a.type) })),
        lastBatchEndAt,
      )
      lastBatchEndAt = at
      if (text) $.ui.toast(text, { timeoutMs: 8000 })
      playChime($, at)
    } else if (!e.agentId && isLongTurn((await read($, main)).turnStartedAt, at)) {
      playChime($, at)
    }

    const result = await next(e)
    // The commentator: one Haiku line, in its own dispatch so the turn never waits on it.
    if (!e.agentId && (await read($, talkOn))) {
      const m = await read($, main)
      const digest = turnDigest({
        since: m.turnStartedAt,
        tools: m.tools,
        files: await read($, files),
        agents: after,
        durationMs: e.durationMs,
        answer: e.answer,
        isAborted: e.isAborted,
      })
      $.clock.after(0, () => {
        void (async () => {
          const text = await commentate($, digest)
          if (text)
            await safe(async () => {
              const now = await $.clock.now()
              await update($, talk, l => pushTalk(l, { at: now, text }))
            })
        })()
      })
    }
    return result
  })

  // Agent-to-agent messages (teams, SendMessage): recorded once, at the send.
  on('session.send', async ($, e, next) => {
    const result = await next(e)
    const m = result.isDelivered ? msgOf(e, await $.clock.now()) : undefined
    if (m) await safe(() => update($, msgs, l => pushMsg(l, m)))
    return result
  }).catch(($, e, next) => next(e))

  // Claude Code's own "Working..." row: the plan's progress and time left.
  on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
    const list = await read($, agents)
    if (list.some(a => a.id === e.requestId)) return next(e)
    const m = await read($, main)
    const tr = await read($, tracks)
    const message = workingRow({
      todos: m.todos ?? [],
      ...(m.progress ? { progress: m.progress } : {}),
      mainTrack: tr.main,
      helpers: list.map(a => ({ status: a.status, track: tr[a.id] })),
      now: await $.clock.now(),
    })
    return message ? next({ ...e, props: { ...e.props, message, suffix: '' } }) : next(e)
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const els = $.ui.resolve(e)
    const { Box, Text, Button } = els
    const Client = 'Client' in els ? els.Client : undefined
    const t = await read($, tick)
    const now = await $.clock.now()
    const m: MainLoop = await read($, main)
    const list: AgentRun[] = await read($, agents)
    const touched: FileTouch[] = await read($, files)
    const u: Usage = await read($, usage)
    const v: View = await read($, view)
    const samples = await read($, hist)
    const compacts: Compaction[] = await read($, compactions)
    const askList = await read($, asks)
    const tr = await read($, tracks)
    const isTalkOn = await read($, talkOn)
    const talkLines = await read($, talk)
    const messages = await read($, msgs)
    // Two cells spare: the pane's last columns can sit under the window edge.
    const cols = Math.max(36, (e.props.bodyColumns || WIDTH) - 2)
    // Inside a card: the frame and one space each side.
    const inner = cols - 4
    const BAR = Math.max(6, inner - 19)
    // The pane redraws once a second: a pulse reads better than a slow spinner.
    const spin = t % 2 ? '●' : '○'

    const running = list.filter(a => a.status === 'running' || a.status === 'idle').reverse()
    const finished = list.filter(a => a.status === 'done' || a.status === 'failed').reverse()
    const isWorking = m.isBusy || running.length > 0
    const waiting = list.filter(a => stateOf(a, now) === 'wait').length

    // Short names for helpers that ran together ("bin", "mods" for "Summarize bin folder"...).
    const names = shortNames(
      batchesOf(list, now).map(b => b.ids.map(id => list.find(a => a.id === id)).filter((a): a is AgentRun => a !== undefined)),
    )
    // An owner is 'main' or an agent's id; state from 0.3.0 holds the agent's type.
    const whoName = (owner: string) => (owner === 'main' || owner === '' ? owner : (names.get(owner) ?? owner))
    const whoColor = (owner: string) =>
      owner === 'main' ? C.brand : ((list.find(a => a.id === owner) ?? list.find(a => a.type === owner))?.color ?? C.fg2)

    const toggle = (id: string) => update($, view, prev => ({ ...prev, expanded: prev.expanded === id ? '' : id }))

    // --- cards: a rounded frame drawn as cells, its title and meta in the top border

    // A part that keeps its width when its row runs short; only the flexible text shrinks.
    const fixed = (key: string, child: RenderChildren) => (
      <Box key={key} flexShrink={0}>
        {child}
      </Box>
    )
    const grow = (key: string, child: RenderChildren) => (
      <Box key={key} flexGrow={1} flexShrink={1}>
        {child}
      </Box>
    )

    // The top border at its exact length: corner, title, dashes, meta, corner.
    const cellsOf = (s: string) => [...s].length
    const cardTop = (key: string, frame: string, title: RenderChildren, titleLen: number, meta?: RenderChildren, metaLen = 0) => {
      const dashes = Math.max(1, cols - 3 - titleLen - 1 - (meta === undefined ? 0 : metaLen + 2) - 2)
      return (
        <Box key={`${key}-top`} flexDirection="row" width={cols}>
          <Text>
            <Text color={frame}>╭─ </Text>
            {title}
            <Text> </Text>
            <Text color={frame}>{'─'.repeat(dashes)}</Text>
          </Text>
          {meta !== undefined && (
            <Box flexDirection="row">
              <Text> </Text>
              {meta}
              <Text> </Text>
            </Box>
          )}
          <Text color={frame}>─╮</Text>
        </Box>
      )
    }

    const cardRow = (key: string, frame: string, ...cells: RenderChildren[]) => (
      <Box key={key} flexDirection="row" width={cols}>
        {fixed(`${key}-l`, <Text color={frame}>│ </Text>)}
        <Box width={inner} flexShrink={0} flexDirection="row">
          {cells}
        </Box>
        {fixed(`${key}-r`, <Text color={frame}> │</Text>)}
      </Box>
    )

    // Three card rows beside a robot: the robot plays on its own clock.
    const robotRows = (key: string, frame: string, bot: RenderChildren, rows: RenderChildren[][]) => (
      <Box key={key} flexDirection="row" width={cols}>
        <Box flexDirection="column" flexShrink={0}>
          {rows.map((_, i) => (
            <Text key={`${key}-l${i}`} color={frame}>
              │{' '}
            </Text>
          ))}
        </Box>
        {bot}
        <Box flexDirection="column" width={inner - ROBOT_W} flexShrink={0}>
          {rows.map((cells, i) => (
            <Box key={`${key}-c${i}`} flexDirection="row">
              {cells}
            </Box>
          ))}
        </Box>
        <Box flexDirection="column" flexShrink={0}>
          {rows.map((_, i) => (
            <Text key={`${key}-r${i}`} color={frame}>
              {' '}│
            </Text>
          ))}
        </Box>
      </Box>
    )

    const cardBottom = (key: string, frame: string) => (
      <Text key={`${key}-bot`} color={frame} wrap="truncate-end">
        ╰{'─'.repeat(Math.max(0, cols - 2))}╯
      </Text>
    )

    // One line of text that cuts with … and never wraps.
    const line = (key: string, child: RenderChildren) =>
      grow(
        key,
        <Text wrap="truncate-end">{child}</Text>,
      )

    const robot = (key: string, type: string, state: State, seed: string, body: string, isMain = false) => {
      const clip = clipOf(type, state, hash(seed) % 9, tint => lineColor(tint, body, isMain))
      if (Client)
        return (
          <Box key={key} width={ROBOT_W} height={3} flexShrink={0}>
            <Client key={`${key}-c`} module="./robot-clip.ts" props={clip} width={ROBOT_W - 1} height={3} />
          </Box>
        )
      // A surface without Client draws a still frame that moves with the pane's clock.
      const f = frameAt(clip, t)
      return (
        <Box key={key} width={ROBOT_W} height={3} flexShrink={0} flexDirection="column">
          {f.lines.map((l, i) => (
            <Text key={`${key}-${i}`} color={f.colors[i]}>
              {l}
            </Text>
          ))}
        </Box>
      )
    }

    const markOf = (a: AgentRun) =>
      stateOf(a, now) === 'wait'
        ? { t: '!', c: C.warn }
        : a.status === 'running'
          ? { t: spin, c: a.color }
          : a.status === 'done'
            ? { t: '✓', c: C.ok }
            : a.status === 'failed'
              ? { t: '✗', c: C.bad }
              : { t: 'z', c: C.muted }

    const needsBadge = (tool?: string) => (
      <Text>
        <Text bold color={C.ink} backgroundColor={C.warn}>
          {' '}! NEEDS YOUR OK{' '}
        </Text>
        <Text color={C.warn}> {tool ?? ''}</Text>
      </Text>
    )

    // Settled chips quiet, the live one bright with its time and label.
    const chips = (rows: ToolRow[], isWaiting: boolean) =>
      rows.slice(-3).map(r =>
        r.status === 'run' ? (
          isWaiting ? (
            <Text key={r.id} color={C.warn}>
              ! {shortTool(r.tool)} held {fmtTime(now - r.startedAt)}
            </Text>
          ) : (
            <Text key={r.id} color={C.fg}>
              {spin} {shortTool(r.tool)} {fmtTime(now - r.startedAt)} <Text color={C.muted}>{r.label}</Text>
            </Text>
          )
        ) : (
          <Text key={r.id} color={r.status === 'err' ? C.bad : C.fg2}>
            {r.status === 'ok' ? '✓' : '✗'} {shortTool(r.tool)}{'  '}
          </Text>
        ),
      )

    const errorText = (rows: ToolRow[]) => {
      const last = rows[rows.length - 1]
      if (!last || last.status !== 'err' || !last.error || last.error === 'stopped') return undefined
      return `✗ ${shortTool(last.tool)} · ${last.error}`
    }

    const toolLog = (key: string, frame: string, rows: ToolRow[]) =>
      rows.slice(-12).map(r =>
        cardRow(
          `${key}-log-${r.id}`,
          frame,
          line(
            `${key}-logl-${r.id}`,
            <Text>
              <Text color={C.faint}>{' '.repeat(ROBOT_W - 2)}│ </Text>
              <Text color={r.status === 'err' ? C.bad : r.status === 'ok' ? C.ok : C.fg}>
                {r.status === 'run' ? spin : r.status === 'ok' ? '✓' : '✗'} {shortTool(r.tool)}
              </Text>
              <Text color={C.muted}>
                {' '}
                {r.startedAt ? fmtTime((r.endedAt ?? now) - r.startedAt) : ''} {r.label}
              </Text>
            </Text>,
          ),
        ),
      )

    // Only the first nine running agents get a digit.
    let digit = 0
    const nextHotkey = () => (++digit <= 9 ? String(digit) : undefined)

    // ================= HEADER =================
    const burn = burnPerHour(samples, now)
    const isIdleMoney = burn < 0.01
    const lastCompact = compacts[compacts.length - 1]
    const meter = (
      key: string,
      label: string,
      pct: number,
      fill: string,
      pctColor: string,
      right: string,
    ) =>
      cardRow(
        key,
        C.frame,
        line(
          `${key}-t`,
          <Text>
            <Text color={C.muted}>{label.padEnd(4)}</Text>
            <Text color={fill}>{bar(pct, BAR, '━', '')}</Text>
            <Text color={C.faint}>{'╍'.repeat(Math.max(0, BAR - Math.round((BAR * Math.min(100, Math.max(0, pct))) / 100)))}</Text>
            <Text bold color={pctColor}>{`${Math.round(pct)}%`.padStart(5)}</Text>
            <Text color={C.muted}>{'  '}{right.padStart(8)}</Text>
          </Text>,
        ),
      )
    const subRow = (key: string, child: RenderChildren) =>
      cardRow(key, C.frame, line(`${key}-t`, <Text><Text color={C.faint}>{'    ╰ '}</Text>{child}</Text>))

    const forecastRow = (key: string, kind: 'fiveHour' | 'sevenDay', reset?: string) => {
      const out = runOut(samples, now, kind, reset)
      if (!out || !out.beforeReset) return null
      const isSoon = out.etaMs < 30 * 60000
      return subRow(
        key,
        <Text bold={isSoon} color={isSoon ? C.bad : C.warn}>
          runs out in {fmtEta(out.etaMs)} at this pace
        </Text>,
      )
    }

    const hdrMeta = `${isWorking ? `${spin} ` : ''}${u.startedAt ? fmtTime(now - u.startedAt) : '0:00'}`
    const header = (
      <Box key="hdr" flexDirection="column">
        {cardTop(
          'hdr',
          C.frame,
          <Text bold color={C.brand}>
            ◆ MISSION CONTROL
          </Text>,
          cellsOf('◆ MISSION CONTROL'),
          <Text color={C.muted}>{hdrMeta}</Text>,
          cellsOf(hdrMeta),
        )}
        {cardRow(
          'hdr-money',
          C.frame,
          line(
            'hdr-money-l',
            <Text>
              <Text bold color={C.money}>
                {fmtCost(u.costUsd).padEnd(8)}
              </Text>
              <Text color={C.moneyDim}>{costSpark(samples, 18, now)}</Text>
            </Text>,
          ),
          fixed(
            'hdr-money-r',
            isIdleMoney ? (
              <Text color={C.muted}>idle · $0.00/h</Text>
            ) : (
              <Text>
                <Text color={C.muted}>burn </Text>
                <Text color={C.money}>{fmtCost(burn)}/h</Text>
              </Text>
            ),
          ),
        )}
        {cardRow('hdr-gap', C.frame, line('hdr-gap-t', <Text> </Text>))}
        {meter('hdr-ctx', 'ctx', u.ctxPercent, ctxColor(u.ctxPercent), ctxColor(u.ctxPercent), u.ctxTokens ? fmtTokens(u.ctxTokens) : '')}
        {lastCompact &&
          subRow(
            'hdr-cmp',
            <Text>
              <Text color={C.brand}>↺ </Text>
              <Text color={C.muted}>
                {lastCompact.trigger} compact
                {lastCompact.tokensBefore && lastCompact.tokensAfter
                  ? ` ${fmtTokens(lastCompact.tokensBefore)}→${fmtTokens(lastCompact.tokensAfter)}`
                  : ''}{' '}
                · {fmtAge(now - lastCompact.at)} ago{compacts.length > 1 ? ` ×${compacts.length}` : ''}
              </Text>
            </Text>,
          )}
        {u.fiveHour !== undefined &&
          meter('hdr-5h', '5h', u.fiveHour, C.pace, C.fg, u.fiveReset ? `↻ ${fmtReset(u.fiveReset, now)}` : '')}
        {u.fiveHour !== undefined && forecastRow('hdr-5h-f', 'fiveHour', u.fiveReset)}
        {u.sevenDay !== undefined &&
          meter('hdr-wk', 'wk', u.sevenDay, C.pace, C.fg, u.sevenReset ? `↻ ${fmtReset(u.sevenReset, now)}` : '')}
        {u.sevenDay !== undefined && forecastRow('hdr-wk-f', 'sevenDay', u.sevenReset)}
        {cardBottom('hdr', C.frame)}
      </Box>
    )

    // ================= MAIN =================
    const mainState = m.isBusy ? stateOf({ status: 'running', waitSince: m.waitSince, tools: m.tools }, now) : 'idle'
    const mainLook = lookOf(mainState, { ctxPct: u.ctxPercent, waitSince: m.waitSince, tools: m.tools }, now)
    const mainWaits = mainState === 'wait'
    const mainFrame = mainWaits ? C.warn : m.isBusy ? C.brand : C.frame
    const mainLast = m.tools[m.tools.length - 1]
    const todos = m.todos ?? []
    const todosDone = todos.filter(x => x.status === 'completed').length
    const todoNow = todos.find(x => x.status === 'in_progress')
    const mainErr = errorText(m.tools)
    const mainEta = etaPart(etaOf(tr.main, now))
    const mainMeta = m.model ? `${modelName(m.model).toLowerCase()}${m.effort ? ` · ${m.effort}` : ''}` : ''
    const mp = m.progress
    const mpTotal = mp?.total ?? 0
    const mpDone = Math.min(mp?.done ?? 0, mpTotal)
    // Helpers the main loop started since its current step began work for that step.
    const stepSince = mp?.since
    const stepCrew =
      stepSince !== undefined && mpDone < mpTotal ? list.filter(a => !a.parentId && a.startedAt >= stepSince) : []
    const crewDone = stepCrew.filter(a => a.status === 'done' || a.status === 'failed').length
    const crewText = stepCrew.length ? `${crewDone}/${stepCrew.length} helpers done` : ''
    const mpSteps = mp?.steps ?? []
    const mainNote = [mp?.note ?? mpSteps[mpDone], mpSteps.length ? '' : crewText].filter(Boolean).join(' · ')
    const toneColor = (tone: PlanTone, now: string): string =>
      tone === 'done' ? C.ok : tone === 'now' ? now : tone === 'extra' ? C.run : tone === 'line' ? C.faint : C.muted
    const planRow = (key: string, frame: string, steps: readonly string[], done: number, nowColor: string, extra = '') =>
      cardRow(
        key,
        frame,
        line(
          `${key}-t`,
          <Text>
            <Text>{' '.repeat(ROBOT_W)}</Text>
            {planParts(steps, done, inner - ROBOT_W, extra).map((pt, i) => (
              <Text key={`${key}-${i}`} bold={pt.tone === 'now'} color={toneColor(pt.tone, nowColor)}>
                {pt.text}
              </Text>
            ))}
          </Text>,
        ),
      )
    const mainBlock = (
      <Box key="main" flexDirection="column">
        {cardTop(
          'main',
          mainFrame,
          <Text bold color={C.brand}>
            MAIN
          </Text>,
          4,
          mainMeta ? <Text color={C.muted}>{mainMeta}</Text> : undefined,
          cellsOf(mainMeta),
        )}
        {robotRows(
          'main-rows',
          mainFrame,
          robot('r-main', 'main', mainLook, 'main', C.brand, true),
          [
          [
          line(
            'main-1-t',
            mainWaits ? (
              <Text bold color={C.warn}>
                ● waiting for you
              </Text>
            ) : m.isBusy && mainLast?.status !== 'run' ? (
              <Text italic color={C.brand}>
                thinking…
              </Text>
            ) : m.isBusy ? (
              <Text color={C.brand}>● working</Text>
            ) : (
              <Text color={C.muted}>
                idle · {running.length ? `${running.length} helper${running.length === 1 ? '' : 's'} working` : 'waiting for you'}
              </Text>
            ),
          ),
          fixed(
            'main-1-x',
            <Text color={C.muted}>{m.isBusy ? `${mainWaits ? '!' : spin} ${fmtTime(now - m.turnStartedAt).padStart(5)}  ` : ''}</Text>,
          ),
          fixed(
            'main-1-b',
            <Button key="x-main" label={v.expanded === 'main' ? '▾' : '▸'} plain hotkey="m" onPress={() => toggle('main')} />,
          ),
          ],
          [
          line(
            'main-2-t',
            mainWaits ? (
              needsBadge(m.waitTool)
            ) : m.isBusy && mainLast?.status === 'run' ? (
              <Text>
                <Text color={C.brand}>{spin} </Text>
                <Text color={C.fg}>{shortTool(mainLast.tool).padEnd(6)}</Text>
                <Text color={C.muted}>{fmtTime(now - mainLast.startedAt).padStart(5)}  {mainLast.label}</Text>
              </Text>
            ) : (
              <Text color={C.muted}>
                {m.toolCount} tools · {list.length} helper{list.length === 1 ? '' : 's'} this session
              </Text>
            ),
          ),
          ],
          [
          line(
            'main-3-t',
            todos.length > 0 ? (
              <Text>
                <Text color={C.brand}>{bar((todosDone / todos.length) * 100, 10, '▰', '')}</Text>
                <Text color={C.faint}>{'▱'.repeat(10 - Math.round((10 * todosDone) / todos.length))}</Text>
                <Text color={C.fg}>{`${todosDone}/${todos.length}`.padStart(6)}</Text>
                <Text color={C.fg2}>{todoNow ? ` · ${todoNow.activeForm ?? todoNow.content}` : ''}</Text>
                {mainEta ? <Text color={C.pace}>{`  ${mainEta}`}</Text> : ''}
              </Text>
            ) : mpTotal > 0 ? (
              <Text>
                <Text color={C.brand}>{bar((mpDone / mpTotal) * 100, 10, '▰', '')}</Text>
                <Text color={C.faint}>{'▱'.repeat(Math.max(0, 10 - Math.round((10 * mpDone) / mpTotal)))}</Text>
                <Text color={C.fg}>{`${mpDone}/${mpTotal}`.padStart(6)}</Text>
                <Text color={C.fg2}>{mainNote ? ` · ${mainNote}` : ''}</Text>
                {mainEta ? <Text color={C.pace}>{`  ${mainEta}`}</Text> : ''}
              </Text>
            ) : (
              <Text> </Text>
            ),
          ),
          ]
          ],
        )}
        {todos.length === 0 && mpSteps.length > 0 && planRow('main-plan', mainFrame, mpSteps, mpDone, C.brand, crewText)}
        {mainErr && cardRow('main-err', mainFrame, line('main-err-t', <Text color={C.bad}>{' '.repeat(ROBOT_W)}{mainErr}</Text>))}
        {v.expanded === 'main' && toolLog('main', mainFrame, m.tools)}
        {cardBottom('main', mainFrame)}
      </Box>
    )

    // ================= RUNNING =================
    const typeOf = (id?: string) => list.find(a => a.id === id)?.type
    const runFrame = waiting ? C.warn : C.run

    const agentBlock = (a: AgentRun, i: number) => {
      const state = stateOf(a, now)
      const isWait = state === 'wait'
      const isOpen = v.expanded === a.id
      const ctx = a.ctxMax ? Math.round((a.ctxTokens / a.ctxMax) * 100) : 0
      const look = lookOf(state, { ctxPct: ctx, waitSince: a.waitSince, tools: a.tools }, now)
      const parent = typeOf(a.parentId)
      const role = roleById(a.role)
      const meta = [role?.id ?? a.type, modelName(a.model).toLowerCase(), a.effort].filter(Boolean).join(' · ')
      const runMeta2 = [modelName(a.model).toLowerCase(), a.effort].filter(Boolean).join(' · ')
      const mk = markOf(a)
      const key = nextHotkey()
      const err = errorText(a.tools)
      const p = a.progress
      const pFill = p?.total ? Math.min(10, Math.round((10 * p.done) / p.total)) : 0
      return (
        <Box key={a.id} flexDirection="column">
          {i > 0 && cardRow(`${a.id}-div`, runFrame, line(`${a.id}-div-t`, <Text color={C.faint}>{'┄'.repeat(200)}</Text>))}
          {robotRows(
            `${a.id}-rows`,
            runFrame,
            robot(`r-${a.id}`, role?.robot ?? a.type, look, a.id, a.color),
            [
            [
            line(
              `${a.id}-1-t`,
              <Text bold color={C.fg}>
                {a.description || a.type}
              </Text>,
            ),
            fixed(
              `${a.id}-1-x`,
              <Text>
                <Text color={mk.c}> {mk.t}</Text>
                <Text color={C.muted}>{fmtTime(now - a.startedAt).padStart(6)}  </Text>
              </Text>,
            ),
            fixed(
              `${a.id}-1-b`,
              <Button key={`x-${a.id}`} label={isOpen ? '▾' : '▸'} plain hotkey={key} onPress={() => toggle(a.id)} />,
            ),
            ],
            [
            line(
              `${a.id}-2-t`,
              isWait ? (
                needsBadge(a.waitTool)
              ) : role ? (
                <Text>
                  <Text bold color={a.color}>
                    {role.id}
                  </Text>
                  <Text italic color={C.fg2}> “{sayOf(role, a.status, look)}”</Text>
                  {parent ? <Text color={C.muted}> ↳ {parent}</Text> : ''}
                </Text>
              ) : (
                <Text color={C.fg2}>
                  {meta}
                  {parent ? <Text color={C.muted}> ↳ {parent}</Text> : ''}
                </Text>
              ),
            ),
            ...(role && !isWait ? [fixed(`${a.id}-2-m`, <Text color={C.muted}> {runMeta2}</Text>)] : []),
            ],
            [
            line(
              `${a.id}-3-t`,
              a.tools.length === 0 ? (
                <Text italic color={C.muted}>
                  thinking…
                </Text>
              ) : (
                <Text>{chips(a.tools, isWait)}</Text>
              ),
            ),
            ]
            ],
          )}
          {p &&
            cardRow(
              `${a.id}-p`,
              runFrame,
              line(
                `${a.id}-p-t`,
                <Text>
                  <Text>{' '.repeat(ROBOT_W)}</Text>
                  <Text color={a.color}>{bar(p.total ? (p.done / p.total) * 100 : 0, 10, '▰', '')}</Text>
                  <Text color={C.faint}>{'▱'.repeat(10 - pFill)}</Text>
                  <Text color={C.fg}>{`${p.done}/${p.total ?? '?'}`.padStart(6)}</Text>
                  <Text color={C.fg2}>{(p.note ?? p.steps?.[p.done]) ? ` · ${p.note ?? p.steps?.[p.done]}` : ''}</Text>
                  {etaPart(etaOf(tr[a.id], now)) ? <Text color={C.pace}>{`  ${etaPart(etaOf(tr[a.id], now))}`}</Text> : ''}
                </Text>,
              ),
            )}
          {cardRow(
            `${a.id}-4`,
            runFrame,
            line(
              `${a.id}-4-t`,
              <Text>
                <Text>{' '.repeat(ROBOT_W)}</Text>
                <Text color={C.muted}>ctx </Text>
                <Text color={a.color}>{spark(a.ctxHist ?? [], 10)}</Text>
                <Text bold color={ctxColor(ctx)}>{`${ctx}%`.padStart(5)}</Text>
              </Text>,
            ),
            fixed(
              `${a.id}-4-r`,
              <Text>
                <Text color={C.muted}>{`${a.toolCount} tools`.padStart(9)}</Text>
                <Text color={C.money}>{fmtCost(a.costUsd).padStart(8)}</Text>
              </Text>,
            ),
          )}
          {err && cardRow(`${a.id}-err`, runFrame, line(`${a.id}-err-t`, <Text color={C.bad}>{' '.repeat(ROBOT_W)}{err}</Text>))}
          {isOpen && toolLog(a.id, runFrame, a.tools)}
        </Box>
      )
    }

    // A one-line agent: DONE rows, and running agents from the 4th on.
    const shortRow = (a: AgentRun, frame: string) => {
      const isOpen = v.expanded === a.id
      const mk = markOf(a)
      const face = a.status === 'done' ? '^‿^' : a.status === 'failed' ? 'x_x' : a.status === 'idle' ? '˘_˘' : '◉‿◉'
      const faceColor = a.status === 'failed' ? C.bad : tintHex('dim', a.color, a.color, { ok: C.ok, warn: C.warn, bad: C.bad, bg: '#1e1e2e' })
      const time = fmtTime((a.endedAt ?? now) - a.startedAt)
      return (
        <Box key={a.id} flexDirection="column">
          {cardRow(
            `${a.id}-s`,
            frame,
            fixed(
              `${a.id}-s-f`,
              <Text>
                <Text color={mk.c}>{mk.t} </Text>
                <Text color={a.status === 'running' ? a.color : faceColor}>{face} </Text>
              </Text>,
            ),
            line(
              `${a.id}-s-t`,
              <Text color={a.status === 'failed' ? C.fg : C.fg2}>{a.description || a.type}</Text>,
            ),
            fixed(
              `${a.id}-s-r`,
              <Text>
                {a.endReason ? <Text color={C.bad}>  {a.endReason}</Text> : ''}
                <Text color={C.muted}>{time.padStart(6)}</Text>
                <Text color={C.money}>{fmtCost(a.costUsd).padStart(7)}</Text>
                <Text> </Text>
              </Text>,
            ),
            fixed(
              `${a.id}-s-b`,
              <Button key={`x-${a.id}`} label={isOpen ? '▾' : '▸'} plain dimColor onPress={() => toggle(a.id)} />,
            ),
          )}
          {isOpen &&
            cardRow(
              `${a.id}-s-m`,
              frame,
              line(
                `${a.id}-s-mt`,
                <Text>
                  <Text color={C.faint}>{'      │ '}</Text>
                  <Text color={C.fg2}>{[roleById(a.role)?.id ?? a.type, modelName(a.model).toLowerCase(), a.effort].filter(Boolean).join(' · ')}</Text>
                  {roleById(a.role) ? <Text italic color={a.color}> “{sayOf(roleById(a.role)!, a.status)}”</Text> : ''}
                </Text>,
              ),
            )}
          {isOpen &&
            a.answer &&
            cardRow(
              `${a.id}-s-a`,
              frame,
              line(
                `${a.id}-s-at`,
                <Text>
                  <Text color={C.faint}>{'      │ '}</Text>
                  <Text italic color={C.fg}>
                    “{a.answer}”
                  </Text>
                </Text>,
              ),
            )}
          {isOpen && toolLog(`${a.id}-s`, frame, a.tools)}
        </Box>
      )
    }

    const runMeta = `! ${waiting} need${waiting === 1 ? 's' : ''} you`
    const runningCard = running.length > 0 && (
      <Box key="run" flexDirection="column">
        {cardTop(
          'run',
          runFrame,
          <Text>
            <Text bold color={C.run}>
              RUNNING
            </Text>
            <Text color={C.run}> {running.length}</Text>
          </Text>,
          cellsOf(`RUNNING ${running.length}`),
          waiting ? (
            <Text bold color={C.warn}>
              {runMeta}
            </Text>
          ) : undefined,
          cellsOf(runMeta),
        )}
        {running.slice(0, FULL_CARDS).map(agentBlock)}
        {running.length > FULL_CARDS &&
          cardRow('run-div2', runFrame, line('run-div2-t', <Text color={C.faint}>{'┄'.repeat(200)}</Text>))}
        {running.slice(FULL_CARDS).map(a => shortRow(a, runFrame))}
        {cardBottom('run', runFrame)}
      </Box>
    )

    // ================= BATCH =================
    const batches = batchesOf(list, now)
    const batch = [...batches].reverse().find(b => b.ids.length >= 2)
    const TRACK = Math.max(8, inner - 24)
    const batchMeta = (b: NonNullable<typeof batch>) =>
      b.endedAt
        ? now - b.endedAt < 60_000
          ? 'ended just now'
          : `ended ${fmtAge(now - b.endedAt)} ago`
        : `${spin} ${fmtTime(now - b.startedAt)}`
    const batchCard = batch && (
      <Box key="batch" flexDirection="column">
        {cardTop(
          'batch',
          C.frame,
          <Text bold color={C.pace}>
            {batch.endedAt ? 'LAST BATCH' : 'BATCH · live'}
          </Text>,
          cellsOf(batch.endedAt ? 'LAST BATCH' : 'BATCH · live'),
          <Text color={C.muted}>{batchMeta(batch)}</Text>,
          cellsOf(batchMeta(batch)),
        )}
        {timeline(batch, list, TRACK, now).map(({ id, bar: lane }) => {
          const a = list.find(x => x.id === id)
          if (!a) return null
          const dur = fmtTime((a.endedAt ?? now) - a.startedAt)
          const mk = markOf(a)
          return cardRow(
            `lane-${id}`,
            C.frame,
            line(
              `lane-${id}-t`,
              <Text>
                <Text color={a.color}>{fitTo(names.get(a.id) ?? (a.description || a.type), 14)} </Text>
                <Text color={a.status === 'failed' ? C.bad : a.color}>{lane}</Text>
                <Text color={C.muted}>{dur.padStart(6)} </Text>
                <Text color={mk.c}>{mk.t}</Text>
              </Text>,
            ),
          )
        })}
        {cardRow(
          'batch-axis',
          C.frame,
          line(
            'batch-axis-t',
            <Text color={C.faint}>
              {' '.repeat(15)}0{' '.repeat(Math.max(0, TRACK - 1 - fmtTime(batch.wallMs).length))}
              {fmtTime(batch.wallMs)}
            </Text>,
          ),
        )}
        {cardRow(
          'batch-receipt',
          C.frame,
          line(
            'batch-receipt-t',
            batch.endedAt ? (
              <Text color={C.fg}>{receipt(batch)}</Text>
            ) : (
              <Text color={C.fg}>
                {batch.done + batch.failed} of {batch.ids.length} done · {fmtTime(batch.wallMs)} so far ·{' '}
                <Text color={C.money}>{fmtCost(batch.costUsd)}</Text>
              </Text>
            ),
          ),
        )}
        {cardBottom('batch', C.frame)}
      </Box>
    )

    // ================= DONE =================
    const showAll = v.isDoneAll === true
    const doneLimit = showAll ? finished.length : running.length > 0 ? 3 : 5
    const okCount = finished.filter(a => a.status === 'done').length
    const badCount = finished.length - okCount
    const doneCard = finished.length > 0 && (
      <Box key="done" flexDirection="column">
        {cardTop(
          'done',
          C.frame,
          <Text>
            <Text bold color={C.ok}>
              DONE
            </Text>
            <Text color={C.ok}> {finished.length}</Text>
          </Text>,
          cellsOf(`DONE ${finished.length}`),
          <Box flexDirection="row">
            <Text>
              <Text color={C.ok}>✓{okCount}</Text>
              {badCount ? <Text color={C.bad}> ✗{badCount}</Text> : ''}
              <Text color={C.muted}> · </Text>
            </Text>
            <Button
              key="fold-done"
              label={showAll ? '▾' : '▸'}
              plain
              hotkey="f"
              onPress={() => update($, view, prev => ({ ...prev, isDoneAll: !showAll }))}
            />
          </Box>,
          // The fold Button draws as "f: ▸".
          cellsOf(`✓${okCount}${badCount ? ` ✗${badCount}` : ''} · `) + 4,
        )}
        {finished.slice(0, doneLimit).map(a => shortRow(a, C.frame))}
        {finished.length > doneLimit &&
          cardRow(
            'done-more',
            C.frame,
            line('done-more-t', <Text color={C.faint}>  + {finished.length - doneLimit} older</Text>),
            fixed('done-more-r', <Text color={C.muted}>f: show all</Text>),
          )}
        {cardBottom('done', C.frame)}
      </Box>
    )

    // ================= FILES: the figures the tree card shows =================
    const ownerColor = whoColor
    const filesMeta = `${touched.filter(f => f.kind === 'edit').length} edit · ${touched.filter(f => f.kind === 'read').length} read`

    // ================= REQUESTS =================
    const isOpenAsk = (x: Ask) => x.status === 'open' || x.status === 'partial'
    const openAsks = askList.filter(isOpenAsk)
    const closedAsks = askList.filter(x => !isOpenAsk(x))
    // Latest closed; on a tie, the later in the list.
    const newestDone = closedAsks.reduce<Ask | undefined>(
      (best, x) => (!best || (x.doneAt ?? x.at) >= (best.doneAt ?? best.at) ? x : best),
      undefined,
    )
    const earlierDone = closedAsks.length - (newestDone ? 1 : 0)
    // Late: still open after a main turn ended, with no helper still on it.
    const isLate = (x: Ask) => isOpenAsk(x) && !m.isBusy && running.length === 0 && (m.turnEndedAt ?? 0) > x.at
    const lateCount = openAsks.filter(isLate).length
    const shownOpen = openAsks.slice(-6)
    const ASK_W = Math.max(10, inner - 2 - 4 - 6)
    const answeredCount = askList.filter(x => x.status === 'answered').length
    const asksMeta = `✓${askList.filter(x => x.status === 'done').length}${answeredCount ? ` · ↩${answeredCount}` : ''} · ${openAsks.length} open${lateCount ? ` · ! ${lateCount} late` : ''}`
    const openAskRows = (x: Ask) => {
      const late = isLate(x)
      const lines = wrapWords(shownAsk(x.text), ASK_W, 2)
      const mark = x.status === 'partial' ? '◐' : late ? '!' : '○'
      const color = late || x.status === 'partial' ? C.warn : C.fg
      return (
        <Box key={`ask-${x.id}`} flexDirection="column">
          {cardRow(
            `ask-${x.id}-r`,
            C.frame,
            fixed(`ask-${x.id}-m`, <Text bold={late} color={color}>{mark} </Text>),
            line(
              `ask-${x.id}-t`,
              <Text color={color}>
                <Text color={C.muted}>{x.id.padEnd(3)} </Text>
                {lines[0] ?? ''}
              </Text>,
            ),
            fixed(`ask-${x.id}-a`, <Text color={late ? C.warn : C.muted}> {fmtAge(now - x.at).padStart(4)}</Text>),
          )}
          {lines.slice(1).map((l, k) =>
            cardRow(`ask-${x.id}-w${k}`, C.frame, line(`ask-${x.id}-wt${k}`, <Text color={color}>{'      '}{l}</Text>)),
          )}
        </Box>
      )
    }
    const asksCard = askList.length > 0 && (
      <Box key="asks" flexDirection="column">
        {cardTop(
          'asks',
          lateCount ? C.warn : C.frame,
          <Text>
            <Text bold color={C.fg}>
              REQUESTS
            </Text>
            <Text color={C.fg}> {askList.length}</Text>
          </Text>,
          cellsOf(`REQUESTS ${askList.length}`),
          <Text color={lateCount ? C.warn : C.muted}>{asksMeta}</Text>,
          cellsOf(asksMeta),
        )}
        {openAsks.length > shownOpen.length &&
          cardRow('asks-older', C.frame, line('asks-older-t', <Text color={C.faint}>  + {openAsks.length - shownOpen.length} older open</Text>))}
        {shownOpen.map(openAskRows)}
        {newestDone &&
          cardRow(
            'ask-done',
            C.frame,
            fixed(
              'ask-done-m',
              <Text color={newestDone.status === 'done' ? C.ok : C.muted}>
                {newestDone.status === 'dropped' ? '✗' : newestDone.status === 'answered' ? '↩' : '✓'}{' '}
              </Text>,
            ),
            line(
              'ask-done-t',
              <Text color={C.fg2}>
                <Text color={C.muted}>{newestDone.id.padEnd(3)} </Text>
                {shownAsk(newestDone.text)}
              </Text>,
            ),
            fixed('ask-done-a', <Text color={C.muted}> {fmtAge(now - (newestDone.doneAt ?? newestDone.at)).padStart(4)}</Text>),
          )}
        {newestDone?.proof &&
          cardRow('ask-done-p', C.frame, line('ask-done-pt', <Text color={C.muted}>{'    ↳ '}{newestDone.proof}</Text>))}
        {earlierDone > 0 &&
          cardRow('asks-earlier', C.frame, line('asks-earlier-t', <Text color={C.faint}>  + {earlierDone} earlier closed</Text>))}
        {cardBottom('asks', lateCount ? C.warn : C.frame)}
      </Box>
    )

    // ================= COMMENTARY =================
    const talkCard = isTalkOn && (
      <Box key="talk" flexDirection="column">
        {cardTop(
          'talk',
          C.frame,
          <Text bold color={C.brand}>
            COMMENTARY
          </Text>,
          cellsOf('COMMENTARY'),
          <Text color={C.muted}>/mission-talk off</Text>,
          cellsOf('/mission-talk off'),
        )}
        {talkLines.length === 0 &&
          cardRow('talk-none', C.frame, line('talk-none-t', <Text italic color={C.muted}>the first call comes after this turn…</Text>))}
        {talkLines.slice(-3).map((l, i) =>
          cardRow(
            `talk-${i}`,
            C.frame,
            line(
              `talk-${i}-t`,
              <Text>
                <Text color={C.muted}>{fmtAge(now - l.at).padStart(4)} </Text>
                <Text italic color={C.fg}>
                  {l.text}
                </Text>
              </Text>,
            ),
          ),
        )}
        {cardBottom('talk', C.frame)}
      </Box>
    )

    // ================= ACTIVITY =================
    const allTools = [
      ...m.tools.map(r => ({ ...r, owner: 'main', isSub: false })),
      ...list.flatMap(a => a.tools.map(r => ({ ...r, owner: a.id, isSub: true }))),
    ]
      .filter(r => !HIDDEN_TOOLS.test(r.tool))
      .sort((x, y) => (x.startedAt ?? 0) - (y.startedAt ?? 0))
    // One row of squares: the recent rhythm.
    const cells = squares(allTools.slice(-inner), inner)
    const counts = kindCounts(allTools)
    const LABEL_W = Math.max(10, Math.min(22, Math.floor(inner * 0.4)))
    const OWNER_W = 10
    const barW = Math.max(4, inner - OWNER_W - LABEL_W - 6 - 3)
    const picks = activityRows(
      allTools.map(r => ({
        id: `${r.owner}-${r.id}`,
        tool: r.tool,
        label: r.label,
        owner: r.owner,
        status: r.status,
        startedAt: r.startedAt ?? now,
        endedAt: r.endedAt,
      })),
      now,
      LABEL_W,
      barW,
      6,
    )
    const activityCard = (
      <Box key="activity" flexDirection="column">
        {cardTop(
          'activity',
          C.frame,
          <Text bold color={C.pace}>
            ACTIVITY
          </Text>,
          cellsOf('ACTIVITY'),
          <Text color={C.muted}>{`${allTools.length} recent`}</Text>,
          cellsOf(`${allTools.length} recent`),
        )}
        {cells.length === 0 && cardRow('act-none', C.frame, line('act-none-t', <Text color={C.muted}>no tool calls yet</Text>))}
        {cells.slice(-1).map((row, i) =>
          cardRow(
            `sq-${i}`,
            C.frame,
            line(
              `sq-${i}-t`,
              <Text>
                {row.map((c, k) => (
                  <Text key={`sq-${i}-${k}`} color={c.color}>
                    {c.glyph}
                  </Text>
                ))}
              </Text>,
            ),
          ),
        )}
        {counts.kinds.length > 0 &&
          cardRow(
            'act-counts',
            C.frame,
            line(
              'act-counts-t',
              <Text>
                {counts.kinds.map((k, i) => (
                  <Text key={`cnt-${k.kind}`}>
                    {i > 0 ? <Text color={C.faint}> · </Text> : ''}
                    <Text color={k.color}>{k.kind} </Text>
                    <Text color={C.fg}>{k.n}</Text>
                  </Text>
                ))}
                {counts.failed > 0 && (
                  <Text>
                    <Text color={C.faint}> · </Text>
                    <Text bold color={C.bad}>
                      ✗ {counts.failed} failed
                    </Text>
                  </Text>
                )}
              </Text>,
            ),
          )}
        {picks.length > 0 && cardRow('act-gap', C.frame, line('act-gap-t', <Text color={C.faint}>{'┄'.repeat(200)}</Text>))}
        {picks.map(r =>
          cardRow(
            `act-${r.id}`,
            C.frame,
            line(
              `act-${r.id}-t`,
              <Text>
                <Text color={whoColor(r.owner)}>{fitTo(whoName(r.owner), OWNER_W - 1)} </Text>
                <Text color={r.why === 'fail' ? C.bad : C.fg2}>{r.label} </Text>
                <Text color={r.color}>{r.bar}</Text>
                <Text color={r.why === 'run' ? C.warn : C.muted}>{r.dur} </Text>
                <Text color={r.markColor}>{r.mark}</Text>
              </Text>,
            ),
          ),
        )}
        {cardBottom('activity', C.frame)}
      </Box>
    )
    const msgLines = arcs(messages, Object.fromEntries(list.map(a => [a.id, a])), now)
    const msgCard = msgLines.length > 0 && (
      <Box key="msgs" flexDirection="column">
        {cardTop(
          'msgs',
          C.frame,
          <Text bold color={C.pace}>
            MESSAGES
          </Text>,
          cellsOf('MESSAGES'),
          <Text color={C.muted}>{`${messages.length}`}</Text>,
          cellsOf(`${messages.length}`),
        )}
        {msgLines.slice(-8).map((t2, i) => cardRow(`msg-${i}`, C.frame, line(`msg-${i}-t`, <Text color={C.fg2}>{t2}</Text>)))}
        {cardBottom('msgs', C.frame)}
      </Box>
    )

    // ================= FILES: the touched files as a tree =================
    // Shorter while helpers run; it sits last, under everything else.
    const tree = treeLines(touched, inner, { maxLines: running.length ? 8 : 16, now })
    const treeCard = (
      <Box key="tree" flexDirection="column">
        {cardTop(
          'tree',
          C.frame,
          <Text>
            <Text bold color={C.edit}>
              FILES
            </Text>
            <Text color={C.edit}> {touched.length}</Text>
          </Text>,
          cellsOf(`FILES ${touched.length}`),
          <Text color={C.muted}>{filesMeta}</Text>,
          cellsOf(filesMeta),
        )}
        {tree.length === 0 && cardRow('tree-none', C.frame, line('tree-none-t', <Text color={C.muted}>nothing touched yet</Text>))}
        {tree.map((l2, i) => {
          const nameColor = l2.more
            ? C.faint
            : l2.clash
              ? C.warn
              : l2.root
                ? C.brand
                : l2.isDir
                  ? l2.dim
                    ? C.muted
                    : C.pace
                  : l2.kind === 'edit'
                    ? C.fg
                    : C.muted
          const right = l2.isDir || l2.root || l2.more ? (l2.count !== undefined ? String(l2.count) : '') : whoName(l2.owner ?? '')
          return cardRow(
            `tree-${i}`,
            C.frame,
            line(
              `tree-${i}-t`,
              <Text>
                <Text color={C.faint}>{l2.indent}</Text>
                <Text bold={l2.root === true} color={nameColor}>
                  {l2.clash && !l2.isDir ? '! ' : ''}
                  {l2.name}
                </Text>
              </Text>,
            ),
            fixed(
              `tree-${i}-r`,
              <Text>
                <Text color={l2.isDir || l2.root ? C.muted : ownerColor(l2.owner ?? '')}> {fitTo(right, 10)}</Text>
                <Text color={C.muted}>{(l2.age ?? '').padStart(4)}</Text>
              </Text>,
            ),
          )
        })}
        {cardBottom('tree', C.frame)}
      </Box>
    )

    return (
      <Box flexDirection="column">
        {header}
        {mainBlock}
        {asksCard}
        {runningCard}
        {/* The batch's lanes once it ended; while it runs, RUNNING tells it. */}
        {running.length === 0 && batchCard}
        {doneCard}
        {talkCard}
        {activityCard}
        {msgCard}
        {treeCard}
      </Box>
    )
  })

  // A band above the prompt: the crew at a glance. One line; the least
  // important parts drop first when the column is narrow.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    // The pane opens itself once, and only beside a fullscreen transcript.
    if (!autoOpened && e.viewport?.isFullscreen === true) {
      autoOpened = true
      void openPane($, false)
    }

    const list: AgentRun[] = await read($, agents)
    const v: View = await read($, view)
    if (e.props.hasSurvey || list.length === 0 || v.isBandHidden) return next(e)

    const els = $.ui.resolve(e)
    const { Box, Text, Button } = els
    const Client = 'Client' in els ? els.Client : undefined
    const now = await $.clock.now()
    const u: Usage = await read($, usage)
    const samples = await read($, hist)
    const running = list.filter(a => a.status === 'running')
    const done = list.filter(a => a.status === 'done').length
    const failed = list.filter(a => a.status === 'failed').length
    // Written by the clock only when it changes: the band never redraws per tick.
    const waiting = await read($, waitN)
    const mm = await read($, main)
    const late = (await read($, asks)).filter(
      a => (a.status === 'open' || a.status === 'partial') && !mm.isBusy && running.length === 0 && (mm.turnEndedAt ?? 0) > a.at,
    ).length
    const lateText = late ? `  ! ${late} request${late === 1 ? '' : 's'} open` : ''
    const lead = running[running.length - 1]
    const burn = burnPerHour(samples, now)
    const five = u.fiveHour !== undefined ? runOut(samples, now, 'fiveHour', u.fiveReset) : undefined
    const last = [...batchesOf(list, now)].reverse().find(b => b.ids.length >= 2 && b.endedAt)

    const face = waiting ? '◕o◕' : running.length ? '◉‿◉' : failed && !done ? 'x_x' : '^‿^'
    const status = running.length ? `${running.length} working` : 'all done'
    const counts = `✓${done}${failed ? ` ✗${failed}` : ''}`
    const money = `${fmtCost(u.costUsd)}${burn >= 0.01 ? ` · ${fmtCost(burn)}/h` : ''}`

    // Parts that may drop, least important first.
    type Part = { key: string; text: string; node: RenderChildren }
    const sep = <Text color={C.faint}>{'  │  '}</Text>
    const parts: Part[] = []
    if (u.ctxPercent >= 0)
      parts.push({
        key: 'ctx',
        text: `  │  ctx ▰▰▰▰▰▰ ${u.ctxPercent}%`,
        node: (
          <Text key="b-ctx">
            {sep}
            <Text color={C.muted}>ctx </Text>
            <Text color={ctxColor(u.ctxPercent)}>{bar(u.ctxPercent, 6, '▰', '▱')}</Text>
            <Text color={C.muted}> {u.ctxPercent}%</Text>
          </Text>
        ),
      })
    if (running.length && five?.beforeReset)
      parts.push({
        key: 'five',
        text: `  │  5h ${Math.round(u.fiveHour ?? 0)}% · out in ${fmtEta(five.etaMs)}`,
        node: (
          <Text key="b-five">
            {sep}
            <Text color={C.warn}>
              5h {Math.round(u.fiveHour ?? 0)}% · out in {fmtEta(five.etaMs)}
            </Text>
          </Text>
        ),
      })
    if (!running.length && last)
      parts.push({
        key: 'batch',
        text: `  │  last batch ${last.parallelism.toFixed(1)}× · ${fmtTime(last.wallMs)}`,
        node: (
          <Text key="b-batch">
            {sep}
            <Text color={C.muted}>last batch </Text>
            <Text bold color={C.ok}>
              {last.parallelism.toFixed(1)}×
            </Text>
            <Text color={C.muted}> · {fmtTime(last.wallMs)}</Text>
          </Text>
        ),
      })
    const fixedText = `◆ ${face} ${status}${waiting ? `  ! ${waiting} needs you` : ''}${lateText}  ${counts}  │  ${money}`
    const room = (e.props.bodyColumns || 80) - 12
    // Drop the ctx bar first, then the forecast or batch, then the counts.
    let kept = [...parts]
    const width = () => fixedText.length + kept.reduce((n, p) => n + p.text.length, 0)
    while (kept.length && width() > room) kept = kept.slice(1)
    const showCounts = fixedText.length <= room

    return (
      <Box flexDirection="row">
        {running.length > 0 && Client && (
          <Box flexShrink={0} width={2}>
            <Client key="mc-spin" module="./robot-clip.ts" props={spinClip(SPIN, C.run)} width={1} height={1} />
          </Box>
        )}
        <Box flexGrow={1} flexShrink={1}>
          <Text wrap="truncate-end">
            <Text color={C.brand}>◆ </Text>
            <Text color={waiting ? C.warn : (lead?.color ?? C.ok)}>{face} </Text>
            <Text bold color={running.length ? C.run : C.ok}>
              {status}
            </Text>
            {waiting > 0 && (
              <Text bold color={C.warn}>
                {'  '}! {waiting} need{waiting === 1 ? 's' : ''} you
              </Text>
            )}
            {late > 0 && (
              <Text bold color={C.warn}>
                {lateText}
              </Text>
            )}
            {showCounts && (
              <Text>
                <Text color={C.ok}>{'  '}✓{done}</Text>
                {failed ? <Text color={C.bad}> ✗{failed}</Text> : ''}
              </Text>
            )}
            {kept.map(p => p.node)}
            {sep}
            <Text color={C.money}>{money}</Text>
          </Text>
        </Box>
        <Box flexShrink={0} flexDirection="row">
          <Text> </Text>
          <Button key="mc-open" label="open" plain hotkey="o" onPress={() => void togglePane($)} />
          <Text> </Text>
          <Button
            key="mc-hide"
            label="✕"
            plain
            role="dismiss"
            onPress={() => update($, view, prev => ({ ...prev, isBandHidden: true }))}
          />
        </Box>
      </Box>
    )
  })
}

// Pad or cut a string to exactly n cells.
function fitTo(s: string, n: number): string {
  const cells = [...s]
  return cells.length > n ? cells.slice(0, n - 1).join('') + '…' : s + ' '.repeat(n - cells.length)
}

function todosOf(e: unknown): Todo[] | undefined {
  const raw = (e as { todos?: unknown }).todos
  if (!Array.isArray(raw)) return undefined
  return raw
    .filter((x): x is Record<string, unknown> => typeof x === 'object' && x !== null)
    .map(x => ({
      content: typeof x.content === 'string' ? x.content : '',
      status: typeof x.status === 'string' ? x.status : '',
      activeForm: typeof x.activeForm === 'string' ? x.activeForm : undefined,
    }))
}
