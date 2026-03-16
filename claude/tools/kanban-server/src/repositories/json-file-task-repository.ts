import type {
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

  private taskDir(boardId: string): string {
    return `${this.boardsDir}/${boardId}`;
  }

  private taskPath(boardId: string, taskId: string): string {
    return `${this.taskDir(boardId)}/${taskId}.json`;
  }

  private async ensureBoardExists(boardId: string): Promise<void> {
    try {
      await Deno.stat(this.taskDir(boardId));
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) {
        throw new Error(`Board '${boardId}' not found`);
      }
      throw e;
    }
  }

  async listTasks(boardId: string, filter?: TaskFilter): Promise<Task[]> {
    await this.ensureBoardExists(boardId);
    const tasks: Task[] = [];
    for await (const entry of Deno.readDir(this.taskDir(boardId))) {
      if (
        !entry.isFile || !entry.name.endsWith(".json") ||
        entry.name === "meta.json"
      ) {
        continue;
      }
      const raw = await Deno.readTextFile(
        `${this.taskDir(boardId)}/${entry.name}`,
      );
      tasks.push(JSON.parse(raw) as Task);
    }

    if (filter) {
      let filtered = tasks;
      if (filter.status !== undefined) {
        filtered = filtered.filter((t) => t.status === filter.status);
      }
      if (filter.priority !== undefined) {
        filtered = filtered.filter((t) => t.priority === filter.priority);
      }
      if (filter.label !== undefined) {
        filtered = filtered.filter((t) => t.labels.includes(filter.label!));
      }
      return filtered;
    }

    return tasks;
  }

  async getTask(boardId: string, taskId: string): Promise<Task | null> {
    try {
      const raw = await Deno.readTextFile(this.taskPath(boardId, taskId));
      return JSON.parse(raw) as Task;
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) return null;
      throw e;
    }
  }

  async createTask(boardId: string, input: CreateTaskInput): Promise<Task> {
    await this.ensureBoardExists(boardId);
    const now = new Date().toISOString();

    const task: Task = {
      id: crypto.randomUUID(),
      title: input.title,
      description: input.description ?? "",
      status: input.status ?? "backlog",
      priority: input.priority ?? "medium",
      labels: input.labels ?? [],
      createdAt: now,
      updatedAt: now,
    };

    if (input.worktree !== undefined) task.worktree = input.worktree;
    if (input.sessionContext !== undefined) {
      task.sessionContext = input.sessionContext;
    }
    if (input.executionHost !== undefined) {
      task.executionHost = input.executionHost;
    }

    await Deno.writeTextFile(
      this.taskPath(boardId, task.id),
      JSON.stringify(task, null, 2),
    );
    return task;
  }

  async updateTask(
    boardId: string,
    taskId: string,
    input: UpdateTaskInput,
  ): Promise<Task> {
    const task = await this.getTask(boardId, taskId);
    if (!task) {
      throw new Error(`Task '${taskId}' not found in board '${boardId}'`);
    }

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
    if (input.executionHost !== undefined) {
      task.executionHost = input.executionHost;
    }

    task.updatedAt = new Date().toISOString();
    await Deno.writeTextFile(
      this.taskPath(boardId, taskId),
      JSON.stringify(task, null, 2),
    );
    return task;
  }

  async deleteTask(boardId: string, taskId: string): Promise<void> {
    try {
      await Deno.remove(this.taskPath(boardId, taskId));
    } catch (e) {
      if (!(e instanceof Deno.errors.NotFound)) throw e;
    }
  }

  async moveTasks(boardId: string, moves: TaskMove[]): Promise<Task[]> {
    const result: Task[] = [];
    const now = new Date().toISOString();
    for (const move of moves) {
      const task = await this.getTask(boardId, move.taskId);
      if (!task) {
        throw new Error(
          `Task '${move.taskId}' not found in board '${boardId}'`,
        );
      }
      task.status = move.status;
      task.updatedAt = now;
      await Deno.writeTextFile(
        this.taskPath(boardId, task.id),
        JSON.stringify(task, null, 2),
      );
      result.push(task);
    }
    return result;
  }
}
