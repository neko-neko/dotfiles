import { assertEquals } from "@std/assert";
import { peerRoutes } from "./peers.ts";
import type { KanbanConfig } from "../config.ts";
import { SessionRepository } from "../repositories/session-repository.ts";
import { PeerService } from "../services/peer-service.ts";

const config: KanbanConfig = {
  port: 3456,
  dataDir: "",
  nodeName: "macbook-main",
  peers: [{ name: "mac-mini", host: "mac-mini.ts.net", port: 3456 }],
  syncthingWatchIntervalMs: 5000,
  peerPollIntervalMs: 10000,
};

async function setup() {
  const dir = await Deno.makeTempDir({ prefix: "kanban-peers-route-test-" });
  const sessionRepo = new SessionRepository(dir);
  return { dir, sessionRepo };
}

async function cleanup(dir: string) {
  await Deno.remove(dir, { recursive: true });
}

Deno.test("GET /node/info returns node info", async () => {
  const { dir, sessionRepo } = await setup();
  try {
    const peerService = new PeerService([], async () => {
      return new Response("{}");
    });
    const app = peerRoutes(peerService, sessionRepo, {
      ...config,
      dataDir: dir,
    });

    const res = await app.request("/node/info");
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.nodeName, "macbook-main");
    assertEquals(typeof body.uptime, "number");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("GET /peers returns peer statuses", async () => {
  const { dir, sessionRepo } = await setup();
  try {
    const peerService = new PeerService(
      config.peers,
      async () => {
        return new Response(
          JSON.stringify({
            nodeName: "mac-mini",
            activeSessions: [],
            uptime: 1000,
          }),
        );
      },
    );
    const app = peerRoutes(peerService, sessionRepo, {
      ...config,
      dataDir: dir,
    });

    const res = await app.request("/peers");
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.length, 1);
    assertEquals(body[0].name, "mac-mini");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST /peers/:name/launch with missing peer returns 404", async () => {
  const { dir, sessionRepo } = await setup();
  try {
    const peerService = new PeerService([], async () => {
      return new Response("{}");
    });
    const app = peerRoutes(peerService, sessionRepo, {
      ...config,
      dataDir: dir,
    });

    const res = await app.request("/peers/nonexistent/launch", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        taskId: "t1",
        boardId: "b1",
        projectPath: "/tmp",
      }),
    });
    assertEquals(res.status, 404);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("POST /peers/:name/launch with missing body fields returns 400", async () => {
  const { dir, sessionRepo } = await setup();
  try {
    const peerService = new PeerService([], async () => {
      return new Response("{}");
    });
    const app = peerRoutes(peerService, sessionRepo, {
      ...config,
      dataDir: dir,
    });

    const res = await app.request("/peers/mac-mini/launch", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ taskId: "t1" }), // missing boardId, projectPath
    });
    assertEquals(res.status, 400);
  } finally {
    await cleanup(dir);
  }
});
