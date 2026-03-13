import { assertEquals } from "@std/assert";
import { Hono } from "@hono/hono";
import { actionRoutes } from "./actions.ts";
import { JsonFileBoardRepository } from "../repositories/json-file-board-repository.ts";
import { JsonFileTaskRepository } from "../repositories/json-file-task-repository.ts";
import type { BoardsIndex } from "../types.ts";

async function setup(): Promise<{
  app: Hono;
  dataDir: string;
  handoverRoot: string;
}> {
  const dataDir = await Deno.makeTempDir({ prefix: "kanban-handover-test-" });
  const index: BoardsIndex = { version: 1, boards: [] };
  await Deno.writeTextFile(`${dataDir}/boards.json`, JSON.stringify(index));
  await Deno.mkdir(`${dataDir}/boards`);

  const boardRepo = new JsonFileBoardRepository(dataDir);
  const taskRepo = new JsonFileTaskRepository(dataDir);
  const routes = actionRoutes(boardRepo, taskRepo);

  const app = new Hono();
  app.route("/api", routes);

  // Create a separate root for handover files
  const handoverRoot = await Deno.makeTempDir({
    prefix: "kanban-handover-root-",
  });

  return { app, dataDir, handoverRoot };
}

async function cleanup(...dirs: string[]): Promise<void> {
  for (const dir of dirs) {
    await Deno.remove(dir, { recursive: true });
  }
}

// --- Sessions endpoint tests ---

Deno.test(
  "GET /handover/sessions returns empty for nonexistent directory",
  async () => {
    const { app, dataDir, handoverRoot } = await setup();
    try {
      const res = await app.request(
        `/api/handover/sessions?root=${handoverRoot}&branch=nonexistent`,
      );
      assertEquals(res.status, 200);
      const body = await res.json();
      assertEquals(body, []);
    } finally {
      await cleanup(dataDir, handoverRoot);
    }
  },
);

Deno.test(
  "GET /handover/sessions returns 400 when root is missing",
  async () => {
    const { app, dataDir, handoverRoot } = await setup();
    try {
      const res = await app.request(`/api/handover/sessions?branch=main`);
      assertEquals(res.status, 400);
    } finally {
      await cleanup(dataDir, handoverRoot);
    }
  },
);

Deno.test(
  "GET /handover/sessions returns 400 when branch is missing",
  async () => {
    const { app, dataDir, handoverRoot } = await setup();
    try {
      const res = await app.request(
        `/api/handover/sessions?root=${handoverRoot}`,
      );
      assertEquals(res.status, 400);
    } finally {
      await cleanup(dataDir, handoverRoot);
    }
  },
);

Deno.test(
  "GET /handover/sessions returns sessions sorted newest first",
  async () => {
    const { app, dataDir, handoverRoot } = await setup();
    try {
      // Create handover directory structure
      const branchDir = `${handoverRoot}/.claude/handover/main`;
      await Deno.mkdir(branchDir, { recursive: true });

      // Create two fingerprint directories
      const fp1 = "20260313-100000";
      const fp2 = "20260313-150000";

      await Deno.mkdir(`${branchDir}/${fp1}`);
      await Deno.mkdir(`${branchDir}/${fp2}`);

      // Write project-state.json for both
      await Deno.writeTextFile(
        `${branchDir}/${fp1}/project-state.json`,
        JSON.stringify({
          status: "ALL_COMPLETE",
          generated_at: "2026-03-13T10:00:00Z",
          active_tasks: [
            { status: "done" },
            { status: "done" },
            { status: "done" },
          ],
        }),
      );

      await Deno.writeTextFile(
        `${branchDir}/${fp2}/project-state.json`,
        JSON.stringify({
          status: "READY",
          generated_at: "2026-03-13T15:00:00Z",
          active_tasks: [
            { status: "done" },
            { status: "done" },
            { status: "in_progress" },
          ],
        }),
      );

      // Write handover.md for fp2 only
      await Deno.writeTextFile(
        `${branchDir}/${fp2}/handover.md`,
        "# Session Handover\n",
      );

      const res = await app.request(
        `/api/handover/sessions?root=${handoverRoot}&branch=main`,
      );
      assertEquals(res.status, 200);
      const body = await res.json();

      assertEquals(body.length, 2);
      // Newest first
      assertEquals(body[0].fingerprint, fp2);
      assertEquals(body[1].fingerprint, fp1);

      // Check fp2 details
      assertEquals(body[0].hasHandover, true);
      assertEquals(body[0].hasProjectState, true);
      assertEquals(body[0].status, "READY");
      assertEquals(body[0].generatedAt, "2026-03-13T15:00:00Z");
      assertEquals(body[0].taskSummary, {
        done: 2,
        in_progress: 1,
        blocked: 0,
      });

      // Check fp1 details
      assertEquals(body[1].hasHandover, false);
      assertEquals(body[1].hasProjectState, true);
      assertEquals(body[1].status, "ALL_COMPLETE");
      assertEquals(body[1].taskSummary, {
        done: 3,
        in_progress: 0,
        blocked: 0,
      });
    } finally {
      await cleanup(dataDir, handoverRoot);
    }
  },
);

// --- Content endpoint tests ---

Deno.test(
  "GET /handover/content reads handover.md and project-state.json",
  async () => {
    const { app, dataDir, handoverRoot } = await setup();
    try {
      const dir = `${handoverRoot}/.claude/handover/main/20260313-150000`;
      await Deno.mkdir(dir, { recursive: true });

      await Deno.writeTextFile(
        `${dir}/handover.md`,
        "# Session Handover\n\n## Completed\n- Task 1\n",
      );
      await Deno.writeTextFile(
        `${dir}/project-state.json`,
        JSON.stringify({ status: "READY", active_tasks: [] }),
      );

      const res = await app.request(
        `/api/handover/content?dir=${encodeURIComponent(dir)}`,
      );
      assertEquals(res.status, 200);
      const body = await res.json();

      assertEquals(
        body.handover,
        "# Session Handover\n\n## Completed\n- Task 1\n",
      );
      assertEquals(body.projectState.status, "READY");
      assertEquals(body.fingerprint, "20260313-150000");
    } finally {
      await cleanup(dataDir, handoverRoot);
    }
  },
);

Deno.test(
  "GET /handover/content rejects paths without /.claude/handover/",
  async () => {
    const { app, dataDir, handoverRoot } = await setup();
    try {
      const res = await app.request(
        `/api/handover/content?dir=${encodeURIComponent("/tmp/evil/path")}`,
      );
      assertEquals(res.status, 403);
    } finally {
      await cleanup(dataDir, handoverRoot);
    }
  },
);

Deno.test(
  "GET /handover/content handles missing files gracefully",
  async () => {
    const { app, dataDir, handoverRoot } = await setup();
    try {
      const dir = `${handoverRoot}/.claude/handover/main/20260313-empty`;
      await Deno.mkdir(dir, { recursive: true });

      const res = await app.request(
        `/api/handover/content?dir=${encodeURIComponent(dir)}`,
      );
      assertEquals(res.status, 200);
      const body = await res.json();

      assertEquals(body.handover, null);
      assertEquals(body.projectState, null);
      assertEquals(body.fingerprint, "20260313-empty");
    } finally {
      await cleanup(dataDir, handoverRoot);
    }
  },
);

Deno.test(
  "GET /handover/content returns 400 when dir is missing",
  async () => {
    const { app, dataDir, handoverRoot } = await setup();
    try {
      const res = await app.request(`/api/handover/content`);
      assertEquals(res.status, 400);
    } finally {
      await cleanup(dataDir, handoverRoot);
    }
  },
);
