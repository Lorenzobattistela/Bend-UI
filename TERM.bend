# Bend-UI terminal: folds raw terminal output into lines of pieces, and says what a key sends.
# Pure; panes.js only draws what comes back and reports what is typed. The lib runs nothing: the app feeds
# it a process's output (feed) and gets the bytes a terminal would send (sent, pasted).
#
# What feed reads:
#   text       written at the cursor, over what was there
#   \n         ends the line; the next one starts at its first column
#   \r         back to the line's first column (what comes next writes over the line)
#   \b         one column back
#   \t         on to the next tab stop (every tab() columns)
#   ESC [ … m  colors (SGR): 0 reset, 1 bold, 2 dim, 22 neither, 30-37 and 90-97 the eight colors and their
#              bright ones, 39 the default color, 38;5;0-15 the same sixteen
#   ESC [ K    erases in the line (0 from the cursor on, 1 up to the cursor, 2 all of it)
#   ESC [ 2 J  and ESC [ 3 J clear the screen
# Every other escape sequence (CSI, OSC, DCS, a charset) is read to its end and dropped: nothing of it prints.
#
# A style is one number: the color (0 the default; 1-8 black, red, green, yellow, blue, magenta, cyan, white;
# 9-16 their bright ones) + 32 when bold + 64 when dim. class_of names it for the CSS.

import Base

# How many finished lines the screen keeps. Undecided.
def scrollback() -> U32: 1000

# Tab stops are this many columns apart.
def tab() -> U32: 8

# What a screen reader hears of new output: at most this many lines at a time, the newest ones (undecided),
# said once the output has been still for say_wait_ms (undecided).
def say_lines() -> U32: 8
def say_wait_ms() -> U32: 400

type Piece is Data:
  Piece{style: U32, text: String}

type Line is Data:
  Line{pieces: List<&2, Piece>}

type Cell is Data:
  Cell{style: U32, char: Char}

# The finished lines, newest first. kept: how many are held. total: how many were ever finished.
# clears: how many times the screen was cleared.
type Page is Data:
  Page{lines: List<&2, Line>, kept: U32, total: U32, clears: U32}

# The line being written, split at the cursor: left is what is before it (nearest first), right is what
# is under and after it. col is the cursor's column.
type Row is Data:
  Row{left: List<&2, Cell>, right: List<&2, Cell>, col: U32}

# What the reader is in the middle of. mode: 0 text, 1 after ESC, 2 in a CSI (ESC [), 3 in a string
# (OSC, DCS: until BEL or ESC \), 4 one more character to drop, 5 in a CSI that is dropped.
# args: the CSI's numbers so far, last first.
type Pen is Data:
  Pen{style: U32, mode: U32, args: List<&2, U32>}

type Screen is Data:
  Screen{page: Page, row: Row, pen: Pen}

def new() -> Screen:
  Screen{Page{[], 0, 0, 0}, Row{[], [], 0}, Pen{0, 0, []}}

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

def within(+k: U32, +lo: U32, +hi: U32) -> Bool:
  U32.is_ge(k, lo) && U32.is_le(k, hi)

# ---------- Styles ----------

def color_of(+style: U32) -> U32:
  (style .&. 31 : U32)

def is_bold(+style: U32) -> Bool:
  Bool.not(U32.is_eq((style .&. 32 : U32), 0))

def is_dim(+style: U32) -> Bool:
  Bool.not(U32.is_eq((style .&. 64 : U32), 0))

def with_color(+style: U32, +color: U32) -> U32:
  ((style .&. 96 : U32) + color : U32)

def color_name(+c: U32) -> String:
  pick_s(U32.is_eq(c, 1) || U32.is_eq(c, 9), " term__black",
  pick_s(U32.is_eq(c, 2) || U32.is_eq(c, 10), " term__red",
  pick_s(U32.is_eq(c, 3) || U32.is_eq(c, 11), " term__green",
  pick_s(U32.is_eq(c, 4) || U32.is_eq(c, 12), " term__yellow",
  pick_s(U32.is_eq(c, 5) || U32.is_eq(c, 13), " term__blue",
  pick_s(U32.is_eq(c, 6) || U32.is_eq(c, 14), " term__magenta",
  pick_s(U32.is_eq(c, 7) || U32.is_eq(c, 15), " term__cyan",
  pick_s(U32.is_eq(c, 8) || U32.is_eq(c, 16), " term__white", ""))))))))

