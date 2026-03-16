import { assertEquals } from "@std/assert";
import { render } from "ink-testing-library";
import { LaunchMenu } from "./launch-menu.tsx";
import type { Task } from "../../types.ts";

const testOpts = { sanitizeOps: false, sanitizeResources: false };

const makeTask = (overrides?: Partial<Task>): Task => ({
  id: "t-001",
  title: "Test Task",
  description: "A test task",
  status: "in_progress",
  priority: "medium",
  labels: [],
  createdAt: "2026-03-14T10:00:00Z",
  updatedAt: "2026-03-14T10:00:00Z",
  ...overrides,
});

Deno.test("LaunchMenu renders task title and menu items", testOpts, () => {
  const { lastFrame, unmount } = render(
    <LaunchMenu
      task={makeTask()}
      projectPath="/home/user/project"
      nodeName="macbook-main"
      onLaunch={() => {}}
      onCancel={() => {}}
    />,
  );
  const frame = lastFrame()!;
  unmount();
  assertEquals(
    frame.includes("Test Task"),
    true,
    `Expected task title in: ${frame}`,
  );
  assertEquals(
    frame.includes("Claude Code"),
    true,
    `Expected local launch option in: ${frame}`,
  );
});

Deno.test(
  "LaunchMenu shows remote node info for tasks running on other nodes",
  testOpts,
  () => {
    const task = makeTask({ executionHost: "mac-mini" });
    const { lastFrame, unmount } = render(
      <LaunchMenu
        task={task}
        projectPath="/home/user/project"
        nodeName="macbook-main"
        onLaunch={() => {}}
        onCancel={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    assertEquals(
      frame.includes("mac-mini"),
      true,
      `Expected remote node name in: ${frame}`,
    );
  },
);

Deno.test(
  "LaunchMenu does not show remote info for self-hosted tasks",
  testOpts,
  () => {
    const task = makeTask({ executionHost: "macbook-main" });
    const { lastFrame, unmount } = render(
      <LaunchMenu
        task={task}
        projectPath="/home/user/project"
        nodeName="macbook-main"
        onLaunch={() => {}}
        onCancel={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    assertEquals(
      frame.includes("実行中"),
      false,
      `Should not show remote info for self: ${frame}`,
    );
  },
);

Deno.test("LaunchMenu renders hint bar", testOpts, () => {
  const { lastFrame, unmount } = render(
    <LaunchMenu
      task={makeTask()}
      projectPath="/home/user/project"
      nodeName="macbook-main"
      onLaunch={() => {}}
      onCancel={() => {}}
    />,
  );
  const frame = lastFrame()!;
  unmount();
  assertEquals(
    frame.includes("Esc cancel"),
    true,
    `Expected hint bar in: ${frame}`,
  );
});
