// The shell of a page written in Bend, the same for every project. Nobody edits it: copy the folder
// to <project>/.page/ and bundle it (bend .page/index.html -o dist). It runs the project's main.bend
// (init, render, on_event; on_input and title when it has them) with Bend-UI on.
import { start } from "../node_modules/bend-ui/web.js";
import Main from "../main.bend";

if (typeof Main.title === "function") document.title = Main.title();
start(Main);
