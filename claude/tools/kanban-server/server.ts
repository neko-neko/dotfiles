import { Hono } from "@hono/hono";
import { serveStatic } from "@hono/hono/deno";
import { cors } from "@hono/hono/cors";
import { boardRoutes } from "./src/routes/boards.ts";
import { taskRoutes } from "./src/routes/tasks.ts";
import { actionRoutes } from "./src/routes/actions.ts";
import { syncRoutes } from "./src/routes/sync.ts";
import { remoteRoutes } from "./src/routes/remote.ts";
import { loadConfig } from "./src/config.ts";
import { JsonFileBoardRepository } from "./src/repositories/json-file-board-repository.ts";
import { JsonFileTaskRepository } from "./src/repositories/json-file-task-repository.ts";
import { GitSyncService } from "./src/services/git-sync-service.ts";

const DATA_DIR = Deno.env.get("KANBAN_DATA_DIR") ??
  `${Deno.env.get("HOME")}/.claude/kanban`;

// Ensure data directory exists
await Deno.mkdir(`${DATA_DIR}/boards`, { recursive: true });
try {
  await Deno.stat(`${DATA_DIR}/boards.json`);
} catch {
  await Deno.writeTextFile(
    `${DATA_DIR}/boards.json`,
    JSON.stringify({ version: 1, boards: [] }, null, 2),
  );
}

const boardRepo = new JsonFileBoardRepository(DATA_DIR);
const taskRepo = new JsonFileTaskRepository(DATA_DIR);

const app = new Hono();

app.use("*", cors());
app.get("/api/health", (c) => c.json({ status: "ok" }));
app.route("/api", boardRoutes(boardRepo));
app.route("/api", taskRoutes(taskRepo));
app.route("/api", actionRoutes(boardRepo, taskRepo));

const gitSync = new GitSyncService(DATA_DIR);
app.route("/api", syncRoutes(gitSync));

const config = await loadConfig(DATA_DIR);
app.route("/api", remoteRoutes(config));

// Auto-pull on startup
try {
  const pullResult = await gitSync.pull();
  if (pullResult.pulled) {
    console.log("Kanban data pulled from remote");
  }
} catch {
  // no remote or not a git repo — ok
}

app.use("/*", serveStatic({ root: "./public" }));

const port = parseInt(Deno.env.get("KANBAN_PORT") ?? "3456");
console.log(`Kanban server running on http://localhost:${port}`);
Deno.serve({ port }, app.fetch);
