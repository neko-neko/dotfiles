import { Hono } from "@hono/hono";
import type { TaskRepository } from "../repositories/task-repository.ts";
import type {
  CreateTaskInput,
  Priority,
  TaskFilter,
  TaskStatus,
  UpdateTaskInput,
} from "../types.ts";

export function taskRoutes(taskRepo: TaskRepository): Hono {
  const app = new Hono();

  app.get("/boards/:boardId/tasks", async (c) => {
    const boardId = c.req.param("boardId");
    const filter: TaskFilter = {};

    const status = c.req.query("status");
    if (status) {
      filter.status = status as TaskStatus;
    }

    const priority = c.req.query("priority");
    if (priority) {
      filter.priority = priority as Priority;
    }

    const label = c.req.query("label");
    if (label) {
      filter.label = label;
    }

    const hasFilter = status || priority || label;
    try {
      const tasks = await taskRepo.listTasks(
        boardId,
        hasFilter ? filter : undefined,
      );
      return c.json(tasks);
    } catch (e) {
      if (e instanceof Error && e.message.includes("not found")) {
        return c.json({ error: e.message }, 404);
      }
      throw e;
    }
  });

  app.post("/boards/:boardId/tasks", async (c) => {
    const boardId = c.req.param("boardId");
    const body = await c.req.json<Partial<CreateTaskInput>>();

    if (typeof body.title !== "string" || body.title.length === 0) {
      return c.json({ error: "title is required" }, 400);
    }

    try {
      const task = await taskRepo.createTask(boardId, {
        title: body.title,
        description: body.description,
        status: body.status,
        priority: body.priority,
        labels: body.labels,
        worktree: body.worktree,
        sessionContext: body.sessionContext,
      });
      return c.json(task, 201);
    } catch (e) {
      if (e instanceof Error && e.message.includes("not found")) {
        return c.json({ error: e.message }, 404);
      }
      throw e;
    }
  });

  app.patch("/boards/:boardId/tasks/:taskId", async (c) => {
    const boardId = c.req.param("boardId");
    const taskId = c.req.param("taskId");
    const body = await c.req.json<UpdateTaskInput>();

    try {
      const task = await taskRepo.updateTask(boardId, taskId, body);
      return c.json(task, 200);
    } catch (e) {
      if (e instanceof Error) {
        if (e.message.includes("not found")) {
          return c.json({ error: e.message }, 404);
        }
        if (e.message.includes("version mismatch")) {
          return c.json({ error: e.message }, 409);
        }
      }
      throw e;
    }
  });

  app.delete("/boards/:boardId/tasks/:taskId", async (c) => {
    const boardId = c.req.param("boardId");
    const taskId = c.req.param("taskId");
    await taskRepo.deleteTask(boardId, taskId);
    return c.body(null, 204);
  });

  return app;
}
