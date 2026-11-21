# UI: Bend-UI's components as Bend values. Each def returns the markup README.md documents for that
# component, as a `Web.HTML` tree: the same tags, the same class names. ui.css styles it and ui.js
# gives it its behaviour exactly as they do for markup written by hand, so a component looks and
# works the same whichever way the page was written. WEB_LAWS.bend holds each def to its markup.
#
#   import ./node_modules/bend-ui/Web.bend as Web
#   import ./node_modules/bend-ui/UI.bend as Ui
#
#   Ui.button(Ev, [Ui.btn_filled{}], "Save", saved{})
#   # <button class="btn btn--filled">Save</button>, and a click sends saved{}
#
# How a def is called:
# - `Ev` first: the type of the page's messages.
# - A component's modifiers are a list of its own type, in the order the classes are written:
#   `.btn--filled` is `btn_filled{}`. A modifier of another component is a type error.
# - The short def is the common case. The `_with` def takes `more` (the page's own classes, or ""),
#   `attrs` (anything else on the node: ARIA, an id, events) and the children.
#
# Limits now:
# - The first components only: icon, button, segmented, dropdown and menu, input and field, panel,
#   disclosure, separator, dot, and the text roles. The others are still written as `Web.node`.
# - The components ui.js draws by itself (chart, diagram, agent, thread, tree, terminal, board) are
#   not here: they are mounted from JS, as before.
# - A segmented is always `data-manual`: Bend holds which choice is pressed.

import Base
import ./Web.bend as Web

# ---------- Classes ----------

def with_more.if(none: Bool, +class: String, +more: String) -> String:
  match none:
    case True{}:
      class
    case False{}:
      class ++ " " ++ more

# A component's classes and then the page's own, when it has any.
def with_more(+class: String, +more: String) -> String:
  with_more.if(String.is_empty(more), class, more)

def bool_text(on: Bool) -> String:
  match on:
    case True{}:
      "true"
    case False{}:
      "false"

