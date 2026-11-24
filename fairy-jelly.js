// jellyFlight: Fairy between two places over the page, pulling its tentacles in on the way to a ball
// ("in") or letting them out on the way to the full fairy ("out"). Approved in the artifact "Fairy Morphs".
// The body and eyes are the Open Bot renderer's, untouched (the eyes never change size); the tentacles are
// FAIRY.bend's outline read as tubes (a spine and a width) and drawn every frame as they slide back along
// their own path. Every number of the motion is FAIRY_MOTION.bend's (jelly_*); this file reads the page,
// steps the springs and draws.
import F from "./FAIRY.bend";
import B from "./FAIRY_MOTION.bend";
import T from "./TOKENS.bend";
import { fairy } from "./fairy.js";
import { createAnimator } from "./fairy-renderer/animator.ts";
import { liveFrame, preparedVolume } from "./fairy-renderer/render.ts";
import { mountCanvas, paintCanvas } from "./fairy-renderer/dom/paint.ts";
import { parsePath, splitSubpaths } from "./fairy-renderer/path.ts";
import { subscribeFrames } from "./fairy-renderer/dom/clock.ts";

const lessMotion = matchMedia("(prefers-reduced-motion: reduce)");
const CENTER = [50, F.center_y()], CORE_R = F.radius(), EYES = [50, F.eye_y()];
const clamp01 = (v) => Math.max(0, Math.min(1, v));
const smooth = (v) => v * v * (3 - 2 * v);
const mul = (r, m) => [r[0] * m[0] + r[2] * m[1], r[1] * m[0] + r[3] * m[1], r[0] * m[2] + r[2] * m[3], r[1] * m[2] + r[3] * m[3], r[0] * m[4] + r[2] * m[5] + r[4], r[1] * m[4] + r[3] * m[5] + r[5]];
const apply = (m, p) => [m[0] * p[0] + m[2] * p[1] + m[4], m[1] * p[0] + m[3] * p[1] + m[5]];

