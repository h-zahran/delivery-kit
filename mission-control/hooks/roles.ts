// Each helper's role, read from its mission: the words of its task pick a
// role, the role gives it a color (a shade per teammate), a robot and a line
// to say. And its mood: tired, nervous or ouch over what it does now.
// Pure: no engine, no clock (the caller passes `now`).

import type { Mood, State } from './robots'

export type RoleId = 'scout' | 'builder' | 'fixer' | 'inspector' | 'researcher' | 'planner' | 'writer'

export type Role = {
  id: RoleId
  /** Its robot in robots.ts. */
  robot: string
  /** Three shades of one color: the 1st, 2nd and 3rd helper of the role. */
  shades: readonly [string, string, string]
  says: { work: string; done: string }
  /** The words that pick the role: a whole word ends at a word boundary, a stem takes any ending. */
  words: RegExp
  /** How a brief's opening "You are …" names the role, tested per word. */
  named: RegExp
}

// Listed in the order a tie goes: a fix beats a test, a test beats a build.
export const ROLES: readonly Role[] = [
  {
    id: 'fixer',
    robot: 'fixer',
    shades: ['#ff8a7a', '#ffad9f', '#e86a5a'],
    says: { work: 'fixing…', done: 'fixed!' },
    words: /\b(fix(es|ed|ing)?\b|debug|bugs?\b|bugfix|errors?\b|repair|patch|resolv|crash|reproduc(e|es|ed|ing)\b|repro\b|regression)/i,
    named: /^(fix|debug)/i,
  },
  {
    id: 'inspector',
    robot: 'inspector',
    shades: ['#9ee86f', '#bdf29b', '#7cc94e'],
    says: { work: 'checking…', done: 'all good!' },
    words: /\b(tests?\b|test(ed|ing)\b|review|checks?\b|check(ed|ing)\b|verif|audit|validat|lint|inspect)/i,
    named: /^(review|audit|test)/i,
  },
  {
    id: 'planner',
    robot: 'Plan',
    shades: ['#8ab4ff', '#b0ccff', '#6493e6'],
    says: { work: 'thinking…', done: 'got a plan!' },
    words: /\b(plan(s|ned|ning)?\b|design(s|ed|ing)?\b|architect|outline|propos|strateg)/i,
    named: /^plan/i,
  },
  {
    id: 'researcher',
    robot: 'researcher',
    shades: ['#c3a6ff', '#dac8ff', '#a585ec'],
    says: { work: 'reading up…', done: 'learned it!' },
    words: /\b(research|web\b|compar|investigat|learn|stud(y|ies|ying)\b|analy)/i,
    named: /^research/i,
  },
  {
    id: 'writer',
    robot: 'writer',
    shades: ['#f78fb3', '#fab3cc', '#e06d95'],
    says: { work: 'writing…', done: 'done writing!' },
    words: /\b(writ|document|readme|changelog|docs?\b|draft|reports?\b|report(ed|ing)\b|describ|explain)/i,
    named: /^writ/i,
  },
  {
    id: 'builder',
    robot: 'builder',
    shades: ['#ff9f43', '#ffbf7a', '#e07f22'],
    says: { work: 'building…', done: 'built!' },
    words: /\b(build|creat|add(s|ed|ing)?\b|implement|mak(e|es|ing)\b|set ?up\b|scaffold|generat|port(s|ed|ing)?\b|migrat|refactor)/i,
    named: /^(implement|build)/i,
  },
  {
    id: 'scout',
    robot: 'Explore',
    shades: ['#4fd6e8', '#86e6f2', '#2cb4c8'],
    says: { work: 'looking around…', done: 'found it!' },
    words: /\b(find|read(s|ing)?\b|summar|scan|explor|search|look(s|ed|ing)?\b|list(s|ed|ing)?\b|map(s|ped)?\b|locat|survey)/i,
    named: /^(scout|explor)/i,
  },
]

const byId = new Map(ROLES.map(r => [r.id, r]))
export const roleById = (id: string | undefined): Role | undefined => (id ? byId.get(id as RoleId) : undefined)

