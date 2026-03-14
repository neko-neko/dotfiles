// src/tui/views/board-select_test.tsx — Basic render tests for BoardSelect
import { assertEquals, assertExists } from "@std/assert";
import { render } from "ink-testing-library";
import { BoardSelect } from "./board-select.tsx";

// Use a temp data dir with no boards.json — should show error state
Deno.test("BoardSelect renders loading state initially", () => {
  const tmpDir = Deno.makeTempDirSync();

  const { lastFrame, unmount } = render(
    <BoardSelect dataDir={tmpDir} onSelect={() => {}} />,
  );

  const frame = lastFrame();
  assertExists(frame);
  assertEquals(frame.includes("Loading"), true);

  unmount();
  Deno.removeSync(tmpDir, { recursive: true });
});

Deno.test("BoardSelect shows error when boards.json is missing", async () => {
  const tmpDir = Deno.makeTempDirSync();

  const { lastFrame, unmount } = render(
    <BoardSelect dataDir={tmpDir} onSelect={() => {}} />,
  );

  // Wait for async load to complete
  await new Promise((r) => setTimeout(r, 200));

  const frame = lastFrame();
  assertExists(frame);
  assertEquals(frame.includes("Error") || frame.includes("error"), true);

  unmount();
  Deno.removeSync(tmpDir, { recursive: true });
});

Deno.test("BoardSelect shows empty state with valid but empty boards", async () => {
  const tmpDir = Deno.makeTempDirSync();
  Deno.mkdirSync(`${tmpDir}/boards`, { recursive: true });
  Deno.writeTextFileSync(
    `${tmpDir}/boards.json`,
    JSON.stringify({ version: 1, boards: [] }),
  );

  const { lastFrame, unmount } = render(
    <BoardSelect dataDir={tmpDir} onSelect={() => {}} />,
  );

  await new Promise((r) => setTimeout(r, 200));

  const frame = lastFrame();
  assertExists(frame);
  assertEquals(
    frame.includes("No boards") || frame.includes("create"),
    true,
  );

  unmount();
  Deno.removeSync(tmpDir, { recursive: true });
});

Deno.test("BoardSelect renders board list with progress bars", async () => {
  const tmpDir = Deno.makeTempDirSync();
  Deno.mkdirSync(`${tmpDir}/boards`, { recursive: true });

  const now = new Date().toISOString();
  Deno.writeTextFileSync(
    `${tmpDir}/boards.json`,
    JSON.stringify({
      version: 1,
      boards: [
        {
          id: "test-board",
          name: "Test Board",
          path: "/tmp/test",
          createdAt: now,
          updatedAt: now,
        },
      ],
    }),
  );

  Deno.writeTextFileSync(
    `${tmpDir}/boards/test-board.json`,
    JSON.stringify({
      version: 1,
      boardId: "test-board",
      columns: ["backlog", "todo", "in_progress", "review", "done"],
      tasks: [
        {
          id: "t1",
          title: "Task 1",
          description: "",
          status: "todo",
          priority: "medium",
          labels: [],
          createdAt: now,
          updatedAt: now,
        },
      ],
    }),
  );

  const { lastFrame, unmount } = render(
    <BoardSelect dataDir={tmpDir} onSelect={() => {}} />,
  );

  await new Promise((r) => setTimeout(r, 200));

  const frame = lastFrame();
  assertExists(frame);
  assertEquals(frame.includes("Test Board"), true);

  unmount();
  Deno.removeSync(tmpDir, { recursive: true });
});
