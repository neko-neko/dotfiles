// src/tui/views/board-view.tsx — Main board view: Split Pane layout
// Integrates SummaryBar, TaskTree, TaskDetail, and KeybindBar.
// Prerequisite: fullscreen-ink ^0.1.0, ink ^5, react ^18
import { useCallback, useEffect, useState } from "react";
import { Box, Text, useApp, useFocusManager, useInput } from "ink";
import { useScreenSize } from "fullscreen-ink";
import type { Task, TaskStatus } from "../../types.ts";
import { groupTasksByStatus, loadBoardData } from "../hooks/use-board.ts";
import { SummaryBar } from "../components/summary-bar.tsx";
import { TaskTree } from "../components/task-tree.tsx";
import { TaskDetail } from "../components/task-detail.tsx";
import { KeybindBar } from "../components/keybind-bar.tsx";
import { theme } from "../theme.ts";

interface BoardViewProps {
  dataDir: string;
  boardId: string;
  onBack?: () => void;
}

/** Maps numeric keys 1-5 to statuses for quick jump. */
const STATUS_JUMP: Record<string, TaskStatus> = {
  "1": "backlog",
  "2": "todo",
  "3": "in_progress",
  "4": "review",
  "5": "done",
};

/** Minimum terminal width to show the detail pane. */
const MIN_SPLIT_WIDTH = 60;

export function BoardView({ dataDir, boardId, onBack }: BoardViewProps) {
  const { exit } = useApp();
  const { width, height } = useScreenSize();
  const { focusNext, focusPrevious } = useFocusManager();

  const [tasks, setTasks] = useState<Task[]>([]);
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // --- Data loading ---
  const loadTasks = useCallback(async () => {
    try {
      const data = await loadBoardData(dataDir, boardId);
      setTasks(data.tasks);
      setError(null);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg);
    }
  }, [dataDir, boardId]);

  useEffect(() => {
    loadTasks();
  }, [loadTasks]);

  // Auto-select first task when tasks load and nothing is selected
  useEffect(() => {
    if (selectedTaskId === null && tasks.length > 0) {
      setSelectedTaskId(tasks[0].id);
    }
  }, [tasks, selectedTaskId]);

  // Watch board file for external changes
  useEffect(() => {
    const boardPath = `${dataDir}/boards/${boardId}.json`;
    let aborted = false;

    (async () => {
      try {
        const watcher = Deno.watchFs(boardPath);
        for await (const event of watcher) {
          if (aborted) break;
          if (event.kind === "modify" || event.kind === "create") {
            await loadTasks();
          }
        }
      } catch {
        // File may not exist yet or watcher unsupported; ignore
      }
    })();

    return () => {
      aborted = true;
    };
  }, [dataDir, boardId, loadTasks]);

  // --- Derived data ---
  const grouped = groupTasksByStatus(tasks);
  const selectedTask = tasks.find((t) => t.id === selectedTaskId) ?? null;

  // Determine which status group the selected task belongs to
  const focusedStatus = selectedTask?.status;

  // --- Global keybinds ---
  useInput((input, key) => {
    // Quit
    if (input === "q" || (key.ctrl && input === "c")) {
      exit();
      return;
    }

    // Tab / Shift+Tab to switch pane focus
    if (key.tab) {
      if (key.shift) {
        focusPrevious();
      } else {
        focusNext();
      }
      return;
    }

    // Board selection (back)
    if (input === "b" && onBack) {
      onBack();
      return;
    }

    // Quick-jump to status group (1-5)
    const jumpStatus = STATUS_JUMP[input];
    if (jumpStatus) {
      const groupTasks = grouped.get(jumpStatus);
      if (groupTasks && groupTasks.length > 0) {
        setSelectedTaskId(groupTasks[0].id);
      }
      return;
    }
  });

  // --- Layout calculations ---
  const showDetail = width >= MIN_SPLIT_WIDTH;
  const leftWidth = showDetail ? Math.floor(width * 0.35) : width;

  return (
    <Box
      flexDirection="column"
      width={width}
      height={height}
    >
      {/* Header */}
      <Box paddingX={1}>
        <Text>
          <Text color={theme.amber} bold>kanban</Text>
          <Text color={theme.textDim}>
            {` \u2500\u2500 `}
          </Text>
          <Text color={theme.text}>{boardId}</Text>
        </Text>
      </Box>

      {/* Summary Bar */}
      <SummaryBar tasks={tasks} focusedStatus={focusedStatus} />

      {/* Error toast */}
      {error && (
        <Box paddingX={1}>
          <Text color={theme.coral}>
            <Text bold>Error:</Text>
            {` ${error}`}
          </Text>
        </Box>
      )}

      {/* Main area: split pane */}
      <Box flexGrow={1} flexDirection="row">
        {/* Left pane: TaskTree */}
        <Box width={leftWidth} flexDirection="column">
          <TaskTree
            groupedTasks={grouped}
            selectedTaskId={selectedTaskId}
            onSelectTask={setSelectedTaskId}
            onFocusRight={() => {
              if (showDetail) focusNext();
            }}
          />
        </Box>

        {/* Right pane: TaskDetail */}
        {showDetail && (
          <Box flexGrow={1} flexDirection="column">
            <TaskDetail task={selectedTask} />
          </Box>
        )}
      </Box>

      {/* Keybind Bar */}
      <KeybindBar />
    </Box>
  );
}
