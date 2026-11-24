# Bend-UI: the agent's motion. Pure math; agent.js only draws what comes back.
#
# The face is a sphere. An eye is a point on it at (lon, lat), in radians. The
# sphere turns by yaw (left/right) and pitch (up/down); we see it from the
# front, so a point shows at (x, y) and is visible while z > 0.

import Base

# Where the eyes sit on the sphere.
def eye_lon() -> F32: 0.36
def eye_lat() -> F32: 0.16

# A point (lon, lat) after the sphere turns by yaw: its x, and its depth before pitch.
def turn_x(+lon: F32, +lat: F32, +yaw: F32) -> F32:
  (F32.cos(lat) * F32.sin(lon) * F32.cos(yaw) + F32.cos(lat) * F32.cos(lon) * F32.sin(yaw) : F32)

def turn_z(+lon: F32, +lat: F32, +yaw: F32) -> F32:
  (F32.cos(lat) * F32.cos(lon) * F32.cos(yaw) - F32.cos(lat) * F32.sin(lon) * F32.sin(yaw) : F32)

# The same point after pitch: its y (up is positive) and its depth (visible while > 0).
def face_x(+lon: F32, +lat: F32, +yaw: F32) -> F32:
  turn_x(lon, lat, yaw)

def face_y(+lon: F32, +lat: F32, +yaw: F32, +pitch: F32) -> F32:
  (F32.sin(lat) * F32.cos(pitch) - turn_z(lon, lat, yaw) * F32.sin(pitch) : F32)

def face_z(+lon: F32, +lat: F32, +yaw: F32, +pitch: F32) -> F32:
  (F32.sin(lat) * F32.sin(pitch) + turn_z(lon, lat, yaw) * F32.cos(pitch) : F32)

# How much a mark on the sphere shrinks along an axis near the edge: sqrt(1 - p²).
def squash(+p: F32) -> F32:
  F32.sqrt(F32.max(0.0, (1.0 - p * p : F32)))

# How far the face turns toward a point: (dx, dy) from its center, reach in pixels.
# Turns at most 0.7 (yaw) and 0.55 (pitch) radians, so the eyes never reach the edge.
def look_yaw(+dx: F32, +dy: F32, +reach: F32) -> F32:
  (dx / F32.max(F32.hypot(dx, dy), 1.0) * F32.min(1.0, (F32.hypot(dx, dy) / reach : F32)) * 0.7 : F32)

def look_pitch(+dx: F32, +dy: F32, +reach: F32) -> F32:
  (dy / F32.max(F32.hypot(dx, dy), 1.0) * F32.min(1.0, (F32.hypot(dx, dy) / reach : F32)) * 0.55 : F32)

# A damped spring: the next velocity toward a target, over dt seconds.
# Stiffness 140 and damping 18 settle with a small bounce.
def spring(+vel: F32, +pos: F32, +target: F32, +dt: F32) -> F32:
  (vel + (140.0 * (target - pos) - 18.0 * vel) * dt : F32)

# Ease out: fast, then slow. t goes 0 → 1.
def ease_out(+t: F32) -> F32:
  (1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t) : F32)

# The items around the face. Fan (lg): one every 45°, starting to the left (180°)
# and turning up; distance in face radii. Row (sm): a line to the left.
def fan_angle(+i: F32) -> F32:
  (3.14159265 * (180.0 + 45.0 * i) / 180.0 : F32)

def fan_dist() -> F32: 2.0

def fan_x(+i: F32, +r: F32, +t: F32) -> F32:
  (F32.cos(fan_angle(i)) * r * fan_dist() * t : F32)

def fan_y(+i: F32, +r: F32, +t: F32) -> F32:
  (F32.sin(fan_angle(i)) * r * fan_dist() * t : F32)

# Row: the item's center, left of the face. r = face radius, w = item width, gap in pixels.
def row_x(+i: F32, +r: F32, +w: F32, +gap: F32, +t: F32) -> F32:
  ((0.0 - (r + gap + w / 2.0 + i * (w + gap))) * t : F32)

# Hover (open: "hover"): how long the options stay after the pointer leaves, in seconds.
# Long enough to cross the gap between the face and an option.
def hover_close() -> F32: 0.28

# Ease in and out (smootherstep): slow, fast, slow. t goes 0 → 1.
def ease_in_out(+t: F32) -> F32:
  (t * t * t * (t * (t * 6.0 - 15.0) + 10.0) : F32)

# Work in progress: how far it has crept after `elapsed` ms, 0 → 1, ever slower, never
# arriving. `tau` (ms, creep_ms in TOKENS.bend) sets the pace: after tau it is about 63% there.
def creep(+elapsed: F32, +tau: F32) -> F32:
  (1.0 - F32.exp(((0.0 - elapsed) / tau : F32)) : F32)

# Thread (pairs): how far the line runs past the aside's node while its work creeps,
# in steps of the path sentence → aside → bottom of the aside.
def thread_reach(+crept: F32) -> F32:
  (1.0 + crept * 0.8 : F32)

