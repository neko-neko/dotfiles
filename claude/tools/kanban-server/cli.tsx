// cli.tsx — Kanban TUI entry point
// Prerequisites: Deno 2.7+, npm:ink@5, npm:fullscreen-ink@^0.1.0, npm:react@18
import { withFullScreen } from "fullscreen-ink";
import { useState } from "react";
import { BoardView } from "./src/tui/views/board-view.tsx";
import { BoardSelect } from "./src/tui/views/board-select.tsx";
import { SessionsDashboard } from "./src/tui/views/sessions-dashboard.tsx";

const DATA_DIR = Deno.env.get("KANBAN_DATA_DIR") ??
  `${Deno.env.get("HOME")}/.claude/kanban`;

type AppView = "select" | "board" | "sessions";

function App() {
  const initialBoardId = Deno.args[0] ?? null;
  const [boardId, setBoardId] = useState<string | null>(initialBoardId);
  const [view, setView] = useState<AppView>(
    initialBoardId ? "board" : "select",
  );

  if (view === "sessions" && boardId) {
    return (
      <SessionsDashboard
        dataDir={DATA_DIR}
        projectPath={Deno.cwd()}
        onBack={() => setView("board")}
      />
    );
  }

  if (view === "select" || !boardId) {
    return (
      <BoardSelect
        dataDir={DATA_DIR}
        onSelect={(id) => {
          setBoardId(id);
          setView("board");
        }}
      />
    );
  }

  return (
    <BoardView
      dataDir={DATA_DIR}
      boardId={boardId}
      onBack={() => {
        setBoardId(null);
        setView("select");
      }}
      onSessions={() => setView("sessions")}
    />
  );
}

async function main() {
  const ink = withFullScreen(<App />);
  await ink.start();
  await ink.waitUntilExit();
}

main();
