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
import { mountAgent } from "./agent.js";
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
  const agents = new Map();
  function syncAgents(r) {
    const slots = new Set(all(r, "[data-ui-agent]"));
    for (const [el, entry] of agents) {
      const key = `${el.dataset.uiAgent}|${el.dataset.size}`;
      if (!slots.has(el) || key !== entry.key) {
        entry.face.destroy(); entry.host.remove(); agents.delete(el);
      }
    }
    for (const el of slots) {
      let entry = agents.get(el);
      if (!entry) {
        const host = document.createElement("div"); el.append(host);
        const face = mountAgent(host, { avatar: el.dataset.uiAgent, size: el.dataset.size, still: true, state: el.dataset.state, mood: el.dataset.mood });
        entry = { host, face, key: `${el.dataset.uiAgent}|${el.dataset.size}`, state: el.dataset.state, mood: el.dataset.mood };
        agents.set(el, entry);
      }
      if (entry.state !== el.dataset.state) { entry.face.setState(el.dataset.state); entry.state = el.dataset.state; }
      if (entry.mood !== el.dataset.mood) { entry.face.setMood(el.dataset.mood); entry.mood = el.dataset.mood; }
    }
  }
  const app = run(root, program, { ...options, patched(r) { alive(r); syncAgents(r); options.patched?.(r); } });
  const stop = app.stop;
  app.stop = () => { for (const entry of agents.values()) { entry.face.destroy(); entry.host.remove(); } agents.clear(); stop(); };
  return app;
}

// start(program): the program on <div id="app">.
export function start(program) {
  const root = document.getElementById("app");
  if (root === null) throw new Error("missing #app mount node");
  return mount(root, program);
}
