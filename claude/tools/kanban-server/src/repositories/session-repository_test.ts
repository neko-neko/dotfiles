import { assertEquals, assertRejects } from "@std/assert";
import { SessionRepository } from "./session-repository.ts";

const OWNER = "macbook-main";

async function setup(): Promise<{ repo: SessionRepository; dir: string }> {
  const dir = await Deno.makeTempDir({ prefix: "kanban-session-test-" });
  return { repo: new SessionRepository(dir), dir };
}

async function cleanup(dir: string): Promise<void> {
  await Deno.remove(dir, { recursive: true });
}

Deno.test("create generates session with UUID and status starting", async () => {
  const { repo, dir } = await setup();
  try {
    const session = await repo.create({
      taskId: "task-1",
      boardId: "board-1",
      host: OWNER,
      ownerNode: OWNER,
    });
    assertEquals(session.status, "starting");
    assertEquals(session.taskId, "task-1");
    assertEquals(session.boardId, "board-1");
    assertEquals(session.host, OWNER);
    assertEquals(session.ownerNode, OWNER);
    const uuidPattern =
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
    assertEquals(uuidPattern.test(session.id), true);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("get returns session by id", async () => {
  const { repo, dir } = await setup();
  try {
    const created = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    const found = await repo.get(created.id);
    assertEquals(found?.id, created.id);
    assertEquals(found?.taskId, "t1");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("get returns null for missing session", async () => {
  const { repo, dir } = await setup();
  try {
    const found = await repo.get("nonexistent");
    assertEquals(found, null);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("list returns all sessions", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    await repo.create({
      taskId: "t2",
      boardId: "b1",
      host: "mac-mini",
      ownerNode: "mac-mini",
    });
    const sessions = await repo.list();
    assertEquals(sessions.length, 2);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("list with host filter", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    await repo.create({
      taskId: "t2",
      boardId: "b1",
      host: "mac-mini",
      ownerNode: "mac-mini",
    });
    const filtered = await repo.list({ host: "mac-mini" });
    assertEquals(filtered.length, 1);
    assertEquals(filtered[0].host, "mac-mini");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("list with status filter", async () => {
  const { repo, dir } = await setup();
  try {
    const s1 = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    await repo.create({
      taskId: "t2",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    // Move s1 to in-progress
    await repo.update(s1.id, { status: "in-progress" }, OWNER);

    const starting = await repo.list({ status: "starting" });
    assertEquals(starting.length, 1);

    const inProgress = await repo.list({ status: "in-progress" });
    assertEquals(inProgress.length, 1);
    assertEquals(inProgress[0].id, s1.id);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("listByTask filters by taskId", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    await repo.create({
      taskId: "t2",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });

    const t1Sessions = await repo.listByTask("t1");
    assertEquals(t1Sessions.length, 2);
    for (const s of t1Sessions) {
      assertEquals(s.taskId, "t1");
    }
  } finally {
    await cleanup(dir);
  }
});

Deno.test("update status starting → in-progress", async () => {
  const { repo, dir } = await setup();
  try {
    const session = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    const updated = await repo.update(
      session.id,
      { status: "in-progress" },
      OWNER,
    );
    assertEquals(updated.status, "in-progress");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("update rejects invalid transition done → in-progress", async () => {
  const { repo, dir } = await setup();
  try {
    const session = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    await repo.update(session.id, { status: "in-progress" }, OWNER);
    await repo.update(session.id, { status: "done" }, OWNER);

    await assertRejects(
      () => repo.update(session.id, { status: "in-progress" }, OWNER),
      Error,
      "Invalid transition",
    );
  } finally {
    await cleanup(dir);
  }
});

Deno.test("update rejects non-owner", async () => {
  const { repo, dir } = await setup();
  try {
    const session = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    await assertRejects(
      () => repo.update(session.id, { status: "in-progress" }, "other-node"),
      Error,
      "ownerNode",
    );
  } finally {
    await cleanup(dir);
  }
});

Deno.test("create with optional fields", async () => {
  const { repo, dir } = await setup();
  try {
    const session = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
      worktree: "/tmp/wt",
      branch: "feature/x",
      launchCommand: "zellij action new-tab -- claude",
    });
    assertEquals(session.worktree, "/tmp/wt");
    assertEquals(session.branch, "feature/x");
    assertEquals(session.launchCommand, "zellij action new-tab -- claude");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("update sets claudeSessionId and handoverPath", async () => {
  const { repo, dir } = await setup();
  try {
    const session = await repo.create({
      taskId: "t1",
      boardId: "b1",
      host: OWNER,
      ownerNode: OWNER,
    });
    const updated = await repo.update(
      session.id,
      {
        status: "in-progress",
        claudeSessionId: "abc-123",
        handoverPath: "/tmp/handover.md",
      },
      OWNER,
    );
    assertEquals(updated.claudeSessionId, "abc-123");
    assertEquals(updated.handoverPath, "/tmp/handover.md");
    assertEquals(updated.status, "in-progress");
  } finally {
    await cleanup(dir);
  }
});
