import type { BoardRepository } from "./repositories/board-repository.ts";
import type { TaskRepository } from "./repositories/task-repository.ts";
import type { GitSyncService } from "./services/git-sync-service.ts";
import type { SshService } from "./services/ssh-service.ts";
import type { KanbanConfig } from "./config.ts";
import { SyncService } from "./services/sync-service.ts";
import type { ProjectState } from "./services/sync-service.ts";
import type {
  AllCapabilities,
  BoardSummary,
  ClaudeSession,
  ContextDocument,
  HandoverContent,
  HandoverSession,
  LaunchResult,
  RemoteStatus,
  SessionMessages,
} from "./capabilities.ts";
import type {
  Board,
  CreateBoardInput,
  CreateTaskInput,
  Task,
  TaskFilter,
  TaskStatus,
  UpdateTaskInput,
} from "./types.ts";

const CLAUDE_DIR = `${Deno.env.get("HOME")}/.claude`;

function encodeProjectPath(projectPath: string): string {
  return projectPath.replace(/[/.]/g, "-");
}

export function createCapabilities(
  boardRepo: BoardRepository,
  taskRepo: TaskRepository,
  gitSync: GitSyncService,
  sshService: SshService,
  config: KanbanConfig,
): AllCapabilities {
  const syncService = new SyncService(taskRepo);

  return {
    // --- Board ---
    async listBoards(): Promise<Board[]> {
      return await boardRepo.listBoards();
    },
    async createBoard(input: CreateBoardInput): Promise<Board> {
      return await boardRepo.createBoard(input);
    },
    async deleteBoard(boardId: string): Promise<void> {
      await boardRepo.deleteBoard(boardId);
    },
    async getOverview(): Promise<BoardSummary[]> {
      const boards = await boardRepo.listBoards();
      const statuses: TaskStatus[] = [
        "backlog",
        "todo",
        "in_progress",
        "review",
        "done",
      ];
      return await Promise.all(
        boards.map(async (board) => {
          try {
            const tasks = await taskRepo.listTasks(board.id);
            const counts: Record<string, number> = {};
            for (const status of statuses) counts[status] = 0;
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
    },

    // --- Task ---
    async listTasks(boardId: string, filter?: TaskFilter): Promise<Task[]> {
      return await taskRepo.listTasks(boardId, filter);
    },
    async getTask(boardId: string, taskId: string): Promise<Task | null> {
      return await taskRepo.getTask(boardId, taskId);
    },
    async createTask(
      boardId: string,
      input: CreateTaskInput,
    ): Promise<Task> {
      return await taskRepo.createTask(boardId, input);
    },
    async updateTask(
      boardId: string,
      taskId: string,
      input: UpdateTaskInput,
    ): Promise<Task> {
      return await taskRepo.updateTask(boardId, taskId, input);
    },
    async deleteTask(boardId: string, taskId: string): Promise<void> {
      await taskRepo.deleteTask(boardId, taskId);
    },
    async moveTask(
      boardId: string,
      taskId: string,
      status: TaskStatus,
    ): Promise<Task> {
      const moved = await taskRepo.moveTasks(boardId, [{ taskId, status }]);
      if (moved.length === 0) throw new Error(`Task ${taskId} not found`);
      return moved[0];
    },

    // --- Sessions ---
    async listHandoverSessions(
      root: string,
      branch: string,
    ): Promise<HandoverSession[]> {
      const handoverDir = `${root}/.claude/handover/${branch}`;
      let entries: Deno.DirEntry[];
      try {
        entries = [];
        for await (const entry of Deno.readDir(handoverDir)) {
          if (entry.isDirectory) entries.push(entry);
        }
      } catch {
        return [];
      }

      const sessions: HandoverSession[] = [];
      for (const entry of entries) {
        const sessionPath = `${handoverDir}/${entry.name}`;
        let hasHandover = false;
        let hasProjectState = false;
        let status = "UNKNOWN";
        let generatedAt: string | null = null;
        const taskSummary = { done: 0, in_progress: 0, blocked: 0 };

        try {
          await Deno.stat(`${sessionPath}/handover.md`);
          hasHandover = true;
        } catch { /* missing */ }
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
        } catch { /* missing or invalid */ }

        sessions.push({
          fingerprint: entry.name,
          path: sessionPath,
          hasHandover,
          hasProjectState,
          status,
          generatedAt,
          taskSummary,
        });
      }

      sessions.sort((a, b) => b.fingerprint.localeCompare(a.fingerprint));
      return sessions;
    },

    async getHandoverContent(dir: string): Promise<HandoverContent> {
      if (!dir.includes("/.claude/handover/")) {
        throw new Error("Invalid path: must contain /.claude/handover/");
      }
      const fingerprint = dir.split("/").pop() ?? "";
      let handover: string | null = null;
      try {
        handover = await Deno.readTextFile(`${dir}/handover.md`);
      } catch { /* missing */ }
      let projectState: unknown = null;
      try {
        const raw = await Deno.readTextFile(`${dir}/project-state.json`);
        projectState = JSON.parse(raw);
      } catch { /* missing */ }
      return { handover, projectState, fingerprint };
    },

    async listClaudeSessions(
      projectPath: string,
    ): Promise<ClaudeSession[]> {
      const encoded = encodeProjectPath(projectPath);
      const projectDir = `${CLAUDE_DIR}/projects/${encoded}`;
      if (!projectDir.startsWith(`${CLAUDE_DIR}/projects/`)) {
        throw new Error("Invalid project path");
      }

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

      // Load history index
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
                  jsonlPath =
                    `${projectDir}/${sessionId}/subagents/${sub.name}`;
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
      return sessions.slice(0, 20);
    },

    async getSessionMessages(
      sessionId: string,
      projectPath: string,
      limit = 50,
    ): Promise<SessionMessages> {
      const clampedLimit = Math.min(Math.max(limit, 1), 200);
      const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(sessionId)) throw new Error("Invalid session ID");

      const encoded = encodeProjectPath(projectPath);
      const projectDir = `${CLAUDE_DIR}/projects/${encoded}`;
      const jsonlFiles: string[] = [];

      try {
        await Deno.stat(`${projectDir}/${sessionId}.jsonl`);
        jsonlFiles.push(`${projectDir}/${sessionId}.jsonl`);
      } catch { /* not found */ }
      try {
        for await (
          const sub of Deno.readDir(
            `${projectDir}/${sessionId}/subagents`,
          )
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
      const MAX_CONTENT = 500;

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
        messages: messages.slice(-clampedLimit),
        totalCount: messages.length,
      };
    },

    async buildContext(
      project: string,
      sessionIds: string[],
      includeHandover?: boolean,
      handoverDir?: string,
    ): Promise<ContextDocument> {
      if (!project) throw new Error("project is required");
      if (!sessionIds || sessionIds.length === 0) {
        throw new Error("sessionIds required");
      }

      const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      for (const sid of sessionIds) {
        if (!uuidRegex.test(sid)) {
          throw new Error(`Invalid session ID: ${sid}`);
        }
      }

      const encoded = encodeProjectPath(project);
      const projectDir = `${CLAUDE_DIR}/projects/${encoded}`;

      // Load history index
      const historyIndex = new Map<string, string>();
      try {
        const historyText = await Deno.readTextFile(
          `${CLAUDE_DIR}/history.jsonl`,
        );
        for (const line of historyText.split("\n")) {
          if (!line.trim()) continue;
          try {
            const h = JSON.parse(line);
            if (h.sessionId && h.display) {
              historyIndex.set(h.sessionId, h.display);
            }
          } catch { /* skip */ }
        }
      } catch { /* not found */ }

      const MAX_MSGS = 10;
      const MIN_LEN = 20;
      const MAX_CHARS = 8000;

      interface CS {
        sessionId: string;
        slug: string;
        gitBranch: string;
        date: string;
        messages: { role: string; content: string }[];
      }
      const contextSessions: CS[] = [];
      let totalMessageCount = 0;

      for (const sessionId of sessionIds) {
        const jsonlPaths: string[] = [];
        try {
          await Deno.stat(`${projectDir}/${sessionId}.jsonl`);
          jsonlPaths.push(`${projectDir}/${sessionId}.jsonl`);
        } catch { /* */ }
        if (jsonlPaths.length === 0) {
          try {
            for await (
              const sub of Deno.readDir(
                `${projectDir}/${sessionId}/subagents`,
              )
            ) {
              if (sub.isFile && sub.name.endsWith(".jsonl")) {
                jsonlPaths.push(
                  `${projectDir}/${sessionId}/subagents/${sub.name}`,
                );
                break;
              }
            }
          } catch { /* */ }
        }
        if (jsonlPaths.length === 0) continue;

        let slug = "", gitBranch = "", timestamp = "";
        const msgs: { role: string; content: string; ts: string }[] = [];
        for (const fp of jsonlPaths) {
          try {
            const text = await Deno.readTextFile(fp);
            for (const line of text.split("\n")) {
              if (!line.trim()) continue;
              try {
                const e = JSON.parse(line);
                if (e.slug && !slug) slug = e.slug;
                if (e.gitBranch && !gitBranch) gitBranch = e.gitBranch;
                if (e.timestamp && !timestamp) timestamp = e.timestamp;
                if (
                  (e.type === "user" || e.type === "assistant") && e.message
                ) {
                  let content = "";
                  const m = e.message;
                  if (typeof m.content === "string") content = m.content;
                  else if (Array.isArray(m.content)) {
                    const tb = m.content.filter(
                      (b: { type: string }) => b.type === "text",
                    );
                    content = e.type === "assistant"
                      ? (tb[0]?.text ?? "")
                      : tb.map((b: { text: string }) => b.text).join("\n");
                  }
                  if (content.length >= MIN_LEN) {
                    msgs.push({
                      role: e.type,
                      content: content.length > 300
                        ? content.slice(0, 300) + "..."
                        : content,
                      ts: e.timestamp ?? "",
                    });
                  }
                }
              } catch { /* skip */ }
            }
          } catch { /* read error */ }
        }

        msgs.sort((a, b) => a.ts.localeCompare(b.ts));
        const limited = msgs.slice(-MAX_MSGS);
        totalMessageCount += limited.length;

        contextSessions.push({
          sessionId,
          slug: slug || historyIndex.get(sessionId)?.slice(0, 50) ||
            sessionId.slice(0, 8),
          gitBranch,
          date: timestamp
            ? new Date(timestamp).toISOString().split("T")[0]
            : "unknown",
          messages: limited.map((m) => ({ role: m.role, content: m.content })),
        });
      }

      let contextDoc = "# Project Context\n\n## Previous Sessions\n\n";
      for (const s of contextSessions) {
        contextDoc += `### Session: ${s.slug} (${s.date})\n`;
        if (s.gitBranch) contextDoc += `Branch: ${s.gitBranch}\n`;
        contextDoc += "\n";
        for (const m of s.messages) {
          contextDoc += `**${
            m.role === "user" ? "User" : "Claude"
          }:** ${m.content}\n\n`;
        }
        contextDoc += "---\n\n";
      }

      if (
        includeHandover && handoverDir &&
        handoverDir.includes("/.claude/handover/")
      ) {
        try {
          contextDoc += `## Current State (from Handover)\n\n${await Deno
            .readTextFile(`${handoverDir}/handover.md`)}\n\n`;
        } catch { /* */ }
        try {
          const ps = JSON.parse(
            await Deno.readTextFile(`${handoverDir}/project-state.json`),
          );
          if (Array.isArray(ps.active_tasks)) {
            contextDoc += "### Task Status\n\n";
            for (const t of ps.active_tasks) {
              contextDoc += `- [${t.status === "done" ? "x" : " "}] ${
                t.title ?? t.id
              } (${t.status})\n`;
            }
            contextDoc += "\n";
          }
        } catch { /* */ }
      }

      contextDoc +=
        "## Your Task\n\nContinue the work based on the context above. Review the current state and ask what to work on next.\n";
      if (contextDoc.length > MAX_CHARS) {
        contextDoc = contextDoc.slice(0, MAX_CHARS) + "\n\n[...truncated]\n";
      }

      return {
        context: contextDoc,
        sessionCount: contextSessions.length,
        messageCount: totalMessageCount,
        tokenEstimate: Math.ceil(contextDoc.length / 4),
      };
    },

    // --- Launch ---
    async launchLocal(
      projectPath: string,
      sessionId?: string,
      context?: string,
    ): Promise<LaunchResult> {
      if (!projectPath) throw new Error("projectPath is required");
      const args = ["cli", "spawn", "--cwd", projectPath, "--", "claude"];
      if (sessionId) {
        args.push("--resume", sessionId);
      } else if (context) {
        const tmpPath = `/tmp/kanban-context-${Date.now()}.md`;
        await Deno.writeTextFile(tmpPath, context);
        args.push("--prompt", `$(cat ${tmpPath})`);
      }

      try {
        let output;
        if (context && !sessionId) {
          output = await new Deno.Command("bash", {
            args: ["-c", `wezterm ${args.join(" ")}`],
          }).output();
        } else {
          output = await new Deno.Command("wezterm", { args }).output();
        }
        if (!output.success) {
          return {
            status: "error",
            error: new TextDecoder().decode(output.stderr),
          };
        }
        return { status: "launched", command: `wezterm ${args.join(" ")}` };
      } catch (e) {
        return {
          status: "error",
          error: e instanceof Error ? e.message : String(e),
        };
      }
    },

    async launchRemote(
      taskId: string,
      projectPath: string,
      host?: string,
      context?: string,
      taskTitle?: string,
    ): Promise<LaunchResult> {
      if (!taskId) throw new Error("taskId is required");
      if (!projectPath) throw new Error("projectPath is required");

      const hostName = host ?? config.defaultRemote;
      if (!hostName) {
        throw new Error(
          "no host specified and no defaultRemote configured",
        );
      }
      const remote = config.remotes[hostName];
      if (!remote) throw new Error(`unknown host: ${hostName}`);

      const sessionName = `kanban-${taskId}`;
      const sshOpts = { user: remote.user };

      await sshService.execSsh(
        remote.host,
        `cd ${projectPath} && git pull`,
        sshOpts,
      );
      if (remote.repos.kanban) {
        await sshService.execSsh(
          remote.host,
          `cd ${remote.repos.kanban} && git pull`,
          sshOpts,
        );
      }
      if (context) {
        const remotePath = `/tmp/kanban-context-${taskId}.md`;
        const tmpFile = await Deno.makeTempFile({ prefix: "kanban-ctx-" });
        await Deno.writeTextFile(tmpFile, context);
        await sshService.scpTo(remote.host, tmpFile, remotePath, sshOpts);
        await Deno.remove(tmpFile);
      }

      const titleArg = taskTitle ? ` --title '${taskTitle}'` : "";
      const launchCmd =
        `cd ${projectPath} && zellij attach ${sessionName} --create -- claude${titleArg}`;
      await sshService.execSsh(
        remote.host,
        `nohup bash -c '${
          launchCmd.replace(/'/g, "'\\''")
        }' > /dev/null 2>&1 &`,
        sshOpts,
      );

      return { status: "launched", host: hostName, sessionName, taskId };
    },

    async getRemoteStatus(
      taskId: string,
      host?: string,
    ): Promise<RemoteStatus> {
      const hostName = host ?? config.defaultRemote;
      if (!hostName) throw new Error("no host specified");
      const remote = config.remotes[hostName];
      if (!remote) throw new Error(`unknown host: ${hostName}`);

      const sessionName = `kanban-${taskId}`;
      const result = await sshService.execSsh(
        remote.host,
        `zellij list-sessions 2>/dev/null | grep -q '^${sessionName}' && echo running || echo stopped`,
        { user: remote.user },
      );
      let status: "running" | "stopped" | "unknown" = "unknown";
      if (result.success) {
        const out = result.stdout.trim();
        if (out === "running") status = "running";
        else if (out === "stopped") status = "stopped";
      }
      return { taskId, host: hostName, sessionName, status };
    },

    listRemoteHosts() {
      const hosts = Object.entries(config.remotes).map(([name, r]) => ({
        name,
        host: r.host,
        user: r.user,
      }));
      return Promise.resolve({ hosts, defaultRemote: config.defaultRemote });
    },

    async pingRemote(host?: string) {
      const hostName = host ?? config.defaultRemote;
      if (!hostName) throw new Error("no host specified");
      const remote = config.remotes[hostName];
      if (!remote) throw new Error(`unknown host: ${hostName}`);
      const result = await sshService.ping(remote.host, remote.user);
      return {
        host: hostName,
        online: result.online,
        latencyMs: result.latencyMs,
      };
    },

    // --- Sync ---
    async getSyncStatus() {
      return await gitSync.getStatus();
    },
    async pull() {
      return await gitSync.pull();
    },
    async push(message: string) {
      return await gitSync.commitAndPush(message);
    },
    async syncFromHandover(boardId: string, branch: string) {
      const homeDir = Deno.env.get("HOME") ?? "";
      const handoverBranchDir = `${homeDir}/.claude/handover/${branch}`;

      let entries: Deno.DirEntry[];
      try {
        entries = [];
        for await (const entry of Deno.readDir(handoverBranchDir)) {
          if (entry.isDirectory) entries.push(entry);
        }
      } catch {
        return {
          created: 0,
          updated: 0,
          errors: [`No handover data for branch '${branch}'`],
        };
      }

      if (entries.length === 0) {
        return {
          created: 0,
          updated: 0,
          errors: [`No handover data for branch '${branch}'`],
        };
      }

      entries.sort((a, b) => b.name.localeCompare(a.name));
      const latestDir = `${handoverBranchDir}/${entries[0].name}`;
      const projectStatePath = `${latestDir}/project-state.json`;

      let projectState: ProjectState;
      try {
        projectState = JSON.parse(
          await Deno.readTextFile(projectStatePath),
        );
      } catch {
        return {
          created: 0,
          updated: 0,
          errors: ["project-state.json not found or invalid"],
        };
      }

      return await syncService.syncFromProjectState(
        boardId,
        projectState,
        projectStatePath,
      );
    },
  };
}
