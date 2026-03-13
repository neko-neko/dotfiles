// src/tui/theme.ts — Terminal Luxe theme for TUI
import type { Priority, TaskStatus } from "../types.ts";

export const theme = {
  bg: "#0D0D0D",
  surface: "#1A1A1A",
  surfaceHover: "#242424",
  text: "#E8E4D9",
  textMuted: "#6B6560",
  textDim: "#3D3A36",
  amber: "#D4A574",
  sage: "#7D9B76",
  coral: "#C47A6C",
  sky: "#6B9BC3",
  violet: "#9B8EC4",
  rose: "#B5727E",
  border: "#2A2725",
  borderActive: "#D4A574",
} as const;

const STATUS_COLORS: Record<TaskStatus, string> = {
  in_progress: theme.amber,
  todo: theme.sky,
  done: theme.sage,
  review: theme.violet,
  backlog: theme.textMuted,
};

const PRIORITY_ICONS: Record<Priority, string> = {
  high: "●",
  medium: "◐",
  low: "○",
};

const STATUS_ICONS: Record<TaskStatus, string> = {
  in_progress: "▶",
  todo: "○",
  done: "✓",
  review: "◎",
  backlog: "◆",
};

export function statusColor(status: TaskStatus): string {
  return STATUS_COLORS[status];
}

export function priorityIcon(priority: Priority): string {
  return PRIORITY_ICONS[priority];
}

export function statusIcon(status: TaskStatus): string {
  return STATUS_ICONS[status];
}
