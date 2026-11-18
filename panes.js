// Panes, tree, terminal and strip (opt-in): import "bend-ui/panes".
//   import { initPane, setPane, setPaneSize, tree, initTree, mountTerm } from "bend-ui/panes";
// Every number in PANES.bend becomes a CSS variable (pane_width → --pane-width), like board.js does with BOARD.bend.
// The logic is Bend: PANES.bend bounds a pane's size, TREE.bend turns paths into rows and keys into moves,
// TERM.bend folds output into lines and says what a key sends. This file reads the pointer and the keyboard,
// and draws what they return. The strip is CSS only.
import { announce } from "./ui.js";
import "./panes.css";
import P from "./PANES.bend";
import TREE from "./TREE.bend";
import TERM from "./TERM.bend";
import T from "./TOKENS.bend";

const px = (n) => n + "px";
const root = document.documentElement.style;
// A layer is a plain number; everything else is a length.
for (const [key, value] of Object.entries(P)) if (typeof value === "function" && value.length === 0 && typeof value() === "number") root.setProperty("--" + key.replace(/_/g, "-"), key.endsWith("_layer") ? String(value()) : px(value()));
export { P as PANES };

// Compiled Bend Bool crosses the JavaScript boundary as a native boolean or as { $: "True" }.
const yes = (b) => b === true || b?.$ === "True";
const list = (xs) => xs.reduceRight((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
const array = (l) => { const out = []; for (; l.$ === "Con"; l = l.tail) out.push(l.head); return out; };
const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const still = matchMedia("(prefers-reduced-motion: reduce)");
// Motion as the side bar's sections: duration_enter and ease. Reduced motion: none.
const move = (el, frames) => (still.matches ? Promise.resolve() : el.animate(frames, { duration: T.duration_enter_ms(), easing: T.ease() }).finished);
let uid = 0;

// ---------- Pane: beside the main column, or under it ----------
// <aside class="pane" id="files">…</aside> inside a .window__body, after its .window__col; a .pane--under goes last
// inside the .window__col. A pane with [hidden] takes no room.
//   initPane(pane, { onResize(size), onToggle(open), label })   adds the grip (.pane__grip) on the pane's inner edge.
//     Drag it with a mouse, a pen or a finger; focused, Left/Right (Up/Down under the column) step it, Home and
//     End take it to its smallest and largest; a double click puts the default back. PANES.bend bounds every size.
//     onResize hears the size (px) when a change ends; onToggle hears the pane open and close.
//   setPane(pane, open)         opens or closes it (it slides; reduced motion: at once).
//   setPaneSize(pane, size)     sets its size from code (a size the app kept), bounded the same way.
//   [data-pane-toggle="id"]     a button that opens and closes that pane (or, with no id, the pane it is in).
// Under [data-narrow] a side pane is a sheet over the column: the focus goes in when it opens and back when it
// closes, and Escape closes it.
const paneOpts = new WeakMap(), paneBack = new WeakMap(), paneSet = new WeakMap();
const isUnder = (pane) => pane.classList.contains("pane--under");
const isSheet = (pane) => !isUnder(pane) && !!pane.closest("[data-narrow]");
const paneOf = (b) => (b.dataset.paneToggle ? document.getElementById(b.dataset.paneToggle) : b.closest(".pane"));
const paneToggles = (pane) => [...document.querySelectorAll("[data-pane-toggle]")].filter((b) => paneOf(b) === pane);
// The room a pane shares with the column: the column's height under it; beside it, the body's width less the other panes.
function paneRoom(pane) {
  const box = pane.parentElement;
  if (isUnder(pane)) return Math.round(box.clientHeight);
  const others = [...box.children].filter((p) => p !== pane && p.matches(".pane:not(.pane--under):not([hidden])"));
  return Math.max(0, Math.round(box.clientWidth - others.reduce((w, p) => w + p.offsetWidth, 0)));
}
const paneSize = (pane) => Math.round(isUnder(pane) ? pane.offsetHeight : pane.offsetWidth);

export function initPane(pane, { onResize = () => {}, onToggle = () => {}, label } = {}) {
  paneOpts.set(pane, { onResize, onToggle });
  const under = isUnder(pane), title = pane.querySelector(":scope > .pane__head .pane__title");
  if (!pane.id) pane.id = "pane-" + ++uid;
  if (title && !pane.hasAttribute("aria-label") && !pane.hasAttribute("aria-labelledby")) pane.setAttribute("aria-labelledby", title.id || (title.id = pane.id + "-title"));
  paneToggles(pane).forEach((b) => { b.setAttribute("aria-expanded", String(!pane.hidden)); b.setAttribute("aria-controls", pane.id); });
  let grip = pane.querySelector(":scope > .pane__grip");
  if (grip?.dataset.ready) return;
  if (!grip) { grip = document.createElement("div"); grip.className = "pane__grip"; pane.prepend(grip); }
  grip.dataset.ready = "1";
  grip.setAttribute("role", "separator"); grip.tabIndex = 0;
  grip.setAttribute("aria-orientation", under ? "horizontal" : "vertical");
  grip.setAttribute("aria-controls", pane.id);
  if (label || !grip.hasAttribute("aria-label")) grip.setAttribute("aria-label", label ?? "Resize " + (pane.getAttribute("aria-label") || title?.textContent.trim() || "pane"));

  let wanted = null;   // the size the person asked for; null: the default
  const mark = () => {
    if (pane.hidden) return;
    const room = paneRoom(pane);
    grip.setAttribute("aria-valuemin", P.clamp(under, 0, room));
    grip.setAttribute("aria-valuemax", P.clamp(under, room, room));
    grip.setAttribute("aria-valuenow", paneSize(pane));
  };
  const set = (size) => {
    wanted = size === null ? null : Math.max(0, Math.round(size));
    if (wanted === null) pane.style.removeProperty("--pane-size");
    else pane.style.setProperty("--pane-size", px(P.clamp(under, wanted, paneRoom(pane))));
    mark();
  };
  // When the room changes (the window, another pane, a sheet that is a pane again), the size asked for is bounded again.
  const again = () => { if (wanted !== null && !pane.hidden) set(wanted); else mark(); };
  paneSet.set(pane, { set, again });
  const seen = new ResizeObserver(again);
  seen.observe(pane.parentElement); seen.observe(pane);

  let drag = null;
  const at = (e) => Math.max(0, Math.round(under ? e.clientY : e.clientX));
  grip.addEventListener("pointerdown", (e) => {
    if (e.button !== 0) return;
    e.preventDefault(); grip.focus({ preventScroll: true });
    try { grip.setPointerCapture(e.pointerId); } catch {}
    drag = { start: paneSize(pane), from: at(e) };
    pane.classList.add("is-resizing");
  });
  grip.addEventListener("pointermove", (e) => { if (drag) set(P.dragged(drag.start, drag.from, at(e))); });
  const drop = () => { if (!drag) return; drag = null; pane.classList.remove("is-resizing"); onResize(paneSize(pane)); };
  grip.addEventListener("pointerup", drop);
  grip.addEventListener("pointercancel", drop);
  grip.addEventListener("dblclick", () => { set(null); onResize(paneSize(pane)); });
  grip.addEventListener("keydown", (e) => {
    const step = P.grip_key(e.key, under);
    if (!step || e.ctrlKey || e.metaKey || e.altKey) return;
    e.preventDefault();
    set(P.stepped(paneSize(pane), step, paneRoom(pane)));
    onResize(paneSize(pane));
  });
  mark();
}

export function setPaneSize(pane, size) {
  const own = paneSet.get(pane);
  if (own) own.set(size); else pane.style.setProperty("--pane-size", px(P.clamp(isUnder(pane), Math.max(0, Math.round(size)), paneRoom(pane))));
}

export function setPane(pane, open) {
  if (!pane.hidden === open) return;
  const under = isUnder(pane), sheet = isSheet(pane), toggles = paneToggles(pane);
  toggles.forEach((b) => b.setAttribute("aria-expanded", String(open)));
  pane.getAnimations().forEach((a) => a.cancel());
  // A sheet slides over the column; a pane beside or under it slides in from the edge, and the column makes room.
  const size = () => px(under ? pane.offsetHeight : pane.offsetWidth);
  const frames = () => (sheet ? [{ transform: "translateX(100%)" }, { transform: "none" }]
    : under ? [{ marginBottom: "-" + size() }, { marginBottom: "0px" }] : [{ marginRight: "-" + size() }, { marginRight: "0px" }]);
  if (open) {
    paneBack.set(pane, document.activeElement);
    pane.hidden = false;
    move(pane, frames()).catch(() => {});
    if (sheet) (pane.querySelector(':is(button, a[href], input, textarea, select, [tabindex]:not([tabindex="-1"])):not(.pane__grip)') ?? pane).focus();
    paneSet.get(pane)?.again();   // the room may have changed while it was closed
  } else {
    const inside = pane.contains(document.activeElement), back = paneBack.get(pane);
    move(pane, frames().reverse()).then(() => { pane.hidden = true; }, () => {});
    if (inside) (back?.isConnected && back !== document.body ? back : toggles[0])?.focus();
  }
  paneOpts.get(pane)?.onToggle(open);
}

document.addEventListener("click", (e) => {
  const b = e.target.closest("[data-pane-toggle]"), pane = b && paneOf(b);
  if (pane) setPane(pane, pane.hidden);
});
// Escape closes a sheet, unless the key was someone else's: an open menu or the side bar's drawer (ui.js closes
// those first), or a terminal that sent it on.
let escTaken = false;
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") escTaken = !!document.querySelector(".dropdown > .menu:not([hidden])") || [...document.querySelectorAll(".side.is-open")].some((s) => s.closest("[data-narrow]") && s.getClientRects().length);
}, true);
document.addEventListener("keydown", (e) => {
  if (e.key !== "Escape" || escTaken || e.defaultPrevented) return;
  const sheet = [...document.querySelectorAll(".pane:not([hidden])")].filter(isSheet).pop();
  if (sheet) setPane(sheet, false);
});

