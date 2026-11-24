// Inspect (opt-in): import "bend-ui/inspect".
//   import { readBoxes, readPart, draw, facts, groups, key, nameOf, tokenName } from "bend-ui/inspect";
// What is drawn over a piece of interface to read it: its padding, margins and gaps with their numbers, the part under
// the pointer, the part picked, a pin where a comment points. INSPECT.bend decides every band and names every
// value on the scale; this file reads the boxes from the page and draws what Bend returns.
//
//   <div class="inspect-host"> the piece … <div class="inspect"></div></div>
//   draw(layer, { boxes: readBoxes(piece), at: layer.getBoundingClientRect(), picked, hover, pins });
//
// The boxes are plain numbers, so they can come from another document (a page in a frame reads its own boxes
// and sends them): draw() only needs them in the same measures as `at`, the layer's own corner.
import "./inspect.css";
import I from "./INSPECT.bend";

const root = document.documentElement.style;
for (const [k, v] of Object.entries(I)) if (k.startsWith("inspect_") && typeof v === "function" && v.length === 0 && typeof v() === "number")
  root.setProperty("--" + k.replace(/_/g, "-"), k.endsWith("_layer") ? String(v()) : /_(tint|share)$/.test(k) ? v() + "%" : v() + "px");
export { I as INSPECT };

// Compiled Bend Bool crosses the JavaScript boundary as a native boolean or as { $: "True" }.
const yes = (b) => b === true || b?.$ === "True";
const array = (l) => { const out = []; for (; l.$ === "Con"; l = l.tail) out.push(l.head); return out; };
const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const px = (v) => parseFloat(v) || 0;
const num = (n) => String(Math.round(n * 10) / 10);
const rect = (el) => { const r = el.getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height }; };

// ---------- Reading the page ----------
// A part's name, as a person would point at it: its tag and its first class.
export const nameOf = (el) => (el ? el.tagName.toLowerCase() + (el.classList[0] ? "." + el.classList[0] : "") : "");
// The parts of a piece: the piece itself and everything inside it, in the page's order.
export const partsOf = (piece) => [piece, ...piece.querySelectorAll("*")];

const sides = (c, what) => [px(c[what + "Top"]), px(c[what + "Right"]), px(c[what + "Bottom"]), px(c[what + "Left"])];
// A child's box with its margin: the room a gap is counted from.
const outer = (el) => { const r = rect(el), [t, e, b, l] = sides(getComputedStyle(el), "margin"); return { x: r.x - l, y: r.y - t, w: r.w + l + e, h: r.h + t + b }; };
// One part's box, as draw() reads it: where it is (in the window's measures), its padding, its margin, its
// gaps and its children's boxes (only when it lays them out with a gap).
export function readBox(el) {
  const c = getComputedStyle(el), flow = /flex|grid/.test(c.display), rowGap = flow ? px(c.rowGap) : 0, colGap = flow ? px(c.columnGap) : 0;
  return { ...rect(el), pad: sides(c, "padding"), margin: sides(c, "margin"), rowGap, colGap,
    kids: rowGap || colGap ? [...el.children].filter((k) => k.offsetWidth && k.offsetHeight).map(outer) : [] };
}
export const readBoxes = (piece) => partsOf(piece).map(readBox);

// One part's values, as facts() shows them.
export function readPart(el) {
  const c = getComputedStyle(el), r = rect(el), flow = /flex|grid/.test(c.display);
  return { name: nameOf(el), w: r.w, h: r.h, pad: sides(c, "padding"), margin: sides(c, "margin"),
    gap: flow ? px(c.rowGap) || px(c.columnGap) : 0, radius: px(c.borderTopLeftRadius), size: px(c.fontSize), weight: c.fontWeight };
}

// ---------- A value's name on the scale ----------
// "space_4", "radius_md", or "" when the number is no token (INSPECT.bend holds the scale).
export function tokenName(n, kind = "space") {
  if (!Number.isInteger(n) || n <= 0) return "";
  return kind === "radius" ? I.radius_name(n) : I.space_name(n);
}
const value = (n, kind) => {
  if (!n) return "0";
  const name = tokenName(Math.round(n * 10) / 10, kind);
  return `${num(n)}px ` + (name ? `<span class="tag tag--mono">${name}</span>` : `<span class="tag tag--warning">off the scale</span>`);
};

// ---------- Drawing ----------
const at = (cls, x, y, w, h, inner = "") => `<i class="${cls}" style="left:${num(x)}px;top:${num(y)}px;width:${num(w)}px;height:${num(h)}px">${inner}</i>`;
const band = (b) => at("inspect__band inspect__band--" + (b.kind === I.gap() ? "gap" : b.kind === I.margin() ? "margin" : "pad"), b.x, b.y, b.w, b.h, yes(b.says) ? `<b class="inspect__n">${num(b.n)}</b>` : "");

