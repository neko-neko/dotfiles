// src/tui/components/task-detail.tsx — Right pane: selected task detail view
// Layout mirrors the Web UI: Title → Description → Labels → Fields → Session → Footer
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

const LABEL_COLORS = [
  theme.amber,
  theme.sage,
  theme.coral,
  theme.sky,
  theme.violet,
  theme.rose,
];

function labelColor(label: string): string {
  let hash = 0;
  for (const char of label) {
    hash = ((hash << 5) - hash + char.charCodeAt(0)) | 0;
  }
  return LABEL_COLORS[Math.abs(hash) % LABEL_COLORS.length];
}

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

function formatDate(dateStr: string): string {
  const d = new Date(dateStr);
  if (Number.isNaN(d.getTime())) return "unknown";
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const h = String(d.getHours()).padStart(2, "0");
  const min = String(d.getMinutes()).padStart(2, "0");
  return `${y}-${m}-${day} ${h}:${min}`;
}

function Separator() {
  return (
    <Box marginY={0}>
      <Text color={theme.textDim}>
        {"  ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄"}
      </Text>
    </Box>
  );
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
      {/* Title (prominent, amber, bold) */}
      <Box marginBottom={0}>
        <Text color={theme.amber} bold>
          {task.title}
        </Text>
      </Box>

      {/* Description (immediately after title, prominent) */}
      {task.description && (
        <Box marginTop={1} marginBottom={0}>
          <Text color={theme.text} wrap="wrap">
            {task.description}
          </Text>
        </Box>
      )}

      {/* Labels as colored tags */}
      {task.labels.length > 0 && (
        <Box marginTop={1} gap={1}>
          {task.labels.map((l) => (
            <Text key={l} color={labelColor(l)}>
              #{l}
            </Text>
          ))}
        </Box>
      )}

      <Separator />

      {/* Status + Priority + Worktree fields */}
      <Field label="Status">
        <Text color={sColor}>
          {sIcon} {task.status}
        </Text>
      </Field>

      <Field label="Priority">
        <Text color={pColor}>
          {pIcon} {task.priority}
        </Text>
      </Field>

      {task.worktree && (
        <Field label="Worktree">
          <Text color={theme.sage}>{task.worktree}</Text>
        </Field>
      )}

      {/* Session Context */}
      {task.sessionContext && (
        <>
          <Separator />
          <Box flexDirection="column">
            <Text color={theme.textMuted} bold>
              Session
            </Text>
            {task.sessionContext.lastSessionId && (
              <Field label="  ID">
                <Text color={theme.violet}>
                  {task.sessionContext.lastSessionId}
                </Text>
              </Field>
            )}
            {task.sessionContext.resumeHint && (
              <Field label="  Resume">
                <Text color={theme.text}>
                  {task.sessionContext.resumeHint}
                </Text>
              </Field>
            )}
            {task.sessionContext.handoverFile && (
              <Field label="  Handover">
                <Text color={theme.sage}>
                  {task.sessionContext.handoverFile}
                </Text>
              </Field>
            )}
          </Box>
        </>
      )}

      {/* Footer: Created, Updated, Task ID */}
      <Separator />
      <Field label="Created">
        <Text color={theme.textMuted}>{formatDate(task.createdAt)}</Text>
      </Field>
      <Field label="Updated">
        <Text color={theme.textMuted}>{timeSince(task.updatedAt)}</Text>
      </Field>
      <Field label="ID">
        <Text color={theme.textDim}>{task.id}</Text>
      </Field>
    </Box>
  );
}
