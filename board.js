// Board, lane and card (opt-in): import "bend-ui/board".
// Every number in BOARD.bend becomes a CSS variable (card_padding_left → --card-padding-left), like ui.js does with TOKENS.bend.
import { squeezeOut, stretchIn } from "./ui.js";
import "./board.css";
import B from "./BOARD.bend";
import D from "./DRAG.bend";
import M from "./MOTION.bend";
import T from "./TOKENS.bend";

const px = (n) => n + "px";
const root = document.documentElement.style;
for (const [key, value] of Object.entries(B)) if (typeof value === "function" && value.length === 0 && typeof value() === "number") root.setProperty("--" + key.replace(/_/g, "-"), px(value()));

// The default shape, until theme({ radius }) picks one.
const shape = B.board_default_shape();
root.setProperty("--board-card-radius", `var(--card-radius-${shape})`);
root.setProperty("--board-lane-radius", `var(--lane-radius-${shape})`);
root.setProperty("--board-foot-justify", { start: "flex-start", end: "flex-end", between: "space-between" }[B.card_foot_align()]);

// Compiled Bend Bool crosses the JavaScript boundary as a native boolean or as { $: "True" }.
const bool = (b) => b === true || b?.$ === "True";
const yes = bool;

// How a card is put together: what it shows and in which order. The app writes the markup; these say what goes where.
export const card = {
  titleRole: B.card_title_role(),
  tagOnTop: B.card_tag_row() === "top",
  footOrder: B.card_foot_order(),
  shows: { id: bool(B.card_shows_id()), menu: bool(B.card_shows_menu()), tag: bool(B.card_shows_tag()), who: bool(B.card_shows_who()) },
};
export { B as BOARD };

// ---------- Complete: the circle before a card's title ----------
// cardCheck(done, labels) is the markup: put it first inside .card__title. initBoard's onDone(id, done) hears the click.
const attr = (t) => String(t).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
export const checkLabels = { mark: "Mark complete", unmark: "Mark incomplete" };
export function cardCheck(done, { labels = checkLabels } = {}) {
  const L = { ...checkLabels, ...labels }, say = done ? L.unmark : L.mark;
  return `<span class="card__mark"><button class="card__check" type="button" aria-pressed="${!!done}" aria-label="${attr(say)}">` +
    `<svg class="icon" aria-hidden="true"><use href="#i-check"/></svg><svg class="status-ring" viewBox="0 0 40 40" aria-hidden="true"><circle cx="20" cy="20" r="19" pathLength="100"/></svg>` +
    `</button><span class="tooltip" aria-hidden="true">${attr(say)}</span></span>`;
}
// Marks a card done or not, on the page: the ring draws only when it becomes done now.
export function setDone(card, done, labels = checkLabels) {
  const L = { ...checkLabels, ...labels }, b = card.querySelector(".card__check");
  card.classList.toggle("is-done", done);
  if (!b) return;
  b.classList.remove("is-just"); void b.offsetWidth; b.classList.toggle("is-just", done);
  b.setAttribute("aria-pressed", String(done));
  b.setAttribute("aria-label", done ? L.unmark : L.mark);
  b.nextElementSibling.textContent = done ? L.unmark : L.mark;
}

// ---------- Drag: pick a card up, the others make room, it settles where it lands ----------
// DRAG.bend decides (when a press becomes a drag, where the card lands, when a spring has settled);
// MOTION.bend's spring moves everything. This file only measures, and draws what they return.

const still = matchMedia("(prefers-reduced-motion: reduce)");

// Moves el from an offset (dx, dy) back to its place, with the spring. Resolves when it settles.
function settle(el, dx, dy) {
  if (still.matches || (!dx && !dy)) { el.style.translate = ""; return Promise.resolve(); }
  return new Promise((done) => {
    let x = dx, y = dy, vx = 0, vy = 0, last = performance.now();
    const frame = (now) => {
      // A frame's time can be a little before the moment we started: never step backwards, never more than two frames.
      const dt = Math.min(0.032, Math.max(0, (now - last) / 1000)); last = Math.max(last, now);
      vx = M.spring(vx, x, 0, dt); vy = M.spring(vy, y, 0, dt);
      x += vx * dt; y += vy * dt;
      if (yes(D.settled(x, 0, vx)) && yes(D.settled(y, 0, vy))) { el.style.translate = ""; el.__settle = null; return done(); }
      el.style.translate = `${x}px ${y}px`;
      el.__settle = requestAnimationFrame(frame);
    };
    cancelAnimationFrame(el.__settle);
    el.__settle = requestAnimationFrame(frame);
  });
}

