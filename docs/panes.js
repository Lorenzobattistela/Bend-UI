// The docs' live examples for the panes extension: a window with a pane beside its column and one under it,
// a tree, a terminal with a made-up shell, and each page's Laws section (none yet: every measure is undecided).
import { PANES, initPane, tree, initTree, mountTerm } from "../panes.js";
import TERM from "../TERM.bend";

const PATHS = ["GDD.md", "README.md", "game/game.html", "game/game.js", "game/sprites.js", "game/sprites/hero.png", "game/sprites/enemy.png", "game/levels/level1.json", "game/levels/level2.json", "notes/"];
const MARKS = { "game/game.js": { add: 14, del: 6 }, "game/sprites.js": { add: 40 }, "GDD.md": { del: 2 } };

// A made-up shell, for the docs only. It echoes what is typed, as a real one does, and knows a few commands.
function fakeShell(el, label) {
  const ESC = "\x1b[", color = (n, text) => `${ESC}${n}m${text}${ESC}0m`;
  let line = "", busy = false;
  const term = mountTerm(el, { label, onData: (data) => typed(data) });
  const prompt = () => term.write(color(32, "docs") + " " + color(34, "~/game") + " $ ");
  const out = (text) => term.write(text + "\r\n");
  const COMMANDS = {
    help: () => out("A made-up shell. It knows: " + ["help", "ls", "echo", "colors", "test", "clear"].map((c) => color(1, c)).join(", ") + "."),
    ls: () => out([color("1;34", "game"), color("1;34", "notes"), "GDD.md", "README.md"].join("\t")),
    echo: (rest) => out(rest),
    colors: () => { out(["red", "green", "yellow", "blue", "magenta", "cyan"].map((name, i) => color(31 + i, name)).join(" ")); out(color(1, "bold") + " " + color(2, "dim") + " plain"); },
    clear: () => term.clear(),
    // A line written over itself (\r), then the result.
    test: () => new Promise((done) => {
      let n = 0;
      const tick = () => {
        term.write(`\rRunning laws ${n}/12`);
        if (n++ < 12) return setTimeout(tick, 80);
        term.write(`\r${ESC}K` + color(32, "✓") + " 12 laws hold\r\n"); done();
      };
      tick();
    }),
  };
  async function run(text) {
    const [name, ...rest] = text.split(" ");
    if (!name) return;
    if (COMMANDS[name]) await COMMANDS[name](rest.join(" "));
    else out(color(31, "command not found: " + name));
  }
  async function typed(data) {
    if (busy || data.startsWith("\x1b")) return;   // the arrows and Escape do nothing here
    for (const c of data) {
      if (c === "\r") { term.write("\r\n"); busy = true; await run(line.trim()); busy = false; line = ""; prompt(); }
      else if (c === "\x7f") { if (line) { line = [...line].slice(0, -1).join(""); term.write("\b \b"); } }
      else if (c === "\x03") { term.write("^C\r\n"); line = ""; prompt(); }
      else if (c === "\x0c") { term.clear(); prompt(); term.write(line); }
      else if (c >= " ") { line += c; term.write(c); }
    }
  }
  out("A made-up shell for these docs. Type " + color(1, "help") + ".");
  prompt();
  return term;
}

// A tree on PATHS: opening a file makes it the current one and says so.
function fileTree(box, said) {
  box.innerHTML = tree(PATHS, { open: ["game"], current: "game/game.js", marks: MARKS, label: "Files" });
  const files = initTree(box.firstElementChild, {
    onOpen: (path) => { files.update(PATHS, { current: path, marks: MARKS }); said.textContent = "Opened " + path + "."; },
    onToggle: (path, open) => { said.textContent = (open ? "Opened " : "Closed ") + path + "/."; },
  });
}

// Laws: none yet. The page lists its measures, each undecided, as the Board page does.
function laws(page, note, values) {
  const doc = document.querySelector(`[data-page="${page}"] .doc`), section = document.createElement("section");
  section.className = "section";
  section.innerHTML = `<h2 class="section-title">Laws</h2><div class="section__body"><p class="detail">None yet. ${note}</p>` +
    (values.length ? `<div class="docs-board-values"><div class="docs-board-row docs-board-head"><span>value</span><span>is</span><span>in</span><span>state</span></div>` +
      values.map(([key, value, file]) => `<div class="docs-board-row"><span class="mono">${key}</span><span class="mono">${value}</span><span class="mono">${file}</span><span><span class="tag tag--warning">undecided</span></span></div>`).join("") + "</div>" : "") + "</div>";
  doc.append(section);
}
const measures = (prefix) => Object.keys(PANES).filter((k) => k.startsWith(prefix) && typeof PANES[k]() === "number").map((k) => [k, PANES[k](), "PANES.bend"]);

export function mountPanesDocs() {
  const $ = (id) => document.getElementById(id);
  // Panes: both panes resize; Width makes the area narrow, where the side pane is a sheet.
  const saidPanes = $("panes-said");
  initPane($("panes-files"), { onResize: (size) => { saidPanes.textContent = `Files is ${size} wide.`; } });
  initPane($("panes-shell"), { onResize: (size) => { saidPanes.textContent = `Terminal is ${size} tall.`; } });
  fileTree($("panes-tree"), saidPanes);
  fakeShell($("panes-term"), "Terminal in a pane");
  document.querySelector("[data-panes-width]").addEventListener("change", (e) => {
    const area = $("panes-area"), w = e.detail.dataset.value;
    if (w === "wide") delete area.dataset.w; else area.dataset.w = w;
  });
  fileTree($("tree-demo"), $("tree-said"));
  fakeShell($("term-demo"), "Terminal");

  const none = "Every measure is marked <strong>undecided</strong>: it shows, without a law, until the owner locks it.";
  laws("panes", none, measures("pane_"));
  laws("tree", none, measures("tree_"));
  laws("terminal", none, ["scrollback", "say_lines", "say_wait_ms"].map((k) => [k, TERM[k](), "TERM.bend"]));
  laws("strip", "The strip has no measure of its own: its space, type and color are the lib's tokens.", []);
}
