import { assertEquals } from "@std/assert";
import { render } from "ink-testing-library";
import { SessionsDashboard } from "./sessions-dashboard.tsx";

const testOpts = { sanitizeOps: false, sanitizeResources: false };

Deno.test(
  "SessionsDashboard renders header and loading state",
  testOpts,
  () => {
    const { lastFrame, unmount } = render(
      <SessionsDashboard
        dataDir="/tmp/kanban-test"
        projectPath="/nonexistent/project"
        onBack={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    assertEquals(
      frame.includes("Sessions"),
      true,
      `Expected "Sessions" header in: ${frame}`,
    );
  },
);

Deno.test(
  "SessionsDashboard renders hint bar with keybinds",
  testOpts,
  () => {
    const { lastFrame, unmount } = render(
      <SessionsDashboard
        dataDir="/tmp/kanban-test"
        projectPath="/nonexistent/project"
        onBack={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    assertEquals(
      frame.includes("[j/k]"),
      true,
      `Expected j/k hint in: ${frame}`,
    );
    assertEquals(
      frame.includes("[b]"),
      true,
      `Expected back hint in: ${frame}`,
    );
    assertEquals(
      frame.includes("navigate"),
      true,
      `Expected navigate label in: ${frame}`,
    );
  },
);
