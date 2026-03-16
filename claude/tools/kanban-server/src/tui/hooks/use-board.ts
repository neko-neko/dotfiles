// src/tui/hooks/use-board.ts
// Provides pure data helpers for loading and grouping board tasks.
// Reads JSON files directly from the kanban data directory (no HTTP dependency).

import type { Priority, Task, TaskStatus } from "../../types.ts";

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
 * Loads all tasks from a board directory (new individual-file format).
 * Reads boards/<boardId>/<taskId>.json files, excluding meta.json.
 *
 * @param dataDir - Root kanban data directory (e.g. `~/.claude/kanban`)
 * @param boardId - Board identifier (directory name)
 * @returns Array of tasks
 * @throws {Deno.errors.NotFound} if the board directory does not exist
 */
export async function loadBoardTasks(
  dataDir: string,
  boardId: string,
): Promise<Task[]> {
  // Validate inputs to prevent path traversal
  if (
    !boardId || boardId.includes("/") || boardId.includes("\\") ||
    boardId.includes("..")
  ) {
    throw new Error(`Invalid boardId: ${boardId}`);
  }

  const boardDir = `${dataDir}/boards/${boardId}`;
  const tasks: Task[] = [];

  for await (const entry of Deno.readDir(boardDir)) {
    if (
      !entry.isFile || !entry.name.endsWith(".json") ||
      entry.name === "meta.json"
    ) {
      continue;
    }
    const raw = await Deno.readTextFile(`${boardDir}/${entry.name}`);
    tasks.push(JSON.parse(raw) as Task);
  }

  return tasks;
}
