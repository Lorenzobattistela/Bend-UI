# Web: a page as a Bend value. `render(state)` gives the whole screen as a tree of `HTML`, and the
# driver (web.js) puts it in the browser, sends each event back and draws the next screen.
#
# The vocabulary is Lorenzo Battistela's, from DungeonBend's port to the new Bend (branch
# port/bend-new, src/Web.bend): `HTML`, `Attr`, `Cmd`, `Update` and the first two events are his,
# unchanged. Bend-UI adds the events that carry something from the browser (typed text, a key, a
# pointer) and the type `Input` that brings it. A page written for his file runs on this one as it is.
#
# Everything under HTML is `Data` on purpose: a view is a plain tree that can be copied, compared in a
# law and handed to JS as `{$: "node", ..}`. A `Data` tree can't hold a function, so an event holds
# only a message, and what the browser has to say arrives beside it: the program defines
#
#   def on_input(+msg: Ev, +got: Web.Input) -> Ev
#
# and the driver sends `on_input(msg, got)` to `on_event`, as it does with any click. The message in
# the view is the event with a placeholder in it (`Web.on{Web.input{name_typed{""}}}`); `on_input`
# returns it filled (`name_typed{"Ana"}`). Every change of state still goes through `on_event`.
#
# A program defines:
#   init()                    -> Web.Update<St, Ev>   the first state, and what to do first
#   render(+st: St)           -> Web.HTML<Ev>         the whole screen, from the state
#   on_event(+ev: Ev, +st: St) -> Web.Update<St, Ev>  one event: the next state, and what to do next
#   on_input(+msg: Ev, +got: Web.Input) -> Ev         only when the view uses an event that carries something
#   key_event(+st: St, +code: U32) -> Ev              only when the view has a key root (data-key-root)
#
# Limits now:
# - No canvas and no WebGL: a page that draws pixel by pixel keeps that part in JS.
# - No command for the network (Cmd has a delay and the browser's storage).
# - A list is compared place by place, with no keys: when an item is put in the middle, what the
#   browser keeps on a node (focus, a running animation) stays with the place, not with the item.
# - One clock per interval on a node: two `every_ms` with the same `ms` on one node count as one.

import Base

type DomEvent<-Ev: Data> is Data:
  click{msg: Ev}
  double_click{msg: Ev}
  input{msg: Ev}          # each keystroke in a field: on_input gets typed{value}
  change{msg: Ev}         # the field was committed (Enter, or it was left): typed{value}
  key_down{msg: Ev}       # a key went down on this node or inside it: key{name, mods, code}
  pointer_down{msg: Ev}   # point{x, y, buttons, mods}, x and y from this node's top left corner
  pointer_move{msg: Ev}
  pointer_up{msg: Ev}

# What the browser hands over with an event.
# key: `name` is the key in lower case ("a", "enter", "arrowup"); `mods` adds 1 for Mod (Cmd on a Mac,
# Ctrl elsewhere), 2 for Shift and 4 for Alt, as SPEC.bend's shortcuts do; `code` is the number
# `key_event` gets.
type Input is Data:
  typed{value: String}
  key{name: String, mods: U32, code: U32}
  point{x: F32, y: F32, buttons: U32, mods: U32}

type Attr<-Ev: Data> is Data:
  attr{name: String, value: String}
  prop{name: String, value: String}
  style{name: String, value: String}
  on{event: DomEvent<Ev>}
  every_ms{ms: U32, msg: Ev}

type HTML<-Ev: Data> is Data:
  text{value: String}
  node{tag: String, attrs: List<&2, Attr<Ev>>, kids: List<&2, HTML<Ev>>}

# App command. `store_get` keeps its callback, so a Cmd (and an Update) is
# affine: it is built once by the update function and consumed by the runtime.
type Cmd<-Ev: Data> is Type:
  none{}
  batch{cmds: List<&1, Cmd<Ev>>}
  delay{ms: U32, event: Ev}
  store_get{key: String, on_some: @+wire: String -> Ev, on_none: Ev}
  store_set{key: String, value: String, event: Ev}
  store_del{key: String, event: Ev}

type Update<-St: Data, -Ev: Data> is Type:
  update{state: St, cmd: Cmd<Ev>}

def _assert_text() -> {text{"hello"} == text{"hello"} : HTML<Unit>}:
  {==}

def _assert_node() -> {node{"button", [attr{"id", "ok"}, on{click{Unit{}}}], [text{"go"}]} == node{"button", [attr{"id", "ok"}, on{click{Unit{}}}], [text{"go"}]} : HTML<Unit>}:
  {==}
