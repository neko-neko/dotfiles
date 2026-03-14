import { assertEquals } from "@std/assert";
import { render } from "ink-testing-library";
import { HandoverBrowser } from "./handover-browser.tsx";
import type { HandoverSession } from "../../capabilities.ts";

const testOpts = { sanitizeOps: false, sanitizeResources: false };

const makeSessions = (): HandoverSession[] => [
  {
    fingerprint: "abc123def456",
    path: "/home/user/.claude/handover/main/abc123def456",
    hasHandover: true,
    hasProjectState: true,
    status: "COMPLETED",
    generatedAt: "2026-03-14T10:00:00Z",
    taskSummary: { done: 3, in_progress: 1, blocked: 0 },
  },
  {
    fingerprint: "xyz789uvw012",
    path: "/home/user/.claude/handover/main/xyz789uvw012",
    hasHandover: false,
    hasProjectState: true,
    status: "IN_PROGRESS",
    generatedAt: "2026-03-14T09:00:00Z",
    taskSummary: { done: 0, in_progress: 2, blocked: 1 },
  },
];

Deno.test(
  "HandoverBrowser renders empty state when no sessions",
  testOpts,
  () => {
    const { lastFrame, unmount } = render(
      <HandoverBrowser
        sessions={[]}
        selectedIndex={0}
        expandedFingerprint={null}
        expandedContent={null}
        onNavigate={() => {}}
        onToggleExpand={() => {}}
        onClose={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    assertEquals(
      frame.includes("No handover sessions found"),
      true,
      `Expected empty state in: ${frame}`,
    );
  },
);

Deno.test(
  "HandoverBrowser renders session list with fingerprints",
  testOpts,
  () => {
    const sessions = makeSessions();
    const { lastFrame, unmount } = render(
      <HandoverBrowser
        sessions={sessions}
        selectedIndex={0}
        expandedFingerprint={null}
        expandedContent={null}
        onNavigate={() => {}}
        onToggleExpand={() => {}}
        onClose={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    assertEquals(
      frame.includes("abc123def456"),
      true,
      `Expected first fingerprint in: ${frame}`,
    );
    assertEquals(
      frame.includes("xyz789uvw012"),
      true,
      `Expected second fingerprint in: ${frame}`,
    );
    assertEquals(
      frame.includes("Handover Sessions"),
      true,
      `Expected header in: ${frame}`,
    );
  },
);

Deno.test(
  "HandoverBrowser shows task summary counts",
  testOpts,
  () => {
    const sessions = makeSessions();
    const { lastFrame, unmount } = render(
      <HandoverBrowser
        sessions={sessions}
        selectedIndex={0}
        expandedFingerprint={null}
        expandedContent={null}
        onNavigate={() => {}}
        onToggleExpand={() => {}}
        onClose={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    assertEquals(
      frame.includes("3done"),
      true,
      `Expected done count in: ${frame}`,
    );
    assertEquals(
      frame.includes("1wip"),
      true,
      `Expected wip count in: ${frame}`,
    );
  },
);

Deno.test(
  "HandoverBrowser shows expanded content when fingerprint matches",
  testOpts,
  () => {
    const sessions = makeSessions();
    const { lastFrame, unmount } = render(
      <HandoverBrowser
        sessions={sessions}
        selectedIndex={0}
        expandedFingerprint="abc123def456"
        expandedContent={{
          handover: "## Session Summary\nThis is the handover content.",
          projectState: null,
          fingerprint: "abc123def456",
        }}
        onNavigate={() => {}}
        onToggleExpand={() => {}}
        onClose={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    assertEquals(
      frame.includes("Session Summary"),
      true,
      `Expected handover content in: ${frame}`,
    );
  },
);

Deno.test(
  "HandoverBrowser shows hint bar",
  testOpts,
  () => {
    const sessions = makeSessions();
    const { lastFrame, unmount } = render(
      <HandoverBrowser
        sessions={sessions}
        selectedIndex={0}
        expandedFingerprint={null}
        expandedContent={null}
        onNavigate={() => {}}
        onToggleExpand={() => {}}
        onClose={() => {}}
      />,
    );
    const frame = lastFrame()!;
    unmount();
    assertEquals(
      frame.includes("j/k navigate"),
      true,
      `Expected hint bar in: ${frame}`,
    );
  },
);