# The classes that draw a style ("" for plain text). A bright color is drawn as its plain one.
def class_of(+style: U32) -> String:
  String.trim(pick_s(is_bold(style), " term__bold", "") ++ pick_s(is_dim(style), " term__dim", "") ++ color_name(color_of(style)))

# One SGR number changes the style.
def sgr_one(+n: U32, +style: U32) -> U32:
  pick(U32.is_eq(n, 0), 0,
  pick(U32.is_eq(n, 1), (style .|. 32 : U32),
  pick(U32.is_eq(n, 2), (style .|. 64 : U32),
  pick(U32.is_eq(n, 22), (style .&. 31 : U32),
  pick(within(n, 30, 37), with_color(style, (n - 29 : U32)),
  pick(U32.is_eq(n, 39), with_color(style, 0),
  pick(within(n, 90, 97), with_color(style, (n - 81 : U32)), style)))))))

# 38 and 48 (a color from a palette, or by its red, green and blue) take the numbers after them:
# 5;n or 2;r;g;b. wait says what the next number is: 0 an SGR number, 1 what follows 38, 2 what follows 48,
# 3 a palette color for the text, 4 a number to drop, 5-7 three, two, one numbers to drop.
def sgr_wait(+wait: U32, +n: U32) -> U32:
  pick(U32.is_eq(wait, 0), pick(U32.is_eq(n, 38), 1, pick(U32.is_eq(n, 48), 2, 0)),
  pick(U32.is_eq(wait, 1), pick(U32.is_eq(n, 5), 3, pick(U32.is_eq(n, 2), 5, 0)),
  pick(U32.is_eq(wait, 2), pick(U32.is_eq(n, 5), 4, pick(U32.is_eq(n, 2), 5, 0)),
  pick(U32.is_eq(wait, 5), 6,
  pick(U32.is_eq(wait, 6), 7, 0)))))

def sgr_style(+wait: U32, +n: U32, +style: U32) -> U32:
  pick(U32.is_eq(wait, 0), sgr_one(n, style),
  pick(U32.is_eq(wait, 3) && U32.is_lt(n, 16), with_color(style, (n + 1 : U32)), style))

# A whole SGR sequence's numbers, in order.
def sgr(args: List<&2, U32>, +wait: U32, +style: U32) -> U32:
  match args:
    case Nil{}:
      style
    case +n <> t:
      sgr(t, sgr_wait(wait, n), sgr_style(wait, n, style))

# ---------- The line being written ----------

def cells(row: Row) -> List<&2, Cell>:
  match row:
    case Row{left, right, col}:
      List.reverse.go(&2, Cell, left, right)

# A character goes where the cursor is, over what was there.
def put(row: Row, cell: Cell) -> Row:
  match row:
    case Row{left, right, col}:
      Row{cell <> left, List.tail(&2, Cell, right), (col + 1 : U32)}

def home(row: Row) -> Row:
  Row{[], cells(row), 0}

def back(row: Row) -> Row:
  match row:
    case Row{Nil{}, right, col}:
      Row{[], right, 0}
    case Row{h <> t, right, col}:
      Row{t, h <> right, (col - 1 : U32)}

# The cursor goes n columns on, over what is there, leaving spaces where there was nothing.
def forward(n: Nat, row: Row) -> Row:
  match n row:
    case 0n r:
      r
    case 1n+p Row{left, Nil{}, col}:
      forward(p, Row{Cell{0, ' '} <> left, [], (col + 1 : U32)})
    case 1n+p Row{left, h <> t, col}:
      forward(p, Row{h <> left, t, (col + 1 : U32)})

