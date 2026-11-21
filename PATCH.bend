# Patch: what to do to the page so the last view becomes the next one. The comparison is here, in
# Bend; web.js only carries each instruction out.
#
# A node is compared with the node at the same place. The same tag: its attributes are compared
# (what went away, what is new or holds another text) and its children, place by place. Another tag,
# or a text where a node was: the node is made again. A message is never compared (a message can be
# any type), so an event or a clock is always set again, which costs the driver one assignment.
#
# Limits now:
# - Place by place, with no keys (see Web.bend).
# - A list's nodes are walked one call deep each: a browser's stack ends between 3,000 and 6,000
#   children of one node (measured in Chromium: 1,000 children compare in 9 ms, 3,000 in 27 ms).

import Base
import ./Web.bend as Web

type Patch<-Ev: Data> is Data:
  keep{}                          # this text is the same
  retext{value: String}           # this text now says value
  swap{node: Web.HTML<Ev>}        # make this node again
  # Same tag: take `dels` off, put `sets` on, patch the children both views have, then take `cut`
  # children off the end or add `adds` there.
  edit{dels: List<&2, Web.Attr<Ev>>, sets: List<&2, Web.Attr<Ev>>, kids: List<&2, Patch<Ev>>, cut: Nat, adds: List<&2, Web.HTML<Ev>>}

def pick(-A: Data, c: Bool, +a: A, +b: A) -> A:
  match c:
    case True{}:
      a
    case False{}:
      b

def same_event(-Ev: Data, +a: Web.DomEvent<Ev>, +b: Web.DomEvent<Ev>) -> Bool:
  match a b:
    case Web.click{_} Web.click{_}:
      True{}
    case Web.double_click{_} Web.double_click{_}:
      True{}
    case Web.input{_} Web.input{_}:
      True{}
    case Web.change{_} Web.change{_}:
      True{}
    case Web.key_down{_} Web.key_down{_}:
      True{}
    case Web.pointer_down{_} Web.pointer_down{_}:
      True{}
    case Web.pointer_move{_} Web.pointer_move{_}:
      True{}
    case Web.pointer_up{_} Web.pointer_up{_}:
      True{}
    case _ _:
      False{}

# The same slot of a node: the same kind of attribute with the same name, the same event, or a clock
# of the same interval.
def same_slot(-Ev: Data, +a: Web.Attr<Ev>, +b: Web.Attr<Ev>) -> Bool:
  match a b:
    case Web.attr{n, _} Web.attr{m, _}:
      String.eq(n, m)
    case Web.prop{n, _} Web.prop{m, _}:
      String.eq(n, m)
    case Web.style{n, _} Web.style{m, _}:
      String.eq(n, m)
    case Web.on{e} Web.on{f}:
      same_event(Ev, e, f)
    case Web.every_ms{s, _} Web.every_ms{t, _}:
      U32.is_eq(s, t)
    case _ _:
      False{}

# The same slot holding the same text. False for an event or a clock: those are always set again.
def same_value(-Ev: Data, +a: Web.Attr<Ev>, +b: Web.Attr<Ev>) -> Bool:
  match a b:
    case Web.attr{n, v} Web.attr{m, w}:
      String.eq(n, m) && String.eq(v, w)
    case Web.prop{n, v} Web.prop{m, w}:
      String.eq(n, m) && String.eq(v, w)
    case Web.style{n, v} Web.style{m, w}:
      String.eq(n, m) && String.eq(v, w)
    case _ _:
      False{}

def has_slot(-Ev: Data, +xs: List<&2, Web.Attr<Ev>>, +a: Web.Attr<Ev>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      same_slot(Ev, h, a) || has_slot(Ev, t, a)

def has_value(-Ev: Data, +xs: List<&2, Web.Attr<Ev>>, +a: Web.Attr<Ev>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      same_value(Ev, h, a) || has_value(Ev, t, a)

def put(-A: Data, keep: Bool, +h: A, +t: List<&2, A>) -> List<&2, A>:
  match keep:
    case True{}:
      h <> t
    case False{}:
      t

# What was on the node and is not any more.
def dels(-Ev: Data, +prev: List<&2, Web.Attr<Ev>>, +next: List<&2, Web.Attr<Ev>>) -> List<&2, Web.Attr<Ev>>:
  match prev:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      put(Web.Attr<Ev>, Bool.not(has_slot(Ev, next, h)), h, dels(Ev, t, next))

# What is new on the node, or holds another text.
def sets(-Ev: Data, +next: List<&2, Web.Attr<Ev>>, +prev: List<&2, Web.Attr<Ev>>) -> List<&2, Web.Attr<Ev>>:
  match next:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      put(Web.Attr<Ev>, Bool.not(has_value(Ev, prev, h)), h, sets(Ev, t, prev))

# How many children the last view has past the end of the next one.
def cut(-Ev: Data, +a: List<&2, Web.HTML<Ev>>, +b: List<&2, Web.HTML<Ev>>) -> Nat:
  match a b:
    case Con{_, t} Con{_, u}:
      cut(Ev, t, u)
    case Con{_, t} Nil{}:
      1n+cut(Ev, t, Nil{})
    case Nil{} _:
      0n

# The children the next view has past the end of the last one.
def adds(-Ev: Data, +a: List<&2, Web.HTML<Ev>>, +b: List<&2, Web.HTML<Ev>>) -> List<&2, Web.HTML<Ev>>:
  match a b:
    case Con{_, t} Con{_, u}:
      adds(Ev, t, u)
    case Nil{} _:
      b
    case Con{_, _} Nil{}:
      Nil{}

# The patches of the nodes two lists have in common, place by place.
def patches(-Ev: Data, +a: List<&2, Web.HTML<Ev>>, +b: List<&2, Web.HTML<Ev>>) -> List<&2, Patch<Ev>>:
  match a b:
    case Con{Web.text{v}, t} Con{Web.text{w}, u}:
      pick(Patch<Ev>, String.eq(v, w), keep{}, retext{w}) <> patches(Ev, t, u)
    case Con{Web.node{g, at, ks}, t} Con{Web.node{h, bt, ls}, u}:
      pick(Patch<Ev>, String.eq(g, h), edit{dels(Ev, at, bt), sets(Ev, bt, at), patches(Ev, ks, ls), cut(Ev, ks, ls), adds(Ev, ks, ls)}, swap{Web.node{h, bt, ls}}) <> patches(Ev, t, u)
    case Con{_, t} Con{n, u}:
      swap{n} <> patches(Ev, t, u)
    case _ _:
      Nil{}

# The patch that turns one view into another.
def diff(-Ev: Data, +prev: Web.HTML<Ev>, +next: Web.HTML<Ev>) -> List<&2, Patch<Ev>>:
  patches(Ev, [prev], [next])
