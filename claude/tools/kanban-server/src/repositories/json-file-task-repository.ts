import type {
  BoardData,
  CreateTaskInput,
  Task,
  TaskFilter,
  TaskMove,
  UpdateTaskInput,
} from "../types.ts";
import type { TaskRepository } from "./task-repository.ts";

export class JsonFileTaskRepository implements TaskRepository {
  private readonly boardsDir: string;

  constructor(dataDir: string) {
    this.boardsDir = `${dataDir}/boards`;
  }

  private boardPath(boardId: string): string {
    return `${this.boardsDir}/${boardId}.json`;
  }

  private async readBoardData(boardId: string): Promise<BoardData> {
    try {
      const raw = await Deno.readTextFile(this.boardPath(boardId));
      return JSON.parse(raw) as BoardData;
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) {
        throw new Error(`Board '${boardId}' not found`);
      }
      throw e;
    }
  }

  private async writeBoardData(
    boardId: string,
    data: BoardData,
  ): Promise<void> {
    await Deno.writeTextFile(
      this.boardPath(boardId),
      JSON.stringify(data, null, 2),
    );
  }

  private generateId(): string {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, "0");
    const d = String(now.getDate()).padStart(2, "0");
    const nnn = String(Math.floor(Math.random() * 1000)).padStart(3, "0");
    return `t-${y}${m}${d}-${nnn}`;
  }

  async listTasks(boardId: string, filter?: TaskFilter): Promise<Task[]> {
    const data = await this.readBoardData(boardId);
    let tasks = data.tasks;

    if (filter) {
      if (filter.status !== undefined) {
        tasks = tasks.filter((t) => t.status === filter.status);
      }
      if (filter.priority !== undefined) {
        tasks = tasks.filter((t) => t.priority === filter.priority);
      }
      if (filter.label !== undefined) {
        tasks = tasks.filter((t) => t.labels.includes(filter.label!));
      }
    }

    return tasks;
  }

  async getTask(boardId: string, taskId: string): Promise<Task | null> {
    const data = await this.readBoardData(boardId);
    return data.tasks.find((t) => t.id === taskId) ?? null;
  }

  async createTask(boardId: string, input: CreateTaskInput): Promise<Task> {
    const data = await this.readBoardData(boardId);
    const now = new Date().toISOString();

    const task: Task = {
      id: this.generateId(),
      title: input.title,
      description: input.description ?? "",
      status: input.status ?? "backlog",
      priority: input.priority ?? "medium",
      labels: input.labels ?? [],
      createdAt: now,
      updatedAt: now,
    };

    if (input.worktree !== undefined) {
      task.worktree = input.worktree;
    }
    if (input.sessionContext !== undefined) {
      task.sessionContext = input.sessionContext;
    }

    data.tasks.push(task);
    await this.writeBoardData(boardId, data);
    return task;
  }

  async updateTask(
    boardId: string,
    taskId: string,
    input: UpdateTaskInput,
  ): Promise<Task> {
    const data = await this.readBoardData(boardId);
    const idx = data.tasks.findIndex((t) => t.id === taskId);

    if (idx === -1) {
      throw new Error(`Task '${taskId}' not found in board '${boardId}'`);
    }

    const task = data.tasks[idx];

    // Optimistic locking
    if (
      input.expectedVersion !== undefined &&
      input.expectedVersion !== task.updatedAt
    ) {
      throw new Error(
        `Optimistic lock version mismatch: expected '${input.expectedVersion}', actual '${task.updatedAt}'`,
      );
    }

    if (input.title !== undefined) task.title = input.title;
    if (input.description !== undefined) task.description = input.description;
    if (input.status !== undefined) task.status = input.status;
    if (input.priority !== undefined) task.priority = input.priority;
    if (input.labels !== undefined) task.labels = input.labels;
    if (input.worktree !== undefined) task.worktree = input.worktree;
    if (input.sessionContext !== undefined) {
      task.sessionContext = input.sessionContext;
    }

    task.updatedAt = new Date().toISOString();
    data.tasks[idx] = task;
    await this.writeBoardData(boardId, data);
    return task;
  }

  async deleteTask(boardId: string, taskId: string): Promise<void> {
    const data = await this.readBoardData(boardId);
    data.tasks = data.tasks.filter((t) => t.id !== taskId);
    await this.writeBoardData(boardId, data);
  }

  async moveTasks(boardId: string, moves: TaskMove[]): Promise<Task[]> {
    const data = await this.readBoardData(boardId);
    const now = new Date().toISOString();
    const result: Task[] = [];

    for (const move of moves) {
      const task = data.tasks.find((t) => t.id === move.taskId);
      if (!task) {
        throw new Error(
          `Task '${move.taskId}' not found in board '${boardId}'`,
        );
      }
      task.status = move.status;
      task.updatedAt = now;
      result.push(task);
    }

    await this.writeBoardData(boardId, data);
    return result;
  }
}
