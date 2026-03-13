// src/tui/views/board-view.tsx — Main board view: Split Pane layout
// Integrates SummaryBar, TaskTree, TaskDetail, KeybindBar,
// and modal modes for add/move/delete operations.
// Prerequisite: fullscreen-ink ^0.1.0, ink ^5, react ^18, @inkjs/ui ^2
import { useCallback, useEffect, useMemo, useState } from "react";
import { Box, Text, useApp, useFocusManager, useInput, useStdin } from "ink";
import { ConfirmInput, TextInput } from "@inkjs/ui";
import { useScreenSize } from "fullscreen-ink";
import type { Priority, Task, TaskStatus } from "../../types.ts";
import type { ProjectState } from "../../services/sync-service.ts";
import { JsonFileTaskRepository } from "../../repositories/mod.ts";
import { SyncService } from "../../services/sync-service.ts";
import {
  groupTasksByStatus,
  loadBoardData,
  STATUS_ORDER,
} from "../hooks/use-board.ts";
import { TaskActions } from "../hooks/use-task-actions.ts";
import { SummaryBar } from "../components/summary-bar.tsx";
import { TaskTree } from "../components/task-tree.tsx";
import { TaskDetail } from "../components/task-detail.tsx";
import { KeybindBar } from "../components/keybind-bar.tsx";
import { StatusSelect } from "../components/status-select.tsx";
import { TaskEditor } from "./task-editor.tsx";
import { SearchOverlay } from "../components/search-overlay.tsx";
import { theme } from "../theme.ts";
import {
  disableMouse,
  enableMouse,
  parseMouseEvent,
} from "../hooks/use-mouse-input.ts";

interface BoardViewProps {
  dataDir: string;
  boardId: string;
  onBack?: () => void;
}

