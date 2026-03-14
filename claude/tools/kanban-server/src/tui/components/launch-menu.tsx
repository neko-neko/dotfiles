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
  onLaunch: (result: LaunchResult) => void;
  onCancel: () => void;
}

interface MenuItem {
  id: string;
  label: string;
  description: string;
  available: boolean;
}

function buildMenuItems(task: Task): MenuItem[] {
  const items: MenuItem[] = [
    {
      id: "local",
      label: "Claude Code \u3067\u958B\u304F",
      description: "WezTerm \u3067\u30ED\u30FC\u30AB\u30EB\u8D77\u52D5",
      available: true,
    },
    {
      id: "remote",
      label: "\u30EA\u30E2\u30FC\u30C8\u5B9F\u884C",
      description: "SSH \u7D4C\u7531\u3067\u30EA\u30E2\u30FC\u30C8\u5B9F\u884C",
      // Only available if remote hosts are configured; for now always show but may fail
      available: true,
    },
  ];

  if (task.executionHost === "remote") {
    items.push({
      id: "remote-attach",
      label:
        "\u30EA\u30E2\u30FC\u30C8\u30BB\u30C3\u30B7\u30E7\u30F3\u306B\u63A5\u7D9A",
      description:
        "\u5B9F\u884C\u4E2D\u306E\u30EA\u30E2\u30FC\u30C8\u30BB\u30C3\u30B7\u30E7\u30F3\u306B\u63A5\u7D9A",
      available: true,
    });
  }

  if (task.status === "done" && task.lastHandoverPath) {
    items.push({
      id: "handover",
      label: "\u30ED\u30FC\u30AB\u30EB\u306B\u5F15\u304D\u7D99\u304E",
      description:
        "Handover \u30C7\u30FC\u30BF\u3067\u30ED\u30FC\u30AB\u30EB\u30BB\u30C3\u30B7\u30E7\u30F3\u3092\u958B\u59CB",
      available: true,
    });
  }

  return items;
}

export function LaunchMenu(
  { task, projectPath, onLaunch, onCancel }: LaunchMenuProps,
) {
  const menuItems = buildMenuItems(task);
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
      } else if (item.id === "remote") {
        // Remote launch - delegate to capabilities when wired
        onLaunch({
          status: "pending",
          taskId: task.id,
          host: "remote",
        });
      } else if (item.id === "remote-attach") {
        onLaunch({
          status: "pending",
          taskId: task.id,
          host: "remote",
          sessionName: task.remoteSessionName ?? `kanban-${task.id}`,
        });
      } else if (item.id === "handover") {
        // Launch with handover context
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
                  {isSelected ? "\u25B6 " : "  "}
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
          {"j/k navigate \u00B7 Enter launch \u00B7 Esc cancel"}
        </Text>
      </Box>
    </Box>
  );
}
