import { assertEquals, assertGreater } from "@std/assert";
import { render } from "ink-testing-library";
import { KeybindBar } from "./keybind-bar.tsx";

const testOpts = { sanitizeOps: false, sanitizeResources: false };

Deno.test("KeybindBar renders keybind labels", testOpts, () => {
  // Default ink-testing-library render width (80 cols) truncates with 14 keybinds.
  // Verify the component renders and the first keybinds are visible.
  const { lastFrame, unmount } = render(<KeybindBar />);
  const frame = lastFrame()!;
  unmount();

  assertGreater(frame.length, 0, "KeybindBar should render non-empty output");
  // First keybinds should always fit within default width
  assertEquals(frame.includes("add"), true, `Expected "add" in: ${frame}`);
  assertEquals(frame.includes("move"), true, `Expected "move" in: ${frame}`);
  assertEquals(frame.includes("edit"), true, `Expected "edit" in: ${frame}`);
  assertEquals(
    frame.includes("filter"),
    true,
    `Expected "filter" in: ${frame}`,
  );
  assertEquals(frame.includes("sync"), true, `Expected "sync" in: ${frame}`);
});