# A node fills like a clock while its work creeps; it never looks full until the work is done.
def node_fill(+crept: F32) -> F32:
  (F32.clamp((crept / 0.75 : F32), 0.0, 1.0) * 0.92 : F32)

# ---------- The agent's timing and feel (agent.js reads these) ----------

# Blink: about every blink_every seconds (plus up to blink_jitter), with chance blink_chance;
# the eyes close to blink_closed of their height for blink_hold seconds.
def blink_every() -> F32: 2.7
def blink_jitter() -> F32: 0.8
def blink_chance() -> F32: 0.6
def blink_closed() -> F32: 0.12
def blink_hold() -> F32: 0.12

# Shake (a small "no"): lasts shake_time seconds, wobbles at shake_speed, at most shake_size radians.
def shake_time() -> F32: 0.6
def shake_speed() -> F32: 38.0
def shake_size() -> F32: 0.32

# Look: the face turns fully toward a point look_reach face widths away (at least look_reach_min px).
# At an element it looks at look_el_x of its width, look_el_amount of the way.
def look_reach() -> F32: 2.2
def look_reach_min() -> F32: 140.0
def look_el_x() -> F32: 0.3
def look_el_amount() -> F32: 0.6

# An eye fades out as it turns away: fully gone at depth 0, fully seen at 1 / eye_fade.
def eye_fade() -> F32: 6.0

# The items opening: each waits item_stagger seconds after the one before, takes item_time
# seconds, and grows from item_scale_from of its size. Fan (lg): gap fan_gap face radii.
def item_stagger() -> F32: 0.06
def item_time() -> F32: 0.28
def item_scale_from() -> F32: 0.5
def fan_gap() -> F32: 0.35

# Label flash: one item's label shows for flash_time seconds.
def flash_time() -> F32: 2.6

# Fly (flyBetween): the face moves between two places in fly_time seconds.
def fly_time() -> F32: 0.46

# A frame never moves things more than max_step seconds, so a slow tab doesn't jump.
def max_step() -> F32: 0.05

# ---------- Rise: the rows of a menu come in one after another (ui.js, .menu[data-motion="rise"]) ----------
# Each row grows from nothing to its height, so the menu's box is built row by row, and its content rises
# rise_distance (TOKENS.bend) into place. In whole ms, so the laws can check them exactly.
def rise_order() -> String: "up"        # undecided. "up": the bottom row first. "down": the top row first.
def rise_stagger_ms() -> U32: 60        # undecided. A row waits this long after the one before (item_stagger).
def rise_time_ms() -> U32: 360          # undecided. One row's time (duration_enter).
def rise_ease() -> String: "spring"     # undecided. "spring" (ease_spring), "ease" or "in-out".

# Which turn row i of n gets.
def rise_turn_down(+i: U32, +n: U32) -> U32: i
def rise_turn_up(+i: U32, +n: U32) -> U32: ((n - 1 : U32) - i : U32)
# A row waits its turn times the stagger before it starts.
def rise_delay(+turn: U32, +stagger: U32) -> U32: (turn * stagger : U32)
# The whole menu is in place after the last turn's wait plus one row's time.
def rise_total(+n: U32, +stagger: U32, +time: U32) -> U32: (rise_delay((n - 1 : U32), stagger) + time : U32)

# ---------- Squeeze and stretch: a piece leaves by closing on its own middle and arrives by opening from it ----------
# (ui.js: squeezeOut, stretchIn; board.js: moveCard.) Nothing crosses the screen: the piece closes on its vertical
# middle where it is, the room it took closes while the room it will take opens, and it opens there. In whole ms.
def squeeze_time_ms() -> U32: 360       # undecided. The piece closing (duration_enter).
def squeeze_ease() -> String: "back"    # "back" (ease_back: it gathers, then goes), "ease" or "in-out".
def stretch_time_ms() -> U32: 360       # undecided. The piece opening (duration_enter).
def stretch_ease() -> String: "in-out"  # "in-out" (slow, fast, slow), "ease" or "spring" (ease_spring).
def space_time_ms() -> U32: 360         # undecided. The room closing where the piece left and opening where it lands.
def move_hold_ms() -> U32: 0            # undecided. A wait before the piece starts to close.
# ease_spring (TOKENS.bend) played backwards: the same curve, mirrored, so a piece gathers before it goes.
def ease_back() -> String: "cubic-bezier(.36, 0, .66, -.56)"

# ---------- A plus that opens into an icon (motion.js: plusIcon, becomeIcon) ----------
# The icon's outline is a line of points. Each comes from the arm of the plus that points its way: a point
# straight out from the middle comes from that arm's tip, a point on a diagonal from the plus's middle. So the
# plus opens like a hand into the icon. Icons are drawn on a grid of 24; the plus has arms of 7 around its middle.
def plus_mid() -> F32: 12.0
def plus_arm() -> F32: 7.0
def plus_points() -> U32: 120            # how many points the line has

