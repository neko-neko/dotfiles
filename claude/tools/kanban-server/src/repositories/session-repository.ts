import {
  type CreateSessionInput,
  type Session,
  SESSION_TRANSITIONS,
  type SessionStatus,
  type UpdateSessionInput,
} from "../types.ts";

export interface SessionDashboard {
  sessions: Session[];
  byHost: Record<string, { count: number }>;
  awaitingReview: number;
}

export class SessionRepository {
  private readonly sessionsDir: string;

  constructor(private readonly dataDir: string) {
    this.sessionsDir = `${dataDir}/sessions`;
  }

  async create(input: CreateSessionInput): Promise<Session> {
    await Deno.mkdir(this.sessionsDir, { recursive: true });
    const now = new Date().toISOString();
    const session: Session = {
      id: crypto.randomUUID(),
      taskId: input.taskId,
      boardId: input.boardId,
      host: input.host,
      ownerNode: input.ownerNode,
      status: "starting",
      createdAt: now,
      updatedAt: now,
    };

    if (input.worktree !== undefined) session.worktree = input.worktree;
    if (input.branch !== undefined) session.branch = input.branch;
    if (input.launchCommand !== undefined) {
      session.launchCommand = input.launchCommand;
    }

    await Deno.writeTextFile(
      `${this.sessionsDir}/${session.id}.json`,
      JSON.stringify(session, null, 2),
    );
    return session;
  }

  async get(id: string): Promise<Session | null> {
    try {
      const raw = await Deno.readTextFile(`${this.sessionsDir}/${id}.json`);
      return JSON.parse(raw) as Session;
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) return null;
      throw e;
    }
  }

  async list(
    filters?: { host?: string; status?: SessionStatus },
  ): Promise<Session[]> {
    const sessions: Session[] = [];

    try {
      for await (const entry of Deno.readDir(this.sessionsDir)) {
        if (!entry.isFile || !entry.name.endsWith(".json")) continue;
        try {
          const raw = await Deno.readTextFile(
            `${this.sessionsDir}/${entry.name}`,
          );
          sessions.push(JSON.parse(raw) as Session);
        } catch {
          // skip malformed files
        }
      }
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) return [];
      throw e;
    }

    let filtered = sessions;
    if (filters?.host) {
      filtered = filtered.filter((s) => s.host === filters.host);
    }
    if (filters?.status) {
      filtered = filtered.filter((s) => s.status === filters.status);
    }

    filtered.sort(
      (a, b) =>
        new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
    );

    return filtered;
  }

  async listByTask(taskId: string): Promise<Session[]> {
    const all = await this.list();
    return all.filter((s) => s.taskId === taskId);
  }

  async update(
    id: string,
    input: UpdateSessionInput,
    requestingNode: string,
  ): Promise<Session> {
    const session = await this.get(id);
    if (!session) {
      throw new Error(`Session '${id}' not found`);
    }
    if (session.ownerNode !== requestingNode) {
      throw new Error(
        `Only ownerNode '${session.ownerNode}' can update this session`,
      );
    }

    if (input.status) {
      const allowed = SESSION_TRANSITIONS[session.status];
      if (!allowed.includes(input.status)) {
        throw new Error(
          `Invalid transition: ${session.status} → ${input.status}`,
        );
      }
      session.status = input.status;
    }

    if (input.claudeSessionId !== undefined) {
      session.claudeSessionId = input.claudeSessionId;
    }
    if (input.handoverPath !== undefined) {
      session.handoverPath = input.handoverPath;
    }
    if (input.worktree !== undefined) session.worktree = input.worktree;
    if (input.branch !== undefined) session.branch = input.branch;

    session.updatedAt = new Date().toISOString();
    await Deno.writeTextFile(
      `${this.sessionsDir}/${id}.json`,
      JSON.stringify(session, null, 2),
    );
    return session;
  }

  async dashboard(): Promise<SessionDashboard> {
    const sessions = await this.list();
    const byHost: Record<string, { count: number }> = {};
    let awaitingReview = 0;

    for (const session of sessions) {
      if (!byHost[session.host]) {
        byHost[session.host] = { count: 0 };
      }
      byHost[session.host].count++;
      if (session.status === "awaiting-review") awaitingReview++;
    }

    return { sessions, byHost, awaitingReview };
  }
}
