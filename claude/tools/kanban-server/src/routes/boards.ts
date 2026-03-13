import { Hono } from "@hono/hono";
import type { BoardRepository } from "../repositories/board-repository.ts";
import type { CreateBoardInput } from "../types.ts";

export function boardRoutes(boardRepo: BoardRepository): Hono {
  const app = new Hono();

  app.get("/boards", async (c) => {
    const boards = await boardRepo.listBoards();
    return c.json(boards);
  });

  app.post("/boards", async (c) => {
    const body = await c.req.json<Partial<CreateBoardInput>>();

    if (
      typeof body.id !== "string" || body.id.length === 0 ||
      typeof body.name !== "string" || body.name.length === 0 ||
      typeof body.path !== "string" || body.path.length === 0
    ) {
      return c.json({ error: "id, name, and path are required" }, 400);
    }

    try {
      const board = await boardRepo.createBoard({
        id: body.id,
        name: body.name,
        path: body.path,
      });
      return c.json(board, 201);
    } catch (e) {
      if (e instanceof Error && e.message.includes("already exists")) {
        return c.json({ error: e.message }, 409);
      }
      throw e;
    }
  });

  app.delete("/boards/:id", async (c) => {
    const id = c.req.param("id");
    await boardRepo.deleteBoard(id);
    return c.body(null, 204);
  });

  return app;
}
