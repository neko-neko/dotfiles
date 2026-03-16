import { assertEquals } from "@std/assert";
import { ConflictResolver } from "./conflict-resolver.ts";

async function setup(): Promise<{ resolver: ConflictResolver; dir: string }> {
  const dir = await Deno.makeTempDir({ prefix: "kanban-conflict-test-" });
  await Deno.mkdir(`${dir}/boards/b1`, { recursive: true });
  await Deno.mkdir(`${dir}/sessions`, { recursive: true });
  return { resolver: new ConflictResolver(dir), dir };
}

async function cleanup(dir: string): Promise<void> {
  await Deno.remove(dir, { recursive: true });
}

Deno.test("detectConflicts finds .sync-conflict files", async () => {
  const { resolver, dir } = await setup();
  try {
    // Create a normal file and a conflict file
    const task = { id: "t1", title: "Task", updatedAt: "2026-01-01T00:00:00Z" };
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.json`,
      JSON.stringify(task),
    );
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.sync-conflict-20260101-120000-ABCDEFG.json`,
      JSON.stringify({ ...task, title: "Conflict" }),
    );

    const conflicts = await resolver.detectConflicts();
    assertEquals(conflicts.length, 1);
    assertEquals(conflicts[0].type, "task");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("resolveConflict picks newer updatedAt (LWW)", async () => {
  const { resolver, dir } = await setup();
  try {
    const older = {
      id: "t1",
      title: "Old",
      updatedAt: "2026-01-01T00:00:00Z",
    };
    const newer = {
      id: "t1",
      title: "New",
      updatedAt: "2026-01-02T00:00:00Z",
    };
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.json`,
      JSON.stringify(older),
    );
    const conflictPath =
      `${dir}/boards/b1/t1.sync-conflict-20260101-120000-ABCDEFG.json`;
    await Deno.writeTextFile(conflictPath, JSON.stringify(newer));

    const conflicts = await resolver.detectConflicts();
    const result = await resolver.resolveConflict(conflicts[0]);

    assertEquals(result.resolved, true);
    assertEquals(result.winner, "remote");

    // Verify original file now has newer content
    const raw = await Deno.readTextFile(`${dir}/boards/b1/t1.json`);
    const resolved = JSON.parse(raw);
    assertEquals(resolved.title, "New");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("resolveConflict picks valid JSON when other is corrupt", async () => {
  const { resolver, dir } = await setup();
  try {
    const valid = {
      id: "t1",
      title: "Valid",
      updatedAt: "2026-01-01T00:00:00Z",
    };
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.json`,
      JSON.stringify(valid),
    );
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.sync-conflict-20260101-120000-ABCDEFG.json`,
      "not json {{{",
    );

    const conflicts = await resolver.detectConflicts();
    const result = await resolver.resolveConflict(conflicts[0]);

    assertEquals(result.resolved, true);
    assertEquals(result.winner, "local");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("resolveConflict returns pending for identical updatedAt", async () => {
  const { resolver, dir } = await setup();
  try {
    const data = {
      id: "t1",
      title: "Same",
      updatedAt: "2026-01-01T00:00:00Z",
    };
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.json`,
      JSON.stringify(data),
    );
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.sync-conflict-20260101-120000-ABCDEFG.json`,
      JSON.stringify({ ...data, title: "Different but same time" }),
    );

    const conflicts = await resolver.detectConflicts();
    const result = await resolver.resolveConflict(conflicts[0]);

    assertEquals(result.resolved, false);
    assertEquals(result.reason, "identical updatedAt");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("resolveConflict deletes conflict file after resolution", async () => {
  const { resolver, dir } = await setup();
  try {
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.json`,
      JSON.stringify({
        id: "t1",
        title: "Old",
        updatedAt: "2026-01-01T00:00:00Z",
      }),
    );
    const conflictPath =
      `${dir}/boards/b1/t1.sync-conflict-20260101-120000-ABCDEFG.json`;
    await Deno.writeTextFile(
      conflictPath,
      JSON.stringify({
        id: "t1",
        title: "New",
        updatedAt: "2026-01-02T00:00:00Z",
      }),
    );

    const conflicts = await resolver.detectConflicts();
    await resolver.resolveConflict(conflicts[0]);

    // Conflict file should be deleted
    try {
      await Deno.stat(conflictPath);
      throw new Error("Conflict file should be deleted");
    } catch (e) {
      assertEquals(e instanceof Deno.errors.NotFound, true);
    }
  } finally {
    await cleanup(dir);
  }
});

Deno.test("detectConflicts limits to 50", async () => {
  const { resolver, dir } = await setup();
  try {
    const task = { id: "t", title: "T", updatedAt: "2026-01-01T00:00:00Z" };
    // Create 51 conflict files
    for (let i = 0; i < 51; i++) {
      const name = `t${i}`;
      await Deno.writeTextFile(
        `${dir}/boards/b1/${name}.json`,
        JSON.stringify({ ...task, id: name }),
      );
      await Deno.writeTextFile(
        `${dir}/boards/b1/${name}.sync-conflict-20260101-120000-ABC${
          String(i).padStart(4, "0")
        }.json`,
        JSON.stringify({ ...task, id: name, title: "conflict" }),
      );
    }

    const conflicts = await resolver.detectConflicts();
    assertEquals(conflicts.length, 50);
  } finally {
    await cleanup(dir);
  }
});