def to_tab(row: Row) -> Row:
  match row:
    case Row{left, right, +col}:
      forward(U32.to_nat((tab() - (col % tab() : U32) : U32)), Row{left, right, col})

def spaces.go(n: Nat, acc: List<&2, Cell>) -> List<&2, Cell>:
  match n:
    case 0n:
      acc
    case 1n+p:
      spaces.go(p, Cell{0, ' '} <> acc)

def spaces(n: Nat) -> List<&2, Cell>:
  spaces.go(n, [])

# ESC [ n K: 0 erases from the cursor on, 1 up to and under the cursor, 2 the whole line. The cursor stays.
def erase.at(n: U32, left: List<&2, Cell>, right: List<&2, Cell>, +col: U32) -> Row:
  match n:
    case 0:
      Row{left, [], col}
    case 1:
      Row{spaces(U32.to_nat(col)), Cell{0, ' '} <> List.tail(&2, Cell, right), col}
    case 2:
      Row{spaces(U32.to_nat(col)), [], col}
    case k:
      Row{left, right, col}

def erase(n: U32, row: Row) -> Row:
  match row:
    case Row{left, right, col}:
      erase.at(n, left, right, col)

# ---------- Cells to pieces: a run of cells in one style is one piece ----------

type Run is Data:
  Run{style: U32, text: String, out: List<&2, Piece>}

def run_out(empty: Bool, +style: U32, text: String, out: List<&2, Piece>) -> List<&2, Piece>:
  match empty:
    case True{}:
      out
    case False{}:
      Piece{style, String.reverse(text)} <> out

def run_end(run: Run) -> List<&2, Piece>:
  match run:
    case Run{+style, +text, out}:
      run_out(String.is_empty(text), style, text, out)

def run_add(same: Bool, cell: Cell, run: Run) -> Run:
  match same cell run:
    case True{} Cell{s, c} Run{style, text, out}:
      Run{style, SCon{c, text}, out}
    case False{} Cell{s, c} r:
      Run{s, SCon{c, SNil{}}, run_end(r)}

def run_step(cell: Cell, run: Run) -> Run:
  match cell run:
    case Cell{+s, c} Run{+style, text, out}:
      run_add(U32.is_eq(s, style), Cell{s, c}, Run{style, text, out})

def pieces.go(cs: List<&2, Cell>, run: Run) -> List<&2, Piece>:
  match cs:
    case Nil{}:
      List.reverse(&2, Piece, run_end(run))
    case h <> t:
      pieces.go(t, run_step(h, run))

def pieces(cs: List<&2, Cell>) -> List<&2, Piece>:
  pieces.go(cs, Run{0, "", []})

# ---------- The finished lines ----------

# Past twice the scrollback, the oldest lines go and the scrollback's worth stays (so a line costs one step,
# not a walk through all of them).
def trim(over: Bool, page: Page) -> Page:
  match over page:
    case False{} p:
      p
    case True{} Page{lines, kept, total, clears}:
      Page{List.take(&2, Line, lines, U32.to_nat(scrollback())), scrollback(), total, clears}

def push(page: Page, line: Line) -> Page:
  match page:
    case Page{lines, +kept, total, clears}:
      trim(U32.is_ge(kept, (scrollback() * 2 : U32)), Page{line <> lines, (kept + 1 : U32), (total + 1 : U32), clears})

def wiped(page: Page) -> Page:
  match page:
    case Page{lines, kept, total, clears}:
      Page{[], 0, total, (clears + 1 : U32)}

# ---------- Reading, a character at a time ----------

# What a character is, as text: 0 it prints, 1 \n, 2 \r, 3 \b, 4 \t, 5 ESC, 6 nothing (the other controls).
def kind(+k: U32) -> U32:
  pick(U32.is_eq(k, 10), 1,
  pick(U32.is_eq(k, 13), 2,
  pick(U32.is_eq(k, 8), 3,
  pick(U32.is_eq(k, 9), 4,
  pick(U32.is_eq(k, 27), 5,
  pick(U32.is_lt(k, 32) || within(k, 127, 159), 6, 0))))))