// ---------- The tentacles, read once from FAIRY.bend's outline ----------
let kit = null;
function tentacleKit() {
  if (kit) return kit;
  const subs = splitSubpaths(parsePath(fairy.body.path));
  const serialize = (segs) => segs.map((s) => s.c === "M" ? `M${s.x} ${s.y}` : s.c === "C" ? `C${s.x1} ${s.y1} ${s.x2} ${s.y2} ${s.x} ${s.y}` : s.c === "A" ? `A${s.rx} ${s.ry} ${s.rot} ${s.large} ${s.sweep} ${s.x} ${s.y}` : s.c === "L" ? `L${s.x} ${s.y}` : "Z").join("");
  const bez = (p0, s, t) => { const u = 1 - t; return [u * u * u * p0[0] + 3 * u * u * t * s.x1 + 3 * u * t * t * s.x2 + t * t * t * s.x, u * u * u * p0[1] + 3 * u * u * t * s.y1 + 3 * u * t * t * s.y2 + t * t * t * s.y]; };
  const flatten = (start, cs) => { const pts = [start]; let p = start; for (const s of cs) { for (let i = 1; i <= 24; i++) pts.push(bez(p, s, i / 24)); p = [s.x, s.y]; } return pts; };
  const lengthOf = (pts) => pts.reduce((sum, q, i) => i ? sum + Math.hypot(q[0] - pts[i - 1][0], q[1] - pts[i - 1][1]) : 0, 0);
  const resample = (pts, n) => {
    const d = [0];
    for (let i = 1; i < pts.length; i++) d.push(d[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]));
    const out = [], L = d[d.length - 1]; let j = 0;
    for (let k = 0; k < n; k++) { const want = (L * k) / (n - 1); while (j < d.length - 2 && d[j + 1] < want) j++; const t = (want - d[j]) / ((d[j + 1] - d[j]) || 1); out.push([pts[j][0] + (pts[j + 1][0] - pts[j][0]) * t, pts[j][1] + (pts[j + 1][1] - pts[j][1]) * t]); }
    return out;
  };
  const N = 90;
  const tentacles = subs.slice(1).map((segs) => {
    const [a1, a2] = segs.map((s, i) => s.c === "A" ? i : -1).filter((i) => i >= 0);
    const side1 = flatten([segs[a1].x, segs[a1].y], segs.slice(a1 + 1, a2).filter((s) => s.c === "C"));
    const side2 = flatten([segs[a2].x, segs[a2].y], segs.slice(a2 + 1).filter((s) => s.c === "C")).reverse();
    // The spine: each point of the long side meets the nearest point of the other, near its own place
    // along it (so a curl's tip never meets its own stem); then evenly spaced.
    const [outer, inner] = lengthOf(side1) >= lengthOf(side2) ? [side1, side2] : [side2, side1];
    const A = resample(outer, N), Bs = resample(inner, N * 6);
    const rough = [], roughHalf = [];
    A.forEach((p, i) => {
      const mid = (i / (N - 1)) * (Bs.length - 1), from = Math.max(0, Math.floor(mid - Bs.length * 0.22)), to = Math.min(Bs.length - 1, Math.ceil(mid + Bs.length * 0.22));
      let best = Infinity, q = Bs[from];
      for (let j = from; j <= to; j++) { const b = Bs[j], d = (b[0] - p[0]) ** 2 + (b[1] - p[1]) ** 2; if (d < best) { best = d; q = b; } }
      rough.push([(p[0] + q[0]) / 2, (p[1] + q[1]) / 2]); roughHalf.push(Math.sqrt(best) / 2);
    });
    rough[0] = [(side1[0][0] + side2[0][0]) / 2, (side1[0][1] + side2[0][1]) / 2]; roughHalf[0] = segs[a1].rx;
    const tipA = side1[side1.length - 1], tipB = side2[side2.length - 1];
    rough[N - 1] = [(tipA[0] + tipB[0]) / 2, (tipA[1] + tipB[1]) / 2]; roughHalf[N - 1] = segs[a2].rx;
    const spine = resample(rough, N);
    const rd = [0]; for (let i = 1; i < N; i++) rd.push(rd[i - 1] + Math.hypot(rough[i][0] - rough[i - 1][0], rough[i][1] - rough[i - 1][1]));
    const half = spine.map((_, k) => { const want = (rd[N - 1] * k) / (N - 1); let j = 0; while (j < N - 2 && rd[j + 1] < want) j++; const f = (want - rd[j]) / ((rd[j + 1] - rd[j]) || 1); return roughHalf[j] + (roughHalf[j + 1] - roughHalf[j]) * f; });
    const s = [0]; for (let i = 1; i < N; i++) s.push(s[i - 1] + Math.hypot(spine[i][0] - spine[i - 1][0], spine[i][1] - spine[i - 1][1]));
    const inX = CENTER[0] - spine[0][0], inY = CENTER[1] - spine[0][1], inL = Math.hypot(inX, inY) || 1;
    return { spine, half, s, L: s[N - 1], inward: [inX / inL, inY / inL] };
  });
  const byLength = [...tentacles].sort((a, b) => b.L - a.L);
  tentacles.forEach((t) => t.rank = byLength.indexOf(t) / (tentacles.length - 1));
  const b = preparedVolume(fairy).vol.bounds;
  kit = { N, tentacles, body: { ...fairy, body: { path: serialize(subs[0]) } }, pivot: [(b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2] };
  return kit;
}
function search(t, x) { let lo = 0, hi = t.s.length - 1; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (t.s[m] <= x) lo = m; else hi = m; } return [lo, hi, (x - t.s[lo]) / ((t.s[hi] - t.s[lo]) || 1)]; }
// A point at arc length u on a tentacle's track: its spine for u >= 0, straight into the body before it.
function along(t, u) {
  if (u <= 0) return [t.spine[0][0] + t.inward[0] * -u, t.spine[0][1] + t.inward[1] * -u];
  if (u >= t.L) return t.spine[t.spine.length - 1];
  const [lo, hi, f] = search(t, u);
  return [t.spine[lo][0] + (t.spine[hi][0] - t.spine[lo][0]) * f, t.spine[lo][1] + (t.spine[hi][1] - t.spine[lo][1]) * f];
}
function halfAt(t, v) { const [lo, hi, f] = search(t, Math.max(0, Math.min(t.L, v))); return t.half[lo] + (t.half[hi] - t.half[lo]) * f; }
const M = 72;
// One tentacle taken in by `amount` (0 out, 1 in): it slides back along its own track, keeping its shape.
function drawTentacle(ctx, t, amount) {
  const e = smooth(clamp01(amount));
  if (e >= 1) return;
  const d = e * t.L, P = [], H = [];
  for (let k = 0; k < M; k++) { const v = (t.L * k) / (M - 1); P.push(along(t, v - d)); H.push(halfAt(t, v)); }
  const left = [], right = [];
  for (let k = 0; k < M; k++) {
    const a = P[Math.max(0, k - 1)], b = P[Math.min(M - 1, k + 1)];
    let nx = -(b[1] - a[1]), ny = b[0] - a[0]; const l = Math.hypot(nx, ny) || 1; nx /= l; ny /= l;
    left.push([P[k][0] + nx * H[k], P[k][1] + ny * H[k]]); right.push([P[k][0] - nx * H[k], P[k][1] - ny * H[k]]);
  }
  ctx.beginPath();
  ctx.moveTo(left[0][0], left[0][1]);
  for (let k = 1; k < M; k++) ctx.lineTo(left[k][0], left[k][1]);
  const tip = P[M - 1], td = Math.atan2(left[M - 1][1] - tip[1], left[M - 1][0] - tip[0]);
  ctx.arc(tip[0], tip[1], H[M - 1], td, td - Math.PI, true);
  for (let k = M - 1; k >= 0; k--) ctx.lineTo(right[k][0], right[k][1]);
  const base = P[0], bd = Math.atan2(right[0][1] - base[1], right[0][0] - base[0]);
  ctx.arc(base[0], base[1], H[0], bd, bd - Math.PI, true);
  ctx.closePath(); ctx.fill();
}