// Runs change(), then slides every card that moved from where it was (FLIP), so nothing jumps.
function slide(board, change) {
  const cards = [...board.querySelectorAll(".card:not(.is-lifted)")];
  const before = new Map(cards.map((c) => [c, c.getBoundingClientRect()]));
  change();
  for (const c of cards) {
    const a = before.get(c), b = c.getBoundingClientRect();
    const dx = a.left - b.left, dy = a.top - b.top;
    if (dx || dy) settle(c, dx + (parseFloat(c.style.translate) || 0), dy + (parseFloat(c.style.translate?.split(" ")[1]) || 0));
  }
}

// initBoard(board, { canDrag(card), onDrop(id, laneId, beforeId), onDone(id, done), labels }): cards drag with a mouse, a pen or a finger.
// Cards need data-id, lanes data-lane. onDrop runs after the card has settled, when the page shows it where it landed.
// Clicking a card's circle (cardCheck) marks it done on the page, then onDone tells the app. The card stays where it is,
// unless the app takes it to another lane (moveCard, below).
export function initBoard(board, { canDrag = () => true, onDrop = () => {}, onDone = () => {}, labels = checkLabels } = {}) {
  let press = null, drag = null;
  board.addEventListener("click", (e) => {
    const b = e.target.closest(".card__check"); if (!b) return;
    const card = b.closest(".card"), done = !card.classList.contains("is-done");
    setDone(card, done, labels);
    onDone(card.dataset.id, done);
  });
  const interactive = "button, a, input, textarea, select, [role=menu], [contenteditable]";

  board.addEventListener("pointerdown", (e) => {
    const card = e.target.closest(".card");
    if (!card || e.button !== 0 || e.target.closest(interactive) || !canDrag(card) || drag) return;
    press = { card, x: e.clientX, y: e.clientY, id: e.pointerId };
  });

  const lift = (e) => {
    const { card } = press, r = card.getBoundingClientRect();
    const slot = document.createElement("div");
    slot.className = "card-slot"; slot.style.height = r.height + "px";
    card.after(slot);
    card.classList.add("is-lifted");
    Object.assign(card.style, { position: "fixed", left: r.left + "px", top: r.top + "px", width: r.width + "px", margin: "0" });
    board.append(card);   // out of its lane, still inside the board (keeps the board's shape)
    drag = { card, slot, from: card.dataset.id, grabX: press.x - r.left, grabY: press.y - r.top };
    try { board.setPointerCapture(press.id); } catch {}
    board.classList.add("is-dragging");
    document.documentElement.classList.add("is-board-dragging");
    getSelection()?.removeAllRanges();
    place(e);
  };

  // The lane under the pointer, and the card the slot goes before (DRAG.bend.lands_before).
  const place = (e) => {
    const { card, slot } = drag;
    card.style.left = e.clientX - drag.grabX + "px";
    card.style.top = e.clientY - drag.grabY + "px";
    const lanes = [...board.querySelectorAll(".lane")];
    const lane = lanes.find((l) => { const r = l.getBoundingClientRect(); return e.clientX >= r.left && e.clientX <= r.right; });
    lanes.forEach((l) => l.classList.toggle("is-over", l === lane));
    if (!lane) return;
    const list = lane.querySelector(".lane__cards");
    const next = [...list.querySelectorAll(":scope > .card")].find((c) => { const r = c.getBoundingClientRect(); return yes(D.lands_before(e.clientY, r.top, r.height)); }) ?? null;
    if (slot.parentElement === list && slot.nextElementSibling === next) return;
    slide(board, () => list.insertBefore(slot, next));
  };

  // Near the board's left or right edge, the board scrolls while the card is held there (DRAG.bend.scroll_step).
  let roll = 0, lastMove = null;
  const scroll = () => {
    roll = 0;
    if (!drag || !lastMove) return;
    const r = board.getBoundingClientRect();
    const step = D.scroll_step(lastMove.clientX - r.left) - D.scroll_step(r.right - lastMove.clientX);
    if (Math.round(step) !== 0) { board.scrollLeft -= step; place(lastMove); roll = requestAnimationFrame(scroll); }
  };

  board.addEventListener("pointermove", (e) => {
    if (drag) { lastMove = e; if (!roll) roll = requestAnimationFrame(scroll); return place(e); }
    if (press && e.pointerId === press.id && yes(D.starts(e.clientX - press.x, e.clientY - press.y))) lift(e);
  });

  const drop = async () => {
    press = null;
    if (!drag) return;
    const { card, slot } = drag; drag = null;
    cancelAnimationFrame(roll); roll = 0; lastMove = null;
    // The click that ends a drag is not a click on the card.
    const swallow = (e) => { e.stopPropagation(); e.preventDefault(); };
    addEventListener("click", swallow, { capture: true, once: true });
    setTimeout(() => removeEventListener("click", swallow, { capture: true }), 0);
    const lane = slot.closest(".lane");
    const before = slot.nextElementSibling?.closest(".card")?.dataset.id ?? null;
    const from = card.getBoundingClientRect();
    card.classList.remove("is-lifted");
    for (const k of ["position", "left", "top", "width", "margin"]) card.style[k] = "";
    slot.replaceWith(card);
    board.querySelectorAll(".is-over").forEach((l) => l.classList.remove("is-over"));
    const to = card.getBoundingClientRect();
    await settle(card, from.left - to.left, from.top - to.top);
    board.classList.remove("is-dragging");
    document.documentElement.classList.remove("is-board-dragging");
    getSelection()?.removeAllRanges();
    if (lane) onDrop(card.dataset.id, lane.dataset.lane, before);
  };
  // Pressing a card and moving doesn't select text anywhere on the page, during the drag or after it.
  document.addEventListener("selectstart", (e) => { if (press || drag) e.preventDefault(); });
  addEventListener("pointerup", () => { if (!drag) press = null; });   // a press that ends off the board, without a drag
  board.addEventListener("pointerup", drop);
  board.addEventListener("pointercancel", drop);
  // While a drag runs, the page doesn't scroll or select text under the finger.
  board.addEventListener("touchmove", (e) => { if (drag) e.preventDefault(); }, { passive: false });
}

