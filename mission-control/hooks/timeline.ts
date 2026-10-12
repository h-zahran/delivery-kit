// ACTIVITY card: pure layout helpers. No imports, no side effects.
// Every glyph used here is East Asian Width A or N (never W/F), so one cell each:
// ■ 25A0 A, □ 25A1 A, ▣ 25A3 A, ● 25CF A, ○ 25CB A, ◉ 25C9 N,
// ━ 2501 A, ╸ 2578 N, ╺ 257A N, ✓ 2713 N, ✗ 2717 N, • 2022 A, … 2026 A.

export type Kind = 'read' | 'edit' | 'shell' | 'web' | 'agent' | 'mcp' | 'other'
export type Status = 'run' | 'ok' | 'err'

export const KIND_COLOR: Record<Kind, string> = {
  read: '#6ea8ff',
  edit: '#5fd38d',
  shell: '#ff9f43',
  web: '#b48cff',
  agent: '#f78fb3',
  mcp: '#7ee0c3',
  other: '#a9b1d6',
}

export const FAIL_COLOR = '#ff6b6b'
export const OK_COLOR = '#5fd38d'

const KIND_ORDER: readonly Kind[] = ['read', 'edit', 'shell', 'web', 'agent', 'mcp', 'other']

const KIND_TOOLS: Record<Exclude<Kind, 'mcp' | 'other'>, readonly string[]> = {
  read: ['Read', 'Grep', 'Glob', 'LS', 'NotebookRead'],
  edit: ['Edit', 'Write', 'MultiEdit', 'NotebookEdit'],
  shell: ['Bash', 'PowerShell'],
  web: ['WebFetch', 'WebSearch'],
  agent: ['Agent', 'Task', 'SendMessage'],
}

export function kindOf(tool: string): Kind {
  if (tool.startsWith('mcp__')) return 'mcp'
  for (const k of ['read', 'edit', 'shell', 'web', 'agent'] as const) {
    if (KIND_TOOLS[k].includes(tool)) return k
  }
  return 'other'
}

export const GLYPH = {
  main: { ok: '■', run: '□', err: '▣' },
  sub: { ok: '●', run: '○', err: '◉' },
} as const

export type Cell = { glyph: string; color: string; kind: Kind; status: Status; isSub: boolean }

/** One cell per call, oldest first, newest last, wrapped into rows of `width`. */
export function squares(
  rows: readonly { tool: string; status: Status; isSub: boolean }[],
  width: number,
): Cell[][] {
  const w = Math.max(1, Math.floor(width) || 1)
  const out: Cell[][] = []
  let line: Cell[] = []
  for (const r of rows) {
    const kind = kindOf(r.tool)
    const set = r.isSub ? GLYPH.sub : GLYPH.main
    line.push({
      glyph: set[r.status],
      color: r.status === 'err' ? FAIL_COLOR : KIND_COLOR[kind],
      kind,
      status: r.status,
      isSub: r.isSub,
    })
    if (line.length === w) {
      out.push(line)
      line = []
    }
  }
  if (line.length) out.push(line)
  return out
}

export type DurationInput = {
  id: string
  tool: string
  label: string
  owner: string
  status: Status
  startedAt: number
  endedAt?: number
}

const shortTool = (tool: string): string => tool.replace(/^mcp__([^_]+)__/, '$1:')

function fit(s: string, w: number): string {
  if (w <= 0) return ''
  const cps = Array.from(s.replace(/\s+/g, ' '))
  if (cps.length <= w) return cps.join('') + ' '.repeat(w - cps.length)
  return cps.slice(0, w - 1).join('') + '…'
}

export function fmtDur(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000))
  const m = Math.floor(s / 60)
  const txt = m > 999 ? '999+' : `${m}:${String(s % 60).padStart(2, '0')}`
  return txt.padStart(6)
}

export type KindCount = { kind: Kind; n: number; color: string }

/** Calls per kind, most first, and how many failed. */
export function kindCounts(rows: readonly { tool: string; status: Status }[]): { kinds: KindCount[]; failed: number } {
  const n = new Map<Kind, number>()
  for (const r of rows) n.set(kindOf(r.tool), (n.get(kindOf(r.tool)) ?? 0) + 1)
  const kinds = KIND_ORDER.filter(k => (n.get(k) ?? 0) > 0)
    .map(k => ({ kind: k, n: n.get(k) ?? 0, color: KIND_COLOR[k] }))
    .sort((a, b) => b.n - a.n)
  return { kinds, failed: rows.filter(r => r.status === 'err').length }
}

export type Why = 'fail' | 'run' | 'slow'

export type ActivityRow = {
  id: string
  /** Owner tag, raw (the renderer names and colors it). */
  owner: string
  /** Exactly labelW cells: "tool arg", truncated with … or padded. */
  label: string
  /** Exactly barW cells: ━ in proportion to the longest pick, then spaces. */
  bar: string
  /** Exactly 6 cells, right-aligned m:ss. */
  dur: string
  /** One cell: ✗ failed, • running, ✓ ok. */
  mark: string
  color: string
  markColor: string
  why: Why
}

/** The running mark's color: a call that runs long reads as a warning. */
export const RUN_COLOR = '#f5c542'

/**
 * The calls worth a look, at most `limit`: the latest 2 that failed, then
 * those running over 5 s (longest first), then the slowest finished (1 s
 * and up). Each bar is in proportion to the longest pick.
 */
export function activityRows(
  rows: readonly DurationInput[],
  now: number,
  labelW: number,
  barW: number,
  limit = 6,
): ActivityRow[] {
  const durOf = (r: DurationInput) => Math.max(0, (r.status === 'run' ? now : (r.endedAt ?? now)) - r.startedAt)
  const failed = rows.filter(r => r.status === 'err').sort((a, b) => b.startedAt - a.startedAt).slice(0, 2)
  const running = rows.filter(r => r.status === 'run' && durOf(r) > 5000).sort((a, b) => durOf(b) - durOf(a))
  const slow = rows.filter(r => r.status === 'ok' && durOf(r) >= 1000).sort((a, b) => durOf(b) - durOf(a))
  const picks: { r: DurationInput; why: Why }[] = []
  const seen = new Set<string>()
  const add = (list: readonly DurationInput[], why: Why) => {
    for (const r of list) {
      if (picks.length >= limit || seen.has(r.id)) continue
      seen.add(r.id)
      picks.push({ r, why })
    }
  }
  add(failed, 'fail')
  add(running, 'run')
  add(slow, 'slow')
  const longest = Math.max(1, ...picks.map(p => durOf(p.r)))
  const w = Math.max(0, Math.floor(barW))
  return picks.map(({ r, why }) => {
    const kind = kindOf(r.tool)
    const d = durOf(r)
    const n = Math.min(w, Math.max(1, Math.round((w * d) / longest)))
    const name = shortTool(r.tool)
    return {
      id: r.id,
      owner: r.owner,
      label: fit(r.label ? `${name} ${r.label}` : name, labelW),
      bar: '━'.repeat(n) + ' '.repeat(w - n),
      dur: fmtDur(d),
      mark: why === 'fail' ? '✗' : why === 'run' ? '•' : '✓',
      color: why === 'fail' ? FAIL_COLOR : KIND_COLOR[kind],
      markColor: why === 'fail' ? FAIL_COLOR : why === 'run' ? RUN_COLOR : OK_COLOR,
      why,
    }
  })
}
