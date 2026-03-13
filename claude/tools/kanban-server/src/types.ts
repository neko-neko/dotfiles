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
  executionHost?: "local" | "remote";
  remoteSessionName?: string;
  lastHandoverPath?: string;
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

export interface BoardData {
  version: number;
  boardId: string;
  columns: TaskStatus[];
  tasks: Task[];
}

export interface BoardsIndex {
  version: number;
  boards: Board[];
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
  executionHost?: "local" | "remote";
  remoteSessionName?: string;
  lastHandoverPath?: string;
}

export interface UpdateTaskInput {
  title?: string;
  description?: string;
  status?: TaskStatus;
  priority?: Priority;
  labels?: string[];
  worktree?: string;
  sessionContext?: SessionContext;
  executionHost?: "local" | "remote";
  remoteSessionName?: string;
  lastHandoverPath?: string;
  expectedVersion?: string;
}

export interface TaskFilter {
  status?: TaskStatus;
  priority?: Priority;
  label?: string;
}

export interface TaskMove {
  taskId: string;
  status: TaskStatus;
}
