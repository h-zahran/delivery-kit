// Pure helper for mission-control: short, distinct helper names.
// No engine, no clock: everything they need comes in as arguments.

export type Named = { id: string; description: string; type: string }

const wordsOf = (s: string): string[] => s.trim().split(/\s+/).filter(Boolean)
const same = (a: string | undefined, b: string | undefined): boolean =>
  a !== undefined && b !== undefined && a.toLowerCase() === b.toLowerCase()

/**
 * Short, distinct names for helpers that ran together: the leading and trailing
 * words every name in a group shares are cut, one word always kept.
 * ("Summarize bin folder", "Summarize mods folder" → "bin", "mods".)
 * A group of one, or a cut that makes two names equal, keeps the full name.
 */
export function shortNames(groups: readonly (readonly Named[])[]): Map<string, string> {
  const out = new Map<string, string>()
  for (const g of groups) {
    const ws = g.map(a => wordsOf(a.description || a.type))
    const first = ws[0] ?? []
    let pre = 0
    let suf = 0
    if (g.length >= 2) {
      const min = Math.min(...ws.map(w => w.length))
      while (pre < min - 1 && ws.every(w => same(w[pre], first[pre]))) pre++
      while (pre + suf < min - 1 && ws.every(w => same(w[w.length - 1 - suf], first[first.length - 1 - suf]))) suf++
    }
    const cut = g.map((a, i) => {
      const w = ws[i] ?? []
      return w.slice(pre, w.length - suf).join(' ') || a.description || a.type
    })
    const isDistinct = new Set(cut.map(c => c.toLowerCase())).size === cut.length
    g.forEach((a, i) => out.set(a.id, isDistinct ? (cut[i] ?? a.type) : a.description || a.type))
  }
  return out
}

export type PlanTone = 'done' | 'now' | 'next' | 'line' | 'extra'
export type PlanPart = { text: string; tone: PlanTone }

const cellsOf = (s: string): number => [...s].length

/** Parts cut to `width` cells, the last one ending in … when anything was cut. */
function cutParts(parts: readonly PlanPart[], width: number): PlanPart[] {
  const total = parts.reduce((n, p) => n + cellsOf(p.text), 0)
  if (total <= width) return [...parts]
  const out: PlanPart[] = []
  let room = Math.max(1, width) - 1
  for (const p of parts) {
    const n = cellsOf(p.text)
    if (n <= room) {
      out.push(p)
      room -= n
      continue
    }
    out.push({ text: [...p.text].slice(0, room).join('') + '…', tone: p.tone })
    break
  }
  return out
}

/**
 * The plan as one row: finished steps ✓, the current one ● in full (with
 * `extra`, e.g. "3/5 helpers done"), the next ones ○ by name. Too long for
 * `width`: the finished names go first (✓ alone), then the end is cut with … .
 */
export function planParts(steps: readonly string[], done: number, width: number, extra = ''): PlanPart[] {
  if (steps.length === 0) return []
  const cur = Math.max(0, Math.min(done, steps.length))
  const build = (isShort: boolean): PlanPart[] => {
    const out: PlanPart[] = []
    const sep = () => out.length > 0 && out.push({ text: ' ━ ', tone: 'line' })
    if (isShort && cur > 0) out.push({ text: '✓'.repeat(cur), tone: 'done' })
    steps.forEach((name, i) => {
      if (i < cur) {
        if (isShort) return
        sep()
        out.push({ text: `✓ ${name}`, tone: 'done' })
      } else if (i === cur) {
        sep()
        out.push({ text: `● ${name}`, tone: 'now' })
        if (extra) out.push({ text: ` ${extra}`, tone: 'extra' })
      } else {
        sep()
        out.push({ text: `○ ${name}`, tone: 'next' })
      }
    })
    return out
  }
  const full = build(false)
  if (full.reduce((n, p) => n + cellsOf(p.text), 0) <= width) return full
  return cutParts(build(true), width)
}

/** Words in at most `maxLines` lines of `width` cells; the last line ends in … when text is left. */
export function wrapWords(text: string, width: number, maxLines: number): string[] {
  const w = Math.max(1, Math.floor(width))
  const lines: string[] = []
  let cur = ''
  for (const word of text.split(/\s+/).filter(Boolean)) {
    let rest = word
    while (cellsOf(rest) > w) {
      if (cur) {
        lines.push(cur)
        cur = ''
      }
      lines.push([...rest].slice(0, w).join(''))
      rest = [...rest].slice(w).join('')
    }
    const next = cur ? `${cur} ${rest}` : rest
    if (cellsOf(next) <= w) cur = next
    else {
      lines.push(cur)
      cur = rest
    }
  }
  if (cur) lines.push(cur)
  if (lines.length <= maxLines) return lines
  const kept = lines.slice(0, maxLines)
  const last = kept[maxLines - 1] ?? ''
  kept[maxLines - 1] = cellsOf(last) >= w ? [...last].slice(0, w - 1).join('') + '…' : `${last}…`
  return kept
}
