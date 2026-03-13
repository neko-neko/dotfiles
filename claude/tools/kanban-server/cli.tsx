// cli.tsx — Kanban TUI entry point
// Prerequisites: Deno 2.7+, npm:ink@5, npm:fullscreen-ink@^0.1.0, npm:react@18
import { withFullScreen } from "fullscreen-ink";
import { useState } from "react";
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
