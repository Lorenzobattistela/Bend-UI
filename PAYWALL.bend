# Paywall (opt-in: import "bend-ui/paywall"). The sheet that opens over an app and says what a plan gives: a
# title, the price with a monthly / yearly switch, a list of what you get (each a title and what it does, its
# check drawing itself in turn), one action and a short note. The sheet is glass, with coloured balls brushing
# its top corner that drift and lean toward the pointer. The action and the checks stay solid.
#
# It is written with Web.bend: `view` gives the sheet as a `Web.HTML` tree and the `Sheet` state decides what it
# shows. An app keeps a `Sheet` in its own state and sends the sheet's events to `opened`, `shut`, `billed` and
# `leaned`. paywall.js writes each measure below as a CSS variable (paywall_radius → --paywall-radius) and
# paywall.css draws the tree. Nothing here is locked yet: every value is "# undecided" (it shows, without a law).
#
# Ideas from: the checklist upgrade dialog of Neon UI (price first, checks drawn one by one, one action), the
# plan upgrade dialogs of shadcn.io blocks, and the glass panels of Apple's visionOS. Approved in the artifact
# "Perks e Customização" (2026-11-24).
import Base
import ./Web.bend as Web
import ./UI.bend as Ui

# ---------- Measures ----------
def paywall_width() -> U32: 400  # undecided. The sheet's width (it is never wider than the window).
def paywall_radius() -> U32: 28  # undecided. The sheet's corners.
def paywall_pad() -> U32: 28  # undecided. Space inside the sheet.
def paywall_gap() -> U32: 18  # undecided. Space between the sheet's rows.
def paywall_list_gap() -> U32: 20  # undecided. Space between two things you get, and around the list.
def paywall_title_size() -> U32: 30  # undecided. The title's size.
def paywall_amount_size() -> U32: 44  # undecided. The price's size.
def paywall_action_height() -> U32: 48  # undecided. The action's height.
def paywall_check_size() -> U32: 20  # undecided. A check mark.
def paywall_blur() -> U32: 22  # undecided. How much the glass blurs what is behind it.
def paywall_lean() -> U32: 14  # undecided. How far the nearest ball leans toward the pointer.
def paywall_layer() -> U32: 60  # undecided. The sheet sits over the window, under nothing.
def paywall_open_ms() -> U32: 420  # undecided. The sheet rises into place.
def paywall_check_ms() -> U32: 380  # undecided. One check draws itself.
def paywall_check_first_ms() -> U32: 260  # undecided. The first check starts this long after the sheet opens.
def paywall_check_step_ms() -> U32: 140  # undecided. Each next check starts this much later.

# Colours. The action and the checks are one solid colour; the balls are three.
def paywall_action_color() -> String: "#009d86"  # undecided
def paywall_action_hover() -> String: "#008b77"  # undecided
def paywall_action_color_dark() -> String: "#00c9aa"  # undecided. On the dark sheet.
def paywall_action_ink_dark() -> String: "#04211c"  # undecided. The action's words on the dark sheet.
def paywall_ball_1() -> String: "#00c9aa"  # undecided
def paywall_ball_2() -> String: "#8b5cf6"  # undecided
def paywall_ball_3() -> String: "#ff8a66"  # undecided

# ---------- What the sheet says ----------
# One thing you get: its title and what it does.
type Perk is Data:
  Perk{title: String, text: String}

# title: the sheet's title. monthly, yearly: the price shown for each (per: what follows it, "/ month").
# billed_monthly, billed_yearly: the line under the price. month, year, save: the switch's words.
# action: the button. note: the line under it. close: the close button's name for screen readers.
type Offer is Data:
  Offer{title: String, monthly: String, yearly: String, per: String, billed_monthly: String, billed_yearly: String, month: String, year: String, save: String, perks: List<&2, Perk>, action: String, note: String, close: String}

# ---------- The state ----------
# open: whether the sheet shows. yearly: which price. x, y: where the pointer leans the balls, each from -1 to 1.
type Sheet is Data:
  Sheet{open: Bool, yearly: Bool, x: F32, y: F32}

def closed() -> Sheet:
  Sheet{False{}, False{}, 0.0, 0.0}

