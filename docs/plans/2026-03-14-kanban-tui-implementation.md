# Kanban TUI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 既存の kanban サーバーのリポジトリ層を直接利用して、Ink ベースのフルスクリーン TUI クライアントを構築する

**Architecture:** Split Pane (左: タスクツリー、右: 詳細パネル) + ステータスサマリーバー。fullscreen-ink で alternate screen buffer 管理。リポジトリ層を直接 import し、サーバー不要で動作。Deno.watchFs でファイル変更を監視し外部変更を即座に反映。

**Tech Stack:** Deno, npm:ink, npm:@inkjs/ui, npm:fullscreen-ink, npm:react, 既存の JsonFileBoardRepository / JsonFileTaskRepository

**Design Doc:** `docs/plans/2026-03-14-kanban-tui-design.md`

---

### Task 1: Deno + Ink 最小動作確認

**Files:**
- Create: `~/.claude/tools/kanban-server/cli.ts`
- Modify: `~/.claude/tools/kanban-server/deno.json`

**Step 1: deno.json に TUI 用タスクと依存を追加**

`deno.json` に以下を追加:

```jsonc
{
  "tasks": {
    // 既存の dev, start, test はそのまま
    "tui": "deno run --allow-read --allow-write --allow-env --allow-run cli.ts",
    "tui:dev": "deno run --allow-read --allow-write --allow-env --allow-run --watch cli.ts"
  },
  "imports": {
    // 既存の @hono/hono, @std/* はそのまま
    "ink": "npm:ink@^5",
    "ink/ui": "npm:@inkjs/ui@^2",
    "fullscreen-ink": "npm:fullscreen-ink@^1",
    "react": "npm:react@^18",
    "react/jsx-runtime": "npm:react/jsx-runtime"
  },
  "compilerOptions": {
    "jsx": "react-jsx",
    "jsxImportSource": "react"
  }
}
```

**Step 2: 最小 cli.ts を作成**

```tsx
// cli.ts
// 前提: Deno 2+, npm:ink@5, npm:fullscreen-ink@1, npm:react@18
// 目的: Deno + Ink + fullscreen-ink の最小動作確認
import { withFullScreen, useScreenSize } from "fullscreen-ink";
import { Box, Text, useApp, useInput } from "ink";
import React from "react";

function App() {
  const { exit } = useApp();
  const { width, height } = useScreenSize();

  useInput((input, key) => {
    if (input === "q" || (input === "c" && key.ctrl)) {
      exit();
    }
  });

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor="#D4A574"
      width={width}
      height={height}
    >
      <Text color="#D4A574" bold>
        kanban TUI — {width}x{height}
      </Text>
      <Text color="#6B6560">Press q to quit</Text>
    </Box>
  );
}

async function main() {
  const ink = withFullScreen(<App />);
  await ink.start();
  await ink.waitUntilExit();
}

main();
```

**Step 3: 動作確認**

Run: `cd ~/.claude/tools/kanban-server && deno task tui`
Expected: フルスクリーンで amber ボーダーのボックスが表示、`q` で終了、元の画面に復帰

**Step 4: 問題があれば修正**

Deno + npm:ink の互換性問題が出た場合:
- `--node-modules-dir` フラグを試す
- `nodeModulesDir: true` を deno.json に追加
- JSX 設定で `"jsxFactory": "React.createElement"` を試す

**Step 5: コミット**

```bash
git add cli.ts deno.json
git commit -m "feat(tui): add minimal Ink + fullscreen-ink scaffold on Deno"
```

---

### Task 2: テーマ定義

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/theme.ts`
- Test: `~/.claude/tools/kanban-server/src/tui/theme_test.ts`

**Step 1: failing test を書く**

```typescript
// src/tui/theme_test.ts
import { assertEquals, assertMatch } from "@std/assert";
import { theme, statusColor, priorityIcon, statusIcon } from "./theme.ts";

Deno.test("theme has all required color keys", () => {
  const required = [
    "bg", "surface", "surfaceHover",
    "text", "textMuted", "textDim",
    "amber", "sage", "coral", "sky", "violet", "rose",
    "border", "borderActive",
  ];
  for (const key of required) {
    assertEquals(typeof (theme as Record<string, string>)[key], "string", `missing: ${key}`);
  }
});