def text(what: U32, +c: Char, page: Page, row: Row, +style: U32) -> Screen:
  match what:
    case 0:
      Screen{page, put(row, Cell{style, c}), Pen{style, 0, []}}
    case 1:
      Screen{push(page, Line{pieces(cells(row))}), Row{[], [], 0}, Pen{style, 0, []}}
    case 2:
      Screen{page, home(row), Pen{style, 0, []}}
    case 3:
      Screen{page, back(row), Pen{style, 0, []}}
    case 4:
      Screen{page, to_tab(row), Pen{style, 0, []}}
    case 5:
      Screen{page, row, Pen{style, 1, []}}
    case n:
      Screen{page, row, Pen{style, 0, []}}

# After ESC: [ opens a CSI; ] P X ^ _ open a string; ( ) * + # % and a space take one more character;
# a second ESC starts over; anything else was a two-character sequence, and is dropped.
def escape(+k: U32) -> U32:
  pick(U32.is_eq(k, 91), 2,
  pick(U32.is_eq(k, 93) || U32.is_eq(k, 80) || U32.is_eq(k, 88) || U32.is_eq(k, 94) || U32.is_eq(k, 95), 3,
  pick(U32.is_eq(k, 32) || U32.is_eq(k, 35) || U32.is_eq(k, 37) || within(k, 40, 43), 4,
  pick(U32.is_eq(k, 27), 1, 0))))

# Inside a CSI: 0 a digit, 1 a ;, 2 its last character, 3 ESC, 4 a mark that makes it one we drop, 5 nothing.
def csi_kind(+k: U32) -> U32:
  pick(within(k, 48, 57), 0,
  pick(U32.is_eq(k, 59), 1,
  pick(within(k, 64, 126), 2,
  pick(U32.is_eq(k, 27), 3,
  pick(within(k, 32, 47) || within(k, 58, 63), 4, 5)))))

def digit(args: List<&2, U32>, +d: U32) -> List<&2, U32>:
  match args:
    case Nil{}:
      [d]
    case h <> t:
      (h * 10 + d : U32) <> t

def first(args: List<&2, U32>) -> U32:
  match args:
    case Nil{}:
      0
    case h <> t:
      h

def clear_if(yes: Bool, page: Page, row: Row, +style: U32) -> Screen:
  match yes:
    case True{}:
      Screen{wiped(page), Row{[], [], 0}, Pen{style, 0, []}}
    case False{}:
      Screen{page, row, Pen{style, 0, []}}

# A CSI ends: m colors, K erases in the line, 2 J and 3 J clear the screen; the others do nothing.
def csi_end(+k: U32, page: Page, row: Row, +style: U32, +args: List<&2, U32>) -> Screen:
  match k:
    case 109:
      Screen{page, row, Pen{sgr(List.reverse(&2, U32, args), 0, style), 0, []}}
    case 75:
      Screen{page, erase(first(args), row), Pen{style, 0, []}}
    case 74:
      clear_if(within(first(args), 2, 3), page, row, style)
    case n:
      Screen{page, row, Pen{style, 0, []}}

def csi(what: U32, +k: U32, page: Page, row: Row, +style: U32, +args: List<&2, U32>) -> Screen:
  match what:
    case 0:
      Screen{page, row, Pen{style, 2, digit(args, (k - 48 : U32))}}
    case 1:
      Screen{page, row, Pen{style, 2, 0 <> args}}
    case 2:
      csi_end(k, page, row, style, args)
    case 3:
      Screen{page, row, Pen{style, 1, []}}
    case 4:
      Screen{page, row, Pen{style, 5, []}}
    case n:
      Screen{page, row, Pen{style, 2, args}}

# A dropped CSI ends at its last character; a string ends at BEL, or at ESC (whose next character ends it).
def dropped_csi(+k: U32) -> U32:
  pick(within(k, 64, 126), 0, pick(U32.is_eq(k, 27), 1, 5))

def string(+k: U32) -> U32:
  pick(U32.is_eq(k, 7), 0, pick(U32.is_eq(k, 27), 1, 3))

