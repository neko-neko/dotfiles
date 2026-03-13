# Kanban Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** ローカル kanban ボード（Deno + Hono API サーバー + Web UI）と Claude Code スキルを構築し、複数ワークツリーのタスク管理を実現する。

**Architecture:** JSON ファイルベースのデータストア（`~/.claude/kanban/`）に対して、API サーバー（Deno + Hono）と Claude Code スキルが疎結合で操作する。Web UI はビルドステップなしで Preact + HTM + Tailwind CSS を CDN から読み込む。リポジトリパターンで将来の Linear 等への移行に備える。

**Tech Stack:** Deno, Hono, Preact + HTM (CDN), Tailwind CSS (CDN), SortableJS (CDN)

**Design doc:** `docs/plans/2026-03-13-kanban-skill-design.md`

**Project locations:**
- Server: `~/.claude/tools/kanban-server/`
- Data: `~/.claude/kanban/`
- Skill: `~/.dotfiles/claude/skills/kanban/`

---

### Task 1: Environment Setup & Project Scaffold

**Files:**
- Create: `~/.claude/tools/kanban-server/deno.json`
- Create: `~/.claude/tools/kanban-server/server.ts`
- Create: `~/.claude/kanban/boards.json`
- Create: `~/.claude/kanban/boards/` (directory)
- Create: `~/.claude/kanban/config.json`

**Step 1: Install Deno via mise**

Run: `mise use -g deno@latest`
Expected: Deno installed globally

**Step 2: Verify Deno installation**

Run: `deno --version`
Expected: deno 2.x.x (or latest)

**Step 3: Check latest Hono version for Deno**

Use context7 MCP tool to resolve `hono` library and query docs for Deno setup.
Verify: import URL format (e.g., `jsr:@hono/hono`)

**Step 4: Create project directory and deno.json**

```json
{
  "tasks": {
    "dev": "deno run --allow-net --allow-read --allow-write --allow-run --watch server.ts",
    "start": "deno run --allow-net --allow-read --allow-write --allow-run server.ts",
    "test": "deno test --allow-read --allow-write"
  },
  "imports": {
    "@hono/hono": "jsr:@hono/hono@^4",
    "@std/assert": "jsr:@std/assert@^1",
    "@std/path": "jsr:@std/path@^1",
    "@std/fs": "jsr:@std/fs@^1"
  }
}
```

Note: import map は `deno.json` の `imports` で管理。バージョンは実装時に context7 で最新を確認すること。

**Step 5: Create minimal server.ts**

```typescript
import { Hono } from "@hono/hono";

const app = new Hono();

app.get("/api/health", (c) => c.json({ status: "ok" }));

Deno.serve({ port: 3456 }, app.fetch);
```

**Step 6: Create initial data directory and files**

`~/.claude/kanban/boards.json`:
```json
{
  "version": 1,
  "boards": []
}
```

`~/.claude/kanban/config.json`:
```json
{
  "port": 3456,
  "dataDir": "~/.claude/kanban"
}
```

Create empty directory: `~/.claude/kanban/boards/`

**Step 7: Run server and verify**

Run: `cd ~/.claude/tools/kanban-server && deno task dev`
Expected: Server starts on port 3456

Run (in another terminal): `curl http://localhost:3456/api/health`
Expected: `{"status":"ok"}`

**Step 8: Initialize git repo and commit**

```bash
cd ~/.claude/tools/kanban-server
git init
echo "node_modules/" > .gitignore
git add .
git commit -m "feat: initial project scaffold with Deno + Hono"
```

---

### Task 2: Data Types & Repository Interfaces

**Files:**
- Create: `~/.claude/tools/kanban-server/src/types.ts`
- Create: `~/.claude/tools/kanban-server/src/repositories/board-repository.ts`
- Create: `~/.claude/tools/kanban-server/src/repositories/task-repository.ts`
- Create: `~/.claude/tools/kanban-server/src/repositories/mod.ts`

**Step 1: Define data types**

`src/types.ts`:
```typescript
export type TaskStatus = "backlog" | "todo" | "in_progress" | "review" | "done";
export type Priority = "high" | "medium" | "low";

export interface SessionContext {
  lastSessionId?: string;
  handoverFile?: string;
  resumeHint?: string;
}

export interface Task {
  id: string;
  title: string;
  description: string;
  status: TaskStatus;
  priority: Priority;
  labels: string[];
  worktree?: string;
  sessionContext?: SessionContext;
  createdAt: string;
  updatedAt: string;
}

export interface Board {
  id: string;
  name: string;
  path: string;
  createdAt: string;
  updatedAt: string;
}

export interface BoardData {
  version: number;
  boardId: string;
  columns: TaskStatus[];
  tasks: Task[];
}

export interface BoardsIndex {
  version: number;
  boards: Board[];
}

export interface CreateBoardInput {
  id: string;
  name: string;
  path: string;
}

export interface CreateTaskInput {
  title: string;
  description?: string;
  status?: TaskStatus;
  priority?: Priority;
  labels?: string[];
  worktree?: string;
  sessionContext?: SessionContext;
}

export interface UpdateTaskInput {
  title?: string;
  description?: string;
  status?: TaskStatus;
  priority?: Priority;
  labels?: string[];
  worktree?: string;
  sessionContext?: SessionContext;
  expectedVersion?: string; // updatedAt for optimistic locking
}

export interface TaskFilter {
  status?: TaskStatus;
  priority?: Priority;
  label?: string;
}

export interface TaskMove {
  taskId: string;
  status: TaskStatus;
}
```

**Step 2: Define repository interfaces**

`src/repositories/board-repository.ts`:
```typescript
import type { Board, CreateBoardInput } from "../types.ts";

export interface BoardRepository {
  listBoards(): Promise<Board[]>;
  getBoard(id: string): Promise<Board | null>;
  createBoard(input: CreateBoardInput): Promise<Board>;
  deleteBoard(id: string): Promise<void>;
}
```

`src/repositories/task-repository.ts`:
```typescript
import type { Task, CreateTaskInput, UpdateTaskInput, TaskFilter, TaskMove } from "../types.ts";

export interface TaskRepository {
  listTasks(boardId: string, filter?: TaskFilter): Promise<Task[]>;
  getTask(boardId: string, taskId: string): Promise<Task | null>;
  createTask(boardId: string, input: CreateTaskInput): Promise<Task>;
  updateTask(boardId: string, taskId: string, input: UpdateTaskInput): Promise<Task>;
  deleteTask(boardId: string, taskId: string): Promise<void>;
  moveTasks(boardId: string, moves: TaskMove[]): Promise<Task[]>;
}
```

`src/repositories/mod.ts`:
```typescript
export type { BoardRepository } from "./board-repository.ts";
export type { TaskRepository } from "./task-repository.ts";
```

**Step 3: Verify types compile**

Run: `deno check src/types.ts src/repositories/mod.ts`
Expected: No errors

**Step 4: Commit**