Deno.test("theme colors are valid hex", () => {
  for (const [key, value] of Object.entries(theme)) {
    assertMatch(value, /^#[0-9A-Fa-f]{6}$/, `invalid hex for ${key}: ${value}`);
  }
});

Deno.test("statusColor returns correct color for each status", () => {
  assertEquals(statusColor("in_progress"), theme.amber);
  assertEquals(statusColor("todo"), theme.sky);
  assertEquals(statusColor("done"), theme.sage);
  assertEquals(statusColor("review"), theme.violet);
  assertEquals(statusColor("backlog"), theme.textMuted);
});

Deno.test("priorityIcon returns icon with correct format", () => {
  assertEquals(priorityIcon("high"), "●");
  assertEquals(priorityIcon("medium"), "◐");
  assertEquals(priorityIcon("low"), "○");
});

Deno.test("statusIcon returns icon for each status", () => {
  assertEquals(statusIcon("in_progress"), "▶");
  assertEquals(statusIcon("todo"), "○");
  assertEquals(statusIcon("done"), "✓");
  assertEquals(statusIcon("review"), "◎");
  assertEquals(statusIcon("backlog"), "◆");
});
```

**Step 2: test が失敗することを確認**

Run: `deno test src/tui/theme_test.ts`
Expected: FAIL — module not found

**Step 3: 実装**

```typescript
// src/tui/theme.ts
import type { TaskStatus, Priority } from "../types.ts";

export const theme = {
  // Surfaces
  bg:           "#0D0D0D",
  surface:      "#1A1A1A",
  surfaceHover: "#242424",

  // Text
  text:         "#E8E4D9",
  textMuted:    "#6B6560",
  textDim:      "#3D3A36",

  // Accents
  amber:        "#D4A574",
  sage:         "#7D9B76",
  coral:        "#C47A6C",
  sky:          "#6B9BC3",
  violet:       "#9B8EC4",
  rose:         "#B5727E",

  // Borders
  border:       "#2A2725",
  borderActive: "#D4A574",
} as const;

const STATUS_COLORS: Record<TaskStatus, string> = {
  in_progress: theme.amber,
  todo:        theme.sky,
  done:        theme.sage,
  review:      theme.violet,
  backlog:     theme.textMuted,
};

const PRIORITY_ICONS: Record<Priority, string> = {
  high:   "●",
  medium: "◐",
  low:    "○",
};

const STATUS_ICONS: Record<TaskStatus, string> = {
  in_progress: "▶",
  todo:        "○",
  done:        "✓",
  review:      "◎",
  backlog:     "◆",
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
```

**Step 4: テスト pass を確認**

Run: `deno test src/tui/theme_test.ts`
Expected: 5 tests PASS

**Step 5: コミット**

```bash
git add src/tui/theme.ts src/tui/theme_test.ts
git commit -m "feat(tui): add Terminal Luxe theme with status/priority helpers"
```

---

### Task 3: useBoard hook — リポジトリ直接アクセス

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/hooks/use-board.ts`
- Test: `~/.claude/tools/kanban-server/src/tui/hooks/use-board_test.ts`

**Step 1: failing test を書く**

```typescript
// src/tui/hooks/use-board_test.ts
import { assertEquals } from "@std/assert";
import { JsonFileBoardRepository } from "../../repositories/json-file-board-repository.ts";
import { JsonFileTaskRepository } from "../../repositories/json-file-task-repository.ts";
import type { Board, Task, BoardData, BoardsIndex } from "../../types.ts";

// リポジトリ層の統合テスト（hook のロジック部分を関数として抽出してテスト）
// Ink の React hook は deno test で直接テストしにくいため、
// データ取得ロジックを純粋関数に分離してテストする

import { loadBoardData, groupTasksByStatus } from "../use-board.ts";

Deno.test("groupTasksByStatus groups tasks correctly", () => {
  const tasks: Task[] = [
    { id: "t-1", title: "A", description: "", status: "todo", priority: "high", labels: [], createdAt: "", updatedAt: "" },
    { id: "t-2", title: "B", description: "", status: "todo", priority: "low", labels: [], createdAt: "", updatedAt: "" },
    { id: "t-3", title: "C", description: "", status: "done", priority: "medium", labels: [], createdAt: "", updatedAt: "" },
  ];

  const grouped = groupTasksByStatus(tasks);

  assertEquals(grouped.get("todo")?.length, 2);
  assertEquals(grouped.get("done")?.length, 1);
  assertEquals(grouped.get("in_progress")?.length, undefined);
});

Deno.test("groupTasksByStatus sorts high priority first within group", () => {
  const tasks: Task[] = [
    { id: "t-1", title: "Low", description: "", status: "todo", priority: "low", labels: [], createdAt: "", updatedAt: "" },
    { id: "t-2", title: "High", description: "", status: "todo", priority: "high", labels: [], createdAt: "", updatedAt: "" },
    { id: "t-3", title: "Med", description: "", status: "todo", priority: "medium", labels: [], createdAt: "", updatedAt: "" },
  ];

  const grouped = groupTasksByStatus(tasks);
  const todoTasks = grouped.get("todo")!;

  assertEquals(todoTasks[0].priority, "high");
  assertEquals(todoTasks[1].priority, "medium");
  assertEquals(todoTasks[2].priority, "low");
});

Deno.test("loadBoardData reads tasks from temp directory", async () => {
  const tmpDir = await Deno.makeTempDir();
  const boardsDir = `${tmpDir}/boards`;
  await Deno.mkdir(boardsDir, { recursive: true });

  // boards.json
  const index: BoardsIndex = {
    version: 1,
    boards: [{ id: "test", name: "Test", path: "/tmp/test", createdAt: "", updatedAt: "" }],
  };
  await Deno.writeTextFile(`${tmpDir}/boards.json`, JSON.stringify(index));

  // board data
  const boardData: BoardData = {
    version: 1,
    boardId: "test",
    columns: ["backlog", "todo", "in_progress", "review", "done"],
    tasks: [
      { id: "t-1", title: "Task 1", description: "desc", status: "todo", priority: "high", labels: ["test"], createdAt: "2026-03-14", updatedAt: "2026-03-14" },
    ],
  };
  await Deno.writeTextFile(`${boardsDir}/test.json`, JSON.stringify(boardData));

  const result = await loadBoardData(tmpDir, "test");

  assertEquals(result.tasks.length, 1);
  assertEquals(result.tasks[0].title, "Task 1");

  await Deno.remove(tmpDir, { recursive: true });
});
```

**Step 2: test が失敗することを確認**

Run: `deno test src/tui/hooks/use-board_test.ts --allow-read --allow-write`
Expected: FAIL — module not found

**Step 3: 実装 — 純粋関数部分**

```typescript
// src/tui/hooks/use-board.ts
import type { Task, TaskStatus, BoardData, Priority } from "../../types.ts";
import { JsonFileTaskRepository } from "../../repositories/json-file-task-repository.ts";

const PRIORITY_ORDER: Record<Priority, number> = {
  high: 0,
  medium: 1,
  low: 2,
};

const STATUS_ORDER: TaskStatus[] = [
  "in_progress", "todo", "backlog", "review", "done"
];

export function groupTasksByStatus(
  tasks: Task[]
): Map<TaskStatus, Task[]> {
  const grouped = new Map<TaskStatus, Task[]>();

  for (const task of tasks) {
    const list = grouped.get(task.status) ?? [];
    list.push(task);
    grouped.set(task.status, list);
  }

  // Sort each group by priority (high first)
  for (const [_status, list] of grouped) {
    list.sort((a, b) => PRIORITY_ORDER[a.priority] - PRIORITY_ORDER[b.priority]);
  }

  return grouped;
}

export async function loadBoardData(
  dataDir: string,
  boardId: string
): Promise<BoardData> {
  const path = `${dataDir}/boards/${boardId}.json`;
  const text = await Deno.readTextFile(path);
  return JSON.parse(text) as BoardData;
}

export { STATUS_ORDER };
```

**Step 4: テスト pass を確認**

Run: `deno test src/tui/hooks/use-board_test.ts --allow-read --allow-write`
Expected: 3 tests PASS

**Step 5: コミット**

```bash
git add src/tui/hooks/use-board.ts src/tui/hooks/use-board_test.ts
git commit -m "feat(tui): add useBoard data helpers with grouping and priority sort"
```

---

### Task 4: useTaskActions hook — CRUD 操作

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/hooks/use-task-actions.ts`
- Test: `~/.claude/tools/kanban-server/src/tui/hooks/use-task-actions_test.ts`

**Step 1: failing test を書く**

```typescript
// src/tui/hooks/use-task-actions_test.ts
import { assertEquals, assertRejects } from "@std/assert";
import { TaskActions } from "./use-task-actions.ts";
import { JsonFileTaskRepository } from "../../repositories/json-file-task-repository.ts";
import type { BoardData, BoardsIndex } from "../../types.ts";

async function setupTempBoard(): Promise<{ dir: string; cleanup: () => Promise<void> }> {
  const dir = await Deno.makeTempDir();
  const boardsDir = `${dir}/boards`;
  await Deno.mkdir(boardsDir, { recursive: true });

  const index: BoardsIndex = {
    version: 1,
    boards: [{ id: "test", name: "Test", path: "/tmp", createdAt: "", updatedAt: "" }],
  };
  await Deno.writeTextFile(`${dir}/boards.json`, JSON.stringify(index));

  const boardData: BoardData = {
    version: 1,
    boardId: "test",
    columns: ["backlog", "todo", "in_progress", "review", "done"],
    tasks: [],
  };
  await Deno.writeTextFile(`${boardsDir}/test.json`, JSON.stringify(boardData));

  return { dir, cleanup: () => Deno.remove(dir, { recursive: true }) };
}

Deno.test("TaskActions.createTask adds a task", async () => {
  const { dir, cleanup } = await setupTempBoard();
  try {
    const repo = new JsonFileTaskRepository(dir);
    const actions = new TaskActions(repo, "test");

    const task = await actions.createTask("New Task");
    assertEquals(task.title, "New Task");
    assertEquals(task.status, "backlog");
    assertEquals(task.priority, "medium");

    const tasks = await repo.listTasks("test");
    assertEquals(tasks.length, 1);
  } finally {
    await cleanup();
  }
});

Deno.test("TaskActions.moveTask changes status", async () => {
  const { dir, cleanup } = await setupTempBoard();
  try {
    const repo = new JsonFileTaskRepository(dir);
    const actions = new TaskActions(repo, "test");

    const task = await actions.createTask("Move Me");
    const moved = await actions.moveTask(task.id, "in_progress");
    assertEquals(moved.status, "in_progress");
  } finally {
    await cleanup();
  }
});

Deno.test("TaskActions.deleteTask removes a task", async () => {
  const { dir, cleanup } = await setupTempBoard();
  try {
    const repo = new JsonFileTaskRepository(dir);
    const actions = new TaskActions(repo, "test");

    const task = await actions.createTask("Delete Me");
    await actions.deleteTask(task.id);

    const tasks = await repo.listTasks("test");
    assertEquals(tasks.length, 0);
  } finally {
    await cleanup();
  }
});

Deno.test("TaskActions.updateTask modifies fields", async () => {
  const { dir, cleanup } = await setupTempBoard();
  try {
    const repo = new JsonFileTaskRepository(dir);
    const actions = new TaskActions(repo, "test");

    const task = await actions.createTask("Edit Me");
    const updated = await actions.updateTask(task.id, {
      title: "Edited",
      priority: "high",
      labels: ["urgent"],
    });
    assertEquals(updated.title, "Edited");
    assertEquals(updated.priority, "high");
    assertEquals(updated.labels, ["urgent"]);
  } finally {
    await cleanup();
  }
});
```

**Step 2: test が失敗することを確認**

Run: `deno test src/tui/hooks/use-task-actions_test.ts --allow-read --allow-write`
Expected: FAIL — module not found

**Step 3: 実装**

```typescript
// src/tui/hooks/use-task-actions.ts
import type { Task, TaskStatus, UpdateTaskInput } from "../../types.ts";
import type { TaskRepository } from "../../repositories/task-repository.ts";

export class TaskActions {
  constructor(
    private readonly repo: TaskRepository,
    private readonly boardId: string,
  ) {}

  async createTask(title: string): Promise<Task> {
    return await this.repo.createTask(this.boardId, { title });
  }

  async moveTask(taskId: string, status: TaskStatus): Promise<Task> {
    const moved = await this.repo.moveTasks(this.boardId, [
      { taskId, status },
    ]);
    return moved[0];
  }

  async deleteTask(taskId: string): Promise<void> {
    await this.repo.deleteTask(this.boardId, taskId);
  }

  async updateTask(
    taskId: string,
    input: Omit<UpdateTaskInput, "expectedVersion">,
  ): Promise<Task> {
    return await this.repo.updateTask(this.boardId, taskId, input);
  }

  async listTasks(): Promise<Task[]> {
    return await this.repo.listTasks(this.boardId);
  }
}
```

**Step 4: テスト pass を確認**

Run: `deno test src/tui/hooks/use-task-actions_test.ts --allow-read --allow-write`
Expected: 4 tests PASS

**Step 5: コミット**

```bash
git add src/tui/hooks/use-task-actions.ts src/tui/hooks/use-task-actions_test.ts
git commit -m "feat(tui): add TaskActions class wrapping repository CRUD"
```

---

### Task 5: SummaryBar コンポーネント

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/components/summary-bar.tsx`

**Step 1: 実装**

```tsx
// src/tui/components/summary-bar.tsx
import React from "react";
import { Box, Text } from "ink";
import type { Task, TaskStatus } from "../../types.ts";
import { theme, statusColor } from "../theme.ts";

interface SummaryBarProps {
  tasks: Task[];
  focusedStatus?: TaskStatus;
}

const STATUSES: { key: TaskStatus; label: string; shortcut: string }[] = [
  { key: "backlog",     label: "backlog",  shortcut: "1" },
  { key: "todo",        label: "todo",     shortcut: "2" },
  { key: "in_progress", label: "active",   shortcut: "3" },
  { key: "review",      label: "review",   shortcut: "4" },
  { key: "done",        label: "done",     shortcut: "5" },
];

export function SummaryBar({ tasks, focusedStatus }: SummaryBarProps) {
  const counts = new Map<TaskStatus, number>();
  for (const task of tasks) {
    counts.set(task.status, (counts.get(task.status) ?? 0) + 1);
  }
  const total = tasks.length;

  return (
    <Box paddingX={1}>
      {STATUSES.map(({ key, label, shortcut }) => {
        const count = counts.get(key) ?? 0;
        const color = statusColor(key);
        const icon = key === focusedStatus ? "◇" : "◆";
        return (
          <Box key={key} marginRight={2}>
            <Text color={color}>
              {icon} {count} {label}
            </Text>
          </Box>
        );
      })}
      <Box flexGrow={1} />
      <Text color={theme.textMuted}>Σ {total}</Text>
    </Box>
  );
}
```

**Step 2: cli.ts に仮組み込みして目視確認**

cli.ts の `<App>` に `<SummaryBar>` をダミーデータで埋め込み、`deno task tui` で表示確認。

**Step 3: コミット**

```bash
git add src/tui/components/summary-bar.tsx
git commit -m "feat(tui): add SummaryBar component with status counts"
```

---

### Task 6: TaskTree コンポーネント（左ペイン）

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/components/task-tree.tsx`

**Step 1: 実装**

```tsx
// src/tui/components/task-tree.tsx
import React, { useState } from "react";
import { Box, Text, useFocus, useInput } from "ink";
import type { Task, TaskStatus } from "../../types.ts";
import { theme, statusColor, statusIcon, priorityIcon } from "../theme.ts";
import { STATUS_ORDER } from "../hooks/use-board.ts";

interface TaskTreeProps {
  groupedTasks: Map<TaskStatus, Task[]>;
  selectedTaskId: string | null;
  onSelectTask: (taskId: string) => void;
  onFocusRight: () => void;
}

export function TaskTree({
  groupedTasks,
  selectedTaskId,
  onSelectTask,
  onFocusRight,
}: TaskTreeProps) {
  const [collapsed, setCollapsed] = useState<Set<TaskStatus>>(new Set());
  const { isFocused } = useFocus({ autoFocus: true });

  // Flatten visible items for navigation
  const flatItems: { type: "group"; status: TaskStatus } | { type: "task"; task: Task }[] = [];
  for (const status of STATUS_ORDER) {
    const tasks = groupedTasks.get(status);
    if (!tasks || tasks.length === 0) continue;

    flatItems.push({ type: "group", status });
    if (!collapsed.has(status)) {
      for (const task of tasks) {
        flatItems.push({ type: "task", task });
      }
    }
  }

  // Find current index
  const currentIndex = flatItems.findIndex(
    (item) => item.type === "task" && item.task.id === selectedTaskId
  );

  useInput((input, key) => {
    if (!isFocused) return;

    if (input === "j" || key.downArrow) {
      // Move down to next task
      for (let i = (currentIndex < 0 ? 0 : currentIndex + 1); i < flatItems.length; i++) {
        const item = flatItems[i];
        if (item.type === "task") {
          onSelectTask(item.task.id);
          return;
        }
      }
    }

    if (input === "k" || key.upArrow) {
      // Move up to previous task
      for (let i = (currentIndex < 0 ? flatItems.length - 1 : currentIndex - 1); i >= 0; i--) {
        const item = flatItems[i];
        if (item.type === "task") {
          onSelectTask(item.task.id);
          return;
        }
      }
    }

    // J/K: jump between status groups
    if (input === "J") {
      const currentGroupIndex = currentIndex >= 0
        ? flatItems.findIndex((item, i) =>
            item.type === "group" &&
            i < currentIndex &&
            flatItems.slice(i + 1).some((fi) => fi.type === "task" && fi.task.id === selectedTaskId)
          )
        : -1;
      // Find next group with tasks
      for (let i = currentIndex + 1; i < flatItems.length; i++) {
        if (flatItems[i].type === "group") {
          // Select first task in this group
          for (let j = i + 1; j < flatItems.length; j++) {
            if (flatItems[j].type === "task") {
              onSelectTask(flatItems[j].task.id);
              return;
            }
            if (flatItems[j].type === "group") break;
          }
        }
      }
    }

    if (input === "K") {
      // Find previous group's first task
      let foundGroup = false;
      for (let i = currentIndex - 1; i >= 0; i--) {
        if (flatItems[i].type === "group") {
          if (foundGroup) {
            // Select first task after this group
            for (let j = i + 1; j < flatItems.length; j++) {
              if (flatItems[j].type === "task") {
                onSelectTask(flatItems[j].task.id);
                return;
              }
              if (flatItems[j].type === "group") break;
            }
          }
          foundGroup = true;
        }
      }
    }

    // o: toggle collapse
    if (input === "o") {
      // Find which group the current task belongs to
      for (let i = currentIndex; i >= 0; i--) {
        const item = flatItems[i];
        if (item.type === "group") {
          setCollapsed((prev) => {
            const next = new Set(prev);
            if (next.has(item.status)) {
              next.delete(item.status);
            } else {
              next.add(item.status);
            }
            return next;
          });
          return;
        }
      }
    }

    // l or Enter: focus right pane
    if (input === "l" || key.return) {
      onFocusRight();
    }
  });

  return (
    <Box flexDirection="column" flexGrow={1}>
      <Text bold color={theme.text}>
        TASKS
      </Text>
      <Box flexDirection="column" marginTop={1}>
        {flatItems.map((item, i) => {
          if (item.type === "group") {
            const count = groupedTasks.get(item.status)?.length ?? 0;
            const isCollapsed = collapsed.has(item.status);
            return (
              <Text key={`g-${item.status}`} color={statusColor(item.status)}>
                {isCollapsed ? "▸" : "▾"} {item.status.replace("_", " ")} ({count})
              </Text>
            );
          }

          const isSelected = item.task.id === selectedTaskId;
          const color = isSelected ? theme.text : theme.textMuted;
          const prefix = isSelected ? "▌" : " ";
          const bgColor = isSelected && isFocused ? theme.surfaceHover : undefined;

          return (
            <Box key={item.task.id} backgroundColor={bgColor}>
              <Text color={isSelected ? theme.amber : theme.textDim}>
                {prefix}
              </Text>
              <Text color={statusColor(item.task.status)}>
                {statusIcon(item.task.status)}{" "}
              </Text>
              <Text color={isSelected ? theme.coral : theme.textMuted}>
                {priorityIcon(item.task.priority)}{" "}
              </Text>
              <Text color={color}>{item.task.title}</Text>
            </Box>
          );
        })}
      </Box>
    </Box>
  );
}
```

**Step 2: 目視確認**

cli.ts に仮データで `<TaskTree>` を組み込み、`deno task tui` で `j/k` 移動、`o` 折りたたみ、`J/K` グループジャンプを確認。

**Step 3: コミット**

```bash
git add src/tui/components/task-tree.tsx
git commit -m "feat(tui): add TaskTree component with keyboard navigation"
```

---

### Task 7: TaskDetail コンポーネント（右ペイン）

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/components/task-detail.tsx`

**Step 1: 実装**

```tsx
// src/tui/components/task-detail.tsx
import React from "react";
import { Box, Text } from "ink";
import type { Task } from "../../types.ts";
import { theme, statusColor, priorityIcon, statusIcon } from "../theme.ts";

interface TaskDetailProps {
  task: Task | null;
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <Box>
      <Box width={12}>
        <Text color={theme.textMuted}>{label}</Text>
      </Box>
      {children}
    </Box>
  );
}

function timeSince(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  if (isNaN(then)) return dateStr;

  const diffMs = now - then;
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export function TaskDetail({ task }: TaskDetailProps) {
  if (!task) {
    return (
      <Box flexDirection="column" flexGrow={1} justifyContent="center" alignItems="center">
        <Text color={theme.textDim}>タスクを選択してください</Text>
      </Box>
    );
  }

  return (
    <Box flexDirection="column" flexGrow={1} paddingX={1}>
      <Box borderStyle="round" borderColor={theme.borderActive} paddingX={1} flexDirection="column">
        <Text bold color={theme.text}>{task.title}</Text>
      </Box>

      <Box flexDirection="column" marginTop={1} gap={0}>
        <Field label="Status">
          <Text color={statusColor(task.status)}>
            {statusIcon(task.status)} {task.status}
          </Text>
        </Field>

        <Field label="Priority">
          <Text color={task.priority === "high" ? theme.coral : task.priority === "medium" ? theme.rose : theme.textMuted}>
            {priorityIcon(task.priority)} {task.priority}
          </Text>
        </Field>

        <Field label="Labels">
          {task.labels.length > 0 ? (
            <Text color={theme.sky}>
              {task.labels.map((l) => `#${l}`).join(" ")}
            </Text>
          ) : (
            <Text color={theme.textDim}>—</Text>
          )}
        </Field>

        {task.worktree && (
          <Field label="Worktree">
            <Text color={theme.violet}>{task.worktree}</Text>
          </Field>
        )}

        <Field label="Updated">
          <Text color={theme.textMuted}>{timeSince(task.updatedAt)}</Text>
        </Field>
      </Box>

      {task.description && (
        <Box flexDirection="column" marginTop={1}>
          <Text color={theme.textDim}>── Description ──</Text>
          <Text color={theme.text}>{task.description}</Text>
        </Box>
      )}

      {task.sessionContext && (
        <Box flexDirection="column" marginTop={1}>
          <Text color={theme.textDim}>── Session ──</Text>
          {task.sessionContext.lastSessionId && (
            <Text color={theme.textMuted}>
              Last: {task.sessionContext.lastSessionId}
            </Text>
          )}
          {task.sessionContext.resumeHint && (
            <Text color={theme.textMuted}>
              Hint: {task.sessionContext.resumeHint}
            </Text>
          )}
        </Box>
      )}
    </Box>
  );
}
```

**Step 2: 目視確認**

**Step 3: コミット**

```bash
git add src/tui/components/task-detail.tsx
git commit -m "feat(tui): add TaskDetail component with field display"
```

---

### Task 8: KeybindBar コンポーネント

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/components/keybind-bar.tsx`