// ---------- Tree: files and folders ----------
//   el.innerHTML = tree(paths, { open, current, marks, label });
//   const files = initTree(el.firstElementChild, { onOpen(path), onToggle(path, open) });
//   files.update(paths, { open, current, marks });   // the files changed: the folders that are open stay open
// paths: the files ("game/game.html"); a path ending in "/" is a folder with nothing in it. open: the folders that
// are open ("game"). current: the file that is open in the app. marks: { path: { add, del } }, shown as +14 −6.
// TREE.bend makes the rows (folders first, by name; every row is written, the ones in a closed folder hidden) and
// says what each key does; a click is Enter. No paths: tree() is "".
const icon = (name) => `<svg class="icon" aria-hidden="true"><use href="#i-${name}"/></svg>`;
function treeRows(paths, { open = [], current = "", marks = {}, active = "" } = {}) {
  const rows = TREE.rows(list(paths), list(open)), stop = TREE.tab_stop(rows, active ?? "", current ?? "");
  let html = "", level = 1, above = null;
  for (const r of array(rows)) {
    const folder = yes(r.folder), isOpen = yes(r.open), m = marks?.[r.path];
    if (r.level > level) { html += `<div class="tree__kids" role="group"${yes(above.open) ? "" : " hidden"}>`; level = Number(r.level); }
    for (; level > r.level; level--) html += "</div>";
    html += `<div class="tree__row" role="treeitem" tabindex="${r.path === stop ? 0 : -1}" data-path="${esc(r.path)}" title="${esc(r.path)}" aria-level="${r.level}" aria-posinset="${r.pos}" aria-setsize="${r.size}"` +
      (folder ? ` data-folder aria-expanded="${isOpen}"` : "") + (r.path === current ? ' aria-current="true"' : "") + ">" +
      icon(folder ? (isOpen ? "chevron-down" : "chevron-right") : "file-text") + `<span class="tree__name">${esc(r.name)}</span>` +
      (m?.add ? `<span class="tree__add">+${esc(m.add)}</span>` : "") + (m?.del ? `<span class="tree__del">−${esc(m.del)}</span>` : "") + "</div>";
    above = r;
  }
  for (; level > 1; level--) html += "</div>";
  return html;
}
export function tree(paths, { label = "Files", ...opts } = {}) {
  const rows = treeRows(paths, opts);
  return rows && `<div class="tree" role="tree" aria-label="${esc(label)}">${rows}</div>`;
}
// A folder's rows grow and shrink like the side bar's sections.
function growKids(kids, open) {
  kids.getAnimations().forEach((a) => a.cancel());
  kids.hidden = false;
  const frames = [{ height: "0px", opacity: 0 }, { height: px(kids.scrollHeight), opacity: 1 }];
  kids.style.overflow = "hidden";
  move(kids, open ? frames : frames.reverse()).then(() => { kids.style.overflow = ""; kids.hidden = !open; }, () => {});
}
export function initTree(el, { onOpen = () => {}, onToggle = () => {} } = {}) {
  const all = () => [...el.querySelectorAll(".tree__row")];
  const pathsNow = () => all().map((r) => r.dataset.path + ("folder" in r.dataset ? "/" : ""));
  const openNow = () => all().filter((r) => r.getAttribute("aria-expanded") === "true").map((r) => r.dataset.path);
  const rowAt = (path) => all().find((r) => r.dataset.path === path);
  let rows = null;   // TREE.bend's rows for what is on screen, made again after a folder opens or closes
  const model = () => (rows ??= TREE.rows(list(pathsNow()), list(openNow())));
  const stopAt = (row) => all().forEach((r) => (r.tabIndex = r === row ? 0 : -1));
  const toggle = (path, open) => {
    const row = rowAt(path), kids = row.nextElementSibling;
    row.setAttribute("aria-expanded", String(open));
    row.querySelector("use").setAttribute("href", open ? "#i-chevron-down" : "#i-chevron-right");
    rows = null;
    if (kids?.matches(".tree__kids")) growKids(kids, open);
    onToggle(path, open);
  };
  const act = (a) => {
    if (a.what === "focus") rowAt(a.path)?.focus();
    else if (a.what === "open" || a.what === "close") toggle(a.path, a.what === "open");
    else if (a.what === "pick") onOpen(a.path);
  };
  el.addEventListener("focusin", (e) => { const row = e.target.closest?.(".tree__row"); if (row) stopAt(row); });
  el.addEventListener("click", (e) => { const row = e.target.closest(".tree__row"); if (row) act(TREE.press(model(), row.dataset.path)); });
  el.addEventListener("keydown", (e) => {
    const row = e.target.closest(".tree__row");
    if (!row || e.ctrlKey || e.metaKey || e.altKey || !yes(TREE.takes(e.key))) return;
    e.preventDefault();
    act(TREE.key(model(), row.dataset.path, e.key));
  });
  return {
    // Draws the tree again. Left out, open stays as it is on screen and current stays the current file.
    update(paths, { open = openNow(), current = el.querySelector('.tree__row[aria-current="true"]')?.dataset.path ?? "", marks } = {}) {
      const active = el.contains(document.activeElement) ? document.activeElement.dataset.path : null;
      el.innerHTML = treeRows(paths, { open, current, marks, active: active ?? el.querySelector('.tree__row[tabindex="0"]')?.dataset.path });
      el.hidden = !el.firstChild;
      rows = null;
      if (active !== null) el.querySelector('.tree__row[tabindex="0"]')?.focus();
    },
  };
}