```bash
git add src/
git commit -m "feat: define data types and repository interfaces"
```

---

### Task 3: JsonFileBoardRepository (TDD)

**Files:**
- Create: `~/.claude/tools/kanban-server/src/repositories/json-file-board-repository.ts`
- Create: `~/.claude/tools/kanban-server/src/repositories/json-file-board-repository_test.ts`

**Step 1: Write failing tests**

`src/repositories/json-file-board-repository_test.ts`:
```typescript
import { assertEquals, assertRejects } from "@std/assert";
import { JsonFileBoardRepository } from "./json-file-board-repository.ts";

const TEST_DIR = await Deno.makeTempDir({ prefix: "kanban-test-" });

async function setup(): Promise<JsonFileBoardRepository> {
  const dir = await Deno.makeTempDir({ dir: TEST_DIR });
  await Deno.writeTextFile(`${dir}/boards.json`, JSON.stringify({ version: 1, boards: [] }));
  await Deno.mkdir(`${dir}/boards`);
  return new JsonFileBoardRepository(dir);
}

Deno.test("listBoards returns empty array initially", async () => {
  const repo = await setup();
  const boards = await repo.listBoards();
  assertEquals(boards, []);
});

Deno.test("createBoard adds a board and returns it", async () => {
  const repo = await setup();
  const board = await repo.createBoard({ id: "test-pj", name: "Test Project", path: "/tmp/test" });
  assertEquals(board.id, "test-pj");
  assertEquals(board.name, "Test Project");
  assertEquals(board.path, "/tmp/test");
  assertEquals(typeof board.createdAt, "string");

  const boards = await repo.listBoards();
  assertEquals(boards.length, 1);
});

Deno.test("createBoard rejects duplicate id", async () => {
  const repo = await setup();
  await repo.createBoard({ id: "dup", name: "Dup", path: "/tmp/dup" });
  await assertRejects(() => repo.createBoard({ id: "dup", name: "Dup2", path: "/tmp/dup2" }));
});

Deno.test("getBoard returns board by id", async () => {
  const repo = await setup();
  await repo.createBoard({ id: "find-me", name: "Find Me", path: "/tmp/find" });
  const board = await repo.getBoard("find-me");
  assertEquals(board?.id, "find-me");
});

Deno.test("getBoard returns null for missing id", async () => {
  const repo = await setup();
  const board = await repo.getBoard("nonexistent");
  assertEquals(board, null);
});

Deno.test("deleteBoard removes the board", async () => {
  const repo = await setup();
  await repo.createBoard({ id: "del", name: "Del", path: "/tmp/del" });
  await repo.deleteBoard("del");
  const boards = await repo.listBoards();
  assertEquals(boards.length, 0);
});

Deno.test("createBoard also creates board data file", async () => {
  const repo = await setup();
  await repo.createBoard({ id: "with-file", name: "With File", path: "/tmp/wf" });
  // Board data file should exist and have correct structure
  const dataDir = (repo as any).dataDir; // access private for test verification
  const data = JSON.parse(await Deno.readTextFile(`${dataDir}/boards/with-file.json`));
  assertEquals(data.boardId, "with-file");
  assertEquals(data.columns.length, 5);
  assertEquals(data.tasks, []);
});
```

**Step 2: Run tests to verify they fail**

Run: `cd ~/.claude/tools/kanban-server && deno test src/repositories/json-file-board-repository_test.ts`
Expected: FAIL (module not found)

**Step 3: Implement JsonFileBoardRepository**

`src/repositories/json-file-board-repository.ts`:
```typescript
import type { Board, BoardData, BoardsIndex, CreateBoardInput } from "../types.ts";
import type { BoardRepository } from "./board-repository.ts";

export class JsonFileBoardRepository implements BoardRepository {
  private readonly dataDir: string;

  constructor(dataDir: string) {
    this.dataDir = dataDir;
  }

  private indexPath(): string {
    return `${this.dataDir}/boards.json`;
  }

  private boardDataPath(boardId: string): string {
    return `${this.dataDir}/boards/${boardId}.json`;
  }

  private async readIndex(): Promise<BoardsIndex> {
    const text = await Deno.readTextFile(this.indexPath());
    return JSON.parse(text) as BoardsIndex;
  }

  private async writeIndex(index: BoardsIndex): Promise<void> {
    await Deno.writeTextFile(this.indexPath(), JSON.stringify(index, null, 2));
  }

  async listBoards(): Promise<Board[]> {
    const index = await this.readIndex();
    return index.boards;
  }

  async getBoard(id: string): Promise<Board | null> {
    const index = await this.readIndex();
    return index.boards.find((b) => b.id === id) ?? null;
  }

  async createBoard(input: CreateBoardInput): Promise<Board> {
    const index = await this.readIndex();
    if (index.boards.some((b) => b.id === input.id)) {
      throw new Error(`Board with id "${input.id}" already exists`);
    }

    const now = new Date().toISOString();
    const board: Board = {
      id: input.id,
      name: input.name,
      path: input.path,
      createdAt: now,
      updatedAt: now,
    };

    index.boards.push(board);
    await this.writeIndex(index);

    const boardData: BoardData = {
      version: 1,
      boardId: input.id,
      columns: ["backlog", "todo", "in_progress", "review", "done"],
      tasks: [],
    };
    await Deno.writeTextFile(this.boardDataPath(input.id), JSON.stringify(boardData, null, 2));

    return board;
  }

  async deleteBoard(id: string): Promise<void> {
    const index = await this.readIndex();
    index.boards = index.boards.filter((b) => b.id !== id);
    await this.writeIndex(index);

    try {
      await Deno.remove(this.boardDataPath(id));
    } catch {
      // File may not exist
    }
  }
}
```

**Step 4: Run tests to verify they pass**

Run: `deno test src/repositories/json-file-board-repository_test.ts`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add src/repositories/
git commit -m "feat: implement JsonFileBoardRepository with tests"
```

---

### Task 4: JsonFileTaskRepository (TDD)

**Files:**
- Create: `~/.claude/tools/kanban-server/src/repositories/json-file-task-repository.ts`
- Create: `~/.claude/tools/kanban-server/src/repositories/json-file-task-repository_test.ts`

**Step 1: Write failing tests**

`src/repositories/json-file-task-repository_test.ts`:
```typescript
import { assertEquals, assertRejects } from "@std/assert";
import { JsonFileTaskRepository } from "./json-file-task-repository.ts";
import type { BoardData } from "../types.ts";

async function setup(): Promise<{ repo: JsonFileTaskRepository; dir: string }> {
  const dir = await Deno.makeTempDir({ prefix: "kanban-task-test-" });
  await Deno.mkdir(`${dir}/boards`);
  const boardData: BoardData = {
    version: 1,
    boardId: "test-board",
    columns: ["backlog", "todo", "in_progress", "review", "done"],
    tasks: [],
  };
  await Deno.writeTextFile(`${dir}/boards/test-board.json`, JSON.stringify(boardData));
  return { repo: new JsonFileTaskRepository(dir), dir };
}

