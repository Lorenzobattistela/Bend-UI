# Laws of the paywall (PAYWALL.bend). The owner's rules for the sheet, said so the proof fails if the view
# breaks them.
import Base
import ./Web.bend as Web
import ./PAYWALL.bend as Pw

# A view's skeleton: its tags, with every text and attribute left out. Two views with the same skeleton take
# the same room on screen when their words are the same length.
def shapes(+hs: List<&2, Web.HTML<Unit>>) -> String:
  match hs:
    case Nil{}:
      ""
    case Con{h, rest}:
      match h:
        case Web.text{_}:
          "t" ++ shapes(rest)
        case Web.node{tag, _, kids}:
          tag ++ "(" ++ shapes(kids) ++ ")" ++ shapes(rest)

def shape(+h: Web.HTML<Unit>) -> String:
  shapes([h])

def offer() -> Pw.Offer:
  Pw.Offer{"Go Premium", "$5", "$4", "/ month", "Billed monthly", "$48 billed yearly", "Monthly", "Yearly", "−20%", [Pw.Perk{"A", "a"}], "Subscribe", "Cancel anytime.", "Close"}

# LAW: switching between monthly and yearly never changes the price's shape: it is always the amount and the
# line under it, so the sheet keeps its size.
law price_keeps_its_shape:
  {shape(Pw.price(Unit, offer(), True{})) == shape(Pw.price(Unit, offer(), False{})) : String}

# LAW: the sheet starts closed.
law sheet_starts_closed:
  {Pw.closed() == Pw.Sheet{False{}, False{}, 0.0, 0.0} : Pw.Sheet}

# LAW: closing keeps the billing that was picked, so the sheet opens again as it was left.
law closing_keeps_the_billing:
  {Pw.opened(Pw.shut(Pw.billed(Pw.opened(Pw.closed()), True{}))) == Pw.Sheet{True{}, True{}, 0.0, 0.0} : Pw.Sheet}

# LAW: Escape closes the sheet.
law escape_closes:
  {Pw.closes("escape") == True{} : Bool}
