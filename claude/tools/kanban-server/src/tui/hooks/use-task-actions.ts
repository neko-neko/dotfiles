import type { Task, TaskStatus, UpdateTaskInput } from "../../types.ts";
import type { TaskRepository } from "../../repositories/task-repository.ts";

export class TaskActions {
  constructor(
    private readonly repo: TaskRepository,
    private readonly boardId: string,
  ) {}

  async createTask(title: string): Promise<Task> {
    return await this.repo.createTask(this.boardId, { title });
  }

  async moveTask(taskId: string, status: TaskStatus): Promise<Task> {
    const moved = await this.repo.moveTasks(this.boardId, [
      { taskId, status },
    ]);
    if (moved.length === 0) {
      throw new Error(`Task ${taskId} not found`);
    }
    return moved[0];
  }

  async deleteTask(taskId: string): Promise<void> {
    await this.repo.deleteTask(this.boardId, taskId);
  }

  async updateTask(
    taskId: string,
    input: Omit<UpdateTaskInput, "expectedVersion">,
  ): Promise<Task> {
    return await this.repo.updateTask(this.boardId, taskId, input);
  }

  async listTasks(): Promise<Task[]> {
    return await this.repo.listTasks(this.boardId);
  }
}
