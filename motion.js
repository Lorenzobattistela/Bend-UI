// Bend-UI: motions that take a page from one place to another (opt-in: import { … } from "bend-ui/motion").
// Every number is MOTION.bend's or a token; this file only measures and draws. With reduced motion nothing
// moves: each function leaves things as they end and resolves at once.
//
//   plusIcon(name)          an icon drawn as a plus, which can open into the icon `name` (one outline, like folder)
//   becomeIcon(svg)         the plus opens into its icon; from then on it is that icon
//   arriveNew(btn)          something new in a side bar (.btn.is-new): its ground shows, its plus turns into place
//   settleNew(btn)          it is made: the ground lets go while the plus becomes its icon
//   leaveNew(el)            nothing came of it: it goes and the room it took closes (take it off the page after)
//   makeRoom(el)            the room a new piece takes opens
//   popIn(el, wait)         a small thing (a state's dot) pops into place
//   liftWords(el)           words leave where they are; .land(target) takes them there, to become the target
//   stepBack(els, toward)   what a place said steps back toward where that place lives; resolves to a release()
//   stepForward(els, from)  and comes forward again from there
//   moveFrom(el, rect)      a piece that is in both places glides from where it was
//   holdStill(canvas)       a picture of a canvas where it is, to stand in while the page changes under it
//   arrive(els, wait)       the pieces of the next place come one after another
//   swapWords(el, text)     a label changes its words
//   nudge(el)               a small answer: the piece grows a little and comes back
import T from "./TOKENS.bend";
import M from "./MOTION.bend";

const less = matchMedia("(prefers-reduced-motion: reduce)");
const SVG = "http://www.w3.org/2000/svg";
const play = (el, frames, opts) => (less.matches ? Promise.resolve() : el.animate(frames, opts).finished.catch(() => {}));
const onRail = (el) => { const side = el.closest(".side"); return !!side && !side.classList.contains("is-open") && !side.closest("[data-narrow]"); };

// ---------- A plus that opens into an icon ----------
// The icon's outline as points along it, and where each starts on the plus (MOTION.bend: plus_x, plus_y).
const lines = new Map();
function lineOf(name) {
  if (lines.has(name)) return lines.get(name);
  const src = document.querySelector(`#i-${CSS.escape(name)} path`);
  let line = null;
  if (src) {
    const svg = document.createElementNS(SVG, "svg"), path = document.createElementNS(SVG, "path");
    svg.setAttribute("width", "0"); svg.setAttribute("height", "0"); svg.style.position = "absolute";
    path.setAttribute("d", src.getAttribute("d")); svg.append(path); document.body.append(svg);
    const len = path.getTotalLength(), n = Number(M.plus_points()), icon = [], plus = [];
    for (let i = 0; i < n; i++) { const p = path.getPointAtLength((len * i) / n); icon.push([p.x, p.y]); plus.push([M.plus_x(p.x, p.y), M.plus_y(p.x, p.y)]); }
    svg.remove();
    line = { icon, plus };
  }
  lines.set(name, line);
  return line;
}
const drawn = (line, p) => "M" + line.icon.map((b, i) => `${M.mix(line.plus[i][0], b[0], p).toFixed(2)} ${M.mix(line.plus[i][1], b[1], p).toFixed(2)}`).join("L") + "Z";

