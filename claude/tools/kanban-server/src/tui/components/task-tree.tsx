// src/tui/components/task-tree.tsx — Left pane: collapsible task tree grouped by status
import { useState } from "react";
import { Box, Text, useFocus, useInput } from "ink";
import type { Task, TaskStatus } from "../../types.ts";
import { STATUS_ORDER } from "../hooks/use-board.ts";
import { priorityIcon, statusColor, statusIcon, theme } from "../theme.ts";

interface TaskTreeProps {
  groupedTasks: Map<TaskStatus, Task[]>;
  selectedTaskId: string | null;
  onSelectTask: (id: string) => void;
  onFocusRight: () => void;
}

const STATUS_LABELS: Record<TaskStatus, string> = {
  in_progress: "In Progress",
  todo: "Todo",
  backlog: "Backlog",
  review: "Review",
  done: "Done",
};

type FlatItem =
  | { type: "group"; status: TaskStatus }
  | { type: "task"; task: Task };

function buildFlatList(
  groupedTasks: Map<TaskStatus, Task[]>,
  collapsed: Set<TaskStatus>,
): FlatItem[] {
  const items: FlatItem[] = [];
  for (const status of STATUS_ORDER) {
    const tasks = groupedTasks.get(status);
    if (!tasks || tasks.length === 0) continue;
    items.push({ type: "group", status });
    if (!collapsed.has(status)) {
      for (const task of tasks) {
        items.push({ type: "task", task });
      }
    }
  }
  return items;
}

function findIndexForTask(
  items: FlatItem[],
  taskId: string | null,
): number {
  if (!taskId) return -1;
  return items.findIndex(
    (item) => item.type === "task" && item.task.id === taskId,
  );
}

function findNextTaskIndex(items: FlatItem[], from: number, dir: 1 | -1): number {
  let i = from + dir;
  while (i >= 0 && i < items.length) {
    if (items[i].type === "task") return i;
    i += dir;
  }
  return -1;
}

function findNextGroupIndex(items: FlatItem[], from: number, dir: 1 | -1): number {
  let i = from + dir;
  while (i >= 0 && i < items.length) {
    if (items[i].type === "group") {
      // Find the first task after this group header
      const taskIdx = findNextTaskIndex(items, i, 1);
      if (taskIdx !== -1) return taskIdx;
    }
    i += dir;
  }
  return -1;
}

export function TaskTree({
  groupedTasks,
  selectedTaskId,
  onSelectTask,
  onFocusRight,
}: TaskTreeProps) {
  const { isFocused } = useFocus({ autoFocus: true });
  const [collapsed, setCollapsed] = useState<Set<TaskStatus>>(new Set());

  const items = buildFlatList(groupedTasks, collapsed);
  const currentIndex = findIndexForTask(items, selectedTaskId);

  // Auto-select first task if nothing is selected
  if (selectedTaskId === null && items.length > 0) {
    const firstTask = items.find((item) => item.type === "task");
    if (firstTask && firstTask.type === "task") {
      // Defer to avoid updating state during render
      queueMicrotask(() => onSelectTask(firstTask.task.id));
    }
  }

  useInput((input, key) => {
    if (!isFocused) return;

    if (input === "j" || (key.downArrow && !key.shift)) {
      // Move to next task
      const next = findNextTaskIndex(items, currentIndex === -1 ? -1 : currentIndex, 1);
      if (next !== -1) {
        const item = items[next];
        if (item.type === "task") onSelectTask(item.task.id);
      }
      return;
    }

    if (input === "k" || (key.upArrow && !key.shift)) {
      // Move to previous task
      const prev = findNextTaskIndex(
        items,
        currentIndex === -1 ? items.length : currentIndex,
        -1,
      );
      if (prev !== -1) {
        const item = items[prev];
        if (item.type === "task") onSelectTask(item.task.id);
      }
      return;
    }

    if (input === "J") {
      // Jump to next status group
      const next = findNextGroupIndex(items, currentIndex === -1 ? -1 : currentIndex, 1);
      if (next !== -1) {
        const item = items[next];
        if (item.type === "task") onSelectTask(item.task.id);
      }
      return;
    }

    if (input === "K") {
      // Jump to previous status group
      const prev = findNextGroupIndex(
        items,
        currentIndex === -1 ? items.length : currentIndex,
        -1,
      );
      if (prev !== -1) {
        const item = items[prev];
        if (item.type === "task") onSelectTask(item.task.id);
      }
      return;
    }

    if (input === "o") {
      // Toggle collapse for the group containing the selected task
      if (currentIndex === -1) return;
      // Walk back to find the group header
      let groupStatus: TaskStatus | null = null;
      for (let i = currentIndex; i >= 0; i--) {
        const item = items[i];
        if (item.type === "group") {
          groupStatus = item.status;
          break;
        }
      }
      if (groupStatus) {
        setCollapsed((prev) => {
          const next = new Set(prev);
          if (next.has(groupStatus)) {
            next.delete(groupStatus);
          } else {
            next.add(groupStatus);
          }
          return next;
        });
      }
      return;
    }

    if (input === "l" || key.return) {
      onFocusRight();
      return;
    }
  });

  return (
    <Box flexDirection="column" borderStyle="round" borderColor={isFocused ? theme.borderActive : theme.border}>
      {items.map((item) => {
        if (item.type === "group") {
          const count = groupedTasks.get(item.status)?.length ?? 0;
          const isCollapsed = collapsed.has(item.status);
          const color = statusColor(item.status);
          return (
            <Box key={`group-${item.status}`} paddingX={1}>
              <Text color={color}>
                {isCollapsed ? "\u25B8" : "\u25BE"} {STATUS_LABELS[item.status]} ({count})
              </Text>
            </Box>
          );
        }

        const isSelected = item.task.id === selectedTaskId;
        const pIcon = priorityIcon(item.task.priority);
        const sIcon = statusIcon(item.task.status);
        const sColor = statusColor(item.task.status);

        return (
          <Box
            key={`task-${item.task.id}`}
            paddingX={1}
            {...(isSelected ? { backgroundColor: theme.surfaceHover } : {})}
          >
            <Text color={isSelected ? theme.amber : theme.textDim}>
              {isSelected ? "\u258C" : " "}
            </Text>
            <Text color={sColor}>{` ${sIcon} `}</Text>
            <Text color={theme.textMuted}>{pIcon} </Text>
            <Text color={isSelected ? theme.text : theme.textMuted}>
              {item.task.title}
            </Text>
          </Box>
        );
      })}
      {items.length === 0 && (
        <Box paddingX={1}>
          <Text color={theme.textDim}>No tasks</Text>
        </Box>
      )}
    </Box>
  );
}
