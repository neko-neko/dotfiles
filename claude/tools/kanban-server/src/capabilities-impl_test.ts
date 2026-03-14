import { assertEquals, assertExists } from "@std/assert";
import { createCapabilities } from "./capabilities-impl.ts";
import { JsonFileBoardRepository } from "./repositories/json-file-board-repository.ts";
import { JsonFileTaskRepository } from "./repositories/json-file-task-repository.ts";
import { GitSyncService } from "./services/git-sync-service.ts";
import { SshService } from "./services/ssh-service.ts";
import { loadConfig } from "./config.ts";
import type { AllCapabilities } from "./capabilities.ts";

async function setup(): Promise<{ caps: AllCapabilities; dataDir: string }> {
  const dataDir = await Deno.makeTempDir();
  await Deno.mkdir(`${dataDir}/boards`, { recursive: true });
  await Deno.writeTextFile(
    `${dataDir}/boards.json`,
    JSON.stringify({ version: 1, boards: [] }),
  );
  const boardRepo = new JsonFileBoardRepository(dataDir);
  const taskRepo = new JsonFileTaskRepository(dataDir);
  const gitSync = new GitSyncService(dataDir);
  const sshService = new SshService();
  const config = await loadConfig(dataDir);
  const caps = createCapabilities(
    boardRepo,
    taskRepo,
    gitSync,
    sshService,
    config,
  );
  return { caps, dataDir };
}

Deno.test("createBoard creates board and listBoards returns it", async () => {
  const { caps, dataDir } = await setup();
  try {
    const board = await caps.createBoard({
      id: "test",
      name: "Test",
      path: "/tmp/test",
    });
    assertEquals(board.id, "test");
    assertEquals(board.name, "Test");
    const boards = await caps.listBoards();
    assertEquals(boards.length, 1);
    assertEquals(boards[0].id, "test");
  } finally {
    await Deno.remove(dataDir, { recursive: true });
  }
});

Deno.test("createTask + listTasks + deleteTask lifecycle", async () => {
  const { caps, dataDir } = await setup();
  try {
    await caps.createBoard({ id: "b1", name: "B1", path: "/tmp/b1" });
    const task = await caps.createTask("b1", {
      title: "Fix bug",
      priority: "high",
      labels: ["bug"],
    });
    assertExists(task.id);
    assertEquals(task.title, "Fix bug");
    assertEquals(task.priority, "high");

    const tasks = await caps.listTasks("b1");
    assertEquals(tasks.length, 1);

    const filtered = await caps.listTasks("b1", { label: "bug" });
    assertEquals(filtered.length, 1);

    const noMatch = await caps.listTasks("b1", { label: "feature" });
    assertEquals(noMatch.length, 0);

    await caps.deleteTask("b1", task.id);
    const after = await caps.listTasks("b1");
    assertEquals(after.length, 0);
  } finally {
    await Deno.remove(dataDir, { recursive: true });
  }
});

Deno.test("moveTask changes status", async () => {
  const { caps, dataDir } = await setup();
  try {
    await caps.createBoard({ id: "b2", name: "B2", path: "/tmp/b2" });
    const task = await caps.createTask("b2", { title: "Task A" });
    assertEquals(task.status, "backlog");

    const moved = await caps.moveTask("b2", task.id, "in_progress");
    assertEquals(moved.status, "in_progress");
  } finally {
    await Deno.remove(dataDir, { recursive: true });
  }
});

Deno.test("getOverview returns board summaries", async () => {
  const { caps, dataDir } = await setup();
  try {
    await caps.createBoard({ id: "o1", name: "Overview", path: "/tmp/o1" });
    await caps.createTask("o1", { title: "T1", status: "todo" });
    await caps.createTask("o1", { title: "T2", status: "done" });

    const overview = await caps.getOverview();
    assertEquals(overview.length, 1);
    assertEquals(overview[0].totalTasks, 2);
    assertEquals(overview[0].taskCounts["todo"], 1);
    assertEquals(overview[0].taskCounts["done"], 1);
  } finally {
    await Deno.remove(dataDir, { recursive: true });
  }
});

Deno.test("deleteBoard removes board", async () => {
  const { caps, dataDir } = await setup();
  try {
    await caps.createBoard({ id: "del", name: "Del", path: "/tmp/del" });
    assertEquals((await caps.listBoards()).length, 1);
    await caps.deleteBoard("del");
    assertEquals((await caps.listBoards()).length, 0);
  } finally {
    await Deno.remove(dataDir, { recursive: true });
  }
});