function bandsOf(b, o) {
  const [pt, pr, pb, pl] = b.pad, x = b.x - o.x, y = b.y - o.y;
  const out = array(I.pad(x, y, b.w, b.h, pt, pr, pb, pl));
  if (b.margin) out.push(...array(I.around(x, y, b.w, b.h, ...b.margin)));
  for (let i = 0; i + 1 < b.kids.length; i++) {
    const a = b.kids[i], n = b.kids[i + 1];
    out.push(...array(I.between(x + pl, y + pt, b.w - pl - pr, b.h - pt - pb, a.x - o.x, a.y - o.y, a.w, a.h, n.x - o.x, n.y - o.y, n.w, n.h, b.rowGap, b.colGap)));
  }
  return out;
}

// draw(layer, what): draws over a piece. Everything in `what` is optional:
//   boxes    the parts to measure (readBoxes); their padding, margins and gaps are drawn
//   at       the layer's own corner, { x, y }, in the same measures as the boxes ({ x: 0, y: 0 } when left out)
//   hover    a box: the part under the pointer
//   picked   a box: the part picked
//   pins     [{ box, fx, fy, label, fresh }]: a pin at that part of its box (0 to 1); fresh is the one being written
export function draw(layer, { boxes = [], at: o = { x: 0, y: 0 }, hover = null, picked = null, pins = [] } = {}) {
  let h = boxes.flatMap((b) => bandsOf(b, o)).map(band).join("");
  if (hover) h += at("inspect__box", hover.x - o.x, hover.y - o.y, hover.w, hover.h);
  if (picked) h += at("inspect__box inspect__box--picked", picked.x - o.x, picked.y - o.y, picked.w, picked.h);
  for (const p of pins) h += `<i class="inspect__pin${p.fresh ? " inspect__pin--new" : ""}" style="left:${num(I.along(p.box.x - o.x, p.box.w, p.fx))}px;top:${num(I.along(p.box.y - o.y, p.box.h, p.fy))}px">${esc(p.label ?? "")}</i>`;
  layer.innerHTML = h;
}

// The key: which color is which space.
export const key = () => `<span class="inspect-key">${[["pad", "padding"], ["margin", "margin"], ["gap", "gap"]].map(([k, name]) => `<span class="inspect-key__item"><i class="inspect-key__mark inspect-key__mark--${k}"></i>${name}</span>`).join("")}</span>`;

// A part's values (readPart), grouped as a person reads them: the part and whether any value is off the scale
// first, then Space (padding, gap, margin), Shape (size, corner) and Text (size, weight). Four equal sides say one
// number, two pairs say two ("13 · 24"). Each number has its token, or "off the scale".
export function groups(part) {
  const off = (n, kind = "space") => n > 0 && !tokenName(Math.round(n * 10) / 10, kind);
  const short = (a) => (a[0] === a[2] && a[1] === a[3] ? (a[0] === a[1] ? [a[0]] : [a[0], a[1]]) : a);
  const vals = (ns, kind = "space") => ns.map((n) => value(n, kind)).join('<span class="inspect-groups__dot">·</span>');
  const row = (name, html) => `<div class="inspect-groups__row"><span class="inspect-groups__name">${name}</span><span class="inspect-groups__val">${html}</span></div>`;
  const group = (title, rows) => (rows ? `<div class="inspect-groups__group"><h4 class="group-title">${title}</h4>${rows}</div>` : "");
  const pad = part.pad || [0, 0, 0, 0], margin = part.margin || [0, 0, 0, 0];
  const count = [...new Set(pad)].filter((n) => off(n)).length + [...new Set(margin)].filter((n) => off(n)).length + (off(part.gap) ? 1 : 0) + (off(part.radius, "radius") ? 1 : 0);
  const space = (pad.some(Boolean) ? row("Padding", vals(short(pad))) : "") + (part.gap ? row("Gap", vals([part.gap])) : "") + (margin.some(Boolean) ? row("Margin", vals(short(margin))) : "");
  const shape = row("Size", `${Math.round(part.w)} × ${Math.round(part.h)}`) + (part.radius ? row("Corner", vals([part.radius], "radius")) : "");
  const text = row("Size", num(part.size) + "px") + row("Weight", esc(part.weight));
  return `<div class="inspect-groups"><div class="inspect-groups__head"><span class="section-title inspect-groups__part">${esc(part.name)}</span>`
    + (count ? `<span class="tag tag--warning">${count} off the scale</span>` : `<span class="tag tag--success">on the scale</span>`) + `</div>`
    + `<div class="inspect-groups__body">${group("Space", space)}${group("Shape", shape)}${group("Text", text)}</div></div>`;
}

// A part's values (readPart), as rows: each space and corner with its token, or "off the scale".
export function facts(part) {
  const rows = [["Part", `<span class="tag tag--mono">${esc(part.name)}</span>`], ["Size", `${Math.round(part.w)} × ${Math.round(part.h)}px`],
    ...["top", "right", "bottom", "left"].map((side, i) => ["Padding " + side, value(part.pad[i], "space")]),
    ...["top", "right", "bottom", "left"].map((side, i) => ["Margin " + side, value(part.margin?.[i] || 0, "space")]).filter((_, i) => part.margin?.[i]),
    ["Gap", value(part.gap, "space")], ["Corner", value(part.radius, "radius")], ["Text size", num(part.size) + "px"], ["Weight", esc(part.weight)]];
  return `<dl class="inspect-facts">${rows.map(([a, b]) => `<dt>${a}</dt><dd>${b}</dd>`).join("")}</dl>`;
}
