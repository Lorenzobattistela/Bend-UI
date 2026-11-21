// Bend-UI web driver: runs a page written in Bend (Web.bend). Nothing here decides what the page
// shows. Bend gives the view (render) and says what changed since the last one (PATCH.bend); this file
// makes the nodes, carries each instruction of the patch out, and sends what the person does back.
//
//   import { start } from "bend-ui/web-driver";      // a page with no Bend-UI
//   import Main from "./main.bend";
//   start(Main);                                      // into <div id="app">
//
//   import { mount } from "bend-ui/web";              // the same, with Bend-UI's pieces alive
//   const app = mount(element, Program, { adopt: true });
//
// The loop is the one Lorenzo Battistela wrote for DungeonBend's port to the new Bend (branch
// port/bend-new, web/driver.js): init, render, on_event, the commands, the clock and the key root are
// his, and a page written for his driver runs on this one. What differs:
// - the comparison of two views is Bend's (PATCH.bend), not this file's;
// - one listener per kind of event, on the window, instead of one per node set again at every draw.
//   It runs after ui.js's own, so Bend-UI acts on the page as it was when the person clicked;
// - a clock (every_ms) keeps running across draws while its interval is the same;
// - the state is kept only after render gave the next view;
// - events that carry something (typed text, a key, a pointer) go through the program's on_input.
//
// Bend values as JS sees them: a constructor is {$: "name", field: value}, a String is a string, a
// U32 is a number, a List is {$: "Con", head, tail} or {$: "Nil"}, a function field is a JS function.
//
// Limits now:
// - The nodes this driver makes are its own. Another script may add nodes among them (Bend-UI's
//   segmented thumb, a field's message) and those are left alone; it must not take the driver's away.
//   If it does, the whole view is made again on the next draw.
// - A field with an input or change event shows what Bend renders: while the person types in it the
//   driver leaves its text alone, and puts Bend's text there when the field is committed or left.

import P from "./PATCH.bend";

const list = (xs) => { const out = []; for (let at = xs; at.$ === "Con"; at = at.tail) out.push(at.head); return out; };
const SVG = "http://www.w3.org/2000/svg";
const OWN = Symbol("bend");   // on a node this driver made: what Bend bound to it
const LOST = Symbol("lost");  // thrown when the page no longer has the nodes the last view had
const KIND = {
  click: "click", double_click: "dblclick", input: "input", change: "change", key_down: "keydown",
  pointer_down: "pointerdown", pointer_move: "pointermove", pointer_up: "pointerup",
};
const mac = /Mac|iPhone|iPad|iPod/.test(navigator.platform);
// Modifiers as SPEC.bend counts them: 1 Mod (Cmd on a Mac, Ctrl elsewhere), 2 Shift, 4 Alt.
const modsOf = (e) => ((mac ? e.metaKey : e.ctrlKey) ? 1 : 0) + (e.shiftKey ? 2 : 0) + (e.altKey ? 4 : 0);
const codeOf = (e) => ((typeof e.which === "number" ? e.which : e.keyCode) ?? 0) >>> 0;

// Attributes
// ==========

const owned = (node) => node[OWN] ?? (node[OWN] = { on: {}, clocks: new Map(), keyRoot: false, value: undefined });

function set(el, a, app) {
  const own = owned(el);
  switch (a.$) {
    case "attr": {
      if (a.name === "value" && "value" in el) {
        own.value = a.value;
        if (app.typing !== el && el.value !== a.value) el.value = a.value;
        return;
      }
      if (a.name === "data-key-root") own.keyRoot = true;   // the page root asks for key presses
      el.setAttribute(a.name, a.value);
      return;
    }
    case "prop": { if (a.name in el) el[a.name] = a.value; else el.setAttribute(a.name, a.value); return; }
    case "style": { el.style.setProperty(a.name, a.value); return; }
    case "on": {
      const kind = KIND[a.event.$];
      if (!kind) throw new Error("unknown Web.DomEvent: " + a.event.$);
      own.on[kind] = a.event.msg;
      return;
    }
    case "every_ms": {
      const ms = a.ms >>> 0, clock = own.clocks.get(ms);
      if (clock) { clock.msg = a.msg; return; }   // the same interval: it keeps its beat and gets the new message
      const made = { msg: a.msg, timer: 0 };
      made.timer = setInterval(() => app.dispatch(made.msg), ms);
      own.clocks.set(ms, made);
      return;
    }
    default: throw new Error("unknown Web.Attr: " + a.$);
  }
}

function unset(el, a) {
  const own = owned(el);
  switch (a.$) {
    case "attr": {
      if (a.name === "value" && "value" in el) { own.value = undefined; el.value = ""; }
      if (a.name === "data-key-root") own.keyRoot = false;
      el.removeAttribute(a.name);
      return;
    }
    case "prop": { if (a.name in el) el[a.name] = ""; el.removeAttribute(a.name); return; }
    case "style": { el.style.removeProperty(a.name); return; }
    case "on": { delete own.on[KIND[a.event.$]]; return; }
    case "every_ms": {
      const ms = a.ms >>> 0, clock = own.clocks.get(ms);
      if (clock) { clearInterval(clock.timer); own.clocks.delete(ms); }
      return;
    }
    default: throw new Error("unknown Web.Attr: " + a.$);
  }
}

