import { assertEquals } from "@std/assert";
import { render } from "ink-testing-library";
import { SearchOverlay } from "./search-overlay.tsx";

const testOpts = { sanitizeOps: false, sanitizeResources: false };

Deno.test("SearchOverlay renders search input and hint", testOpts, () => {
  const { lastFrame, unmount } = render(
    <SearchOverlay tasks={[]} onSelect={() => {}} onCancel={() => {}} />,
  );
  const frame = lastFrame()!;
  unmount();
  assertEquals(frame.includes("/"), true, `Expected "/" in: ${frame}`);
  assertEquals(
    frame.includes("Esc cancel"),
    true,
    `Expected hint in: ${frame}`,
  );
});