# An element with a class: the plain way to write a node whose class is the page's own.
def box(-Ev: Data, +tag: String, +class: String, +attrs: List<&2, Web.Attr<Ev>>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Web.node{tag, Web.attr{"class", class} <> attrs, kids}

# A text in one of the type roles: says(Ev, "span", "item-title", "Origin").
def says(-Ev: Data, +tag: String, +class: String, +text: String) -> Web.HTML<Ev>:
  Web.node{tag, [Web.attr{"class", class}], [Web.text{text}]}

# ---------- Icon ----------

type Icon is Data:
  icon_sm{}
  icon_lg{}

def icon_class(+m: Icon) -> String:
  match m:
    case icon_sm{}:
      " icon--sm"
    case icon_lg{}:
      " icon--lg"

def icon_classes(+ms: List<&2, Icon>) -> String:
  match ms:
    case Nil{}:
      ""
    case Con{h, t}:
      icon_class(h) ++ icon_classes(t)

# <svg class="icon"><use href="#i-plus"/></svg>
def icon_with(-Ev: Data, +ms: List<&2, Icon>, +more: String, +attrs: List<&2, Web.Attr<Ev>>, +id: String) -> Web.HTML<Ev>:
  Web.node{"svg", Web.attr{"class", with_more("icon" ++ icon_classes(ms), more)} <> attrs, [Web.node{"use", [Web.attr{"href", "#i-" ++ id}], []}]}

def icon(-Ev: Data, +id: String) -> Web.HTML<Ev>:
  icon_with(Ev, [], "", [], id)

# ---------- Button ----------

type Btn is Data:
  btn_filled{}
  btn_tinted{}
  btn_bordered{}
  btn_plain{}
  btn_link{}
  btn_neutral{}
  btn_danger{}
  btn_sm{}
  btn_lg{}
  btn_xl{}
  btn_wide{}
  btn_icon{}
  btn_round{}
  btn_pill{}
  btn_sharp{}
  btn_toggle{}
  btn_primary{}
  btn_ghost{}
  btn_reveal{}
  btn_hold{}
  btn_async{}
  btn_extend{}

def btn_class(+m: Btn) -> String:
  match m:
    case btn_filled{}:
      " btn--filled"
    case btn_tinted{}:
      " btn--tinted"
    case btn_bordered{}:
      " btn--bordered"
    case btn_plain{}:
      " btn--plain"
    case btn_link{}:
      " btn--link"
    case btn_neutral{}:
      " btn--neutral"
    case btn_danger{}:
      " btn--danger"
    case btn_sm{}:
      " btn--sm"
    case btn_lg{}:
      " btn--lg"
    case btn_xl{}:
      " btn--xl"
    case btn_wide{}:
      " btn--wide"
    case btn_icon{}:
      " btn--icon"
    case btn_round{}:
      " btn--round"
    case btn_pill{}:
      " btn--pill"
    case btn_sharp{}:
      " btn--sharp"
    case btn_toggle{}:
      " btn--toggle"
    case btn_primary{}:
      " btn--primary"
    case btn_ghost{}:
      " btn--ghost"
    case btn_reveal{}:
      " btn--reveal"
    case btn_hold{}:
      " btn--hold"
    case btn_async{}:
      " btn--async"
    case btn_extend{}:
      " btn--extend"

def btn_classes(+ms: List<&2, Btn>) -> String:
  match ms:
    case Nil{}:
      ""
    case Con{h, t}:
      btn_class(h) ++ btn_classes(t)

def button_with(-Ev: Data, +ms: List<&2, Btn>, +more: String, +attrs: List<&2, Web.Attr<Ev>>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Web.node{"button", Web.attr{"class", with_more("btn" ++ btn_classes(ms), more)} <> attrs, kids}

# <button class="btn btn--filled">Save</button>
def button(-Ev: Data, +ms: List<&2, Btn>, +label: String, +msg: Ev) -> Web.HTML<Ev>:
  button_with(Ev, ms, "", [Web.on{Web.click{msg}}], [Web.text{label}])

# <button class="btn btn--plain btn--neutral btn--sm btn--icon" aria-label="Add"><svg class="icon"><use href="#i-plus"/></svg></button>
def icon_button(-Ev: Data, +ms: List<&2, Btn>, +name: String, +id: String, +msg: Ev) -> Web.HTML<Ev>:
  button_with(Ev, ms, "", [Web.attr{"aria-label", name}, Web.on{Web.click{msg}}], [icon(Ev, id)])

# A button that stays pressed: `.btn--toggle` with aria-pressed. Give btn_toggle{} among the modifiers.
def toggle(-Ev: Data, +ms: List<&2, Btn>, +more: String, +label: String, on: Bool, +msg: Ev) -> Web.HTML<Ev>:
  button_with(Ev, ms, more, [Web.attr{"type", "button"}, Web.attr{"aria-pressed", bool_text(on)}, Web.on{Web.click{msg}}], [Web.text{label}])

# ---------- Segmented ----------

type Seg is Data:
  seg_slide{}
  seg_extend{}
  seg_icons{}

def seg_class(+m: Seg) -> String:
  match m:
    case seg_slide{}:
      " segmented--slide"
    case seg_extend{}:
      " segmented--extend"
    case seg_icons{}:
      " segmented--icons"

def seg_classes(+ms: List<&2, Seg>) -> String:
  match ms:
    case Nil{}:
      ""
    case Con{h, t}:
      seg_class(h) ++ seg_classes(t)

# One choice of a group: <button aria-pressed="true">One</button>
def choice_with(-Ev: Data, on: Bool, +attrs: List<&2, Web.Attr<Ev>>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Web.node{"button", Web.attr{"aria-pressed", bool_text(on)} <> attrs, kids}

def choice(-Ev: Data, +label: String, on: Bool, +msg: Ev) -> Web.HTML<Ev>:
  choice_with(Ev, on, [Web.on{Web.click{msg}}], [Web.text{label}])

# <div class="segmented" data-manual="">…</div>: Bend says which choice is pressed.
def segmented_with(-Ev: Data, +ms: List<&2, Seg>, +more: String, +attrs: List<&2, Web.Attr<Ev>>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Web.node{"div", Web.attr{"class", with_more("segmented" ++ seg_classes(ms), more)} <> Web.attr{"data-manual", ""} <> attrs, kids}

# A named group: role="group" and aria-label.
def segmented(-Ev: Data, +ms: List<&2, Seg>, +name: String, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  segmented_with(Ev, ms, "", [Web.attr{"role", "group"}, Web.attr{"aria-label", name}], kids)

# ---------- Dropdown and menu ----------

type Menu is Data:
  menu_end{}
  menu_up{}
  menu_wide{}

def menu_class(+m: Menu) -> String:
  match m:
    case menu_end{}:
      " menu--end"
    case menu_up{}:
      " menu--up"
    case menu_wide{}:
      " menu--wide"

def menu_classes(+ms: List<&2, Menu>) -> String:
  match ms:
    case Nil{}:
      ""
    case Con{h, t}:
      menu_class(h) ++ menu_classes(t)

# <div class="dropdown">trigger menu</div>: ui.js opens and closes the menu and places it.
def dropdown(-Ev: Data, +trigger: Web.HTML<Ev>, +menu: Web.HTML<Ev>) -> Web.HTML<Ev>:
  Web.node{"div", [Web.attr{"class", "dropdown"}], [trigger, menu]}

# The button that opens the menu: a button with aria-haspopup="menu" aria-expanded="false".
def trigger_with(-Ev: Data, +ms: List<&2, Btn>, +more: String, +attrs: List<&2, Web.Attr<Ev>>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  button_with(Ev, ms, more, Web.attr{"aria-haspopup", "menu"} <> Web.attr{"aria-expanded", "false"} <> attrs, kids)

# <div class="menu" hidden>…</div>, closed: ui.js shows it. Give its role among the attributes.
def menu_with(-Ev: Data, +ms: List<&2, Menu>, +more: String, +attrs: List<&2, Web.Attr<Ev>>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Web.node{"div", Web.attr{"class", with_more("menu" ++ menu_classes(ms), more)} <> List.append(&2, Web.Attr<Ev>, attrs, [Web.attr{"hidden", ""}]), kids}

# <div class="menu" role="menu" hidden>…</div>
def menu(-Ev: Data, +ms: List<&2, Menu>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  menu_with(Ev, ms, "", [Web.attr{"role", "menu"}], kids)

# <button class="menu__item" role="menuitem"><svg class="icon icon--sm"><use href="#i-plus"/></svg><span>Add node below</span></button>
def menu_item(-Ev: Data, +id: String, +label: String, +msg: Ev) -> Web.HTML<Ev>:
  Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"role", "menuitem"}, Web.on{Web.click{msg}}], [icon_with(Ev, [icon_sm{}], "", [], id), Web.node{"span", [], [Web.text{label}]}]}

# One of a set, with its check:
# <button class="menu__item" role="menuitemradio" aria-checked="false"><svg class="icon"><use href="#i-heading-1"/></svg><span>Title</span><svg class="icon icon--sm menu__check"><use href="#i-check"/></svg></button>
def menu_radio(-Ev: Data, +id: String, +label: String, checked: Bool, +msg: Ev) -> Web.HTML<Ev>:
  Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"role", "menuitemradio"}, Web.attr{"aria-checked", bool_text(checked)}, Web.on{Web.click{msg}}], [icon(Ev, id), Web.node{"span", [], [Web.text{label}]}, icon_with(Ev, [icon_sm{}], "menu__check", [], "check")]}

# <hr class="separator">
def separator(-Ev: Data) -> Web.HTML<Ev>:
  Web.node{"hr", [Web.attr{"class", "separator"}], []}

# ---------- Input and field ----------

type Inp is Data:
  input_sm{}
  input_lg{}
  input_xl{}
  input_mono{}

def input_class(+m: Inp) -> String:
  match m:
    case input_sm{}:
      " input--sm"
    case input_lg{}:
      " input--lg"
    case input_xl{}:
      " input--xl"
    case input_mono{}:
      " input--mono"

def input_classes(+ms: List<&2, Inp>) -> String:
  match ms:
    case Nil{}:
      ""
    case Con{h, t}:
      input_class(h) ++ input_classes(t)

# <input class="input" …>
def input_with(-Ev: Data, +ms: List<&2, Inp>, +more: String, +attrs: List<&2, Web.Attr<Ev>>) -> Web.HTML<Ev>:
  Web.node{"input", Web.attr{"class", with_more("input" ++ input_classes(ms), more)} <> attrs, []}

# A field Bend listens to: `typing` is sent filled at each keystroke, `commit` when the field is
# committed or left (on_input fills them with typed{value}). `value` is what the field shows.
def text_input(-Ev: Data, +ms: List<&2, Inp>, +id: String, +value: String, +typing: Ev, +commit: Ev) -> Web.HTML<Ev>:
  input_with(Ev, ms, "", [Web.attr{"id", id}, Web.attr{"value", value}, Web.on{Web.input{typing}}, Web.on{Web.change{commit}}])

# The same for a number: type="number" and its step.
def number_input(-Ev: Data, +ms: List<&2, Inp>, +id: String, +value: String, +step: String, +typing: Ev, +commit: Ev) -> Web.HTML<Ev>:
  input_with(Ev, ms, "", [Web.attr{"id", id}, Web.attr{"type", "number"}, Web.attr{"step", step}, Web.attr{"value", value}, Web.on{Web.input{typing}}, Web.on{Web.change{commit}}])

# <span class="field__label">Name</span>
def field_label(-Ev: Data, +text: String) -> Web.HTML<Ev>:
  Web.node{"span", [Web.attr{"class", "field__label"}], [Web.text{text}]}

# <label class="field" for="name">…</label>
def field_with(-Ev: Data, +more: String, +attrs: List<&2, Web.Attr<Ev>>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Web.node{"label", Web.attr{"class", with_more("field", more)} <> attrs, kids}

# A label and its control: <label class="field" for="name"><span class="field__label">Name</span><input id="name" class="input"></label>
def field(-Ev: Data, +id: String, +label: String, +control: Web.HTML<Ev>) -> Web.HTML<Ev>:
  field_with(Ev, "", [Web.attr{"for", id}], [field_label(Ev, label), control])

# ---------- Panel ----------

# <div class="panel">…</div>, on the tag the page needs (a div, a section).
def panel_as(-Ev: Data, +tag: String, +more: String, +attrs: List<&2, Web.Attr<Ev>>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Web.node{tag, Web.attr{"class", with_more("panel", more)} <> attrs, kids}

# <div class="panel__header">Header</div>
def panel_header(-Ev: Data, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Web.node{"div", [Web.attr{"class", "panel__header"}], kids}

# <div class="panel__body">Body</div>
def panel_body_with(-Ev: Data, +more: String, +attrs: List<&2, Web.Attr<Ev>>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Web.node{"div", Web.attr{"class", with_more("panel__body", more)} <> attrs, kids}

# <div class="panel"><div class="panel__header">Header</div><div class="panel__body">Body</div></div>
def panel(-Ev: Data, +header: List<&2, Web.HTML<Ev>>, +body: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  panel_as(Ev, "div", "", [], [panel_header(Ev, header), panel_body_with(Ev, "", [], body)])

# ---------- Disclosure ----------

# <span class="disclosure__title">Laws</span>
def disclosure_title(-Ev: Data, +text: String) -> Web.HTML<Ev>:
  Web.node{"span", [Web.attr{"class", "disclosure__title"}], [Web.text{text}]}

# <details class="disclosure"><summary><svg class="icon icon--sm disclosure__chevron"><use href="#i-chevron-down"/></svg>…</summary>…</details>
# `attrs` go on the details (open, to start open), `chevron` on the chevron, `summary` after it.
def disclosure_with(-Ev: Data, +more: String, +attrs: List<&2, Web.Attr<Ev>>, +chevron: List<&2, Web.Attr<Ev>>, +summary: List<&2, Web.HTML<Ev>>, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  Web.node{"details", Web.attr{"class", with_more("disclosure", more)} <> attrs, Web.node{"summary", [], icon_with(Ev, [icon_sm{}], "disclosure__chevron", chevron, "chevron-down") <> summary} <> kids}

# A closed section with a title. It opens by itself: <details> is the browser's.
def disclosure(-Ev: Data, +title: String, +kids: List<&2, Web.HTML<Ev>>) -> Web.HTML<Ev>:
  disclosure_with(Ev, "", [], [], [disclosure_title(Ev, title)], kids)

# ---------- Dot ----------

type Dot is Data:
  dot_success{}
  dot_warning{}
  dot_danger{}
  dot_busy{}

def dot_class(+m: Dot) -> String:
  match m:
    case dot_success{}:
      " dot--success"
    case dot_warning{}:
      " dot--warning"
    case dot_danger{}:
      " dot--danger"
    case dot_busy{}:
      " dot--busy"

def dot_classes(+ms: List<&2, Dot>) -> String:
  match ms:
    case Nil{}:
      ""
    case Con{h, t}:
      dot_class(h) ++ dot_classes(t)

# <span class="dot dot--success"></span>
def dot_with(-Ev: Data, +ms: List<&2, Dot>, +attrs: List<&2, Web.Attr<Ev>>) -> Web.HTML<Ev>:
  Web.node{"span", Web.attr{"class", "dot" ++ dot_classes(ms)} <> attrs, []}

def dot(-Ev: Data, +ms: List<&2, Dot>) -> Web.HTML<Ev>:
  dot_with(Ev, ms, [])