// Nodes
// =====

// The children of a node that this driver made, in order. Another script's nodes among them are skipped.
const mine = (el) => { const out = []; for (const n of el.childNodes) if (n[OWN]) out.push(n); return out; };
const svgInside = (el) => el.namespaceURI === SVG && el.localName !== "foreignObject";

function make(view, app, svg) {
  if (view.$ === "text") { const t = document.createTextNode(view.value); t[OWN] = true; return t; }
  if (view.$ !== "node") throw new Error("unknown Web.HTML: " + view.$);
  const isSvg = svg || view.tag === "svg";
  const el = isSvg ? document.createElementNS(SVG, view.tag) : document.createElement(view.tag);
  owned(el);
  for (const a of list(view.attrs)) set(el, a, app);
  const kidSvg = isSvg && view.tag !== "foreignObject";
  for (const kid of list(view.kids)) el.appendChild(make(kid, app, kidSvg));
  return el;
}

// A node leaves the page: its clocks stop, and so do the ones inside it.
function drop(node) {
  const own = node[OWN];
  if (own && own !== true) { for (const c of own.clocks.values()) clearInterval(c.timer); own.clocks.clear(); }
  for (const kid of node.childNodes) drop(kid);
}

// Carries one patch out on the node it is about. Returns the node that stands there afterwards.
function apply(node, patch, app) {
  switch (patch.$) {
    case "keep": return node;
    case "retext": { node.nodeValue = patch.value; return node; }
    case "swap": {
      if (node === app.root) throw new Error("the element a page is mounted on can't change its tag");
      const parent = node.parentNode;
      const made = make(patch.node, app, !!parent && svgInside(parent));
      parent.replaceChild(made, node);
      drop(node);
      return made;
    }
    case "edit": {
      for (const a of list(patch.dels)) unset(node, a);
      for (const a of list(patch.sets)) set(node, a, app);
      const kids = mine(node), patches = list(patch.kids), cut = Number(patch.cut);
      if (kids.length !== patches.length + cut) throw LOST;
      for (let i = 0; i < patches.length; i++) apply(kids[i], patches[i], app);
      for (let i = 0; i < cut; i++) { const last = kids.pop(); drop(last); node.removeChild(last); }
      let after = mine(node).pop();
      for (const view of list(patch.adds)) {
        const made = make(view, app, svgInside(node));
        if (after) after.after(made); else node.appendChild(made);
        after = made;
      }
      return node;
    }
    default: throw new Error("unknown Patch: " + patch.$);
  }
}

// The first view. Adopting, the mount element stands for the view's own root node: it takes the
// root's attributes and children, and keeps whatever it already had.
function first(app, view) {
  if (app.adopt) {
    if (view.$ !== "node") throw new Error("a page that adopts its element renders a node, not a text");
    owned(app.root);
    for (const a of list(view.attrs)) set(app.root, a, app);
    for (const kid of list(view.kids)) app.root.appendChild(make(kid, app, svgInside(app.root)));
  } else {
    app.dom = make(view, app, false);
    app.root.replaceChildren(app.dom);
  }
  app.view = view;
}

function draw(app, next) {
  try {
    const patch = P.diff(app.view, next).head;
    if (app.adopt) apply(app.root, patch, app); else app.dom = apply(app.dom, patch, app);
  } catch (e) {
    if (e !== LOST) throw e;
    // The page lost nodes the last view had: make the whole view again.
    if (app.adopt) { for (const n of mine(app.root)) { drop(n); n.remove(); } } else drop(app.dom);
    first(app, next);
  }
  app.view = next;
  app.patched?.(app.root);
}

// Events
// ======

const apps = new Set();

// The elements between the event's target and the app's root, innermost first.
function path(app, target) {
  const out = [];
  for (let el = target; el; el = el.parentNode) { if (el.nodeType === 1) out.push(el); if (el === app.root) return out; }
  return null;
}

function payload(e, el) {
  if (e.type === "input" || e.type === "change") {
    const v = e.target.value;
    return { $: "typed", value: typeof v === "string" ? v.toWellFormed?.() ?? v : "" };
  }
  if (e.type === "keydown") return { $: "key", name: e.key.toLowerCase(), mods: modsOf(e), code: codeOf(e) };
  const box = el.getBoundingClientRect();
  return { $: "point", x: Math.fround(e.clientX - box.left), y: Math.fround(e.clientY - box.top), buttons: e.buttons >>> 0, mods: modsOf(e) };
}

