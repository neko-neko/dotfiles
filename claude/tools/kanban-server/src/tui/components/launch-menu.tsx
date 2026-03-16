// src/tui/components/launch-menu.tsx — Modal menu for launching Claude Code
// Shows contextual launch options based on task state.
// Prerequisite: ink ^5, react ^18, @inkjs/ui ^2
import { useEffect, useState } from "react";
import { Box, Text, useInput } from "ink";
import type { Task } from "../../types.ts";
import type { LaunchResult } from "../../capabilities.ts";
import { theme } from "../theme.ts";

export interface LaunchMenuProps {
  task: Task;
  projectPath: string;
  nodeName: string;
  onLaunch: (result: LaunchResult) => void;
  onCancel: () => void;
}

interface MenuItem {
  id: string;
  label: string;
  description: string;
  available: boolean;
}

function buildMenuItems(task: Task, nodeName: string): MenuItem[] {
  const items: MenuItem[] = [
    {
      id: "local",
      label: "Claude Code で開く",
      description: "ローカル起動",
      available: true,
    },
  ];

  // Show remote-attach if task is running on another node
  if (task.executionHost && task.executionHost !== nodeName) {
    items.push({
      id: "remote-info",
      label: `実行中: ${task.executionHost}`,
      description:
        `${task.executionHost} で実行中のセッション（Web UI で管理）`,
      available: false,
    });
  }

  return items;
}

export function LaunchMenu(
  { task, projectPath, nodeName, onLaunch, onCancel }: LaunchMenuProps,
) {
  const menuItems = buildMenuItems(task, nodeName);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [launching, setLaunching] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const clampedIndex = Math.min(
    Math.max(0, selectedIndex),
    menuItems.length - 1,
  );

  // Reset index when menu items change
  useEffect(() => {
    setSelectedIndex(0);
  }, [task.id]);

  const doLaunch = async (item: MenuItem) => {
    if (!item.available || launching) return;
    setLaunching(true);
    setError(null);

    try {
      if (item.id === "local") {
        const args = ["cli", "spawn", "--cwd", projectPath, "--", "claude"];
        if (task.sessionContext?.lastSessionId) {
          args.push("--resume", task.sessionContext.lastSessionId);
        }
        const cmd = new Deno.Command("wezterm", { args });
        const output = await cmd.output();
        if (!output.success) {
          const errText = new TextDecoder().decode(output.stderr);
          setError(errText || "WezTerm launch failed");
          setLaunching(false);
          return;
        }
        onLaunch({
          status: "launched",
          command: `wezterm ${args.join(" ")}`,
          taskId: task.id,
        });
      }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg);
      setLaunching(false);
    }
  };

  useInput((input, key) => {
    if (launching) return;

    if (key.escape || input === "q") {
      onCancel();
      return;
    }
    if (input === "j" || key.downArrow) {
      setSelectedIndex((i) => Math.min(i + 1, menuItems.length - 1));
      return;
    }
    if (input === "k" || key.upArrow) {
      setSelectedIndex((i) => Math.max(i - 1, 0));
      return;
    }
    if (key.return) {
      const item = menuItems[clampedIndex];
      if (item) doLaunch(item);
      return;
    }
  });

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor={theme.amber}
      paddingX={2}
      paddingY={1}
    >
      {/* Header */}
      <Text color={theme.amber} bold>
        Launch: {task.title}
      </Text>
      <Box marginTop={0}>
        <Text color={theme.textDim}>
          {"─".repeat(40)}
        </Text>
      </Box>

      {/* Menu items */}
      <Box flexDirection="column" marginTop={1}>
        {menuItems.map((item, i) => {
          const isSelected = i === clampedIndex;
          return (
            <Box key={item.id} flexDirection="column">
              <Box>
                <Text
                  color={isSelected
                    ? theme.amber
                    : item.available
                    ? theme.text
                    : theme.textDim}
                  bold={isSelected}
                >
                  {isSelected ? "▶ " : "  "}
                  {item.label}
                </Text>
              </Box>
              {isSelected && (
                <Box marginLeft={4}>
                  <Text color={theme.textMuted}>{item.description}</Text>
                </Box>
              )}
            </Box>
          );
        })}
      </Box>

      {/* Status */}
      {launching && (
        <Box marginTop={1}>
          <Text color={theme.amber}>Launching...</Text>
        </Box>
      )}
      {error && (
        <Box marginTop={1}>
          <Text color={theme.coral}>
            <Text bold>Error:</Text> {error}
          </Text>
        </Box>
      )}

      {/* Hint */}
      <Box marginTop={1}>
        <Text color={theme.textDim}>
          {"j/k navigate · Enter launch · Esc cancel"}
        </Text>
      </Box>
    </Box>
  );
}
