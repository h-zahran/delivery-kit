// Files tab: touched files as a compact folder tree (code map).
// Pure, no imports, no Node APIs. Erasable TS only (Node strips types).

export type Kind = 'read' | 'edit'

/** FileTouch-like input (owner/editors optional). */
export type TouchLike = {
  path: string
  kind: Kind
  at: number
  owner?: string
  editors?: readonly string[]
}

export type Line = {
  /** Tree guides: '', '├─ ', '│  └─ ' ... (1 column per char). */
  indent: string
  /** Already truncated (from the start) to fit. */
  name: string
  isDir: boolean
  /** Files: their kind. Dirs: 'edit' if any edit below, else 'read'. */
  kind?: Kind
  /** File edited by 2+ owners; dir: some file below clashes. */
  clash?: boolean
  /** Files only: who touched it last. */
  owner?: string
  /** Newest touch at or below this line: now, 5m, 2h, 3d. */
  age?: string
  /** Dirs / root / '… N more': touched files below. */
  count?: number
  /** Dir that only holds reads: render dimmed. */
  dim?: boolean
  /** Top line of a root group (common root, shortened). */
  root?: boolean
  /** Dir whose contents were folded into the next '… N more' line. */
  collapsed?: boolean
  /** A '… N more' summary line. */
  more?: boolean
  /** Full path of the file or dir (not on '… more' lines). */
  path?: string
}

/** `drives`: read Git Bash's `/e/x` as `E:\x` (Windows sessions only: on Linux it is a real path). */
export type PathOpts = { drives?: boolean }

/** `home`: the session user's real home folder, drawn as `~` wherever it shows. */
export type TreeOpts = PathOpts & { maxLines?: number; now?: number; home?: string }

/** Right columns a renderer draws after the name: ' ' + owner(L10) + ' ' + age(R4). */
export const OWNER_W = 10
export const AGE_W = 4
export const RIGHT_W = 1 + OWNER_W + 1 + AGE_W

const MIN = 60_000
const HOUR = 60 * MIN
const DAY = 24 * HOUR

/** Elapsed ms -> 'now' | '5m' | '2h' | '3d' | '2y' (always <= 4 chars). */
export function ageOf(ms: number): string {
  if (!Number.isFinite(ms) || ms < MIN) return 'now'
  if (ms < HOUR) return `${Math.floor(ms / MIN)}m`
  if (ms < DAY) return `${Math.floor(ms / HOUR)}h`
  const d = Math.floor(ms / DAY)
  return d < 1000 ? `${d}d` : `${Math.min(999, Math.floor(d / 365))}y`
}

/** Keep the tail of s so it fits n columns, marking the cut with '…'. */
export function fitStart(s: string, n: number): string {
  const cs = Array.from(s)
  if (cs.length <= n) return s
  if (n <= 0) return ''
  if (n === 1) return '…'
  return '…' + cs.slice(cs.length - (n - 1)).join('')
}

// ---------------------------------------------------------------- parsing

/** `base`: real segments folded out of `segs` (the home folder), drawn as `~`. */
type Parsed = { key: string; disp: string; sep: string; win: boolean; segs: string[]; base?: readonly string[] }

/** Segments, with `.` dropped and `..` taking the one before it (kept only at a relative start). */
function split(p: string, isRelative = false): string[] {
  const out: string[] = []
  for (const s of p.split('/')) {
    if (s === '' || s === '.') continue
    if (s !== '..') out.push(s)
    else if (out.length > 0 && out[out.length - 1] !== '..') out.pop()
    else if (isRelative) out.push(s)
  }
  return out
}

