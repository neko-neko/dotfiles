import { assertEquals } from "@std/assert";
import { render } from "ink-testing-library";
import { SummaryBar } from "./summary-bar.tsx";
import type { Task } from "../../types.ts";

const testOpts = { sanitizeOps: false, sanitizeResources: false };

function makeTask(overrides: Partial<Task> = {}): Task {
  return {
    id: `t-${Math.random().toString(36).slice(2)}`,
    title: "Test",
    description: "",
    status: "todo",
    priority: "medium",
    labels: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    ...overrides,
  };
}

Deno.test("SummaryBar shows task counts per status", testOpts, () => {
  const tasks: Task[] = [
    makeTask({ status: "todo" }),
    makeTask({ status: "todo" }),
    makeTask({ status: "in_progress" }),
    makeTask({ status: "done" }),
  ];
  const { lastFrame, unmount } = render(<SummaryBar tasks={tasks} />);
  const frame = lastFrame()!;
  unmount();
  assertEquals(
    frame.includes("2 todo"),
    true,
    `Expected "2 todo" in: ${frame}`,
  );
  assertEquals(
    frame.includes("1 active"),
    true,
    `Expected "1 active" in: ${frame}`,
  );
  assertEquals(
    frame.includes("1 done"),
    true,
    `Expected "1 done" in: ${frame}`,
  );
});

Deno.test("SummaryBar shows zero counts", testOpts, () => {
  const { lastFrame, unmount } = render(<SummaryBar tasks={[]} />);
  const frame = lastFrame()!;
  unmount();
  assertEquals(
    frame.includes("0 todo"),
    true,
    `Expected "0 todo" in: ${frame}`,
  );
});
