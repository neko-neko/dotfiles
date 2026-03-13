// src/tui/views/task-editor.tsx — Inline task editor form
// Replaces right pane when editing. Tab/Shift+Tab to navigate fields,
// Enter to save, Escape to cancel.
// Prerequisite: @inkjs/ui ^2 (TextInput, Select), react ^18, ink ^5
import { useCallback, useState } from "react";
import { Box, Text, useInput } from "ink";
import { Select, TextInput } from "@inkjs/ui";
import type { Priority, Task, TaskStatus } from "../../types.ts";
import { theme } from "../theme.ts";

interface TaskEditorProps {
  task: Task;
  onSave: (
    updates: Partial<{
      title: string;
      description: string;
      status: TaskStatus;
      priority: Priority;
      labels: string[];
      worktree: string;
    }>,
  ) => void;
  onCancel: () => void;
}

const FIELD_NAMES = [
  "title",
  "status",
  "priority",
  "labels",
  "worktree",
  "description",
] as const;

type FieldName = (typeof FIELD_NAMES)[number];

const FIELD_LABELS: Record<FieldName, string> = {
  title: "Title",
  status: "Status",
  priority: "Priority",
  labels: "Labels",
  worktree: "Worktree",
  description: "Description",
};

const STATUS_OPTIONS: { label: string; value: string }[] = [
  { label: "Backlog", value: "backlog" },
  { label: "Todo", value: "todo" },
  { label: "In Progress", value: "in_progress" },
  { label: "Review", value: "review" },
  { label: "Done", value: "done" },
];

const PRIORITY_OPTIONS: { label: string; value: string }[] = [
  { label: "High", value: "high" },
  { label: "Medium", value: "medium" },
  { label: "Low", value: "low" },
];

export function TaskEditor({ task, onSave, onCancel }: TaskEditorProps) {
  const [activeField, setActiveField] = useState(0);
  const [title, setTitle] = useState(task.title);
  const [status, setStatus] = useState<TaskStatus>(task.status);
  const [priority, setPriority] = useState<Priority>(task.priority);
  const [labels, setLabels] = useState(task.labels.join(", "));
  const [worktree, setWorktree] = useState(task.worktree ?? "");
  const [description, setDescription] = useState(task.description);

  const currentFieldName = FIELD_NAMES[activeField];

  const handleSave = useCallback(() => {
    const trimmedTitle = title.trim();
    if (trimmedTitle.length === 0) return; // title is required

    const parsedLabels = labels
      .split(",")
      .map((l) => l.trim())
      .filter((l) => l.length > 0);

    const updates: Partial<{
      title: string;
      description: string;
      status: TaskStatus;
      priority: Priority;
      labels: string[];
      worktree: string;
    }> = {};

    if (trimmedTitle !== task.title) updates.title = trimmedTitle;
    if (description !== task.description) updates.description = description;
    if (status !== task.status) updates.status = status;
    if (priority !== task.priority) updates.priority = priority;
    if (
      JSON.stringify(parsedLabels) !== JSON.stringify(task.labels)
    ) {
      updates.labels = parsedLabels;
    }
    const trimmedWorktree = worktree.trim();
    if (trimmedWorktree !== (task.worktree ?? "")) {
      updates.worktree = trimmedWorktree || undefined;
    }

    onSave(updates);
  }, [title, description, status, priority, labels, worktree, task, onSave]);

  // Navigation between fields + save/cancel
  useInput((_input, key) => {
    if (key.escape) {
      onCancel();
      return;
    }

    // Enter saves (but not when a Select field is active — Select uses Enter internally)
    if (
      key.return && currentFieldName !== "status" &&
      currentFieldName !== "priority"
    ) {
      handleSave();
      return;
    }

    // Tab / Shift+Tab to move between fields
    if (key.tab) {
      setActiveField((prev) => {
        if (key.shift) {
          return prev > 0 ? prev - 1 : FIELD_NAMES.length - 1;
        }
        return prev < FIELD_NAMES.length - 1 ? prev + 1 : 0;
      });
      return;
    }
  });

  const renderField = (field: FieldName, index: number) => {
    const isActive = activeField === index;
    const label = FIELD_LABELS[field];
    const labelColor = isActive ? theme.amber : theme.textMuted;

    switch (field) {
      case "title":
        return (
          <Box key={field} flexDirection="row" gap={1}>
            <Text color={labelColor} bold={isActive}>
              {label}:
            </Text>
            {isActive
              ? <TextInput defaultValue={title} onChange={setTitle} />
              : <Text color={theme.text}>{title}</Text>}
          </Box>
        );

      case "status":
        return (
          <Box key={field} flexDirection="column">
            <Text color={labelColor} bold={isActive}>
              {label}:
            </Text>
            {isActive
              ? (
                <Select
                  options={STATUS_OPTIONS}
                  defaultValue={status}
                  onChange={(v) => setStatus(v as TaskStatus)}
                />
              )
              : <Text color={theme.text}>{` ${status}`}</Text>}
          </Box>
        );

      case "priority":
        return (
          <Box key={field} flexDirection="column">
            <Text color={labelColor} bold={isActive}>
              {label}:
            </Text>
            {isActive
              ? (
                <Select
                  options={PRIORITY_OPTIONS}
                  defaultValue={priority}
                  onChange={(v) => setPriority(v as Priority)}
                />
              )
              : <Text color={theme.text}>{` ${priority}`}</Text>}
          </Box>
        );

      case "labels":
        return (
          <Box key={field} flexDirection="row" gap={1}>
            <Text color={labelColor} bold={isActive}>
              {label}:
            </Text>
            {isActive
              ? (
                <TextInput
                  defaultValue={labels}
                  placeholder="comma-separated"
                  onChange={setLabels}
                />
              )
              : (
                <Text color={theme.text}>
                  {labels || <Text color={theme.textDim}>none</Text>}
                </Text>
              )}
          </Box>
        );

      case "worktree":
        return (
          <Box key={field} flexDirection="row" gap={1}>
            <Text color={labelColor} bold={isActive}>
              {label}:
            </Text>
            {isActive
              ? (
                <TextInput
                  defaultValue={worktree}
                  placeholder="/path/to/worktree"
                  onChange={setWorktree}
                />
              )
              : (
                <Text color={theme.text}>
                  {worktree || <Text color={theme.textDim}>none</Text>}
                </Text>
              )}
          </Box>
        );

      case "description":
        return (
          <Box key={field} flexDirection="column">
            <Text color={labelColor} bold={isActive}>
              {label}:
            </Text>
            {isActive
              ? (
                <TextInput
                  defaultValue={description}
                  placeholder="Task description..."
                  onChange={setDescription}
                />
              )
              : (
                <Text color={theme.text}>
                  {description || <Text color={theme.textDim}>empty</Text>}
                </Text>
              )}
          </Box>
        );
    }
  };

  return (
    <Box flexDirection="column" paddingX={1} paddingY={1}>
      <Box marginBottom={1}>
        <Text color={theme.amber} bold>
          Edit Task
        </Text>
        <Text color={theme.textDim}>
          {" ── Tab: next field, Shift+Tab: prev, Enter: save, Esc: cancel"}
        </Text>
      </Box>

      {FIELD_NAMES.map((field, i) => renderField(field, i))}

      <Box marginTop={1}>
        <Text color={theme.textDim}>
          [{activeField + 1}/{FIELD_NAMES.length}]{" "}
          {FIELD_LABELS[currentFieldName]}
        </Text>
      </Box>
    </Box>
  );
}
