import type { Board, CreateBoardInput, TaskStatus } from "../types.ts";
import type { BoardRepository } from "./board-repository.ts";

const DEFAULT_COLUMNS: TaskStatus[] = [
  "backlog",
  "todo",
  "in_progress",
  "review",
  "done",
];

interface BoardMeta {
  id: string;
  name: string;
  columns: TaskStatus[];
  createdAt: string;
  updatedAt: string;
}

export class JsonFileBoardRepository implements BoardRepository {
  private readonly boardsDir: string;

  constructor(private readonly dataDir: string) {
    this.boardsDir = `${dataDir}/boards`;
  }

  private metaPath(boardId: string): string {
    return `${this.boardsDir}/${boardId}/meta.json`;
  }

  async listBoards(): Promise<Board[]> {
    const boards: Board[] = [];
    try {
      for await (const entry of Deno.readDir(this.boardsDir)) {
        if (!entry.isDirectory) continue;
        try {
          const raw = await Deno.readTextFile(
            `${this.boardsDir}/${entry.name}/meta.json`,
          );
          const meta = JSON.parse(raw) as BoardMeta;
          boards.push({
            id: meta.id,
            name: meta.name,
            path: this.dataDir,
            createdAt: meta.createdAt,
            updatedAt: meta.updatedAt,
          });
        } catch {
          // Skip directories without valid meta.json
        }
      }
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) return [];
      throw e;
    }
    return boards;
  }

  async getBoard(id: string): Promise<Board | null> {
    try {
      const raw = await Deno.readTextFile(this.metaPath(id));
      const meta = JSON.parse(raw) as BoardMeta;
      return {
        id: meta.id,
        name: meta.name,
        path: this.dataDir,
        createdAt: meta.createdAt,
        updatedAt: meta.updatedAt,
      };
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) return null;
      throw e;
    }
  }

  async createBoard(input: CreateBoardInput): Promise<Board> {
    // Check for duplicate
    const existing = await this.getBoard(input.id);
    if (existing) {
      throw new Error(`Board with id '${input.id}' already exists`);
    }

    const now = new Date().toISOString();
    const boardDir = `${this.boardsDir}/${input.id}`;
    await Deno.mkdir(boardDir, { recursive: true });

    const meta: BoardMeta = {
      id: input.id,
      name: input.name,
      columns: [...DEFAULT_COLUMNS],
      createdAt: now,
      updatedAt: now,
    };
    await Deno.writeTextFile(
      `${boardDir}/meta.json`,
      JSON.stringify(meta, null, 2),
    );

    return {
      id: input.id,
      name: input.name,
      path: input.path,
      createdAt: now,
      updatedAt: now,
    };
  }

  async deleteBoard(id: string): Promise<void> {
    try {
      await Deno.remove(`${this.boardsDir}/${id}`, { recursive: true });
    } catch (e) {
      if (!(e instanceof Deno.errors.NotFound)) {
        throw e;
      }
    }
  }
}
