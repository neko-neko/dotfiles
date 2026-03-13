import type { TaskRepository } from "../repositories/task-repository.ts";
import type { TaskStatus, SessionContext } from "../types.ts";

export interface ProjectStateTask {
  id: string;
  description: string;
  status: string;
  commit_sha?: string;
  file_paths?: string[];
  next_action?: string;
  blockers?: string[];
  last_touched?: string;
}

export interface ProjectState {
  version: number;
  session_id: string;
  status: string;
  workspace: {
    root: string;
    branch: string;
    is_worktree: boolean;
  };
  active_tasks: ProjectStateTask[];
}

export interface SyncResult {
  created: number;
  updated: number;
  errors: string[];
}

const STATUS_MAP: Record<string, TaskStatus> = {
  done: "done",
  in_progress: "in_progress",
  blocked: "review",
};

export class SyncService {
  constructor(private readonly taskRepo: TaskRepository) {}

  async syncFromProjectState(
    boardId: string,
    projectState: ProjectState,
    handoverFile: string,
  ): Promise<SyncResult> {
    const result: SyncResult = { created: 0, updated: 0, errors: [] };

    // Fetch existing tasks to match by title
    const existingTasks = await this.taskRepo.listTasks(boardId);
    const taskByTitle = new Map(existingTasks.map((t) => [t.title, t]));

    for (const psTask of projectState.active_tasks) {
      const mappedStatus = STATUS_MAP[psTask.status];
      if (!mappedStatus) {
        result.errors.push(
          `Unknown status '${psTask.status}' for task '${psTask.id}'`,
        );
        continue;
      }

      const sessionContext: SessionContext = {
        lastSessionId: projectState.session_id,
        handoverFile,
      };
      if (psTask.next_action) {
        sessionContext.resumeHint = psTask.next_action;
      }

      const worktree = projectState.workspace.root;
      const description = psTask.description;

      const existing = taskByTitle.get(description);

      try {
        if (existing) {
          // Update existing task
          await this.taskRepo.updateTask(boardId, existing.id, {
            status: mappedStatus,
            description,
            worktree,
            sessionContext,
          });
          result.updated++;
        } else {
          // Create new task
          await this.taskRepo.createTask(boardId, {
            title: description,
            description,
            status: mappedStatus,
            worktree,
            sessionContext,
          });
          result.created++;
        }
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        result.errors.push(`Failed to sync task '${psTask.id}': ${msg}`);
      }
    }

    return result;
  }
}