function parse(raw: string, opts: PathOpts = {}): Parsed {
  let p = raw.trim().replace(/\\/g, '/')
  p = p.replace(/^\/\/[?.]\/UNC\//i, '//') // \\?\UNC\server\share
  p = p.replace(/^\/\/[?.]\//, '') // \\?\C:\... long-path prefix
  if (opts.drives) p = p.replace(/^\/([A-Za-z])(?=\/|$)/, '$1:') // Git Bash /e/x
  let m = /^([A-Za-z]):(?:\/|$)/.exec(p)
  if (m) {
    const d = (m[1] ?? '').toUpperCase() + ':'
    return { key: d, disp: d, sep: '\\', win: true, segs: split(p.slice(2)) }
  }
  m = /^\/\/([^/]+)\/([^/]+)/.exec(p) // UNC \\server\share
  if (m) {
    const r = `\\\\${m[1] ?? ''}\\${m[2] ?? ''}`
    return { key: r.toLowerCase(), disp: r, sep: '\\', win: true, segs: split(p.slice(m[0].length)) }
  }
  if (p.startsWith('/')) return { key: '/', disp: '', sep: '/', win: false, segs: split(p) }
  return { key: '.', disp: '.', sep: '/', win: false, segs: split(p, true) }
}

function joinPath(g: { disp: string; sep: string; base?: readonly string[] }, segs: readonly string[]): string {
  const head = g.disp === '' ? '/' : g.disp === '.' ? '' : g.disp + g.sep
  const s = head + [...(g.base ?? []), ...segs].join(g.sep)
  return s === '' ? '.' : s
}

/** One spelling of a path: separators, the drive's case, `\\?\` prefixes, `.` and `..` settled. */
export function normPath(raw: string, opts: PathOpts = {}): string {
  const p = parse(raw, opts)
  return joinPath(p, p.segs)
}

/** What makes two paths one file: normPath, with case folded on Windows-style paths. */
export function pathKey(raw: string, opts: PathOpts = {}): string {
  const p = parse(raw, opts)
  return p.key + '|' + p.segs.map((s) => fold(s, p.win)).join('/')
}

/** A path below `home` as its own `~` root (another user's folder, or Public, is not), else `p`. */
function underHome(p: Parsed, home: Parsed | undefined): Parsed {
  if (!home || home.segs.length === 0 || p.key !== home.key || p.segs.length <= home.segs.length) return p
  const n = home.segs.length
  for (let i = 0; i < n; i++) if (fold(p.segs[i] ?? '', p.win) !== fold(home.segs[i] ?? '', p.win)) return p
  return { ...p, key: '~' + p.key, base: p.segs.slice(0, n), segs: p.segs.slice(n) }
}

// ---------------------------------------------------------------- tree

type FileN = { name: string; path: string; kind: Kind; at: number; owner: string; clash: boolean }

type DirN = {
  name: string
  path: string
  dirs: DirN[]
  files: FileN[]
  at: number
  count: number
  edits: number
  clash: boolean
  depth: number
  collapsed: boolean
}

type Group = {
  key: string
  disp: string
  sep: string
  win: boolean
  base?: readonly string[]
  items: { segs: string[]; f: FileN }[]
  root?: DirN
  /** The root's segments below the head: the files' common folder. */
  pre: string[]
  /** Max children of the root shown; the rest fold into '… N more'. */
  limit: number
}

function newDir(name: string, path: string, depth: number): DirN {
  return { name, path, dirs: [], files: [], at: -Infinity, count: 0, edits: 0, clash: false, depth, collapsed: false }
}

function fold(s: string, win: boolean): string {
  return win ? s.toLowerCase() : s
}

function buildGroups(files: readonly TouchLike[], opts: TreeOpts): Group[] {
  const home = opts.home ? parse(opts.home, opts) : undefined
  // 1. Dedupe by path (case-insensitive on Windows), merging touches.
  const merged = new Map<string, { p: Parsed; at: number; kind: Kind; owner: string; editors: Set<string> }>()
  for (const t of files) {
    if (!t || typeof t.path !== 'string' || t.path.trim() === '') continue
    const p = underHome(parse(t.path, opts), home)
    if (p.segs.length === 0) continue
    const k = p.key + '|' + p.segs.map((s) => fold(s, p.win)).join('/')
    const at = Number.isFinite(t.at) ? t.at : 0
    const prev = merged.get(k)
    const eds = t.editors ?? []
    if (!prev) {
      merged.set(k, { p, at, kind: t.kind, owner: t.owner ?? '', editors: new Set(eds) })
      continue
    }
    for (const e of eds) prev.editors.add(e)
    if (t.kind === 'edit') prev.kind = 'edit'
    if (at >= prev.at) {
      prev.at = at
      if (t.owner) prev.owner = t.owner
    }
  }

  // 2. Group by root (drive / UNC share / POSIX / relative).
  const groups = new Map<string, Group>()
  for (const m of merged.values()) {
    const { p } = m
    let g = groups.get(p.key)
    if (!g) {
      g = { key: p.key, disp: p.disp, sep: p.sep, win: p.win, items: [], limit: Infinity, pre: [] }
      if (p.base) g.base = p.base
      groups.set(p.key, g)
    }
    const name = p.segs[p.segs.length - 1] ?? ''
    g.items.push({
      segs: p.segs,
      f: { name, path: joinPath(p, p.segs), kind: m.kind, at: m.at, owner: m.owner, clash: m.editors.size >= 2 },
    })
  }

  // 3. Per group: common dir prefix, then the tree below it.
  for (const g of groups.values()) {
    const first = g.items[0]
    let pre = first ? first.segs.slice(0, -1) : []
    for (const it of g.items) {
      const dir = it.segs.slice(0, -1)
      let i = 0
      while (i < pre.length && i < dir.length && fold(pre[i] ?? '', g.win) === fold(dir[i] ?? '', g.win)) i++
      pre = pre.slice(0, i)
    }
    g.pre = pre
    const root = newDir('', joinPath(g, pre), 0)
    for (const it of g.items) {
      let node = root
      const rel = it.segs.slice(pre.length, -1)
      for (let i = 0; i < rel.length; i++) {
        const seg = rel[i] ?? ''
        let next = node.dirs.find((d) => fold(d.name, g.win) === fold(seg, g.win))
        if (!next) {
          next = newDir(seg, joinPath(g, it.segs.slice(0, pre.length + i + 1)), node.depth + 1)
          node.dirs.push(next)
        }
        node = next
      }
      node.files.push(it.f)
    }
    aggregate(root)
    for (const d of root.dirs) compress(d)
    sortTree(root)
    g.root = root
  }

  return [...groups.values()].sort((a, b) => (b.root?.at ?? 0) - (a.root?.at ?? 0) || a.key.localeCompare(b.key))
}

function aggregate(d: DirN): void {
  for (const c of d.dirs) {
    aggregate(c)
    d.at = Math.max(d.at, c.at)
    d.count += c.count
    d.edits += c.edits
    d.clash ||= c.clash
  }
  for (const f of d.files) {
    d.at = Math.max(d.at, f.at)
    d.count++
    if (f.kind === 'edit') d.edits++
    d.clash ||= f.clash
  }
}

/** Fold single-child folder chains: hooks -> sub becomes 'hooks/sub'. */
function compress(d: DirN): void {
  for (;;) {
    const only = d.dirs.length === 1 && d.files.length === 0 ? d.dirs[0] : undefined
    if (!only) break
    d.name = d.name + '/' + only.name
    d.path = only.path
    d.dirs = only.dirs
    d.files = only.files
  }
  for (const c of d.dirs) {
    c.depth = d.depth + 1
    compress(c)
  }
}

function sortTree(d: DirN): void {
  d.dirs.sort((a, b) => b.at - a.at || a.name.localeCompare(b.name))
  d.files.sort((a, b) => b.at - a.at || a.name.localeCompare(b.name))
  for (const c of d.dirs) sortTree(c)
}

// ---------------------------------------------------------------- render

type Ctx = { width: number; now: number }

const fitName = (ctx: Ctx, indent: string, s: string): string =>
  fitStart(s, Math.max(1, ctx.width - Array.from(indent).length - RIGHT_W))

const ageAt = (ctx: Ctx, at: number): string => ageOf(ctx.now - at)

function moreLine(ctx: Ctx, indent: string, n: number, at: number, edits: number, clash: boolean): Line {
  const l: Line = {
    indent,
    name: fitName(ctx, indent, `… ${n} more`),
    isDir: false,
    more: true,
    count: n,
    kind: edits > 0 ? 'edit' : 'read',
    age: ageAt(ctx, at),
  }
  if (edits === 0) l.dim = true
  if (clash) l.clash = true
  return l
}

function dirLine(ctx: Ctx, indent: string, d: DirN): Line {
  const l: Line = {
    indent,
    name: fitName(ctx, indent, d.name),
    isDir: true,
    kind: d.edits > 0 ? 'edit' : 'read',
    count: d.count,
    age: ageAt(ctx, d.at),
    path: d.path,
  }
  if (d.edits === 0) l.dim = true
  if (d.clash) l.clash = true
  if (d.collapsed) l.collapsed = true
  return l
}

function fileLine(ctx: Ctx, indent: string, f: FileN): Line {
  const l: Line = { indent, name: fitName(ctx, indent, f.name), isDir: false, kind: f.kind, age: ageAt(ctx, f.at), path: f.path }
  if (f.owner) l.owner = f.owner
  if (f.clash) l.clash = true
  return l
}

type Child = { dir: DirN; file?: undefined } | { file: FileN; dir?: undefined }

function children(d: DirN): Child[] {
  return [...d.dirs.map((dir): Child => ({ dir })), ...d.files.map((file): Child => ({ file }))]
}

function renderBody(ctx: Ctx, d: DirN, prefix: string, out: Line[], limit = Infinity): void {
  const kids = children(d)
  const shown = kids.slice(0, Math.max(0, limit))
  const hidden = kids.slice(shown.length)
  shown.forEach((k, i) => {
    const last = i === shown.length - 1 && hidden.length === 0
    const ind = prefix + (last ? '└─ ' : '├─ ')
    const sub = prefix + (last ? '   ' : '│  ')
    if (k.file) {
      out.push(fileLine(ctx, ind, k.file))
      return
    }
    const dir = k.dir
    out.push(dirLine(ctx, ind, dir))
    if (dir.collapsed) out.push(moreLine(ctx, sub + '└─ ', dir.count, dir.at, dir.edits, dir.clash))
    else renderBody(ctx, dir, sub, out)
  })
  if (hidden.length > 0) {
    let n = 0
    let at = -Infinity
    let edits = 0
    let clash = false
    for (const k of hidden) {
      if (k.file) {
        n++
        at = Math.max(at, k.file.at)
        if (k.file.kind === 'edit') edits++
        clash ||= k.file.clash
      } else {
        n += k.dir.count
        at = Math.max(at, k.dir.at)
        edits += k.dir.edits
        clash ||= k.dir.clash
      }
    }
    out.push(moreLine(ctx, prefix + '└─ ', n, at, edits, clash))
  }
}

function renderGroup(ctx: Ctx, g: Group, out: Line[]): void {
  const r = g.root
  if (!r) return
  const l = dirLine(ctx, '', r)
  l.root = true
  l.name = fitName(ctx, '', g.base ? ['~', ...g.pre].join(g.sep) : r.path)
  out.push(l)
  renderBody(ctx, r, '', out, g.limit)
}

function renderAll(ctx: Ctx, groups: readonly Group[]): Line[] {
  const out: Line[] = []
  for (const g of groups) renderGroup(ctx, g, out)
  return out
}

/** Lines one dir currently renders below its own line. */
function bodyLines(ctx: Ctx, d: DirN): number {
  if (d.collapsed) return 1
  const out: Line[] = []
  renderBody(ctx, d, '', out)
  return out.length
}

// ---------------------------------------------------------------- API

/**
 * Touched files as a folder tree, one Line per row.
 * Each root (drive, UNC share, POSIX '/') gets its own group: a root line
 * (common root, shortened) then the tree. Over maxLines, the oldest/deepest
 * folders fold into '… N more', then the oldest root entries do.
 */
export function treeLines(files: readonly TouchLike[], width: number, opts: TreeOpts = {}): Line[] {
  const ctx: Ctx = { width: Math.max(1, Math.floor(width)), now: opts.now ?? Date.now() }
  const max = opts.maxLines ?? Infinity
  if (max <= 0) return []
  const groups = buildGroups(files, opts)
  let lines = renderAll(ctx, groups)
  if (lines.length <= max) return lines

  // Pass 1: fold the oldest thing visible, deepest on ties, until it fits:
  // either a folder (its contents become '… N more') or the oldest entry
  // directly under a root (trailing entries become '… N more').
  for (;;) {
    let bestAt = Infinity
    let bestDepth = -1
    let act: (() => void) | undefined
    const consider = (at: number, depth: number, fn: () => void): void => {
      if (at < bestAt || (at === bestAt && depth > bestDepth)) {
        bestAt = at
        bestDepth = depth
        act = fn
      }
    }
    const walk = (d: DirN): void => {
      for (const c of d.dirs) {
        if (c.collapsed) continue
        if (bodyLines(ctx, c) >= 2) consider(c.at, c.depth, () => (c.collapsed = true))
        walk(c)
      }
    }
    for (const g of groups) {
      const r = g.root
      if (!r) continue
      const shown = children(r).slice(0, Math.max(0, g.limit))
      const last = shown[shown.length - 1]
      if (last) {
        // Folding the last shown entry must save a line now or enable it.
        const hidden = shown.length < children(r).length
        const body = last.dir ? bodyLines(ctx, last.dir) : 0
        if (hidden || body > 0 || shown.length >= 2) {
          consider(last.dir ? last.dir.at : last.file.at, 0, () => (g.limit = shown.length - 1))
        }
      }
      for (const k of shown) {
        if (!k.dir || k.dir.collapsed) continue
        if (bodyLines(ctx, k.dir) >= 2) {
          const d = k.dir
          consider(d.at, d.depth, () => (d.collapsed = true))
        }
        walk(k.dir)
      }
    }
    if (!act) break
    act()
    lines = renderAll(ctx, groups)
    if (lines.length <= max) return lines
  }

  // Pass 2: too many roots for the space: keep the newest, sum up the rest.
  const out: Line[] = []
  const rest = groups.slice()
  for (let g = rest[0]; g; g = rest[0]) {
    const gl: Line[] = []
    renderGroup(ctx, g, gl)
    if (out.length + gl.length + (rest.length > 1 ? 1 : 0) > max) break
    out.push(...gl)
    rest.shift()
  }
  if (rest.length > 0) {
    let n = 0
    let at = -Infinity
    let edits = 0
    let clash = false
    for (const g of rest) {
      const r = g.root
      if (!r) continue
      n += r.count
      at = Math.max(at, r.at)
      edits += r.edits
      clash ||= r.clash
    }
    out.length = Math.min(out.length, max - 1)
    out.push(moreLine(ctx, '', n, at, edits, clash))
  }
  return out
}
