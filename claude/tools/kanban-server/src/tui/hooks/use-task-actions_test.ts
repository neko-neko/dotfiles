import { assertEquals } from "@std/assert";
import { TaskActions } from "./use-task-actions.ts";
import { JsonFileTaskRepository } from "../../repositories/json-file-task-repository.ts";

async function setupTempBoard(): Promise<
  { dir: string; cleanup: () => Promise<void> }
> {
  const dir = await Deno.makeTempDir();
  const boardDir = `${dir}/boards/test`;
  await Deno.mkdir(boardDir, { recursive: true });

  await Deno.writeTextFile(
    `${boardDir}/meta.json`,
    JSON.stringify({
      id: "test",
      name: "Test",
      columns: ["backlog", "todo", "in_progress", "review", "done"],
      createdAt: "",
      updatedAt: "",
    }),
  );

  return { dir, cleanup: () => Deno.remove(dir, { recursive: true }) };
}

Deno.test("TaskActions.createTask adds a task", async () => {
  const { dir, cleanup } = await setupTempBoard();
  try {
    const repo = new JsonFileTaskRepository(dir);
    const actions = new TaskActions(repo, "test");

    const task = await actions.createTask({ title: "New Task" });
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

    const task = await actions.createTask({ title: "Move Me" });
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

    const task = await actions.createTask({ title: "Delete Me" });
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

    const task = await actions.createTask({ title: "Edit Me" });
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
