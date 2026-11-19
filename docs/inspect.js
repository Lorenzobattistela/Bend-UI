// The docs' live example for the inspect extension: a panel to read. Measures draws its padding and gaps;
// Inspect shows the values of the part you click; Comment drops a pin where you click.
import { INSPECT, readBoxes, readBox, readPart, partsOf, draw, facts, key, nameOf } from "../inspect.js";

export function mountInspectDocs() {
  const $ = (id) => document.getElementById(id);
  const host = $("inspect-host"), piece = $("inspect-piece"), layer = $("inspect-layer"), out = $("inspect-out"), said = $("inspect-said");
  const S = { measures: true, tool: "", hover: null, picked: null, pins: [] };

  function paint() {
    const parts = partsOf(piece), box = (i) => (i == null || !parts[i] ? null : readBox(parts[i]));
    draw(layer, { boxes: S.measures ? readBoxes(piece) : [], at: { x: layer.getBoundingClientRect().left, y: layer.getBoundingClientRect().top },
      hover: S.tool ? box(S.hover) : null, picked: S.tool === "inspect" ? box(S.picked) : null,
      pins: S.pins.map((p, i) => ({ box: box(p.part), fx: p.fx, fy: p.fy, label: i + 1 })).filter((p) => p.box) });
    host.dataset.tool = S.tool;
    $("inspect-key").innerHTML = S.measures ? key() : "";
    const el = S.picked == null ? null : parts[S.picked];
    out.innerHTML = S.tool === "inspect" && el ? facts(readPart(el)) : "";
    said.textContent = S.tool === "inspect" ? (el ? "" : "Click a part of the panel to read its values.")
      : S.tool === "comment" ? (S.pins.length ? `${S.pins.length} pinned. The last one is on ${nameOf(parts[S.pins.at(-1).part])}.` : "Click a part of the panel to pin a comment on it.")
      : "Turn Inspect or Comment on, then click a part of the panel.";
  }

  document.querySelector("[data-inspect-tools]").addEventListener("click", (e) => {
    const b = e.target.closest("button[data-tool]"); if (!b) return;
    if (b.dataset.tool === "measures") S.measures = !S.measures;
    else { S.tool = S.tool === b.dataset.tool ? "" : b.dataset.tool; S.hover = null; }
    for (const x of e.currentTarget.querySelectorAll("button[data-tool]")) x.setAttribute("aria-pressed", x.dataset.tool === "measures" ? S.measures : S.tool === x.dataset.tool);
    paint();
  });
  // While a tool is on, a click on the piece reads the part and does nothing else.
  piece.addEventListener("click", (e) => {
    if (!S.tool) return;
    e.preventDefault(); e.stopPropagation();
    const part = partsOf(piece).indexOf(e.target), r = e.target.getBoundingClientRect();
    if (S.tool === "inspect") S.picked = part;
    else S.pins.push({ part, fx: (e.clientX - r.left) / r.width, fy: (e.clientY - r.top) / r.height });
    paint();
  }, true);
  piece.addEventListener("pointermove", (e) => { if (!S.tool) return; const i = partsOf(piece).indexOf(e.target); if (i !== S.hover) { S.hover = i; paint(); } });
  piece.addEventListener("pointerleave", () => { if (S.hover != null) { S.hover = null; paint(); } });
  new ResizeObserver(paint).observe(host);
  // The page is hidden until it is picked: it paints when it shows.
  new IntersectionObserver((list) => list.forEach((e) => { if (e.isIntersecting) paint(); })).observe(host);
  document.fonts?.ready.then(paint);

  // Laws: none yet. The page lists its measures, each undecided, as the Panes page does.
  const doc = document.querySelector('[data-page="inspect"] .doc'), section = document.createElement("section");
  const values = Object.keys(INSPECT).filter((k) => k.startsWith("inspect_") && typeof INSPECT[k]() === "number").map((k) => [k, INSPECT[k]()]);
  section.className = "section";
  section.innerHTML = `<h2 class="section-title">Laws</h2><div class="section__body"><p class="detail">None yet. Every measure is marked <strong>undecided</strong>: it shows, without a law, until the owner locks it.</p>` +
    `<div class="docs-board-values"><div class="docs-board-row docs-board-head"><span>value</span><span>is</span><span>in</span><span>state</span></div>` +
    values.map(([k, v]) => `<div class="docs-board-row"><span class="mono">${k}</span><span class="mono">${v}</span><span class="mono">INSPECT.bend</span><span><span class="tag tag--warning">undecided</span></span></div>`).join("") + "</div></div>";
  doc.append(section);
}
