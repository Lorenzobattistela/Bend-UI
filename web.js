// Bend-UI web: a page written in Bend (Web.bend, UI.bend), with Bend-UI's pieces alive on it.
//
//   import { mount } from "bend-ui/web";
//   import Program from "./panels.bend";
//   mount(document.getElementById("panels"), Program, { adopt: true });
//
// It is web-driver.js plus what ui.js needs to know about nodes that Bend adds after the page
// loaded: a segmented gets its thumb, an area its measure, a hold button its timer. And when Bend
// changes which choice of a segmented is pressed, ui.js is told, so the thumb travels there.
// Importing this file turns Bend-UI on, as importing "bend-ui" does.

import { initSegmented, initArea, initButtons } from "./ui.js";
import { mount as run } from "./web-driver.js";

const pressed = new WeakMap();   // each segmented's pressed button at the last draw
const ready = new WeakSet();     // buttons initButtons has already seen
const all = (root, sel) => [...(root.matches(sel) ? [root] : []), ...root.querySelectorAll(sel)];

function alive(root) {
  for (const group of all(root, ".segmented--slide, .segmented--extend")) initSegmented(group);   // does nothing the second time
  for (const area of all(root, ".area")) initArea(area);
  const fresh = all(root, ".btn--hold, .btn[data-reserve]").filter((b) => !ready.has(b));
  if (fresh.length) { fresh.forEach((b) => ready.add(b)); initButtons(); }
  // Bend holds a segmented's choice (data-manual), so ui.js fires no change of its own: say it here.
  for (const group of all(root, ".segmented[data-manual]")) {
    const on = group.querySelector(':scope > button[aria-pressed="true"]');
    if (pressed.has(group) && pressed.get(group) !== on) group.dispatchEvent(new CustomEvent("change", { detail: on }));
    pressed.set(group, on);
  }
}

// mount(root, program, options): as web-driver.js's mount (adopt, patched, changed).
export function mount(root, program, options = {}) {
  return run(root, program, { ...options, patched(r) { alive(r); options.patched?.(r); } });
}

// start(program): the program on <div id="app">.
export function start(program) {
  const root = document.getElementById("app");
  if (root === null) throw new Error("missing #app mount node");
  return mount(root, program);
}
