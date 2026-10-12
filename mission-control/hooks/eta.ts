// Pure ETA math for mission-control: no engine, no clock, no I/O.
// Every function takes the time it should reason about (`at`, `now`) as an argument.

/** One update that finished `n` steps at `at`; `perStepMs` is each one's share of the wait. */
export type Mark = { at: number; n: number; perStepMs: number }

/** Step history of one list: the main loop's todos or one subagent's progress. */
export type StepTrack = {
  /** When the track was first seen. */
  startedAt: number
  /** When the current step began: the last completion, or startedAt. */
  lastAt: number
  done: number
  total: number
  /** The most recent completions, oldest first. */
  marks: Mark[]
}

export type StepCount = { done: number; total: number }
export type Eta = { leftMs: number; isRough: boolean; isLong: boolean }

const KEEP_MARKS = 8
/** How many recent step durations the median is taken over. */
const RECENT = 5

/**
 * Folds one observation of `{ done, total }` into the track. Returns `prev`
 * itself when nothing changed, so an atom update can skip the write.
 *
 * - `done` grew by k: one mark, each of the k steps credited (at - lastAt) / k
 *   (TodoWrite often flips several todos at once; k equal stamps would read 0).
 * - `done` shrank: the list was rewritten; history resets, startedAt kept.
 * - only `total` changed (a todo added mid-flight): history kept.
 */
export function trackSteps(prev: StepTrack | undefined, next: StepCount, at: number): StepTrack {
  const done = Math.max(0, Math.floor(next.done))
  const total = Math.max(0, Math.floor(next.total))
  if (!prev) return { startedAt: at, lastAt: at, done, total, marks: [] }
  if (done < prev.done) return { startedAt: prev.startedAt, lastAt: at, done, total, marks: [] }
  if (done > prev.done) {
    const n = done - prev.done
    const mark: Mark = { at, n, perStepMs: Math.max(0, at - prev.lastAt) / n }
    return { ...prev, lastAt: at, done, total, marks: [...prev.marks, mark].slice(-KEEP_MARKS) }
  }
  return total === prev.total ? prev : { ...prev, total }
}

/** The main loop's todos as a step count. */
export function todoCount(todos: readonly { status: string }[]): StepCount {
  return { done: todos.filter(t => t.status === 'completed').length, total: todos.length }
}

export function median(xs: readonly number[]): number {
  if (xs.length === 0) return 0
  const s = [...xs].sort((a, b) => a - b)
  const mid = s.length >> 1
  return s.length % 2 ? (s[mid] ?? 0) : ((s[mid - 1] ?? 0) + (s[mid] ?? 0)) / 2
}

/**
 * Time left: the median of the last few step durations times the steps left,
 * less what the current step has already used (never below the remaining full
 * steps). Undefined with no total or no finished step to measure.
 */
export function etaOf(track: StepTrack | undefined, now: number): Eta | undefined {
  if (!track || track.total <= 0) return undefined
  const remaining = track.total - track.done
  if (remaining <= 0) return { leftMs: 0, isRough: false, isLong: false }
  const samples: number[] = []
  for (const m of track.marks) for (let i = 0; i < m.n; i++) samples.push(m.perStepMs)
  if (samples.length === 0) return undefined
  const med = median(samples.slice(-RECENT))
  const cur = Math.max(0, now - track.lastAt)
  return {
    leftMs: Math.max(0, med - cur) + med * (remaining - 1),
    isRough: samples.length < 2,
    isLong: med > 0 && cur > 2 * med,
  }
}

/** `<1m left`, `~8m left`, `~1h05 left`. */
export function fmtLeft(ms: number): string {
  if (!(ms >= 60_000)) return '<1m left'
  const min = Math.round(ms / 60_000)
  if (min < 60) return `~${min}m left`
  return `~${Math.floor(min / 60)}h${String(min % 60).padStart(2, '0')} left`
}

/** `42s`, `4m33s`, `1h05m`. */
export function fmtDur(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000))
  if (s < 60) return `${s}s`
  if (s < 3600) return `${Math.floor(s / 60)}m${String(s % 60).padStart(2, '0')}s`
  return `${Math.floor(s / 3600)}h${String(Math.floor(s / 60) % 60).padStart(2, '0')}m`
}

