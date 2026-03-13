import { assertEquals } from "@std/assert";
import { Hono } from "@hono/hono";
import { syncRoutes } from "./sync.ts";
import { GitSyncService } from "../services/git-sync-service.ts";

async function setupGitRepo(): Promise<string> {
  const tmpDir = await Deno.makeTempDir({ prefix: "kanban-sync-route-" });
  const run = async (args: string[]) => {
    const cmd = new Deno.Command("git", {
      args,
      cwd: tmpDir,
      stdout: "null",
      stderr: "null",
    });
    await cmd.output();
  };
  await run(["init"]);
  await run(["config", "user.email", "test@test.com"]);
  await run(["config", "user.name", "Test"]);
  await Deno.writeTextFile(
    `${tmpDir}/boards.json`,
    '{"version":1,"boards":[]}',
  );
  await Deno.mkdir(`${tmpDir}/boards`);
  await run(["add", "."]);
  await run(["commit", "-m", "init"]);
  return tmpDir;
}

function createApp(dataDir: string): Hono {
  const gitSync = new GitSyncService(dataDir);
  const app = new Hono();
  app.route("/api", syncRoutes(gitSync));
  return app;
}

Deno.test("GET /sync/status returns clean for fresh repo", async () => {
  const tmpDir = await setupGitRepo();
  try {
    const app = createApp(tmpDir);
    const res = await app.request("/api/sync/status");
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.isRepo, true);
    assertEquals(body.dirty, false);
  } finally {
    await Deno.remove(tmpDir, { recursive: true });
  }
});

Deno.test("GET /sync/status returns dirty after change", async () => {
  const tmpDir = await setupGitRepo();
  try {
    await Deno.writeTextFile(
      `${tmpDir}/boards.json`,
      '{"version":1,"boards":[{"id":"b1"}]}',
    );
    const app = createApp(tmpDir);
    const res = await app.request("/api/sync/status");
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.isRepo, true);
    assertEquals(body.dirty, true);
  } finally {
    await Deno.remove(tmpDir, { recursive: true });
  }
});

Deno.test("POST /sync/push commits changes", async () => {
  const tmpDir = await setupGitRepo();
  try {
    await Deno.writeTextFile(
      `${tmpDir}/boards.json`,
      '{"version":1,"boards":[{"id":"b1"}]}',
    );
    const app = createApp(tmpDir);

    const pushRes = await app.request("/api/sync/push", { method: "POST" });
    assertEquals(pushRes.status, 200);
    const pushBody = await pushRes.json();
    assertEquals(pushBody.committed, true);

    // After push, status should be clean
    const statusRes = await app.request("/api/sync/status");
    const statusBody = await statusRes.json();
    assertEquals(statusBody.dirty, false);
  } finally {
    await Deno.remove(tmpDir, { recursive: true });
  }
});

Deno.test("POST /sync/push returns error when nothing to commit", async () => {
  const tmpDir = await setupGitRepo();
  try {
    const app = createApp(tmpDir);
    const res = await app.request("/api/sync/push", { method: "POST" });
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.committed, false);
  } finally {
    await Deno.remove(tmpDir, { recursive: true });
  }
});