Deno.test("listTasks returns empty initially", async () => {
  const { repo } = await setup();
  const tasks = await repo.listTasks("test-board");
  assertEquals(tasks, []);
});

Deno.test("createTask adds a task with generated id", async () => {
  const { repo } = await setup();
  const task = await repo.createTask("test-board", { title: "Test task" });
  assertEquals(task.title, "Test task");
  assertEquals(task.status, "backlog"); // default
  assertEquals(task.priority, "medium"); // default
  assertEquals(task.labels, []);
  assertEquals(task.id.startsWith("t-"), true);
});

Deno.test("getTask returns task by id", async () => {
  const { repo } = await setup();
  const created = await repo.createTask("test-board", { title: "Find me" });
  const found = await repo.getTask("test-board", created.id);
  assertEquals(found?.title, "Find me");
});

Deno.test("getTask returns null for missing id", async () => {
  const { repo } = await setup();
  const found = await repo.getTask("test-board", "nonexistent");
  assertEquals(found, null);
});

Deno.test("updateTask modifies task fields", async () => {
  const { repo } = await setup();
  const created = await repo.createTask("test-board", { title: "Original" });
  const updated = await repo.updateTask("test-board", created.id, {
    title: "Updated",
    status: "in_progress",
    priority: "high",
  });
  assertEquals(updated.title, "Updated");
  assertEquals(updated.status, "in_progress");
  assertEquals(updated.priority, "high");
});

Deno.test("updateTask with optimistic lock rejects on version mismatch", async () => {
  const { repo } = await setup();
  const created = await repo.createTask("test-board", { title: "Locked" });
  await assertRejects(
    () => repo.updateTask("test-board", created.id, {
      title: "Should fail",
      expectedVersion: "1970-01-01T00:00:00.000Z",
    }),
    Error,
    "conflict",
  );
});

Deno.test("deleteTask removes the task", async () => {
  const { repo } = await setup();
  const created = await repo.createTask("test-board", { title: "Delete me" });
  await repo.deleteTask("test-board", created.id);
  const tasks = await repo.listTasks("test-board");
  assertEquals(tasks.length, 0);
});

Deno.test("listTasks with filter", async () => {
  const { repo } = await setup();
  await repo.createTask("test-board", { title: "T1", status: "backlog", priority: "high" });
  await repo.createTask("test-board", { title: "T2", status: "in_progress", priority: "low" });
  await repo.createTask("test-board", { title: "T3", status: "backlog", priority: "low" });

  const backlog = await repo.listTasks("test-board", { status: "backlog" });
  assertEquals(backlog.length, 2);

  const high = await repo.listTasks("test-board", { priority: "high" });
  assertEquals(high.length, 1);
});

Deno.test("moveTasks bulk moves", async () => {
  const { repo } = await setup();
  const t1 = await repo.createTask("test-board", { title: "T1" });
  const t2 = await repo.createTask("test-board", { title: "T2" });
  const moved = await repo.moveTasks("test-board", [
    { taskId: t1.id, status: "in_progress" },
    { taskId: t2.id, status: "done" },
  ]);
  assertEquals(moved[0].status, "in_progress");
  assertEquals(moved[1].status, "done");
});

Deno.test("listTasks with label filter", async () => {
  const { repo } = await setup();
  await repo.createTask("test-board", { title: "T1", labels: ["frontend"] });
  await repo.createTask("test-board", { title: "T2", labels: ["backend"] });
  const frontend = await repo.listTasks("test-board", { label: "frontend" });
  assertEquals(frontend.length, 1);
  assertEquals(frontend[0].title, "T1");
});

Deno.test("createTask rejects for nonexistent board", async () => {
  const { repo } = await setup();
  await assertRejects(() => repo.createTask("nonexistent", { title: "Fail" }));
});
```

**Step 2: Run tests to verify they fail**

Run: `deno test src/repositories/json-file-task-repository_test.ts`
Expected: FAIL

**Step 3: Implement JsonFileTaskRepository**

`src/repositories/json-file-task-repository.ts`:
```typescript
import type { BoardData, CreateTaskInput, Task, TaskFilter, TaskMove, UpdateTaskInput } from "../types.ts";
import type { TaskRepository } from "./task-repository.ts";

export class JsonFileTaskRepository implements TaskRepository {
  private readonly dataDir: string;

  constructor(dataDir: string) {
    this.dataDir = dataDir;
  }

  private boardDataPath(boardId: string): string {
    return `${this.dataDir}/boards/${boardId}.json`;
  }

  private async readBoardData(boardId: string): Promise<BoardData> {
    try {
      const text = await Deno.readTextFile(this.boardDataPath(boardId));
      return JSON.parse(text) as BoardData;
    } catch {
      throw new Error(`Board "${boardId}" not found`);
    }
  }

  private async writeBoardData(boardId: string, data: BoardData): Promise<void> {
    await Deno.writeTextFile(this.boardDataPath(boardId), JSON.stringify(data, null, 2));
  }

  private generateId(): string {
    const now = new Date();
    const date = now.toISOString().slice(0, 10).replace(/-/g, "");
    const seq = String(Math.floor(Math.random() * 999) + 1).padStart(3, "0");
    return `t-${date}-${seq}`;
  }

  async listTasks(boardId: string, filter?: TaskFilter): Promise<Task[]> {
    const data = await this.readBoardData(boardId);
    let tasks = data.tasks;

    if (filter?.status) {
      tasks = tasks.filter((t) => t.status === filter.status);
    }
    if (filter?.priority) {
      tasks = tasks.filter((t) => t.priority === filter.priority);
    }
    if (filter?.label) {
      tasks = tasks.filter((t) => t.labels.includes(filter.label!));
    }

    return tasks;
  }

  async getTask(boardId: string, taskId: string): Promise<Task | null> {
    const data = await this.readBoardData(boardId);
    return data.tasks.find((t) => t.id === taskId) ?? null;
  }

  async createTask(boardId: string, input: CreateTaskInput): Promise<Task> {
    const data = await this.readBoardData(boardId);
    const now = new Date().toISOString();

    const task: Task = {
      id: this.generateId(),
      title: input.title,
      description: input.description ?? "",
      status: input.status ?? "backlog",
      priority: input.priority ?? "medium",
      labels: input.labels ?? [],
      worktree: input.worktree,
      sessionContext: input.sessionContext,
      createdAt: now,
      updatedAt: now,
    };

    data.tasks.push(task);
    await this.writeBoardData(boardId, data);
    return task;
  }