# How far a direction is from the nearest arm: 0 along it, 1 on the diagonal between two. It is the angle
# as a share of 45°, read from the tangent t (atan(t) is t·π/4 + 0.273·t·(1 − t), within 0.004).
def plus_off.of(+t: F32) -> F32:
  (t + 0.3476 * t * (1.0 - t) : F32)

def plus_off(+dx: F32, +dy: F32) -> F32:
  plus_off.of((F32.min(F32.abs(dx), F32.abs(dy)) / F32.max(F32.max(F32.abs(dx), F32.abs(dy)), 0.0001) : F32))

# How far out on its arm a point of the icon starts.
def plus_reach(+dx: F32, +dy: F32) -> F32:
  (plus_arm() * (1.0 - plus_off(dx, dy)) : F32)

def plus_side(+v: F32) -> F32:
  Bool.pick(F32, F32.is_lt(v, 0.0), (0.0 - 1.0 : F32), 1.0)

# Is the direction nearer a side arm (left, right) than an up or down one?
def plus_across(+dx: F32, +dy: F32) -> Bool:
  F32.is_ge(F32.abs(dx), F32.abs(dy))

# Where the icon's point (x, y) starts on the plus.
def plus_x.at(+dx: F32, +dy: F32) -> F32:
  Bool.pick(F32, plus_across(dx, dy), (plus_mid() + plus_side(dx) * plus_reach(dx, dy) : F32), plus_mid())

def plus_y.at(+dx: F32, +dy: F32) -> F32:
  Bool.pick(F32, plus_across(dx, dy), plus_mid(), (plus_mid() + plus_side(dy) * plus_reach(dx, dy) : F32))

def plus_x(+x: F32, +y: F32) -> F32:
  plus_x.at((x - plus_mid() : F32), (y - plus_mid() : F32))

def plus_y(+x: F32, +y: F32) -> F32:
  plus_y.at((x - plus_mid() : F32), (y - plus_mid() : F32))

# A point on its way: at p 0 it is on the plus (a), at 1 on the icon (b).
def mix(+a: F32, +b: F32, +p: F32) -> F32:
  (a + (b - a) * p : F32)

# The plus arrives turning into place: from plus_in_scale of its size and plus_in_turn degrees away, in
# plus_in_ms (duration_enter), on ease_spring, plus_in_wait_ms after its ground starts to show.
def plus_in_ms() -> U32: 360
def plus_in_wait_ms() -> U32: 60
def plus_in_scale() -> F32: 0.2
def plus_in_turn() -> F32: (0.0 - 90.0 : F32)

# It becomes the icon in become_ms (duration_connect), its line opening on ease_in_out. The whole icon
# gathers first (become_gather of its size, at become_gather_at of the way), comes out a little too big
# (become_over, at become_over_at) and settles become_settle_ms after the line is done: the landing is the
# whole icon's, so the shape itself is never bent.
def become_ms() -> U32: 560
def become_settle_ms() -> U32: 120
def become_gather() -> F32: 0.9
def become_gather_at() -> F32: 0.2
def become_over() -> F32: 1.12
def become_over_at() -> F32: 0.72

# ---------- Something new in a side bar (motion.js: arriveNew, settleNew, leaveNew, popIn, makeRoom) ----------
# Its ground shows in new_in_ms (duration_enter); on the rail, where it is a small square, it also grows from
# new_in_scale of its size, on ease_spring. A state's dot pops in in pop_ms (duration_enter), on ease_spring.
# Nothing came of it: it leaves in new_out_ms (2 × duration), to new_out_scale of its size.
def new_in_ms() -> U32: 360
def new_in_scale() -> F32: 0.5
def new_out_ms() -> U32: 240
def new_out_scale() -> F32: 0.6
def pop_ms() -> U32: 360
def room_ms() -> U32: 240                # the room it takes opens, or closes (2 × duration)

# ---------- Words that travel (motion.js: liftWords) ----------
# The words of a link leave where they were and become a name somewhere else, in words_ms (duration_connect).
def words_ms() -> U32: 560

# ---------- Stepping back (motion.js: stepBack, stepForward) ----------
# What a place said goes smaller and fainter toward where that place lives (its button), to step_scale of
# its size; it leaves in step_back_ms (2 × duration) and comes forward again in step_forward_ms (duration_enter).
def step_scale() -> F32: 0.94
def step_back_ms() -> U32: 240
def step_forward_ms() -> U32: 360
# What arrives in its place rises arrive_rise px (space_1) while it shows, each piece arrive_stagger_ms after the one before.
def arrive_rise() -> F32: 4.0
def arrive_stagger_ms() -> U32: 60

# A label changes its words (motion.js: swapWords): the old ones go in words_out_ms (duration), the new ones
# come from the side, arrive_rise away.
def words_out_ms() -> U32: 120

# A small answer (motion.js: nudge): the piece grows to nudge_scale at nudge_at of the way and comes back, in
# nudge_ms (duration_enter), on ease_spring.
def nudge_scale() -> F32: 1.14
def nudge_at() -> F32: 0.4
def nudge_ms() -> U32: 360
