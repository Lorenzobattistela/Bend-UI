# Panes, tree, terminal and strip (opt-in: import "bend-ui/panes"). From the Harness Lab's approved mockup.
# Nothing here is locked yet: every value is "# undecided" (it shows on screen, without a law).
# panes.js writes each number as a CSS variable (pane_width → --pane-width).
import Base
import ./TOKENS.bend as T

# Pane: beside a window's main column (on the right), or under it (.pane--under)
def pane_width() -> U32: 256  # undecided. A side pane opens this wide (4 × space_8).
def pane_min() -> U32: 192  # undecided. It is never narrower (3 × space_8).
def pane_col_min() -> U32: 320  # undecided. The main column keeps this much beside a pane (5 × space_8).
def pane_under_height() -> U32: 160  # undecided. A pane under the column opens this tall (2.5 × space_8).
def pane_under_min() -> U32: 96  # undecided. It is never shorter (1.5 × space_8).
def pane_page_min() -> U32: 128  # undecided. The column keeps this much above a pane under it (2 × space_8).
def pane_step() -> U32: T.space_4()  # undecided. One arrow key on the grip.
def pane_grip() -> U32: T.space_2()  # undecided. The grip takes the pointer this far across the pane's edge.
def pane_layer() -> U32: 10  # undecided. A pane as a sheet: over the window's corners (layer_dock), under the side bar's drawer (layer_side).

# Tree
def tree_row() -> U32: T.control_sm()  # undecided. A row's height.
def tree_indent() -> U32: T.space_3()  # undecided. Each level sits this far in, up to its guide line.
def tree_guide_gap() -> U32: T.space_1()  # undecided. From the guide line to the rows inside.

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_s(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# How wide a side pane may be (px): at least pane_min, and the column keeps pane_col_min of the room the two
# share (the window body's width, less any other pane). When the room is too small for both, the pane keeps
# its minimum.
def clamp_width(+wanted: U32, +room: U32) -> U32:
  U32.max(pane_min(), U32.min(wanted, (room - U32.min(room, pane_col_min()) : U32)))

# How tall a pane under the column may be: at least pane_under_min, and the column keeps pane_page_min of
# the room (the column's height).
def clamp_height(+wanted: U32, +room: U32) -> U32:
  U32.max(pane_under_min(), U32.min(wanted, (room - U32.min(room, pane_page_min()) : U32)))

# The size a pane may have: clamp_height for a pane under the column, clamp_width for one beside it.
def clamp(under: Bool, +wanted: U32, +room: U32) -> U32:
  match under:
    case True{}:
      clamp_height(wanted, room)
    case False{}:
      clamp_width(wanted, room)

# The size a pane opens with.
def opens_at(under: Bool) -> U32:
  match under:
    case True{}:
      pane_under_height()
    case False{}:
      pane_width()

# The size a drag asks for: the pane's size when the press began, plus how far the pointer went toward the
# column (from − to, px: the grip is on the pane's inner edge, so going left, or up, grows it). clamp bounds it.
def dragged(+start: U32, +from: U32, +to: U32) -> U32:
  (U32.max((start + from : U32), to) - to : U32)

# What a key on the focused grip does: 1 grow, 2 shrink, 3 the smallest, 4 the largest, 0 nothing (the key
# is not the grip's). The arrow toward the column grows the pane: Left beside it, Up under it.
def grip_key(+key: String, +under: Bool) -> U32:
  pick(String.eq(key, pick_s(under, "ArrowUp", "ArrowLeft")), 1,
  pick(String.eq(key, pick_s(under, "ArrowDown", "ArrowRight")), 2,
  pick(String.eq(key, "Home"), 3,
  pick(String.eq(key, "End"), 4, 0))))

# The size that move asks for (clamp bounds it): a step of pane_step, nothing at all, or the whole room.
def stepped(+now: U32, +move: U32, +room: U32) -> U32:
  pick(U32.is_eq(move, 1), (now + pane_step() : U32),
  pick(U32.is_eq(move, 2), (now - U32.min(now, pane_step()) : U32),
  pick(U32.is_eq(move, 3), 0,
  pick(U32.is_eq(move, 4), room, now))))
