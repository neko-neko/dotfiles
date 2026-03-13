import { Hono } from "@hono/hono";
import type { SessionRepository } from "../repositories/session-repository.ts";

export function sessionsRoutes(sessionRepo: SessionRepository): Hono {
  const app = new Hono();

  app.get("/", async (c) => {
    const host = c.req.query("host");
    const status = c.req.query("status");

    const filters: { host?: string; status?: string } = {};
    if (host) filters.host = host;
    if (status) filters.status = status;

    const sessions = await sessionRepo.list(
      Object.keys(filters).length > 0 ? filters : undefined,
    );
    return c.json(sessions);
  });

  app.get("/dashboard", async (c) => {
    const dashboard = await sessionRepo.dashboard();
    return c.json(dashboard);
  });

  app.get("/:id", async (c) => {
    const id = c.req.param("id");
    const session = await sessionRepo.get(id);

    if (!session) {
      return c.json({ error: "Session not found" }, 404);
    }

    return c.json(session);
  });

  return app;
}
