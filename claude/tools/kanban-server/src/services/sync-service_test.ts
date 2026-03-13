import { assertEquals } from "@std/assert";
import { SyncService } from "./sync-service.ts";
import { JsonFileTaskRepository } from "../repositories/json-file-task-repository.ts";
import type { BoardData } from "../types.ts";

const BOARD_ID = "sync-test-board";

interface ProjectState {
  version: number;
  session_id: string;
  status: string;
  workspace: {
    root: string;
    branch: string;
    is_worktree: boolean;
  };
  active_tasks: Array<{
    id: string;
    description: string;
    status: string;
    commit_sha?: string;
    file_paths?: string[];
    next_action?: string;
    blockers?: string[];
    last_touched?: string;
  }>;
}

async function setup(): Promise<{
  taskRepo: JsonFileTaskRepository;
  dir: string;
}> {
  const dir = await Deno.makeTempDir({ prefix: "kanban-sync-test-" });
  await Deno.mkdir(`${dir}/boards`);
  const boardData: BoardData = {
    version: 1,
    boardId: BOARD_ID,
    columns: ["backlog", "todo", "in_progress", "review", "done"],
    tasks: [],
  };
  await Deno.writeTextFile(
    `${dir}/boards/${BOARD_ID}.json`,
    JSON.stringify(boardData),
  );
  return { taskRepo: new JsonFileTaskRepository(dir), dir };
}

async function cleanup(dir: string): Promise<void> {
  await Deno.remove(dir, { recursive: true });
}

function makeProjectState(overrides?: Partial<ProjectState>): ProjectState {
  return {
    version: 3,
    session_id: "session-abc",
    status: "READY",
    workspace: {
      root: "/tmp/test",
      branch: "feature/auth",
      is_worktree: false,
    },
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
    ...overrides,
  };
}

Deno.test("syncFromProjectState creates tasks from project-state.json", async () => {
  const { taskRepo, dir } = await setup();
  try {
    const service = new SyncService(taskRepo);
    const projectState = makeProjectState();

    const result = await service.syncFromProjectState(
      BOARD_ID,
      projectState,
      "/tmp/handover/project-state.json",
    );

    assertEquals(result.created, 3);
    assertEquals(result.updated, 0);
    assertEquals(result.errors.length, 0);

    const tasks = await taskRepo.listTasks(BOARD_ID);
    assertEquals(tasks.length, 3);

    // Verify status mapping: done -> done, in_progress -> in_progress, blocked -> review
    const doneTask = tasks.find((t) => t.title === "認証APIの実装");
    assertEquals(doneTask?.status, "done");

    const inProgressTask = tasks.find((t) => t.title === "テスト追加");
    assertEquals(inProgressTask?.status, "in_progress");

    const blockedTask = tasks.find((t) => t.title === "ドキュメント更新");
    assertEquals(blockedTask?.status, "review");

    // Verify sessionContext is populated
    assertEquals(doneTask?.sessionContext?.lastSessionId, "session-abc");
    assertEquals(
      doneTask?.sessionContext?.handoverFile,
      "/tmp/handover/project-state.json",
    );

    // in_progress task should have resumeHint from next_action
    assertEquals(
      inProgressTask?.sessionContext?.resumeHint,
      "エッジケースのテストを書く",
    );

    // blocked task should have resumeHint from next_action
    assertEquals(
      blockedTask?.sessionContext?.resumeHint,
      "API仕様確定を待つ",
    );

    // Verify worktree is set from workspace.root
    assertEquals(doneTask?.worktree, "/tmp/test");
    assertEquals(inProgressTask?.worktree, "/tmp/test");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("syncFromProjectState merges with existing tasks (no duplicates)", async () => {
  const { taskRepo, dir } = await setup();
  try {
    const service = new SyncService(taskRepo);
    const projectState = makeProjectState();

    // First sync
    const result1 = await service.syncFromProjectState(
      BOARD_ID,
      projectState,
      "/tmp/handover/project-state.json",
    );
    assertEquals(result1.created, 3);
    assertEquals(result1.updated, 0);

    // Second sync with updated data
    const updatedState = makeProjectState({
      session_id: "session-def",
      active_tasks: [
        {
          id: "T1",
          description: "認証APIの実装",
          status: "done",
          commit_sha: "def456",
          file_paths: ["src/auth.ts"],
          last_touched: "2026-03-13T11:00:00Z",
        },
        {
          id: "T2",
          description: "テスト追加",
          status: "done",
          file_paths: ["tests/auth_test.ts"],
          last_touched: "2026-03-13T12:00:00Z",
        },
        {
          id: "T3",
          description: "ドキュメント更新",
          status: "in_progress",
          file_paths: ["docs/auth.md"],
          next_action: "ドキュメントを書く",
          last_touched: "2026-03-13T13:00:00Z",
        },
      ],
    });

    const result2 = await service.syncFromProjectState(
      BOARD_ID,
      updatedState,
      "/tmp/handover/project-state.json",
    );
    assertEquals(result2.created, 0);
    assertEquals(result2.updated, 3);
    assertEquals(result2.errors.length, 0);

    // Verify no duplicates
    const tasks = await taskRepo.listTasks(BOARD_ID);
    assertEquals(tasks.length, 3);

    // Verify updated statuses
    const t2 = tasks.find((t) => t.title === "テスト追加");
    assertEquals(t2?.status, "done");

    const t3 = tasks.find((t) => t.title === "ドキュメント更新");
    assertEquals(t3?.status, "in_progress");

    // Verify sessionContext updated with new session id
    assertEquals(t2?.sessionContext?.lastSessionId, "session-def");
    assertEquals(t3?.sessionContext?.resumeHint, "ドキュメントを書く");
  } finally {
    await cleanup(dir);
  }
});
