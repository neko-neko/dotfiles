import { Hono } from "@hono/hono";
import type { GitSyncService } from "../services/git-sync-service.ts";

export function syncRoutes(gitSync: GitSyncService): Hono {
  const app = new Hono();

  // GET /sync/status
  app.get("/sync/status", async (c) => {
    const status = await gitSync.getStatus();
    return c.json(status);
  });

  // POST /sync/pull
  app.post("/sync/pull", async (c) => {
    const result = await gitSync.pull();
    return c.json(result);
  });

  // POST /sync/push
  app.post("/sync/push", async (c) => {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(
      0,
      19,
    );
    const result = await gitSync.commitAndPush(`kanban sync ${timestamp}`);
    return c.json(result);
  });

  return app;
}
