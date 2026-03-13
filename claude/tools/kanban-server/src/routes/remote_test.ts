import { assertEquals } from "@std/assert";
import { Hono } from "@hono/hono";
import { remoteRoutes } from "./remote.ts";
import type { KanbanConfig } from "../config.ts";

const testConfig: KanbanConfig = {
  port: 3456,
  dataDir: "/tmp/test",
  remotes: {
    "test-host": {
      host: "test-host",
      repos: { kanban: "~/.claude/kanban", dotfiles: "~/.dotfiles" },
      zellijLayout: "compact",
    },
  },
  defaultRemote: "test-host",
};

function createApp(config: KanbanConfig) {
  const app = new Hono();
  app.route("/api", remoteRoutes(config));
  return app;
}

Deno.test("GET /remote/hosts returns configured hosts", async () => {
  const app = createApp(testConfig);
  const res = await app.request("/api/remote/hosts");
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.hosts.length, 1);
  assertEquals(body.hosts[0].name, "test-host");
  assertEquals(body.hosts[0].host, "test-host");
  assertEquals(body.defaultRemote, "test-host");
});

Deno.test("GET /remote/hosts returns empty for no remotes", async () => {
  const app = createApp({
    ...testConfig,
    remotes: {},
    defaultRemote: undefined,
  });
  const res = await app.request("/api/remote/hosts");
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.hosts.length, 0);
  assertEquals(body.defaultRemote, undefined);
});

Deno.test("POST /remote/launch returns 400 for missing taskId", async () => {
  const app = createApp(testConfig);
  const res = await app.request("/api/remote/launch", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ projectPath: "/some/path" }),
  });
  assertEquals(res.status, 400);
  const body = await res.json();
  assertEquals(body.error, "taskId is required");
});

Deno.test("POST /remote/launch returns 400 for missing projectPath", async () => {
  const app = createApp(testConfig);
  const res = await app.request("/api/remote/launch", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ taskId: "task-1" }),
  });
  assertEquals(res.status, 400);
  const body = await res.json();
  assertEquals(body.error, "projectPath is required");
});

Deno.test("POST /remote/launch returns 404 for unknown host", async () => {
  const app = createApp(testConfig);
  const res = await app.request("/api/remote/launch", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      taskId: "task-1",
      projectPath: "/some/path",
      host: "unknown-host",
    }),
  });
  assertEquals(res.status, 404);
  const body = await res.json();
  assertEquals(body.error, "unknown host: unknown-host");
});
