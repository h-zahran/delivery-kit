// Surface module (Client) for mission-control: plays a Clip (anim.ts) on the
// drawing thread with its own frame clock. Copy to hooks/robot-clip.ts.
//
// Self-contained on purpose: only a type import (erased), no runtime import,
// no `h`/`Fragment`/JSX (d.ts 14757-14764), no `$` (d.ts 1554). Its local
// state survives the plugin's redraws while the Client key stays (d.ts 1510).

import type { ClientModule } from 'claude-code'

type Clip = { frames: string[][]; colors: string[][]; seq: number[]; ms: number; k0: number }
type S = { k: number }

const RobotClip: ClientModule<Clip, S> = (clip, surface) => {
  const { Box, Text } = surface.elements

  // Start the clock once, while state is still undefined (d.ts 1586-1591).
  // Each fire is a "tick" event, so a setState per fire is no render loop (d.ts 1571-1573).
  if (surface.state === undefined) {
    surface.setState({ k: 0 })
    if ((clip.seq?.length ?? 0) > 1) {
      surface.every(clip.ms > 0 ? clip.ms : 200, () => surface.setState({ k: (surface.state?.k ?? 0) + 1 }))
    }
  }

  // New props (state changed: work -> done) arrive here with k kept (d.ts 1524-1525);
  // indexing modulo the new length is enough, no reset needed.
  const n = clip.seq?.length ?? 0
  const k = (surface.state?.k ?? 0) + (clip.k0 ?? 0)
  const i = n ? (clip.seq[k % n] ?? 0) : 0
  const lines = clip.frames?.[i] ?? []
  const colors = clip.colors?.[i] ?? []

  // Never throw: a throw unmounts the instance until an invalidate (d.ts 1441, 4042-4043).
  if (lines.length === 0) return Text({ children: ' ' })
  return Box({
    flexDirection: 'column',
    children: lines.map((line, j) => Text({ color: colors[j], children: line })),
  })
}

export default RobotClip
