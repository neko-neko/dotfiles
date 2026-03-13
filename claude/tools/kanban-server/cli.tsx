// cli.tsx — Minimal Ink + fullscreen-ink scaffold on Deno
// Prerequisites: Deno 2.7+, npm:ink@5, npm:fullscreen-ink@2, npm:react@18
import { useScreenSize, withFullScreen } from "fullscreen-ink";
import { Box, Text, useApp, useInput } from "ink";

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
