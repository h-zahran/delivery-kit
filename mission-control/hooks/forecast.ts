// forecast.ts — pure usage-history helpers for the side pane.
// No imports, no Node APIs, no Date.now(): `now` is always passed in.

export type Sample = { at: number; costUsd: number; fiveHour?: number; sevenDay?: number };

const MIN = 60_000;
const HOUR = 60 * MIN;

/** "Meaningful" change thresholds for pushSample (bypass the min gap). */
export const COST_EPS = 0.05; // $ change
export const PCT_EPS = 1; // percentage-point change in fiveHour / sevenDay

/** What runOut needs before it projects: this much time, and this many points of rise. */
export const MIN_SPAN_MS = 5 * MIN;
export const MIN_RISE = 2;

function pctChanged(a: number | undefined, b: number | undefined): boolean {
  if (a === undefined || b === undefined) return a !== b;
  return Math.abs(a - b) >= PCT_EPS;
}

/**
 * Append `s` if ≥ minGapMs (default 30 s) since the last sample, or if a value
 * changed meaningfully (cost ±$0.05, either percent ±1 pt, or a percent
 * appearing/disappearing). Samples older than the last one are ignored.
 * Returns a new array when appending, otherwise the same `hist` reference.
 * Kept by age: samples more than `maxAgeMs` (default 30 min, the sparkline's
 * window) before `s` go, all but the newest of them, which anchors the
 * window's first delta. `keep` (default 720) is a hard cap on top.
 */
export function pushSample(
  hist: Sample[],
  s: Sample,
  opts?: { minGapMs?: number; keep?: number; maxAgeMs?: number },
): Sample[] {
  const minGapMs = opts?.minGapMs ?? 30_000;
  const keep = Math.max(1, opts?.keep ?? 720);
  const maxAgeMs = opts?.maxAgeMs ?? 30 * MIN;
  const last = hist[hist.length - 1];
  if (last) {
    if (s.at < last.at) return hist;
    const gapOk = s.at - last.at >= minGapMs;
    const changed =
      Math.abs(s.costUsd - last.costUsd) >= COST_EPS ||
      pctChanged(last.fiveHour, s.fiveHour) ||
      pctChanged(last.sevenDay, s.sevenDay);
    if (!gapOk && !changed) return hist;
  }
  const next = hist.concat([s]);
  const fresh = next.findIndex((x) => x.at >= s.at - maxAgeMs);
  const from = Math.max(0, fresh - 1, next.length - keep);
  return from > 0 ? next.slice(from) : next;
}

const LEVELS = ['▁', '▂', '▃', '▄', '▅', '▆', '▇'] as const;

/**
 * Spend sparkline: exactly `width` chars. Buckets cover the window ending at
 * `now` (default bucket = 30 min / width). Spend = positive cost deltas between
 * consecutive samples, credited to the later sample's bucket.
 * ' ' = bucket entirely before the first sample, '▁' = no spend,
 * '▂'..'▇' = spend scaled to the max bucket.
 */
export function costSpark(hist: Sample[], width: number, now: number, bucketMs?: number): string {
  const w = Math.max(0, Math.floor(width));
  if (w === 0) return '';
  const bms = bucketMs && bucketMs > 0 ? bucketMs : (30 * MIN) / w;
  const origin = now - w * bms;
  const spend: number[] = new Array<number>(w).fill(0);
  for (let i = 1; i < hist.length; i++) {
    const a = hist[i - 1];
    const b = hist[i];
    if (!a || !b) continue;
    const d = b.costUsd - a.costUsd;
    if (!(d > 0) || b.at < origin || b.at > now) continue;
    const idx = Math.min(w - 1, Math.floor((b.at - origin) / bms));
    spend[idx] = (spend[idx] ?? 0) + d;
  }
  const max = Math.max(0, ...spend);
  const first = hist[0];
  let out = '';
  for (let i = 0; i < w; i++) {
    const end = origin + (i + 1) * bms;
    if (!first || end <= first.at) {
      out += ' ';
      continue;
    }
    const v = spend[i] ?? 0;
    if (v <= 0 || max <= 0) {
      out += LEVELS[0];
      continue;
    }
    const lvl = Math.min(6, Math.max(1, Math.ceil((v / max) * 6)));
    out += LEVELS[lvl] ?? LEVELS[6];
  }
  return out;
}

