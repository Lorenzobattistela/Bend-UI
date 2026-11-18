# Board, lane and card (opt-in: import "bend-ui/board"). Made in the card editor.
# Only what the owner locked is fixed: BOARD_LAWS.bend pins it. "# undecided" shows on screen but has no law yet.
import Base
import ./TOKENS.bend as T

# Shape
def board_default_shape() -> String: "sharp"
def card_radius_sharp() -> U32: T.space_0()  # undecided
def card_radius_rounded() -> U32: T.radius_md()  # undecided
def card_radius_pill() -> U32: T.radius_full()  # undecided
def lane_radius_sharp() -> U32: T.space_0()  # undecided
def lane_radius_rounded() -> U32: T.radius_lg()  # undecided
def lane_radius_pill() -> U32: T.radius_full()  # undecided

# Card
def card_padding_left() -> U32: T.space_3()
def card_padding_right() -> U32: T.space_3()
def card_padding_top() -> U32: T.space_3()
def card_padding_bottom() -> U32: T.space_3()
def card_gap() -> U32: T.space_3()
def card_row() -> U32: T.control_sm()  # undecided
def card_title_role() -> String: "text"  # undecided
def card_tag_row() -> String: "top"  # undecided
def card_head_gap() -> U32: T.space_3()  # undecided
def card_foot_align() -> String: "end"
def card_foot_order() -> String: "who_tag"
def card_foot_gap() -> U32: T.space_3()
def card_content_width() -> U32: 240  # undecided
def card_shows_id() -> Bool: True{}  # undecided
def card_shows_menu() -> Bool: True{}  # undecided
def card_shows_tag() -> Bool: True{}  # undecided
def card_shows_who() -> Bool: True{}  # undecided
def card_check_size() -> U32: T.icon_md()  # undecided
def card_check_gap() -> U32: T.space_3()

# Lane
def lane_padding_left() -> U32: T.space_3()  # undecided
def lane_padding_right() -> U32: T.space_3()  # undecided
def lane_padding_top() -> U32: T.space_3()  # undecided
def lane_padding_bottom() -> U32: T.space_3()  # undecided
def lane_gap() -> U32: T.space_2()  # undecided
def lane_head_padding_left() -> U32: T.space_hairline()  # undecided
def lane_head_padding_right() -> U32: T.space_3()  # undecided

# Board
def board_padding_x() -> U32: T.space_5()  # undecided
def board_gap() -> U32: T.space_5()  # undecided
def board_head_padding_y() -> U32: T.space_3()  # undecided
def board_head_gap() -> U32: T.space_2()  # undecided

# Open card: the dialog a card opens into (the "ficha"). Values from the Cartão aberto editor; none locked yet.
def card_dialog_padding() -> U32: T.space_4()  # undecided
def card_dialog_head_gap() -> U32: T.space_4()  # undecided
def card_dialog_head_item_gap() -> U32: T.space_4()  # undecided
def card_dialog_title_gap() -> U32: T.space_3()  # undecided
def card_dialog_data_gap() -> U32: T.space_1()  # undecided
def card_dialog_notes_gap() -> U32: T.space_4()  # undecided
def card_dialog_foot_gap() -> U32: T.space_4()  # undecided
def card_dialog_actions_gap() -> U32: T.space_4()  # undecided
def card_dialog_open_top() -> U32: T.space_8()  # undecided
def card_dialog_open_height() -> String: "60dvh"  # undecided. How tall it opens: a share of the screen's height.
def card_dialog_edit_pad() -> U32: T.space_1()  # undecided
def card_dialog_editable() -> String: "tint"  # undecided. How a field shows it can be edited: "cursor", "tint" or "line".

# Open card: pieces. What gets added to a card (its sub-cards, a checklist, the cards it waits for) is a block under its
# notes, with a list of rows. Values from the "Subtask e bloqueio" artifact, where they borrowed the card's own; none locked yet.
def card_piece_padding() -> U32: T.space_3()  # undecided
def card_piece_gap() -> U32: T.space_1()  # undecided
def card_piece_radius() -> U32: T.radius_md()  # undecided
def card_pieces_gap() -> U32: T.space_3()  # undecided
def card_item_row() -> U32: T.control_sm()  # undecided
def card_item_gap() -> U32: T.space_3()  # undecided

# Where the open card sits, px from the top of the screen. It opens `open` down and grows down with its text;
# when it touches the bottom (gap from the edge) it moves up; it never goes above `gap`. Past that, its middle scrolls.
# In whole px. The height counts up to the screen less both gaps, so nothing goes below zero.
def card_dialog_top(+open: U32, +screen: U32, +gap: U32, +h: U32) -> U32:
  U32.max(gap, U32.min(open, ((screen - gap : U32) - U32.min(h, ((screen - gap : U32) - gap : U32)) : U32)))

# Derived: a level inside a list starts under the text of the level above (past the circle and its gap).
def card_item_indent() -> U32: ((card_check_size() + card_item_gap() : U32))

# Derived: the card grows outward with its sides, so a padding never squeezes the content.
def card_width() -> U32: ((card_content_width() + card_padding_left() : U32) + card_padding_right() : U32)
def lane_width() -> U32: ((card_width() + lane_padding_left() : U32) + lane_padding_right() : U32)
