import { assertEquals, assertExists } from "@std/assert";
import { createCapabilities } from "./capabilities-impl.ts";
import { JsonFileBoardRepository } from "./repositories/json-file-board-repository.ts";
import { JsonFileTaskRepository } from "./repositories/json-file-task-repository.ts";
import { PeerService } from "./services/peer-service.ts";
import type { KanbanConfig } from "./config.ts";
import type { AllCapabilities } from "./capabilities.ts";

const config: KanbanConfig = {
  port: 3456,
  dataDir: "",
  nodeName: "test-node",
  peers: [{ name: "peer-1", host: "peer-1.ts.net", port: 3456 }],
  syncthingWatchIntervalMs: 5000,
  peerPollIntervalMs: 10000,
};

async function setup(): Promise<{ caps: AllCapabilities; dataDir: string }> {
  const dataDir = await Deno.makeTempDir();
  await Deno.mkdir(`${dataDir}/boards`, { recursive: true });
  const boardRepo = new JsonFileBoardRepository(dataDir);
  const taskRepo = new JsonFileTaskRepository(dataDir);
  const peerService = new PeerService(config.peers, async () => {
    return new Response(
      JSON.stringify({
        nodeName: "peer-1",
        activeSessions: [],
        uptime: 1000,
      }),
    );
  });
  const caps = createCapabilities(
    boardRepo,
    taskRepo,
    peerService,
    { ...config, dataDir },
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

    const tasks = await caps.listTasks("b1");
    assertEquals(tasks.length, 1);

    await caps.deleteTask("b1", task.id);
    const afterDelete = await caps.listTasks("b1");
    assertEquals(afterDelete.length, 0);
  } finally {
    await Deno.remove(dataDir, { recursive: true });
  }
});

Deno.test("pingAll returns peer statuses", async () => {
  const { caps, dataDir } = await setup();
  try {
    const statuses = await caps.pingAll();
    assertEquals(statuses.length, 1);
    assertEquals(statuses[0].name, "peer-1");
    assertEquals(statuses[0].online, true);
  } finally {
    await Deno.remove(dataDir, { recursive: true });
  }
});

Deno.test("getNodeInfo returns peer info", async () => {
  const { caps, dataDir } = await setup();
  try {
    const info = await caps.getNodeInfo("peer-1");
    assertEquals(info.nodeName, "peer-1");
    assertEquals(info.uptime, 1000);
  } finally {
    await Deno.remove(dataDir, { recursive: true });
  }
});