# A CSI starts with one number, 0, so ESC [ m is ESC [ 0 m.
def pick_args(csi: Bool) -> List<&2, U32>:
  match csi:
    case True{}:
      [0]
    case False{}:
      []

def step.at(mode: U32, +c: Char, page: Page, row: Row, +style: U32, +args: List<&2, U32>) -> Screen:
  match mode:
    case 0:
      text(kind(Char.to_u32(c)), c, page, row, style)
    case 1:
      Screen{page, row, Pen{style, escape(Char.to_u32(c)), pick_args(U32.is_eq(Char.to_u32(c), 91))}}
    case 2:
      csi(csi_kind(Char.to_u32(c)), Char.to_u32(c), page, row, style, args)
    case 3:
      Screen{page, row, Pen{style, string(Char.to_u32(c)), []}}
    case 4:
      Screen{page, row, Pen{style, 0, []}}
    case n:
      Screen{page, row, Pen{style, dropped_csi(Char.to_u32(c)), []}}

def step(+c: Char, screen: Screen) -> Screen:
  match screen:
    case Screen{page, row, Pen{style, mode, args}}:
      step.at(mode, c, page, row, style, args)

# One pass, a character at a time (tail calls: the output may be long).
def scan(s: String, screen: Screen) -> Screen:
  match s:
    case SNil{}:
      screen
    case SCon{+h, t}:
      scan(t, step(h, screen))

# The screen after more output.
def feed(screen: Screen, text: String) -> Screen:
  scan(text, screen)

# The screen with nothing on it (the terminal's own clear()).
def cleared(screen: Screen) -> Screen:
  match screen:
    case Screen{page, row, pen}:
      Screen{wiped(page), Row{[], [], 0}, Pen{0, 0, []}}

# ---------- What to draw ----------

def total(screen: Screen) -> U32:
  match screen:
    case Screen{Page{lines, kept, total, clears}, row, pen}:
      total

def clears(screen: Screen) -> U32:
  match screen:
    case Screen{Page{lines, kept, total, clears}, row, pen}:
      clears

# The lines finished after the first `seen` ones, oldest first: what a screen that has drawn `seen` lines
# has to add. Never more than the scrollback; older ones are gone.
def fresh(screen: Screen, +seen: U32) -> List<&2, Line>:
  match screen:
    case Screen{Page{lines, +kept, +total, clears}, row, pen}:
      List.reverse(&2, Line, List.take(&2, Line, lines,
        U32.to_nat(U32.min((total - U32.min(seen, total) : U32), U32.min(kept, scrollback())))))

# Every line the screen keeps, oldest first.
def lines(screen: Screen) -> List<&2, Line>:
  fresh(screen, 0)

# The line being written, around the cursor: what is before it, the character under it (a space when
# there is none), and what is after it.
def before(screen: Screen) -> List<&2, Piece>:
  match screen:
    case Screen{page, Row{left, right, col}, pen}:
      pieces(List.reverse(&2, Cell, left))

def under.of(right: List<&2, Cell>) -> Piece:
  match right:
    case Nil{}:
      Piece{0, " "}
    case Cell{s, c} <> t:
      Piece{s, SCon{c, SNil{}}}

def under(screen: Screen) -> Piece:
  match screen:
    case Screen{page, Row{left, right, col}, pen}:
      under.of(right)

def after(screen: Screen) -> List<&2, Piece>:
  match screen:
    case Screen{page, Row{left, right, col}, pen}:
      pieces(List.tail(&2, Cell, right))

# ---------- What to say ----------

def line_text.go(ps: List<&2, Piece>, acc: String) -> String:
  match ps:
    case Nil{}:
      acc
    case Piece{s, t} <> rest:
      line_text.go(rest, acc ++ t)

# A line's words, without its colors.
def line_text(line: Line) -> String:
  match line:
    case Line{ps}:
      line_text.go(ps, "")

def said.go(ls: List<&2, Line>, +acc: String) -> String:
  match ls:
    case Nil{}:
      acc
    case h <> t:
      said.go(t, pick_s(String.is_empty(acc), "", acc ++ "\n") ++ line_text(h))

