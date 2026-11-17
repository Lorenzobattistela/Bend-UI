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

# Derived: the card grows outward with its sides, so a padding never squeezes the content.
def card_width() -> U32: ((card_content_width() + card_padding_left() : U32) + card_padding_right() : U32)
def lane_width() -> U32: ((card_width() + lane_padding_left() : U32) + lane_padding_right() : U32)
