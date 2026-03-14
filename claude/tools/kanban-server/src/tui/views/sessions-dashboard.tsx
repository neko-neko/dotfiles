// src/tui/views/sessions-dashboard.tsx — Full-screen Claude Code sessions dashboard
// Replaces BoardView when user navigates to sessions (S key).
// Loads session data directly from filesystem (same logic as capabilities-impl.ts).
// Prerequisite: ink ^5, react ^18, fullscreen-ink ^0.1.0
import { useCallback, useEffect, useMemo, useState } from "react";
import { Box, Text, useApp, useInput } from "ink";
import { useScreenSize } from "fullscreen-ink";
import type { ClaudeSession, SessionMessages } from "../../capabilities.ts";
import { theme } from "../theme.ts";

export interface SessionsDashboardProps {
  dataDir: string;
  projectPath: string;
  onBack: () => void;
}

const CLAUDE_DIR = `${Deno.env.get("HOME")}/.claude`;

function encodeProjectPath(projectPath: string): string {
  return projectPath.replace(/[/.]/g, "-");
}

function formatTimestamp(ts: string): string {
  const d = new Date(ts);
  if (Number.isNaN(d.getTime())) return "unknown";
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const h = String(d.getHours()).padStart(2, "0");
  const min = String(d.getMinutes()).padStart(2, "0");
  return `${y}-${m}-${day} ${h}:${min}`;
}

function truncate(s: string, maxLen: number): string {
  if (s.length <= maxLen) return s;
  return s.slice(0, maxLen - 3) + "...";
}

/** Load Claude sessions from the filesystem (mirrors capabilities-impl.ts logic). */
async function loadSessions(projectPath: string): Promise<ClaudeSession[]> {
  const encoded = encodeProjectPath(projectPath);
  const projectDir = `${CLAUDE_DIR}/projects/${encoded}`;
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  let dirEntries: Deno.DirEntry[];
  try {
    dirEntries = [];
    for await (const entry of Deno.readDir(projectDir)) {
      dirEntries.push(entry);
    }
  } catch {
    return [];
  }

  // Load history index for first-prompt display
  const historyIndex = new Map<string, string>();
  try {
    const historyText = await Deno.readTextFile(`${CLAUDE_DIR}/history.jsonl`);
    for (const line of historyText.split("\n")) {
      if (!line.trim()) continue;
      try {
        const h = JSON.parse(line);
        if (h.sessionId && h.display && !historyIndex.has(h.sessionId)) {
          historyIndex.set(h.sessionId, h.display);
        }
      } catch { /* skip */ }
    }
  } catch { /* not found */ }

  const sessionMap = new Map<
    string,
    { jsonlPaths: string[]; hasDir: boolean }
  >();
  for (const entry of dirEntries) {
    if (entry.isDirectory && uuidRegex.test(entry.name)) {
      const sid = entry.name;
      if (!sessionMap.has(sid)) {
        sessionMap.set(sid, { jsonlPaths: [], hasDir: true });
      } else {
        sessionMap.get(sid)!.hasDir = true;
      }
    }
    if (
      entry.isFile && entry.name.endsWith(".jsonl") &&
      uuidRegex.test(entry.name.replace(".jsonl", ""))
    ) {
      const sid = entry.name.replace(".jsonl", "");
      if (!sessionMap.has(sid)) {
        sessionMap.set(sid, { jsonlPaths: [], hasDir: false });
      }
      sessionMap.get(sid)!.jsonlPaths.push(`${projectDir}/${entry.name}`);
    }
  }

  const sessions: ClaudeSession[] = [];
  for (const [sessionId, info] of sessionMap) {
    let jsonlPath: string | null = info.jsonlPaths[0] ?? null;
    if (!jsonlPath && info.hasDir) {
      const rootJsonl = `${projectDir}/${sessionId}.jsonl`;
      try {
        await Deno.stat(rootJsonl);
        jsonlPath = rootJsonl;
      } catch {
        try {
          for await (
            const sub of Deno.readDir(
              `${projectDir}/${sessionId}/subagents`,
            )
          ) {
            if (sub.isFile && sub.name.endsWith(".jsonl")) {
              jsonlPath = `${projectDir}/${sessionId}/subagents/${sub.name}`;
              break;
            }
          }
        } catch { /* no subagents */ }
      }
    }
    if (!jsonlPath) continue;

    // Read first 20 lines for metadata
    const lines: string[] = [];
    try {
      const file = await Deno.open(jsonlPath, { read: true });
      try {
        const decoder = new TextDecoder();
        const buf = new Uint8Array(8192);
        let remainder = "";
        outer: while (true) {
          const n = await file.read(buf);
          if (n === null) break;
          const chunk = remainder + decoder.decode(buf.subarray(0, n));
          const parts = chunk.split("\n");
          remainder = parts.pop() ?? "";
          for (const part of parts) {
            if (part.trim()) {
              lines.push(part);
              if (lines.length >= 20) break outer;
            }
          }
        }
        if (remainder.trim() && lines.length < 20) lines.push(remainder);
      } finally {
        file.close();
      }
    } catch { /* unreadable */ }

    const meta: Record<string, string> = {};
    for (const line of lines) {
      try {
        const e = JSON.parse(line);
        if (e.sessionId && !meta.sessionId) meta.sessionId = e.sessionId;
        if (e.slug && !meta.slug) meta.slug = e.slug;
        if (e.version && !meta.version) meta.version = e.version;
        if (e.gitBranch && !meta.gitBranch) meta.gitBranch = e.gitBranch;
        if (e.timestamp && !meta.timestamp) meta.timestamp = e.timestamp;
      } catch { /* skip */ }
    }
    if (!meta.timestamp) continue;

    let agentCount = 0;
    try {
      for await (
        const sub of Deno.readDir(
          `${projectDir}/${sessionId}/subagents`,
        )
      ) {
        if (sub.isFile && sub.name.endsWith(".jsonl")) agentCount++;
      }
    } catch { /* no subagents */ }

    const firstPrompt = historyIndex.get(sessionId) ?? "";
    sessions.push({
      sessionId,
      slug: meta.slug ?? "",
      gitBranch: meta.gitBranch ?? "",
      version: meta.version ?? "",
      timestamp: meta.timestamp,
      firstPrompt: firstPrompt.length > 200
        ? firstPrompt.slice(0, 200) + "..."
        : firstPrompt,
      agentCount,
    });
  }

  sessions.sort((a, b) => b.timestamp.localeCompare(a.timestamp));
  return sessions.slice(0, 30);
}