/**
 * $/h over the last `windowMs` (default 15 min): positive cost deltas between
 * in-window samples, divided by (now − first in-window sample). 0 if fewer than
 * 2 samples in window or under 1 min of span.
 */
export function burnPerHour(hist: Sample[], now: number, windowMs: number = 15 * MIN): number {
  const from = now - windowMs;
  const win = hist.filter((s) => s.at >= from && s.at <= now);
  const first = win[0];
  if (!first || win.length < 2) return 0;
  let spent = 0;
  for (let i = 1; i < win.length; i++) {
    const a = win[i - 1];
    const b = win[i];
    if (!a || !b) continue;
    const d = b.costUsd - a.costUsd;
    if (d > 0) spent += d;
  }
  const span = now - first.at;
  if (span < MIN) return 0;
  return (spent / span) * HOUR;
}

/**
 * Linear (least-squares) projection of percent-used over the last 20 min to
 * 100 %. Only samples after the latest drop (window reset) are used.
 * undefined if < 3 samples, under MIN_SPAN_MS of span, a rise under MIN_RISE
 * points (percents are whole numbers: one tick in 30 s is noise), or slope ≤ 0.
 * etaMs is measured from `now` (≥ 0). beforeReset: eta lands before
 * `resetIso`; true when resetIso is absent/unparseable (no reset known).
 */
export function runOut(
  hist: Sample[],
  now: number,
  kind: 'fiveHour' | 'sevenDay',
  resetIso?: string,
): { etaMs: number; beforeReset: boolean } | undefined {
  const from = now - 20 * MIN;
  let pts: { t: number; v: number }[] = [];
  for (const s of hist) {
    const v = s[kind];
    if (v === undefined || !Number.isFinite(v) || s.at < from || s.at > now) continue;
    const prev = pts[pts.length - 1];
    if (prev && v < prev.v - 0.5) pts = []; // window reset: start over
    pts.push({ t: s.at, v });
  }
  const last = pts[pts.length - 1];
  const first = pts[0];
  if (!last || !first || pts.length < 3) return undefined;
  if (last.t - first.t < MIN_SPAN_MS || last.v - first.v < MIN_RISE) return undefined;
  const n = pts.length;
  let st = 0, sv = 0;
  for (const p of pts) { st += p.t; sv += p.v; }
  const mt = st / n, mv = sv / n;
  let num = 0, den = 0;
  for (const p of pts) {
    num += (p.t - mt) * (p.v - mv);
    den += (p.t - mt) * (p.t - mt);
  }
  if (den === 0) return undefined;
  const slope = num / den; // pct per ms
  if (!(slope > 0)) return undefined;
  const remaining = Math.max(0, 100 - last.v);
  const etaMs = Math.max(0, remaining / slope - (now - last.t));
  const resetAt = resetIso ? Date.parse(resetIso) : NaN;
  const beforeReset = Number.isNaN(resetAt) ? true : now + etaMs < resetAt;
  return { etaMs, beforeReset };
}

/** 42m, 1h40, 1h05, 2h, 2d3h, 2d; '<1m' under a minute, '0m' for ≤ 0, '∞' if not finite. */
export function fmtEta(ms: number): string {
  if (!Number.isFinite(ms)) return '∞';
  if (ms <= 0) return '0m';
  const totalMin = Math.round(ms / MIN);
  if (totalMin < 1) return '<1m';
  if (totalMin < 60) return `${totalMin}m`;
  if (totalMin < 24 * 60) {
    const h = Math.floor(totalMin / 60);
    const m = totalMin % 60;
    return m === 0 ? `${h}h` : `${h}h${String(m).padStart(2, '0')}`;
  }
  const totalH = Math.round(ms / HOUR);
  const d = Math.floor(totalH / 24);
  const h = totalH % 24;
  return h === 0 ? `${d}d` : `${d}d${h}h`;
}
