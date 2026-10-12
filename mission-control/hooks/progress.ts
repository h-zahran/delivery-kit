// Self-reported subagent progress: a tool the subagent calls (`mcp__<plugin>__step`),
// the prompt hint that asks it to, and the pure state update the pane draws from.
import type { ToolSpec } from 'claude-code'

export const STEP_TOOL_NAME = 'step'
export const NOTE_MAX = 40
export const STEP_NAME_MAX = 24
export const STEPS_MAX = 8

/** The argument of `$.tool.register` (session.start). */
export const stepToolArgs: ToolSpec = {
  name: STEP_TOOL_NAME,
  description:
    'Report progress on your own task to the side pane, which draws it as a progress bar. ' +
    'Once you have a plan, call it with `total` (your plan in 3-8 steps) and `done: 0`; ' +
    'call it again with the new `done` each time a step finishes, and `note` naming the step now in progress. ' +
    'Cheap and silent: it returns "ok", changes nothing else, and needs no mention in your answer. ' +
    'Leave `total` out to keep the previous one; send a new one if the plan changes. ' +
    'Optionally send `steps` (the step names, 2-3 words each) once, with the plan.',
  inputSchema: {
    type: 'object',
    properties: {
      done: { type: 'integer', minimum: 0, description: 'Steps finished so far.' },
      total: { type: 'integer', minimum: 1, description: 'Steps planned; may change if the plan changes.' },
      note: { type: 'string', maxLength: NOTE_MAX, description: 'The step in progress, a few words.' },
      steps: {
        type: 'array',
        items: { type: 'string', maxLength: STEP_NAME_MAX },
        maxItems: STEPS_MAX,
        description: 'Optional: the step names, 2-3 words each, sent once with the plan; sets `total`.',
      },
    },
    required: ['done'],
  },
  // Left out, a plugin tool waits behind ToolSearch; a subagent should see it directly.
  isDeferred: false,
}

export type Step = { done: number; total?: number; note?: string; steps?: string[] }
/** `since`: when `done` last changed, so when the current step began. */
export type Progress = { done: number; total?: number; note?: string; steps?: string[]; at: number; since?: number }

function toInt(v: unknown): number | undefined {
  const n = typeof v === 'number' ? v : typeof v === 'string' && v.trim() !== '' ? Number(v) : NaN
  return Number.isFinite(n) ? Math.round(n) : undefined
}

function toNote(v: unknown, max = NOTE_MAX): string | undefined {
  if (typeof v !== 'string') return undefined
  const s = v.replace(/\s+/g, ' ').trim()
  if (!s) return undefined
  return s.length > max ? `${s.slice(0, max - 1).trimEnd()}…` : s
}

// Step names: an array of strings (or one in JSON), each clipped; none when empty.
function toSteps(v: unknown): string[] | undefined {
  let raw = v
  if (typeof raw === 'string' && raw.trim().startsWith('[')) {
    try {
      raw = JSON.parse(raw)
    } catch {
      return undefined
    }
  }
  if (!Array.isArray(raw)) return undefined
  const steps = raw
    .map(x => toNote(x, STEP_NAME_MAX))
    .filter((x): x is string => x !== undefined)
    .slice(0, STEPS_MAX)
  return steps.length > 0 ? steps : undefined
}

/**
 * Reads a step from a `tool.call` event (arguments sit at its top level, beside
 * `tool`, `tool_use_id` and `agentId`). Undefined when `done` is missing or not a number.
 */
export function parseStep(e: unknown): Step | undefined {
  if (typeof e !== 'object' || e === null) return undefined
  const r = e as Record<string, unknown>
  const rawDone = toInt(r.done)
  if (rawDone === undefined) return undefined
  const steps = toSteps(r.steps)
  const rawTotal = toInt(r.total)
  const total = steps ? steps.length : rawTotal !== undefined && rawTotal >= 1 ? rawTotal : undefined
  const done = Math.max(0, total !== undefined ? Math.min(rawDone, total) : rawDone)
  const note = toNote(r.note)
  return {
    done,
    ...(total !== undefined ? { total } : {}),
    ...(note !== undefined ? { note } : {}),
    ...(steps !== undefined ? { steps } : {}),
  }
}

/**
 * The next progress: `total` carries over when left out (and `done` is clamped
 * to it); `note` carries over only while `done` stays the same, since a note
 * names the step in progress.
 */
export function applyStep(prev: Progress | undefined, step: Step, at: number): Progress {
  const total = step.total ?? prev?.total
  // Names carry over while the count still matches them.
  const steps = step.steps ?? (prev?.steps && prev.steps.length === total ? prev.steps : undefined)
  const done = total !== undefined ? Math.min(step.done, total) : step.done
  const note = step.note ?? (prev !== undefined && prev.done === done ? prev.note : undefined)
  const since = prev !== undefined && prev.done === done ? (prev.since ?? prev.at) : at
  return {
    done,
    ...(total !== undefined ? { total } : {}),
    ...(note !== undefined ? { note } : {}),
    ...(steps !== undefined ? { steps } : {}),
    at,
    since,
  }
}

export function stepToolFullName(pluginName: string): string {
  return `mcp__${pluginName}__${STEP_TOOL_NAME}`
}

/** Appended to a subagent's prompt at `agent.spawn`. */
export function progressHint(pluginName: string): string {
  const tool = stepToolFullName(pluginName)
  return (
    `Progress: if you have the tool \`${tool}\`, call it once you have a plan, with \`total\` (your plan in 3-8 steps) and \`done: 0\`. ` +
    `You may add \`steps\`: the step names, 2-3 words each. ` +
    `After each step finishes, call it again with the new \`done\` and a short \`note\` (the next step, a few words). ` +
    `It is cheap and silent; do not mention it in your answer. If you do not have that tool, ignore this.`
  )
}

/** The prompt with the hint appended, once: unchanged if it already names the tool. */
export function withHint(prompt: string, pluginName: string): string {
  if (prompt.includes(stepToolFullName(pluginName))) return prompt
  return `${prompt.trimEnd()}\n\n${progressHint(pluginName)}`
}
