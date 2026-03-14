// src/tui/components/filter-overlay_test.tsx — Basic render tests for FilterOverlay
import { assertEquals, assertExists } from "@std/assert";
import { render } from "ink-testing-library";
import { FilterOverlay } from "./filter-overlay.tsx";

Deno.test("FilterOverlay renders with empty filter", () => {
  const { lastFrame, unmount } = render(
    <FilterOverlay
      currentFilter={{}}
      availableLabels={["bug", "feature"]}
      onApply={() => {}}
      onCancel={() => {}}
    />,
  );

  const frame = lastFrame();
  assertExists(frame);
  assertEquals(frame.includes("Filter Tasks"), true);
  assertEquals(frame.includes("Status"), true);
  assertEquals(frame.includes("Priority"), true);
  assertEquals(frame.includes("Label"), true);

  unmount();
});

Deno.test("FilterOverlay renders with existing filter values", () => {
  const { lastFrame, unmount } = render(
    <FilterOverlay
      currentFilter={{ status: "todo", priority: "high" }}
      availableLabels={[]}
      onApply={() => {}}
      onCancel={() => {}}
    />,
  );

  const frame = lastFrame();
  assertExists(frame);
  assertEquals(frame.includes("Filter Tasks"), true);

  unmount();
});

Deno.test("FilterOverlay renders field navigation indicator", () => {
  const { lastFrame, unmount } = render(
    <FilterOverlay
      currentFilter={{}}
      availableLabels={["bug"]}
      onApply={() => {}}
      onCancel={() => {}}
    />,
  );

  const frame = lastFrame();
  assertExists(frame);
  // Should show field counter [1/3]
  assertEquals(frame.includes("[1/3]"), true);

  unmount();
});
