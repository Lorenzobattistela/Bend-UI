// Born right: the contract of the board components. Runs with `bun run check`, after the proof.
//  1. The rules of .board, .lane and .card use no --space-* and no loose px: only values from BOARD.bend (and the lib's colors and type).
//  2. Every value in BOARD.bend has a law (the owner locked it) or is marked "# undecided". Derived ones (card_width, lane_width) are made of others.
//  3. Every number in BOARD.bend reaches the screen (in the CSS, or through a derived value that does): no law guards something the screen doesn't use.
import fs from "fs";
const read = (f) => fs.readFileSync(new URL(f, import.meta.url), "utf8");
const css = read("./board.css").replace(/\/\*[\s\S]*?\*\//g, "");
const bend = read("./BOARD.bend"), laws = read("./BOARD_LAWS.bend"), js = read("./board.js");
const defs = [...bend.matchAll(/^def (\w+)\(\) -> (\w+): (.*)$/gm)].map((m) => ({ key: m[1], type: m[2], body: m[3] }));
// Variables the CSS declares itself, or board.js writes from a BOARD.bend choice, are not BOARD.bend numbers.
const local = new Set([...css.matchAll(/(--[a-z-]+)\s*:/g), ...js.matchAll(/setProperty\("(--[a-z-]+)"/g)].map((m) => m[1]));
const errors = [], used = new Set();
for (const m of css.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
  const sel = m[1].trim();
  if (!/(^|\s|,)\.(board|lane|card)(?![a-z-])/.test(sel)) continue;
  for (const d of m[2].split(";")) {
    const v = d.trim(); if (!v) continue;
    if (/var\(--space-/.test(v)) errors.push(`${sel} { ${v} }: --space-* used directly. Add a value to BOARD.bend.`);
    if (/(^|[\s(:])-?\d*\.?\d+px/.test(v.replace(/var\([^)]*\)/g, ""))) errors.push(`${sel} { ${v} }: loose px.`);
    for (const t of v.matchAll(/var\((--(?:card|lane|board)-[a-z-]+)\)/g)) if (!local.has(t[1])) used.add(t[1].slice(2).replace(/-/g, "_"));
  }
}
// A derived value in use pulls in the values it is made of.
let grew = true;
while (grew) { grew = false; for (const d of defs) if (used.has(d.key)) for (const r of d.body.matchAll(/(?<![.\w])(\w+)\(\)/g)) if (defs.some((x) => x.key === r[1]) && !used.has(r[1])) { used.add(r[1]); grew = true; } }
// The radius of each shape is read through --board-card-radius / --board-lane-radius.
for (const d of defs) if (/^(card|lane)_radius_/.test(d.key) && css.includes(`var(--${d.key.replace(/_/g, "-")})`)) used.add(d.key);
const pinned = (k) => new RegExp(`B\\.${k}\\(\\)`).test(laws);
for (const d of defs) {
  const derived = /^\(/.test(d.body), undecided = /# undecided/.test(d.body);
  if (!derived && !undecided && !pinned(d.key)) errors.push(`${d.key}: no law and not "# undecided".`);
  if (d.type === "U32" && !used.has(d.key)) errors.push(`${d.key}: a number the screen doesn't use.`);
}
for (const u of used) if (!defs.some((d) => d.key === u)) errors.push(`--${u.replace(/_/g, "-")}: used in board.css but missing from BOARD.bend.`);
if (errors.length) { console.error("BOARD: FAILED\n- " + errors.join("\n- ")); process.exit(1); }
const n = (f) => defs.filter(f).length;
console.log(`BOARD: ${defs.length} values (${n((d) => pinned(d.key))} with a law, ${n((d) => /# undecided/.test(d.body))} undecided, ${n((d) => /^\(/.test(d.body))} derived); every number reaches the screen; no --space-* or loose px.`);
