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
 * - a time ≤ 0 is no time: it changes nothing, and a track based on one is
 *   started afresh at the next real time, so no step is measured from 0.
 */
export function trackSteps(prev: StepTrack | undefined, next: StepCount, at: number): StepTrack {
  const done = Math.max(0, Math.floor(next.done))
  const total = Math.max(0, Math.floor(next.total))
  if (!(at > 0)) return prev ?? { startedAt: 0, lastAt: 0, done, total, marks: [] }
  if (!prev || !(prev.lastAt > 0)) return { startedAt: at, lastAt: at, done, total, marks: [] }
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
    // One measured step is a guess, not a pace to fall behind.
    isLong: samples.length >= 2 && med > 0 && cur > 2 * med,
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

/**
 * Whether the main loop's plan is its todo list: one with a todo still open,
 * or a finished one with no step plan beside it. A finished list gives way to
 * the step reports, which may still have steps to go.
 */
export function isTodoPlan(todos: readonly { status: string }[], progress?: { total?: number }): boolean {
  if (todos.length === 0) return false
  return todos.some(t => t.status !== 'completed') || !((progress?.total ?? 0) > 0)
}

/**
 * Whether a step report starts a new plan rather than moving the one there is:
 * `done: 0` with a `total` (or step names), over a plan that had moved on, was
 * finished, or counts or names other steps. The old plan's names, note and
 * timing go; the same plan sent again at step 0 stays as it is.
 */
export function isNewPlan(
  prev: { done: number; total?: number; steps?: readonly string[] } | undefined,
  step: { done: number; total?: number; steps?: readonly string[] },
): boolean {
  if (!prev || step.done !== 0 || step.total === undefined) return false
  if (prev.done > 0 || step.total !== prev.total) return true
  return step.steps !== undefined && step.steps.join('\n') !== (prev.steps ?? []).join('\n')
}

export type HelperIn = { status: string; track?: StepTrack }
export type RowIn = {
  todos: readonly { status: string }[]
  /** The main loop's own step reports, used when its todos are not the plan (isTodoPlan). */
  progress?: { done: number; total?: number }
  mainTrack?: StepTrack
  helpers: readonly HelperIn[]
  now: number
}

/**
 * The Spinner row's text, or undefined to leave the engine's own.
 * Convention: percent = done/total, step = the one in progress (done+1).
 *   `25% · step 2/4 · 4m33s · ~12m left`   (4m33s: time on the current step)
 *   `3 helpers working · ~5m left`          (every helper has an ETA: the slowest)
 *   `3 helpers working · 2 ~5m left (1 unknown)`   (some have none yet)
 * The percent rounds down: 199/200 is 99%, never 100% with a step left.
 */
export function workingRow(i: RowIn): string | undefined {
  const { done, total } = isTodoPlan(i.todos, i.progress)
    ? todoCount(i.todos)
    : { done: i.progress?.done ?? 0, total: i.progress?.total ?? 0 }
  if (total > 0 && done < total) {
    const parts = [`${Math.floor((100 * done) / total)}%`, `step ${done + 1}/${total}`]
    if (i.mainTrack && i.mainTrack.lastAt > 0) parts.push(fmtDur(i.now - i.mainTrack.lastAt))
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
  if (long > 0) parts.push(`${long} running long`)
  else if (known.length > 0) {
    const slowest = known.reduce((a, e) => (e.leftMs > a.leftMs ? e : a), known[0] as Eta)
    const left = fmtLeft(slowest.leftMs) + (known.some(e => e.isRough) ? '?' : '')
    const unknown = etas.length - known.length
    parts.push(unknown > 0 ? `${known.length} ${left} (${unknown} unknown)` : left)
  }
  return parts.join(' · ')
}

/** The main loop's tracks: `main` (its step reports) and `main:*` (its todos, `main:todos`). */
const isMainKey = (k: string): boolean => k === 'main' || k.startsWith('main:')

/** The tracks of agents still listed, and the main loop's; `t` itself when none goes. */
export function pruneTracks<T>(t: Record<string, T>, ids: readonly string[]): Record<string, T> {
  const keep = new Set(ids)
  const gone = Object.keys(t).filter(k => !isMainKey(k) && !keep.has(k))
  if (gone.length === 0) return t
  const out = { ...t }
  for (const k of gone) delete out[k]
  return out
}

/**
 * At a turn's start: the main loop's tracks restart their current step at `at`
 * (the time between turns was the person's), their measured steps kept.
 * Helpers' tracks are left alone; `t` itself when there is no main track.
 */
export function restartSteps(t: Record<string, StepTrack>, at: number): Record<string, StepTrack> {
  const keys = Object.keys(t).filter(isMainKey)
  if (keys.length === 0) return t
  const out = { ...t }
  for (const k of keys) {
    const tr = out[k]
    if (tr) out[k] = { ...tr, lastAt: at }
  }
  return out
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
