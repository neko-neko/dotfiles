import { assertEquals } from "@std/assert";
import { TaskActions } from "./use-task-actions.ts";
import { JsonFileTaskRepository } from "../../repositories/json-file-task-repository.ts";
import type { BoardData, BoardsIndex } from "../../types.ts";

async function setupTempBoard(): Promise<
  { dir: string; cleanup: () => Promise<void> }
> {
  const dir = await Deno.makeTempDir();
  const boardsDir = `${dir}/boards`;
  await Deno.mkdir(boardsDir, { recursive: true });

  const index: BoardsIndex = {
    version: 1,
    boards: [{
      id: "test",
      name: "Test",
      path: "/tmp",
      createdAt: "",
      updatedAt: "",
    }],
  };
  await Deno.writeTextFile(`${dir}/boards.json`, JSON.stringify(index));

  const boardData: BoardData = {
    version: 1,
    boardId: "test",
    columns: ["backlog", "todo", "in_progress", "review", "done"],
    tasks: [],
  };
  await Deno.writeTextFile(
    `${boardsDir}/test.json`,
    JSON.stringify(boardData),
  );

  return { dir, cleanup: () => Deno.remove(dir, { recursive: true }) };
}

Deno.test("TaskActions.createTask adds a task", async () => {
  const { dir, cleanup } = await setupTempBoard();
  try {
    const repo = new JsonFileTaskRepository(dir);
    const actions = new TaskActions(repo, "test");

    const task = await actions.createTask("New Task");
    assertEquals(task.title, "New Task");
    assertEquals(task.status, "backlog");
    assertEquals(task.priority, "medium");

    const tasks = await repo.listTasks("test");
    assertEquals(tasks.length, 1);
  } finally {
    await cleanup();
  }
});

Deno.test("TaskActions.moveTask changes status", async () => {
  const { dir, cleanup } = await setupTempBoard();
  try {
    const repo = new JsonFileTaskRepository(dir);
    const actions = new TaskActions(repo, "test");

    const task = await actions.createTask("Move Me");
    const moved = await actions.moveTask(task.id, "in_progress");
    assertEquals(moved.status, "in_progress");
  } finally {
    await cleanup();
  }
});

Deno.test("TaskActions.deleteTask removes a task", async () => {
  const { dir, cleanup } = await setupTempBoard();
  try {
    const repo = new JsonFileTaskRepository(dir);
    const actions = new TaskActions(repo, "test");

    const task = await actions.createTask("Delete Me");
    await actions.deleteTask(task.id);

    const tasks = await repo.listTasks("test");
    assertEquals(tasks.length, 0);
  } finally {
    await cleanup();
  }
});

Deno.test("TaskActions.updateTask modifies fields", async () => {
  const { dir, cleanup } = await setupTempBoard();
  try {
    const repo = new JsonFileTaskRepository(dir);
    const actions = new TaskActions(repo, "test");

    const task = await actions.createTask("Edit Me");
    const updated = await actions.updateTask(task.id, {
      title: "Edited",
      priority: "high",
      labels: ["urgent"],
    });
    assertEquals(updated.title, "Edited");
    assertEquals(updated.priority, "high");
    assertEquals(updated.labels, ["urgent"]);
  } finally {
    await cleanup();
  }
});
