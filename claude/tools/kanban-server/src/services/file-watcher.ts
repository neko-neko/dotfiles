import type { ConflictFile, ConflictResolver } from "./conflict-resolver.ts";

const MAX_PENDING = 200;

export class FileWatcher {
  private readonly resolver: ConflictResolver;
  private readonly dataDir: string;
  private readonly intervalMs: number;
  private pending: ConflictFile[] = [];
  private intervalId: number | null = null;
  private watcher: Deno.FsWatcher | null = null;

  constructor(
    resolver: ConflictResolver,
    dataDir: string,
    intervalMs: number = 5000,
  ) {
    this.resolver = resolver;
    this.dataDir = dataDir;
    this.intervalMs = intervalMs;
  }

  start(): void {
    // Primary: periodic scan
    this.intervalId = setInterval(() => {
      this.scanOnce().catch((e) => {
        console.error("[FileWatcher] scan error:", e);
      });
    }, this.intervalMs);

    // Secondary: Deno.watchFs (best-effort)
    try {
      this.watcher = Deno.watchFs(this.dataDir, { recursive: true });
      this.watchLoop();
    } catch {
      // watchFs not available — periodic scan only
    }
  }

  stop(): void {
    if (this.intervalId !== null) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
    if (this.watcher) {
      try {
        this.watcher.close();
      } catch {
        // already closed
      }
      this.watcher = null;
    }
  }

  private async watchLoop(): Promise<void> {
    if (!this.watcher) return;
    try {
      for await (const event of this.watcher) {
        if (event.kind === "create" || event.kind === "rename") {
          const hasConflict = event.paths.some((p) =>
            p.includes(".sync-conflict")
          );
          if (hasConflict) {
            // Wait 1 second for file to stabilize
            await new Promise((r) => setTimeout(r, 1000));
            await this.scanOnce();
          }
        }
      }
    } catch {
      // watcher closed or error — stop watching
    }
  }

  async scanOnce(): Promise<void> {
    const conflicts = await this.resolver.detectConflicts();

    for (const conflict of conflicts) {
      const result = await this.resolver.resolveConflict(conflict);
      if (!result.resolved) {
        // Check if this conflict is already in pending (by path)
        const exists = this.pending.some(
          (p) => p.conflictPath === conflict.conflictPath,
        );
        if (!exists) {
          this.pending.push(conflict);
        }
      }
    }

    // Enforce pending limit
    if (this.pending.length > MAX_PENDING) {
      const excess = this.pending.length - MAX_PENDING;
      console.warn(
        `[FileWatcher] pending conflicts exceeded ${MAX_PENDING}, dropping ${excess} oldest`,
      );
      this.pending = this.pending.slice(excess);
    }
  }

  getPendingConflicts(): ConflictFile[] {
    return [...this.pending];
  }
}
