// Converts browser input and Bend's state into the renderer's wire types.
import A from "../FAIRY_ANIMATOR.bend";
import { resolveLook, STATES } from './motion.ts';

export function unpackHistory(h: any): any {
  if (h.$ === 'none') return undefined;
  return { state: STATES[h.state], mood: h.arc === 1 ? 'happy' : 'neutral', age: h.age,
    ...(h.from.$ === 'none' ? {} : { blend: { from: unpackHistory(h.from), t: h.t } }) };
}
export function createAnimator() {
  let state = A.init();
  return {
    step(input: any) {
      const look = resolveLook(input);
      const step = A.step(state, input.now, STATES.indexOf(look.state), look.mood === 'happy' ? 1 : 0,
        input.target?.x ?? 0, input.target?.y ?? 0, !!input.target, !!input.hold, input.reducedMotion);
      state = step.next;
      return {
        gaze: step.weight > 0 ? { x: step.follow.x, y: step.follow.y, weight: step.weight } : undefined,
        motionBlend: step.history.$ === 'none' ? undefined : { from: unpackHistory(step.history), t: step.progress },
        stateAge: step.age, moving: step.moving,
      };
    },
    reset() { state = A.init(); },
  };
}
