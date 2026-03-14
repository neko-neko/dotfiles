// src/tui/hooks/use-mouse-input.ts — SGR mouse protocol parsing and enable/disable
// Supports SGR (1006) extended mouse mode for accurate coordinate reporting.

export interface MouseEvent {
  button: "left" | "middle" | "right" | "scrollUp" | "scrollDown";
  x: number;
  y: number;
  type: "press" | "release";
}

/** SGR mouse sequence: ESC [ < Cb ; Cx ; Cy M/m */
// deno-lint-ignore no-control-regex
const SGR_MOUSE_RE = /^\x1b\[<(\d+);(\d+);(\d+)([Mm])$/;

/**
 * Parse an SGR-format mouse event string.
 * Returns null if the input is not a valid SGR mouse sequence.
 */
export function parseMouseEvent(data: string): MouseEvent | null {
  const match = data.match(SGR_MOUSE_RE);
  if (!match) return null;

  const code = parseInt(match[1], 10);
  const x = parseInt(match[2], 10);
  const y = parseInt(match[3], 10);
  const type: MouseEvent["type"] = match[4] === "M" ? "press" : "release";

  let button: MouseEvent["button"];
  if (code === 0) button = "left";
  else if (code === 1) button = "middle";
  else if (code === 2) button = "right";
  else if (code === 64) button = "scrollUp";
  else if (code === 65) button = "scrollDown";
  else return null;

  return { button, x, y, type };
}

/** Enable SGR mouse tracking (X10 basic + SGR extended). */
export function enableMouse(): void {
  Deno.stdout.writeSync(new TextEncoder().encode("\x1b[?1000h\x1b[?1006h"));
}

/** Disable SGR mouse tracking. */
export function disableMouse(): void {
  Deno.stdout.writeSync(new TextEncoder().encode("\x1b[?1000l\x1b[?1006l"));
}
