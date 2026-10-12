// Pure helpers: unroll a robot's animation into a Clip, plain JSON that the
// `robot-clip.ts` surface module (a Client) plays on the drawing thread.
// The hooks module never redraws for a frame change; it only hands a new Clip
// when the robot's state or color changes (a redraw it does anyway).
//
// Copy beside robots.ts (hooks/anim.ts). No `$`, no atoms: unit-testable.

import { frameOf, robotOf } from './robots'
import type { State, Tint } from './robots'

/** What the Client plays. JsonValue-safe (Client props must be plain data). */
export type Clip = {
  /** Unique frames, each a list of lines. */
  frames: string[][]
  /** Per frame, one hex color per line (parallel to `frames`). */
  colors: string[][]
  /** Frame index for each base tick of one full period. */
  seq: number[]
  /** Base tick in ms (the drawing-thread clock of the Client). */
  ms: number
  /** Start offset into `seq`, so agents do not move in lockstep. */
  k0: number
}

/** Base tick: robots' `ticks: 2` frames last 400 ms, `ticks: 4` 800 ms. */
export const ROBOT_TICK_MS = 200

const gcd = (a: number, b: number): number => (b === 0 ? a : gcd(b, a % b))
const lcm = (a: number, b: number): number => (a / gcd(a, b)) * b

/** Ticks after which frameOf repeats: work blinks on (t+seed)%9 so lcm with 9. */
export function periodOf(type: string, state: State): number {
  const a = robotOf(type).anim[state]
  const cycle = a.ticks * a.frames.length
  return state === 'work' ? lcm(cycle, 9) : cycle
}

/**
 * Unroll `frameOf` over one period into deduped frames + a tick sequence.
 * `color(tint)` resolves a tint to hex (pass register.tsx's lineColor bound to
 * the agent's body color), so the Client needs no import of robots.ts.
 */
export function clipOf(
  type: string,
  state: State,
  seed: number,
  color: (tint: Tint) => string,
  ms = ROBOT_TICK_MS,
): Clip {
  const r = robotOf(type)
  const n = periodOf(type, state)
  const frames: string[][] = []
  const colors: string[][] = []
  const index = new Map<string, number>()
  const seq: number[] = []
  for (let t = 0; t < n; t++) {
    // seed 0 here; the offset is applied by the Client through k0.
    const f = frameOf(r, state, t, 0)
    const lines = [...f.lines]
    const cs = lines.map((_, i) => color(f.tints[i] ?? 'body'))
    const id = lines.join('\n') + '|' + cs.join(',')
    let at = index.get(id)
    if (at === undefined) {
      at = frames.length
      index.set(id, at)
      frames.push(lines)
      colors.push(cs)
    }
    seq.push(at)
  }
  return { frames, colors, seq, ms, k0: seed % n }
}

/** A one-line clip (the band's spinner): each glyph one tick. */
export function spinClip(glyphs: readonly string[], hex: string, ms = 100): Clip {
  return {
    frames: glyphs.map(g => [g]),
    colors: glyphs.map(() => [hex]),
    seq: glyphs.map((_, i) => i),
    ms,
    k0: 0,
  }
}

/** The frame a Clip shows at tick k (what the Client draws; also the static fallback). */
export function frameAt(c: Clip, k: number): { lines: string[]; colors: string[] } {
  const n = c.seq.length
  const i = n ? (c.seq[(((c.k0 + k) % n) + n) % n] ?? 0) : 0
  return { lines: c.frames[i] ?? [], colors: c.colors[i] ?? [] }
}
