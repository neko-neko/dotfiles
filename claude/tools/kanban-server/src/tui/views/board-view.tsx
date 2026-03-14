// src/tui/views/board-view.tsx — Main board view: Split Pane layout
// Integrates SummaryBar, TaskTree, TaskDetail, KeybindBar,
// and modal modes for add/move/delete operations.
// Prerequisite: fullscreen-ink ^0.1.0, ink ^5, react ^18, @inkjs/ui ^2
import { useCallback, useEffect, useMemo, useState } from "react";
import { Box, Text, useApp, useFocusManager, useInput, useStdin } from "ink";
import { ConfirmInput } from "@inkjs/ui";
import { useScreenSize } from "fullscreen-ink";
import type {
  CreateTaskInput,
  Priority,
  Task,
  TaskFilter,
  TaskStatus,
} from "../../types.ts";
import type { ProjectState } from "../../services/sync-service.ts";
import { JsonFileTaskRepository } from "../../repositories/mod.ts";
import { SyncService } from "../../services/sync-service.ts";
import { GitSyncService } from "../../services/git-sync-service.ts";
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
import { FilterOverlay } from "../components/filter-overlay.tsx";
import { HandoverBrowser } from "../components/handover-browser.tsx";
import { LaunchMenu } from "../components/launch-menu.tsx";
import type { HandoverContent, HandoverSession } from "../../capabilities.ts";
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
  onSessions?: () => void;
}

type ViewMode =
  | "normal"
  | "adding"
  | "moving"
  | "deleting"
  | "editing"
  | "searching"
  | "filtering"
  | "launching";

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

