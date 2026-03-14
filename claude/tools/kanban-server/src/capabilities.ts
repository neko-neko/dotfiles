// src/capabilities.ts
import type {
  Board,
  CreateBoardInput,
  CreateTaskInput,
  Task,
  TaskFilter,
  TaskStatus,
  UpdateTaskInput,
} from "./types.ts";
import type { SyncResult } from "./services/sync-service.ts";
import type {
  PullResult,
  PushResult,
  SyncStatus,
} from "./services/git-sync-service.ts";

// --- Session types (shared between TUI and Web) ---

export interface HandoverSession {
  fingerprint: string;
  path: string;
  hasHandover: boolean;
  hasProjectState: boolean;
  status: string;
  generatedAt: string | null;
  taskSummary: { done: number; in_progress: number; blocked: number };
}

export interface HandoverContent {
  handover: string | null;
  projectState: unknown;
  fingerprint: string;
}

export interface ClaudeSession {
  sessionId: string;
  slug: string;
  gitBranch: string;
  version: string;
  timestamp: string;
  firstPrompt: string;
  agentCount: number;
}

export interface SessionMessage {
  role: string;
  content: string;
  timestamp: string;
  agentId?: string;
}

export interface SessionMessages {
  sessionId: string;
  slug: string;
  messages: SessionMessage[];
  totalCount: number;
}

export interface ContextDocument {
  context: string;
  sessionCount: number;
  messageCount: number;
  tokenEstimate: number;
}

export interface BoardSummary {
  id: string;
  name: string;
  path: string;
  taskCounts: Record<string, number>;
  totalTasks: number;
}

export interface LaunchResult {
  status: string;
  command?: string;
  host?: string;
  sessionName?: string;
  taskId?: string;
  error?: string;
}

export interface RemoteStatus {
  taskId: string;
  host: string;
  sessionName: string;
  status: "running" | "stopped" | "unknown";
}

// --- Capability Interfaces ---

export interface BoardCapabilities {
  listBoards(): Promise<Board[]>;
  createBoard(input: CreateBoardInput): Promise<Board>;
  deleteBoard(boardId: string): Promise<void>;
  getOverview(): Promise<BoardSummary[]>;
}

export interface TaskCapabilities {
  listTasks(boardId: string, filter?: TaskFilter): Promise<Task[]>;
  getTask(boardId: string, taskId: string): Promise<Task | null>;
  createTask(boardId: string, input: CreateTaskInput): Promise<Task>;
  updateTask(
    boardId: string,
    taskId: string,
    input: UpdateTaskInput,
  ): Promise<Task>;
  deleteTask(boardId: string, taskId: string): Promise<void>;
  moveTask(boardId: string, taskId: string, status: TaskStatus): Promise<Task>;
}

export interface SessionCapabilities {
  listHandoverSessions(
    root: string,
    branch: string,
  ): Promise<HandoverSession[]>;
  getHandoverContent(dir: string): Promise<HandoverContent>;
  listClaudeSessions(projectPath: string): Promise<ClaudeSession[]>;
  getSessionMessages(
    sessionId: string,
    projectPath: string,
    limit?: number,
  ): Promise<SessionMessages>;
  buildContext(
    project: string,
    sessionIds: string[],
    includeHandover?: boolean,
    handoverDir?: string,
  ): Promise<ContextDocument>;
}

export interface LaunchCapabilities {
  launchLocal(
    projectPath: string,
    sessionId?: string,
    context?: string,
  ): Promise<LaunchResult>;
  launchRemote(
    taskId: string,
    projectPath: string,
    host?: string,
    context?: string,
    taskTitle?: string,
  ): Promise<LaunchResult>;
  getRemoteStatus(taskId: string, host?: string): Promise<RemoteStatus>;
  listRemoteHosts(): Promise<{
    hosts: Array<{ name: string; host: string; user?: string }>;
    defaultRemote?: string;
  }>;
  pingRemote(
    host?: string,
  ): Promise<{ host: string; online: boolean; latencyMs: number }>;
}

export interface SyncCapabilities {
  getSyncStatus(): Promise<SyncStatus>;
  pull(): Promise<PullResult>;
  push(message: string): Promise<PushResult>;
  syncFromHandover(boardId: string, branch: string): Promise<SyncResult>;
}

export type AllCapabilities =
  & BoardCapabilities
  & TaskCapabilities
  & SessionCapabilities
  & LaunchCapabilities
  & SyncCapabilities;
