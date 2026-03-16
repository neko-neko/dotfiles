// src/tui/views/board-select.tsx — Board selection / management screen
// Auto-detects board from cwd, otherwise shows a Select list.
// Supports board creation (c), deletion (d), with progress bars.
// Prerequisite: @inkjs/ui ^2 (Select, TextInput, ConfirmInput), react ^18, ink ^5
import { useCallback, useEffect, useState } from "react";
import { Box, Text, useInput } from "ink";
import { ConfirmInput, Select, TextInput } from "@inkjs/ui";
import type { Board } from "../../types.ts";
import { loadBoardTasks } from "../hooks/use-board.ts";
import { JsonFileBoardRepository } from "../../repositories/mod.ts";
import { theme } from "../theme.ts";

interface BoardSelectProps {
  dataDir: string;
  onSelect: (boardId: string) => void;
}

type SubMode = "list" | "creating" | "deleting";
type CreateField = "name" | "id" | "path";

const CREATE_FIELDS: CreateField[] = ["name", "id", "path"];

interface BoardWithCounts extends Board {
  counts: Record<string, number>;
  total: number;
}

/** Renders a simple text-based progress bar for task counts per status. */
function ProgressBar(
  { counts, total }: { counts: Record<string, number>; total: number },
) {
  if (total === 0) {
    return <Text color={theme.textDim}>no tasks</Text>;
  }

  const segments: { char: string; color: string }[] = [];
  const statusConfig: { key: string; color: string }[] = [
    { key: "done", color: theme.sage },
    { key: "review", color: theme.violet },
    { key: "in_progress", color: theme.amber },
    { key: "todo", color: theme.sky },
    { key: "backlog", color: theme.textMuted },
  ];

  const barWidth = 20;
  for (const { key, color } of statusConfig) {
    const count = counts[key] ?? 0;
    if (count > 0) {
      const width = Math.max(1, Math.round((count / total) * barWidth));
      for (let i = 0; i < width; i++) {
        segments.push({ char: "\u2588", color });
      }
    }
  }

  // Trim or pad to barWidth
  while (segments.length > barWidth) segments.pop();
  while (segments.length < barWidth) {
    segments.push({ char: "\u2591", color: theme.textDim });
  }

  return (
    <Text>
      {segments.map((s, i) => <Text key={i} color={s.color}>{s.char}</Text>)}
      <Text color={theme.textMuted}>{total}</Text>
    </Text>
  );
}

