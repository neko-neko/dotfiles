// src/tui/components/filter-overlay.tsx — Filter overlay for tasks
// Allows filtering by status, priority, and label (partial match).
// Tab to switch fields, Enter to apply, Escape to cancel.
// Prerequisite: ink ^5, react ^18, @inkjs/ui ^2
import { useState } from "react";
import { Box, Text, useInput } from "ink";
import { Select, TextInput } from "@inkjs/ui";
import type { Priority, TaskFilter, TaskStatus } from "../../types.ts";
import { theme } from "../theme.ts";

interface FilterOverlayProps {
  currentFilter: TaskFilter;
  availableLabels: string[];
  onApply: (filter: TaskFilter) => void;
  onCancel: () => void;
}

type FilterField = "status" | "priority" | "label";

const FILTER_FIELDS: FilterField[] = ["status", "priority", "label"];

const STATUS_OPTIONS: { label: string; value: string }[] = [
  { label: "All", value: "" },
  { label: "Backlog", value: "backlog" },
  { label: "Todo", value: "todo" },
  { label: "In Progress", value: "in_progress" },
  { label: "Review", value: "review" },
  { label: "Done", value: "done" },
];

const PRIORITY_OPTIONS: { label: string; value: string }[] = [
  { label: "All", value: "" },
  { label: "High", value: "high" },
  { label: "Medium", value: "medium" },
  { label: "Low", value: "low" },
];

export function FilterOverlay(
  { currentFilter, availableLabels: _availableLabels, onApply, onCancel }:
    FilterOverlayProps,
) {
  const [activeField, setActiveField] = useState(0);
  const [status, setStatus] = useState<string>(currentFilter.status ?? "");
  const [priority, setPriority] = useState<string>(
    currentFilter.priority ?? "",
  );
  const [label, setLabel] = useState(currentFilter.label ?? "");

  const currentFieldName = FILTER_FIELDS[activeField];

  useInput((_input, key) => {
    if (key.escape) {
      onCancel();
      return;
    }

    // Enter applies filter (but not when a Select field is active)
    if (
      key.return && currentFieldName !== "status" &&
      currentFieldName !== "priority"
    ) {
      const filter: TaskFilter = {};
      if (status) filter.status = status as TaskStatus;
      if (priority) filter.priority = priority as Priority;
      if (label.trim()) filter.label = label.trim();
      onApply(filter);
      return;
    }

    // Tab / Shift+Tab to move between fields
    if (key.tab) {
      setActiveField((prev) => {
        if (key.shift) {
          return prev > 0 ? prev - 1 : FILTER_FIELDS.length - 1;
        }
        return prev < FILTER_FIELDS.length - 1 ? prev + 1 : 0;
      });
      return;
    }
  });

  return (
    <Box flexDirection="column" paddingX={1}>
      <Box marginBottom={1}>
        <Text color={theme.amber} bold>
          Filter Tasks
        </Text>
        <Text color={theme.textDim}>
          {" \u2500\u2500 Tab: next field, Enter: apply, Esc: cancel"}
        </Text>
      </Box>

      {/* Status filter */}
      <Box flexDirection="column">
        <Text
          color={activeField === 0 ? theme.amber : theme.textMuted}
          bold={activeField === 0}
        >
          Status:
        </Text>
        {activeField === 0
          ? (
            <Select
              options={STATUS_OPTIONS}
              defaultValue={status}
              onChange={setStatus}
            />
          )
          : (
            <Text color={theme.text}>
              {` ${status || "all"}`}
            </Text>
          )}
      </Box>

      {/* Priority filter */}
      <Box flexDirection="column">
        <Text
          color={activeField === 1 ? theme.amber : theme.textMuted}
          bold={activeField === 1}
        >
          Priority:
        </Text>
        {activeField === 1
          ? (
            <Select
              options={PRIORITY_OPTIONS}
              defaultValue={priority}
              onChange={setPriority}
            />
          )
          : (
            <Text color={theme.text}>
              {` ${priority || "all"}`}
            </Text>
          )}
      </Box>

      {/* Label filter */}
      <Box flexDirection="row" gap={1}>
        <Text
          color={activeField === 2 ? theme.amber : theme.textMuted}
          bold={activeField === 2}
        >
          Label:
        </Text>
        {activeField === 2
          ? (
            <TextInput
              defaultValue={label}
              placeholder="partial match..."
              onChange={setLabel}
            />
          )
          : (
            <Text color={theme.text}>
              {label || <Text color={theme.textDim}>any</Text>}
            </Text>
          )}
      </Box>

      <Box marginTop={1}>
        <Text color={theme.textDim}>
          [{activeField + 1}/{FILTER_FIELDS.length}]{" "}
          {FILTER_FIELDS[activeField]}
        </Text>
      </Box>
    </Box>
  );
}