  async updateTask(boardId: string, taskId: string, input: UpdateTaskInput): Promise<Task> {
    const data = await this.readBoardData(boardId);
    const idx = data.tasks.findIndex((t) => t.id === taskId);
    if (idx === -1) {
      throw new Error(`Task "${taskId}" not found in board "${boardId}"`);
    }

    const existing = data.tasks[idx];

    if (input.expectedVersion && existing.updatedAt !== input.expectedVersion) {
      throw new Error(`Version conflict: expected ${input.expectedVersion}, got ${existing.updatedAt}`);
    }

    const now = new Date().toISOString();
    const updated: Task = {
      ...existing,
      ...(input.title !== undefined && { title: input.title }),
      ...(input.description !== undefined && { description: input.description }),
      ...(input.status !== undefined && { status: input.status }),
      ...(input.priority !== undefined && { priority: input.priority }),
      ...(input.labels !== undefined && { labels: input.labels }),
      ...(input.worktree !== undefined && { worktree: input.worktree }),
      ...(input.sessionContext !== undefined && { sessionContext: input.sessionContext }),
      updatedAt: now,
    };

    data.tasks[idx] = updated;
    await this.writeBoardData(boardId, data);
    return updated;
  }

  async deleteTask(boardId: string, taskId: string): Promise<void> {
    const data = await this.readBoardData(boardId);
    data.tasks = data.tasks.filter((t) => t.id !== taskId);
    await this.writeBoardData(boardId, data);
  }

  async moveTasks(boardId: string, moves: TaskMove[]): Promise<Task[]> {
    const data = await this.readBoardData(boardId);
    const now = new Date().toISOString();
    const results: Task[] = [];

    for (const move of moves) {
      const idx = data.tasks.findIndex((t) => t.id === move.taskId);
      if (idx === -1) {
        throw new Error(`Task "${move.taskId}" not found`);
      }
      data.tasks[idx] = { ...data.tasks[idx], status: move.status, updatedAt: now };
      results.push(data.tasks[idx]);
    }

    await this.writeBoardData(boardId, data);
    return results;
  }
}
```

**Step 4: Run tests to verify they pass**

Run: `deno test src/repositories/json-file-task-repository_test.ts`
Expected: All tests PASS

**Step 5: Update mod.ts and commit**

Add exports to `src/repositories/mod.ts`:
```typescript
export type { BoardRepository } from "./board-repository.ts";
export type { TaskRepository } from "./task-repository.ts";
export { JsonFileBoardRepository } from "./json-file-board-repository.ts";
export { JsonFileTaskRepository } from "./json-file-task-repository.ts";
```

```bash
git add src/
git commit -m "feat: implement JsonFileTaskRepository with tests"
```

---

### Task 5: API Server - Board Routes (TDD)

**Files:**
- Create: `~/.claude/tools/kanban-server/src/routes/boards.ts`
- Create: `~/.claude/tools/kanban-server/src/routes/boards_test.ts`
- Modify: `~/.claude/tools/kanban-server/server.ts`

**Step 1: Write failing tests**

`src/routes/boards_test.ts`:
```typescript
import { assertEquals } from "@std/assert";
import { Hono } from "@hono/hono";
import { boardRoutes } from "./boards.ts";
import { JsonFileBoardRepository } from "../repositories/json-file-board-repository.ts";

async function createTestApp() {
  const dir = await Deno.makeTempDir({ prefix: "kanban-route-test-" });
  await Deno.writeTextFile(`${dir}/boards.json`, JSON.stringify({ version: 1, boards: [] }));
  await Deno.mkdir(`${dir}/boards`);
  const boardRepo = new JsonFileBoardRepository(dir);
  const app = new Hono();
  app.route("/api", boardRoutes(boardRepo));
  return { app, dir };
}

Deno.test("GET /api/boards returns empty list", async () => {
  const { app } = await createTestApp();
  const res = await app.request("/api/boards");
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body, []);
});

Deno.test("POST /api/boards creates a board", async () => {
  const { app } = await createTestApp();
  const res = await app.request("/api/boards", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id: "test", name: "Test", path: "/tmp/test" }),
  });
  assertEquals(res.status, 201);
  const body = await res.json();
  assertEquals(body.id, "test");
});

Deno.test("POST /api/boards rejects invalid input", async () => {
  const { app } = await createTestApp();
  const res = await app.request("/api/boards", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name: "No ID" }),
  });
  assertEquals(res.status, 400);
});

Deno.test("DELETE /api/boards/:id removes board", async () => {
  const { app } = await createTestApp();
  await app.request("/api/boards", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id: "del", name: "Del", path: "/tmp" }),
  });
  const res = await app.request("/api/boards/del", { method: "DELETE" });
  assertEquals(res.status, 204);
});
```

**Step 2: Run tests to verify they fail**

Run: `deno test src/routes/boards_test.ts`
Expected: FAIL

**Step 3: Implement board routes**

`src/routes/boards.ts`:
```typescript
import { Hono } from "@hono/hono";
import type { BoardRepository } from "../repositories/board-repository.ts";

export function boardRoutes(boardRepo: BoardRepository): Hono {
  const app = new Hono();

  app.get("/boards", async (c) => {
    const boards = await boardRepo.listBoards();
    return c.json(boards);
  });

  app.post("/boards", async (c) => {
    const body = await c.req.json();
    if (!body.id || !body.name || !body.path) {
      return c.json({ error: "id, name, and path are required" }, 400);
    }
    try {
      const board = await boardRepo.createBoard(body);
      return c.json(board, 201);
    } catch (e) {
      return c.json({ error: (e as Error).message }, 409);
    }
  });

  app.delete("/boards/:id", async (c) => {
    const id = c.req.param("id");
    await boardRepo.deleteBoard(id);
    return c.body(null, 204);
  });

  return app;
}
```

**Step 4: Run tests to verify they pass**

Run: `deno test src/routes/boards_test.ts`
Expected: All PASS

**Step 5: Commit**

```bash
git add src/routes/
git commit -m "feat: add board API routes with tests"
```

---

### Task 6: API Server - Task Routes (TDD)

**Files:**
- Create: `~/.claude/tools/kanban-server/src/routes/tasks.ts`
- Create: `~/.claude/tools/kanban-server/src/routes/tasks_test.ts`

**Step 1: Write failing tests**

`src/routes/tasks_test.ts`:
```typescript
import { assertEquals } from "@std/assert";
import { Hono } from "@hono/hono";
import { taskRoutes } from "./tasks.ts";
import { JsonFileTaskRepository } from "../repositories/json-file-task-repository.ts";
import type { BoardData } from "../types.ts";

async function createTestApp() {
  const dir = await Deno.makeTempDir({ prefix: "kanban-task-route-test-" });
  await Deno.mkdir(`${dir}/boards`);
  const boardData: BoardData = {
    version: 1, boardId: "test-board",
    columns: ["backlog", "todo", "in_progress", "review", "done"],
    tasks: [],
  };
  await Deno.writeTextFile(`${dir}/boards/test-board.json`, JSON.stringify(boardData));
  const taskRepo = new JsonFileTaskRepository(dir);
  const app = new Hono();
  app.route("/api", taskRoutes(taskRepo));
  return { app, dir };
}

