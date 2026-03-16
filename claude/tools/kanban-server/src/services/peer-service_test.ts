import { assertEquals } from "@std/assert";
import { PeerService } from "./peer-service.ts";
import type { PeerNode } from "../config.ts";

const testPeer: PeerNode = {
  name: "mac-mini",
  host: "mac-mini.ts.net",
  port: 3456,
};

function mockFetch(
  responses: Map<string, { ok: boolean; body: unknown; delay?: number }>,
): typeof fetch {
  return (async (input: string | URL | Request) => {
    const url = typeof input === "string"
      ? input
      : input instanceof URL
      ? input.toString()
      : input.url;

    const response = responses.get(url);
    if (!response) {
      throw new TypeError("Network error");
    }
    if (response.delay) {
      await new Promise((r) => setTimeout(r, response.delay));
    }
    return new Response(JSON.stringify(response.body), {
      status: response.ok ? 200 : 500,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

Deno.test("pingAll returns online for reachable peer", async () => {
  const fetchFn = mockFetch(
    new Map([
      [
        "http://mac-mini.ts.net:3456/api/node/info",
        {
          ok: true,
          body: { nodeName: "mac-mini", activeSessions: [], uptime: 1000 },
        },
      ],
    ]),
  );
  const service = new PeerService([testPeer], fetchFn);
  const results = await service.pingAll();

  assertEquals(results.length, 1);
  assertEquals(results[0].name, "mac-mini");
  assertEquals(results[0].online, true);
});

Deno.test("pingAll returns offline for unreachable peer", async () => {
  const fetchFn = (async () => {
    throw new TypeError("Network error");
  }) as typeof fetch;

  const service = new PeerService([testPeer], fetchFn);
  const results = await service.pingAll();

  assertEquals(results.length, 1);
  assertEquals(results[0].online, false);
});

Deno.test("getNodeInfo returns node info", async () => {
  const info = {
    nodeName: "mac-mini",
    activeSessions: [{ id: "s1" }],
    uptime: 5000,
  };
  const fetchFn = mockFetch(
    new Map([
      ["http://mac-mini.ts.net:3456/api/node/info", { ok: true, body: info }],
    ]),
  );
  const service = new PeerService([testPeer], fetchFn);
  const result = await service.getNodeInfo(testPeer);

  assertEquals(result.nodeName, "mac-mini");
  assertEquals(result.uptime, 5000);
});

Deno.test("launchOnPeer sends POST to peer", async () => {
  const launchResult = { success: true, sessionId: "s-123" };
  const fetchFn = mockFetch(
    new Map([
      [
        "http://mac-mini.ts.net:3456/api/peers/mac-mini/launch",
        { ok: true, body: launchResult },
      ],
    ]),
  );
  const service = new PeerService([testPeer], fetchFn);
  const result = await service.launchOnPeer(testPeer, {
    taskId: "t1",
    boardId: "b1",
    projectPath: "/home/user/project",
  });

  assertEquals(result.success, true);
  assertEquals(result.sessionId, "s-123");
});

Deno.test("backoff after 3 consecutive failures", async () => {
  let callCount = 0;
  const fetchFn = (async () => {
    callCount++;
    throw new TypeError("Network error");
  }) as typeof fetch;

  const service = new PeerService([testPeer], fetchFn);

  // 3 consecutive failures
  await service.pingAll();
  await service.pingAll();
  await service.pingAll();

  assertEquals(service.isInBackoff("mac-mini"), true);

  // 4th call should skip due to backoff
  callCount = 0;
  const results = await service.pingAll();
  assertEquals(results[0].online, false);
  assertEquals(callCount, 0); // fetch was not called
});
