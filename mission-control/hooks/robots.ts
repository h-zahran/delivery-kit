// Cute rounded robots, v2, for the agent side pane.
// Every sprite: 3 lines x exactly 7 columns.
//   col 0 and col 6 are "slots" for arms, sparkles, z's, ?, bubbles;
//   cols 1-5 are the 5-wide body (hat / face / feet).
// Arms attach to the face line with ┤ ├ sides:  ╭┤ ├╮ arms down, ╰┤ ├╯ arms up.
//
// Personality per agent type (hat, eyes, how it works):
//   main             ╭^^^╮ gold crown, ◕‿◕  types: arms alternate, crown twinkles
//   Explore          ╭─°─╮ antenna bulb, ◉‿◉  scurries left/right, looks around, bulb pings
//   Plan             ╭═══╮ flat cap, ⊙_⊙ glasses  ponders, eureka (*), writes notes (⠤⠶)
//   general-purpose  ╭─┴─╮ antenna, ●‿●  hammers: arm swings up/level/down, spark on hit
//   fork             ╭┴─┴╮ twin antennas, ○‿○  dances: arms + feet alternate, lights blink
//   other            ╭───╮ plain, °‿°  gentle sway (like v1)
// States (all readable without color):
//   work    4-frame cycle above             blink   eyes become -
//   think   hand on chin, ~ mouth, bubble rising · ° ○
//   wait    hand raised, o mouth, ? blinking (waiting for permission)
//   done    both arms up, ^‿^, sparkles * · swap sides
//   failed  x_x, limp arms, slumped feet, antenna retracted, smoke ~ drifting
//   idle    sitting (no legs), ˘_˘, z / z / Z rising
// Moods (v0.7, picked by roles.ts lookOf over the state):
//   tired   context almost full: sleepy ˘_˘ eyes, yawns, a z
//   nervous waits long for permission: wobbly ~ mouth, a sweat drop falls
//   ouch    a tool call just failed: >_< and a little star
//
// v1 compatibility: work/blink/done/failed/idle keep the v1 names; `work` now
// has 4 frames (v1 renderer used work[0], work[1] — still a sensible pair).
// New: think, wait, and `anim` (frames + per-line tint hints + ticks/frame).

export type Sprite = string[];

// Per-line color hints (one color per line). Suggested mapping:
//   body   = the agent's color          accent = robot.accent (type-specific)
//   dim    = body mixed ~50% toward bg  ok/warn/bad = done/gold/fail colors
export type Tint = 'body' | 'accent' | 'dim' | 'ok' | 'warn' | 'bad';
export type LineTints = [Tint, Tint, Tint];
export type State = 'work' | 'think' | 'wait' | 'done' | 'failed' | 'idle' | Mood;
export type Mood = 'tired' | 'nervous' | 'ouch';

export interface Anim {
  frames: Sprite[];
  tints: LineTints[]; // parallel to frames
  ticks: number; // pane ticks per frame
}

export interface Robot {
  // v1 shape
  work: Sprite[];
  blink: Sprite;
  done: Sprite;
  failed: Sprite;
  idle: Sprite;
  // v2 additions
  think: Sprite[];
  wait: Sprite[];
  accent: string;
  restFrame: number; // the "standing still" work frame (blink is built from it)
  anim: Record<State, Anim>;
}

const t3 = (a: Tint = 'body', b: Tint = 'body', c: Tint = 'body'): LineTints => [a, b, c];

const FEET = ' ╰┬─┬╯ ';
const SLUMP = ' ╰┴─┴╯ ';
const SIT = ' ╰───╯ ';

interface Spec {
  hat: string; // 5 cols
  hatOff: string; // failed: antenna retracted / light out
  eye: string;
  accent: string;
  topAccent: boolean; // line 1 always accent (main's gold crown)
  restFrame: number;
  work: Sprite[];
  workTints: LineTints[];
}

