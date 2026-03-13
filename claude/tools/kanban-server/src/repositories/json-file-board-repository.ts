import type {
  Board,
  BoardData,
  BoardsIndex,
  CreateBoardInput,
  TaskStatus,
} from "../types.ts";
import type { BoardRepository } from "./board-repository.ts";

const DEFAULT_COLUMNS: TaskStatus[] = [
  "backlog",
  "todo",
  "in_progress",
  "review",
  "done",
];

export class JsonFileBoardRepository implements BoardRepository {
  private readonly indexPath: string;
  private readonly boardsDir: string;

  constructor(private readonly dataDir: string) {
    this.indexPath = `${dataDir}/boards.json`;
    this.boardsDir = `${dataDir}/boards`;
  }

  private async readIndex(): Promise<BoardsIndex> {
    const raw = await Deno.readTextFile(this.indexPath);
    return JSON.parse(raw) as BoardsIndex;
  }

  private async writeIndex(index: BoardsIndex): Promise<void> {
    await Deno.writeTextFile(this.indexPath, JSON.stringify(index, null, 2));
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
      throw new Error(`Board with id '${input.id}' already exists`);
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
      columns: [...DEFAULT_COLUMNS],
      tasks: [],
    };
    await Deno.writeTextFile(
      `${this.boardsDir}/${input.id}.json`,
      JSON.stringify(boardData, null, 2),
    );

    return board;
  }

  async deleteBoard(id: string): Promise<void> {
    const index = await this.readIndex();
    index.boards = index.boards.filter((b) => b.id !== id);
    await this.writeIndex(index);

    try {
      await Deno.remove(`${this.boardsDir}/${id}.json`);
    } catch (e) {
      if (!(e instanceof Deno.errors.NotFound)) {
        throw e;
      }
    }
  }
}
