export type TaskStatus = "backlog" | "todo" | "in_progress" | "review" | "done";
export type Priority = "high" | "medium" | "low";

export interface SessionContext {
  lastSessionId?: string;
  handoverFile?: string;
  resumeHint?: string;
}

export interface Task {
  id: string;
  title: string;
  description: string;
  status: TaskStatus;
  priority: Priority;
  labels: string[];
  worktree?: string;
  sessionContext?: SessionContext;
  executionHost?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Board {
  id: string;
  name: string;
  path: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateBoardInput {
  id: string;
  name: string;
  path: string;
}

export interface CreateTaskInput {
  title: string;
  description?: string;
  status?: TaskStatus;
  priority?: Priority;
  labels?: string[];
  worktree?: string;
  sessionContext?: SessionContext;
  executionHost?: string;
}

export interface UpdateTaskInput {
  title?: string;
  description?: string;
  status?: TaskStatus;
  priority?: Priority;
  labels?: string[];
  worktree?: string;
  sessionContext?: SessionContext;
  executionHost?: string;
  expectedVersion?: string;
}

// Session types for multi-node sync
export type SessionStatus =
  | "starting"
  | "in-progress"
  | "awaiting-review"
  | "done"
  | "failed";

export interface Session {
  id: string;
  taskId: string;
  boardId: string;
  host: string;
  ownerNode: string;
  status: SessionStatus;
  claudeSessionId?: string;
  handoverPath?: string;
  worktree?: string;
  branch?: string;
  launchCommand?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateSessionInput {
  taskId: string;
  boardId: string;
  host: string;
  ownerNode: string;
  worktree?: string;
  branch?: string;
  launchCommand?: string;
}

export interface UpdateSessionInput {
  status?: SessionStatus;
  claudeSessionId?: string;
  handoverPath?: string;
  worktree?: string;
  branch?: string;
}

export const SESSION_TRANSITIONS: Record<SessionStatus, SessionStatus[]> = {
  "starting": ["in-progress", "failed"],
  "in-progress": ["awaiting-review", "done", "failed"],
  "awaiting-review": ["done"],
  "done": [],
  "failed": [],
};

export interface TaskFilter {
  status?: TaskStatus;
  priority?: Priority;
  label?: string;
}

export interface TaskMove {
  taskId: string;
  status: TaskStatus;
}