export function BoardView(
  { dataDir, boardId, onBack, onSessions }: BoardViewProps,
) {
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
  const [filter, setFilter] = useState<TaskFilter>({});
  const [syncDirty, setSyncDirty] = useState<boolean | null>(null);
  const [rightPane, setRightPane] = useState<"detail" | "handover">("detail");
  const [handoverSessions, setHandoverSessions] = useState<HandoverSession[]>(
    [],
  );
  const [handoverIndex, setHandoverIndex] = useState(0);
  const [expandedFingerprint, setExpandedFingerprint] = useState<string | null>(
    null,
  );
  const [expandedContent, setExpandedContent] = useState<
    HandoverContent | null
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

  // --- Sync status polling ---
  useEffect(() => {
    const gitSync = new GitSyncService(dataDir);
    const check = async () => {
      try {
        const status = await gitSync.getStatus();
        setSyncDirty(status.dirty);
      } catch {
        // ignore — data dir may not be a git repo
      }
    };
    check();
    const interval = setInterval(check, 30000);
    return () => clearInterval(interval);
  }, [dataDir]);

  // --- Mouse support ---
  const { stdin, isRawModeSupported } = useStdin();

  // Mouse tracking toggle: disable during TextInput to prevent SGR injection,
  // but keep enabled during Select fields so click-to-select works.
  const [editorFieldType, setEditorFieldType] = useState<
    "text" | "select" | null
  >(null);
  const [selectClickIndex, setSelectClickIndex] = useState<number | null>(
    null,
  );

  const isTextInputMode = mode === "searching" || mode === "filtering" ||
    ((mode === "editing" || mode === "adding") && editorFieldType === "text");
  useEffect(() => {
    if (isTextInputMode) {
      disableMouse();
    } else {
      enableMouse();
    }
    return () => disableMouse();
  }, [isTextInputMode]);

  // --- Layout calculations (needed early for mouse hit-testing) ---
  const showDetail = width >= MIN_SPLIT_WIDTH;
  // Fixed character width for left pane (30 chars including border)
  // Percentage-based sizing doesn't work well with Ink's flexbox + border
  const leftWidth = showDetail
    ? Math.min(36, Math.max(12, Math.floor(width * 0.28)))
    : Math.max(12, width);

  // --- Derived data ---
  const filteredTasks = useMemo(() => {
    let result = tasks;
    if (filter.status) {
      result = result.filter((t) => t.status === filter.status);
    }
    if (filter.priority) {
      result = result.filter((t) => t.priority === filter.priority);
    }
    if (filter.label) {
      const lowerLabel = filter.label.toLowerCase();
      result = result.filter((t) =>
        t.labels.some((l) => l.toLowerCase().includes(lowerLabel))
      );
    }
    return result;
  }, [tasks, filter]);

  const activeFilterCount = useMemo(() => {
    let count = 0;
    if (filter.status) count++;
    if (filter.priority) count++;
    if (filter.label) count++;
    return count;
  }, [filter]);

  const grouped = groupTasksByStatus(filteredTasks);
  const selectedTask = tasks.find((t) => t.id === selectedTaskId) ?? null;

  // Determine which status group the selected task belongs to
  const focusedStatus = selectedTask?.status;

  // Collapsed state lifted from TaskTree so mouse hit-testing stays in sync (B1)
  const [collapsed, setCollapsed] = useState<Set<TaskStatus>>(new Set());
  const onToggleCollapse = useCallback((status: TaskStatus) => {
    setCollapsed((prev) => {
      const next = new Set(prev);
      if (next.has(status)) next.delete(status);
      else next.add(status);
      return next;
    });
  }, []);

  // Build flat item list for mouse hit-testing (mirrors task-tree.tsx logic)
  const flatItems = useMemo(() => {
    const items: Array<
      { type: "group"; status: TaskStatus } | { type: "task"; task: Task }
    > = [];
    for (const status of STATUS_ORDER) {
      const group = grouped.get(status);
      if (!group || group.length === 0) continue;
      items.push({ type: "group", status });
      if (!collapsed.has(status)) {
        for (const task of group) {
          items.push({ type: "task", task });
        }
      }
    }
    return items;
  }, [grouped, collapsed]);

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

  /** Handle mouse click at terminal coordinates (SGR 1-based). */
  const handleMouseClick = useCallback(
    (sgrX: number, sgrY: number) => {
      // SGR mouse coordinates are 1-based; convert to 0-based
      const x = sgrX - 1;
      const y = sgrY - 1;

      const headerRows = 2 + (toast ? 1 : 0) + (error ? 1 : 0);

      // When editing with a Select field active, clicks in the right pane
      // map to a dropdown option by y-offset from the editor top.
      if (
        (mode === "editing" || mode === "adding") &&
        editorFieldType === "select" && showDetail && x >= leftWidth
      ) {
        // Pass y relative to the right pane top so TaskEditor can compute option index
        const relativeY = y - headerRows;
        if (relativeY >= 0) {
          setSelectClickIndex(relativeY);
          setTimeout(() => setSelectClickIndex(null), 50);
        }
        return;
      }

      const treeStartRow = headerRows + 1; // +1 for border top of TaskTree box

      // Only process clicks in the left pane area
      if (x >= leftWidth) return;

      const itemIndex = y - treeStartRow;
      if (itemIndex < 0 || itemIndex >= flatItems.length) return;

      const item = flatItems[itemIndex];
      if (item.type === "task") {
        setSelectedTaskId(item.task.id);
      }
    },
    [flatItems, toast, error, leftWidth, mode, editorFieldType, showDetail],
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
  const handleAddSave = useCallback(
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
      const title = updates.title?.trim();
      if (!title || title.length === 0) {
        setMode("normal");
        return;
      }
      try {
        const input: CreateTaskInput = { title };
        if (updates.description) input.description = updates.description;
        if (updates.status) input.status = updates.status;
        if (updates.priority) input.priority = updates.priority;
        if (updates.labels) input.labels = updates.labels;
        if (updates.worktree) input.worktree = updates.worktree;
        await actions.createTask(input);
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

      // Filter
      if (input === "f") {
        setMode("filtering");
        return;
      }

      // Launch menu
      if (input === "x" && selectedTask) {
        setMode("launching");
        return;
      }

      // Handover browser
      if (input === "H") {
        (async () => {
          try {
            const branchCmd = new Deno.Command("git", {
              args: ["rev-parse", "--abbrev-ref", "HEAD"],
              stdout: "piped",
              stderr: "piped",
            });
            const branchOutput = await branchCmd.output();
            const branch = new TextDecoder().decode(branchOutput.stdout).trim();
            if (!branch) {
              showToast("No git branch detected", theme.coral);
              return;
            }

            const homeDir = Deno.env.get("HOME") ?? "";
            const handoverDir = `${homeDir}/.claude/handover/${branch}`;
            const sessions: HandoverSession[] = [];

            try {
              for await (const entry of Deno.readDir(handoverDir)) {
                if (!entry.isDirectory) continue;
                const sessionPath = `${handoverDir}/${entry.name}`;
                let hasHandover = false;
                let hasProjectState = false;
                let status = "UNKNOWN";
                let generatedAt: string | null = null;
                const taskSummary = { done: 0, in_progress: 0, blocked: 0 };
                try {
                  await Deno.stat(`${sessionPath}/handover.md`);
                  hasHandover = true;
                } catch { /* */ }
                try {
                  const raw = await Deno.readTextFile(
                    `${sessionPath}/project-state.json`,
                  );
                  hasProjectState = true;
                  const ps = JSON.parse(raw);
                  status = ps.status ?? "UNKNOWN";
                  generatedAt = ps.generated_at ?? null;
                  if (Array.isArray(ps.active_tasks)) {
                    for (const t of ps.active_tasks) {
                      if (t.status === "done") taskSummary.done++;
                      else if (t.status === "in_progress") {
                        taskSummary.in_progress++;
                      } else if (t.status === "blocked") taskSummary.blocked++;
                    }
                  }
                } catch { /* */ }
                sessions.push({
                  fingerprint: entry.name,
                  path: sessionPath,
                  hasHandover,
                  hasProjectState,
                  status,
                  generatedAt,
                  taskSummary,
                });
              }
            } catch {
              showToast("No handover data found", theme.coral);
              return;
            }

            sessions.sort((a, b) => b.fingerprint.localeCompare(a.fingerprint));
            setHandoverSessions(sessions);
            setHandoverIndex(0);
            setExpandedFingerprint(null);
            setExpandedContent(null);
            setRightPane("handover");
          } catch (e) {
            showToast(
              `Handover error: ${e instanceof Error ? e.message : String(e)}`,
              theme.coral,
            );
          }
        })();
        return;
      }

      // Sessions dashboard
      if (input === "S" && onSessions) {
        onSessions();
        return;
      }

      // Search
      if (input === "/") {
        setMode("searching");
        return;
      }

      // Git pull
      if (input === "P") {
        const gitSync = new GitSyncService(dataDir);
        gitSync.pull().then((r) => {
          showToast(
            r.pulled ? "Pulled" : `Pull: ${r.error}`,
            r.pulled ? theme.sage : theme.coral,
          );
          if (r.pulled) loadTasks();
        });
        return;
      }

      // Git push
      if (input === "U") {
        const gitSync = new GitSyncService(dataDir);
        gitSync.commitAndPush("kanban: auto-sync").then((r) => {
          showToast(
            r.pushed
              ? "Pushed"
              : (r.committed
                ? "Committed locally"
                : r.error ?? "Nothing to push"),
            r.pushed ? theme.sage : theme.amber,
          );
        });
        return;
      }

      // Quick-jump to status group (1-5)
      const jumpStatus = STATUS_JUMP[input];
      if (jumpStatus) {
        const groupTasks = grouped.get(jumpStatus);
        if (groupTasks && groupTasks.length > 0) {
          setSelectedTaskId(groupTasks[0].id);
        } else {
          showToast(
            `No tasks in ${jumpStatus.replace("_", " ")}`,
            theme.textMuted,
          );
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
        {syncDirty !== null && (
          <Text color={syncDirty ? theme.amber : theme.textDim}>
            {` ${syncDirty ? "\u25C6" : "\u25C7"} sync`}
          </Text>
        )}
      </Box>

      {/* Summary Bar */}
      <SummaryBar
        tasks={filteredTasks}
        focusedStatus={focusedStatus}
        activeFilterCount={activeFilterCount}
      />

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
            collapsed={collapsed}
            onToggleCollapse={onToggleCollapse}
            isActive={mode === "normal"}
          />
        </Box>

        {/* Right pane: TaskDetail, TaskEditor, or HandoverBrowser */}
        {showDetail && (
          <Box flexGrow={1} flexDirection="column">
            {rightPane === "handover"
              ? (
                <HandoverBrowser
                  sessions={handoverSessions}
                  selectedIndex={handoverIndex}
                  expandedFingerprint={expandedFingerprint}
                  expandedContent={expandedContent}
                  onNavigate={(delta) =>
                    setHandoverIndex((i) =>
                      Math.min(
                        Math.max(0, i + delta),
                        handoverSessions.length - 1,
                      )
                    )}
                  onToggleExpand={async () => {
                    const session = handoverSessions[handoverIndex];
                    if (!session) return;
                    if (expandedFingerprint === session.fingerprint) {
                      setExpandedFingerprint(null);
                      setExpandedContent(null);
                    } else {
                      try {
                        let handover: string | null = null;
                        try {
                          handover = await Deno.readTextFile(
                            `${session.path}/handover.md`,
                          );
                        } catch { /* */ }
                        let projectState: unknown = null;
                        try {
                          projectState = JSON.parse(
                            await Deno.readTextFile(
                              `${session.path}/project-state.json`,
                            ),
                          );
                        } catch { /* */ }
                        setExpandedFingerprint(session.fingerprint);
                        setExpandedContent({
                          handover,
                          projectState,
                          fingerprint: session.fingerprint,
                        });
                      } catch { /* */ }
                    }
                  }}
                  onClose={() => setRightPane("detail")}
                />
              )
              : mode === "editing" && selectedTask
              ? (
                <TaskEditor
                  task={selectedTask}
                  onActiveFieldType={setEditorFieldType}
                  selectClickIndex={selectClickIndex}
                  onSave={handleEditSave}
                  onCancel={handleEditCancel}
                />
              )
              : mode === "adding"
              ? (
                <TaskEditor
                  task={{
                    id: "",
                    title: "",
                    description: "",
                    status: "backlog",
                    priority: "medium",
                    labels: [],
                    createdAt: "",
                    updatedAt: "",
                  }}
                  isNew
                  onActiveFieldType={setEditorFieldType}
                  selectClickIndex={selectClickIndex}
                  onSave={handleAddSave}
                  onCancel={() => setMode("normal")}
                />
              )
              : <TaskDetail task={selectedTask} />}
          </Box>
        )}
      </Box>

      {/* Modal overlays */}
      {mode === "adding" && !showDetail && (
        <TaskEditor
          task={{
            id: "",
            title: "",
            description: "",
            status: "backlog",
            priority: "medium",
            labels: [],
            createdAt: "",
            updatedAt: "",
          }}
          isNew
          onActiveFieldType={setEditorFieldType}
          selectClickIndex={selectClickIndex}
          onSave={handleAddSave}
          onCancel={() => setMode("normal")}
        />
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

      {mode === "filtering" && (
        <FilterOverlay
          currentFilter={filter}
          availableLabels={[
            ...new Set(tasks.flatMap((t) => t.labels)),
          ]}
          onApply={(f) => {
            setFilter(f);
            setMode("normal");
          }}
          onCancel={() => setMode("normal")}
        />
      )}

      {mode === "launching" && selectedTask && (
        <LaunchMenu
          task={selectedTask}
          projectPath={Deno.cwd()}
          onLaunch={(result) => {
            showToast(
              result.status === "launched"
                ? "Launched!"
                : `Error: ${result.error}`,
              result.status === "launched" ? theme.sage : theme.coral,
            );
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
