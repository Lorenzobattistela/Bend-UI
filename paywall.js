// Paywall (opt-in): import "bend-ui/paywall".
//   import Pw from "bend-ui/PAYWALL.bend";   // in a page written with Web.bend: Pw.view, Pw.Sheet, Pw.opened…
//   import { focusSheet } from "bend-ui/paywall";
// The sheet that opens over an app and says what a plan gives. PAYWALL.bend draws it and decides it; this file
// writes its measures as CSS variables and moves the focus into the sheet when it opens (a dialog takes the
// focus, WCAG 2.4.3), and back to where it was when it closes.
import "./paywall.css";
import P from "./PAYWALL.bend";

const root = document.documentElement.style;
for (const [k, v] of Object.entries(P)) {
  if (!k.startsWith("paywall_") || typeof v !== "function" || v.length !== 0) continue;
  const val = v(), name = "--" + k.replace(/_/g, "-");
  if (typeof val === "string") root.setProperty(name, val);
  else if (typeof val === "number") root.setProperty(name, k.endsWith("_ms") ? val + "ms" : k.endsWith("_layer") ? String(val) : val + "px");
}
export { P as PAYWALL };

// Call it from mount's `patched(root)`: when the sheet has just opened, the sheet takes the focus (so Escape and Tab
// work inside it at once, with no ring drawn on any button);
// when it has just closed, the focus goes back to what had it before.
const before = new WeakMap();
export function focusSheet(r) {
  for (const sheet of r.matches?.(".paywall") ? [r] : r.querySelectorAll(".paywall")) {
    const open = sheet.classList.contains("is-open"), was = before.get(sheet);
    if (open && !was) { before.set(sheet, document.activeElement || true); sheet.querySelector(".paywall__sheet")?.focus({ preventScroll: true }); }
    if (!open && was) { before.delete(sheet); if (was instanceof HTMLElement && was.isConnected) was.focus({ preventScroll: true }); }
  }
}
