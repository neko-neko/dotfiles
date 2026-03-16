// src/tui/hooks/use-board_test.ts
import { assertEquals } from "@std/assert";
import type { Task } from "../../types.ts";
import { groupTasksByStatus, loadBoardTasks } from "./use-board.ts";

Deno.test("groupTasksByStatus groups tasks correctly", () => {
  const tasks: Task[] = [
    {
      id: "t-1",
      title: "A",
      description: "",
      status: "todo",
      priority: "high",
      labels: [],
      createdAt: "",
      updatedAt: "",
    },
    {
      id: "t-2",
      title: "B",
      description: "",
      status: "todo",
      priority: "low",
      labels: [],
      createdAt: "",
      updatedAt: "",
    },
    {
      id: "t-3",
      title: "C",
      description: "",
      status: "done",
      priority: "medium",
      labels: [],
      createdAt: "",
      updatedAt: "",
    },
  ];

  const grouped = groupTasksByStatus(tasks);

  assertEquals(grouped.get("todo")?.length, 2);
  assertEquals(grouped.get("done")?.length, 1);
  assertEquals(grouped.has("in_progress"), false);
});

Deno.test("groupTasksByStatus sorts high priority first within group", () => {
  const tasks: Task[] = [
    {
      id: "t-1",
      title: "Low",
      description: "",
      status: "todo",
      priority: "low",
      labels: [],
      createdAt: "",
      updatedAt: "",
    },
    {
      id: "t-2",
      title: "High",
      description: "",
      status: "todo",
      priority: "high",
      labels: [],
      createdAt: "",
      updatedAt: "",
    },
    {
      id: "t-3",
      title: "Med",
      description: "",
      status: "todo",
      priority: "medium",
      labels: [],
      createdAt: "",
      updatedAt: "",
    },
  ];

  const grouped = groupTasksByStatus(tasks);
  const todoTasks = grouped.get("todo")!;

  assertEquals(todoTasks[0].priority, "high");
  assertEquals(todoTasks[1].priority, "medium");
  assertEquals(todoTasks[2].priority, "low");
});

Deno.test("loadBoardTasks reads individual task files from board directory", async () => {
  const tmpDir = await Deno.makeTempDir();
  const boardDir = `${tmpDir}/boards/test`;
  await Deno.mkdir(boardDir, { recursive: true });

  // Write meta.json (should be excluded)
  await Deno.writeTextFile(
    `${boardDir}/meta.json`,
    JSON.stringify({
      id: "test",
      name: "Test",
      columns: [],
      createdAt: "",
      updatedAt: "",
    }),
  );

  // Write task file
  const task: Task = {
    id: "t-1",
    title: "Task 1",
    description: "desc",
    status: "todo",
    priority: "high",
    labels: ["test"],
    createdAt: "2026-03-14",
    updatedAt: "2026-03-14",
  };
  await Deno.writeTextFile(`${boardDir}/t-1.json`, JSON.stringify(task));

  const result = await loadBoardTasks(tmpDir, "test");

  assertEquals(result.length, 1);
  assertEquals(result[0].title, "Task 1");

  await Deno.remove(tmpDir, { recursive: true });
});
