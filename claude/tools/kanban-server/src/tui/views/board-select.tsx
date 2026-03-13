// src/tui/views/board-select.tsx — Board selection screen
// Auto-detects board from cwd, otherwise shows a Select list.
// Prerequisite: @inkjs/ui ^2 (Select), react ^18, ink ^5
import { useEffect, useState } from "react";
import { Box, Text } from "ink";
import { Select } from "@inkjs/ui";
import type { Board } from "../../types.ts";
import { JsonFileBoardRepository } from "../../repositories/mod.ts";
import { theme } from "../theme.ts";

interface BoardSelectProps {
  dataDir: string;
  onSelect: (boardId: string) => void;
}

export function BoardSelect({ dataDir, onSelect }: BoardSelectProps) {
  const [boards, setBoards] = useState<Board[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const repo = new JsonFileBoardRepository(dataDir);
    repo
      .listBoards()
      .then((list) => {
        setBoards(list);
        setLoading(false);

        // Auto-detect: if cwd matches a board's path, select it immediately
        const cwd = Deno.cwd();
        const match = list.find((b) =>
          cwd === b.path || cwd.startsWith(b.path + "/")
        );
        if (match) {
          onSelect(match.id);
        }
      })
      .catch((e: unknown) => {
        const msg = e instanceof Error ? e.message : String(e);
        setError(msg);
        setLoading(false);
      });
  }, [dataDir, onSelect]);

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

  if (boards.length === 0) {
    return (
      <Box paddingX={1} paddingY={1} flexDirection="column">
        <Text color={theme.amber} bold>
          kanban
        </Text>
        <Text color={theme.textMuted}>ボードが見つかりません</Text>
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
        <Text color={theme.textDim}>── Select a board</Text>
      </Box>
      <Select options={options} onChange={(value) => onSelect(value)} />
    </Box>
  );
}
