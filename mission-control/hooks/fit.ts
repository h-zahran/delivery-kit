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

// East Asian Wide and Fullwidth: two terminal cells. Emoji drawn as emoji
// (Emoji_Presentation) are Wide too.
const WIDE: readonly (readonly [number, number])[] = [
  [0x1100, 0x115f], [0x2329, 0x232a], [0x2e80, 0x303e], [0x3041, 0x33ff], [0x3400, 0x4dbf],
  [0x4e00, 0x9fff], [0xa000, 0xa4cf], [0xa960, 0xa97f], [0xac00, 0xd7a3], [0xf900, 0xfaff],
  [0xfe10, 0xfe19], [0xfe30, 0xfe6f], [0xff00, 0xff60], [0xffe0, 0xffe6], [0x16fe0, 0x16fe4],
  [0x17000, 0x18cff], [0x1b000, 0x1b2ff], [0x1f200, 0x1f2ff], [0x20000, 0x2fffd], [0x30000, 0x3fffd],
]
const EMOJI = /\p{Emoji_Presentation}/u
// Zero cells: combining marks (variation selectors among them) and skin-tone modifiers.
const ZERO = /[\p{M}\p{Emoji_Modifier}]/u
const ZWJ = 0x200d

/** One code point's cells; `joined` when it follows a zero-width joiner (drawn inside the glyph before it). */
function cellOf(ch: string, joined: boolean): number {
  const cp = ch.codePointAt(0) ?? 0
  if (joined || cp === ZWJ || ZERO.test(ch)) return 0
  if (cp < 0x1100) return 1
  if (EMOJI.test(ch)) return 2
  return WIDE.some(([lo, hi]) => cp >= lo && cp <= hi) ? 2 : 1
}

/** Terminal cells a text takes: wide CJK and emoji 2, combining marks and joiners 0, the rest 1. */
export function cellsOf(s: string): number {
  let n = 0
  let joined = false
  for (const ch of s) {
    n += cellOf(ch, joined)
    joined = ch.codePointAt(0) === ZWJ
  }
  return n
}

/** The longest start of `s` that fits in `n` cells. */
export function cutCells(s: string, n: number): string {
  let used = 0
  let end = 0
  let joined = false
  for (const ch of s) {
    const w = cellOf(ch, joined)
    if (used + w > n) break
    used += w
    end += ch.length
    joined = ch.codePointAt(0) === ZWJ
  }
  return s.slice(0, end)
}

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
    out.push({ text: cutCells(p.text, room) + '…', tone: p.tone })
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
      // A wide character in a one-cell width still takes a line of its own.
      const head = cutCells(rest, w) || (Array.from(rest)[0] ?? rest)
      lines.push(head)
      rest = rest.slice(head.length)
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
  kept[maxLines - 1] = cellsOf(last) >= w ? cutCells(last, w - 1) + '…' : `${last}…`
  return kept
}