const box = (x) => (x instanceof Element ? x.getBoundingClientRect() : x);
function bezier(x1, y1, x2, y2) {
  const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx, cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
  const X = (t) => ((ax * t + bx) * t + cx) * t, Y = (t) => ((ay * t + by) * t + cy) * t, dX = (t) => (3 * ax * t + 2 * bx) * t + cx;
  return (x) => { let t = x; for (let i = 0; i < 6; i++) { const d = dX(t); if (Math.abs(d) < 1e-6) break; t -= (X(t) - x) / d; } return Y(clamp01(t)); };
}
const EASE = bezier(.2, .8, .2, 1);   // --ease (TOKENS.bend ease)

/**
 * Fly Fairy from `from` (an .agent__fairy, or its rect) to `to` (an .agent__fairy, given now or later with
 * land()). "in" starts as the full fairy and lands as the ball (mountAgent's ball: true); "out" the other way.
 * Until it knows where it goes it stays where it was, doing its Jelly there. `done` runs once it has landed
 * and settled: show the face that waits there then (keep it hidden until). With reduced motion it does
 * nothing and `done` runs at once.
 */
export function jellyFlight({ from, to = null, direction = "in", done } = {}) {
  let landed = done, target = to, cancelled = false;
  let finished = false;
  const api = {
    land(el, cb) { target = el; if (cb) landed = cb; if (finished && !cancelled) landed?.(); },   // already done (reduced motion): show it now
    cancel() { cancelled = true; },
    get flying() { return !cancelled && !finished; },
  };
  const start = box(from);
  if (lessMotion.matches || !start || !start.width) { finished = true; queueMicrotask(() => landed?.()); return api; }

  const k = tentacleKit();
  const goingIn = direction === "in";
  const size0 = start.width, toRect0 = target ? box(target) : null;
  const BIG = Math.round(Math.max(size0, toRect0 ? toRect0.width : 0));
  const el = document.createElement("div");
  el.className = "fairy-flight";
  el.innerHTML = '<canvas class="fairy-flight__tentacles"></canvas><div></div>';
  el.style.width = el.style.height = BIG + "px";
  document.body.append(el);
  const tent = el.firstChild, host = el.lastChild;
  const css = getComputedStyle(document.documentElement);
  const COLOR = css.getPropertyValue("--fairy-color").trim() || T.fairy_color(), INK = css.getPropertyValue("--fairy-ink").trim() || T.fairy_ink();
  const animator = createAnimator();
  let surface = null;

  // The springs: the tentacles (amount: 0 out, 1 in) and the squash (q, of the body's height).
  const s = { amount: goingIn ? 0 : 1, target: goingIn ? 1 : 0, vel: 0, q: 0, qv: 0, prev: goingIn ? 0 : 1, happyUntil: 0 };
  s.qv = goingIn ? B.jelly_reach() : B.jelly_squash() * B.jelly_let_go();
  let here = [start.left + start.width / 2, start.top + start.height / 2], hereSize = size0, travel = null, last = null;

  const finish = () => {
    if (finished) return;
    finished = true; el.remove(); if (!cancelled) landed?.();
  };
  const draw = (time) => {
    if (cancelled) { el.remove(); finished = true; return false; }
    const now = performance.now();
    const dt = last === null ? 0 : Math.min(0.05, (now - last) / 1000); last = now;
    // Springs.
    const c = 2 * Math.sqrt(B.jelly_spring()) * B.jelly_damping();
    s.vel += (B.jelly_spring() * (s.target - s.amount) - c * s.vel) * dt;
    s.amount = clamp01(s.amount + s.vel * dt);
    if (Math.abs(s.target - s.amount) < 0.0005 && Math.abs(s.vel) < 0.001) { s.amount = s.target; s.vel = 0; }
    if (goingIn && s.prev < B.jelly_arrive() && s.amount >= B.jelly_arrive()) { s.qv -= B.jelly_squash(); s.happyUntil = now + B.jelly_smile() * 1000; }
    s.prev = s.amount;
    const qc = 2 * Math.sqrt(B.jelly_squash_spring()) * B.jelly_squash_damping();
    s.qv += (-B.jelly_squash_spring() * s.q - qc * s.qv) * dt;
    s.q += s.qv * dt;
    if (Math.abs(s.q) < 1e-4 && Math.abs(s.qv) < 1e-3) { s.q = 0; s.qv = 0; }
    s.q = Math.max(-B.jelly_grow() * 0.9 - 0.12, Math.min(0.35, s.q));

    // Where: where it was until it knows where it goes, then a flight there that follows the place.
    const dest = target ? box(target) : null;
    if (dest && !travel) travel = { from: here.slice(), fromSize: hereSize, start: now };
    let at = here, size = hereSize, flown = false;
    if (dest) {
      const x = clamp01((now - travel.start) / (B.jelly_travel() * 1000)), e = EASE(x);
      const c2 = [dest.left + dest.width / 2, dest.top + dest.height / 2];
      at = [travel.from[0] + (c2[0] - travel.from[0]) * e, travel.from[1] + (c2[1] - travel.from[1]) * e];
      size = travel.fromSize + (dest.width - travel.fromSize) * e;
      flown = x >= 1;
    }
    here = at; hereSize = size;
    const sc = size / BIG;
    el.style.transform = `translate(${at[0] - (BIG * sc) / 2}px, ${at[1] - (BIG * sc) / 2}px) scale(${sc})`;

    // The fairy: the renderer's body (grown, squashed on its base), its eyes moved but not resized,
    // and the tentacles on its middle plane.
    const happy = now < s.happyUntil;
    const st = animator.step({ now, state: "idle", mood: happy ? "happy" : "neutral", target: null, hold: false, reducedMotion: false });
    const opts = { state: "idle", mood: happy ? "happy" : "neutral", stateAge: st.stateAge, motionBlend: st.motionBlend, size: BIG, time, gaze: st.gaze, reducedMotion: false, color: COLOR, eyeColor: INK };
    const full = liveFrame(fairy, opts);
    const body = liveFrame(k.body, opts);
    body.root = full.root;
    const g = 1 + B.jelly_grow() * smooth(s.amount);
    const sy = g * (1 + s.q), sx = g * (1 - s.q * B.jelly_keep_volume());
    const py = CENTER[1] + CORE_R * g;                                   // squashes on its base
    const S = [sx, 0, 0, sy, CENTER[0] - sx * CENTER[0], py - sy * py];
    const eyeAt = apply(S, EYES), E = [1, 0, 0, 1, eyeAt[0] - EYES[0], eyeAt[1] - EYES[1]];
    body.shapes = body.shapes.map((sh) => sh.kind === "slice" ? { ...sh, matrix: mul(S, sh.matrix) } : sh.kind === "eye" ? { ...sh, matrix: mul(E, sh.matrix) } : sh);
    if (!surface) surface = mountCanvas(host, "fairy-flight", k.body, undefined);
    paintCanvas(surface, body, BIG, COLOR, INK);
    const eye = full.shapes.find((x) => x.kind === "eye");
    const [a, b, , d] = eye ? eye.matrix : [1, 0, 0, 1];
    const plane = [a, b, 0, d, k.pivot[0] - a * k.pivot[0], k.pivot[1] - d * k.pivot[1] - b * k.pivot[0]];
    const m = mul(full.root, mul(S, plane));
    const dpr = window.devicePixelRatio || 1, px = Math.round(BIG * dpr);
    if (tent.width !== px) tent.width = tent.height = px;
    const ctx = tent.getContext("2d");
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, px, px);
    const u = (BIG / 100) * dpr;
    ctx.setTransform(u * m[0], u * m[1], u * m[2], u * m[3], u * m[4], u * m[5]);
    ctx.fillStyle = COLOR;
    const spread = B.jelly_stagger();
    for (const t of k.tentacles) drawTentacle(ctx, t, s.amount * (1 + spread) - t.rank * spread);

    // Landed and settled (and smiling done): the face that waits there takes over.
    const still = s.amount === s.target && s.q === 0 && now > s.happyUntil + 350;
    if (flown && still) { finish(); return false; }
    return true;
  };
  subscribeFrames({ draw });
  return api;
}
