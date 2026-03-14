// src/tui/hooks/use-mouse-input_test.ts
import { assertEquals } from "@std/assert";
import { parseMouseEvent } from "./use-mouse-input.ts";

Deno.test("parseMouseEvent parses SGR mouse click", () => {
  const result = parseMouseEvent("\x1b[<0;10;5M");
  assertEquals(result, { button: "left", x: 10, y: 5, type: "press" });
});

Deno.test("parseMouseEvent parses SGR mouse release", () => {
  const result = parseMouseEvent("\x1b[<0;10;5m");
  assertEquals(result, { button: "left", x: 10, y: 5, type: "release" });
});

Deno.test("parseMouseEvent parses right click", () => {
  const result = parseMouseEvent("\x1b[<2;20;10M");
  assertEquals(result, { button: "right", x: 20, y: 10, type: "press" });
});

Deno.test("parseMouseEvent parses scroll up", () => {
  const result = parseMouseEvent("\x1b[<64;5;5M");
  assertEquals(result, { button: "scrollUp", x: 5, y: 5, type: "press" });
});

Deno.test("parseMouseEvent parses scroll down", () => {
  const result = parseMouseEvent("\x1b[<65;5;5M");
  assertEquals(result, { button: "scrollDown", x: 5, y: 5, type: "press" });
});

Deno.test("parseMouseEvent returns null for non-mouse input", () => {
  assertEquals(parseMouseEvent("hello"), null);
  assertEquals(parseMouseEvent(""), null);
  assertEquals(parseMouseEvent("\x1b[A"), null);
});
