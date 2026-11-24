import Base

# Open Bot Avatar 0.3.0 motion, translated without changing curves or timing.
# Browser I/O, frame scheduling and the original volume renderer stay in JS.
type Point is Data:
  Point{x: F32, y: F32}
type Follow is Data:
  Follow{x: F32, y: F32, attention: F32}
type FollowResult is Data:
  FollowResult{state: Follow, moving: Bool}
type Pose is Data:
  Pose{yaw: F32, pitch: F32, roll: F32, lift: F32, sx: F32, sy: F32, gazeX: F32, gazeY: F32, blink: F32, squintL: F32, squintR: F32, arc: F32, slit: F32, ribbons: F32, cage: F32, sweep: F32, bang: F32, dots: F32}

def choose(test: Bool, yes: F32, no: F32) -> F32: Bool.pick(F32, test, yes, no)
def clamp(x: F32) -> F32: F32.clamp(x, 0.0, 1.0)
def mix(+a: F32, b: F32, k: F32) -> F32: (a + (b - a) * k : F32)
def smooth(v: F32) -> F32:
  +x = clamp(v)
  (x * x * (3.0 - 2.0 * x) : F32)
def tau() -> F32: 6.283185307179586

def noise(+seed: U32, n: F32) -> F32:
  +h = U32.xor(seed, U32.mul(F32.to_u32(n), 2654435761))
  +a = U32.mul(U32.xor(h, U32.shrn(h, 16n)), 2246822507)
  +b = U32.mul(U32.xor(a, U32.shrn(a, 13n)), 3266489909)
  (U32.to_f32(U32.xor(b, U32.shrn(b, 16n))) / 4294967296.0 : F32)

def gaze_axis(+dx: F32, +dy: F32) -> F32:
  +m = F32.hypot(dx, dy)
  +e = F32.exp((0.0 - 2.0 * m : F32))
  choose((m < 0.000000001 : F32), 0.0, (dx * ((1.0 - e) / (1.0 + e)) / F32.max(m, 0.000000001) : F32))
def pointer_gaze(+px: F32, +py: F32, +left: F32, +top: F32, +width: F32, +height: F32, ox: F32, oy: F32) -> Point:
  +reach = F32.max(F32.max(width, height), 160.0)
  +dx = ((px - (left + width * ox)) / reach : F32)
  +dy = ((py - (top + height * oy)) / reach : F32)
  Point{gaze_axis(dx, dy), gaze_axis(dy, dx)}
def ease(+dt: F32, constant: F32, reduced: Bool) -> F32:
  choose(reduced, 1.0, (1.0 - F32.exp((0.0 - F32.clamp(dt, 0.0, 0.1) / constant : F32)) : F32))
def follow_result(+x: F32, +y: F32, +a: F32, +tx: F32, +ty: F32, +ta: F32) -> FollowResult:
  +moving = (F32.abs((tx - x : F32)) > 0.002 : F32) || (F32.abs((ty - y : F32)) > 0.002 : F32) || (F32.abs((ta - a : F32)) > 0.002 : F32)
  FollowResult{Follow{choose(moving, x, tx), choose(moving, y, ty), choose(moving, a, ta)}, moving}
def follow_step(x: F32, y: F32, a: F32, +tx: F32, +ty: F32, +active: Bool, +dt: F32, +reduced: Bool) -> FollowResult:
  +gx = choose(active, tx, 0.0)
  +gy = choose(active, ty, 0.0)
  +ga = choose(active, 1.0, 0.0)
  +k = ease(dt, choose(active, 0.12, 0.3), reduced)
  follow_result(mix(x, gx, k), mix(y, gy, k), mix(a, ga, ease(dt, 0.3, reduced)), gx, gy, ga)
def mood_progress(ms: F32) -> F32: smooth((ms / 420.0 : F32))
def drag_yaw(start: F32, dx: F32) -> F32: (start + dx * 0.011 : F32)
def drag_pitch(start: F32, dy: F32) -> F32: F32.clamp((start - dy * 0.009 : F32), (0.0 - 0.9 : F32), 0.9)
def reset_progress(ms: F32) -> F32:
  +u = (1.0 - clamp((ms / 420.0 : F32)) : F32)
  (1.0 - u * u * u : F32)