function bot(s: Spec): Robot {
  const { hat, eye: e } = s;
  const top: Tint = s.topAccent ? 'accent' : 'body';

  const rest = s.work[s.restFrame] as Sprite;
  const blink: Sprite = [rest[0]!, rest[1]!.split(e).join('-'), rest[2]!];

  const think: Sprite[] = [
    [` ${hat} `, `╰┤${e}~${e}│·`, FEET],
    [` ${hat}°`, `╰┤${e}~${e}│ `, FEET],
    [` ${hat}○`, `╰┤${e}~${e}│ `, FEET],
  ];
  const wait: Sprite[] = [
    [` ${hat}?`, ` │${e}o${e}├╯`, FEET],
    [` ${hat} `, ` │${e}o${e}├╯`, FEET],
  ];
  const done: Sprite[] = [
    [`*${hat}·`, '╰┤^‿^├╯', FEET],
    [`·${hat}*`, '╰┤^‿^├╯', FEET],
  ];
  const failed: Sprite[] = [
    [` ${s.hatOff}~`, '╭┤x_x├╮', SLUMP],
    [`~${s.hatOff} `, '╭┤x_x├╮', SLUMP],
  ];
  const idle: Sprite[] = [
    [` ${hat} `, ' │˘_˘│z', SIT],
    [` ${hat}z`, ' │˘_˘│ ', SIT],
    [` ${hat}Z`, ' │˘_˘│ ', SIT],
  ];
  const tired: Sprite[] = [
    [` ${hat} `, '╭┤˘_˘├╮', FEET],
    [` ${hat}z`, '╭┤˘_˘├╮', FEET],
    [` ${hat} `, '╭┤˘O˘├╮', FEET],
    [` ${hat} `, '╭┤˘_˘├╮', FEET],
  ];
  const nervous: Sprite[] = [
    [`'${hat}?`, ` │${e}~${e}├╯`, FEET],
    [` ${hat} `, `,│${e}~${e}├╯`, FEET],
    [` ${hat}?`, ` │${e}~${e}├╯`, FEET],
  ];
  const ouch: Sprite[] = [
    [`*${hat} `, '╭┤>_<├╮', FEET],
    [` ${hat}!`, '╭┤>_<├╮', FEET],
  ];

  return {
    work: s.work,
    blink,
    done: done[0]!,
    failed: failed[0]!,
    idle: idle[0]!,
    think,
    wait,
    accent: s.accent,
    restFrame: s.restFrame,
    anim: {
      work: { frames: s.work, tints: s.workTints, ticks: 2 },
      think: { frames: think, tints: think.map(() => t3(top)), ticks: 3 },
      wait: { frames: wait, tints: [t3('warn'), t3(top)], ticks: 2 },
      done: { frames: done, tints: done.map(() => t3('ok')), ticks: 3 },
      failed: { frames: failed, tints: failed.map(() => t3('bad')), ticks: 4 },
      idle: { frames: idle, tints: idle.map(() => t3('dim', 'dim', 'dim')), ticks: 4 },
      tired: { frames: tired, tints: tired.map(() => t3(top, 'dim', 'dim')), ticks: 4 },
      nervous: { frames: nervous, tints: [t3('warn'), t3(top), t3('warn')], ticks: 2 },
      ouch: { frames: ouch, tints: ouch.map(() => t3(top, 'bad', 'body')), ticks: 2 },
    },
  };
}

const all = (n: number, x: LineTints): LineTints[] => Array.from({ length: n }, () => x);