/** Load session messages from filesystem (simplified version). */
async function loadSessionMessages(
  sessionId: string,
  projectPath: string,
  limit = 20,
): Promise<SessionMessages> {
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(sessionId)) {
    return { sessionId, slug: "", messages: [], totalCount: 0 };
  }

  const encoded = encodeProjectPath(projectPath);
  const projectDir = `${CLAUDE_DIR}/projects/${encoded}`;
  const jsonlFiles: string[] = [];

  try {
    await Deno.stat(`${projectDir}/${sessionId}.jsonl`);
    jsonlFiles.push(`${projectDir}/${sessionId}.jsonl`);
  } catch { /* not found */ }
  try {
    for await (
      const sub of Deno.readDir(`${projectDir}/${sessionId}/subagents`)
    ) {
      if (sub.isFile && sub.name.endsWith(".jsonl")) {
        jsonlFiles.push(
          `${projectDir}/${sessionId}/subagents/${sub.name}`,
        );
      }
    }
  } catch { /* no subagents */ }

  if (jsonlFiles.length === 0) {
    return { sessionId, slug: "", messages: [], totalCount: 0 };
  }

  const messages: Array<{
    role: string;
    content: string;
    timestamp: string;
    agentId?: string;
  }> = [];
  let slug = "";
  const MAX_CONTENT = 300;

  for (const filePath of jsonlFiles) {
    try {
      const text = await Deno.readTextFile(filePath);
      for (const line of text.split("\n")) {
        if (!line.trim()) continue;
        try {
          const entry = JSON.parse(line);
          if (!slug && entry.slug) slug = entry.slug;
          if (
            (entry.type === "user" || entry.type === "assistant") &&
            entry.message
          ) {
            const msg = entry.message;
            let content = "";
            if (typeof msg.content === "string") content = msg.content;
            else if (Array.isArray(msg.content)) {
              content = msg.content
                .filter((b: { type: string }) => b.type === "text")
                .map((b: { text: string }) => b.text)
                .join("\n");
            }
            if (!content) continue;
            if (content.length > MAX_CONTENT) {
              content = content.slice(0, MAX_CONTENT) + "...";
            }
            messages.push({
              role: entry.type,
              content,
              timestamp: entry.timestamp ?? msg.timestamp ?? "",
              agentId: entry.agentId,
            });
          }
        } catch { /* skip malformed */ }
      }
    } catch { /* file error */ }
  }

  messages.sort((a, b) => a.timestamp.localeCompare(b.timestamp));
  return {
    sessionId,
    slug,
    messages: messages.slice(-limit),
    totalCount: messages.length,
  };
}

