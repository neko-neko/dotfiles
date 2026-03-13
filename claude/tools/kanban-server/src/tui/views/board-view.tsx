// src/tui/views/board-view.tsx — Main board view: Split Pane layout
// Integrates SummaryBar, TaskTree, TaskDetail, KeybindBar,
// and modal modes for add/move/delete operations.
// Prerequisite: fullscreen-ink ^0.1.0, ink ^5, react ^18, @inkjs/ui ^2
import { useCallback, useEffect, useMemo, useState } from "react";
import { Box, Text, useApp, useFocusManager, useInput } from "ink";
import { ConfirmInput, TextInput } from "@inkjs/ui";
import { useScreenSize } from "fullscreen-ink";
import type { Priority, Task, TaskStatus } from "../../types.ts";
import { JsonFileTaskRepository } from "../../repositories/mod.ts";
import { groupTasksByStatus, loadBoardData } from "../hooks/use-board.ts";
import { TaskActions } from "../hooks/use-task-actions.ts";
import { SummaryBar } from "../components/summary-bar.tsx";
import { TaskTree } from "../components/task-tree.tsx";
import { TaskDetail } from "../components/task-detail.tsx";
import { KeybindBar } from "../components/keybind-bar.tsx";
import { StatusSelect } from "../components/status-select.tsx";
import { TaskEditor } from "./task-editor.tsx";
import { theme } from "../theme.ts";

interface BoardViewProps {
  dataDir: string;
  boardId: string;
  onBack?: () => void;
}

type ViewMode = "normal" | "adding" | "moving" | "deleting" | "editing";

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
  const [mode, setMode] = useState<ViewMode>("normal");

  // --- TaskActions instance ---
  const actions = useMemo(() => {
    const repo = new JsonFileTaskRepository(dataDir);
    return new TaskActions(repo, boardId);
  }, [dataDir, boardId]);

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

  // --- Mode handlers ---
  const handleAddSubmit = useCallback(
    async (title: string) => {
      const trimmed = title.trim();
      if (trimmed.length === 0) {
        setMode("normal");
        return;
      }
      try {
        await actions.createTask(trimmed);
        await loadTasks();
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        setError(msg);
      }
      setMode("normal");
    },
    [actions, loadTasks],
  );

  const handleMoveSelect = useCallback(
    async (status: TaskStatus) => {
      if (!selectedTaskId) {
        setMode("normal");
        return;
      }
      try {
        await actions.moveTask(selectedTaskId, status);
        await loadTasks();
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        setError(msg);
      }
      setMode("normal");
    },
    [actions, selectedTaskId, loadTasks],
  );

  const handleDeleteConfirm = useCallback(async () => {
    if (!selectedTaskId) {
      setMode("normal");
      return;
    }
    try {
      await actions.deleteTask(selectedTaskId);
      setSelectedTaskId(null);
      await loadTasks();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg);
    }
    setMode("normal");
  }, [actions, selectedTaskId, loadTasks]);

  const handleDeleteCancel = useCallback(() => {
    setMode("normal");
  }, []);

  const handleEditSave = useCallback(
    async (
      updates: Partial<{
        title: string;
        description: string;
        status: TaskStatus;
        priority: Priority;
        labels: string[];
        worktree: string;
      }>,
    ) => {
      if (!selectedTaskId) {
        setMode("normal");
        return;
      }
      try {
        if (Object.keys(updates).length > 0) {
          await actions.updateTask(selectedTaskId, updates);
          await loadTasks();
        }
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        setError(msg);
      }
      setMode("normal");
    },
    [actions, selectedTaskId, loadTasks],
  );

  const handleEditCancel = useCallback(() => {
    setMode("normal");
  }, []);

  // --- Global keybinds (only active in normal mode) ---
  useInput(
    (input, key) => {
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

      // Add task
      if (input === "a") {
        setMode("adding");
        return;
      }

      // Move task
      if (input === "m" && selectedTask) {
        setMode("moving");
        return;
      }

      // Edit task
      if (input === "e" && selectedTask) {
        setMode("editing");
        return;
      }

      // Delete task
      if (input === "d" && selectedTask) {
        setMode("deleting");
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
    },
    { isActive: mode === "normal" },
  );

  // Escape handler for modal modes
  useInput(
    (_input, key) => {
      if (key.escape) {
        setMode("normal");
      }
    },
    { isActive: mode !== "normal" },
  );

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

        {/* Right pane: TaskDetail or TaskEditor */}
        {showDetail && (
          <Box flexGrow={1} flexDirection="column">
            {mode === "editing" && selectedTask
              ? (
                <TaskEditor
                  task={selectedTask}
                  onSave={handleEditSave}
                  onCancel={handleEditCancel}
                />
              )
              : <TaskDetail task={selectedTask} />}
          </Box>
        )}
      </Box>

      {/* Modal overlays */}
      {mode === "adding" && (
        <Box paddingX={1} flexDirection="row" gap={1}>
          <Text color={theme.amber} bold>New task:</Text>
          <TextInput
            placeholder="Task title..."
            onSubmit={handleAddSubmit}
          />
        </Box>
      )}

      {mode === "moving" && selectedTask && (
        <StatusSelect
          currentStatus={selectedTask.status}
          onSelect={handleMoveSelect}
        />
      )}

      {mode === "deleting" && selectedTask && (
        <Box paddingX={1} flexDirection="row" gap={1}>
          <Text color={theme.coral} bold>
            Delete &apos;{selectedTask.title}&apos;?
          </Text>
          <ConfirmInput
            defaultChoice="cancel"
            onConfirm={handleDeleteConfirm}
            onCancel={handleDeleteCancel}
          />
        </Box>
      )}

      {/* Keybind Bar */}
      <KeybindBar />
    </Box>
  );
}
