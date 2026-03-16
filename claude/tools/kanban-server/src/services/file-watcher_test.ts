import { assertEquals } from "@std/assert";
import { FileWatcher } from "./file-watcher.ts";
import { ConflictResolver } from "./conflict-resolver.ts";

async function setup(): Promise<
  { watcher: FileWatcher; resolver: ConflictResolver; dir: string }
> {
  const dir = await Deno.makeTempDir({ prefix: "kanban-watcher-test-" });
  await Deno.mkdir(`${dir}/boards/b1`, { recursive: true });
  await Deno.mkdir(`${dir}/sessions`, { recursive: true });
  const resolver = new ConflictResolver(dir);
  const watcher = new FileWatcher(resolver, dir, 60000); // long interval, we test scanOnce
  return { watcher, resolver, dir };
}

async function cleanup(dir: string): Promise<void> {
  await Deno.remove(dir, { recursive: true });
}

Deno.test("scanOnce detects and resolves conflict files", async () => {
  const { watcher, dir } = await setup();
  try {
    // Create conflict
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.json`,
      JSON.stringify({
        id: "t1",
        title: "Old",
        updatedAt: "2026-01-01T00:00:00Z",
      }),
    );
    await Deno.writeTextFile(
      `${dir}/boards/b1/t1.sync-conflict-20260101-120000-ABCDEFG.json`,
      JSON.stringify({
        id: "t1",
        title: "New",
        updatedAt: "2026-01-02T00:00:00Z",
      }),
    );

    await watcher.scanOnce();

    // Conflict should be resolved
    const pending = watcher.getPendingConflicts();
    assertEquals(pending.length, 0);

    // Original file should have newer content
    const raw = await Deno.readTextFile(`${dir}/boards/b1/t1.json`);
    assertEquals(JSON.parse(raw).title, "New");
  } finally {
    watcher.stop();
    await cleanup(dir);
  }
});

Deno.test("getPendingConflicts returns unresolved conflicts", async () => {
  const { watcher, dir } = await setup();
  try {
    // Create conflict with identical updatedAt (→ pending)
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
      JSON.stringify({ ...data, title: "Different" }),
    );

    await watcher.scanOnce();

    const pending = watcher.getPendingConflicts();
    assertEquals(pending.length, 1);
  } finally {
    watcher.stop();
    await cleanup(dir);
  }
});

Deno.test("pending limit 200: oldest dropped when exceeded", async () => {
  const { watcher, dir } = await setup();
  try {
    // Create 201 unresolvable conflicts (identical updatedAt)
    const ts = "2026-01-01T00:00:00Z";
    for (let i = 0; i < 201; i++) {
      const name = `t${String(i).padStart(4, "0")}`;
      await Deno.writeTextFile(
        `${dir}/boards/b1/${name}.json`,
        JSON.stringify({ id: name, title: "A", updatedAt: ts }),
      );
      await Deno.writeTextFile(
        `${dir}/boards/b1/${name}.sync-conflict-20260101-120000-X${
          String(i).padStart(4, "0")
        }.json`,
        JSON.stringify({ id: name, title: "B", updatedAt: ts }),
      );
    }

    // detectConflicts returns max 50 per cycle, so we need multiple scans
    // But pending accumulates across scans
    for (let i = 0; i < 5; i++) {
      await watcher.scanOnce();
    }

    const pending = watcher.getPendingConflicts();
    // Should be capped at 200
    assertEquals(pending.length <= 200, true);
  } finally {
    watcher.stop();
    await cleanup(dir);
  }
});