type ViewMode =
  | "normal"
  | "adding"
  | "moving"
  | "deleting"
  | "editing"
  | "searching";

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
  const [toast, setToast] = useState<
    { message: string; color: string } | null
  >(null);

  // --- TaskActions & SyncService instances ---
  const { actions, syncService } = useMemo(() => {
    const repo = new JsonFileTaskRepository(dataDir);
    return {
      actions: new TaskActions(repo, boardId),
      syncService: new SyncService(repo),
    };
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
    const controller = new AbortController();

    (async () => {
      try {
        const watcher = Deno.watchFs(boardPath);
        controller.signal.addEventListener("abort", () => watcher.close());
        for await (const event of watcher) {
          if (controller.signal.aborted) break;
          if (event.kind === "modify" || event.kind === "create") {
            await loadTasks();
          }
        }
      } catch {
        // File may not exist yet, or watcher closed; ignore
      }
    })();

    return () => controller.abort();
  }, [dataDir, boardId, loadTasks]);

  // --- Mouse support ---
  const { stdin, isRawModeSupported } = useStdin();

  useEffect(() => {
    enableMouse();
    return () => disableMouse();
  }, []);

  // --- Layout calculations (needed early for mouse hit-testing) ---
  const showDetail = width >= MIN_SPLIT_WIDTH;
  // Fixed character width for left pane (30 chars including border)
  // Percentage-based sizing doesn't work well with Ink's flexbox + border
  const leftWidth = showDetail ? Math.min(36, Math.floor(width * 0.28)) : width;

  // --- Derived data ---
  const grouped = groupTasksByStatus(tasks);
  const selectedTask = tasks.find((t) => t.id === selectedTaskId) ?? null;

  // Determine which status group the selected task belongs to
  const focusedStatus = selectedTask?.status;

  // Build flat item list for mouse hit-testing (mirrors task-tree.tsx logic)
  const flatItems = useMemo(() => {
    const items: Array<
      { type: "group"; status: TaskStatus } | { type: "task"; task: Task }
    > = [];
    for (const status of STATUS_ORDER) {
      const group = grouped.get(status);
      if (!group || group.length === 0) continue;
      items.push({ type: "group", status });
      for (const task of group) {
        items.push({ type: "task", task });
      }
    }
    return items;
  }, [grouped]);

  /** Navigate task selection by delta (+1 = down, -1 = up). */
  const navigateTask = useCallback(
    (delta: number) => {
      const currentIdx = flatItems.findIndex(
        (item) => item.type === "task" && item.task.id === selectedTaskId,
      );
      const dir = delta > 0 ? 1 : -1;
      let i =
        (currentIdx === -1 ? (dir > 0 ? -1 : flatItems.length) : currentIdx) +
        dir;
      while (i >= 0 && i < flatItems.length) {
        const item = flatItems[i];
        if (item.type === "task") {
          setSelectedTaskId(item.task.id);
          return;
        }
        i += dir;
      }
    },
    [flatItems, selectedTaskId],
  );

  /** Handle mouse click at terminal coordinates. */
  const handleMouseClick = useCallback(
    (x: number, y: number) => {
      // Row layout (0-indexed terminal rows):
      //   0: Header
      //   1: Summary bar
      //   2: Toast or Error (conditional, may not exist)
      //   3+: Main pane (task-tree border top is row 3, items start at row 4)
      // The border of the TaskTree box adds 1 row top + 1 row bottom.
      const headerRows = 2 + (toast ? 1 : 0) + (error ? 1 : 0);
      const treeStartRow = headerRows + 1; // +1 for border top of TaskTree box

      // Only process clicks in the left pane area
      const leftPaneWidth = leftWidth;
      if (x > leftPaneWidth) return;

      const itemIndex = y - treeStartRow;
      if (itemIndex < 0 || itemIndex >= flatItems.length) return;

      const item = flatItems[itemIndex];
      if (item.type === "task") {
        setSelectedTaskId(item.task.id);
      }
    },
    [flatItems, toast, error, width, showDetail],
  );

  // Mouse event listener on stdin
  useEffect(() => {
    if (!isRawModeSupported || !stdin) return;

    const handler = (data: Uint8Array | string) => {
      const str = typeof data === "string"
        ? data
        : new TextDecoder().decode(data);
      const mouseEvent = parseMouseEvent(str);
      if (!mouseEvent || mouseEvent.type !== "press") return;

      if (mouseEvent.button === "left") {
        handleMouseClick(mouseEvent.x, mouseEvent.y);
      }
      if (mouseEvent.button === "scrollUp") {
        navigateTask(-1);
      }
      if (mouseEvent.button === "scrollDown") {
        navigateTask(1);
      }
    };

    stdin.on("data", handler);
    return () => {
      stdin.removeListener("data", handler);
    };
  }, [stdin, isRawModeSupported, handleMouseClick, navigateTask]);

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

  // --- Toast helper ---
  const showToast = useCallback(
    (message: string, color: string = theme.sage) => {
      setToast({ message, color });
      setTimeout(() => setToast(null), 3000);
    },
    [],
  );

  // --- Handover sync handler ---
  const handleSync = useCallback(async () => {
    try {
      // Get current git branch
      const branchCmd = new Deno.Command("git", {
        args: ["rev-parse", "--abbrev-ref", "HEAD"],
        stdout: "piped",
        stderr: "piped",
      });
      const branchOutput = await branchCmd.output();
      if (!branchOutput.success) {
        showToast("Failed to detect git branch", theme.coral);
        return;
      }
      const branch = new TextDecoder().decode(branchOutput.stdout).trim();
      if (!branch) {
        showToast("No git branch detected", theme.coral);
        return;
      }

      // Find latest fingerprint directory in ~/.claude/handover/<branch>/
      const homeDir = Deno.env.get("HOME") ?? "";
      const handoverBranchDir = `${homeDir}/.claude/handover/${branch}`;

      let entries: Deno.DirEntry[];
      try {
        entries = [];
        for await (const entry of Deno.readDir(handoverBranchDir)) {
          if (entry.isDirectory) {
            entries.push(entry);
          }
        }
      } catch {
        showToast(`No handover data for branch '${branch}'`, theme.coral);
        return;
      }

      if (entries.length === 0) {
        showToast(`No handover data for branch '${branch}'`, theme.coral);
        return;
      }

      // Sort by name descending to get the latest fingerprint
      entries.sort((a, b) => b.name.localeCompare(a.name));
      const latestDir = `${handoverBranchDir}/${entries[0].name}`;
      const projectStatePath = `${latestDir}/project-state.json`;

      let projectStateText: string;
      try {
        projectStateText = await Deno.readTextFile(projectStatePath);
      } catch {
        showToast("project-state.json not found", theme.coral);
        return;
      }

      let projectState: ProjectState;
      try {
        projectState = JSON.parse(projectStateText);
      } catch {
        showToast("Invalid project-state.json", theme.coral);
        return;
      }
      const result = await syncService.syncFromProjectState(
        boardId,
        projectState,
        projectStatePath,
      );

      await loadTasks();

      const parts: string[] = [];
      if (result.created > 0) parts.push(`${result.created} created`);
      if (result.updated > 0) parts.push(`${result.updated} updated`);
      if (result.errors.length > 0) {
        parts.push(`${result.errors.length} errors`);
      }
      const summary = parts.length > 0 ? parts.join(", ") : "no changes";
      showToast(`Synced: ${summary}`, theme.sage);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      showToast(`Sync failed: ${msg}`, theme.coral);
    }
  }, [syncService, boardId, loadTasks, showToast]);

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

      // Handover sync
      if (input === "s") {
        handleSync();
        return;
      }

      // Search
      if (input === "/") {
        setMode("searching");
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

      {/* Toast notification */}
      {toast && (
        <Box paddingX={1}>
          <Text color={toast.color}>{toast.message}</Text>
        </Box>
      )}

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

      {mode === "searching" && (
        <SearchOverlay
          tasks={tasks}
          onSelect={(taskId) => {
            setSelectedTaskId(taskId);
            setMode("normal");
          }}
          onCancel={() => setMode("normal")}
        />
      )}

      {/* Keybind Bar */}
      <KeybindBar />
    </Box>
  );
}