Deno.test("GET /api/boards/:id/tasks returns empty", async () => {
  const { app } = await createTestApp();
  const res = await app.request("/api/boards/test-board/tasks");
  assertEquals(res.status, 200);
  assertEquals(await res.json(), []);
});

Deno.test("POST /api/boards/:id/tasks creates task", async () => {
  const { app } = await createTestApp();
  const res = await app.request("/api/boards/test-board/tasks", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "New task" }),
  });
  assertEquals(res.status, 201);
  const task = await res.json();
  assertEquals(task.title, "New task");
  assertEquals(task.status, "backlog");
});

Deno.test("PATCH /api/boards/:id/tasks/:taskId updates task", async () => {
  const { app } = await createTestApp();
  const createRes = await app.request("/api/boards/test-board/tasks", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "Original" }),
  });
  const created = await createRes.json();

  const res = await app.request(`/api/boards/test-board/tasks/${created.id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "Updated", status: "in_progress" }),
  });
  assertEquals(res.status, 200);
  const updated = await res.json();
  assertEquals(updated.title, "Updated");
  assertEquals(updated.status, "in_progress");
});

Deno.test("PATCH with version conflict returns 409", async () => {
  const { app } = await createTestApp();
  const createRes = await app.request("/api/boards/test-board/tasks", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "Locked" }),
  });
  const created = await createRes.json();

  const res = await app.request(`/api/boards/test-board/tasks/${created.id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "Fail", expectedVersion: "1970-01-01T00:00:00.000Z" }),
  });
  assertEquals(res.status, 409);
});

Deno.test("DELETE /api/boards/:id/tasks/:taskId removes task", async () => {
  const { app } = await createTestApp();
  const createRes = await app.request("/api/boards/test-board/tasks", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "Delete me" }),
  });
  const created = await createRes.json();

  const res = await app.request(`/api/boards/test-board/tasks/${created.id}`, { method: "DELETE" });
  assertEquals(res.status, 204);
});

Deno.test("GET /api/boards/:id/tasks with status filter", async () => {
  const { app } = await createTestApp();
  await app.request("/api/boards/test-board/tasks", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "T1", status: "backlog" }),
  });
  await app.request("/api/boards/test-board/tasks", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "T2", status: "in_progress" }),
  });

  const res = await app.request("/api/boards/test-board/tasks?status=backlog");
  const tasks = await res.json();
  assertEquals(tasks.length, 1);
  assertEquals(tasks[0].title, "T1");
});
```

**Step 2: Run tests to verify they fail**

Run: `deno test src/routes/tasks_test.ts`
Expected: FAIL

**Step 3: Implement task routes**

`src/routes/tasks.ts`:
```typescript
import { Hono } from "@hono/hono";
import type { TaskRepository } from "../repositories/task-repository.ts";
import type { TaskFilter, TaskStatus, Priority } from "../types.ts";

export function taskRoutes(taskRepo: TaskRepository): Hono {
  const app = new Hono();

  app.get("/boards/:boardId/tasks", async (c) => {
    const boardId = c.req.param("boardId");
    const filter: TaskFilter = {};
    const status = c.req.query("status");
    const priority = c.req.query("priority");
    const label = c.req.query("label");
    if (status) filter.status = status as TaskStatus;
    if (priority) filter.priority = priority as Priority;
    if (label) filter.label = label;

    try {
      const tasks = await taskRepo.listTasks(boardId, filter);
      return c.json(tasks);
    } catch {
      return c.json({ error: "Board not found" }, 404);
    }
  });

  app.post("/boards/:boardId/tasks", async (c) => {
    const boardId = c.req.param("boardId");
    const body = await c.req.json();
    if (!body.title) {
      return c.json({ error: "title is required" }, 400);
    }
    try {
      const task = await taskRepo.createTask(boardId, body);
      return c.json(task, 201);
    } catch {
      return c.json({ error: "Board not found" }, 404);
    }
  });

  app.patch("/boards/:boardId/tasks/:taskId", async (c) => {
    const boardId = c.req.param("boardId");
    const taskId = c.req.param("taskId");
    const body = await c.req.json();
    try {
      const task = await taskRepo.updateTask(boardId, taskId, body);
      return c.json(task);
    } catch (e) {
      const msg = (e as Error).message;
      if (msg.includes("conflict")) return c.json({ error: msg }, 409);
      return c.json({ error: msg }, 404);
    }
  });

  app.delete("/boards/:boardId/tasks/:taskId", async (c) => {
    const boardId = c.req.param("boardId");
    const taskId = c.req.param("taskId");
    await taskRepo.deleteTask(boardId, taskId);
    return c.body(null, 204);
  });

  return app;
}
```

**Step 4: Run tests to verify they pass**

Run: `deno test src/routes/tasks_test.ts`
Expected: All PASS

**Step 5: Commit**

```bash
git add src/routes/
git commit -m "feat: add task API routes with tests"
```

---

### Task 7: Sync & Launch Routes (TDD)

**Files:**
- Create: `~/.claude/tools/kanban-server/src/services/sync-service.ts`
- Create: `~/.claude/tools/kanban-server/src/services/sync-service_test.ts`
- Create: `~/.claude/tools/kanban-server/src/routes/actions.ts`
- Create: `~/.claude/tools/kanban-server/src/routes/actions_test.ts`

**Step 1: Write failing tests for SyncService**

`src/services/sync-service_test.ts`:
```typescript
import { assertEquals } from "@std/assert";
import { SyncService } from "./sync-service.ts";
import { JsonFileTaskRepository } from "../repositories/json-file-task-repository.ts";
import type { BoardData } from "../types.ts";

async function setup() {
  const dir = await Deno.makeTempDir({ prefix: "kanban-sync-test-" });
  await Deno.mkdir(`${dir}/boards`);
  const boardData: BoardData = {
    version: 1, boardId: "test-board",
    columns: ["backlog", "todo", "in_progress", "review", "done"],
    tasks: [],
  };
  await Deno.writeTextFile(`${dir}/boards/test-board.json`, JSON.stringify(boardData));
  const taskRepo = new JsonFileTaskRepository(dir);
  const syncService = new SyncService(taskRepo);
  return { syncService, taskRepo, dir };
}

// project-state.json format (from handover skill)
const sampleProjectState = {
  version: 3,
  generated_at: "2026-03-13T10:00:00Z",
  session_id: "session-abc",
  status: "READY",
  workspace: { root: "/tmp/test", branch: "feature/auth", is_worktree: false },
  active_tasks: [
    {
      id: "T1",
      description: "認証APIの実装",
      status: "done",
      commit_sha: "abc123",
      file_paths: ["src/auth.ts"],
      last_touched: "2026-03-13T09:00:00Z",
    },
    {
      id: "T2",
      description: "テスト追加",
      status: "in_progress",
      file_paths: ["tests/auth_test.ts"],
      next_action: "エッジケースのテストを書く",
      last_touched: "2026-03-13T10:00:00Z",
    },
    {
      id: "T3",
      description: "ドキュメント更新",
      status: "blocked",
      file_paths: ["docs/auth.md"],
      next_action: "API仕様確定を待つ",
      blockers: ["API仕様が未確定"],
      last_touched: "2026-03-13T08:00:00Z",
    },
  ],
};

