import { assertEquals } from "@std/assert";
import { conflictRoutes } from "./conflicts.ts";
import { ConflictResolver } from "../services/conflict-resolver.ts";
import { FileWatcher } from "../services/file-watcher.ts";

async function setup() {
  const dir = await Deno.makeTempDir({
    prefix: "kanban-conflicts-route-test-",
  });
  await Deno.mkdir(`${dir}/boards/b1`, { recursive: true });
  await Deno.mkdir(`${dir}/sessions`, { recursive: true });
  const resolver = new ConflictResolver(dir);
  const watcher = new FileWatcher(resolver, dir, 60000);
  return { dir, resolver, watcher };
}

async function cleanup(dir: string) {
  await Deno.remove(dir, { recursive: true });
}

Deno.test("GET /conflicts returns pending conflicts", async () => {
  const { dir, resolver, watcher } = await setup();
  try {
    // Create an unresolvable conflict (same updatedAt)
    const data = { id: "t1", title: "A", updatedAt: "2026-01-01T00:00:00Z" };
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.json`,
      JSON.stringify(data),
    );
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.sync-conflict-20260101-120000-ABCDEFG.json`,
      JSON.stringify({ ...data, title: "B" }),
    );
    await watcher.scanOnce();

    const app = conflictRoutes(watcher, resolver);
    const res = await app.request("/conflicts");
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.length, 1);
  } finally {
    watcher.stop();
    await cleanup(dir);
  }
});

Deno.test("POST /conflicts/:id/resolve with invalid winner returns 400", async () => {
  const { dir, resolver, watcher } = await setup();
  try {
    const app = conflictRoutes(watcher, resolver);
    const res = await app.request("/conflicts/some-id/resolve", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ winner: "invalid" }),
    });
    assertEquals(res.status, 400);
  } finally {
    watcher.stop();
    await cleanup(dir);
  }
});

Deno.test("POST /conflicts/:id/resolve with unknown id returns 404", async () => {
  const { dir, resolver, watcher } = await setup();
  try {
    const app = conflictRoutes(watcher, resolver);
    const res = await app.request("/conflicts/nonexistent/resolve", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ winner: "local" }),
    });
    assertEquals(res.status, 404);
  } finally {
    watcher.stop();
    await cleanup(dir);
  }
});
