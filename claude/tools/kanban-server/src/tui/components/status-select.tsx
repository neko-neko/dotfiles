// src/tui/components/status-select.tsx — Status selector for moving tasks
import { Box, Text } from "ink";
import { Select } from "@inkjs/ui";
import type { TaskStatus } from "../../types.ts";
import { statusIcon } from "../theme.ts";

interface StatusSelectProps {
  currentStatus: TaskStatus;
  onSelect: (status: TaskStatus) => void;
}

const STATUSES: TaskStatus[] = [
  "backlog",
  "todo",
  "in_progress",
  "review",
  "done",
];

const STATUS_LABELS: Record<TaskStatus, string> = {
  backlog: "Backlog",
  todo: "Todo",
  in_progress: "In Progress",
  review: "Review",
  done: "Done",
};

export function StatusSelect({ currentStatus, onSelect }: StatusSelectProps) {
  const options = STATUSES
    .filter((s) => s !== currentStatus)
    .map((s) => ({
      label: `${statusIcon(s)} ${STATUS_LABELS[s]}`,
      value: s,
    }));

  return (
    <Box flexDirection="column" paddingX={1}>
      <Text bold>Move to:</Text>
      <Select
        options={options}
        onChange={(value) => onSelect(value as TaskStatus)}
      />
    </Box>
  );
}