**Step 1: 実装**

```tsx
// src/tui/components/keybind-bar.tsx
import React from "react";
import { Box, Text } from "ink";
import { theme } from "../theme.ts";

interface KeyAction {
  key: string;
  label: string;
}

const ACTIONS: KeyAction[] = [
  { key: "a", label: "add" },
  { key: "m", label: "move" },
  { key: "e", label: "edit" },
  { key: "d", label: "delete" },
  { key: "s", label: "sync" },
  { key: "/", label: "search" },
  { key: "b", label: "boards" },
  { key: "q", label: "quit" },
];

export function KeybindBar() {
  return (
    <Box paddingX={1}>
      {ACTIONS.map(({ key, label }) => (
        <Box key={key} marginRight={1}>
          <Text color={theme.amber}>[{key}]</Text>
          <Text color={theme.textMuted}>{label}</Text>
        </Box>
      ))}
    </Box>
  );
}
```

**Step 2: コミット**

```bash
git add src/tui/components/keybind-bar.tsx
git commit -m "feat(tui): add KeybindBar component"
```

---

### Task 9: BoardView — Split Pane 統合

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/views/board-view.tsx`
- Modify: `~/.claude/tools/kanban-server/cli.ts`

**Step 1: BoardView を実装**

```tsx
// src/tui/views/board-view.tsx
import React, { useState, useEffect, useCallback } from "react";
import { Box, Text, useApp, useInput, useFocusManager } from "ink";
import { useScreenSize } from "fullscreen-ink";
import type { Task, TaskStatus } from "../../types.ts";
import { JsonFileTaskRepository } from "../../repositories/json-file-task-repository.ts";
import { TaskActions } from "../hooks/use-task-actions.ts";
import { groupTasksByStatus, loadBoardData } from "../hooks/use-board.ts";
import { theme } from "../theme.ts";
import { SummaryBar } from "../components/summary-bar.tsx";
import { TaskTree } from "../components/task-tree.tsx";
import { TaskDetail } from "../components/task-detail.tsx";
import { KeybindBar } from "../components/keybind-bar.tsx";