Deno.test("syncFromProjectState creates tasks from project-state.json", async () => {
  const { syncService, taskRepo } = await setup();
  const result = await syncService.syncFromProjectState("test-board", sampleProjectState);
  assertEquals(result.created, 3);
  assertEquals(result.updated, 0);

  const tasks = await taskRepo.listTasks("test-board");
  assertEquals(tasks.length, 3);

  // done task should be in "done" column
  const doneTask = tasks.find((t) => t.title === "認証APIの実装");
  assertEquals(doneTask?.status, "done");

  // in_progress should stay in_progress
  const ipTask = tasks.find((t) => t.title === "テスト追加");
  assertEquals(ipTask?.status, "in_progress");

  // blocked → review (closest mapping)
  const blockedTask = tasks.find((t) => t.title === "ドキュメント更新");
  assertEquals(blockedTask?.status, "review");

  // session context should be populated
  assertEquals(ipTask?.sessionContext?.lastSessionId, "session-abc");
});

Deno.test("syncFromProjectState merges with existing tasks", async () => {
  const { syncService, taskRepo } = await setup();
  // First sync
  await syncService.syncFromProjectState("test-board", sampleProjectState);
  // Second sync with updated data
  const updated = {
    ...sampleProjectState,
    active_tasks: [
      { ...sampleProjectState.active_tasks[1], status: "done", commit_sha: "def456" },
    ],
  };
  const result = await syncService.syncFromProjectState("test-board", updated);
  assertEquals(result.updated, 1);

  const tasks = await taskRepo.listTasks("test-board");
  const mergedTask = tasks.find((t) => t.title === "テスト追加");
  assertEquals(mergedTask?.status, "done");
});
```

**Step 2: Run tests to verify they fail**

Run: `deno test src/services/sync-service_test.ts`
Expected: FAIL

**Step 3: Implement SyncService**

`src/services/sync-service.ts`:
```typescript
import type { TaskRepository } from "../repositories/task-repository.ts";
import type { CreateTaskInput, TaskStatus } from "../types.ts";

interface ProjectStateTask {
  id: string;
  description: string;
  status: "done" | "in_progress" | "blocked";
  commit_sha?: string;
  file_paths?: string[];
  next_action?: string;
  blockers?: string[];
  last_touched?: string;
}

interface ProjectState {
  session_id?: string;
  workspace?: { root?: string; branch?: string };
  active_tasks: ProjectStateTask[];
}

interface SyncResult {
  created: number;
  updated: number;
  errors: string[];
}

function mapStatus(handoverStatus: string): TaskStatus {
  switch (handoverStatus) {
    case "done": return "done";
    case "in_progress": return "in_progress";
    case "blocked": return "review";
    default: return "backlog";
  }
}

export class SyncService {
  constructor(private readonly taskRepo: TaskRepository) {}

  async syncFromProjectState(boardId: string, state: ProjectState): Promise<SyncResult> {
    const existing = await this.taskRepo.listTasks(boardId);
    const result: SyncResult = { created: 0, updated: 0, errors: [] };

    for (const stateTask of state.active_tasks) {
      const match = existing.find((t) => t.title === stateTask.description);
      const status = mapStatus(stateTask.status);

      const sessionContext = {
        lastSessionId: state.session_id,
        handoverFile: state.workspace?.root
          ? `${state.workspace.root}/.claude/handover/${state.workspace.branch}/`
          : undefined,
        resumeHint: state.session_id ? `--resume ${state.session_id}` : undefined,
      };

      if (match) {
        await this.taskRepo.updateTask(boardId, match.id, {
          status,
          description: stateTask.next_action ?? match.description,
          worktree: state.workspace?.branch,
          sessionContext,
        });
        result.updated++;
      } else {
        const input: CreateTaskInput = {
          title: stateTask.description,
          description: stateTask.next_action ?? "",
          status,
          priority: stateTask.status === "blocked" ? "high" : "medium",
          labels: [],
          worktree: state.workspace?.branch,
          sessionContext,
        };
        await this.taskRepo.createTask(boardId, input);
        result.created++;
      }
    }

    return result;
  }
}
```

**Step 4: Run tests to verify they pass**

Run: `deno test src/services/sync-service_test.ts`
Expected: All PASS

**Step 5: Write actions routes (sync + launch)**

`src/routes/actions.ts`:
```typescript
import { Hono } from "@hono/hono";
import type { TaskRepository } from "../repositories/task-repository.ts";
import type { BoardRepository } from "../repositories/board-repository.ts";
import { SyncService } from "../services/sync-service.ts";

export function actionRoutes(boardRepo: BoardRepository, taskRepo: TaskRepository): Hono {
  const app = new Hono();
  const syncService = new SyncService(taskRepo);

  // Sync from project-state.json
  app.post("/boards/:boardId/sync", async (c) => {
    const boardId = c.req.param("boardId");
    const body = await c.req.json();

    if (!body.projectState) {
      return c.json({ error: "projectState is required" }, 400);
    }

    const result = await syncService.syncFromProjectState(boardId, body.projectState);
    return c.json(result);
  });

  // Launch Claude Code via WezTerm
  app.post("/launch", async (c) => {
    const body = await c.req.json();
    const { projectPath, sessionId, handoverFile } = body;

    if (!projectPath) {
      return c.json({ error: "projectPath is required" }, 400);
    }

    const args = ["wezterm", "cli", "spawn", "--cwd", projectPath, "--"];
    if (sessionId) {
      args.push("claude", "--resume", sessionId);
    } else if (handoverFile) {
      args.push("claude", "--prompt", `Continue from handover: $(cat ${handoverFile})`);
    } else {
      args.push("claude");
    }

    try {
      const cmd = new Deno.Command(args[0], { args: args.slice(1) });
      const output = await cmd.output();
      if (!output.success) {
        const stderr = new TextDecoder().decode(output.stderr);
        return c.json({ error: `WezTerm launch failed: ${stderr}` }, 500);
      }
      return c.json({ status: "launched", command: args.join(" ") });
    } catch (e) {
      return c.json({ error: (e as Error).message }, 500);
    }
  });

  // Cross-project overview
  app.get("/overview", async (c) => {
    const boards = await boardRepo.listBoards();
    const overview = await Promise.all(
      boards.map(async (board) => {
        try {
          const tasks = await taskRepo.listTasks(board.id);
          const counts: Record<string, number> = {};
          for (const task of tasks) {
            counts[task.status] = (counts[task.status] ?? 0) + 1;
          }
          return { ...board, taskCounts: counts, totalTasks: tasks.length };
        } catch {
          return { ...board, taskCounts: {}, totalTasks: 0 };
        }
      }),
    );
    return c.json(overview);
  });

  return app;
}
```

**Step 6: Commit**

```bash
git add src/services/ src/routes/actions.ts
git commit -m "feat: add sync service and action routes (sync, launch, overview)"
```

---

### Task 8: Wire Up Server & Static File Serving

**Files:**
- Modify: `~/.claude/tools/kanban-server/server.ts`
- Create: `~/.claude/tools/kanban-server/public/index.html` (minimal placeholder)

**Step 1: Update server.ts to wire all routes**

```typescript
import { Hono } from "@hono/hono";
import { serveStatic } from "@hono/hono/deno";
import { cors } from "@hono/hono/cors";
import { boardRoutes } from "./src/routes/boards.ts";
import { taskRoutes } from "./src/routes/tasks.ts";
import { actionRoutes } from "./src/routes/actions.ts";
import { JsonFileBoardRepository } from "./src/repositories/json-file-board-repository.ts";
import { JsonFileTaskRepository } from "./src/repositories/json-file-task-repository.ts";