// Puts back what Bend last rendered in a field Bend listens to (the person may have typed something
// Bend formats another way, or refuses).
function settle(el) {
  const own = el[OWN];
  if (own && own !== true && own.value !== undefined && (own.on.input !== undefined || own.on.change !== undefined) && el.value !== own.value) el.value = own.value;
}

function handle(e) {
  if ((e.type === "input" || e.type === "change") && e instanceof CustomEvent) return;   // Bend-UI's own change on a segmented
  for (const app of apps) {
    const els = path(app, e.target);
    if (!els) continue;
    for (const el of els) {
      const own = el[OWN];
      if (!own || own === true) continue;
      if (e.type === "keydown" && own.keyRoot) {   // the old on_key_down of the page root
        e.preventDefault();
        app.dispatch(app.program.key_event(app.state, codeOf(e)));
      }
      const msg = own.on[e.type];
      if (msg === undefined) continue;
      if (e.type === "click" || e.type === "dblclick") { app.dispatch(msg); continue; }
      if (typeof app.program.on_input !== "function") throw new Error("the page binds a " + e.type + " event, so its program needs on_input(msg, got)");
      const ev = app.program.on_input(msg, payload(e, el));
      if (typeof ev === "function") throw new Error("on_input takes two arguments: the message and what the browser handed over");
      if (e.type === "pointerdown" && (own.on.pointermove !== undefined || own.on.pointerup !== undefined)) el.setPointerCapture?.(e.pointerId);
      if (e.type === "input") { app.typing = e.target; try { app.dispatch(ev); } finally { app.typing = null; } }
      else app.dispatch(ev);
    }
    if (e.type === "change") settle(e.target);
  }
}
const left = (e) => { for (const app of apps) if (path(app, e.target)) settle(e.target); };

function listen(on) {
  for (const kind of Object.values(KIND)) (on ? addEventListener : removeEventListener)(kind, handle);
  (on ? addEventListener : removeEventListener)("focusout", left);
}

// Commands
// ========

function runCmd(cmd, app) {
  switch (cmd.$) {
    case "none": return;
    case "batch": { for (const sub of list(cmd.cmds)) runCmd(sub, app); return; }
    case "delay": { setTimeout(() => app.dispatch(cmd.event), cmd.ms >>> 0); return; }
    case "store_get": {
      let value = null;
      try { value = localStorage.getItem(cmd.key); } catch {}
      app.dispatch(typeof value === "string" ? cmd.on_some(value) : cmd.on_none);
      return;
    }
    case "store_set": { try { localStorage.setItem(cmd.key, cmd.value); } catch {} app.dispatch(cmd.event); return; }
    case "store_del": { try { localStorage.removeItem(cmd.key); } catch {} app.dispatch(cmd.event); return; }
    default: throw new Error("unknown Web.Cmd: " + cmd.$);
  }
}

// App
// ===

// mount(root, program, options): runs a program on an element.
//   adopt: the element stands for the view's root node (it keeps the children it already has, and the
//     view's children are added after them). Without it, the view replaces what is inside the element.
//   patched(root): called after the first draw and after every draw.
//   changed(state, before): called after an event changed the state.
// Returns { program, state, dispatch(ev), set(state, { render }), view(), stop() }.
//   dispatch(ev): send an event, as a click would.
//   set(state): replace the state from outside and draw it; { render: false } keeps the page as it is
//     until the next event (for a state that changes every frame).
export function mount(root, program, { adopt = false, patched, changed } = {}) {
  if (!root) throw new Error("mount needs an element");
  const boot = program.init();
  const app = { root, program, adopt, patched, changed, state: boot.state, view: null, dom: null, typing: null, on: true };
  app.dispatch = (ev) => {
    if (!app.on) return;
    const result = program.on_event(ev, app.state), before = app.state;
    draw(app, program.render(result.state));   // render first: if it throws, the state and the page stay as they were
    app.state = result.state;
    app.changed?.(app.state, before);
    runCmd(result.cmd, app);
  };
  first(app, program.render(app.state));
  if (!apps.size) listen(true);
  apps.add(app);
  app.patched?.(root);
  const handle = {
    program,
    get state() { return app.state; },
    dispatch: app.dispatch,
    set(state, { render = true } = {}) { app.state = state; if (render && app.on) draw(app, program.render(state)); },
    view: () => app.view,
    stop() {
      app.on = false;
      apps.delete(app);
      if (!apps.size) listen(false);
      if (app.adopt) { drop(app.root); } else if (app.dom) drop(app.dom);
    },
  };
  runCmd(boot.cmd, app);
  return handle;
}

// start(program): the program on <div id="app">, as DungeonBend's driver starts it.
export function start(program) {
  const root = document.getElementById("app");
  if (root === null) throw new Error("missing #app mount node");
  const app = mount(root, program);
  // For the browser console and for tests: the live state and the last view.
  globalThis.__dungeonbend = { app, view: app.view, game: program };
  return app;
}