export const ROBOTS: Record<string, Robot> = {
  // The boss: gold crown, typing away; the crown glints.
  main: bot({
    hat: '╭^^^╮', hatOff: '╭─^─╮', eye: '◕', accent: '#ffd166', topAccent: true, restFrame: 0,
    work: [
      [' ╭^^^╮ ', '╭┤◕‿◕├╯', FEET],
      [' ╭^^^╮ ', '╰┤◕‿◕├╮', FEET],
      [' ╭^^^╮*', '╭┤◕‿◕├╯', FEET],
      [' ╭^^^╮·', '╰┤◕‿◕├╮', FEET],
    ],
    workTints: all(4, t3('accent')),
  }),

  // The scout: scurries side to side, eyes darting, antenna pings.
  Explore: bot({
    hat: '╭─°─╮', hatOff: '╭─·─╮', eye: '◉', accent: '#7ee0c3', topAccent: false, restFrame: 1,
    work: [
      ['╭─·─╮  ', '│◉◉ │  ', '╰┬─┴╯  '],
      [' ╭─°─╮ ', ' │◉‿◉│ ', ' ╰┴─┬╯ '],
      ['  ╭─·─╮', '  │ ◉◉│', '  ╰┬─┴╯'],
      [' ╭─◉─╮ ', ' │◉‿◉│ ', ' ╰┴─┬╯ '],
    ],
    workTints: [t3(), t3(), t3(), t3('accent')],
  }),

  // The thinker: glasses, ponders, has an idea, jots notes.
  Plan: bot({
    hat: '╭═══╮', hatOff: '╭═─═╮', eye: '⊙', accent: '#ffd166', topAccent: false, restFrame: 0,
    work: [
      [' ╭═══╮ ', '╰┤⊙_⊙│ ', FEET],
      [' ╭═══╮*', ' │⊙‿⊙├╯', FEET],
      [' ╭═══╮ ', ' │⊙_⊙├╮', ' ╰┬─┬╯⠤'],
      [' ╭═══╮ ', ' │⊙_⊙├╮', ' ╰┬─┬╯⠶'],
    ],
    workTints: [t3(), t3('accent'), t3(), t3()],
  }),

  // The handyman: hammer swing up, level, down (spark!), level.
  'general-purpose': bot({
    hat: '╭─┴─╮', hatOff: '╭─┬─╮', eye: '●', accent: '#ff9f43', topAccent: false, restFrame: 1,
    work: [
      [' ╭─┴─╮ ', '╭┤●‿●├╯', FEET],
      [' ╭─┴─╮ ', '╭┤●‿●├─', FEET],
      [' ╭─┴─╮ ', '╭┤●_●├╮', ' ╰┬─┬╯*'],
      [' ╭─┴─╮ ', '╭┤●‿●├─', FEET],
    ],
    workTints: [t3(), t3(), t3('body', 'body', 'accent'), t3()],
  }),

  // The twin: dances, arms and feet alternate, twin lights blink.
  fork: bot({
    hat: '╭┴─┴╮', hatOff: '╭┬─┬╮', eye: '○', accent: '#c3a6ff', topAccent: false, restFrame: 1,
    work: [
      [' ╭┴─┴╮ ', '╰┤○‿○├╯', ' ╰┬─┴╯ '],
      [' ╭┴─┴╮ ', '╭┤○‿○├╮', ' ╰┴─┬╯ '],
      [' ╭┴─┴╮ ', '╰┤○‿○├╮', ' ╰┬─┴╯ '],
      [' ╭┴─┴╮ ', '╭┤○‿○├╯', ' ╰┴─┬╯ '],
    ],
    workTints: [t3('accent'), t3(), t3('accent'), t3()],
  }),

  // --- robots for helper roles (roles.ts); scout and planner reuse Explore and Plan ---

  // The builder: yellow hard hat, hammer swings, spark on the hit.
  builder: bot({
    hat: '╭▄▄▄╮', hatOff: '╭▄─▄╮', eye: '●', accent: '#ffd166', topAccent: true, restFrame: 1,
    work: [
      [' ╭▄▄▄╮ ', '╭┤●‿●├╯', FEET],
      [' ╭▄▄▄╮ ', '╭┤●‿●├─', FEET],
      [' ╭▄▄▄╮ ', '╭┤●_●├╮', ' ╰┬─┬╯*'],
      [' ╭▄▄▄╮ ', '╭┤●‿●├─', FEET],
    ],
    workTints: [t3('accent'), t3('accent'), t3('accent', 'body', 'accent'), t3('accent')],
  }),

  // The fixer: medic cross, turns a wrench, sparks fly.
  fixer: bot({
    hat: '╭─┼─╮', hatOff: '╭───╮', eye: '•', accent: '#ffd166', topAccent: false, restFrame: 2,
    work: [
      [' ╭─┼─╮ ', '╭┤•_•├┐', FEET],
      [' ╭─┼─╮ ', '╭┤•_•├┘', FEET],
      ['·╭─┼─╮ ', '╭┤•‿•├┐', FEET],
      [' ╭─┼─╮ ', '╭┤•‿•├┘', ' ╰┬─┬╯~'],
    ],
    workTints: [t3(), t3(), t3('accent', 'body', 'body'), t3('body', 'body', 'accent')],
  }),

  // The inspector: detective hat, magnifier, looks left and right, ticks it off.
  inspector: bot({
    hat: '▁╭─╮▁', hatOff: '▁╭─╮▁', eye: '◎', accent: '#5fd38d', topAccent: false, restFrame: 0,
    work: [
      [' ▁╭─╮▁ ', ' │◎‿◎├○', FEET],
      [' ▁╭─╮▁ ', ' │◎◎ ├○', FEET],
      [' ▁╭─╮▁ ', ' │ ◎◎├○', FEET],
      [' ▁╭─╮▁✓', ' │◎‿◎├○', FEET],
    ],
    workTints: [t3(), t3(), t3(), t3('accent', 'body', 'body')],
  }),

  // The researcher: reads a book, turns the page, gets an idea.
  researcher: bot({
    hat: '╭─◇─╮', hatOff: '╭─·─╮', eye: '◔', accent: '#ffd166', topAccent: false, restFrame: 0,
    work: [
      [' ╭─◇─╮ ', ' │◔_◔├▤', FEET],
      [' ╭─◇─╮ ', ' │◔_◔├▥', FEET],
      [' ╭─◇─╮°', ' │◔‿◔├▤', FEET],
      [' ╭─◆─╮ ', ' │◔‿◔├▤', FEET],
    ],
    workTints: [t3(), t3(), t3('accent', 'body', 'body'), t3('accent', 'body', 'body')],
  }),

  // The writer: beret, pencil scribbles, lines of text appear.
  writer: bot({
    hat: '╭─▾─╮', hatOff: '╭───╮', eye: '·', accent: '#ffd166', topAccent: false, restFrame: 0,
    work: [
      [' ╭─▾─╮ ', ' │·‿·├/', FEET],
      [' ╭─▾─╮ ', ' │·_·├/', ' ╰┬─┬╯⠤'],
      [' ╭─▾─╮ ', ' │·_·├/', ' ╰┬─┬╯⠶'],
      [' ╭─▾─╮ ', ' │·‿·├\\', FEET],
    ],
    workTints: [t3(), t3('body', 'body', 'accent'), t3('body', 'body', 'accent'), t3()],
  }),

  // Anyone else: the classic gentle sway.
  other: bot({
    hat: '╭───╮', hatOff: '╭───╮', eye: '°', accent: '#8ab4ff', topAccent: false, restFrame: 1,
    work: [
      ['╭───╮  ', '│°‿°│  ', '╰┬─┬╯  '],
      [' ╭───╮ ', ' │°‿°│ ', FEET],
      ['  ╭───╮', '  │°‿°│', '  ╰┬─┬╯'],
      [' ╭───╮ ', ' │°‿°│ ', FEET],
    ],
    workTints: all(4, t3()),
  }),
};

