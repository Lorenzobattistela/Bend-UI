// Browser adapter for Fairy. Geometry and motion come from Bend; Open Bot draws.
import F from "./FAIRY.bend";
import B from "./FAIRY_MOTION.bend";
import { mountAvatar } from "./fairy-renderer/dom/mount.ts";
import { pointerGaze } from "./fairy-renderer/follow.ts";

export const fairy = Object.freeze({
  version: 1, id: "fairy", name: "Fairy",
  body: { path: F.path() },
  eyes: { x: 50, y: F.eye_y(), spacing: F.eye_spacing(), scale: F.eye_scale() },
});

// A decorative canvas inside mountAgent's accessible face button.
export function mountFairy(host, options = {}) {
  const avatar = mountAvatar(host, {
    definition: fairy, color: "var(--fairy-color)", eyeColor: "var(--fairy-ink)",
    followPointer: true, label: "", ...options,
  });
  let gesture = null;
  return {
    update: (next) => avatar.update(next),
    lookAt(x, y, amount = 1) {
      const gaze = pointerGaze({ x, y }, host.getBoundingClientRect(), { x: .5, y: F.eye_y() / 100 });
      avatar.update({ lookAt: { x: gaze.x * amount, y: gaze.y * amount } });
    },
    follow() { avatar.update({ lookAt: null }); },
    spin() { gesture = { kind: "spin", start: performance.now() }; },
    shake() { gesture = { kind: "shake", start: performance.now() }; },
    tick(now, reduced) {
      if (!gesture) return;
      const age = now - gesture.start;
      const done = reduced || B.turn_done(age);
      const yaw = done ? 0 : gesture.kind === "spin" ? B.turn_angle(0, B.tau(), age) : B.shake_angle(age);
      avatar.update({ view: { yaw, pitch: 0 } });
      if (done) gesture = null;
    },
    destroy() { gesture = null; avatar.destroy(); },
  };
}
