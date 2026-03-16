import { Hono } from "@hono/hono";
import type { BoardRepository } from "../repositories/board-repository.ts";
import type { TaskRepository } from "../repositories/task-repository.ts";
import type { TaskStatus } from "../types.ts";

export function actionRoutes(
  boardRepo: BoardRepository,
  taskRepo: TaskRepository,
): Hono {
  const app = new Hono();

  // POST /launch — launch WezTerm with Claude
  app.post("/launch", async (c) => {
    const body = await c.req.json<{
      projectPath?: string;
      sessionId?: string;
      handoverFile?: string;
      context?: string;
    }>();

    if (!body.projectPath || typeof body.projectPath !== "string") {
      return c.json({ error: "projectPath is required" }, 400);
    }

    const args = ["cli", "spawn", "--cwd", body.projectPath, "--", "claude"];

    // Prefer sessionId (resume) over context
    if (body.sessionId) {
      args.push("--resume", body.sessionId);
    } else if (body.context && typeof body.context === "string") {
      // Write context to a temp file to avoid shell escaping issues
      // Old temp files can be cleaned up periodically (not implemented — YAGNI)
      const tmpPath = `/tmp/kanban-context-${Date.now()}.md`;
      try {
        await Deno.writeTextFile(tmpPath, body.context);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        return c.json(
          { error: "Failed to write context temp file", details: msg },
          500,
        );
      }
      args.push("--prompt", `$(cat ${tmpPath})`);
    }

    const commandStr = `wezterm ${args.join(" ")}`;

    try {
      // When using context with $(cat ...), we need to run through shell
      let output;
      if (body.context && !body.sessionId) {
        const shellArgs = args.slice(0); // copy
        const shellCmd = `wezterm ${shellArgs.join(" ")}`;
        const command = new Deno.Command("bash", {
          args: ["-c", shellCmd],
        });
        output = await command.output();
      } else {
        const command = new Deno.Command("wezterm", { args });
        output = await command.output();
      }

      if (!output.success) {
        const stderr = new TextDecoder().decode(output.stderr);
        return c.json(
          { error: "WezTerm launch failed", details: stderr },
          500,
        );
      }

      return c.json({ status: "launched", command: commandStr });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return c.json(
        { error: "WezTerm launch failed", details: msg },
        500,
      );
    }
  });

  // GET /handover/sessions — list handover sessions for a branch
  app.get("/handover/sessions", async (c) => {
    const root = c.req.query("root");
    const branch = c.req.query("branch");

    if (!root || !branch) {
      return c.json(
        { error: "root and branch query params are required" },
        400,
      );
    }

    const handoverDir = `${root}/.claude/handover/${branch}`;

    let entries: Deno.DirEntry[];
    try {
      entries = [];
      for await (const entry of Deno.readDir(handoverDir)) {
        if (entry.isDirectory) {
          entries.push(entry);
        }
      }
    } catch {
      // Directory doesn't exist — return empty array
      return c.json([]);
    }

    const sessions = [];
    for (const entry of entries) {
      const fingerprint = entry.name;
      const sessionPath = `${handoverDir}/${fingerprint}`;

      let hasHandover = false;
      let hasProjectState = false;
      let status = "UNKNOWN";
      let generatedAt: string | null = null;
      let taskSummary: { done: number; in_progress: number; blocked: number } =
        {
          done: 0,
          in_progress: 0,
          blocked: 0,
        };

      try {
        await Deno.stat(`${sessionPath}/handover.md`);
        hasHandover = true;
      } catch {
        // file missing
      }

      try {
        const raw = await Deno.readTextFile(
          `${sessionPath}/project-state.json`,
        );
        hasProjectState = true;
        const ps = JSON.parse(raw);
        status = ps.status ?? "UNKNOWN";
        generatedAt = ps.generated_at ?? null;

        if (Array.isArray(ps.active_tasks)) {
          for (const t of ps.active_tasks) {
            if (t.status === "done") taskSummary.done++;
            else if (t.status === "in_progress") taskSummary.in_progress++;
            else if (t.status === "blocked") taskSummary.blocked++;
          }
        }
      } catch {
        // file missing or invalid
      }

      sessions.push({
        fingerprint,
        path: sessionPath,
        hasHandover,
        hasProjectState,
        status,
        generatedAt,
        taskSummary,
      });
    }

    // Sort by fingerprint descending (newest first)
    sessions.sort((a, b) => b.fingerprint.localeCompare(a.fingerprint));

    return c.json(sessions);
  });

  // GET /handover/content — read handover.md and project-state.json from a dir
  app.get("/handover/content", async (c) => {
    const dir = c.req.query("dir");

    if (!dir) {
      return c.json({ error: "dir query param is required" }, 400);
    }

    // Security: only allow paths containing /.claude/handover/
    if (!dir.includes("/.claude/handover/")) {
      return c.json(
        { error: "Invalid path: must contain /.claude/handover/" },
        403,
      );
    }

    const fingerprint = dir.split("/").pop() ?? "";

    let handover: string | null = null;
    try {
      handover = await Deno.readTextFile(`${dir}/handover.md`);
    } catch {
      // file missing
    }

    let projectState: unknown = null;
    try {
      const raw = await Deno.readTextFile(`${dir}/project-state.json`);
      projectState = JSON.parse(raw);
    } catch {
      // file missing or invalid
    }

    return c.json({ handover, projectState, fingerprint });
  });

  // --- Claude Code Session History ---

  const CLAUDE_DIR = `${Deno.env.get("HOME")}/.claude`;

  function encodeProjectPath(projectPath: string): string {
    // Replace all / and . with - to get the directory name
    return projectPath.replace(/[/.]/g, "-");
  }

  /** Read the first N lines of a file without loading the whole file */
  async function readFirstLines(
    filePath: string,
    maxLines: number,
  ): Promise<string[]> {
    const lines: string[] = [];
    try {
      const file = await Deno.open(filePath, { read: true });
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
              if (lines.length >= maxLines) break outer;
            }
          }
        }
        if (remainder.trim() && lines.length < maxLines) {
          lines.push(remainder);
        }
      } finally {
        file.close();
      }
    } catch {
      // file not found or unreadable
    }
    return lines;
  }

  /** Extract metadata from early lines of a JSONL session file */
  function extractSessionMeta(lines: string[]): {
    sessionId?: string;
    slug?: string;
    version?: string;
    gitBranch?: string;
    timestamp?: string;
  } {
    const meta: {
      sessionId?: string;
      slug?: string;
      version?: string;
      gitBranch?: string;
      timestamp?: string;
    } = {};
    for (const line of lines) {
      try {
        const entry = JSON.parse(line);
        if (entry.sessionId && !meta.sessionId) {
          meta.sessionId = entry.sessionId;
        }
        if (entry.slug && !meta.slug) meta.slug = entry.slug;
        if (entry.version && !meta.version) meta.version = entry.version;
        if (entry.gitBranch && !meta.gitBranch) {
          meta.gitBranch = entry.gitBranch;
        }
        if (entry.timestamp && !meta.timestamp) {
          meta.timestamp = entry.timestamp;
        }
        // Stop early if we have everything
        if (
          meta.sessionId && meta.slug && meta.version && meta.gitBranch &&
          meta.timestamp
        ) break;
      } catch {
        // skip malformed lines
      }
    }
    return meta;
  }

  // GET /sessions/list — list Claude Code sessions for a project
  app.get("/claude-sessions/list", async (c) => {
    const project = c.req.query("project");
    if (!project || typeof project !== "string") {
      return c.json({ error: "project query param is required" }, 400);
    }

    const encoded = encodeProjectPath(project);
    const projectDir = `${CLAUDE_DIR}/projects/${encoded}`;

    // Security: ensure we stay within ~/.claude/projects/
    if (!projectDir.startsWith(`${CLAUDE_DIR}/projects/`)) {
      return c.json({ error: "Invalid project path" }, 403);
    }

    // Scan for session directories (UUID-named dirs)
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    let dirEntries: Deno.DirEntry[];
    try {
      dirEntries = [];
      for await (const entry of Deno.readDir(projectDir)) {
        dirEntries.push(entry);
      }
    } catch {
      return c.json([]);
    }

    // Find all session JSONL files (both root-level and within session dirs)
    const sessionMap = new Map<
      string,
      { jsonlPaths: string[]; hasDir: boolean }
    >();

    for (const entry of dirEntries) {
      if (entry.isDirectory && uuidRegex.test(entry.name)) {
        const sessionId = entry.name;
        if (!sessionMap.has(sessionId)) {
          sessionMap.set(sessionId, { jsonlPaths: [], hasDir: true });
        } else {
          sessionMap.get(sessionId)!.hasDir = true;
        }
      }
      if (
        entry.isFile && entry.name.endsWith(".jsonl") &&
        uuidRegex.test(entry.name.replace(".jsonl", ""))
      ) {
        const sessionId = entry.name.replace(".jsonl", "");
        if (!sessionMap.has(sessionId)) {
          sessionMap.set(sessionId, { jsonlPaths: [], hasDir: false });
        }
        sessionMap.get(sessionId)!.jsonlPaths.push(
          `${projectDir}/${entry.name}`,
        );
      }
    }

    // Load history.jsonl index for first-prompt lookup
    const historyIndex = new Map<string, string>();
    try {
      const historyPath = `${CLAUDE_DIR}/history.jsonl`;
      const historyText = await Deno.readTextFile(historyPath);
      for (const line of historyText.split("\n")) {
        if (!line.trim()) continue;
        try {
          const h = JSON.parse(line);
          if (h.sessionId && h.display && !historyIndex.has(h.sessionId)) {
            historyIndex.set(h.sessionId, h.display);
          }
        } catch {
          // skip
        }
      }
    } catch {
      // history.jsonl not found
    }

    // Build session list
    const sessions: {
      sessionId: string;
      slug: string;
      gitBranch: string;
      version: string;
      timestamp: string;
      firstPrompt: string;
      agentCount: number;
    }[] = [];

    for (const [sessionId, info] of sessionMap) {
      // Find a JSONL file to read metadata from
      let jsonlPath: string | null = null;
      if (info.jsonlPaths.length > 0) {
        jsonlPath = info.jsonlPaths[0];
      } else if (info.hasDir) {
        // Try finding a JSONL file in the root that matches, or in subagents
        const rootJsonl = `${projectDir}/${sessionId}.jsonl`;
        try {
          await Deno.stat(rootJsonl);
          jsonlPath = rootJsonl;
        } catch {
          // Try subagents
          try {
            for await (
              const sub of Deno.readDir(`${projectDir}/${sessionId}/subagents`)
            ) {
              if (sub.isFile && sub.name.endsWith(".jsonl")) {
                jsonlPath = `${projectDir}/${sessionId}/subagents/${sub.name}`;
                break;
              }
            }
          } catch {
            // no subagents
          }
        }
      }

      if (!jsonlPath) continue;

      // Read first ~20 lines for metadata (slug may not be on line 1)
      const firstLines = await readFirstLines(jsonlPath, 20);
      if (firstLines.length === 0) continue;

      const meta = extractSessionMeta(firstLines);
      if (!meta.timestamp) continue;

      // Count agents in subagents dir
      let agentCount = 0;
      try {
        for await (
          const sub of Deno.readDir(`${projectDir}/${sessionId}/subagents`)
        ) {
          if (sub.isFile && sub.name.endsWith(".jsonl")) {
            agentCount++;
          }
        }
      } catch {
        // no subagents dir
      }

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

    // Sort by timestamp descending (newest first)
    sessions.sort((a, b) => b.timestamp.localeCompare(a.timestamp));

    // Return last 20
    return c.json(sessions.slice(0, 20));
  });

  // GET /sessions/:sessionId/messages — get conversation messages for a session
  app.get("/claude-sessions/:sessionId/messages", async (c) => {
    const sessionId = c.req.param("sessionId");
    const project = c.req.query("project");
    const limitStr = c.req.query("limit");
    const limit = Math.min(
      Math.max(parseInt(limitStr ?? "50", 10) || 50, 1),
      200,
    );

    if (!project || typeof project !== "string") {
      return c.json({ error: "project query param is required" }, 400);
    }

    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(sessionId)) {
      return c.json({ error: "Invalid session ID" }, 400);
    }

    const encoded = encodeProjectPath(project);
    const projectDir = `${CLAUDE_DIR}/projects/${encoded}`;

    if (!projectDir.startsWith(`${CLAUDE_DIR}/projects/`)) {
      return c.json({ error: "Invalid project path" }, 403);
    }

    // Collect all JSONL files for this session
    const jsonlFiles: string[] = [];

    // Root-level JSONL
    const rootJsonl = `${projectDir}/${sessionId}.jsonl`;
    try {
      await Deno.stat(rootJsonl);
      jsonlFiles.push(rootJsonl);
    } catch {
      // not found
    }

    // Subagent JSONLs
    try {
      for await (
        const sub of Deno.readDir(`${projectDir}/${sessionId}/subagents`)
      ) {
        if (sub.isFile && sub.name.endsWith(".jsonl")) {
          jsonlFiles.push(`${projectDir}/${sessionId}/subagents/${sub.name}`);
        }
      }
    } catch {
      // no subagents dir
    }

    if (jsonlFiles.length === 0) {
      return c.json({ sessionId, slug: "", messages: [] });
    }

    // Read and filter messages from all files
    interface SessionMessage {
      role: string;
      content: string;
      timestamp: string;
      agentId?: string;
    }

    const messages: SessionMessage[] = [];
    let slug = "";
    const MAX_CONTENT_LENGTH = 500;

    for (const filePath of jsonlFiles) {
      try {
        const text = await Deno.readTextFile(filePath);
        for (const line of text.split("\n")) {
          if (!line.trim()) continue;
          try {
            const entry = JSON.parse(line);
            if (!slug && entry.slug) slug = entry.slug;

            if (entry.type === "user" && entry.message) {
              let content = "";
              const msg = entry.message;
              if (typeof msg.content === "string") {
                content = msg.content;
              } else if (Array.isArray(msg.content)) {
                content = msg.content
                  .filter((b: { type: string }) => b.type === "text")
                  .map((b: { text: string }) => b.text)
                  .join("\n");
              }
              if (!content) continue;
              if (content.length > MAX_CONTENT_LENGTH) {
                content = content.slice(0, MAX_CONTENT_LENGTH) + "...";
              }
              messages.push({
                role: "user",
                content,
                timestamp: entry.timestamp ?? msg.timestamp ?? "",
                agentId: entry.agentId,
              });
            } else if (entry.type === "assistant" && entry.message) {
              const msg = entry.message;
              let content = "";
              if (typeof msg.content === "string") {
                content = msg.content;
              } else if (Array.isArray(msg.content)) {
                // Extract only text blocks, skip tool_use
                content = msg.content
                  .filter((b: { type: string }) => b.type === "text")
                  .map((b: { text: string }) => b.text)
                  .join("\n");
              }
              if (!content) continue;
              if (content.length > MAX_CONTENT_LENGTH) {
                content = content.slice(0, MAX_CONTENT_LENGTH) + "...";
              }
              messages.push({
                role: "assistant",
                content,
                timestamp: entry.timestamp ?? "",
                agentId: entry.agentId,
              });
            }
          } catch {
            // skip malformed lines
          }
        }
      } catch {
        // file read error
      }
    }

    // Sort by timestamp
    messages.sort((a, b) => a.timestamp.localeCompare(b.timestamp));

    // Return last N messages
    const sliced = messages.slice(-limit);

    return c.json({
      sessionId,
      slug,
      messages: sliced,
      totalCount: messages.length,
    });
  });

  // POST /context/build — build merged context from multiple sessions
  app.post("/context/build", async (c) => {
    const body = await c.req.json<{
      project?: string;
      sessionIds?: string[];
      includeHandover?: boolean;
      handoverDir?: string;
    }>();

    if (!body.project || typeof body.project !== "string") {
      return c.json({ error: "project is required" }, 400);
    }
    if (!Array.isArray(body.sessionIds) || body.sessionIds.length === 0) {
      return c.json({
        error: "sessionIds array is required and must not be empty",
      }, 400);
    }

    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    for (const sid of body.sessionIds) {
      if (!uuidRegex.test(sid)) {
        return c.json({ error: `Invalid session ID: ${sid}` }, 400);
      }
    }

    const encoded = encodeProjectPath(body.project);
    const projectDir = `${CLAUDE_DIR}/projects/${encoded}`;

    if (!projectDir.startsWith(`${CLAUDE_DIR}/projects/`)) {
      return c.json({ error: "Invalid project path" }, 403);
    }

    // Load history.jsonl index for first-prompt lookup
    const historyIndex = new Map<string, string>();
    try {
      const historyText = await Deno.readTextFile(
        `${CLAUDE_DIR}/history.jsonl`,
      );
      for (const line of historyText.split("\n")) {
        if (!line.trim()) continue;
        try {
          const h = JSON.parse(line);
          if (h.sessionId && h.display && !historyIndex.has(h.sessionId)) {
            historyIndex.set(h.sessionId, h.display);
          }
        } catch {
          // skip
        }
      }
    } catch {
      // history.jsonl not found
    }

    const MAX_MESSAGES_PER_SESSION = 10;
    const MIN_MESSAGE_LENGTH = 20;
    const MAX_TOTAL_CHARS = 8000;

    interface ContextSession {
      sessionId: string;
      slug: string;
      gitBranch: string;
      date: string;
      messages: { role: string; content: string }[];
    }

    const contextSessions: ContextSession[] = [];
    let totalMessageCount = 0;

    for (const sessionId of body.sessionIds) {
      // Find JSONL file for this session
      const jsonlPaths: string[] = [];
      const rootJsonl = `${projectDir}/${sessionId}.jsonl`;
      try {
        await Deno.stat(rootJsonl);
        jsonlPaths.push(rootJsonl);
      } catch {
        // not found at root
      }

      if (jsonlPaths.length === 0) {
        // Try subagents
        try {
          for await (
            const sub of Deno.readDir(`${projectDir}/${sessionId}/subagents`)
          ) {
            if (sub.isFile && sub.name.endsWith(".jsonl")) {
              jsonlPaths.push(
                `${projectDir}/${sessionId}/subagents/${sub.name}`,
              );
              break;
            }
          }
        } catch {
          // no subagents
        }
      }

      if (jsonlPaths.length === 0) continue;

      let slug = "";
      let gitBranch = "";
      let timestamp = "";
      const messages: { role: string; content: string; ts: string }[] = [];

      for (const filePath of jsonlPaths) {
        try {
          const text = await Deno.readTextFile(filePath);
          for (const line of text.split("\n")) {
            if (!line.trim()) continue;
            try {
              const entry = JSON.parse(line);
              if (entry.slug && !slug) slug = entry.slug;
              if (entry.gitBranch && !gitBranch) gitBranch = entry.gitBranch;
              if (entry.timestamp && !timestamp) timestamp = entry.timestamp;

              if (entry.type === "user" && entry.message) {
                let content = "";
                const msg = entry.message;
                if (typeof msg.content === "string") {
                  content = msg.content;
                } else if (Array.isArray(msg.content)) {
                  content = msg.content
                    .filter((b: { type: string }) => b.type === "text")
                    .map((b: { text: string }) => b.text)
                    .join("\n");
                }
                if (content.length >= MIN_MESSAGE_LENGTH) {
                  messages.push({
                    role: "user",
                    content: content.length > 300
                      ? content.slice(0, 300) + "..."
                      : content,
                    ts: entry.timestamp ?? msg.timestamp ?? "",
                  });
                }
              } else if (entry.type === "assistant" && entry.message) {
                const msg = entry.message;
                let content = "";
                if (typeof msg.content === "string") {
                  content = msg.content;
                } else if (Array.isArray(msg.content)) {
                  // Only first text block as summary
                  const textBlocks = msg.content.filter(
                    (b: { type: string }) => b.type === "text",
                  );
                  if (textBlocks.length > 0) {
                    content = textBlocks[0].text ?? "";
                  }
                }
                if (content.length >= MIN_MESSAGE_LENGTH) {
                  messages.push({
                    role: "assistant",
                    content: content.length > 300
                      ? content.slice(0, 300) + "..."
                      : content,
                    ts: entry.timestamp ?? "",
                  });
                }
              }
            } catch {
              // skip malformed lines
            }
          }
        } catch {
          // file read error
        }
      }

      // Sort by timestamp, take last N
      messages.sort((a, b) => a.ts.localeCompare(b.ts));
      const limited = messages.slice(-MAX_MESSAGES_PER_SESSION);
      totalMessageCount += limited.length;

      const dateStr = timestamp
        ? new Date(timestamp).toISOString().split("T")[0]
        : "unknown";

      contextSessions.push({
        sessionId,
        slug: slug || historyIndex.get(sessionId)?.slice(0, 50) ||
          sessionId.slice(0, 8),
        gitBranch,
        date: dateStr,
        messages: limited.map((m) => ({ role: m.role, content: m.content })),
      });
    }

    // Build markdown document
    let contextDoc = "# Project Context\n\n## Previous Sessions\n\n";

    for (const session of contextSessions) {
      contextDoc += `### Session: ${session.slug} (${session.date})\n`;
      if (session.gitBranch) {
        contextDoc += `Branch: ${session.gitBranch}\n`;
      }
      contextDoc += "\n";

      for (const msg of session.messages) {
        const label = msg.role === "user" ? "User" : "Claude";
        contextDoc += `**${label}:** ${msg.content}\n\n`;
      }

      contextDoc += "---\n\n";
    }

    // Include handover content if requested
    if (body.includeHandover && body.handoverDir) {
      // Security: only allow paths containing /.claude/handover/
      if (body.handoverDir.includes("/.claude/handover/")) {
        try {
          const handoverMd = await Deno.readTextFile(
            `${body.handoverDir}/handover.md`,
          );
          contextDoc += `## Current State (from Handover)\n\n${handoverMd}\n\n`;
        } catch {
          // handover.md not found
        }

        try {
          const psRaw = await Deno.readTextFile(
            `${body.handoverDir}/project-state.json`,
          );
          const ps = JSON.parse(psRaw);
          if (Array.isArray(ps.active_tasks)) {
            contextDoc += "### Task Status\n\n";
            for (const t of ps.active_tasks) {
              contextDoc += `- [${t.status === "done" ? "x" : " "}] ${
                t.title ?? t.id
              } (${t.status})\n`;
            }
            contextDoc += "\n";
          }
        } catch {
          // project-state.json not found or invalid
        }
      }
    }

    contextDoc +=
      "## Your Task\n\nContinue the work based on the context above. Review the current state and ask what to work on next.\n";

    // Truncate to max chars
    if (contextDoc.length > MAX_TOTAL_CHARS) {
      contextDoc = contextDoc.slice(0, MAX_TOTAL_CHARS) +
        "\n\n[...truncated]\n";
    }

    const tokenEstimate = Math.ceil(contextDoc.length / 4);

    return c.json({
      context: contextDoc,
      sessionCount: contextSessions.length,
      messageCount: totalMessageCount,
      tokenEstimate,
    });
  });

  // GET /overview — all boards with task counts per status
  app.get("/overview", async (c) => {
    const boards = await boardRepo.listBoards();
    const statuses: TaskStatus[] = [
      "backlog",
      "todo",
      "in_progress",
      "review",
      "done",
    ];

    const overview = await Promise.all(
      boards.map(async (board) => {
        try {
          const tasks = await taskRepo.listTasks(board.id);
          const counts: Record<string, number> = {};
          for (const status of statuses) {
            counts[status] = 0;
          }
          for (const task of tasks) {
            counts[task.status] = (counts[task.status] ?? 0) + 1;
          }
          return {
            id: board.id,
            name: board.name,
            path: board.path,
            taskCounts: counts,
            totalTasks: tasks.length,
          };
        } catch {
          return {
            id: board.id,
            name: board.name,
            path: board.path,
            taskCounts: {},
            totalTasks: 0,
          };
        }
      }),
    );

    return c.json(overview);
  });

  return app;
}
