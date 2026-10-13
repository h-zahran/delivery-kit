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
// PowerShell by its full path: Windows looks for a bare `powershell.exe` in the
// current folder before PATH, so a repository could carry one that runs here.
const PS_ARGS = ['-NoProfile', '-NonInteractive', '-Command'] as const

/** Windows' own folder: `SystemRoot` when it reads as a plain drive path, else C:\Windows. */
export function windowsRoot(systemRoot: string | undefined): string {
  const r = (systemRoot ?? '').trim().replace(/\\+$/, '')
  return /^[A-Za-z]:\\[^"'<>|*?\r\n]+$/.test(r) ? r : 'C:\\Windows'
}

/** The full path of Windows PowerShell under `systemRoot`. */
export const powershellPath = (systemRoot: string | undefined): string =>
  `${windowsRoot(systemRoot)}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe`

/** One way to play a clip: the argv to run, and variables set for it. */
export type Player = { argv: string[]; env?: Record<string, string> }

/**
 * Windows' script: fixed text, the clip's path read from the environment, so
 * no character of a path (a quote, U+2019, a `$`) is ever PowerShell syntax.
 * PlaySync, since Play() is cut off when the process exits.
 */
export const PS_SCRIPT = '(New-Object System.Media.SoundPlayer $env:MC_SOUND).PlaySync()'

/**
 * The commands that can play the clip at `path`, to try in order. Windows:
 * PS_SCRIPT with `MC_SOUND` set to the path. Linux: PulseAudio or PipeWire,
 * then plain ALSA, by name: Linux searches only PATH, never the current
 * folder, and a full path would miss players outside /usr/bin. Mac and none:
 * no command.
 */
export function playersFor(platform: Platform, path: string, systemRoot?: string): Player[] {
  if (platform === 'windows')
    return [{ argv: [powershellPath(systemRoot), ...PS_ARGS, PS_SCRIPT], env: { MC_SOUND: path } }]
  if (platform === 'linux') return [{ argv: ['paplay', path] }, { argv: ['pw-play', path] }, { argv: ['aplay', '-q', path] }]
  return []
}

/** A main turn worth a sound: it ran a minute or more. */
export const isLongTurn = (turnStartedAt: number, at: number, minMs = 60_000): boolean =>
  turnStartedAt > 0 && at - turnStartedAt >= minMs
