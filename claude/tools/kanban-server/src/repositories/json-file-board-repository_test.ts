import { assertEquals, assertRejects } from "@std/assert";
import { JsonFileBoardRepository } from "./json-file-board-repository.ts";
import type { BoardsIndex } from "../types.ts";

async function setup(): Promise<
  { repo: JsonFileBoardRepository; dir: string }
> {
  const dir = await Deno.makeTempDir({ prefix: "kanban-test-" });
  const index: BoardsIndex = { version: 1, boards: [] };
  await Deno.writeTextFile(`${dir}/boards.json`, JSON.stringify(index));
  await Deno.mkdir(`${dir}/boards`);
  return { repo: new JsonFileBoardRepository(dir), dir };
}

async function cleanup(dir: string): Promise<void> {
  await Deno.remove(dir, { recursive: true });
}

Deno.test("listBoards returns empty array initially", async () => {
  const { repo, dir } = await setup();
  try {
    const boards = await repo.listBoards();
    assertEquals(boards, []);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("createBoard adds a board and returns it", async () => {
  const { repo, dir } = await setup();
  try {
    const board = await repo.createBoard({
      id: "b1",
      name: "My Board",
      path: "/tmp/project",
    });
    assertEquals(board.id, "b1");
    assertEquals(board.name, "My Board");
    assertEquals(board.path, "/tmp/project");
    assertEquals(typeof board.createdAt, "string");
    assertEquals(typeof board.updatedAt, "string");

    const boards = await repo.listBoards();
    assertEquals(boards.length, 1);
    assertEquals(boards[0].id, "b1");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("createBoard rejects duplicate id", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.createBoard({ id: "b1", name: "Board 1", path: "/tmp/p1" });
    await assertRejects(
      () =>
        repo.createBoard({ id: "b1", name: "Board 1 dup", path: "/tmp/p2" }),
      Error,
      "already exists",
    );
  } finally {
    await cleanup(dir);
  }
});

Deno.test("getBoard returns board by id", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.createBoard({ id: "b1", name: "Board 1", path: "/tmp/p1" });
    const board = await repo.getBoard("b1");
    assertEquals(board?.id, "b1");
    assertEquals(board?.name, "Board 1");
  } finally {
    await cleanup(dir);
  }
});

Deno.test("getBoard returns null for missing id", async () => {
  const { repo, dir } = await setup();
  try {
    const board = await repo.getBoard("nonexistent");
    assertEquals(board, null);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("deleteBoard removes the board", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.createBoard({ id: "b1", name: "Board 1", path: "/tmp/p1" });
    await repo.deleteBoard("b1");
    const boards = await repo.listBoards();
    assertEquals(boards.length, 0);
    const board = await repo.getBoard("b1");
    assertEquals(board, null);
  } finally {
    await cleanup(dir);
  }
});

Deno.test("createBoard also creates board data file with correct structure", async () => {
  const { repo, dir } = await setup();
  try {
    await repo.createBoard({ id: "b1", name: "Board 1", path: "/tmp/p1" });
    const raw = await Deno.readTextFile(`${dir}/boards/b1.json`);
    const data = JSON.parse(raw);
    assertEquals(data.version, 1);
    assertEquals(data.boardId, "b1");
    assertEquals(data.columns, [
      "backlog",
      "todo",
      "in_progress",
      "review",
      "done",
    ]);
    assertEquals(data.tasks, []);
  } finally {
    await cleanup(dir);
  }
});
