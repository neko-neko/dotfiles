// cli.tsx — Kanban TUI entry point
// Prerequisites: Deno 2.7+, npm:ink@5, npm:fullscreen-ink@^0.1.0, npm:react@18
import { withFullScreen } from "fullscreen-ink";
import { BoardView } from "./src/tui/views/board-view.tsx";

const DATA_DIR = Deno.env.get("KANBAN_DATA_DIR") ??
  `${Deno.env.get("HOME")}/.claude/kanban`;

// For now, use first CLI arg or default to "dotfiles"
const boardId = Deno.args[0] ?? "dotfiles";

async function main() {
  const ink = withFullScreen(
    <BoardView dataDir={DATA_DIR} boardId={boardId} />,
  );
  await ink.start();
  await ink.waitUntilExit();
}

main();
