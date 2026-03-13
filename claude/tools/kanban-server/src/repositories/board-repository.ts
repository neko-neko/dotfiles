import type { Board, CreateBoardInput } from "../types.ts";

export interface BoardRepository {
  listBoards(): Promise<Board[]>;
  getBoard(id: string): Promise<Board | null>;
  createBoard(input: CreateBoardInput): Promise<Board>;
  deleteBoard(id: string): Promise<void>;
}
