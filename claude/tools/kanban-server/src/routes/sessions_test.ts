import { assertEquals } from "@std/assert";
import { sessionsRoutes } from "./sessions.ts";
import { SessionRepository } from "../repositories/session-repository.ts";
import type { KanbanConfig } from "../config.ts";

const OWNER = "macbook-main";
const config: KanbanConfig = {
  port: 3456,
  dataDir: "",
  nodeName: OWNER,
  peers: [],
  syncthingWatchIntervalMs: 5000,
  peerPollIntervalMs: 10000,
};

async function setup() {
  const dir = await Deno.makeTempDir({ prefix: "kanban-sessions-route-" });
  const repo = new SessionRepository(dir);
  const app = sessionsRoutes(repo, { ...config, dataDir: dir });
  return { dir, repo, app };
}

async function cleanup(dir: string) {
  await Deno.remove(dir, { recursive: true });
}

Deno.test("GET / returns session list", async () => {
  const { dir, repo, app } = await setup();
  try {
    await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    const res = await app.request("/");
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.length, 1);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("GET / with host filter", async () => {
  const { dir, repo, app } = await setup();
  try {
    await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    await repo.create({
      taskId: "t2",
      boardId: "b1",
      host: "mac-mini",
      ownerNode: "mac-mini",
    });
    const res = await app.request("/?host=mac-mini");
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.length, 1);
    assertEquals(body[0].host, "mac-mini");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST / creates session", async () => {
  const { dir, app } = await setup();
  try {
    const res = await app.request("/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        taskId: "t1",
        boardId: "b1",
        host: OWNER,
        ownerNode: OWNER,
      }),
    });
    assertEquals(res.status, 201);
    const body = await res.json();
    assertEquals(body.status, "starting");
    assertEquals(body.taskId, "t1");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST / with missing fields returns 400", async () => {
  const { dir, app } = await setup();
  try {
    const res = await app.request("/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ taskId: "t1" }),
    });
    assertEquals(res.status, 400);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("GET /:id returns session", async () => {
  const { dir, repo, app } = await setup();
  try {
    const session = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    const res = await app.request(`/${session.id}`);
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.id, session.id);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("GET /:id not found returns 404", async () => {
  const { dir, app } = await setup();
  try {
    const res = await app.request("/nonexistent");
    assertEquals(res.status, 404);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("PATCH /:id updates session (ownerNode match)", async () => {
  const { dir, repo, app } = await setup();
  try {
    const session = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    const res = await app.request(`/${session.id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-Node-Name": OWNER,
      },
      body: JSON.stringify({ status: "in-progress" }),
    });
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.status, "in-progress");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("PATCH /:id rejects non-owner with 403", async () => {
  const { dir, repo, app } = await setup();
  try {
    const session = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    const res = await app.request(`/${session.id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-Node-Name": "other-node",
      },
      body: JSON.stringify({ status: "in-progress" }),
    });
    assertEquals(res.status, 403);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("PATCH /:id rejects invalid transition with 400", async () => {
  const { dir, repo, app } = await setup();
  try {
    const session = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    await repo.update(session.id, { status: "in-progress" }, OWNER);
    await repo.update(session.id, { status: "done" }, OWNER);

    const res = await app.request(`/${session.id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-Node-Name": OWNER,
      },
      body: JSON.stringify({ status: "in-progress" }),
    });
    assertEquals(res.status, 400);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("GET /by-task/:taskId returns sessions for task", async () => {
  const { dir, repo, app } = await setup();
  try {
    await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    await repo.create({
      taskId: "t2",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    const res = await app.request("/by-task/t1");
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.length, 1);
    assertEquals(body[0].taskId, "t1");
  } finally {
    await cleanup(dir);
  }
});