// --- helpers a renderer can use (optional) ---

export const robotOf = (type: string): Robot =>
  ROBOTS[type] ?? ROBOTS[type.replace(/^[^:]*:/, '')] ?? (ROBOTS.other as Robot);

/** Pick the frame for a state at pane tick `t`; `seed` desyncs agents. */
export function frameOf(
  r: Robot, state: State, t: number, seed = 0,
): { lines: Sprite; tints: LineTints } {
  const a = r.anim[state];
  if (state === 'work' && (t + seed) % 9 === 0) {
    return { lines: r.blink, tints: a.tints[r.restFrame] ?? t3() };
  }
  const i = Math.floor((t + seed) / a.ticks) % a.frames.length;
  return { lines: a.frames[i] as Sprite, tints: a.tints[i] ?? t3() };
}

const mix = (a: string, b: string, k: number): string => {
  const p = (h: string, i: number) => parseInt(h.slice(1 + i * 2, 3 + i * 2), 16);
  const c = [0, 1, 2].map(i => Math.round(p(a, i) * (1 - k) + p(b, i) * k));
  return '#' + c.map(v => v.toString(16).padStart(2, '0')).join('');
};

/** Resolve a tint hint to a hex color. */
export function tintHex(
  tint: Tint, body: string, accent: string,
  pal = { ok: '#7bd88f', warn: '#f5c542', bad: '#ff6b6b', bg: '#1e1e2e' },
): string {
  switch (tint) {
    case 'accent': return accent;
    case 'dim': return mix(body, pal.bg, 0.5);
    case 'ok': return pal.ok;
    case 'warn': return pal.warn;
    case 'bad': return pal.bad;
    default: return body;
  }
}
