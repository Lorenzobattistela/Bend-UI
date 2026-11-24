# The Paywall page's example: a page written with Web.bend that keeps a sheet in its state and opens it from
# a button. The words are LawEditor's.
import Base
import ../Web.bend as Web
import ../UI.bend as Ui
import ../PAYWALL.bend as Pw

type Ev is Data:
  opened{}
  shut{}
  monthly{}
  yearly{}
  subscribed{}
  keyed{name: String}
  leaned{x: F32, y: F32}

def offer() -> Pw.Offer:
  Pw.Offer{"Go Premium", "$5", "$4", "/ month", "Billed monthly", "$48 billed yearly", "Monthly", "Yearly", "−20%", [
    Pw.Perk{"Access to UniiChat", "One continuous chat with an AI agent that never loses its memory."},
    Pw.Perk{"300 Visual Refinement Credits / month", "Improve the visual quality of your game with AI guided by a curated library of design references."},
    Pw.Perk{"Customization", "Personalize your agent's appearance and your app icon."}], "Subscribe", "Cancel anytime. Everything free stays free.", "Close"}

def init() -> Web.Update<Pw.Sheet, Ev>:
  Web.update{Pw.closed(), Web.none{}}

def render(+s: Pw.Sheet) -> Web.HTML<Ev>:
  Web.node{"div", [Web.attr{"class", "v-paywall"}], [
    Ui.button(Ev, [Ui.btn_filled{}], "Go Premium", opened{}),
    Pw.view(Ev, offer(), s, shut{}, monthly{}, yearly{}, subscribed{}, keyed{""}, leaned{0.0, 0.0})]}

def on_input(+msg: Ev, +got: Web.Input) -> Ev:
  match msg got:
    case keyed{_} Web.key{n, _, _}:
      keyed{n}
    case leaned{_, _} Web.point{x, y, _, _}:
      leaned{x, y}
    case _ _:
      msg

def on_key(+yes: Bool, +s: Pw.Sheet) -> Pw.Sheet:
  match yes:
    case True{}:
      Pw.shut(s)
    case False{}:
      s

def on_event(+ev: Ev, +s: Pw.Sheet) -> Web.Update<Pw.Sheet, Ev>:
  match ev:
    case opened{}:
      Web.update{Pw.opened(s), Web.none{}}
    case shut{}:
      Web.update{Pw.shut(s), Web.none{}}
    case monthly{}:
      Web.update{Pw.billed(s, False{}), Web.none{}}
    case yearly{}:
      Web.update{Pw.billed(s, True{}), Web.none{}}
    case subscribed{}:
      Web.update{Pw.shut(s), Web.none{}}
    case keyed{n}:
      Web.update{on_key(Pw.closes(n), s), Web.none{}}
    case leaned{x, y}:
      Web.update{Pw.leaned(s, x, y), Web.none{}}
