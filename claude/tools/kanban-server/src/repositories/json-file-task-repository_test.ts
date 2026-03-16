import { assertEquals, assertRejects } from "@std/assert";
import { JsonFileTaskRepository } from "./json-file-task-repository.ts";

const BOARD_ID = "test-board";

async function setup(): Promise<{ repo: JsonFileTaskRepository; dir: string }> {
  const dir = await Deno.makeTempDir({ prefix: "kanban-task-test-" });
  // Create board directory (new format: boards/<boardId>/ with meta.json)
  const boardDir = `${dir}/boards/${BOARD_ID}`;
  await Deno.mkdir(boardDir, { recursive: true });
  await Deno.writeTextFile(
    `${boardDir}/meta.json`,
    JSON.stringify({
      id: BOARD_ID,
      name: "Test Board",
      columns: ["backlog", "todo", "in_progress", "review", "done"],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }),
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

Deno.test("createTask creates individual file with UUID v4 id", async () => {
  const { repo, dir } = await setup();
  try {
    const task = await repo.createTask(BOARD_ID, { title: "Test task" });
    assertEquals(typeof task.id, "string");
    // UUID v4 format
    const uuidPattern =
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
    assertEquals(
      uuidPattern.test(task.id),
      true,
      `id '${task.id}' should be UUID v4`,
    );
    assertEquals(task.title, "Test task");

    // Verify individual file exists
    const filePath = `${dir}/boards/${BOARD_ID}/${task.id}.json`;
    const stat = await Deno.stat(filePath);
    assertEquals(stat.isFile, true);
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

Deno.test("getTask reads individual file by id", async () => {
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

Deno.test("listTasks reads all JSON files in board directory excluding meta.json", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.createTask(BOARD_ID, { title: "Task 1" });
    await repo.createTask(BOARD_ID, { title: "Task 2" });
    await repo.createTask(BOARD_ID, { title: "Task 3" });

    const tasks = await repo.listTasks(BOARD_ID);
    assertEquals(tasks.length, 3);
    const titles = tasks.map((t) => t.title).sort();
    assertEquals(titles, ["Task 1", "Task 2", "Task 3"]);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("updateTask overwrites individual file", async () => {
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
    assertEquals(updated.createdAt, created.createdAt);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("updateTask with optimistic lock rejects on version mismatch", async () => {
  const { repo, dir } = await setup();
  try {
    const created = await repo.createTask(BOARD_ID, { title: "Locked" });
    await new Promise((r) => setTimeout(r, 10));
    await repo.updateTask(BOARD_ID, created.id, { title: "Changed" });
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

Deno.test("deleteTask physically removes the file", async () => {
  const { repo, dir } = await setup();
  try {
    const created = await repo.createTask(BOARD_ID, { title: "Delete me" });
    await repo.deleteTask(BOARD_ID, created.id);
    const found = await repo.getTask(BOARD_ID, created.id);
    assertEquals(found, null);
    const tasks = await repo.listTasks(BOARD_ID);
    assertEquals(tasks.length, 0);

    // Verify file is gone
    try {
      await Deno.stat(`${dir}/boards/${BOARD_ID}/${created.id}.json`);
      throw new Error("File should not exist");
    } catch (e) {
      assertEquals(e instanceof Deno.errors.NotFound, true);
    }
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
    await repo.createTask(BOARD_ID, { title: "Medium" });
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
  } finally {
    await cleanup(dir);
  }
});

Deno.test("moveTasks updates multiple task statuses", async () => {
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
      "not found",
    );
  } finally {
    await cleanup(dir);
  }
});

Deno.test("createTask sets optional fields", async () => {
  const { repo, dir } = await setup();
  try {
    const task = await repo.createTask(BOARD_ID, {
      title: "With options",
      worktree: "/tmp/wt",
      executionHost: "mac-mini-1",
      sessionContext: { lastSessionId: "abc" },
    });
    assertEquals(task.worktree, "/tmp/wt");
    assertEquals(task.executionHost, "mac-mini-1");
    assertEquals(task.sessionContext?.lastSessionId, "abc");
  } finally {
    await cleanup(dir);
  }
});
