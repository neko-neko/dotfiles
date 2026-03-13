// src/tui/components/keybind-bar.tsx — Bottom bar showing available keybinds
import { Box, Text } from "ink";
import { theme } from "../theme.ts";

const BINDINGS: { key: string; label: string }[] = [
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
    <Box paddingX={1} gap={1}>
      {BINDINGS.map(({ key, label }) => (
        <Box key={key}>
          <Text color={theme.amber}>[{key}]</Text>
          <Text color={theme.textMuted}>{label}</Text>
        </Box>
      ))}
    </Box>
  );
}