def opened(+s: Sheet) -> Sheet:
  match s:
    case Sheet{_, yearly, _, _}:
      Sheet{True{}, yearly, 0.0, 0.0}

def shut(+s: Sheet) -> Sheet:
  match s:
    case Sheet{_, yearly, _, _}:
      Sheet{False{}, yearly, 0.0, 0.0}

def billed(+s: Sheet, +yearly: Bool) -> Sheet:
  match s:
    case Sheet{open, _, x, y}:
      Sheet{open, yearly, x, y}

# A number kept between -1 and 1.
def unit(+n: F32) -> F32:
  F32.max(F32.sub(0.0, 1.0), F32.min(1.0, n))

# The pointer at (px, py) from the sheet's top left corner, on a sheet w wide and h tall: how far it leans,
# from -1 (left, top) to 1 (right, bottom).
def lean_of(+p: F32, +size: F32) -> F32:
  unit(F32.div(F32.sub(p, F32.div(size, 2.0)), F32.div(size, 2.0)))

# The sheet's height is not known in Bend: the balls lean on the width both ways, which is what the eye reads.
def leaned(+s: Sheet, +px: F32, +py: F32) -> Sheet:
  match s:
    case Sheet{open, yearly, _, _}:
      Sheet{open, yearly, lean_of(px, U32.to_f32(paywall_width())), lean_of(py, U32.to_f32(paywall_width()))}

# The key that closes the sheet.
def closes(+key: String) -> Bool:
  String.eq(key, "escape")

# ---------- The view ----------
def pick(+yes: Bool, +a: String, +b: String) -> String:
  match yes:
    case True{}:
      a
    case False{}:
      b

# The price is always two lines, the amount and how it is billed, whichever is picked: switching never moves
# anything (PAYWALL_LAWS.bend holds it).
def price(-Ev: Data, +o: Offer, +yearly: Bool) -> Web.HTML<Ev>:
  match o:
    case Offer{_, monthly, year_price, per, billed_monthly, billed_yearly, _, _, _, _, _, _, _}:
      Web.node{"div", [Web.attr{"class", "paywall__price"}], [
        Web.node{"span", [Web.attr{"class", "paywall__amount"}], [Web.node{"b", [], [Web.text{pick(yearly, year_price, monthly)}]}, Web.node{"span", [], [Web.text{per}]}]},
        Web.node{"small", [Web.attr{"class", "paywall__billed"}], [Web.text{pick(yearly, billed_yearly, billed_monthly)}]}]}

def bill(-Ev: Data, +o: Offer, +yearly: Bool, +month_msg: Ev, +year_msg: Ev) -> Web.HTML<Ev>:
  match o:
    case Offer{_, _, _, _, _, _, month, year, save, _, _, _, _}:
      Web.node{"div", [Web.attr{"class", "paywall__bill"}, Web.attr{"data-on", pick(yearly, "1", "0")}, Web.attr{"role", "group"}, Web.attr{"aria-label", "Billing"}], [
        Web.node{"i", [Web.attr{"aria-hidden", "true"}], []},
        Web.node{"button", [Web.attr{"type", "button"}, Web.attr{"aria-pressed", pick(yearly, "false", "true")}, Web.on{Web.click{month_msg}}], [Web.text{month}]},
        Web.node{"button", [Web.attr{"type", "button"}, Web.attr{"aria-pressed", pick(yearly, "true", "false")}, Web.on{Web.click{year_msg}}], [Web.text{year}, Web.node{"em", [], [Web.text{save}]}]}]}

# A check mark that draws itself: one stroke.
def tick(-Ev: Data) -> Web.HTML<Ev>:
  Web.node{"span", [Web.attr{"class", "paywall__tick"}, Web.attr{"aria-hidden", "true"}], [
    Web.node{"svg", [Web.attr{"viewBox", "0 0 24 24"}, Web.attr{"fill", "none"}, Web.attr{"stroke", "currentColor"}, Web.attr{"stroke-width", "2.6"}, Web.attr{"stroke-linecap", "round"}, Web.attr{"stroke-linejoin", "round"}], [
      Web.node{"path", [Web.attr{"d", "M5 12.5l4.5 4.5L19 7.5"}], []}]}]}