export function plusIcon(name = "folder") {
  const svg = document.createElementNS(SVG, "svg"), line = lineOf(name);
  svg.setAttribute("class", "icon"); svg.setAttribute("aria-hidden", "true");
  if (!line) { svg.innerHTML = '<use href="#i-plus"/>'; return svg; }   // no outline to open into: a plain plus
  svg.setAttribute("viewBox", "0 0 24 24"); svg.dataset.becomes = name;
  svg.innerHTML = `<path d="${drawn(line, 0)}"/>`;
  return svg;
}
export function becomeIcon(svg) {
  const name = svg.dataset.becomes, line = name && lineOf(name), path = svg.querySelector("path");
  const end = () => { if (!name) return; svg.removeAttribute("viewBox"); delete svg.dataset.becomes; svg.innerHTML = `<use href="#i-${name}"/>`; };
  if (!line || !path || less.matches) { end(); return Promise.resolve(); }
  const time = Number(M.become_ms()), whole = time + Number(M.become_settle_ms());
  const shape = new Promise((done) => {
    const t0 = performance.now(); let over = false;
    const finish = () => { if (over) return; over = true; path.setAttribute("d", drawn(line, 1)); done(); };
    const step = (now) => {
      if (over) return;
      const x = (now - t0) / time;
      if (x >= 1) return finish();
      path.setAttribute("d", drawn(line, M.ease_in_out(Math.max(0, x)))); requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
    setTimeout(finish, time + 400);   // a page that isn't being drawn gets no frame
  });
  const size = play(svg, [
    { transform: "scale(1)", easing: "ease-out" },
    { transform: `scale(${M.become_gather()})`, offset: M.become_gather_at(), easing: "ease-in-out" },
    { transform: `scale(${M.become_over()})`, offset: M.become_over_at(), easing: "ease-in-out" },
    { transform: "scale(1)" },
  ], { duration: whole });
  return Promise.all([shape, size]).then(end);
}

// ---------- Something new in a side bar ----------
export function arriveNew(btn) {
  const rail = onRail(btn), icon = btn.querySelector(".icon");
  return Promise.all([
    play(btn, rail ? [{ opacity: 0, transform: `scale(${M.new_in_scale()})` }, { opacity: 1, transform: "scale(1)" }] : [{ opacity: 0 }, { opacity: 1 }],
      { duration: Number(M.new_in_ms()), easing: rail ? T.ease_spring() : T.ease() }),
    icon && play(icon, [{ opacity: 0, transform: `scale(${M.plus_in_scale()}) rotate(${M.plus_in_turn()}deg)` }, { opacity: 1, transform: "scale(1) rotate(0deg)" }],
      { duration: Number(M.plus_in_ms()), delay: Number(M.plus_in_wait_ms()), easing: T.ease_spring(), fill: "backwards" }),
  ]);
}
// state: its state's dot, already in place; it pops in as the icon lands.
export function settleNew(btn, { state = null } = {}) {
  const icon = btn.querySelector("svg[data-becomes]");
  const was = getComputedStyle(btn), from = { backgroundColor: was.backgroundColor, color: was.color };
  const own = btn.style.transition; btn.style.transition = "none";   // its own short fade would hide where it ends
  btn.classList.remove("is-new");
  const is = getComputedStyle(btn), to = { backgroundColor: is.backgroundColor, color: is.color };
  btn.offsetWidth; btn.style.transition = own;
  return Promise.all([play(btn, [from, to], { duration: Number(M.become_ms()), easing: T.ease() }), icon && becomeIcon(icon), state && popIn(state, Number(M.become_ms()) - T.duration_ms())]);
}
export async function leaveNew(el) {
  if (less.matches) return;
  const rail = onRail(el), h = el.offsetHeight, hold = { fill: "forwards", easing: T.ease() };
  await play(el, rail ? [{ opacity: 1, transform: "scale(1)" }, { opacity: 0, transform: `scale(${M.new_out_scale()})` }] : [{ opacity: 1 }, { opacity: 0 }], { duration: Number(M.new_out_ms()), ...hold });
  el.style.overflow = "hidden";
  await play(el, [{ height: h + "px" }, { height: "0px" }], { duration: Number(M.room_ms()), ...hold });
}
export function makeRoom(el) {
  return play(el, [{ height: "0px" }, { height: el.offsetHeight + "px" }], { duration: Number(M.room_ms()), easing: T.ease() });
}
export function popIn(el, wait = 0) {
  return play(el, [{ transform: "scale(0)" }, { transform: "scale(1)" }], { duration: Number(M.pop_ms()), delay: wait, easing: T.ease_spring(), fill: "backwards" });
}

// ---------- Words that travel ----------
// Where the words sit in an element (it may hold an icon before them).
function wordsIn(el) {
  const walk = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
  let n, first = null, last = null;
  while ((n = walk.nextNode())) if (n.textContent.trim()) { first ||= n; last = n; }
  if (!first) return null;
  const r = document.createRange(); r.setStartBefore(first); r.setEndAfter(last);
  return r.getBoundingClientRect();
}
// The words leave `from` (which hides) as a copy that stays where they were, whatever the page does under it.
// land(to): the copy goes to `to`, taking its size, color, ground and corners on the way, and `to` shows as
// it lands. drop(): they never left. Both put `from` back as it was.
export function liftWords(from, text = from.textContent) {
  if (less.matches) return { land: () => Promise.resolve(), drop() {} };
  const at = from.getBoundingClientRect(), was = getComputedStyle(from);
  const first = { fontSize: was.fontSize, fontWeight: was.fontWeight, color: was.color, backgroundColor: "rgba(0, 0, 0, 0)", paddingLeft: "0px", paddingRight: "0px", borderRadius: "0px", textDecorationColor: was.color, height: at.height + "px", transform: "translate(0px, 0px)" };
  const fly = document.createElement("span");
  fly.className = "fly-words"; fly.textContent = text;
  Object.assign(fly.style, { left: at.left + "px", top: at.top + "px", fontFamily: was.fontFamily, textDecorationLine: was.textDecorationLine }, first);
  document.body.append(fly);
  const shown = from.style.visibility; from.style.visibility = "hidden";
  let gone = false;
  const drop = () => { if (gone) return; gone = true; fly.remove(); from.style.visibility = shown; };
  return {
    drop,
    async land(to) {
      const box = to?.getBoundingClientRect();
      if (gone || !box || !box.width) { drop(); return; }
      const will = getComputedStyle(to), words = wordsIn(to) || box, own = to.style.visibility;
      to.style.visibility = "hidden";
      const last = { fontSize: will.fontSize, fontWeight: will.fontWeight, color: will.color, backgroundColor: will.backgroundColor, paddingLeft: words.left - box.left + "px", paddingRight: box.right - words.right + "px", borderRadius: will.borderRadius, textDecorationColor: "rgba(0, 0, 0, 0)", height: box.height + "px", transform: `translate(${box.left - at.left}px, ${box.top - at.top}px)` };
      await fly.animate([first, last], { duration: Number(M.words_ms()), easing: T.ease(), fill: "forwards" }).finished.catch(() => {});
      to.style.visibility = own; drop();
    },
  };
}

// ---------- Stepping back, and what comes in its place ----------
function step(els, toward, forward) {
  if (less.matches) return Promise.resolve(() => {});
  const home = toward?.getBoundingClientRect(), held = [];
  const release = () => { held.forEach((a) => a.cancel()); els.forEach((x) => { x.style.transformOrigin = ""; }); };
  const small = { opacity: 0, transform: `scale(${M.step_scale()})` }, whole = { opacity: 1, transform: "scale(1)" };
  return Promise.all(els.map((x) => {
    const box = x.getBoundingClientRect();
    if (home && home.width) x.style.transformOrigin = `${home.left + home.width / 2 - box.left}px ${home.top + home.height / 2 - box.top}px`;
    const a = x.animate(forward ? [small, whole] : [whole, small], { duration: Number(forward ? M.step_forward_ms() : M.step_back_ms()), easing: T.ease(), fill: forward ? "none" : "forwards" });
    held.push(a);
    return a.finished.catch(() => {});
  })).then(() => { if (forward) release(); return release; });
}
export const stepBack = (els, toward) => step(els, toward, false);
export const stepForward = (els, from) => step(els, from, true);
export function moveFrom(el, was) {
  const is = el.getBoundingClientRect();
  if (!was || !was.width || !is.width) return Promise.resolve();
  return play(el, [{ transform: `translate(${was.left - is.left}px, ${was.top - is.top}px)` }, { transform: "translate(0px, 0px)" }], { duration: T.duration_connect_ms(), easing: T.ease() });
}
// from: "below" (they rise into place), "side" (a name beside its icon) or "here" (they only show: a piece
// that is turned or moved by its own rule keeps it).
export function arrive(els, wait = 0, from = "below") {
  const first = from === "here" ? { opacity: 0 } : { opacity: 0, transform: from === "side" ? `translateX(${-M.arrive_rise()}px)` : `translateY(${M.arrive_rise()}px)` };
  const last = from === "here" ? { opacity: 1 } : { opacity: 1, transform: "none" };
  return Promise.all(els.map((x, i) => play(x, [first, last],
    { duration: T.duration_enter_ms(), delay: wait + i * Number(M.arrive_stagger_ms()), easing: T.ease(), fill: "backwards" })));
}
// A label changes its words: the old ones go, the new ones come from the side.
export async function swapWords(el, text) {
  if (el.textContent && el.textContent !== text) await play(el, [{ opacity: 1 }, { opacity: 0 }], { duration: Number(M.words_out_ms()), easing: T.ease(), fill: "forwards" });
  el.getAnimations().forEach((a) => a.cancel());
  el.textContent = text;
  await arrive([el], 0, "side");
}
// A small answer: the piece grows a little and comes back.
export function nudge(el) {
  return play(el, [{ transform: "scale(1)" }, { transform: `scale(${M.nudge_scale()})`, offset: M.nudge_at() }, { transform: "scale(1)" }], { duration: Number(M.nudge_ms()), easing: T.ease_spring() });
}
// A picture of a canvas (the fairy's ball), fixed where the canvas is, to stand in while the page under it is
// swapped: a canvas that was just put on the page is blank until its first frame. let() takes it away, after
// `frames` frames of the page (the new one has drawn itself by then).
export function holdStill(canvas, frames = 2) {
  const none = { let() {} };
  if (less.matches || !canvas || !canvas.width) return none;
  const box = canvas.getBoundingClientRect();
  if (!box.width) return none;
  const still = document.createElement("canvas");
  still.className = "fly-still"; still.width = canvas.width; still.height = canvas.height;
  still.getContext("2d")?.drawImage(canvas, 0, 0);
  Object.assign(still.style, { left: box.left + "px", top: box.top + "px", width: box.width + "px", height: box.height + "px" });
  document.body.append(still);
  return { let() { let n = frames; const wait = () => (n-- > 0 ? requestAnimationFrame(wait) : still.remove()); wait(); setTimeout(() => still.remove(), 400); } };
}