/** An ETA as one row part: `~12m left`, `~12m left?` (rough), `running long`. */
export function etaPart(eta: Eta | undefined): string | undefined {
  // A finished plan has no time left to show.
  if (!eta || (eta.leftMs <= 0 && !eta.isLong)) return undefined
  if (eta.isLong) return 'running long'
  return fmtLeft(eta.leftMs) + (eta.isRough ? '?' : '')
}

export type HelperIn = { status: string; track?: StepTrack }
export type RowIn = {
  todos: readonly { status: string }[]
  /** The main loop's own step reports, used when it keeps no todos. */
  progress?: { done: number; total?: number }
  mainTrack?: StepTrack
  helpers: readonly HelperIn[]
  now: number
}

/**
 * The Spinner row's text, or undefined to leave the engine's own.
 * Convention: percent = done/total, step = the one in progress (done+1).
 *   `25% · step 2/4 · 4m33s · ~12m left`   (4m33s: time on the current step)
 *   `3 helpers working · ~5m left`          (ETA only when every helper has one)
 */
export function workingRow(i: RowIn): string | undefined {
  const fromTodos = todoCount(i.todos)
  const { done, total } =
    fromTodos.total > 0 ? fromTodos : { done: i.progress?.done ?? 0, total: i.progress?.total ?? 0 }
  if (total > 0 && done < total) {
    const parts = [`${Math.round((100 * done) / total)}%`, `step ${done + 1}/${total}`]
    if (i.mainTrack) parts.push(fmtDur(i.now - i.mainTrack.lastAt))
    const eta = etaPart(etaOf(i.mainTrack, i.now))
    if (eta) parts.push(eta)
    return parts.join(' · ')
  }
  const running = i.helpers.filter(h => h.status === 'running')
  if (running.length === 0) return undefined
  const parts = [`${running.length} helper${running.length === 1 ? '' : 's'} working`]
  const etas = running.map(h => etaOf(h.track, i.now))
  const long = etas.filter(e => e?.isLong).length
  const known = etas.filter((e): e is Eta => e !== undefined)
  if (known.length === etas.length && known.every(e => !e.isLong)) {
    const slowest = known.reduce((a, e) => (e.leftMs > a.leftMs ? e : a), known[0] as Eta)
    parts.push(fmtLeft(slowest.leftMs) + (known.some(e => e.isRough) ? '?' : ''))
  } else if (long > 0) parts.push(`${long} running long`)
  return parts.join(' · ')
}

export type RunIn = { status: string; startedAt: number; endedAt?: number }

/** True when this update ended the last running helper. `idle` is not running. */
export function batchEnded(before: readonly RunIn[], after: readonly RunIn[]): boolean {
  return before.some(r => r.status === 'running') && !after.some(r => r.status === 'running')
}

export type RollIn = RunIn & { name: string }

/**
 * The batch toast with a roll call: `3 helpers done in 0:42 · 1 failed:
 * scout ✓ 0:12 · fixer ✗ 0:30 · …`, in the order they ended, at most `max`.
 */
export function rollCall(runs: readonly RollIn[], sinceAt = 0, max = 6): string | undefined {
  const head = batchToast(runs, sinceAt)
  if (!head) return undefined
  const batch = runs.filter(r => r.endedAt !== undefined && r.endedAt > sinceAt).sort((a, b) => a.endedAt! - b.endedAt!)
  if (batch.length < 2) return head
  const items = batch
    .slice(0, max)
    .map(r => `${r.name} ${r.status === 'failed' ? '✗' : '✓'} ${fmtDur(r.endedAt! - r.startedAt)}`)
  const more = batch.length > max ? ` · +${batch.length - max} more` : ''
  return `${head}: ${items.join(' · ')}${more}`
}

/** `3 helpers done in 4m12s · 1 failed`; the runs that ended since `sinceAt`. */
export function batchToast(runs: readonly RunIn[], sinceAt = 0): string | undefined {
  const batch = runs.filter(r => r.endedAt !== undefined && r.endedAt > sinceAt)
  if (batch.length === 0) return undefined
  const start = Math.min(...batch.map(r => r.startedAt))
  const end = Math.max(...batch.map(r => r.endedAt!))
  const failed = batch.filter(r => r.status === 'failed').length
  const noun = batch.length === 1 ? 'helper' : 'helpers'
  return `${batch.length} ${noun} done in ${fmtDur(end - start)}${failed ? ` · ${failed} failed` : ''}`
}