# The things you get, each with its place in the order (--i: when its check draws).
def perks(-Ev: Data, +ps: List<&2, Perk>, +i: U32) -> List<&2, Web.HTML<Ev>>:
  match ps:
    case Nil{}:
      []
    case Con{p, rest}:
      match p:
        case Perk{title, text}:
          Web.node{"li", [Web.style{"--i", U32.show(i)}], [tick(Ev), Web.node{"span", [Web.attr{"class", "paywall__perk"}], [Web.node{"b", [], [Web.text{title}]}, Web.node{"span", [], [Web.text{text}]}]}]} <> perks(Ev, rest, (i + 1 : U32))

def balls(-Ev: Data) -> Web.HTML<Ev>:
  Web.node{"div", [Web.attr{"class", "paywall__balls"}, Web.attr{"aria-hidden", "true"}], [
    Web.node{"span", [Web.attr{"class", "paywall__ball paywall__ball--1"}], [Web.node{"i", [], []}]},
    Web.node{"span", [Web.attr{"class", "paywall__ball paywall__ball--2"}], [Web.node{"i", [], []}]},
    Web.node{"span", [Web.attr{"class", "paywall__ball paywall__ball--3"}], [Web.node{"i", [], []}]}]}

# While closed the sheet is out of reach: no focus, no screen reader, no pointer.
def root_attrs(-Ev: Data, +open: Bool) -> List<&2, Web.Attr<Ev>>:
  match open:
    case True{}:
      [Web.attr{"class", "paywall is-open"}]
    case False{}:
      [Web.attr{"class", "paywall"}, Web.attr{"inert", ""}, Web.attr{"aria-hidden", "true"}]

# The sheet. shut_msg: the close button, the ground around the sheet and Escape send it. month_msg, year_msg: the
# switch. act_msg: the action. key_msg, lean_msg: events that carry something (a key, the pointer); the app's
# on_input fills them from Web.key and Web.point and sends them on to `closes` and `leaned`.
def view(-Ev: Data, +o: Offer, +s: Sheet, +shut_msg: Ev, +month_msg: Ev, +year_msg: Ev, +act_msg: Ev, +key_msg: Ev, +lean_msg: Ev) -> Web.HTML<Ev>:
  match o s:
    case Offer{title, _, _, _, _, _, _, _, _, list, action, note, close} Sheet{open, yearly, x, y}:
      Web.node{"div", root_attrs(Ev, open), [
        Web.node{"div", [Web.attr{"class", "paywall__ground"}, Web.on{Web.click{shut_msg}}], []},
        Web.node{"section", [Web.attr{"class", "paywall__sheet"}, Web.attr{"tabindex", "-1"}, Web.attr{"role", "dialog"}, Web.attr{"aria-modal", "true"}, Web.attr{"aria-labelledby", "paywall-title"}, Web.style{"--mx", F32.show(x)}, Web.style{"--my", F32.show(y)}, Web.on{Web.key_down{key_msg}}, Web.on{Web.pointer_move{lean_msg}}], [
          balls(Ev),
          Web.node{"button", [Web.attr{"class", "paywall__close"}, Web.attr{"type", "button"}, Web.attr{"aria-label", close}, Web.on{Web.click{shut_msg}}], [Ui.icon(Ev, "x")]},
          Web.node{"div", [Web.attr{"class", "paywall__in"}], [
            Web.node{"h2", [Web.attr{"class", "paywall__title"}, Web.attr{"id", "paywall-title"}], [Web.text{title}]},
            Web.node{"div", [Web.attr{"class", "paywall__pricerow"}], [price(Ev, o, yearly), bill(Ev, o, yearly, month_msg, year_msg)]},
            Web.node{"ul", [Web.attr{"class", "paywall__list"}], perks(Ev, list, 0)},
            Web.node{"button", [Web.attr{"class", "paywall__action"}, Web.attr{"type", "button"}, Web.on{Web.click{act_msg}}], [Ui.icon(Ev, "star"), Web.node{"span", [], [Web.text{action}]}]},
            Web.node{"p", [Web.attr{"class", "paywall__note"}], [Web.text{note}]}]}]}]}
