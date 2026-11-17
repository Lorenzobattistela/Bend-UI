# Bend-UI: dragging a card on the board. Pure; board.js only measures and moves.
# The motion itself is MOTION.bend's spring.
import Base

# A press becomes a drag once the pointer moves this far (px), so a click stays a click. Undecided.
def start_distance() -> F32: 4.0

# The pointer is far enough from where it pressed to start a drag.
def starts(+dx: F32, +dy: F32) -> Bool:
  F32.is_gt(F32.hypot(dx, dy), start_distance())

# A dragged card lands before a card when the pointer is above that card's middle.
def lands_before(+y: F32, +top: F32, +height: F32) -> Bool:
  F32.is_gt((top + height / 2.0 : F32), y)

# How far a number is from zero.
def size(+d: F32) -> F32:
  F32.max(d, (0.0 - d : F32))

# A spring has settled: within half a pixel of its target and moving less than half a pixel a second.
def settled(+pos: F32, +target: F32, +vel: F32) -> Bool:
  F32.is_gt(0.5, size((target - pos : F32))) && F32.is_gt(0.5, size(vel))

# Near an edge of the board (px), a dragged card scrolls it. Undecided.
def edge() -> F32: 48.0

# How fast the board scrolls (px a frame) with the pointer this far inside an edge: faster the closer it is,
# up to 16 at the edge itself; 0 outside. Undecided.
def scroll_step(+inside: F32) -> F32:
  F32.max(0.0, (16.0 * (1.0 - inside / edge()) : F32))