def blink_one(+u: F32) -> F32:
  choose((u > 0.0 : F32) && (u < 1.0 : F32), F32.sin((3.141592653589793 * u : F32)), 0.0)
def blink_slot(+seed: U32, +t: F32, +s: F32) -> F32:
  +start = (s * 4.2 + 0.5 + noise(seed, (s * 2.0 : F32)) * 2.9 : F32)
  F32.max(blink_one(((t - start) / 0.19 : F32)), choose((noise(seed, (s * 2.0 + 1.0 : F32)) > 0.8 : F32), blink_one(((t - start - 0.34) / 0.19 : F32)), 0.0))
def blink(+seed: U32, +t: F32) -> F32:
  +slot = F32.floor((t / 4.2 : F32))
  F32.max(blink_slot(seed, t, (slot - 1.0 : F32)), blink_slot(seed, t, slot))
def wander_target(+seed: U32, +k: F32, +axis: F32) -> F32:
  choose((noise(seed, (1000.0 + k * 3.0 : F32)) < 0.4 : F32), 0.0, ((noise(seed, (1001.0 + axis + k * 3.0 : F32)) * 2.0 - 1.0) * choose(F32.is_eq(axis, 0.0), 0.6, 0.35) : F32))
def wander(+seed: U32, +t: F32, +axis: F32) -> F32:
  +s = F32.floor((t / 1.9 : F32))
  mix(wander_target(seed, (s - 1.0 : F32), axis), wander_target(seed, s, axis), smooth(((t - s * 1.9) / 0.16 : F32)))
def dart_target(+seed: U32, +k: F32, +axis: F32) -> F32:
  +n = noise(seed, (2001.0 + axis + k * 3.0 : F32))
  choose(F32.is_eq(axis, 0.0), ((n * 2.0 - 1.0) * 0.8 : F32), (0.1 + n * 0.5 : F32))
def dart(+seed: U32, +t: F32, +axis: F32) -> F32:
  +s = F32.floor((t / 0.62 : F32))
  mix(dart_target(seed, (s - 1.0 : F32), axis), dart_target(seed, s, axis), smooth(((t - s * 0.62) / 0.12 : F32)))