// ---------- A new card: the field becomes the card ----------
// newCard(placeholder, label) is the markup: a .card with a .card__field (a textarea) that grows with its text.
// fitField(field) keeps the field as tall as its text. formCard(card, from) grows a card just put in place from
// `from` px (the field's height) to its own height, and its rows rise rise_distance into it one after another, with
// the menu's rise (MOTION.bend: rise_time_ms, rise_stagger_ms, rise_ease). Reduced motion: it just shows.
export const newCard = (placeholder = "", label = placeholder) =>
  `<div class="card"><textarea class="card__field ${attr(B.card_title_role())}" rows="1" placeholder="${attr(placeholder)}" aria-label="${attr(label)}"></textarea></div>`;
export function fitField(field) {
  const fit = () => { field.style.height = "auto"; field.style.height = px(field.scrollHeight); };
  field.addEventListener("input", fit); fit();
}
const formEase = () => ({ spring: T.ease_spring(), ease: T.ease() })[M.rise_ease()] ?? (getComputedStyle(document.documentElement).getPropertyValue("--ease-in-out").trim() || "ease-in-out");
export function formCard(card, from) {
  if (still.matches || !card) return;
  const t = { duration: M.rise_time_ms(), easing: formEase() }, h = card.offsetHeight;
  card.style.overflow = "hidden";
  card.animate([{ height: px(from) }, { height: px(h) }], t).finished.finally(() => (card.style.overflow = ""));
  [...card.children].forEach((row, i) => row.animate([{ opacity: 0, transform: `translateY(${px(T.rise_distance())})` }, { opacity: 1, transform: "none" }], { ...t, delay: i * M.rise_stagger_ms(), fill: "backwards" }));
}

// ---------- A card changes lane without crossing the board ----------
// moveCard(card, list, { before, wait, onSwap }) takes a card to a lane's .lane__cards: before the card `before`, or at
// the end. It waits `wait` ms (checkTime() lets a card just completed finish its green ring), closes on its own middle
// (ui.js: squeezeOut), the room it took closes while its new room opens, and it opens there (stretchIn). onSwap runs
// when it changes place, so a count can follow. The board takes no clicks meanwhile. Resolves when the card is in
// place. The same call brings it back. Reduced motion: it is just put there.
export const checkTime = () => T.duration_ms() * 5;   // the ring a completed card draws (board.css: card-ring-out)
// An empty box where a card was or will be: it grows or closes with the lane's gap, so the lane follows and nothing jumps.
function room(list, place, from, to) {
  const slot = document.createElement("div");
  place(slot);
  const gap = parseFloat(getComputedStyle(list).rowGap) || 0, alone = list.children.length === 1, row = B.card_row();   // an empty lane keeps card_row
  const at = (h) => (alone ? { height: px(Math.max(h, row)), marginBottom: px(0) } : { height: px(h), marginBottom: px(h ? 0 : -gap) });
  Object.assign(slot.style, at(from));
  return { slot, run: () => slot.animate([at(from), at(to)], { duration: M.space_time_ms(), easing: T.ease(), fill: "forwards" }).finished.catch(() => {}) };
}
export async function moveCard(card, list, { before = null, wait = 0, onSwap = () => {} } = {}) {
  const board = card.closest(".board"), from = card.parentElement;
  const put = (el) => list.insertBefore(el, before?.parentElement === list ? before : null);
  if (still.matches) { put(card); onSwap(); return; }
  if (board) board.inert = true;
  try {
    const pause = wait + M.move_hold_ms();
    if (pause) await new Promise((ok) => setTimeout(ok, pause));
    if (!card.isConnected || !list.isConnected) return;   // the page drew the board again meanwhile
    const h = card.offsetHeight;
    await squeezeOut(card);
    if (!card.isConnected || !list.isConnected) return;
    const a = room(from, (s) => card.replaceWith(s), h, 0), b = room(list, put, 0, h);
    onSwap();
    await Promise.all([a.run(), b.run()]);
    a.slot.remove(); b.slot.replaceWith(card);
    await stretchIn(card);
  } finally { if (board) board.inert = false; }
}

