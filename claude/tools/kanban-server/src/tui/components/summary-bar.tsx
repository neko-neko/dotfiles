// src/tui/components/summary-bar.tsx — Status count summary bar
import { Box, Text } from "ink";
import type { Task, TaskStatus } from "../../types.ts";
import { statusColor, theme } from "../theme.ts";

interface SummaryBarProps {
  tasks: Task[];
  focusedStatus?: TaskStatus;
  activeFilterCount?: number;
}

const STATUSES: { key: TaskStatus; label: string }[] = [
  { key: "backlog", label: "backlog" },
  { key: "todo", label: "todo" },
  { key: "in_progress", label: "active" },
  { key: "review", label: "review" },
  { key: "done", label: "done" },
];

export function SummaryBar(
  { tasks, focusedStatus, activeFilterCount }: SummaryBarProps,
) {
  const counts = new Map<TaskStatus, number>();
  for (const task of tasks) {
    counts.set(task.status, (counts.get(task.status) ?? 0) + 1);
  }

  return (
    <Box paddingX={1}>
      {STATUSES.map(({ key, label }) => {
        const count = counts.get(key) ?? 0;
        const color = statusColor(key);
        const icon = key === focusedStatus ? "◇" : "◆";
        return (
          <Box key={key} marginRight={2}>
            <Text color={color}>
              {icon} {count} {label}
            </Text>
          </Box>
        );
      })}
      <Box flexGrow={1} />
      {activeFilterCount !== undefined && activeFilterCount > 0 && (
        <Box marginRight={2}>
          <Text color={theme.amber}>
            {`\u25C7 ${activeFilterCount} filter${
              activeFilterCount > 1 ? "s" : ""
            }`}
          </Text>
        </Box>
      )}
      <Text color={theme.textMuted}>{`\u03A3 ${tasks.length}`}</Text>
    </Box>
  );
}