// Agent types that already say what they do.
const TYPE_ROLE: Record<string, RoleId> = { Explore: 'scout', Plan: 'planner' }

/**
 * The role a brief gives its helper in its first line, "You are the release
 * builder…", "You are implementing Task 3…": the first of its next four words
 * that names a role.
 */
export function namedRole(prompt: string): Role | undefined {
  const first = prompt.split(/\r?\n/).find(l => l.trim()) ?? ''
  const head = /^\s*You are (?:the |an? )?([\w -]*)/i.exec(first)?.[1] ?? ''
  for (const w of head.split(/\s+/).filter(Boolean).slice(0, 4)) {
    const r = ROLES.find(r => r.named.test(w))
    if (r) return r
  }
  return undefined
}

/**
 * The role a task's words pick: the word that comes first (ties go by the
 * order of ROLES). Of three words or more the last is likely a noun, as in
 * "Lane 056 one config read", so it picks nothing. Of two, a last "plan" is
 * the thing made: a test plan is a planner's.
 */
export function wordRole(description: string): Role | undefined {
  const words = description.match(/\S+/g) ?? []
  if (words.length === 2 && /^plans?$/i.test(words[1]!)) return roleById('planner')
  const lastAt = words.length >= 3 ? description.trimEnd().length - words[words.length - 1]!.length : Infinity
  let best: Role | undefined
  let bestAt = Infinity
  for (const r of ROLES) {
    const m = r.words.exec(description)
    if (m && m.index < bestAt && m.index < lastAt) {
      best = r
      bestAt = m.index
    }
  }
  return best
}

/**
 * The role a mission reads as: an agent type that already says what it does
 * (Explore, Plan), else the brief's "You are …" line, else the task's words,
 * else none (the helper keeps the plain look). A fix is a fixer's work even
 * when the brief calls its helper the implementer.
 */
export function roleOf(description: string, type: string, prompt = ''): Role | undefined {
  const typed = roleById(TYPE_ROLE[type])
  if (typed) return typed
  const named = namedRole(prompt)
  if (named?.id === 'builder' && /\bfix(es|ed|ing)?\b/i.test(description)) return roleById('fixer')
  return named ?? wordRole(description)
}

/** The color of a new helper of `role`: the next shade after its teammates. */
export function shadeOf(role: Role, teammates: number): string {
  return role.shades[teammates % role.shades.length] ?? role.shades[0]
}

/** Context fill (percent) from which a robot gets tired. */
export const TIRED_PCT = 85
/** How long a permission wait lasts before the robot gets nervous. */
export const NERVOUS_MS = 10_000
/** How long a robot says "ouch" after a failed tool call. */
export const OUCH_MS = 10_000

export const MOOD_SAY: Record<Mood, string> = {
  tired: 'so sleepy…',
  nervous: 'waiting for you…',
  ouch: 'ouch!',
}

/**
 * The look a robot shows: its state, or a mood over it. A long permission
 * wait makes it nervous; at work, a call that just failed is "ouch", and an
 * almost full context makes it tired.
 */
export function lookOf(
  state: State,
  a: { ctxPct: number; waitSince?: number; tools: readonly { status: string; endedAt?: number }[] },
  now: number,
): State {
  if (state === 'wait') return a.waitSince !== undefined && now - a.waitSince >= NERVOUS_MS ? 'nervous' : 'wait'
  if (state !== 'work' && state !== 'think') return state
  // Any call that failed a moment ago, even if a new one already runs.
  if (a.tools.some(t => t.status === 'err' && t.endedAt !== undefined && now - t.endedAt < OUCH_MS)) return 'ouch'
  if (a.ctxPct >= TIRED_PCT) return 'tired'
  return state
}

/** What the helper says now; a mood speaks first. */
export function sayOf(role: Role, status: string, look?: State): string {
  if (look === 'tired' || look === 'nervous' || look === 'ouch') return MOOD_SAY[look]
  if (status === 'done') return role.says.done
  if (status === 'failed') return 'oops…'
  if (status === 'idle') return 'resting…'
  return role.says.work
}
