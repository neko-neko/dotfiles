import { Hono } from "@hono/hono";
import { serveStatic } from "@hono/hono/deno";
import { cors } from "@hono/hono/cors";
import { boardRoutes } from "./src/routes/boards.ts";
import { taskRoutes } from "./src/routes/tasks.ts";
import { actionRoutes } from "./src/routes/actions.ts";
import { peerRoutes } from "./src/routes/peers.ts";
import { conflictRoutes } from "./src/routes/conflicts.ts";
import { sessionsRoutes } from "./src/routes/sessions.ts";
import { loadConfig } from "./src/config.ts";
import { JsonFileBoardRepository } from "./src/repositories/json-file-board-repository.ts";
import { JsonFileTaskRepository } from "./src/repositories/json-file-task-repository.ts";
import { SessionRepository } from "./src/repositories/session-repository.ts";
import { PeerService } from "./src/services/peer-service.ts";
import { ConflictResolver } from "./src/services/conflict-resolver.ts";
import { FileWatcher } from "./src/services/file-watcher.ts";

const DATA_DIR = Deno.env.get("KANBAN_DATA_DIR") ??
  `${Deno.env.get("HOME")}/.claude/kanban`;

// Ensure data directory exists
await Deno.mkdir(`${DATA_DIR}/boards`, { recursive: true });

const config = await loadConfig(DATA_DIR);

const boardRepo = new JsonFileBoardRepository(DATA_DIR);
const taskRepo = new JsonFileTaskRepository(DATA_DIR);
const sessionRepo = new SessionRepository(DATA_DIR);
const peerService = new PeerService(config.peers);
const conflictResolver = new ConflictResolver(DATA_DIR);
const fileWatcher = new FileWatcher(
  conflictResolver,
  DATA_DIR,
  config.syncthingWatchIntervalMs,
);

// Start file watcher for syncthing conflict detection
fileWatcher.start();

const app = new Hono();

app.use("*", cors());
app.get("/api/health", (c) => c.json({ status: "ok" }));
app.route("/api", boardRoutes(boardRepo));
app.route("/api", taskRoutes(taskRepo));
app.route("/api", actionRoutes(boardRepo, taskRepo));
app.route("/api", peerRoutes(peerService, sessionRepo, config));
app.route("/api", conflictRoutes(fileWatcher, conflictResolver));
app.route("/api/sessions", sessionsRoutes(sessionRepo, config));

app.use("/*", serveStatic({ root: "./public" }));

const port = parseInt(Deno.env.get("KANBAN_PORT") ?? "3456");
console.log(
  `Kanban server [${config.nodeName}] running on http://localhost:${port}`,
);
Deno.serve({ port }, app.fetch);
