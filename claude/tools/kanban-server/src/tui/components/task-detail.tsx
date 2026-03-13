// src/tui/components/task-detail.tsx — Right pane: selected task detail view
import { Box, Text } from "ink";
import type { Task } from "../../types.ts";
import { priorityIcon, statusColor, statusIcon, theme } from "../theme.ts";

interface TaskDetailProps {
  task: Task | null;
}

interface FieldProps {
  label: string;
  children: React.ReactNode;
}

const LABEL_WIDTH = 12;

function Field({ label, children }: FieldProps) {
  return (
    <Box>
      <Box width={LABEL_WIDTH}>
        <Text color={theme.textMuted}>{label}</Text>
      </Box>
      <Box flexShrink={1}>{children}</Box>
    </Box>
  );
}

function timeSince(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  if (Number.isNaN(then)) return "unknown";

  const diffMs = Math.max(0, now - then);
  const seconds = Math.floor(diffMs / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (days > 0) return `${days}d ago`;
  if (hours > 0) return `${hours}h ago`;
  if (minutes > 0) return `${minutes}m ago`;
  return "just now";
}

const PRIORITY_COLORS: Record<string, string> = {
  high: theme.coral,
  medium: theme.amber,
  low: theme.textMuted,
};

export function TaskDetail({ task }: TaskDetailProps) {
  if (!task) {
    return (
      <Box
        flexDirection="column"
        borderStyle="round"
        borderColor={theme.border}
        justifyContent="center"
        alignItems="center"
        flexGrow={1}
      >
        <Text color={theme.textDim}>タスクを選択してください</Text>
      </Box>
    );
  }

  const sColor = statusColor(task.status);
  const sIcon = statusIcon(task.status);
  const pIcon = priorityIcon(task.priority);
  const pColor = PRIORITY_COLORS[task.priority] ?? theme.textMuted;

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor={theme.border}
      paddingX={1}
      flexGrow={1}
    >
      {/* Title */}
      <Box marginBottom={1}>
        <Text color={theme.amber} bold>{task.title}</Text>
      </Box>

      {/* Fields */}
      <Field label="Status">
        <Text color={sColor}>{sIcon} {task.status}</Text>
      </Field>

      <Field label="Priority">
        <Text color={pColor}>{pIcon} {task.priority}</Text>
      </Field>

      {task.labels.length > 0 && (
        <Field label="Labels">
          <Text color={theme.sky}>
            {task.labels.map((l) => `#${l}`).join(" ")}
          </Text>
        </Field>
      )}

      {task.worktree && (
        <Field label="Worktree">
          <Text color={theme.sage}>{task.worktree}</Text>
        </Field>
      )}

      <Field label="Updated">
        <Text color={theme.textMuted}>{timeSince(task.updatedAt)}</Text>
      </Field>

      {/* Description */}
      {task.description && (
        <Box marginTop={1} flexDirection="column">
          <Text color={theme.textMuted} underline>Description</Text>
          <Box marginTop={0}>
            <Text color={theme.text}>{task.description}</Text>
          </Box>
        </Box>
      )}

      {/* Session Context */}
      {task.sessionContext && (
        <Box marginTop={1} flexDirection="column">
          <Text color={theme.textMuted} underline>Session</Text>
          {task.sessionContext.lastSessionId && (
            <Field label="Session ID">
              <Text color={theme.violet}>{task.sessionContext.lastSessionId}</Text>
            </Field>
          )}
          {task.sessionContext.resumeHint && (
            <Field label="Resume">
              <Text color={theme.text}>{task.sessionContext.resumeHint}</Text>
            </Field>
          )}
          {task.sessionContext.handoverFile && (
            <Field label="Handover">
              <Text color={theme.sage}>{task.sessionContext.handoverFile}</Text>
            </Field>
          )}
        </Box>
      )}
    </Box>
  );
}
