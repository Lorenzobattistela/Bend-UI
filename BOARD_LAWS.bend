# Laws of the board. Each locked value is pinned: change it anywhere and the proof fails.
import Base
import ./TOKENS.bend as T
import ./SPEC.bend as S
import ./BOARD.bend as B

# LAW: board_default_shape is "sharp".
law board_default_shape_is_fixed:
  {B.board_default_shape() == "sharp" : String}

# LAW: card_padding_left is 12.
law card_padding_left_is_fixed:
  {U32.is_eq(B.card_padding_left(), 12) == True{} : Bool}

# LAW: card_padding_right is 12.
law card_padding_right_is_fixed:
  {U32.is_eq(B.card_padding_right(), 12) == True{} : Bool}

# LAW: card_padding_top is 12.
law card_padding_top_is_fixed:
  {U32.is_eq(B.card_padding_top(), 12) == True{} : Bool}

# LAW: card_padding_bottom is 12.
law card_padding_bottom_is_fixed:
  {U32.is_eq(B.card_padding_bottom(), 12) == True{} : Bool}

# LAW: card_gap is 12.
law card_gap_is_fixed:
  {U32.is_eq(B.card_gap(), 12) == True{} : Bool}

# LAW: card_foot_align is "end".
law card_foot_align_is_fixed:
  {B.card_foot_align() == "end" : String}

# LAW: card_foot_order is "who_tag".
law card_foot_order_is_fixed:
  {B.card_foot_order() == "who_tag" : String}

# LAW: card_foot_gap is 12.
law card_foot_gap_is_fixed:
  {U32.is_eq(B.card_foot_gap(), 12) == True{} : Bool}

# LAW: card_check_gap is 12.
law card_check_gap_is_fixed:
  {U32.is_eq(B.card_check_gap(), 12) == True{} : Bool}

# LAW: with room below, the open card stays where it opened and grows down.
law card_dialog_grows_down:
  {U32.is_eq(B.card_dialog_top(64, 800, 16, 400), 64) == True{} : Bool}

# LAW: touching the bottom, it moves up just enough to keep the gap there.
law card_dialog_moves_up_at_bottom:
  {U32.is_eq(B.card_dialog_top(64, 800, 16, 740), 44) == True{} : Bool}

# LAW: taller than the screen, it stops at the gap at the top (and its middle scrolls).
law card_dialog_keeps_top_gap:
  {U32.is_eq(B.card_dialog_top(64, 800, 16, 900), 16) == True{} : Bool}