interface BoardViewProps {
  dataDir: string;
  boardId: string;
}

export function BoardView({ dataDir, boardId }: BoardViewProps) {
  const { exit } = useApp();
  const { width, height } = useScreenSize();
  const { focusNext, focusPrevious } = useFocusManager();

  const [tasks, setTasks] = useState<Task[]>([]);
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const taskRepo = new JsonFileTaskRepository(dataDir);
  const actions = new TaskActions(taskRepo, boardId);

  // Load tasks
  const loadTasks = useCallback(async () => {
    try {
      const data = await loadBoardData(dataDir, boardId);
      setTasks(data.tasks);
      setError(null);

      // Select first task if none selected
      if (!selectedTaskId && data.tasks.length > 0) {
        setSelectedTaskId(data.tasks[0].id);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }, [dataDir, boardId]);

  useEffect(() => {
    loadTasks();
  }, []);

  // File watcher for external changes
  useEffect(() => {
    const boardFile = `${dataDir}/boards/${boardId}.json`;
    let watcher: Deno.FsWatcher | null = null;

    (async () => {
      try {
        watcher = Deno.watchFs(boardFile);
        for await (const event of watcher) {
          if (event.kind === "modify") {
            await loadTasks();
          }
        }
      } catch {
        // File might not exist yet, or watcher closed
      }
    })();

    return () => {
      watcher?.close();
    };
  }, [boardFile]);

  const groupedTasks = groupTasksByStatus(tasks);
  const selectedTask = tasks.find((t) => t.id === selectedTaskId) ?? null;
  const focusedStatus = selectedTask?.status;

  // Global keybinds
  useInput(async (input, key) => {
    if (input === "q" || (input === "c" && key.ctrl)) {
      exit();
    }

    // Status jump via 1-5
    const statusKeys: Record<string, TaskStatus> = {
      "1": "backlog", "2": "todo", "3": "in_progress", "4": "review", "5": "done",
    };
    if (statusKeys[input]) {
      const target = statusKeys[input];
      const tasksInStatus = groupedTasks.get(target);
      if (tasksInStatus && tasksInStatus.length > 0) {
        setSelectedTaskId(tasksInStatus[0].id);
      }
    }

    // Tab to switch panes
    if (key.tab) {
      if (key.shift) {
        focusPrevious();
      } else {
        focusNext();
      }
    }
  });

  const isNarrow = width < 60;
  const leftWidth = isNarrow ? width - 2 : Math.floor(width * 0.35);

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor={theme.border}
      width={width}
      height={height}
    >
      {/* Header */}
      <Box paddingX={1}>
        <Text bold color={theme.amber}>kanban</Text>
        <Text color={theme.textDim}> ── </Text>
        <Text color={theme.text}>{boardId}</Text>
      </Box>

      {/* Summary Bar */}
      <SummaryBar tasks={tasks} focusedStatus={focusedStatus} />

      {/* Error toast */}
      {error && (
        <Box paddingX={1}>
          <Text color={theme.coral}>⚠ {error}</Text>
        </Box>
      )}

      {/* Main: Split Pane */}
      <Box flexGrow={1}>
        <Box width={leftWidth} flexDirection="column" borderStyle="single" borderColor={theme.border} borderRight>
          <TaskTree
            groupedTasks={groupedTasks}
            selectedTaskId={selectedTaskId}
            onSelectTask={setSelectedTaskId}
            onFocusRight={() => focusNext()}
          />
        </Box>
        {!isNarrow && (
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
```

**Step 2: cli.ts を更新**

```tsx
// cli.ts
import { withFullScreen } from "fullscreen-ink";
import React from "react";
import { BoardView } from "./src/tui/views/board-view.tsx";

const DATA_DIR = Deno.env.get("KANBAN_DATA_DIR") ??
  `${Deno.env.get("HOME")}/.claude/kanban`;

// TODO: Task 11 でボード選択画面を追加。暫定で引数 or 最初のボードを使う
const boardId = Deno.args[0] ?? "dotfiles";

async function main() {
  const ink = withFullScreen(
    <BoardView dataDir={DATA_DIR} boardId={boardId} />
  );
  await ink.start();
  await ink.waitUntilExit();
}

main();
```

**Step 3: 統合動作確認**

Run: `cd ~/.claude/tools/kanban-server && deno task tui`
Expected: Split Pane が表示。左ペインでタスク移動、右ペインに詳細。`q` で終了。

**Step 4: コミット**

```bash
git add src/tui/views/board-view.tsx cli.ts
git commit -m "feat(tui): integrate Split Pane BoardView with live data"
```

---

### Task 10: タスク追加・移動・削除のキーバインド統合

**Files:**
- Modify: `~/.claude/tools/kanban-server/src/tui/views/board-view.tsx`
- Create: `~/.claude/tools/kanban-server/src/tui/components/status-select.tsx`

**Step 1: ステータス選択コンポーネントを作成**

```tsx
// src/tui/components/status-select.tsx
import React from "react";
import { Box, Text } from "ink";
import { Select } from "ink/ui";
import type { TaskStatus } from "../../types.ts";
import { statusColor, statusIcon } from "../theme.ts";

interface StatusSelectProps {
  currentStatus: TaskStatus;
  onSelect: (status: TaskStatus) => void;
  onCancel: () => void;
}

const STATUSES: TaskStatus[] = ["backlog", "todo", "in_progress", "review", "done"];

export function StatusSelect({ currentStatus, onSelect, onCancel }: StatusSelectProps) {
  const options = STATUSES.filter((s) => s !== currentStatus).map((s) => ({
    label: `${statusIcon(s)} ${s}`,
    value: s,
  }));

  return (
    <Box flexDirection="column" paddingX={1}>
      <Text bold>Move to:</Text>
      <Select
        options={options}
        onChange={(value) => onSelect(value as TaskStatus)}
      />
    </Box>
  );
}
```

**Step 2: BoardView に追加・移動・削除の操作を統合**

`board-view.tsx` の `useInput` 内に以下のキーバインドを追加:

- `a`: タスクタイトル入力モードに遷移 → `TextInput` で入力 → `actions.createTask()` → `loadTasks()`
- `m`: `StatusSelect` オーバーレイを表示 → 選択 → `actions.moveTask()` → `loadTasks()`
- `d`: 確認プロンプト表示 → `y` で `actions.deleteTask()` → `loadTasks()`

状態管理: `mode` state を追加 (`"normal" | "adding" | "moving" | "deleting" | "editing"`)

**Step 3: 動作確認**

Run: `deno task tui`
- `a` → タイトル入力 → Enter → タスク追加確認
- `m` → ステータス選択 → 移動確認
- `d` → `y` 確認 → 削除確認

**Step 4: コミット**

```bash
git add src/tui/components/status-select.tsx src/tui/views/board-view.tsx
git commit -m "feat(tui): add task create/move/delete keybinds"
```

---

### Task 11: TaskEditor — 詳細編集フォーム

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/views/task-editor.tsx`
- Modify: `~/.claude/tools/kanban-server/src/tui/views/board-view.tsx`

**Step 1: 実装**

```tsx
// src/tui/views/task-editor.tsx
import React, { useState } from "react";
import { Box, Text, useInput } from "ink";
import { TextInput, Select } from "ink/ui";
import type { Task, TaskStatus, Priority } from "../../types.ts";
import { theme } from "../theme.ts";

interface TaskEditorProps {
  task: Task;
  onSave: (updates: {
    title?: string;
    description?: string;
    status?: TaskStatus;
    priority?: Priority;
    labels?: string[];
    worktree?: string;
  }) => void;
  onCancel: () => void;
}

type Field = "title" | "status" | "priority" | "labels" | "worktree" | "description";

const FIELDS: Field[] = ["title", "status", "priority", "labels", "worktree", "description"];
const STATUSES: TaskStatus[] = ["backlog", "todo", "in_progress", "review", "done"];
const PRIORITIES: Priority[] = ["high", "medium", "low"];

export function TaskEditor({ task, onSave, onCancel }: TaskEditorProps) {
  const [activeField, setActiveField] = useState<number>(0);
  const [title, setTitle] = useState(task.title);
  const [status, setStatus] = useState(task.status);
  const [priority, setPriority] = useState(task.priority);
  const [labels, setLabels] = useState(task.labels.join(", "));
  const [worktree, setWorktree] = useState(task.worktree ?? "");
  const [description, setDescription] = useState(task.description);

  useInput((input, key) => {
    if (key.escape) {
      onCancel();
      return;
    }

    if (key.tab) {
      setActiveField((prev) =>
        key.shift
          ? (prev - 1 + FIELDS.length) % FIELDS.length
          : (prev + 1) % FIELDS.length
      );
    }
  });

  const handleSave = () => {
    onSave({
      title: title !== task.title ? title : undefined,
      description: description !== task.description ? description : undefined,
      status: status !== task.status ? status : undefined,
      priority: priority !== task.priority ? priority : undefined,
      labels: labels !== task.labels.join(", ")
        ? labels.split(",").map((l) => l.trim()).filter(Boolean)
        : undefined,
      worktree: worktree !== (task.worktree ?? "") ? worktree : undefined,
    });
  };

  const currentField = FIELDS[activeField];

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor={theme.borderActive}
      paddingX={1}
    >
      <Text bold color={theme.amber}>Edit: {task.title}</Text>

      <Box marginTop={1} flexDirection="column" gap={0}>
        <Box>
          <Box width={12}><Text color={theme.textMuted}>Title</Text></Box>
          {currentField === "title" ? (
            <TextInput defaultValue={title} onChange={setTitle} onSubmit={handleSave} />
          ) : (
            <Text color={theme.text}>{title}</Text>
          )}
        </Box>

        <Box>
          <Box width={12}><Text color={theme.textMuted}>Status</Text></Box>
          {currentField === "status" ? (
            <Select
              options={STATUSES.map((s) => ({ label: s, value: s }))}
              defaultValue={status}
              onChange={(v) => { setStatus(v as TaskStatus); setActiveField((p) => p + 1); }}
            />
          ) : (
            <Text color={theme.text}>{status}</Text>
          )}
        </Box>

        <Box>
          <Box width={12}><Text color={theme.textMuted}>Priority</Text></Box>
          {currentField === "priority" ? (
            <Select
              options={PRIORITIES.map((p) => ({ label: p, value: p }))}
              defaultValue={priority}
              onChange={(v) => { setPriority(v as Priority); setActiveField((p) => p + 1); }}
            />
          ) : (
            <Text color={theme.text}>{priority}</Text>
          )}
        </Box>

        <Box>
          <Box width={12}><Text color={theme.textMuted}>Labels</Text></Box>
          {currentField === "labels" ? (
            <TextInput defaultValue={labels} onChange={setLabels} onSubmit={handleSave} />
          ) : (
            <Text color={theme.text}>{labels || "—"}</Text>
          )}
        </Box>

        <Box>
          <Box width={12}><Text color={theme.textMuted}>Worktree</Text></Box>
          {currentField === "worktree" ? (
            <TextInput defaultValue={worktree} onChange={setWorktree} onSubmit={handleSave} />
          ) : (
            <Text color={theme.text}>{worktree || "—"}</Text>
          )}
        </Box>

        <Box marginTop={1}>
          <Box width={12}><Text color={theme.textMuted}>Description</Text></Box>
        </Box>
        <Box>
          {currentField === "description" ? (
            <TextInput defaultValue={description} onChange={setDescription} onSubmit={handleSave} />
          ) : (
            <Text color={theme.text}>{description || "—"}</Text>
          )}
        </Box>
      </Box>

      <Box marginTop={1} justifyContent="center">
        <Text color={theme.textMuted}>[Enter] Save    [Esc] Cancel    [Tab] Next field</Text>
      </Box>
    </Box>
  );
}
```

**Step 2: BoardView に `e` キーで TaskEditor を表示する統合**

`board-view.tsx` の `mode === "editing"` 時に右ペインを `<TaskEditor>` に差し替え。

**Step 3: 動作確認**

Run: `deno task tui` → タスク選択 → `e` → フィールド編集 → Enter で保存、Esc でキャンセル

**Step 4: コミット**

```bash
git add src/tui/views/task-editor.tsx src/tui/views/board-view.tsx
git commit -m "feat(tui): add TaskEditor form with field navigation"
```

---

### Task 12: BoardSelect — ボード選択画面

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/views/board-select.tsx`
- Modify: `~/.claude/tools/kanban-server/cli.ts`

**Step 1: 実装**

```tsx
// src/tui/views/board-select.tsx
import React, { useState, useEffect } from "react";
import { Box, Text } from "ink";
import { Select } from "ink/ui";
import { JsonFileBoardRepository } from "../../repositories/json-file-board-repository.ts";
import type { Board } from "../../types.ts";
import { theme } from "../theme.ts";

interface BoardSelectProps {
  dataDir: string;
  onSelect: (boardId: string) => void;
}

export function BoardSelect({ dataDir, onSelect }: BoardSelectProps) {
  const [boards, setBoards] = useState<Board[]>([]);

  useEffect(() => {
    const repo = new JsonFileBoardRepository(dataDir);
    repo.listBoards().then(setBoards);
  }, []);

  if (boards.length === 0) {
    return (
      <Box flexDirection="column" padding={2}>
        <Text color={theme.textMuted}>ボードが見つかりません。</Text>
        <Text color={theme.textDim}>/kanban add でタスクを追加するとボードが作成されます。</Text>
      </Box>
    );
  }

  // Auto-detect board from cwd
  const cwd = Deno.cwd();
  const autoBoard = boards.find((b) => cwd.startsWith(b.path));

  if (autoBoard) {
    // Auto-select if cwd matches
    onSelect(autoBoard.id);
    return null;
  }

  const options = boards.map((b) => ({
    label: `${b.name} (${b.path})`,
    value: b.id,
  }));

  return (
    <Box flexDirection="column" padding={2}>
      <Text bold color={theme.amber}>Select a board:</Text>
      <Box marginTop={1}>
        <Select options={options} onChange={onSelect} />
      </Box>
    </Box>
  );
}
```

**Step 2: cli.ts を更新 — ボード選択 → BoardView の遷移**

```tsx
// cli.ts
import { withFullScreen } from "fullscreen-ink";
import React, { useState } from "react";
import { BoardView } from "./src/tui/views/board-view.tsx";
import { BoardSelect } from "./src/tui/views/board-select.tsx";

const DATA_DIR = Deno.env.get("KANBAN_DATA_DIR") ??
  `${Deno.env.get("HOME")}/.claude/kanban`;

function App() {
  const initialBoardId = Deno.args[0] ?? null;
  const [boardId, setBoardId] = useState<string | null>(initialBoardId);

  if (!boardId) {
    return <BoardSelect dataDir={DATA_DIR} onSelect={setBoardId} />;
  }

  return (
    <BoardView
      dataDir={DATA_DIR}
      boardId={boardId}
      onBack={() => setBoardId(null)}
    />
  );
}

async function main() {
  const ink = withFullScreen(<App />);
  await ink.start();
  await ink.waitUntilExit();
}

main();
```

**Step 3: BoardView に `onBack` prop を追加**

`board-view.tsx` の `b` キーバインドで `onBack()` を呼び出す。

**Step 4: 動作確認**

Run: `deno task tui`
- 引数なし → ボード選択画面 → 選択 → BoardView
- 引数あり → 直接 BoardView
- `b` キー → ボード選択に戻る

**Step 5: コミット**

```bash
git add src/tui/views/board-select.tsx cli.ts src/tui/views/board-view.tsx
git commit -m "feat(tui): add BoardSelect with auto-detect and navigation"
```

---

### Task 13: マウスサポート (use-mouse-input hook)

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/hooks/use-mouse-input.ts`
- Test: `~/.claude/tools/kanban-server/src/tui/hooks/use-mouse-input_test.ts`

**Step 1: failing test を書く**

```typescript
// src/tui/hooks/use-mouse-input_test.ts
import { assertEquals } from "@std/assert";
import { parseMouseEvent, type MouseEvent } from "./use-mouse-input.ts";

Deno.test("parseMouseEvent parses SGR mouse click", () => {
  // SGR format: \x1b[<0;10;5M (button 0, x=10, y=5, press)
  const result = parseMouseEvent("\x1b[<0;10;5M");
  assertEquals(result, { button: "left", x: 10, y: 5, type: "press" });
});

Deno.test("parseMouseEvent parses SGR mouse release", () => {
  const result = parseMouseEvent("\x1b[<0;10;5m");
  assertEquals(result, { button: "left", x: 10, y: 5, type: "release" });
});

Deno.test("parseMouseEvent parses right click", () => {
  const result = parseMouseEvent("\x1b[<2;20;10M");
  assertEquals(result, { button: "right", x: 20, y: 10, type: "press" });
});

Deno.test("parseMouseEvent parses scroll up", () => {
  const result = parseMouseEvent("\x1b[<64;5;5M");
  assertEquals(result, { button: "scrollUp", x: 5, y: 5, type: "press" });
});

Deno.test("parseMouseEvent parses scroll down", () => {
  const result = parseMouseEvent("\x1b[<65;5;5M");
  assertEquals(result, { button: "scrollDown", x: 5, y: 5, type: "press" });
});

Deno.test("parseMouseEvent returns null for non-mouse input", () => {
  const result = parseMouseEvent("hello");
  assertEquals(result, null);
});
```

**Step 2: test が失敗することを確認**

Run: `deno test src/tui/hooks/use-mouse-input_test.ts`
Expected: FAIL

**Step 3: 実装**

```typescript
// src/tui/hooks/use-mouse-input.ts
export interface MouseEvent {
  button: "left" | "middle" | "right" | "scrollUp" | "scrollDown";
  x: number;
  y: number;
  type: "press" | "release";
}

const SGR_MOUSE_RE = /^\x1b\[<(\d+);(\d+);(\d+)([Mm])$/;

export function parseMouseEvent(data: string): MouseEvent | null {
  const match = data.match(SGR_MOUSE_RE);
  if (!match) return null;

  const code = parseInt(match[1], 10);
  const x = parseInt(match[2], 10);
  const y = parseInt(match[3], 10);
  const type = match[4] === "M" ? "press" : "release";

  let button: MouseEvent["button"];
  if (code === 0) button = "left";
  else if (code === 1) button = "middle";
  else if (code === 2) button = "right";
  else if (code === 64) button = "scrollUp";
  else if (code === 65) button = "scrollDown";
  else return null;

  return { button, x, y, type };
}

// Enable SGR mouse mode on stdin
export function enableMouse(): void {
  // Enable SGR extended mouse mode
  Deno.stdout.writeSync(new TextEncoder().encode("\x1b[?1000h\x1b[?1006h"));
}

// Disable mouse mode
export function disableMouse(): void {
  Deno.stdout.writeSync(new TextEncoder().encode("\x1b[?1000l\x1b[?1006l"));
}
```

**Step 4: テスト pass を確認**

Run: `deno test src/tui/hooks/use-mouse-input_test.ts`
Expected: 6 tests PASS

**Step 5: コンポーネントにマウスハンドリングを統合**

`board-view.tsx` の `useEffect` で `enableMouse()` / `disableMouse()` を呼び出し、`useStdin` から raw data を受け取って `parseMouseEvent` でパース。クリック座標からコンポーネントへのヒットテスト。

**Step 6: コミット**

```bash
git add src/tui/hooks/use-mouse-input.ts src/tui/hooks/use-mouse-input_test.ts src/tui/views/board-view.tsx
git commit -m "feat(tui): add mouse support with SGR protocol parsing"
```

---

### Task 14: インクリメンタルサーチ

**Files:**
- Create: `~/.claude/tools/kanban-server/src/tui/components/search-overlay.tsx`
- Modify: `~/.claude/tools/kanban-server/src/tui/views/board-view.tsx`

**Step 1: 実装**

```tsx
// src/tui/components/search-overlay.tsx
import React from "react";
import { Box, Text } from "ink";
import { TextInput } from "ink/ui";
import type { Task } from "../../types.ts";
import { theme, statusIcon, priorityIcon } from "../theme.ts";

interface SearchOverlayProps {
  query: string;
  results: Task[];
  onQueryChange: (query: string) => void;
  onSelect: (taskId: string) => void;
  onCancel: () => void;
}

export function SearchOverlay({
  query,
  results,
  onQueryChange,
  onSelect,
  onCancel,
}: SearchOverlayProps) {
  return (
    <Box flexDirection="column" paddingX={1}>
      <Box>
        <Text color={theme.amber}>/</Text>
        <TextInput
          defaultValue={query}
          onChange={onQueryChange}
          onSubmit={() => {
            if (results.length > 0) {
              onSelect(results[0].id);
            }
          }}
        />
      </Box>
      <Box flexDirection="column" marginTop={1}>
        {results.slice(0, 10).map((task) => (
          <Text key={task.id} color={theme.text}>
            {statusIcon(task.status)} {priorityIcon(task.priority)} {task.title}
            <Text color={theme.textDim}> ({task.status})</Text>
          </Text>
        ))}
        {results.length === 0 && query.length > 0 && (
          <Text color={theme.textDim}>No results</Text>
        )}
      </Box>
    </Box>
  );
}
```

**Step 2: BoardView に検索モードを統合**

`mode === "searching"` 時に `SearchOverlay` を表示。タイトル・ラベル・説明文を対象に部分一致フィルタ。

**Step 3: 動作確認**

Run: `deno task tui` → `/` → テキスト入力 → リアルタイムフィルタ → Enter で選択 → Esc でキャンセル

**Step 4: コミット**

```bash
git add src/tui/components/search-overlay.tsx src/tui/views/board-view.tsx
git commit -m "feat(tui): add incremental search overlay"
```

---

### Task 15: `/kanban` スキル統合

**Files:**
- Modify: `~/.claude/tools/kanban-server/../../../skills/kanban/SKILL.md` (`~/.dotfiles/claude/skills/kanban/SKILL.md`)

**Step 1: SKILL.md を更新**

`/kanban`（引数なし）と `/kanban show` を TUI 起動に変更:

```markdown
### `/kanban`（引数なし）
1. TUI を起動する:
   ```bash
   cd ~/.claude/tools/kanban-server && deno task tui
   ```
2. 現在の `pwd` から対応するボードを自動検出する
```

`/kanban show` セクションを削除。

`/kanban add`, `/kanban move`, `/kanban sync` はワンショットのまま残す。ただし API 経由ではなく、リポジトリを直接操作する記述に変更。

**Step 2: 動作確認**

`/kanban` スキルで TUI が起動することを確認。

**Step 3: コミット**

```bash
git add claude/skills/kanban/SKILL.md
git commit -m "feat(tui): update /kanban skill to launch TUI"
```

---

### Task 16: Handover sync キーバインド統合

**Files:**
- Modify: `~/.claude/tools/kanban-server/src/tui/views/board-view.tsx`

**Step 1: `s` キーで handover sync を実行**

`board-view.tsx` に以下を追加:
- `SyncService` を import
- `s` キーで現在の `pwd` から最新の `project-state.json` を探す
- `syncFromProjectState()` を呼び出す
- 結果をトースト表示（`created: N, updated: M`）

**Step 2: 動作確認**

Run: `deno task tui` → `s` → sync 結果のトースト確認

**Step 3: コミット**

```bash
git add src/tui/views/board-view.tsx
git commit -m "feat(tui): add handover sync via 's' keybind"
```

---

### Task 17: 最終統合テスト・リファクタ

**Files:**
- 全 TUI ファイル

**Step 1: 全テスト実行**

Run: `cd ~/.claude/tools/kanban-server && deno test --allow-read --allow-write --allow-env --allow-run`
Expected: 全テスト PASS（既存テスト + 新規テスト）

**Step 2: 型チェック**

Run: `deno check cli.ts`
Expected: エラーなし

**Step 3: エッジケース手動確認**

- 空のボード → 「タスクを選択してください」表示
- ターミナル幅 50 → 右ペイン非表示、リスト単独表示
- 外部変更（別ターミナルから JSON 直接編集）→ TUI が自動更新
- 存在しないボード ID → エラーメッセージ表示

**Step 4: コミット**

```bash
git add -A
git commit -m "feat(tui): final integration and polish"
```
