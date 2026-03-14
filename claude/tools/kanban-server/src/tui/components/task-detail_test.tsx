import { assertEquals } from "@std/assert";
import { render } from "ink-testing-library";
import { TaskDetail } from "./task-detail.tsx";
import type { Task } from "../../types.ts";

const testOpts = { sanitizeOps: false, sanitizeResources: false };

Deno.test(
  "TaskDetail shows placeholder when no task selected",
  testOpts,
  () => {
    const { lastFrame, unmount } = render(<TaskDetail task={null} />);
    const frame = lastFrame()!;
    unmount();
    assertEquals(frame.includes("タスクを選択してください"), true);
  },
);

Deno.test("TaskDetail shows task title and description", testOpts, () => {
  const task: Task = {
    id: "t-001",
    title: "Fix bug",
    description: "This is a bug fix",
    status: "in_progress",
    priority: "high",
    labels: ["bug"],
    createdAt: "2026-03-14T10:00:00Z",
    updatedAt: "2026-03-14T10:00:00Z",
  };
  const { lastFrame, unmount } = render(<TaskDetail task={task} />);
  const frame = lastFrame()!;
  unmount();
  assertEquals(frame.includes("Fix bug"), true, `Expected title in: ${frame}`);
  assertEquals(
    frame.includes("This is a bug fix"),
    true,
    `Expected description in: ${frame}`,
  );
  assertEquals(frame.includes("#bug"), true, `Expected label in: ${frame}`);
});

Deno.test("TaskDetail shows session context when present", testOpts, () => {
  const task: Task = {
    id: "t-002",
    title: "Task with session",
    description: "",
    status: "todo",
    priority: "medium",
    labels: [],
    createdAt: "2026-03-14T10:00:00Z",
    updatedAt: "2026-03-14T10:00:00Z",
    sessionContext: { lastSessionId: "abc-123", resumeHint: "Continue work" },
  };
  const { lastFrame, unmount } = render(<TaskDetail task={task} />);
  const frame = lastFrame()!;
  unmount();
  assertEquals(
    frame.includes("abc-123"),
    true,
    `Expected session ID in: ${frame}`,
  );
  assertEquals(
    frame.includes("Continue work"),
    true,
    `Expected resume hint in: ${frame}`,
  );
});
