// The orbit pad. The pad node is replaced whenever the knob moves, so the drag
// is tracked on the document instead of on that node. The callback receives
// stick positions from -1 to 1: x is right, y is down.

let report = null;
let dragging = false;
let pointerId = null;
let listening = false;

function clamp(n) {
  return Math.max(-1, Math.min(1, n));
}

function pad() {
  return document.querySelector("[data-test-id=orbit-stick]");
}

function place(event) {
  const clientX = event.clientX;
  const clientY = event.clientY;
  if (!report || !Number.isFinite(clientX) || !Number.isFinite(clientY)) {
    return;
  }
  const el = pad();
  if (!el) return;
  const rect = el.getBoundingClientRect();
  if (rect.width === 0 || rect.height === 0) return;
  const x = clamp(((clientX - rect.left) / rect.width) * 2 - 1);
  const y = clamp(((clientY - rect.top) / rect.height) * 2 - 1);
  if (!Number.isFinite(x) || !Number.isFinite(y)) return;
  report(x, y);
}

function onDown(event) {
  const el = pad();
  if (!el || !el.contains(event.target)) return;
  if (event.button !== 0) return;
  dragging = true;
  pointerId = event.pointerId;
  event.preventDefault();
  place(event);
}

function track(event) {
  if (!dragging || event.pointerId !== pointerId) return;
  place(event);
}

function onUp(event) {
  if (!dragging || event.pointerId !== pointerId) return;
  dragging = false;
  pointerId = null;
}

export function bindStick(onChange) {
  report = onChange;
  if (listening) return;
  listening = true;
  document.addEventListener("pointerdown", onDown);
  document.addEventListener("pointermove", track);
  document.addEventListener("pointerup", onUp);
  document.addEventListener("pointercancel", onUp);
}
