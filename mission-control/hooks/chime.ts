// The "done" sound: the mod's own clip (sounds/done.wav, "happy robot").
// Mac: the engine's $.audio.play plays it (afplay). Windows and Linux have no
// engine player (d.ts 2672-2674), so it runs one through $.process.run:
// argv, no shell, as the session's user. Pure: register.tsx does the calls.

export type Platform = 'windows' | 'mac' | 'linux' | 'none'

export type SoundKind = 'done' | 'needsYou'

/** The clips, relative to the mod's folder: "happy robot" when work ends, "ding-dong" when the person is needed. */
export const SOUND_ASSETS: Record<SoundKind, string> = {
  done: 'sounds/done.wav',
  needsYou: 'sounds/needs-you.wav',
}

/** Claude Code's notifications that ask the person for something (a permission, a question). */
export const isNeedsYou = (notificationType: string | undefined): boolean =>
  /permission|elicitation/i.test(notificationType ?? '')

/** Where the session runs: `OS` is Windows_NT on Windows, else `uname -s` says. */
export function platformOf(osEnv: string | undefined, uname: string | undefined): Platform {
  if (osEnv === 'Windows_NT') return 'windows'
  const u = (uname ?? '').trim()
  if (u === 'Darwin') return 'mac'
  if (u === 'Linux') return 'linux'
  return 'none'
}

// No `-WindowStyle Hidden`: the child inherits the session's console, so no
// window opens; and Windows Terminal maps ShowWindow on its pseudo-console to
// its own window, so hiding "our" window could hide or minimize the terminal.
const PS = ['powershell.exe', '-NoProfile', '-NonInteractive', '-Command'] as const

/**
 * The commands that can play the clip at `path`, to try in order. Windows:
 * PlaySync, since Play() is cut off when the process exits. Linux: PulseAudio
 * or PipeWire, then plain ALSA. Mac and none: no command.
 */
export function playersFor(platform: Platform, path: string): string[][] {
  if (platform === 'windows')
    return [[...PS, `(New-Object System.Media.SoundPlayer '${path.replace(/'/g, "''")}').PlaySync()`]]
  if (platform === 'linux') return [['paplay', path], ['pw-play', path], ['aplay', '-q', path]]
  return []
}

/** A main turn worth a sound: it ran a minute or more. */
export const isLongTurn = (turnStartedAt: number, at: number, minMs = 60_000): boolean =>
  turnStartedAt > 0 && at - turnStartedAt >= minMs