// ---------- Terminal: a surface ----------
//   const term = mountTerm(el, { onData(text), label });
//   term.write(text)   output to draw, as a process wrote it     term.clear()   term.focus()
// The lib runs nothing. TERM.bend folds the output into lines of colored pieces (feed) and says what each key
// sends (sent); this draws the lines and passes what is typed to onData. Nothing typed shows by itself: the
// shell echoes. It stays at the bottom while output arrives, unless the person scrolled up. New lines are said
// through announce(), once the output is still, while the terminal has the focus.
export function mountTerm(el, { onData = () => {}, label, hint = "Tab types a tab. To leave the terminal, press Escape, then Tab, or Shift+Tab." } = {}) {
  el.classList.add("term");
  el.tabIndex = 0;
  el.setAttribute("role", "textbox"); el.setAttribute("aria-multiline", "true"); el.setAttribute("aria-roledescription", "terminal");
  if (label || !el.hasAttribute("aria-label")) el.setAttribute("aria-label", label ?? "Terminal");
  const lines = document.createElement("div"), now = document.createElement("div"), how = document.createElement("span");
  now.className = "term__line";
  how.hidden = true; how.id = "term-hint-" + ++uid; how.textContent = hint;
  el.setAttribute("aria-describedby", how.id);
  el.replaceChildren(lines, now, how);

  let screen = TERM.new(), seen = 0, clears = 0, frame = 0, stick = true, heard = 0, sayT = 0, escaped = false;
  const span = (p) => { const s = document.createElement("span"), c = TERM.class_of(p.style); if (c) s.className = c; s.textContent = p.text; return s; };
  const spans = (l) => array(l).map(span);
  const draw = () => {
    frame = 0;
    if (TERM.clears(screen) !== clears) { clears = TERM.clears(screen); seen = 0; lines.replaceChildren(); }
    for (const line of array(TERM.fresh(screen, seen))) { const row = document.createElement("div"); row.className = "term__line"; row.append(...spans(line.pieces)); lines.append(row); }
    seen = TERM.total(screen);
    while (lines.childElementCount > TERM.scrollback()) lines.firstElementChild.remove();
    const caret = span(TERM.under(screen)); caret.classList.add("term__caret");
    now.replaceChildren(...spans(TERM.before(screen)), caret, ...spans(TERM.after(screen)));
    if (stick) el.scrollTop = el.scrollHeight;
  };
  const later = () => { frame ||= requestAnimationFrame(draw); };
  const say = () => { const text = TERM.said(screen, heard); heard = TERM.total(screen); if (text) announce(text); };
  el.addEventListener("scroll", () => { stick = el.scrollHeight - el.scrollTop - el.clientHeight < 2; });
  el.addEventListener("focus", () => { heard = TERM.total(screen); });
  el.addEventListener("blur", () => { escaped = false; clearTimeout(sayT); });
  const send = (data) => { stick = true; el.scrollTop = el.scrollHeight; onData(data); };
  el.addEventListener("keydown", (e) => {
    if (e.isComposing) return;
    const data = TERM.sent(e.key, e.ctrlKey, e.altKey, e.metaKey, e.shiftKey, escaped);
    if (!["Shift", "Control", "Alt", "Meta"].includes(e.key)) escaped = e.key === "Escape";
    if (!data) return;
    e.preventDefault();
    send(data);
  });
  el.addEventListener("paste", (e) => {
    const text = e.clipboardData?.getData("text");
    if (!text) return;
    e.preventDefault();
    send(TERM.pasted(text));
  });
  draw();
  return {
    write(text) {
      screen = TERM.feed(screen, String(text));
      later();
      if (document.activeElement === el) { clearTimeout(sayT); sayT = setTimeout(say, TERM.say_wait_ms()); }
    },
    clear() { screen = TERM.cleared(screen); stick = true; later(); },
    focus() { el.focus(); },
  };
}
