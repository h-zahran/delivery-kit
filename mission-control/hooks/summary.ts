// Batch summary for the mission-control side pane: groups subagent runs into
// batches, renders a one-line receipt and per-agent swimlanes.
// Pure: no imports, no Date.now(), no Node APIs. `now` is always passed in.

/** The subset of AgentRun this module reads (structurally compatible). */
export type RunLike = {
  id: string
  status: 'running' | 'done' | 'failed' | 'idle'
  startedAt: number
  endedAt?: number
  costUsd: number
  toolCount: number
  /** Its calls; an idle run's work ended with the last of them. */
  tools?: readonly { startedAt: number; endedAt?: number }[]
  /** Its last step report. */
  progress?: { at: number }
}

export type Batch = {
  ids: string[]
  startedAt: number
  /** Absent while any member is still open (its end was taken from `now`). */
  endedAt?: number
  wallMs: number
  agentMs: number
  parallelism: number
  costUsd: number
  done: number
  failed: number
  running: number
  tools: number
}

/** Gap allowed between a batch's latest end and the next start. */
export const JOIN_GAP_MS = 30_000
const MAX_RECEIPT = 44

/**
 * End of an agent's active span. Running agents end at `now`. Anything else
 * uses `endedAt`. An idle run (waiting on its own background job) with no
 * `endedAt` ends at its last activity: no event says when it went idle, and
 * ending it at `now` would hold its batch open for the session. A done or
 * failed run with no `endedAt` (malformed) stays open at `now`. Never earlier
 * than `startedAt`.
 */
function endOf(a: RunLike, now: number): { end: number; open: boolean } {
  if (a.status === 'idle' && a.endedAt === undefined) return { end: lastActivity(a), open: false }
  const open = a.status === 'running' || a.endedAt === undefined
  const raw = open ? now : (a.endedAt as number)
  return { end: Math.max(raw, a.startedAt), open }
}

/** The latest time a run was seen working: its calls' ends (or starts), its last step report. */
function lastActivity(a: RunLike): number {
  let at = Math.max(a.startedAt, a.progress?.at ?? 0)
  for (const t of a.tools ?? []) at = Math.max(at, t.endedAt ?? t.startedAt)
  return at
}

type Acc = {
  ids: string[]
  start: number
  end: number
  open: boolean
  agentMs: number
  costUsd: number
  done: number
  failed: number
  running: number
  tools: number
}

function finish(b: Acc): Batch {
  const wallMs = b.end - b.start
  const out: Batch = {
    ids: b.ids,
    startedAt: b.start,
    wallMs,
    agentMs: b.agentMs,
    // Zero-length batch: report 1× (no parallel speed-up measurable).
    parallelism: wallMs > 0 ? b.agentMs / wallMs : 1,
    costUsd: b.costUsd,
    done: b.done,
    failed: b.failed,
    running: b.running,
    tools: b.tools,
  }
  if (!b.open) out.endedAt = b.end
  return out
}

/** Group agents into batches by a sweep over startedAt; oldest first, newest last. */
export function batchesOf(agents: readonly RunLike[], now: number): Batch[] {
  const sorted = [...agents].sort((x, y) => x.startedAt - y.startedAt)
  const out: Batch[] = []
  let cur: Acc | undefined
  for (const a of sorted) {
    const { end, open } = endOf(a, now)
    if (cur === undefined || a.startedAt > cur.end + JOIN_GAP_MS) {
      if (cur !== undefined) out.push(finish(cur))
      cur = {
        ids: [], start: a.startedAt, end, open: false, agentMs: 0, costUsd: 0,
        done: 0, failed: 0, running: 0, tools: 0,
      }
    }
    cur.ids.push(a.id)
    cur.end = Math.max(cur.end, end)
    cur.open = cur.open || open
    cur.agentMs += end - a.startedAt
    cur.costUsd += a.costUsd
    cur.tools += a.toolCount
    if (a.status === 'done') cur.done++
    else if (a.status === 'failed') cur.failed++
    else if (a.status === 'running') cur.running++
  }
  if (cur !== undefined) out.push(finish(cur))
  return out
}

/** m:ss under an hour, XhMM from an hour up (so an hour never reads as minutes). */
export function fmtDur(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000))
  if (s < 3600) return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
  const m = Math.floor(s / 60)
  return `${Math.floor(m / 60)}h${String(m % 60).padStart(2, '0')}`
}

/** One line, at most 44 chars: `3 helpers · 4:12 wall · 2.6× · $1.20`. */
export function receipt(batch: Batch): string {
  const n = batch.ids.length
  const who = `${n} ${n === 1 ? 'helper' : 'helpers'}`
  const wall = `${fmtDur(batch.wallMs)} wall`
  const p = batch.parallelism
  const par = p >= 1.1 ? `${p < 100 ? p.toFixed(1) : Math.round(p).toString()}×` : ''
  const cost = Math.max(0, batch.costUsd)
  const costs = [`$${cost.toFixed(2)}`, `$${Math.round(cost)}`]
  // Degrade: drop cents, then the × part, then hard-truncate.
  for (const withPar of par ? [true, false] : [false]) {
    for (const c of costs) {
      const line = [who, wall, ...(withPar ? [par] : []), c].join(' · ')
      if (line.length <= MAX_RECEIPT) return line
    }
  }
  const last = [who, wall, costs[1] ?? ''].join(' · ')
  return last.length <= MAX_RECEIPT ? last : last.slice(0, MAX_RECEIPT - 1) + '…'
}

const FULL = '━'
const LEFT = '╸' // heavy left half
const RIGHT = '╺' // heavy right half
const EMPTY = ' '

/**
 * One swimlane per batch member, in batch order. Each bar is exactly `width`
 * single-width cells, quantized to half-cells. Running agents end at `now`.
 */
export function timeline(
  batch: Batch,
  agents: readonly RunLike[],
  width: number,
  now: number,
): { id: string; bar: string }[] {
  const w = Math.max(0, Math.floor(width))
  const byId = new Map<string, RunLike>()
  for (const a of agents) byId.set(a.id, a)
  const s0 = batch.startedAt
  let e0 = batch.endedAt ?? now
  for (const id of batch.ids) {
    const a = byId.get(id)
    if (a) e0 = Math.max(e0, endOf(a, now).end)
  }
  const span = e0 - s0
  const halves = 2 * w
  const rows: { id: string; bar: string }[] = []
  for (const id of batch.ids) {
    const a = byId.get(id)
    if (a === undefined) {
      rows.push({ id, bar: EMPTY.repeat(w) })
      continue
    }
    let lo: number
    let hi: number
    if (span <= 0) {
      lo = 0
      hi = halves
    } else {
      const end = endOf(a, now).end
      lo = Math.round(((a.startedAt - s0) / span) * halves)
      hi = Math.round(((end - s0) / span) * halves)
      lo = Math.min(Math.max(lo, 0), halves)
      hi = Math.min(Math.max(hi, 0), halves)
      if (hi <= lo) {
        // Always show at least one half-cell.
        if (lo < halves) hi = lo + 1
        else lo = hi - 1
      }
    }
    const cells: string[] = []
    for (let i = 0; i < w; i++) {
      const l = lo <= 2 * i && 2 * i < hi
      const r = lo <= 2 * i + 1 && 2 * i + 1 < hi
      cells.push(l && r ? FULL : l ? LEFT : r ? RIGHT : EMPTY)
    }
    rows.push({ id, bar: cells.join('') })
  }
  return rows
}
