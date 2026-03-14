// src/tui/components/handover-browser.tsx — Right-pane handover session browser
// Shows handover sessions for the current worktree/branch.
// Data loading is done externally (board-view.tsx); this is a pure display component.
// Prerequisite: ink ^5, react ^18
import { Box, Text, useInput } from "ink";
import type { HandoverContent, HandoverSession } from "../../capabilities.ts";
import { theme } from "../theme.ts";

export interface HandoverBrowserProps {
  sessions: HandoverSession[];
  selectedIndex: number;
  expandedFingerprint: string | null;
  expandedContent: HandoverContent | null;
  onNavigate: (delta: number) => void;
  onToggleExpand: () => void;
  onClose: () => void;
}

const STATUS_BADGE: Record<string, { icon: string; color: string }> = {
  COMPLETED: { icon: "✓", color: theme.sage },
  IN_PROGRESS: { icon: "▶", color: theme.amber },
  BLOCKED: { icon: "●", color: theme.coral },
  UNKNOWN: { icon: "?", color: theme.textMuted },
};

function statusBadge(status: string): { icon: string; color: string } {
  return STATUS_BADGE[status] ?? STATUS_BADGE.UNKNOWN;
}

function formatFingerprint(fp: string): string {
  // Show first 8 chars for readability
  return fp.length > 12 ? fp.slice(0, 12) : fp;
}

function TaskSummaryText(
  { summary }: { summary: HandoverSession["taskSummary"] },
) {
  const parts: Array<{ count: number; label: string; color: string }> = [];
  if (summary.done > 0) {
    parts.push({ count: summary.done, label: "done", color: theme.sage });
  }
  if (summary.in_progress > 0) {
    parts.push({
      count: summary.in_progress,
      label: "wip",
      color: theme.amber,
    });
  }
  if (summary.blocked > 0) {
    parts.push({
      count: summary.blocked,
      label: "blocked",
      color: theme.coral,
    });
  }

  if (parts.length === 0) {
    return <Text color={theme.textDim}>no tasks</Text>;
  }

  return (
    <Box gap={1}>
      {parts.map((p) => (
        <Text key={p.label} color={p.color}>
          {p.count}
          {p.label}
        </Text>
      ))}
    </Box>
  );
}

export function HandoverBrowser({
  sessions,
  selectedIndex,
  expandedFingerprint,
  expandedContent,
  onNavigate,
  onToggleExpand,
  onClose,
}: HandoverBrowserProps) {
  useInput((input, key) => {
    if (input === "j" || key.downArrow) {
      onNavigate(1);
      return;
    }
    if (input === "k" || key.upArrow) {
      onNavigate(-1);
      return;
    }
    if (key.return) {
      onToggleExpand();
      return;
    }
    if (input === "h" || key.escape) {
      onClose();
      return;
    }
  });

  if (sessions.length === 0) {
    return (
      <Box
        flexDirection="column"
        borderStyle="round"
        borderColor={theme.border}
        justifyContent="center"
        alignItems="center"
        flexGrow={1}
      >
        <Text color={theme.textDim}>No handover sessions found</Text>
        <Text color={theme.textDim}>Press h or Esc to close</Text>
      </Box>
    );
  }

  const clampedIndex = Math.min(
    Math.max(0, selectedIndex),
    sessions.length - 1,
  );

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor={theme.amber}
      paddingX={1}
      paddingY={0}
      flexGrow={1}
    >
      {/* Header */}
      <Box marginBottom={0}>
        <Text color={theme.amber} bold>
          Handover Sessions
        </Text>
        <Text color={theme.textDim}>
          {` (${sessions.length})`}
        </Text>
      </Box>

      {/* Session list */}
      <Box flexDirection="column" flexGrow={1}>
        {sessions.map((session, i) => {
          const isSelected = i === clampedIndex;
          const isExpanded = session.fingerprint === expandedFingerprint;
          const badge = statusBadge(session.status);

          return (
            <Box key={session.fingerprint} flexDirection="column">
              {/* Session row */}
              <Box>
                <Text
                  color={isSelected ? theme.amber : theme.text}
                  bold={isSelected}
                >
                  {isSelected ? "\u25B6 " : "  "}
                </Text>
                <Text color={badge.color}>{badge.icon}</Text>
                <Text color={theme.textMuted}></Text>
                <Text
                  color={isSelected ? theme.amber : theme.text}
                  bold={isSelected}
                >
                  {formatFingerprint(session.fingerprint)}
                </Text>
                <Text color={theme.textMuted}></Text>
                <TaskSummaryText summary={session.taskSummary} />
                {session.hasHandover && <Text color={theme.sage}>[md]</Text>}
                {session.hasProjectState && <Text color={theme.sky}>[ps]</Text>}
              </Box>

              {/* Expanded content */}
              {isExpanded && expandedContent && (
                <Box
                  flexDirection="column"
                  marginLeft={4}
                  marginY={0}
                  paddingX={1}
                  borderStyle="single"
                  borderColor={theme.border}
                >
                  {expandedContent.handover
                    ? (
                      <Text color={theme.text} wrap="wrap">
                        {expandedContent.handover.length > 2000
                          ? expandedContent.handover.slice(0, 2000) +
                            "\n...(truncated)"
                          : expandedContent.handover}
                      </Text>
                    )
                    : (
                      <Text color={theme.textDim} italic>
                        No handover.md content
                      </Text>
                    )}
                </Box>
              )}
              {isExpanded && !expandedContent && (
                <Box marginLeft={4}>
                  <Text color={theme.textMuted}>Loading...</Text>
                </Box>
              )}
            </Box>
          );
        })}
      </Box>

      {/* Hint bar */}
      <Box>
        <Text color={theme.textDim}>
          {"j/k navigate \u00B7 Enter expand \u00B7 h/Esc close"}
        </Text>
      </Box>
    </Box>
  );
}