const DATA_DIR = Deno.env.get("KANBAN_DATA_DIR") ??
  `${Deno.env.get("HOME")}/.claude/kanban`;

// Ensure data directory exists
await Deno.mkdir(`${DATA_DIR}/boards`, { recursive: true });
try {
  await Deno.stat(`${DATA_DIR}/boards.json`);
} catch {
  await Deno.writeTextFile(`${DATA_DIR}/boards.json`, JSON.stringify({ version: 1, boards: [] }, null, 2));
}

const boardRepo = new JsonFileBoardRepository(DATA_DIR);
const taskRepo = new JsonFileTaskRepository(DATA_DIR);

const app = new Hono();

app.use("*", cors());
app.get("/api/health", (c) => c.json({ status: "ok" }));
app.route("/api", boardRoutes(boardRepo));
app.route("/api", taskRoutes(taskRepo));
app.route("/api", actionRoutes(boardRepo, taskRepo));
app.use("/*", serveStatic({ root: "./public" }));

const port = parseInt(Deno.env.get("KANBAN_PORT") ?? "3456");
console.log(`Kanban server running on http://localhost:${port}`);
Deno.serve({ port }, app.fetch);
```

Note: `serveStatic` の import パスは context7 で最新を確認すること。Hono の Deno adapter のパスが変わっている可能性あり。

**Step 2: Create placeholder index.html**

`public/index.html`:
```html
<!DOCTYPE html>
<html><head><title>Kanban</title></head>
<body><h1>Kanban Board</h1><p>Loading...</p></body>
</html>
```

**Step 3: Run all tests**

Run: `deno test --allow-read --allow-write`
Expected: All tests PASS

**Step 4: Verify server starts**

Run: `deno task dev`
Verify: `curl http://localhost:3456/api/health` → `{"status":"ok"}`
Verify: `curl http://localhost:3456/` → HTML response

**Step 5: Commit**

```bash
git add server.ts public/
git commit -m "feat: wire up all routes and static file serving"
```

---

### Task 9: Web UI - Kanban Board View

**Files:**
- Modify: `~/.claude/tools/kanban-server/public/index.html`

全て単一 HTML ファイルで実装。CDN から Preact + HTM + Tailwind CSS + SortableJS を読み込む。ビルドステップなし。

**Step 1: Create full kanban board UI**

`public/index.html` — 以下の要素を含む単一 HTML ファイル:

- **CDN imports**: Preact, HTM, Tailwind CSS (Play CDN), SortableJS
- **コンポーネント構成**:
  - `App` — ルートコンポーネント。ボード一覧 or ボードビュー or 横断ビューをルーティング
  - `BoardSelector` — ヘッダーのPJセレクター
  - `KanbanBoard` — 5カラムレイアウト。SortableJS でドラッグ&ドロップ
  - `TaskCard` — タスクカード。priority バッジ、labels、ワークツリー名
  - `TaskDetail` — サイドドロワー。タスク編集、「Claude Code で開く」ボタン
  - `Overview` — PJ横断ビュー。全ボードのサマリーカード
  - `CreateTaskModal` — タスク追加モーダル
- **API通信**: `fetch` で REST API を呼び出し
- **ドラッグ&ドロップ**: SortableJS の `onEnd` で PATCH API を呼んでステータス変更

主要な実装ポイント:
- Preact + HTM のタグ付きテンプレートリテラルで JSX-like に記述
- ステートは `useState` / `useEffect` で管理
- カラム間ドラッグ時: `Sortable.create` で各カラムに設定、`group: "tasks"` で共有
- priority の色: high=赤, medium=黄, low=緑 のバッジ
- labels は小さなチップで表示
- 「Claude Code で開く」ボタン: POST `/api/launch` を呼び出し

**実装の詳細コードは長大になるため、以下の方針で実装する**:
1. まず App + BoardSelector + KanbanBoard の基本レイアウトを作成
2. TaskCard のレンダリングを実装
3. SortableJS によるドラッグ&ドロップを組み込み
4. TaskDetail サイドドロワーを追加
5. CreateTaskModal を追加
6. Overview ページを追加

各サブステップで動作確認しながら進める。

**Step 2: Verify UI renders with mock data**

Run: `deno task dev`
Open: `http://localhost:3456`
Expected: kanban ボードが表示される

**Step 3: Create a test board via API and verify UI**

```bash
curl -X POST http://localhost:3456/api/boards \
  -H 'Content-Type: application/json' \
  -d '{"id":"test","name":"Test Project","path":"/tmp/test"}'

curl -X POST http://localhost:3456/api/boards/test/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"Sample task","status":"in_progress","priority":"high"}'
```

Open: `http://localhost:3456` and select "Test Project"
Expected: タスクカードが In Progress カラムに表示される

**Step 4: Verify drag-and-drop works**

Drag a task card from one column to another.
Expected: PATCH API が呼ばれ、タスクのステータスが更新される

**Step 5: Commit**

```bash
git add public/
git commit -m "feat: implement kanban board Web UI with drag-and-drop"
```

---

### Task 10: Web UI - Task Detail & Claude Launch

**Files:**
- Modify: `~/.claude/tools/kanban-server/public/index.html`

**Step 1: Implement TaskDetail side drawer**

追加する UI 要素:
- タスクカードクリックで右側からスライドインするドロワー
- タイトル・説明の inline 編集
- ステータスのドロップダウン切り替え
- priority セレクター
- labels のタグ入力（入力 + Enter で追加、× で削除）
- ワークツリー名の表示
- 「Claude Code で開く」ボタン（sessionContext があれば resume、なければ新規起動）
- セッション情報の表示（lastSessionId, handoverFile）

**Step 2: Implement launch button**