export function BoardSelect({ dataDir, onSelect }: BoardSelectProps) {
  const [boards, setBoards] = useState<BoardWithCounts[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [subMode, setSubMode] = useState<SubMode>("list");
  const [toast, setToast] = useState<
    { message: string; color: string } | null
  >(null);

  // Create form state
  const [createField, setCreateField] = useState(0);
  const [createName, setCreateName] = useState("");
  const [createId, setCreateId] = useState("");
  const [createPath, setCreatePath] = useState("");

  // Delete state
  const [deleteTarget, setDeleteTarget] = useState<string | null>(null);

  const showToast = useCallback(
    (message: string, color: string = theme.sage) => {
      setToast({ message, color });
      setTimeout(() => setToast(null), 3000);
    },
    [],
  );

  const loadBoards = useCallback(async () => {
    try {
      const repo = new JsonFileBoardRepository(dataDir);
      const list = await repo.listBoards();

      // Load task counts for each board
      const withCounts: BoardWithCounts[] = await Promise.all(
        list.map(async (board) => {
          try {
            const tasks = await loadBoardTasks(dataDir, board.id);
            const counts: Record<string, number> = {};
            for (const task of tasks) {
              counts[task.status] = (counts[task.status] ?? 0) + 1;
            }
            return { ...board, counts, total: tasks.length };
          } catch {
            return { ...board, counts: {}, total: 0 };
          }
        }),
      );

      setBoards(withCounts);
      setLoading(false);

      // Auto-detect: if cwd matches a board's path, select it immediately
      const cwd = Deno.cwd();
      const match = list.find((b) =>
        cwd === b.path || cwd.startsWith(b.path + "/")
      );
      if (match) {
        onSelect(match.id);
      }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg);
      setLoading(false);
    }
  }, [dataDir, onSelect]);

  useEffect(() => {
    loadBoards();
  }, [loadBoards]);

  // Keybinds for list mode
  useInput(
    (input, _key) => {
      if (input === "c") {
        setSubMode("creating");
        setCreateField(0);
        setCreateName("");
        setCreateId("");
        setCreatePath(Deno.cwd());
        return;
      }
      if (input === "d" && boards.length > 0) {
        setDeleteTarget(null);
        setSubMode("deleting");
        return;
      }
    },
    { isActive: subMode === "list" },
  );

  // Create form navigation
  useInput(
    (_input, key) => {
      if (key.escape) {
        setSubMode("list");
        return;
      }

      if (key.tab) {
        setCreateField((prev) => {
          if (key.shift) {
            return prev > 0 ? prev - 1 : CREATE_FIELDS.length - 1;
          }
          return prev < CREATE_FIELDS.length - 1 ? prev + 1 : 0;
        });
        return;
      }

      if (key.return) {
        // Submit create form
        const trimmedName = createName.trim();
        const trimmedId = createId.trim();
        const trimmedPath = createPath.trim();

        if (!trimmedName || !trimmedId || !trimmedPath) {
          showToast("All fields are required", theme.coral);
          return;
        }

        if (
          trimmedId.includes("/") || trimmedId.includes("\\") ||
          trimmedId.includes("..")
        ) {
          showToast("Invalid board ID", theme.coral);
          return;
        }

        const repo = new JsonFileBoardRepository(dataDir);
        repo.createBoard({
          id: trimmedId,
          name: trimmedName,
          path: trimmedPath,
        })
          .then(() => {
            showToast(`Board '${trimmedName}' created`, theme.sage);
            setSubMode("list");
            loadBoards();
          })
          .catch((err: unknown) => {
            const msg = err instanceof Error ? err.message : String(err);
            showToast(`Error: ${msg}`, theme.coral);
          });
        return;
      }
    },
    { isActive: subMode === "creating" },
  );

  // Delete mode — escape to cancel
  useInput(
    (_input, key) => {
      if (key.escape) {
        setSubMode("list");
        return;
      }
    },
    { isActive: subMode === "deleting" },
  );

  const handleDeleteConfirm = useCallback(() => {
    if (!deleteTarget) {
      setSubMode("list");
      return;
    }
    const repo = new JsonFileBoardRepository(dataDir);
    repo.deleteBoard(deleteTarget)
      .then(() => {
        showToast(`Board deleted`, theme.sage);
        setSubMode("list");
        loadBoards();
      })
      .catch((err: unknown) => {
        const msg = err instanceof Error ? err.message : String(err);
        showToast(`Error: ${msg}`, theme.coral);
      });
  }, [deleteTarget, dataDir, showToast, loadBoards]);

  if (loading) {
    return (
      <Box paddingX={1} paddingY={1}>
        <Text color={theme.textMuted}>Loading boards...</Text>
      </Box>
    );
  }

  if (error) {
    return (
      <Box paddingX={1} paddingY={1}>
        <Text color={theme.coral}>
          <Text bold>Error:</Text> {error}
        </Text>
      </Box>
    );
  }

  // --- Create form ---
  if (subMode === "creating") {
    const currentFieldName = CREATE_FIELDS[createField];
    return (
      <Box flexDirection="column" paddingX={1} paddingY={1}>
        <Box marginBottom={1}>
          <Text color={theme.amber} bold>
            New Board
          </Text>
          <Text color={theme.textDim}>
            {" \u2500\u2500 Tab: next field, Enter: create, Esc: cancel"}
          </Text>
        </Box>

        <Box flexDirection="row" gap={1}>
          <Text
            color={createField === 0 ? theme.amber : theme.textMuted}
            bold={createField === 0}
          >
            Name:
          </Text>
          {createField === 0
            ? (
              <TextInput
                defaultValue={createName}
                placeholder="My Project"
                onChange={setCreateName}
              />
            )
            : <Text color={theme.text}>{createName || "..."}</Text>}
        </Box>

        <Box flexDirection="row" gap={1}>
          <Text
            color={createField === 1 ? theme.amber : theme.textMuted}
            bold={createField === 1}
          >
            ID:
          </Text>
          {createField === 1
            ? (
              <TextInput
                defaultValue={createId}
                placeholder="my-project"
                onChange={setCreateId}
              />
            )
            : <Text color={theme.text}>{createId || "..."}</Text>}
        </Box>

        <Box flexDirection="row" gap={1}>
          <Text
            color={createField === 2 ? theme.amber : theme.textMuted}
            bold={createField === 2}
          >
            Path:
          </Text>
          {createField === 2
            ? (
              <TextInput
                defaultValue={createPath}
                placeholder="/path/to/project"
                onChange={setCreatePath}
              />
            )
            : <Text color={theme.text}>{createPath || "..."}</Text>}
        </Box>

        <Box marginTop={1}>
          <Text color={theme.textDim}>
            [{createField + 1}/{CREATE_FIELDS.length}] {currentFieldName}
          </Text>
        </Box>
      </Box>
    );
  }

  // --- Delete mode ---
  if (subMode === "deleting") {
    if (!deleteTarget) {
      // Show board selector for deletion target
      const options = boards.map((b) => ({
        label: `${b.name}  ${b.path}`,
        value: b.id,
      }));
      return (
        <Box flexDirection="column" paddingX={1} paddingY={1}>
          <Box marginBottom={1}>
            <Text color={theme.coral} bold>
              Delete Board
            </Text>
            <Text color={theme.textDim}>
              {" \u2500\u2500 Select board to delete, Esc: cancel"}
            </Text>
          </Box>
          <Select
            options={options}
            onChange={(value) => setDeleteTarget(value)}
          />
        </Box>
      );
    }

    const targetBoard = boards.find((b) => b.id === deleteTarget);
    return (
      <Box flexDirection="column" paddingX={1} paddingY={1}>
        <Box flexDirection="row" gap={1}>
          <Text color={theme.coral} bold>
            Delete &apos;{targetBoard?.name ?? deleteTarget}&apos;?
          </Text>
          <ConfirmInput
            defaultChoice="cancel"
            onConfirm={handleDeleteConfirm}
            onCancel={() => setSubMode("list")}
          />
        </Box>
      </Box>
    );
  }

  // --- List mode ---
  if (boards.length === 0) {
    return (
      <Box paddingX={1} paddingY={1} flexDirection="column">
        <Box marginBottom={1}>
          <Text color={theme.amber} bold>
            kanban
          </Text>
        </Box>
        <Text color={theme.textMuted}>
          No boards found. Press [c] to create one.
        </Text>
        {toast && (
          <Box paddingX={0} marginTop={1}>
            <Text color={toast.color}>{toast.message}</Text>
          </Box>
        )}
        <Box marginTop={1} gap={1}>
          <Box>
            <Text color={theme.amber}>[c]</Text>
            <Text color={theme.textMuted}>create</Text>
          </Box>
        </Box>
      </Box>
    );
  }

  const options = boards.map((b) => ({
    label: `${b.name}  ${b.path}`,
    value: b.id,
  }));

  return (
    <Box flexDirection="column" paddingX={1} paddingY={1}>
      <Box marginBottom={1}>
        <Text color={theme.amber} bold>
          kanban
        </Text>
        <Text color={theme.textDim}>{`\u2500\u2500 Select a board`}</Text>
      </Box>

      {/* Board list with progress bars */}
      {boards.map((board) => (
        <Box key={board.id} flexDirection="row" gap={2} paddingX={1}>
          <Box width={24}>
            <Text color={theme.text}>{board.name}</Text>
          </Box>
          <ProgressBar counts={board.counts} total={board.total} />
        </Box>
      ))}

      <Box marginTop={1}>
        <Select options={options} onChange={(value) => onSelect(value)} />
      </Box>

      {toast && (
        <Box paddingX={0}>
          <Text color={toast.color}>{toast.message}</Text>
        </Box>
      )}

      {/* Keybind hints */}
      <Box marginTop={1} gap={1}>
        <Box>
          <Text color={theme.amber}>[c]</Text>
          <Text color={theme.textMuted}>create</Text>
        </Box>
        <Box>
          <Text color={theme.amber}>[d]</Text>
          <Text color={theme.textMuted}>delete</Text>
        </Box>
      </Box>
    </Box>
  );
}