# What a screen reader hears: the lines finished after the first `seen` ones, as plain text, at most the
# newest say_lines of them.
def said(screen: Screen, +seen: U32) -> String:
  match screen:
    case Screen{Page{lines, +kept, +total, clears}, row, pen}:
      said.go(List.reverse(&2, Line, List.take(&2, Line, lines,
        U32.to_nat(U32.min((total - U32.min(seen, total) : U32), U32.min(kept, say_lines()))))), "")

# ---------- What is typed ----------

# A letter held with Ctrl sends its control character (Ctrl+C is 3, Ctrl+D 4, Ctrl+L 12).
def control(+k: U32) -> String:
  pick_s(within(k, 97, 122), SCon{Char.from_u32((k - 96 : U32)), SNil{}},
  pick_s(within(k, 65, 90), SCon{Char.from_u32((k - 64 : U32)), SNil{}}, ""))

def named(+key: String, shift: Bool, after_escape: Bool) -> String:
  pick_s(String.eq(key, "Enter"), "\r",
  pick_s(String.eq(key, "Backspace"), "\u{7f}",
  pick_s(String.eq(key, "Tab"), pick_s(shift || after_escape, "", "\t"),
  pick_s(String.eq(key, "Escape"), "\u{1b}",
  pick_s(String.eq(key, "ArrowUp"), "\u{1b}[A",
  pick_s(String.eq(key, "ArrowDown"), "\u{1b}[B",
  pick_s(String.eq(key, "ArrowRight"), "\u{1b}[C",
  pick_s(String.eq(key, "ArrowLeft"), "\u{1b}[D",
  pick_s(String.eq(key, "Home"), "\u{1b}[H",
  pick_s(String.eq(key, "End"), "\u{1b}[F",
  pick_s(String.eq(key, "Delete"), "\u{1b}[3~", "")))))))))))

def one_char(+key: String, ctrl: Bool, alt: Bool, shift: Bool, +k: U32) -> String:
  match ctrl alt:
    case True{} False{}:
      pick_s(shift || U32.is_eq(k, 118) || U32.is_eq(k, 86), "", control(k))
    case c a:
      key

def sent.at(+key: String, ctrl: Bool, alt: Bool, shift: Bool, after_escape: Bool) -> String:
  match key:
    case SCon{h, SNil{}}:
      one_char(key, ctrl, alt, shift, Char.to_u32(h))
    case other:
      named(key, shift, after_escape)

# What a key sends, as a terminal would ("" when it sends nothing, and the key stays the browser's).
# key is the keyboard event's key. A character sends itself; with Ctrl (and no Alt) a letter sends its control
# character, except V (paste stays the browser's) and with Shift. Enter is \r, Backspace DEL, the arrows
# ESC [ A to D. Tab is \t, but Shift+Tab, and Tab right after Escape, send nothing: they move the focus on,
# so the keyboard is never held inside the terminal. With ⌘ held nothing is sent.
def sent(+key: String, ctrl: Bool, alt: Bool, meta: Bool, shift: Bool, after_escape: Bool) -> String:
  match meta:
    case True{}:
      ""
    case False{}:
      sent.at(key, ctrl, alt, shift, after_escape)

def pasted.char(k: U32, h: Char) -> Char:
  match k:
    case 10:
      '\r'
    case n:
      h

def pasted.put(skip: Bool, c: Char, acc: String) -> String:
  match skip:
    case True{}:
      acc
    case False{}:
      SCon{c, acc}

# cr: the character before was a \r, so a \n right after it is the same line break.
def pasted.go(s: String, acc: String, cr: Bool) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{+h, t}:
      pasted.go(t, pasted.put(cr && Char.is_eq(h, '\n'), pasted.char(Char.to_u32(h), h), acc), Char.is_eq(h, '\r'))

# Pasted text as a terminal sends it: each line break (\n, \r\n) is one \r.
def pasted(text: String) -> String:
  pasted.go(text, "", False{})