def wave(t: F32, period: F32, phase: F32, live: F32) -> F32: (F32.sin((tau() * t / period + phase : F32)) * live : F32)
def base(arc: F32) -> Pose: Pose{(0.0 - 0.3 : F32), 0.2, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, arc, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
def rest(+seed: U32, +t: F32, +pace: F32, +sway: F32, +live: F32, arc: F32) -> Pose:
  +breath = wave(t, (3.4 * pace : F32), (0.0 - 1.5707963267948966 : F32), live)
  Pose{((0.0 - 0.3 : F32) + 0.07 * sway * wave(t, (6.1 * pace : F32), 0.0, live) : F32), (0.2 + 0.04 * sway * wave(t, (4.7 * pace : F32), 1.0, live) : F32), (1.6 * wave(t, (5.3 * pace : F32), 2.0, live) : F32), ((0.0 - 0.45 : F32) * (1.0 - F32.cos((tau() * t / (3.4 * pace) : F32))) * live : F32), (1.0 - 0.008 * breath : F32), (1.0 + 0.012 * breath : F32), (wander(seed, t, 0.0) * live : F32), (wander(seed, t, 1.0) * live : F32), (blink(seed, t) * live : F32), 0.0, 0.0, arc, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
def happy(+t: F32, +live: F32) -> Pose:
  +p = choose(F32.is_eq(live, 0.0), 0.5, (((t % 0.92 + 0.92) % 0.92) / 0.92 : F32))
  +air = (4.0 * p * (1.0 - p) : F32)
  +land = (clamp((1.0 - F32.min(p, (1.0 - p : F32)) / 0.12 : F32)) * live : F32)
  Pose{((0.0 - 0.3 : F32) + 0.1 * wave(t, 1.84, 0.6, live) : F32), 0.2, (4.5 * wave(t, 1.84, 0.0, live) : F32), ((0.0 - 3.2 : F32) * air * live : F32), (1.0 + 0.07 * land - 0.015 * air * live : F32), (1.0 - 0.09 * land + 0.03 * air * live : F32), 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
def thinking(+seed: U32, +t: F32, sway: F32, +live: F32, arc: F32) -> Pose:
  Pose{((0.0 - 0.3 : F32) + 0.12 + 0.05 * sway * wave(t, 7.3, 0.0, live) : F32), 0.28, ((0.0 - 5.0 : F32) + 1.4 * wave(t, 4.1, 0.0, live) : F32), ((0.0 - 0.5 : F32) * (1.0 - F32.cos((tau() * t / 5.2 : F32))) * live : F32), 1.0, 1.0, (0.55 + 0.3 * wave(t, 5.6, 0.0, live) : F32), (0.0 - 0.8 : F32), (blink(seed, (t * 0.7 : F32)) * live : F32), 0.22, (0.32 + 0.1 * wave(t, 3.1, 0.0, live) : F32), arc, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0}
def waiting(seed: U32, +t: F32, sway: F32, +live: F32, +arc: F32) -> Pose:
  +p = ((((t % 6.5 + 6.5) % 6.5) / 6.5) * live : F32)
  +sigh = F32.sin((tau() * clamp((p / 0.33 : F32)) : F32))
  Pose{((0.0 - 0.3 : F32) + 0.04 * sway * wave(t, 7.4, 0.0, live) : F32), (0.22 + 0.03 * sigh : F32), (7.0 + 1.2 * wave(t, 6.4, 2.0, live) : F32), ((0.0 - 0.3 : F32) * (1.0 - F32.cos((tau() * t / 6.5 : F32))) * live : F32), (1.0 - 0.012 * sigh : F32), (1.0 + 0.025 * sigh : F32), (0.5 + 0.15 * wave(t, 8.2, 0.0, live) : F32), 0.1, (blink(seed, (t * 0.6 : F32)) * live : F32), 0.0, 0.0, arc, (1.0 - arc : F32), 0.0, 0.0, 0.0, 0.0, 0.0}
def blocked(arc: F32) -> Pose: Pose{(0.0 - 0.3 : F32), 0.2, 0.0, 0.0, 0.99, 1.02, 0.0, 0.0, 0.0, 0.0, 0.0, arc, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0}

def work_candidate(seed: U32, +age: F32, first: F32, +k: F32) -> F32:
  +start = (first + k * 7.5 + choose(F32.is_eq(k, 0.0), 0.0, (1.5 * noise(seed, (60.0 + k : F32)) : F32)) : F32)
  choose((k >= 0.0 : F32) && (age >= start : F32) && (age < start + 1.5 : F32), (age - start : F32), (0.0 - 1.0 : F32))
def work_turn(+seed: U32, +age: F32) -> F32:
  +first = (1.2 + 1.2 * noise(seed, 41.0) : F32)
  +n = F32.floor(((age - first) / 7.5 : F32))
  +a = work_candidate(seed, age, first, n)
  choose((age < first : F32), (0.0 - 1.0 : F32), choose((a >= 0.0 : F32), a, work_candidate(seed, age, first, (n - 1.0 : F32))))
def work_extra(pose: Pose, +into: F32) -> Pose:
  match pose:
    case Pose{yaw, pitch, roll, lift, sx, sy, gx, gy, blink, sl, sr, arc, slit, ribbons, cage, sweep, bang, dots}:
      +on = choose((into >= 0.0 : F32), 1.0, 0.0)
      +e = (6.2 * F32.max(into, 0.0) : F32)
      +turn = (tau() * (1.0 - (1.0 + e) * F32.exp((0.0 - e : F32))) : F32)
      +swell = (F32.sin((turn / 2.0 : F32)) * on : F32)
      Pose{(yaw + 0.22 * swell : F32), pitch, (roll + 3.0 * swell : F32), (lift - 1.2 * swell : F32), sx, sy, F32.clamp((gx * (1.0 - swell) - 0.85 * F32.sin(turn) * on : F32), (0.0 - 1.0 : F32), 1.0), (gy * (1.0 - swell) - 0.3 * swell : F32), blink, sl, sr, arc, slit, (clamp((into / 0.16 : F32)) * clamp(((1.5 - into) / 0.5 : F32)) * on : F32), cage, (turn * on : F32), bang, dots}
def working(+seed: U32, +t: F32, sway: F32, +live: F32, arc: F32, age: F32) -> Pose:
  +beat = wave(t, 0.7, 0.0, live)
  p = {Pose{((0.0 - 0.3 : F32) + 0.08 * sway * wave(t, 2.3, 0.4, live) : F32), 0.15, (3.0 + 0.6 * beat : F32), ((0.0 - 0.3 : F32) * (0.5 + 0.5 * beat) * live : F32), (1.005 + 0.005 * beat : F32), (0.99 - 0.008 * beat : F32), choose(F32.is_eq(live, 0.0), 0.15, dart(seed, t, 0.0)), choose(F32.is_eq(live, 0.0), 0.3, dart(seed, t, 1.0)), (blink(seed, (t * 1.3 : F32)) * live : F32), 0.25, 0.25, arc, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0} : Pose}
  work_extra(p, choose(F32.is_eq(live, 0.0), (0.0 - 1.0 : F32), work_turn(seed, F32.max(age, 0.0))))

def celebration(+t: F32) -> F32:
  +v = ((9.0 * tau() + 0.5) / 2.4625 : F32)
  +q = (1.0 - (t - 2.54) / 1.25 : F32)
  choose((t <= 0.0 : F32), 0.0, choose((t < 0.24 : F32), ((0.0 - 0.25 : F32) * (1.0 - F32.cos((3.141592653589793 * t / 0.24 : F32))) : F32), choose((t < 0.54 : F32), ((0.0 - 0.5 : F32) + v * (t - 0.24) * (t - 0.24) / 0.6 : F32), choose((t < 2.54 : F32), ((0.0 - 0.5 : F32) + v * (t - 0.39) : F32), choose((t < 3.79 : F32), ((0.0 - 0.5 : F32) + v * 2.15 + 1.25 * v * (1.0 - q * q * q * q) / 4.0 : F32), (9.0 * tau() : F32))))))
def done_extra(pose: Pose, +since: F32, +way: F32) -> Pose:
  match pose:
    case Pose{yaw, pitch, roll, lift, sx, sy, gx, gy, blink, sl, sr, arc, slit, ribbons, cage, sweep, bang, dots}:
      +on = choose((since < 3.87 : F32), 1.0, 0.0)
      +swell = (F32.sin((3.141592653589793 * since / 3.87 : F32)) * on : F32)
      +turn = (celebration(since) * way / 3.0 : F32)
      +near = (turn - tau() * F32.round((turn / tau() : F32)) : F32)
      Pose{(yaw + near * on : F32), pitch, roll, (lift - 2.2 * swell : F32), sx, (sy + 0.04 * swell : F32), gx, gy, blink, sl, sr, arc, slit, (clamp((since / 0.1 : F32)) * clamp(((3.87 - since) / 0.5 : F32)) * on : F32), on, (way * F32.max(0.0, celebration(since)) * on : F32), bang, dots}
def done(+seed: U32, t: F32, sway: F32, +live: F32, arc: F32, age: F32) -> Pose:
  +a = choose(F32.is_eq(live, 0.0), 3.87, F32.max(age, 0.0))
  +length = (6.2 * (1.0 + 0.15 * noise(seed, 31.0)) : F32)
  +cycle = F32.floor((a / length : F32))
  done_extra(rest(seed, t, 1.25, sway, live, arc), (a - cycle * length : F32), choose(F32.is_eq((cycle % 2.0 : F32), 0.0), 1.0, (0.0 - 1.0 : F32)))

def state_pose(state: U32, +seed: U32, +t: F32, +sway: F32, +live: F32, +arc: F32, age: F32) -> Pose:
  match state:
    case 1: thinking(seed, t, sway, live, arc)
    case 2: working(seed, t, sway, live, arc, age)
    case 3: waiting(seed, t, sway, live, arc)
    case 4: blocked(arc)
    case 5: done(seed, t, sway, live, arc, age)
    case _: Bool.pick(Pose, F32.is_eq(arc, 1.0), happy(t, live), rest(seed, t, 1.0, sway, live, arc))
def aim(pose: Pose, +gx: F32, +gy: F32, +weight: F32, +live: F32, vy: F32, vp: F32) -> Pose:
  match pose:
    case Pose{yaw, pitch, roll, lift, sx, sy, x, y, blink, sl, sr, +arc, slit, ribbons, cage, sweep, bang, dots}:
      +follow = (weight * (1.0 - arc) : F32)
      +share = choose(F32.is_eq(live, 0.0), 1.0, 0.7)
      Pose{(yaw + weight * (gx * 0.32 + 0.3) * live + vy : F32), (pitch + weight * (0.0 - gy * 0.18 - 0.1) * live + vp : F32), roll, lift, sx, sy, mix(x, (gx * share : F32), follow), mix(y, (gy * share : F32), follow), blink, sl, sr, arc, slit, ribbons, cage, sweep, bang, dots}
def pose(+seed: U32, time: F32, state: U32, arc: F32, age: F32, gx: F32, gy: F32, +weight: F32, reduced: Bool, vy: F32, vp: F32) -> Pose:
  +live = choose(reduced, 0.0, 1.0)
  +t = ((time + noise(seed, 7.0) * 10.0) * live : F32)
  aim(state_pose(state, seed, t, (1.0 - 0.7 * weight : F32), live, arc, age), gx, gy, weight, live, vy, vp)

# Interrupted states blend their poses at the same clock instant.
def blend_pose(+a: Pose, +b: Pose, t: F32) -> Pose:
  match a b:
    case Pose{ayaw, apitch, aroll, alift, asx, asy, agazeX, agazeY, ablink, asquintL, asquintR, aarc, aslit, aribbons, acage, asweep, abang, adots} Pose{byaw, bpitch, broll, blift, bsx, bsy, bgazeX, bgazeY, bblink, bsquintL, bsquintR, barc, bslit, bribbons, bcage, bsweep, bbang, bdots}:
      +k = clamp(t)
      Pose{mix(ayaw, byaw, k), mix(apitch, bpitch, k), mix(aroll, broll, k), mix(alift, blift, k), mix(asx, bsx, k), mix(asy, bsy, k), mix(agazeX, bgazeX, k), mix(agazeY, bgazeY, k), mix(ablink, bblink, k), mix(asquintL, bsquintL, k), mix(asquintR, bsquintR, k), mix(aarc, barc, k), mix(aslit, bslit, k), mix(aribbons, bribbons, k), choose((aribbons > 0.0 : F32), choose((bribbons > 0.0 : F32), mix(acage, bcage, k), acage), bcage), choose((aribbons > 0.0 : F32), choose((bribbons > 0.0 : F32), mix(asweep, bsweep, k), asweep), bsweep), mix(abang, bbang, k), mix(adots, bdots, k)}

# Agent gestures use the same clock as the canvas, without another RAF.
def turn_angle(+start: F32, end: F32, ms: F32) -> F32:
  mix(start, end, reset_progress(ms))
def turn_done(ms: F32) -> Bool: (ms >= 420.0 : F32)
def shake_angle(ms: F32) -> F32:
  +t = clamp((ms / 420.0 : F32))
  (F32.sin((t * tau() * 3.0 : F32)) * 0.12 * (1.0 - t) : F32)

# Jelly (bend-ui/fairy-jelly): the fairy pulls its tentacles in on its way from the start to the chat,
# and lets them out on the way back. Approved in the artifact "Fairy Morphs" (2026-11-24).
# The tentacles' spring (stiffness, damping ratio), and how much the longer ones start first.
def jelly_spring() -> F32: 150.0
def jelly_damping() -> F32: 0.85
def jelly_stagger() -> F32: 0.12
# The body alone grows this much once they are in; the eyes keep their size.
def jelly_grow() -> F32: 0.14
# A reach up before pulling in; the squash on its base when the last one is in, keeping its volume;
# a pop when it lets them go (a share of the squash); the squash's own spring.
def jelly_reach() -> F32: 2.6
def jelly_squash() -> F32: 2.6
def jelly_keep_volume() -> F32: 0.7
def jelly_let_go() -> F32: 0.45
def jelly_squash_spring() -> F32: 210.0
def jelly_squash_damping() -> F32: 0.3
def jelly_arrive() -> F32: 0.985
# Happy eyes after the squash, and the flight between the start and the chat, in seconds.
def jelly_smile() -> F32: 0.9
def jelly_travel() -> F32: 0.64
