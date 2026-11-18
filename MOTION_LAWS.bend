# Laws of the rise (MOTION.bend). They hold for any value of the stagger and the time:
# change how the turns or the waits are counted and the proof fails.
import Base
import ./MOTION.bend as M

# LAW: the first turn doesn't wait.
law rise_first_waits_none:
  {U32.is_eq(M.rise_delay(0, M.rise_stagger_ms()), 0) == True{} : Bool}

# LAW: going up, the bottom row (the last of 4) has the first turn.
law rise_up_bottom_first:
  {U32.is_eq(M.rise_turn_up(3, 4), 0) == True{} : Bool}

# LAW: going down, the top row has the first turn.
law rise_down_top_first:
  {U32.is_eq(M.rise_turn_down(0, 4), 0) == True{} : Bool}

# LAW: each turn waits one stagger more than the turn before.
law rise_waits_one_stagger_more:
  {U32.is_eq(M.rise_delay(2, M.rise_stagger_ms()), (M.rise_delay(1, M.rise_stagger_ms()) + M.rise_stagger_ms() : U32)) == True{} : Bool}

# LAW: a menu of 4 is in place after the last turn's wait plus one row's time.
law rise_total_is_last_wait_plus_time:
  {U32.is_eq(M.rise_total(4, M.rise_stagger_ms(), M.rise_time_ms()), (M.rise_delay(3, M.rise_stagger_ms()) + M.rise_time_ms() : U32)) == True{} : Bool}

# Laws of the squeeze and the stretch (MOTION.bend): the owner locked how a piece leaves and how it arrives.

# LAW: a piece leaves gathering first: squeeze_ease is "back".
law squeeze_ease_is_fixed:
  {M.squeeze_ease() == "back" : String}

# LAW: a piece arrives slow, fast, slow: stretch_ease is "in-out".
law stretch_ease_is_fixed:
  {M.stretch_ease() == "in-out" : String}
