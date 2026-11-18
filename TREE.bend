# Bend-UI tree: a list of file paths as the rows of a tree, and what each key does on a row.
# Pure; panes.js draws the rows and forwards the keys.
#
# A path is its folders and its name, parted by "/" ("game/sprites/hero.png"). Every folder on the way is a
# row of its own; a path that ends in "/" is a folder with nothing in it yet. A folder's path has no "/" at
# its end ("game/sprites"). On each level folders come first, then files, each by name (capitals and small
# letters together).

import Base

# One thing in the tree: its parts ("game", "sprites", "hero.png"), whether it is a folder, and its path.
type Entry is Data:
  Entry{parts: List<&2, String>, folder: Bool, path: String}

# One row. level: 1 at the top. open: an open folder. shown: every folder above it is open.
# pos and size: which one it is among the rows of its folder, and how many they are (for screen readers).
type Row is Data:
  Row{path: String, name: String, level: U32, folder: Bool, open: Bool, shown: Bool, pos: U32, size: U32}

# What a key or a click asks for: "focus" (move to path), "open" or "close" (the folder at path),
# "pick" (the file at path), or "" (nothing).
type Act is Data:
  Act{what: String, path: String}

def pick_s(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_act(c: Bool, a: Act, b: Act) -> Act:
  match c:
    case True{}:
      a
    case False{}:
      b

def has(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      String.eq(h, x) || has(t, x)

# ---------- Paths to entries ----------

def filled(s: String) -> Bool:
  Bool.not(String.is_empty(s))

def parts(path: String) -> List<&2, String>:
  List.filter(~String, ~filled, String.split(path, '/'))

def under(+folder: String, +name: String) -> String:
  pick_s(String.is_empty(folder), name, folder ++ "/" ++ name)

# A path's own entry, after one for each folder on the way to it. done: the parts above, nearest first.
def entries.of(ps: List<&2, String>, +done: List<&2, String>, +above: String, +folder: Bool) -> List<&2, Entry>:
  match ps:
    case Nil{}:
      []
    case +h <> Nil{}:
      [Entry{List.reverse(&2, String, h <> done), folder, under(above, h)}]
    case +h <> t:
      Entry{List.reverse(&2, String, h <> done), True{}, under(above, h)} <> entries.of(t, h <> done, under(above, h), folder)

def entries(paths: List<&2, String>) -> List<&2, Entry>:
  match paths:
    case Nil{}:
      []
    case +p <> t:
      List.append(&2, Entry, entries.of(parts(p), [], "", String.ends_with(p, "/")), entries(t))

# ---------- The order ----------

def is_empty(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      False{}

def by_name(c: Cmp, a: String, b: String) -> Cmp:
  match c:
    case EQ{}:
      String.order(a, b)
    case o:
      o

# Two names on the same level: a folder before a file, then by name.
def rank(+a: String, a_folder: Bool, +b: String, b_folder: Bool) -> Cmp:
  match a_folder b_folder:
    case True{} False{}:
      LT{}
    case False{} True{}:
      GT{}
    case x y:
      by_name(String.order(String.to_lower(a), String.to_lower(b)), a, b)

def decide(c: Cmp, deeper: Unit -> Bool) -> Bool:
  match c:
    case LT{}:
      True{}
    case GT{}:
      False{}
    case EQ{}:
      deeper(Unit{})

# a comes before b (or is b): part by part from the top; a folder comes before what is inside it.
def before.go(a: List<&2, String>, b: List<&2, String>, +af: Bool, +bf: Bool) -> Bool:
  match a b:
    case Nil{} y:
      True{}
    case x Nil{}:
      False{}
    case +ah <> +at +bh <> +bt:
      decide(rank(ah, Bool.not(is_empty(at)) || af, bh, Bool.not(is_empty(bt)) || bf), u => before.go(at, bt, af, bf))

def before(a: Entry, b: Entry) -> Bool:
  match a b:
    case Entry{ap, af, ax} Entry{bp, bf, bx}:
      before.go(ap, bp, af, bf)

def key_of(e: Entry) -> String:
  match e:
    case Entry{ps, folder, path}:
      path ++ pick_s(folder, "/", "")

def keep(yes: Bool, e: Entry, rest: List<&2, Entry>) -> List<&2, Entry>:
  match yes:
    case True{}:
      e <> rest
    case False{}:
      rest

# Sorted entries without the ones that say the same thing twice (a folder named by two of its files).
def uniq(es: List<&2, Entry>, +last: String) -> List<&2, Entry>:
  match es:
    case Nil{}:
      []
    case +h <> t:
      keep(Bool.not(String.eq(key_of(h), last)), h, uniq(t, key_of(h)))

def sorted(paths: List<&2, String>) -> List<&2, Entry>:
  uniq(List.sort(~Entry, ~before, entries(paths)), "")

# ---------- Entries to rows ----------

# Every folder above the last part is open.
def shown(ps: List<&2, String>, +above: String, +open: List<&2, String>) -> Bool:
  match ps:
    case Nil{}:
      True{}
    case h <> Nil{}:
      True{}
    case +h <> t:
      has(open, under(above, h)) && shown(t, under(above, h), open)

def last_of(ps: List<&2, String>, +last: String) -> String:
  match ps:
    case Nil{}:
      last
    case h <> t:
      last_of(t, h)

def row_of(e: Entry, +open: List<&2, String>) -> Row:
  match e:
    case Entry{+ps, +folder, +path}:
      Row{path, last_of(ps, ""), U32.from_nat(List.length(&2, String, ps)), folder, folder && has(open, path), shown(ps, "", open), 0, 0}

def level_of(r: Row) -> U32:
  match r:
    case Row{path, name, level, folder, open, shown, pos, size}:
      level

def pos_of(r: Row) -> U32:
  match r:
    case Row{path, name, level, folder, open, shown, pos, size}:
      pos

def path_of(r: Row) -> String:
  match r:
    case Row{path, name, level, folder, open, shown, pos, size}:
      path

def is_shown(r: Row) -> Bool:
  match r:
    case Row{path, name, level, folder, open, shown, pos, size}:
      shown

# Counting the rows of each folder. counts holds one number per level, the deepest first: going deeper adds
# a level at 0, coming back up drops the deeper ones.
def fit(counts: List<&2, U32>, +have: U32, +level: U32) -> List<&2, U32>:
  List.append(&2, U32, List.replicate(U32, U32.to_nat((level - U32.min(level, have) : U32)), 0),
    List.drop(&2, U32, counts, U32.to_nat((have - U32.min(have, level) : U32))))

def top(counts: List<&2, U32>) -> U32:
  match counts:
    case Nil{}:
      0
    case h <> t:
      h

def one_more(counts: List<&2, U32>) -> List<&2, U32>:
  match counts:
    case Nil{}:
      [1]
    case h <> t:
      (h + 1 : U32) <> t

def pick_u(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# 0 means not known yet: the first row met (the folder's last, since this pass walks backwards) says it.
def known(counts: List<&2, U32>, +n: U32) -> List<&2, U32>:
  match counts:
    case Nil{}:
      [n]
    case +h <> t:
      U32.max(h, pick_u(U32.is_eq(h, 0), n, 0)) <> t

def with_pos(r: Row, +n: U32) -> Row:
  match r:
    case Row{path, name, level, folder, open, shown, pos, size}:
      Row{path, name, level, folder, open, shown, n, size}

def with_size(r: Row, +n: U32) -> Row:
  match r:
    case Row{path, name, level, folder, open, shown, pos, size}:
      Row{path, name, level, folder, open, shown, pos, n}

# Forwards: each row's place among the rows of its folder. The rows come out last first.
def number.go(rows: List<&2, Row>, +counts: List<&2, U32>, +have: U32, out: List<&2, Row>) -> List<&2, Row>:
  match rows:
    case Nil{}:
      out
    case +h <> t:
      number.go(t, one_more(fit(counts, have, level_of(h))), level_of(h),
        with_pos(h, top(one_more(fit(counts, have, level_of(h))))) <> out)

# Backwards: how many rows its folder has. The rows come out first first again.
def count.go(rows: List<&2, Row>, +counts: List<&2, U32>, +have: U32, out: List<&2, Row>) -> List<&2, Row>:
  match rows:
    case Nil{}:
      out
    case +h <> t:
      count.go(t, known(fit(counts, have, level_of(h)), pos_of(h)), level_of(h),
        with_size(h, top(known(fit(counts, have, level_of(h)), pos_of(h)))) <> out)

def rows.of(es: List<&2, Entry>, +open: List<&2, String>) -> List<&2, Row>:
  match es:
    case Nil{}:
      []
    case h <> t:
      row_of(h, open) <> rows.of(t, open)

# Every row of the tree, in order: paths are the files (and empty folders), open the folders that are open.
# A row inside a closed folder is there too, with shown False: the screen keeps it hidden.
def rows(paths: List<&2, String>, +open: List<&2, String>) -> List<&2, Row>:
  count.go(number.go(rows.of(sorted(paths), open), [], 0, []), [], 0, [])

def only_shown(rows: List<&2, Row>) -> List<&2, Row>:
  List.filter(~Row, ~is_shown, rows)

# ---------- Open folders ----------

def put_if(yes: Bool, x: String, rest: List<&2, String>) -> List<&2, String>:
  match yes:
    case True{}:
      x <> rest
    case False{}:
      rest

def without(xs: List<&2, String>, +x: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case +h <> t:
      put_if(Bool.not(String.eq(h, x)), h, without(t, x))

# The open folders after one opens or closes.
def opened(open: List<&2, String>, +path: String) -> List<&2, String>:
  path <> without(open, path)

def closed(open: List<&2, String>, +path: String) -> List<&2, String>:
  without(open, path)

# ---------- Keys ----------

def nothing() -> Act:
  Act{"", ""}

def focus(+path: String) -> Act:
  pick_act(String.is_empty(path), nothing(), Act{"focus", path})

def first(rows: List<&2, Row>) -> String:
  match rows:
    case Nil{}:
      ""
    case h <> t:
      path_of(h)

def last(rows: List<&2, Row>, seen: String) -> String:
  match rows:
    case Nil{}:
      seen
    case h <> t:
      last(t, path_of(h))

# The row after the one at path ("" when it is the last, or not there).
def next(rows: List<&2, Row>, +path: String) -> String:
  match rows:
    case Nil{}:
      ""
    case h <> +t:
      pick_s(String.eq(path_of(h), path), first(t), next(t, path))

def prev(rows: List<&2, Row>, +path: String, +last: String) -> String:
  match rows:
    case Nil{}:
      ""
    case +h <> t:
      pick_s(String.eq(path_of(h), path), last, prev(t, path, path_of(h)))

def blank() -> Row:
  Row{"", "", 0, False{}, False{}, False{}, 0, 0}

def pick_row(c: Bool, a: Row, b: Row) -> Row:
  match c:
    case True{}:
      a
    case False{}:
      b

def find(rows: List<&2, Row>, +path: String) -> Row:
  match rows:
    case Nil{}:
      blank()
    case +h <> t:
      pick_row(String.eq(path_of(h), path), h, find(t, path))

# The first row inside the folder at path: the row right after it, when that one is deeper.
def kid(rows: List<&2, Row>, +path: String, +level: U32) -> String:
  match rows:
    case Nil{}:
      ""
    case h <> +t:
      pick_s(String.eq(path_of(h), path), pick_s(U32.is_gt(level_of(find(t, first(t))), level), first(t), ""), kid(t, path, level))

def drop_last(ps: List<&2, String>) -> List<&2, String>:
  match ps:
    case Nil{}:
      []
    case h <> Nil{}:
      []
    case h <> t:
      h <> drop_last(t)

# The folder a path is in ("" at the top).
def parent(path: String) -> String:
  String.join(drop_last(parts(path)), "/")

# Enter, Space or a click: a folder opens or closes, a file is picked.
def press.on(r: Row) -> Act:
  match r:
    case Row{+path, name, level, folder, open, shown, pos, size}:
      match folder open:
        case True{} True{}:
          Act{"close", path}
        case True{} False{}:
          Act{"open", path}
        case False{} o:
          pick_act(String.is_empty(path), nothing(), Act{"pick", path})

def press(rows: List<&2, Row>, +path: String) -> Act:
  press.on(find(rows, path))

# Right: a closed folder opens; an open one sends the focus to its first row; a file stays.
def right(r: Row, rows: List<&2, Row>) -> Act:
  match r:
    case Row{+path, name, +level, folder, open, shown, pos, size}:
      match folder open:
        case True{} True{}:
          focus(kid(rows, path, level))
        case True{} False{}:
          Act{"open", path}
        case False{} o:
          nothing()

# Left: an open folder closes; anything else sends the focus to the folder it is in.
def left(r: Row) -> Act:
  match r:
    case Row{+path, name, level, folder, open, shown, pos, size}:
      match folder open:
        case True{} True{}:
          Act{"close", path}
        case f o:
          focus(parent(path))

# The keys the tree answers to (so the page does not scroll under them).
def takes(+key: String) -> Bool:
  has(["ArrowDown", "ArrowUp", "ArrowRight", "ArrowLeft", "Home", "End", "Enter", " "], key)

def key.on(+rows: List<&2, Row>, +path: String, +key: String) -> Act:
  pick_act(String.eq(key, "ArrowDown"), focus(next(rows, path)),
  pick_act(String.eq(key, "ArrowUp"), focus(prev(rows, path, "")),
  pick_act(String.eq(key, "Home"), focus(first(rows)),
  pick_act(String.eq(key, "End"), focus(last(rows, "")),
  pick_act(String.eq(key, "ArrowRight"), right(find(rows, path), rows),
  pick_act(String.eq(key, "ArrowLeft"), left(find(rows, path)),
  pick_act(String.eq(key, "Enter") || String.eq(key, " "), press(rows, path), nothing())))))))

# What a key does on the row at path (the WAI-ARIA tree's keys). rows is what rows() gave; only the rows
# that show take part. Down and Up go to the next and the previous row, Home and End to the first and the
# last, Right and Left open, close and step in and out of a folder, Enter and Space press the row.
def key(rows: List<&2, Row>, +path: String, +key: String) -> Act:
  key.on(only_shown(rows), path, key)

# The one row Tab reaches (the others are reached with the arrows): the row that had the focus, else the
# current file, else the first row; always one that shows.
def tab_stop.on(+rows: List<&2, Row>, +active: String, +current: String) -> String:
  pick_s(filled(path_of(find(rows, active))), active,
  pick_s(filled(path_of(find(rows, current))), current, first(rows)))

def tab_stop(rows: List<&2, Row>, +active: String, +current: String) -> String:
  tab_stop.on(only_shown(rows), active, current)
