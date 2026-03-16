import { Hono } from "@hono/hono";
import type { KanbanConfig } from "../config.ts";
import type { PeerService } from "../services/peer-service.ts";
import type { SessionRepository } from "../repositories/session-repository.ts";

const startTime = Date.now();

export function peerRoutes(
  peerService: PeerService,
  sessionRepo: SessionRepository,
  config: KanbanConfig,
): Hono {
  const app = new Hono();

  // GET /node/info
  app.get("/node/info", async (c) => {
    const sessions = await sessionRepo.list({
      host: config.nodeName,
      status: "in-progress",
    });
    return c.json({
      nodeName: config.nodeName,
      activeSessions: sessions,
      uptime: Date.now() - startTime,
    });
  });

  // GET /peers
  app.get("/peers", async (c) => {
    const statuses = await peerService.pingAll();
    return c.json(statuses);
  });

  // POST /peers/:name/launch
  app.post("/peers/:name/launch", async (c) => {
    const peerName = c.req.param("name");
    const peer = config.peers.find((p) => p.name === peerName);
    if (!peer) {
      return c.json({ error: `Peer '${peerName}' not found` }, 404);
    }

    const body = await c.req.json<{
      taskId?: string;
      boardId?: string;
      projectPath?: string;
    }>();

    if (!body.taskId || !body.boardId || !body.projectPath) {
      return c.json(
        { error: "taskId, boardId, and projectPath are required" },
        400,
      );
    }

    // Create session
    const session = await sessionRepo.create({
      taskId: body.taskId,
      boardId: body.boardId,
      host: peerName,
      ownerNode: peerName,
      launchCommand: peer.launchCommand,
    });

    // Launch on peer
    try {
      const result = await peerService.launchOnPeer(peer, {
        taskId: body.taskId,
        boardId: body.boardId,
        projectPath: body.projectPath,
      });

      if (result.success) {
        return c.json({ sessionId: session.id, ...result });
      }
      return c.json({ error: result.error, sessionId: session.id }, 500);
    } catch (e) {
      return c.json(
        { error: (e as Error).message, sessionId: session.id },
        500,
      );
    }
  });

  return app;
}
