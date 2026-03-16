export interface ConflictFile {
  id: string;
  originalPath: string;
  conflictPath: string;
  type: "task" | "session" | "board-meta";
  detectedAt: string;
}

export interface ConflictResult {
  resolved: boolean;
  winner: "local" | "remote";
  reason: string;
}

const SYNC_CONFLICT_PATTERN = /\.sync-conflict-\d{8}-\d{6}-\w+\.json$/;

export class ConflictResolver {
  private readonly dataDir: string;

  constructor(dataDir: string) {
    this.dataDir = dataDir;
  }

  async detectConflicts(): Promise<ConflictFile[]> {
    const conflicts: ConflictFile[] = [];
    await this.scanDir(`${this.dataDir}/boards`, conflicts);
    await this.scanDir(`${this.dataDir}/sessions`, conflicts);

    // Limit to 50 per cycle
    return conflicts.slice(0, 50);
  }

  private async scanDir(
    dirPath: string,
    conflicts: ConflictFile[],
  ): Promise<void> {
    try {
      for await (const entry of Deno.readDir(dirPath)) {
        const fullPath = `${dirPath}/${entry.name}`;
        if (entry.isDirectory) {
          await this.scanDir(fullPath, conflicts);
        } else if (entry.isFile && SYNC_CONFLICT_PATTERN.test(entry.name)) {
          const originalName = entry.name.replace(
            /\.sync-conflict-\d{8}-\d{6}-\w+\.json$/,
            ".json",
          );
          const originalPath = `${dirPath}/${originalName}`;
          const type = this.inferType(dirPath);

          conflicts.push({
            id: crypto.randomUUID(),
            originalPath,
            conflictPath: fullPath,
            type,
            detectedAt: new Date().toISOString(),
          });
        }
      }
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) return;
      throw e;
    }
  }

  private inferType(
    dirPath: string,
  ): "task" | "session" | "board-meta" {
    if (dirPath.includes("/sessions")) return "session";
    if (dirPath.includes("/boards")) return "task";
    return "board-meta";
  }

  async resolveConflict(conflict: ConflictFile): Promise<ConflictResult> {
    let localData: Record<string, unknown> | null = null;
    let remoteData: Record<string, unknown> | null = null;

    try {
      const raw = await Deno.readTextFile(conflict.originalPath);
      localData = JSON.parse(raw);
    } catch {
      // local file corrupt or missing
    }

    try {
      const raw = await Deno.readTextFile(conflict.conflictPath);
      remoteData = JSON.parse(raw);
    } catch {
      // conflict file corrupt
    }

    // If one side is corrupt, pick the valid one
    if (localData && !remoteData) {
      await this.deleteConflictFile(conflict.conflictPath);
      return { resolved: true, winner: "local", reason: "remote parse error" };
    }
    if (!localData && remoteData) {
      await Deno.writeTextFile(
        conflict.originalPath,
        JSON.stringify(remoteData, null, 2),
      );
      await this.deleteConflictFile(conflict.conflictPath);
      return { resolved: true, winner: "remote", reason: "local parse error" };
    }
    if (!localData && !remoteData) {
      await this.deleteConflictFile(conflict.conflictPath);
      return {
        resolved: true,
        winner: "local",
        reason: "both corrupt, kept original",
      };
    }

    // Both valid — LWW by updatedAt
    const localTime = (localData as Record<string, string>).updatedAt ?? "";
    const remoteTime = (remoteData as Record<string, string>).updatedAt ?? "";

    if (localTime === remoteTime) {
      return {
        resolved: false,
        winner: "local",
        reason: "identical updatedAt",
      };
    }

    if (new Date(remoteTime).getTime() > new Date(localTime).getTime()) {
      // Remote wins
      await Deno.writeTextFile(
        conflict.originalPath,
        JSON.stringify(remoteData, null, 2),
      );
      await this.deleteConflictFile(conflict.conflictPath);
      return { resolved: true, winner: "remote", reason: "newer updatedAt" };
    }

    // Local wins
    await this.deleteConflictFile(conflict.conflictPath);
    return { resolved: true, winner: "local", reason: "newer updatedAt" };
  }

  private async deleteConflictFile(path: string): Promise<void> {
    try {
      await Deno.remove(path);
    } catch (e) {
      if (!(e instanceof Deno.errors.NotFound)) throw e;
    }
  }
}
