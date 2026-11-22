# State, mood and pointer history; the browser supplies only input and elapsed time.
import Base
import ./FAIRY_MOTION.bend as M

type History is Data:
  none{}
  before{state: U32, arc: F32, age: F32, t: F32, from: History}
type Animator is Data:
  Animator{follow: M.Follow, last: F32, ready: Bool, state: U32, arc: F32, since: F32, began: F32, history: History}
type Step is Data:
  Step{next: Animator, follow: M.Follow, weight: F32, history: History, progress: F32, age: F32, moving: Bool}

def init() -> Animator:
  Animator{M.Follow{0.0, 0.0, 0.0}, 0.0, False{}, 0, 0.0, 0.0, 0.0, none{}}
def has(h: History) -> Bool:
  match h:
    case none{}: False{}
    case before{s, a, age, t, from}: True{}
# Same bounded interrupted-transition history as Open Bot: drop contributions below 2%.
def settle(h: History, +share: F32, +depth: U32) -> History:
  match h:
    case none{}: none{}
    case before{state, arc, age, +t, from}:
      +rest = (share * (1.0 - t) : F32)
      before{state, arc, age, t, Bool.pick(History, (rest < 0.02 : F32) || (depth >= 3 : U32), none{}, settle(from, rest, (depth + 1 : U32)))}
def follow(old: M.Follow, +x: F32, +y: F32, active: Bool, hold: Bool, dt: F32, reduced: Bool) -> M.FollowResult:
  match old:
    case M.Follow{+ox, +oy, +a}:
      Bool.pick(M.FollowResult, hold, M.FollowResult{M.Follow{ox, oy, a}, False{}}, M.follow_step(ox, oy, a, x, y, active, dt, reduced))
def result(f: M.FollowResult, +now: F32, +state: U32, +arc: F32, +since: F32, +began: F32, history: History, reduced: Bool) -> Step:
  match f:
    case M.FollowResult{M.Follow{+x, +y, +attention}, +moving}:
      +progress = M.choose(reduced, 1.0, M.mood_progress((now - since : F32)))
      +h = Bool.pick(History, (progress < 1.0 : F32), history, none{})
      +look = {M.Follow{x, y, attention} : M.Follow}
      Step{Animator{look, now, True{}, state, arc, since, began, h}, look, M.smooth(attention), h, progress, ((now - began) / 1000.0 : F32), moving || has(h)}
def step(old: Animator, +now: F32, +state: U32, +arc: F32, x: F32, y: F32, active: Bool, hold: Bool, +reduced: Bool) -> Step:
  match old:
    case Animator{look, last, +ready, +prev, +old_arc, +since, +began, +history}:
      +changed = ready && (U32.is_ne(state, prev) || F32.is_ne(arc, old_arc))
      +since_next = M.choose(ready, M.choose(changed, now, since), now)
      +began_next = M.choose(ready, M.choose(U32.is_ne(state, prev), now, began), (now - M.choose(U32.is_eq(state, 5), 3870.0, 0.0) : F32))
      h = Bool.pick(History, changed, Bool.pick(History, reduced, none{}, settle(before{prev, old_arc, ((now - began) / 1000.0 : F32), M.mood_progress((now - since : F32)), history}, 1.0, 0)), history)
      result(follow(look, x, y, active, hold, M.choose(ready, ((now - last) / 1000.0 : F32), 0.0), reduced), now, state, arc, since_next, began_next, h, reduced)

# Evaluate each contributing pose at the same clock instant, preserving state ages.
def pose(h: History, +seed: U32, +time: F32, +state: U32, arc: F32, +age: F32, +progress: F32, +gx: F32, +gy: F32, +weight: F32, +reduced: Bool, +vy: F32, +vp: F32) -> M.Pose:
  match h:
    case none{}: M.pose(seed, time, state, arc, age, gx, gy, weight, reduced, vy, vp)
    case before{+prev, old_arc, old_age, t, from}:
      current = M.pose(seed, time, state, arc, age, gx, gy, weight, reduced, vy, vp)
      previous = pose(from, seed, time, prev, old_arc, M.choose(U32.is_eq(prev, state), age, old_age), t, gx, gy, weight, reduced, vy, vp)
      M.blend_pose(previous, current, progress)