export function SessionsDashboard(
  { dataDir: _dataDir, projectPath, onBack }: SessionsDashboardProps,
) {
  const { exit } = useApp();
  const { width, height } = useScreenSize();

  const [sessions, setSessions] = useState<ClaudeSession[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [selectedSet, setSelectedSet] = useState<Set<string>>(new Set());
  const [expandedSessionId, setExpandedSessionId] = useState<string | null>(
    null,
  );
  const [expandedMessages, setExpandedMessages] = useState<
    SessionMessages | null
  >(null);

  // Load sessions on mount
  useEffect(() => {
    setLoading(true);
    loadSessions(projectPath)
      .then((s) => {
        setSessions(s);
        setLoading(false);
      })
      .catch((e: unknown) => {
        setError(e instanceof Error ? e.message : String(e));
        setLoading(false);
      });
  }, [projectPath]);

  // Derived
  const activeCount = useMemo(
    () => sessions.filter((s) => s.gitBranch && s.gitBranch.length > 0).length,
    [sessions],
  );

  const clampedIndex = sessions.length > 0
    ? Math.min(Math.max(0, selectedIndex), sessions.length - 1)
    : 0;

  // Expand / collapse messages
  const toggleExpand = useCallback(async () => {
    if (sessions.length === 0) return;
    const session = sessions[clampedIndex];
    if (expandedSessionId === session.sessionId) {
      setExpandedSessionId(null);
      setExpandedMessages(null);
    } else {
      setExpandedSessionId(session.sessionId);
      try {
        const msgs = await loadSessionMessages(
          session.sessionId,
          projectPath,
        );
        setExpandedMessages(msgs);
      } catch {
        setExpandedMessages({
          sessionId: session.sessionId,
          slug: "",
          messages: [],
          totalCount: 0,
        });
      }
    }
  }, [sessions, clampedIndex, expandedSessionId, projectPath]);

  // Toggle selection
  const toggleSelection = useCallback(() => {
    if (sessions.length === 0) return;
    const session = sessions[clampedIndex];
    setSelectedSet((prev) => {
      const next = new Set(prev);
      if (next.has(session.sessionId)) {
        next.delete(session.sessionId);
      } else {
        next.add(session.sessionId);
      }
      return next;
    });
  }, [sessions, clampedIndex]);

  // Keybinds
  useInput((input, key) => {
    if (input === "q" || (key.ctrl && input === "c")) {
      exit();
      return;
    }
    if (input === "b" || key.escape) {
      onBack();
      return;
    }
    if (input === "j" || key.downArrow) {
      setSelectedIndex((i) => Math.min(i + 1, sessions.length - 1));
      return;
    }
    if (input === "k" || key.upArrow) {
      setSelectedIndex((i) => Math.max(i - 1, 0));
      return;
    }
    if (key.return) {
      toggleExpand();
      return;
    }
    if (input === " ") {
      toggleSelection();
      return;
    }
    // x = build context and launch (placeholder: just show info)
    if (input === "x" && selectedSet.size > 0) {
      // TODO: Wire to LaunchMenu / buildContext when integrated
      return;
    }
  });

  // Visible rows for scrolling
  const maxVisibleRows = Math.max(1, height - 8); // header + summary + hint

  // Calculate scroll window
  const scrollStart = Math.max(
    0,
    Math.min(
      clampedIndex - Math.floor(maxVisibleRows / 2),
      sessions.length - maxVisibleRows,
    ),
  );
  const visibleSessions = sessions.slice(
    scrollStart,
    scrollStart + maxVisibleRows,
  );

  return (
    <Box flexDirection="column" width={width} height={height}>
      {/* Header */}
      <Box paddingX={1}>
        <Text color={theme.amber} bold>kanban</Text>
        <Text color={theme.textDim}>{` \u2500\u2500 `}</Text>
        <Text color={theme.text}>Sessions</Text>
      </Box>

      {/* Summary row */}
      <Box paddingX={1} gap={2}>
        <Text color={theme.textMuted}>
          Total: <Text color={theme.text} bold>{sessions.length}</Text>
        </Text>
        <Text color={theme.textMuted}>
          With branch: <Text color={theme.sage} bold>{activeCount}</Text>
        </Text>
        {selectedSet.size > 0 && (
          <Text color={theme.amber}>
            Selected: <Text bold>{selectedSet.size}</Text>
          </Text>
        )}
      </Box>

      {/* Error */}
      {error && (
        <Box paddingX={1}>
          <Text color={theme.coral}>
            <Text bold>Error:</Text> {error}
          </Text>
        </Box>
      )}

      {/* Main content */}
      <Box flexGrow={1} flexDirection="column" paddingX={1}>
        {loading
          ? (
            <Box justifyContent="center" alignItems="center" flexGrow={1}>
              <Text color={theme.textMuted}>Loading sessions...</Text>
            </Box>
          )
          : sessions.length === 0
          ? (
            <Box justifyContent="center" alignItems="center" flexGrow={1}>
              <Text color={theme.textDim}>No sessions found</Text>
            </Box>
          )
          : (
            <Box flexDirection="column">
              {visibleSessions.map((session, vi) => {
                const realIndex = scrollStart + vi;
                const isSelected = realIndex === clampedIndex;
                const isChecked = selectedSet.has(session.sessionId);
                const isExpanded = session.sessionId === expandedSessionId;

                return (
                  <Box key={session.sessionId} flexDirection="column">
                    <Box>
                      {/* Selection checkbox */}
                      <Text color={isChecked ? theme.amber : theme.textDim}>
                        {isChecked ? "[x]" : "[ ]"}
                      </Text>
                      <Text color={theme.textMuted}></Text>

                      {/* Cursor */}
                      <Text
                        color={isSelected ? theme.amber : theme.text}
                        bold={isSelected}
                      >
                        {isSelected ? "\u25B6 " : "  "}
                      </Text>

                      {/* Slug / ID */}
                      <Text
                        color={isSelected ? theme.amber : theme.text}
                        bold={isSelected}
                      >
                        {truncate(
                          session.slug || session.sessionId.slice(0, 8),
                          20,
                        )}
                      </Text>
                      <Text color={theme.textMuted}></Text>

                      {/* Branch */}
                      {session.gitBranch && (
                        <>
                          <Text color={theme.sage}>
                            {truncate(session.gitBranch, 20)}
                          </Text>
                          <Text color={theme.textMuted}></Text>
                        </>
                      )}

                      {/* Timestamp */}
                      <Text color={theme.textDim}>
                        {formatTimestamp(session.timestamp)}
                      </Text>

                      {/* Agent count */}
                      {session.agentCount > 0 && (
                        <Text color={theme.violet}>
                          {" "}
                          {session.agentCount}ag
                        </Text>
                      )}
                    </Box>

                    {/* First prompt snippet */}
                    {session.firstPrompt && (
                      <Box marginLeft={8}>
                        <Text color={theme.textMuted}>
                          {truncate(session.firstPrompt, 60)}
                        </Text>
                      </Box>
                    )}

                    {/* Expanded messages */}
                    {isExpanded && expandedMessages && (
                      <Box
                        flexDirection="column"
                        marginLeft={6}
                        paddingX={1}
                        borderStyle="single"
                        borderColor={theme.border}
                      >
                        {expandedMessages.messages.length === 0
                          ? <Text color={theme.textDim}>No messages</Text>
                          : expandedMessages.messages.map((msg, mi) => (
                            <Box key={`${msg.timestamp}-${mi}`}>
                              <Text
                                color={msg.role === "user"
                                  ? theme.sky
                                  : theme.sage}
                                bold
                              >
                                {msg.role === "user" ? "User: " : "Claude: "}
                              </Text>
                              <Text color={theme.text} wrap="wrap">
                                {truncate(msg.content, 120)}
                              </Text>
                            </Box>
                          ))}
                        <Text color={theme.textDim}>
                          ({expandedMessages.totalCount} total messages)
                        </Text>
                      </Box>
                    )}
                  </Box>
                );
              })}
            </Box>
          )}
      </Box>

      {/* Hint bar */}
      <Box paddingX={1} gap={1}>
        <Box>
          <Text color={theme.amber}>[j/k]</Text>
          <Text color={theme.textMuted}>navigate</Text>
        </Box>
        <Box>
          <Text color={theme.amber}>[Enter]</Text>
          <Text color={theme.textMuted}>messages</Text>
        </Box>
        <Box>
          <Text color={theme.amber}>[Space]</Text>
          <Text color={theme.textMuted}>select</Text>
        </Box>
        <Box>
          <Text color={theme.amber}>[x]</Text>
          <Text color={theme.textMuted}>launch</Text>
        </Box>
        <Box>
          <Text color={theme.amber}>[b]</Text>
          <Text color={theme.textMuted}>back</Text>
        </Box>
        <Box>
          <Text color={theme.amber}>[q]</Text>
          <Text color={theme.textMuted}>quit</Text>
        </Box>
      </Box>
    </Box>
  );
}