ボタン押下時:
```javascript
async function launchClaude(task) {
  const board = currentBoard;
  const body = {
    projectPath: board.path,
    sessionId: task.sessionContext?.lastSessionId,
    handoverFile: task.sessionContext?.handoverFile,
  };
  const res = await fetch('/api/launch', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const result = await res.json();
  if (res.ok) {
    alert('Claude Code launched in WezTerm');
  } else {
    alert('Launch failed: ' + result.error);
  }
}
```

Note: ブラウザの alert は一時的な実装。後で toast 通知に変更可能。

**Step 3: Verify task detail works**

Open board → click task card → edit title → save
Expected: PATCH API called, task updated

Click "Claude Code で開く"
Expected: WezTerm で新しいタブが開く（WezTerm が起動している場合）

**Step 4: Commit**

```bash
git add public/
git commit -m "feat: add task detail drawer and Claude Code launch button"
```

---

### Task 11: Web UI - Cross-Project Overview

**Files:**
- Modify: `~/.claude/tools/kanban-server/public/index.html`

**Step 1: Implement Overview component**

- GET `/api/overview` を呼び出してデータ取得
- 各ボードをカードで表示:
  - PJ名
  - パス
  - In Progress / Review のタスク数（バッジ）
  - 全タスク数
  - カードクリックでそのボードに遷移
- グリッドレイアウト（2-3列）

**Step 2: Add navigation**

- ヘッダーに「Overview」リンクを追加
- ボードビュー ↔ Overview の切り替え

**Step 3: Verify**

複数ボードを作成し、Overview ページで全ボードのサマリーが表示されることを確認。

**Step 4: Commit**

```bash
git add public/
git commit -m "feat: add cross-project overview page"
```

---

### Task 12: Claude Code Skill (/kanban)

**Files:**
- Create: `~/.dotfiles/claude/skills/kanban/SKILL.md`

**Step 1: Write the skill definition**

`~/.dotfiles/claude/skills/kanban/SKILL.md`:
```markdown
---
name: kanban
description: ローカル kanban ボードのタスク管理。タスクの追加・移動・表示・handover同期・サーバー起動を行う。
user-invocable: true
---

ローカル kanban ボードを操作する。データは `~/.claude/kanban/` に JSON で保存される。

## コマンド

引数に応じて以下の操作を実行する:

### `/kanban`（引数なし）
1. `~/.claude/kanban/boards.json` を読み込む
2. ボード一覧を表示する
3. 現在の `pwd` に対応するボードがあれば、そのサマリー（カラムごとのタスク数）を表示する

### `/kanban add <title>`
1. 現在の `pwd` から対応するボードを `boards.json` の `path` で検索する
2. 見つからない場合: AskUserQuestion でボード新規作成を提案する（id, name を確認）
3. `~/.claude/kanban/boards/<board-id>.json` にタスクを追加する:
   - status: `backlog`
   - priority: `medium`
   - id: `t-YYYYMMDD-NNN`（NNN はランダム3桁）
   - worktree: 現在のブランチ名（`git rev-parse --abbrev-ref HEAD`）

### `/kanban move <task-id> <status>`
1. status は `backlog`, `todo`, `in_progress`, `review`, `done` のいずれか
2. 対応するボードの JSON ファイルを更新する
3. 更新後のタスク情報を表示する

### `/kanban show`
1. 現在の `pwd` に対応するボードのタスクを読み込む
2. カラムごとにグループ化してテーブル形式で表示する:

```
┌─────────┬────────┬─────────────┬────────┬──────┐
│ Backlog │ Todo   │ In Progress │ Review │ Done │
├─────────┼────────┼─────────────┼────────┼──────┤
│ [t-001] │        │ [t-002]     │        │      │
│ タスク1 │        │ タスク2     │        │      │
│ 🔴 high │        │ 🟡 med      │        │      │
└─────────┴────────┴─────────────┴────────┴──────┘
```

### `/kanban sync`
1. 現在の `pwd` から `.claude/handover/` 配下の最新 `project-state.json` を探す
   - ブランチ名でディレクトリを特定
   - 最新の fingerprint ディレクトリを選択
2. project-state.json の `active_tasks` を読み込む
3. 既存タスクとのマッチング（タイトル = description で照合）:
   - マッチ: `updatedAt` が新しい方を採用
   - 未マッチ: 新規タスクとして追加
4. セッション情報を `sessionContext` に記録
5. 同期結果（created / updated 件数）を表示

### `/kanban serve`
1. `~/.claude/tools/kanban-server/` でサーバーを起動する:
   ```bash
   cd ~/.claude/tools/kanban-server && deno task start &
   ```
2. `http://localhost:3456` をブラウザで開く:
   ```bash
   open http://localhost:3456
   ```

## プロジェクト自動検出

- `pwd` と `boards.json` の各ボードの `path` をマッチングする
- `pwd` がボードの `path` の子ディレクトリでもマッチする
- ワークツリーの場合: `git worktree list --porcelain` で main worktree のパスも確認する

## データパス

- ボード一覧: `~/.claude/kanban/boards.json`
- ボードデータ: `~/.claude/kanban/boards/<board-id>.json`
- サーバーコード: `~/.claude/tools/kanban-server/`
```

**Step 2: Verify skill loads**

Claude Code で `/kanban` を実行し、スキルが読み込まれることを確認する。

**Step 3: Commit (in dotfiles repo)**

```bash
cd ~/.dotfiles
git add claude/skills/kanban/
git commit -m "feat: add /kanban Claude Code skill"
```

---

### Task 13: Integration Smoke Test

**Files:** (no new files)

**Step 1: Start the server**

```bash
cd ~/.claude/tools/kanban-server && deno task start
```

**Step 2: Create a board and tasks via API**

```bash
# Create board
curl -X POST http://localhost:3456/api/boards \
  -H 'Content-Type: application/json' \
  -d '{"id":"dotfiles","name":"Dotfiles","path":"'"$HOME"'/.dotfiles"}'

# Create tasks
curl -X POST http://localhost:3456/api/boards/dotfiles/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"Kanban スキル実装","status":"in_progress","priority":"high","labels":["feature"]}'

curl -X POST http://localhost:3456/api/boards/dotfiles/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"テスト追加","status":"backlog","priority":"medium"}'
```

**Step 3: Verify Web UI**

Open `http://localhost:3456`
Expected:
- Overview に "Dotfiles" ボードが表示される
- ボードを選択すると kanban ビューに遷移
- タスクカードが正しいカラムに表示される
- ドラッグ&ドロップで移動できる
- タスククリックで詳細ドロワーが開く

**Step 4: Verify Claude Code skill**

```
/kanban show
```
Expected: ターミナルにボードが表示される

```
/kanban add "README更新"
```
Expected: タスクが Backlog に追加される

**Step 5: Run all tests**

```bash
cd ~/.claude/tools/kanban-server && deno test --allow-read --allow-write
```
Expected: All PASS

**Step 6: Final commit**

```bash
cd ~/.claude/tools/kanban-server
git add .
git commit -m "chore: integration smoke test verified"
```
