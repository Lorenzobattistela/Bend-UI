# Inspect (opt-in: import "bend-ui/inspect"). What is drawn over a piece of interface to read it: the space
# inside each part (padding), around it (margin) and between its children (gap) with its number, the part under the pointer,
# the part picked, and a pin where a comment points.
# Nothing here is locked yet: every value is "# undecided" (it shows on screen, without a law).
# inspect.js writes each number as a CSS variable (inspect_pin → --inspect-pin).
#
# Ideas from: the box model overlay of Chrome DevTools and Firefox (padding in one color, the number on it),
# the red measures between layers in Figma's Dev Mode, and the comment pins of Figma and of Claude's artifacts.
import Base
import ./TOKENS.bend as T

def inspect_pin() -> U32: T.control_sm()  # undecided. A comment's pin: a circle this wide.
def inspect_says_across() -> U32: T.space_3()  # undecided. A band that lies across (top, bottom, a row gap) shows its number when it is at least this thick.
def inspect_says_along() -> U32: T.space_4()  # undecided. A band that stands (left, right, a column gap) shows its number when it is at least this wide.
def inspect_layer() -> U32: 5  # undecided. The drawing sits over the piece, under a menu (layer_menu).
def inspect_out_share() -> U32: 40  # undecided. The picked part's values take at most this much of the height they share with the page, in percent.
def inspect_tint() -> U32: 26  # undecided. How much of its color a band has, in percent: what is under it still reads.

# ---------- A band: one space, drawn ----------
# kind: 0 is padding, 1 is a gap, 2 is a margin. x, y, w, h: where it is, in the layer's own measures (px). n: the space it
# shows. says: whether its number fits on it.
type Band is Data:
  Band{kind: U32, x: F32, y: F32, w: F32, h: F32, n: F32, says: Bool}

def padding() -> U32: 0
def gap() -> U32: 1
def margin() -> U32: 2

def keep(yes: Bool, b: Band, rest: List<&2, Band>) -> List<&2, Band>:
  match yes:
    case True{}:
      b <> rest
    case False{}:
      rest

# A space under one pixel is not drawn.
def shows(+n: F32) -> Bool:
  F32.is_ge(n, 1.0)

def says_across(+thick: F32) -> Bool:
  F32.is_ge(thick, U32.to_f32(inspect_says_across()))

def says_along(+wide: F32, +tall: F32) -> Bool:
  F32.is_ge(wide, U32.to_f32(inspect_says_along())) && F32.is_ge(tall, U32.to_f32(inspect_says_across()))

# The padding of one part, as up to four bands: top and bottom take the part's whole width, left and right
# the height between them, so no corner is painted twice.
# x, y, w, h: the part's box. pt, pr, pb, pl: its padding (top, right, bottom, left).
def pad(+x: F32, +y: F32, +w: F32, +h: F32, +pt: F32, +pr: F32, +pb: F32, +pl: F32) -> List<&2, Band>:
  +mid = (h - pt - pb : F32)
  keep(shows(pt), Band{padding(), x, y, w, pt, pt, says_across(pt)},
    keep(shows(pb), Band{padding(), x, (y + h - pb : F32), w, pb, pb, says_across(pb)},
      keep(shows(pl) && shows(mid), Band{padding(), x, (y + pt : F32), pl, mid, pl, says_along(pl, mid)},
        keep(shows(pr) && shows(mid), Band{padding(), (x + w - pr : F32), (y + pt : F32), pr, mid, pr, says_along(pr, mid)}, Nil{}))))

# The margin of one part, as up to four bands outside its box: top and bottom take the box's width, left and
# right its height. A margin that pulls a part in (below zero) is not drawn.
# x, y, w, h: the part's box. mt, mr, mb, ml: its margin (top, right, bottom, left).
def around(+x: F32, +y: F32, +w: F32, +h: F32, +mt: F32, +mr: F32, +mb: F32, +ml: F32) -> List<&2, Band>:
  keep(shows(mt), Band{margin(), x, (y - mt : F32), w, mt, mt, says_across(mt)},
    keep(shows(mb), Band{margin(), x, (y + h : F32), w, mb, mb, says_across(mb)},
      keep(shows(ml), Band{margin(), (x - ml : F32), y, ml, h, ml, says_along(ml, h)},
        keep(shows(mr), Band{margin(), (x + w : F32), y, mr, h, mr, says_along(mr, h)}, Nil{}))))

def near(+a: F32, +b: F32) -> Bool:
  F32.is_lt((a - b : F32), 1.0) && F32.is_lt((b - a : F32), 1.0)

# The gap between two children that follow each other, when the room between them is the part's own gap
# (room left over by other rules, like a row pushed to its ends, is not a gap and is not drawn).
# ix, iy, iw, ih: the part's box inside its padding. a and b: the two children's boxes, each with its margin. rg, cg: the part's
# row gap and column gap.
def between(+ix: F32, +iy: F32, +iw: F32, +ih: F32, +ax: F32, +ay: F32, +aw: F32, +ah: F32, +bx: F32, +by: F32, +bw: F32, +bh: F32, +rg: F32, +cg: F32) -> List<&2, Band>:
  +dy = (by - ay - ah : F32)
  +dx = (bx - ax - aw : F32)
  +top = F32.min(ay, by)
  +tall = (F32.max((ay + ah : F32), (by + bh : F32)) - top : F32)
  keep(shows(rg) && near(dy, rg), Band{gap(), ix, (ay + ah : F32), iw, dy, dy, says_across(dy)},
    keep(Bool.not(shows(rg) && near(dy, rg)) && shows(cg) && near(dx, cg), Band{gap(), (ax + aw : F32), top, dx, tall, dx, says_along(dx, tall)}, Nil{}))

# ---------- A value's name on the scale ----------
# The token a number of pixels is, or "" when it is none: a space off the scale is said to be so.

def pick_s(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

# name when px is the token's value, or what the rest of the scale answers.
def named(+token: U32, name: String, +px: U32, rest: String) -> String:
  pick_s(U32.is_eq(token, px), name, rest)

def space_name(+px: U32) -> String:
  named(T.space_hairline(), "space_hairline", px, named(T.space_1(), "space_1", px, named(T.space_2(), "space_2", px, named(T.space_3(), "space_3", px, named(T.space_4(), "space_4", px, named(T.space_5(), "space_5", px, named(T.space_6(), "space_6", px, named(T.space_7(), "space_7", px, named(T.space_8(), "space_8", px, "")))))))))

def radius_name(+px: U32) -> String:
  named(T.radius_xs(), "radius_xs", px, named(T.radius_sm(), "radius_sm", px, named(T.radius_md(), "radius_md", px, named(T.radius_lg(), "radius_lg", px, ""))))

# ---------- A pin ----------
# Where a pin sits along one side of its part: part is how far along it was put (0 to 1), kept inside.
def along(+start: F32, +size: F32, +part: F32) -> F32:
  (start + size * F32.clamp(part, 0.0, 1.0) : F32)
