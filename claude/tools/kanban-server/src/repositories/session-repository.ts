export interface Session {
  id: string;
  name: string;
  description: string;
  status: "starting" | "in-progress" | "awaiting-review" | "done" | "failed";
  phase: string;
  host: string;
  worktree: string;
  branch: string;
  wezterm_pane_id: string;
  zellij_session: string | null;
  created_at: string;
  updated_at: string;
  waiting_since: string | null;
}

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

  async list(
    filters?: { host?: string; status?: string },
  ): Promise<Session[]> {
    const sessions: Session[] = [];

    try {
      for await (const entry of Deno.readDir(this.sessionsDir)) {
        if (!entry.isFile || !entry.name.endsWith(".json")) continue;

        try {
          const raw = await Deno.readTextFile(
            `${this.sessionsDir}/${entry.name}`,
          );
          const session = JSON.parse(raw) as Session;
          sessions.push(session);
        } catch {
          // skip malformed files
        }
      }
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) {
        return [];
      }
      throw e;
    }

    let filtered = sessions;

    if (filters?.host) {
      filtered = filtered.filter((s) => s.host === filters.host);
    }
    if (filters?.status) {
      filtered = filtered.filter((s) => s.status === filters.status);
    }

    filtered.sort((a, b) =>
      new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime()
    );

    return filtered;
  }

  async get(id: string): Promise<Session | null> {
    try {
      const raw = await Deno.readTextFile(
        `${this.sessionsDir}/${id}.json`,
      );
      return JSON.parse(raw) as Session;
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) {
        return null;
      }
      throw e;
    }
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

      if (session.status === "awaiting-review") {
        awaitingReview++;
      }
    }

    return { sessions, byHost, awaitingReview };
  }
}
