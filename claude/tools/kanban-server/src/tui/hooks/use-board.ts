// src/tui/hooks/use-board.ts
// Provides pure data helpers for loading and grouping board tasks.
// Reads JSON files directly from the kanban data directory (no HTTP dependency).

import type { BoardData, Priority, Task, TaskStatus } from "../../types.ts";

const PRIORITY_ORDER: Record<Priority, number> = {
  high: 0,
  medium: 1,
  low: 2,
};

/** Canonical column display order for the TUI board view. */
export const STATUS_ORDER: TaskStatus[] = [
  "in_progress",
  "todo",
  "backlog",
  "review",
  "done",
];

/**
 * Groups tasks by their status and sorts each group by priority (high first).
 * Only statuses that have at least one task will appear as keys.
 */
export function groupTasksByStatus(
  tasks: Task[],
): Map<TaskStatus, Task[]> {
  const grouped = new Map<TaskStatus, Task[]>();

  for (const task of tasks) {
    const list = grouped.get(task.status) ?? [];
    list.push(task);
    grouped.set(task.status, list);
  }

  for (const [_status, list] of grouped) {
    list.sort(
      (a, b) => PRIORITY_ORDER[a.priority] - PRIORITY_ORDER[b.priority],
    );
  }

  return grouped;
}

/**
 * Loads a board's JSON data directly from the filesystem.
 *
 * @param dataDir - Root kanban data directory (e.g. `~/.claude/kanban`)
 * @param boardId - Board identifier (filename without `.json`)
 * @throws {Deno.errors.NotFound} if the board file does not exist
 */
export async function loadBoardData(
  dataDir: string,
  boardId: string,
): Promise<BoardData> {
  // Validate inputs to prevent path traversal
  if (
    !boardId || boardId.includes("/") || boardId.includes("\\") ||
    boardId.includes("..")
  ) {
    throw new Error(`Invalid boardId: ${boardId}`);
  }

  const path = `${dataDir}/boards/${boardId}.json`;
  const text = await Deno.readTextFile(path);
  return JSON.parse(text) as BoardData;
}
