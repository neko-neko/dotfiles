import { Hono } from "@hono/hono";
import type { SessionRepository } from "../repositories/session-repository.ts";
import type { KanbanConfig } from "../config.ts";
import type { SessionStatus } from "../types.ts";

export function sessionsRoutes(
  sessionRepo: SessionRepository,
  config: KanbanConfig,
): Hono {
  const app = new Hono();

  // Static routes first (before /:id)
  app.get("/dashboard", async (c) => {
    const dashboard = await sessionRepo.dashboard();
    return c.json(dashboard);
  });

  app.get("/by-task/:taskId", async (c) => {
    const taskId = c.req.param("taskId");
    const sessions = await sessionRepo.listByTask(taskId);
    return c.json(sessions);
  });

  // GET / — list with filters
  app.get("/", async (c) => {
    const host = c.req.query("host");
    const status = c.req.query("status") as SessionStatus | undefined;

    const filters: { host?: string; status?: SessionStatus } = {};
    if (host) filters.host = host;
    if (status) filters.status = status;

    const sessions = await sessionRepo.list(
      Object.keys(filters).length > 0 ? filters : undefined,
    );
    return c.json(sessions);
  });

  // POST / — create session
  app.post("/", async (c) => {
    const body = await c.req.json<{
      taskId?: string;
      boardId?: string;
      host?: string;
      ownerNode?: string;
      worktree?: string;
      branch?: string;
      launchCommand?: string;
    }>();

    if (!body.taskId || !body.boardId || !body.host || !body.ownerNode) {
      return c.json(
        { error: "taskId, boardId, host, and ownerNode are required" },
        400,
      );
    }

    const session = await sessionRepo.create({
      taskId: body.taskId,
      boardId: body.boardId,
      host: body.host,
      ownerNode: body.ownerNode,
      worktree: body.worktree,
      branch: body.branch,
      launchCommand: body.launchCommand,
    });
    return c.json(session, 201);
  });

  // GET /:id
  app.get("/:id", async (c) => {
    const id = c.req.param("id");
    const session = await sessionRepo.get(id);
    if (!session) {
      return c.json({ error: "Session not found" }, 404);
    }
    return c.json(session);
  });

  // PATCH /:id — update (ownerNode validation via X-Node-Name header)
  app.patch("/:id", async (c) => {
    const id = c.req.param("id");
    const nodeName = c.req.header("X-Node-Name") ?? config.nodeName;
    const body = await c.req.json<{
      status?: SessionStatus;
      claudeSessionId?: string;
      handoverPath?: string;
      worktree?: string;
      branch?: string;
    }>();

    try {
      const updated = await sessionRepo.update(id, body, nodeName);
      return c.json(updated);
    } catch (e) {
      const msg = (e as Error).message;
      if (msg.includes("not found")) return c.json({ error: msg }, 404);
      if (msg.includes("ownerNode")) return c.json({ error: msg }, 403);
      if (msg.includes("Invalid transition")) {
        return c.json({ error: msg }, 400);
      }
      throw e;
    }
  });

  return app;
}
