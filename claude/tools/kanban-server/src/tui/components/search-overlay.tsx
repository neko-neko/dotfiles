// src/tui/components/search-overlay.tsx — Incremental search overlay
// Filters tasks by case-insensitive partial match on title, labels, description.
// Prerequisite: ink ^5, react ^18, @inkjs/ui ^2
import { useState } from "react";
import { Box, Text, useInput } from "ink";
import { TextInput } from "@inkjs/ui";
import type { Task } from "../../types.ts";
import { priorityIcon, statusIcon, theme } from "../theme.ts";

interface SearchOverlayProps {
  tasks: Task[];
  onSelect: (taskId: string) => void;
  onCancel: () => void;
}

const MAX_RESULTS = 10;

function matchesQuery(task: Task, query: string): boolean {
  if (query.length === 0) return false;
  const q = query.toLowerCase();
  if (task.title.toLowerCase().includes(q)) return true;
  if (task.description.toLowerCase().includes(q)) return true;
  if (task.labels.some((l) => l.toLowerCase().includes(q))) return true;
  return false;
}

export function SearchOverlay(
  { tasks, onSelect, onCancel }: SearchOverlayProps,
) {
  const [query, setQuery] = useState("");
  const [cursor, setCursor] = useState(0);

  const results = query.length > 0
    ? tasks.filter((t) => matchesQuery(t, query)).slice(0, MAX_RESULTS)
    : [];

  // Clamp cursor to valid range (covers results shrinking between renders)
  const clampedCursor = results.length > 0
    ? Math.min(cursor, results.length - 1)
    : 0;

  useInput((input, key) => {
    if (key.escape) {
      onCancel();
      return;
    }
    if (key.return && results.length > 0) {
      onSelect(results[clampedCursor].id);
      return;
    }
    // Navigate results with Ctrl+n / Ctrl+p (arrow keys captured by TextInput)
    if (key.ctrl && input === "n") {
      setCursor((prev) => Math.min(prev + 1, results.length - 1));
      return;
    }
    if (key.ctrl && input === "p") {
      setCursor((prev) => Math.max(prev - 1, 0));
      return;
    }
  });

  return (
    <Box flexDirection="column" paddingX={1}>
      {/* Search input */}
      <Box flexDirection="row" gap={1}>
        <Text color={theme.amber} bold>/</Text>
        <TextInput
          placeholder="Search tasks..."
          onChange={(value) => {
            setQuery(value);
            setCursor(0);
          }}
        />
      </Box>

      {/* Results */}
      {results.length > 0
        ? (
          <Box flexDirection="column">
            {results.map((task, i) => {
              const isSelected = i === clampedCursor;
              return (
                <Box key={task.id} paddingX={1}>
                  <Text
                    color={isSelected ? theme.amber : theme.text}
                    bold={isSelected}
                  >
                    {isSelected ? "\u25B6 " : "  "}
                    {statusIcon(task.status)} {priorityIcon(task.priority)}{" "}
                    {task.title}
                    {task.labels.length > 0 && (
                      <Text color={theme.textMuted}>
                        [{task.labels.join(", ")}]
                      </Text>
                    )}
                  </Text>
                </Box>
              );
            })}
          </Box>
        )
        : query.length > 0
        ? (
          <Box paddingX={1}>
            <Text color={theme.textMuted}>No results</Text>
          </Box>
        )
        : null}

      {/* Hint */}
      <Box paddingX={1}>
        <Text color={theme.textDim}>
          C-n/C-p navigate \u00B7 Enter select \u00B7 Esc cancel
        </Text>
      </Box>
    </Box>
  );
}
