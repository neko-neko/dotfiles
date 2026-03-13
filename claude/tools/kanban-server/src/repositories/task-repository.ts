import type { Task, CreateTaskInput, UpdateTaskInput, TaskFilter, TaskMove } from "../types.ts";

export interface TaskRepository {
  listTasks(boardId: string, filter?: TaskFilter): Promise<Task[]>;
  getTask(boardId: string, taskId: string): Promise<Task | null>;
  createTask(boardId: string, input: CreateTaskInput): Promise<Task>;
  updateTask(boardId: string, taskId: string, input: UpdateTaskInput): Promise<Task>;
  deleteTask(boardId: string, taskId: string): Promise<void>;
  moveTasks(boardId: string, moves: TaskMove[]): Promise<Task[]>;
}
