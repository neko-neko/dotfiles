import { assertEquals } from "@std/assert";
import { taskRoutes } from "./tasks.ts";
import { JsonFileTaskRepository } from "../repositories/json-file-task-repository.ts";
import type { BoardData } from "../types.ts";

const BOARD_ID = "test-board";

async function setup(): Promise<{
  app: ReturnType<typeof taskRoutes>;
  dir: string;
}> {
  const dir = await Deno.makeTempDir({ prefix: "kanban-task-routes-test-" });
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
  const repo = new JsonFileTaskRepository(dir);
  const app = taskRoutes(repo);
  return { app, dir };
}

async function cleanup(dir: string): Promise<void> {
  await Deno.remove(dir, { recursive: true });
}

Deno.test("GET /boards/:boardId/tasks returns empty list", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request(`/boards/${BOARD_ID}/tasks`);
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body, []);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST /boards/:boardId/tasks creates task (201)", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request(`/boards/${BOARD_ID}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "New task" }),
    });
    assertEquals(res.status, 201);
    const body = await res.json();
    assertEquals(body.title, "New task");
    assertEquals(body.status, "backlog");
    assertEquals(body.priority, "medium");
    assertEquals(typeof body.id, "string");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST /boards/:boardId/tasks rejects missing title (400)", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request(`/boards/${BOARD_ID}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ description: "no title" }),
    });
    assertEquals(res.status, 400);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("PATCH /boards/:boardId/tasks/:taskId updates task (200)", async () => {
  const { app, dir } = await setup();
  try {
    // Create a task first
    const createRes = await app.request(`/boards/${BOARD_ID}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Original" }),
    });
    const created = await createRes.json();

    const res = await app.request(
      `/boards/${BOARD_ID}/tasks/${created.id}`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Updated", status: "in_progress" }),
      },
    );
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.title, "Updated");
    assertEquals(body.status, "in_progress");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("PATCH with version conflict returns 409", async () => {
  const { app, dir } = await setup();
  try {
    // Create a task
    const createRes = await app.request(`/boards/${BOARD_ID}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Locked" }),
    });
    const created = await createRes.json();

    // Update once to change updatedAt
    await new Promise((r) => setTimeout(r, 10));
    await app.request(`/boards/${BOARD_ID}/tasks/${created.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Changed" }),
    });

    // Try to update with stale version
    const res = await app.request(
      `/boards/${BOARD_ID}/tasks/${created.id}`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: "Conflict",
          expectedVersion: created.updatedAt,
        }),
      },
    );
    assertEquals(res.status, 409);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("PATCH for non-existent task returns 404", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request(
      `/boards/${BOARD_ID}/tasks/nonexistent`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Ghost" }),
      },
    );
    assertEquals(res.status, 404);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("DELETE /boards/:boardId/tasks/:taskId removes task (204)", async () => {
  const { app, dir } = await setup();
  try {
    // Create a task
    const createRes = await app.request(`/boards/${BOARD_ID}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Delete me" }),
    });
    const created = await createRes.json();

    const res = await app.request(
      `/boards/${BOARD_ID}/tasks/${created.id}`,
      { method: "DELETE" },
    );
    assertEquals(res.status, 204);

    // Verify it's gone
    const listRes = await app.request(`/boards/${BOARD_ID}/tasks`);
    const list = await listRes.json();
    assertEquals(list.length, 0);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("GET /boards/:boardId/tasks returns 404 for nonexistent board", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request("/boards/nonexistent-board/tasks");
    assertEquals(res.status, 404);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST /boards/:boardId/tasks returns 404 for nonexistent board", async () => {
  const { app, dir } = await setup();
  try {
    const res = await app.request("/boards/nonexistent-board/tasks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Orphan task" }),
    });
    assertEquals(res.status, 404);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("GET /boards/:boardId/tasks with status filter", async () => {
  const { app, dir } = await setup();
  try {
    // Create tasks with different statuses
    await app.request(`/boards/${BOARD_ID}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Backlog task" }),
    });
    await app.request(`/boards/${BOARD_ID}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Todo task", status: "todo" }),
    });
    await app.request(`/boards/${BOARD_ID}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Another backlog" }),
    });

    const res = await app.request(
      `/boards/${BOARD_ID}/tasks?status=backlog`,
    );
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.length, 2);

    const todoRes = await app.request(
      `/boards/${BOARD_ID}/tasks?status=todo`,
    );
    const todoBody = await todoRes.json();
    assertEquals(todoBody.length, 1);
    assertEquals(todoBody[0].title, "Todo task");
  } finally {
    await cleanup(dir);
  }
});
