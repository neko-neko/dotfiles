import { Hono } from "@hono/hono";
import type { FileWatcher } from "../services/file-watcher.ts";
import type { ConflictResolver } from "../services/conflict-resolver.ts";

export function conflictRoutes(
  fileWatcher: FileWatcher,
  conflictResolver: ConflictResolver,
): Hono {
  const app = new Hono();

  // GET /conflicts
  app.get("/conflicts", (c) => {
    const pending = fileWatcher.getPendingConflicts();
    return c.json(pending);
  });

  // POST /conflicts/:id/resolve
  app.post("/conflicts/:id/resolve", async (c) => {
    const conflictId = c.req.param("id");
    const body = await c.req.json<{ winner?: string }>();

    if (!body.winner || !["local", "remote"].includes(body.winner)) {
      return c.json(
        { error: "winner must be 'local' or 'remote'" },
        400,
      );
    }

    const pending = fileWatcher.getPendingConflicts();
    const conflict = pending.find((p) => p.id === conflictId);
    if (!conflict) {
      return c.json({ error: `Conflict '${conflictId}' not found` }, 404);
    }

    // Manual resolution: apply the winner
    if (body.winner === "remote") {
      try {
        const raw = await Deno.readTextFile(conflict.conflictPath);
        await Deno.writeTextFile(conflict.originalPath, raw);
      } catch (e) {
        return c.json({ error: (e as Error).message }, 500);
      }
    }

    // Remove conflict file
    try {
      await Deno.remove(conflict.conflictPath);
    } catch {
      // already removed
    }

    return c.json({ resolved: true, winner: body.winner });
  });

  return app;
}
