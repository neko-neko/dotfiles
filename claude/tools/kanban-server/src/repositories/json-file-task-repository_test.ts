import { assertEquals, assertRejects } from "@std/assert";
import { JsonFileTaskRepository } from "./json-file-task-repository.ts";
import type { BoardData } from "../types.ts";

const BOARD_ID = "test-board";

async function setup(): Promise<{ repo: JsonFileTaskRepository; dir: string }> {
  const dir = await Deno.makeTempDir({ prefix: "kanban-task-test-" });
  await Deno.mkdir(`${dir}/boards`);
  const boardData: BoardData = {
    version: 1,
    boardId: BOARD_ID,
    columns: ["backlog", "todo", "in_progress", "review", "done"],
    tasks: [],
  };
  await Deno.writeTextFile(
    `${dir}/boards/${BOARD_ID}.json`,
    JSON.stringify(boardData),
  );
  return { repo: new JsonFileTaskRepository(dir), dir };
}

async function cleanup(dir: string): Promise<void> {
  await Deno.remove(dir, { recursive: true });
}

Deno.test("listTasks returns empty initially", async () => {
  const { repo, dir } = await setup();
  try {
    const tasks = await repo.listTasks(BOARD_ID);
    assertEquals(tasks, []);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("createTask adds a task with generated id (format: t-YYYYMMDD-NNN)", async () => {
  const { repo, dir } = await setup();
  try {
    const task = await repo.createTask(BOARD_ID, { title: "Test task" });
    assertEquals(typeof task.id, "string");
    // id format: t-YYYYMMDD-NNN
    const idPattern = /^t-\d{8}-\d{3}$/;
    assertEquals(
      idPattern.test(task.id),
      true,
      `id '${task.id}' should match t-YYYYMMDD-NNN`,
    );
    assertEquals(task.title, "Test task");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("createTask defaults: status=backlog, priority=medium, labels=[]", async () => {
  const { repo, dir } = await setup();
  try {
    const task = await repo.createTask(BOARD_ID, { title: "Defaults test" });
    assertEquals(task.status, "backlog");
    assertEquals(task.priority, "medium");
    assertEquals(task.labels, []);
    assertEquals(task.description, "");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("getTask returns task by id", async () => {
  const { repo, dir } = await setup();
  try {
    const created = await repo.createTask(BOARD_ID, { title: "Find me" });
    const found = await repo.getTask(BOARD_ID, created.id);
    assertEquals(found?.id, created.id);
    assertEquals(found?.title, "Find me");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("getTask returns null for missing id", async () => {
  const { repo, dir } = await setup();
  try {
    const found = await repo.getTask(BOARD_ID, "nonexistent");
    assertEquals(found, null);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("updateTask modifies task fields", async () => {
  const { repo, dir } = await setup();
  try {
    const created = await repo.createTask(BOARD_ID, { title: "Original" });
    const updated = await repo.updateTask(BOARD_ID, created.id, {
      title: "Updated",
      status: "in_progress",
      priority: "high",
      labels: ["urgent"],
    });
    assertEquals(updated.title, "Updated");
    assertEquals(updated.status, "in_progress");
    assertEquals(updated.priority, "high");
    assertEquals(updated.labels, ["urgent"]);
    // updatedAt should change
    assertEquals(updated.createdAt, created.createdAt);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("updateTask with optimistic lock rejects on version mismatch", async () => {
  const { repo, dir } = await setup();
  try {
    const created = await repo.createTask(BOARD_ID, { title: "Locked" });
    // Wait briefly so updatedAt changes on next update
    await new Promise((r) => setTimeout(r, 10));
    // Update once to change updatedAt
    await repo.updateTask(BOARD_ID, created.id, { title: "Changed" });
    // Now try updating with stale expectedVersion
    await assertRejects(
      () =>
        repo.updateTask(BOARD_ID, created.id, {
          title: "Conflict",
          expectedVersion: created.updatedAt,
        }),
      Error,
      "version mismatch",
    );
  } finally {
    await cleanup(dir);
  }
});

Deno.test("deleteTask removes the task", async () => {
  const { repo, dir } = await setup();
  try {
    const created = await repo.createTask(BOARD_ID, { title: "Delete me" });
    await repo.deleteTask(BOARD_ID, created.id);
    const found = await repo.getTask(BOARD_ID, created.id);
    assertEquals(found, null);
    const tasks = await repo.listTasks(BOARD_ID);
    assertEquals(tasks.length, 0);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("listTasks with status filter", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.createTask(BOARD_ID, { title: "Backlog task" });
    await repo.createTask(BOARD_ID, { title: "Todo task", status: "todo" });
    await repo.createTask(BOARD_ID, { title: "Another backlog" });

    const backlogTasks = await repo.listTasks(BOARD_ID, { status: "backlog" });
    assertEquals(backlogTasks.length, 2);

    const todoTasks = await repo.listTasks(BOARD_ID, { status: "todo" });
    assertEquals(todoTasks.length, 1);
    assertEquals(todoTasks[0].title, "Todo task");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("listTasks with priority filter", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.createTask(BOARD_ID, { title: "High", priority: "high" });
    await repo.createTask(BOARD_ID, { title: "Medium" }); // default medium
    await repo.createTask(BOARD_ID, { title: "Low", priority: "low" });

    const highTasks = await repo.listTasks(BOARD_ID, { priority: "high" });
    assertEquals(highTasks.length, 1);
    assertEquals(highTasks[0].title, "High");

    const mediumTasks = await repo.listTasks(BOARD_ID, { priority: "medium" });
    assertEquals(mediumTasks.length, 1);
    assertEquals(mediumTasks[0].title, "Medium");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("listTasks with label filter", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.createTask(BOARD_ID, {
      title: "Bug fix",
      labels: ["bug", "frontend"],
    });
    await repo.createTask(BOARD_ID, { title: "Feature", labels: ["feature"] });
    await repo.createTask(BOARD_ID, { title: "No labels" });

    const bugTasks = await repo.listTasks(BOARD_ID, { label: "bug" });
    assertEquals(bugTasks.length, 1);
    assertEquals(bugTasks[0].title, "Bug fix");

    const featureTasks = await repo.listTasks(BOARD_ID, { label: "feature" });
    assertEquals(featureTasks.length, 1);
    assertEquals(featureTasks[0].title, "Feature");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("moveTasks bulk moves multiple tasks", async () => {
  const { repo, dir } = await setup();
  try {
    const t1 = await repo.createTask(BOARD_ID, { title: "Task 1" });
    const t2 = await repo.createTask(BOARD_ID, { title: "Task 2" });

    const moved = await repo.moveTasks(BOARD_ID, [
      { taskId: t1.id, status: "in_progress" },
      { taskId: t2.id, status: "done" },
    ]);

    assertEquals(moved.length, 2);
    const m1 = moved.find((t) => t.id === t1.id);
    const m2 = moved.find((t) => t.id === t2.id);
    assertEquals(m1?.status, "in_progress");
    assertEquals(m2?.status, "done");

    // Verify persistence
    const persisted1 = await repo.getTask(BOARD_ID, t1.id);
    assertEquals(persisted1?.status, "in_progress");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("createTask rejects for nonexistent board", async () => {
  const { repo, dir } = await setup();
  try {
    await assertRejects(
      () => repo.createTask("no-such-board", { title: "Fail" }),
      Error,
    );
  } finally {
    await cleanup(dir);
  }
});
