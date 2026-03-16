import { assertEquals } from "@std/assert";
import { boardRoutes } from "./boards.ts";
import { JsonFileBoardRepository } from "../repositories/json-file-board-repository.ts";
import type { BoardsIndex } from "../types.ts";

async function setup(): Promise<{
  app: ReturnType<typeof boardRoutes>;
  dir: string;
}> {
  const dir = await Deno.makeTempDir({ prefix: "kanban-board-routes-test-" });
  const index: BoardsIndex = { version: 1, boards: [] };
  await Deno.writeTextFile(`${dir}/boards.json`, JSON.stringify(index));
  await Deno.mkdir(`${dir}/boards`);
  const repo = new JsonFileBoardRepository(dir);
  const app = boardRoutes(repo);
  return { app, dir };
}

async function cleanup(dir: string): Promise<void> {
  await Deno.remove(dir, { recursive: true });
}

Deno.test("GET /boards returns empty list", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request("/boards");
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body, []);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST /boards creates a board (201)", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request("/boards", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        id: "b1",
        name: "My Board",
        path: "/tmp/project",
      }),
    });
    assertEquals(res.status, 201);
    const body = await res.json();
    assertEquals(body.id, "b1");
    assertEquals(body.name, "My Board");
    assertEquals(body.path, "/tmp/project");
    assertEquals(typeof body.createdAt, "string");

    // Verify it shows up in the list
    const listRes = await app.request("/boards");
    const list = await listRes.json();
    assertEquals(list.length, 1);
    assertEquals(list[0].id, "b1");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST /boards rejects invalid input - missing id (400)", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request("/boards", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "No ID", path: "/tmp" }),
    });
    assertEquals(res.status, 400);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST /boards rejects invalid input - missing name (400)", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request("/boards", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: "b1", path: "/tmp" }),
    });
    assertEquals(res.status, 400);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST /boards rejects invalid input - missing path (400)", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request("/boards", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: "b1", name: "Board" }),
    });
    assertEquals(res.status, 400);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST /boards rejects duplicate id (409)", async () => {
  const { app, dir } = await setup();
  try {
    await app.request("/boards", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: "b1", name: "Board 1", path: "/tmp/p1" }),
    });
    const res = await app.request("/boards", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: "b1", name: "Board 1 dup", path: "/tmp/p2" }),
    });
    assertEquals(res.status, 409);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("DELETE /boards/:id removes board (204)", async () => {
  const { app, dir } = await setup();
  try {
    await app.request("/boards", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: "b1", name: "Board 1", path: "/tmp/p1" }),
    });
    const res = await app.request("/boards/b1", { method: "DELETE" });
    assertEquals(res.status, 204);

    // Verify it's gone
    const listRes = await app.request("/boards");
    const list = await listRes.json();
    assertEquals(list.length, 0);
  } finally {
    await cleanup(dir);
  }
});
