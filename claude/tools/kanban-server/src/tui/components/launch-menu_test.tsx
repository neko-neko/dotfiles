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
  // Japanese label for local launch
  assertEquals(
    frame.includes("Claude Code"),
    true,
    `Expected local launch option in: ${frame}`,
  );
});

Deno.test(
  "LaunchMenu shows remote-attach option for remote tasks",
  testOpts,
  () => {
    const task = makeTask({ executionHost: "remote" });
    const { lastFrame, unmount } = render(
      <LaunchMenu
        task={task}
        projectPath="/home/user/project"
        onLaunch={() => {}}
        onCancel={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    // Check for the remote session connect option (Japanese)
    assertEquals(
      frame.includes("\u30EA\u30E2\u30FC\u30C8\u30BB\u30C3\u30B7\u30E7\u30F3"),
      true,
      `Expected remote attach option in: ${frame}`,
    );
  },
);

Deno.test(
  "LaunchMenu shows handover option for done tasks with handover path",
  testOpts,
  () => {
    const task = makeTask({
      status: "done",
      lastHandoverPath: "/home/user/.claude/handover/main/abc123",
    });
    const { lastFrame, unmount } = render(
      <LaunchMenu
        task={task}
        projectPath="/home/user/project"
        onLaunch={() => {}}
        onCancel={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    // Check for the handover option (Japanese)
    assertEquals(
      frame.includes("\u5F15\u304D\u7D99\u304E"),
      true,
      `Expected handover option in: ${frame}`,
    );
  },
);

Deno.test("LaunchMenu renders hint bar", testOpts, () => {
  const { lastFrame, unmount } = render(
    <LaunchMenu
      task={makeTask()}
      projectPath="/home/user/project"
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