// ---------- Open card: the dialog a card opens into ----------
// cardDialog(dialog) turns a <dialog class="dialog"> into the open card (board.css: .card-dialog). Its open() shows it
// card_dialog_open_top from the top of the screen and its rows rise in one after another (MOTION.bend's rise); the
// textareas (.card-dialog__field) keep as tall as their text (fitField), and the box follows: it grows down, moves up when
// it touches the bottom and stops at the top (BOARD.bend: card_dialog_top); only then its middle scrolls. close() fades it
// out. Escape and a click outside close it too. Reduced motion: it just shows.
export function cardDialog(dialog) {
  dialog.classList.add("card-dialog");
  dialog.dataset.edit = B.card_dialog_editable();
  root.setProperty("--card-dialog-open-height", B.card_dialog_open_height());
  let last = 0, busy = false;
  const gap = () => T.dialog_screen_gap();
  const place = (animate) => {
    if (!dialog.open) return;
    const run = dialog.getAnimations().find((a) => a.id === "grow");
    let fromH = last, fromTop = parseFloat(dialog.style.top) || B.card_dialog_open_top();
    if (run) { const r = dialog.getBoundingClientRect(); fromH = r.height; fromTop = r.top; run.cancel(); }
    const h = dialog.offsetHeight, top = B.card_dialog_top(B.card_dialog_open_top(), innerHeight, gap(), Math.ceil(h));
    dialog.style.top = px(top); last = h;
    dialog.classList.toggle("is-full", h >= innerHeight - 2 * gap() - 0.5);
    if (!animate || busy || still.matches || (Math.abs(h - fromH) < 0.5 && Math.abs(top - fromTop) < 0.5)) return;
    dialog.classList.add("is-growing");
    const a = dialog.animate([{ height: px(fromH), top: px(fromTop) }, { height: px(h), top: px(top) }], { duration: M.rise_time_ms(), easing: formEase() });
    a.id = "grow";
    a.finished.catch(() => {}).then(() => { if (!dialog.getAnimations().some((x) => x.id === "grow")) dialog.classList.remove("is-growing"); });
  };
  const close = () => {
    if (!dialog.open) return Promise.resolve();
    dialog.getAnimations().forEach((a) => a.cancel());
    if (still.matches) { dialog.close(); return Promise.resolve(); }
    return dialog.animate([{ opacity: 1 }, { opacity: 0 }], { duration: T.duration_ms(), easing: T.ease() }).finished.then(() => dialog.close(), () => dialog.close());
  };
  dialog.addEventListener("input", (e) => { if (e.target.matches?.(".card-dialog__field")) place(true); });
  dialog.addEventListener("cancel", (e) => { e.preventDefault(); close(); });
  dialog.addEventListener("click", (e) => {
    if (e.target !== dialog) return;   // a click on the backdrop lands on the dialog itself, outside its box
    const r = dialog.getBoundingClientRect();
    if (e.clientX < r.left || e.clientX > r.right || e.clientY < r.top || e.clientY > r.bottom) close();
  });
  addEventListener("resize", () => place(false));
  return {
    open() {
      dialog.getAnimations().forEach((a) => a.cancel());
      dialog.style.top = px(B.card_dialog_open_top());
      if (!dialog.open) dialog.showModal();
      dialog.querySelectorAll(".card-dialog__field").forEach(fitField);
      place(false);
      if (still.matches) return;
      busy = true;
      const t = { duration: M.rise_time_ms(), easing: formEase() }, h = dialog.offsetHeight;
      const body = dialog.querySelector(".card-dialog__body");
      const rows = [...dialog.children].flatMap((c) => (c === body ? [...c.children] : [c]));
      const list = [dialog.animate([{ height: px(T.control_xl()), minHeight: "0px", opacity: 0 }, { height: px(h), minHeight: "0px", opacity: 1 }], t)];
      rows.forEach((row, i) => list.push(row.animate([{ opacity: 0, transform: `translateY(${px(T.rise_distance())})` }, { opacity: 1, transform: "none" }], { ...t, delay: i * M.rise_stagger_ms(), fill: "backwards" })));
      Promise.all(list.map((a) => a.finished.catch(() => {}))).then(() => { list.forEach((a) => a.cancel()); busy = false; place(false); });
    },
    close,
  };
}
