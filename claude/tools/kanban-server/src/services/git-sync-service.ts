export interface SyncStatus {
  isRepo: boolean;
  dirty: boolean;
  branch: string;
  hasRemote: boolean;
  lastCommit: string;
}

export interface PushResult {
  committed: boolean;
  pushed: boolean;
  error?: string;
}

export interface PullResult {
  pulled: boolean;
  error?: string;
}

export class GitSyncService {
  constructor(private readonly repoDir: string) {}

  private async git(
    args: string[],
  ): Promise<{ success: boolean; stdout: string; stderr: string }> {
    const cmd = new Deno.Command("git", {
      args,
      cwd: this.repoDir,
      stdout: "piped",
      stderr: "piped",
    });
    const output = await cmd.output();
    return {
      success: output.success,
      stdout: new TextDecoder().decode(output.stdout).trim(),
      stderr: new TextDecoder().decode(output.stderr).trim(),
    };
  }

  async getStatus(): Promise<SyncStatus> {
    const revParse = await this.git(["rev-parse", "--is-inside-work-tree"]);
    if (!revParse.success) {
      return {
        isRepo: false,
        dirty: false,
        branch: "",
        hasRemote: false,
        lastCommit: "",
      };
    }

    const statusResult = await this.git(["status", "--porcelain"]);
    const dirty = statusResult.stdout.length > 0;

    const branchResult = await this.git(["branch", "--show-current"]);
    const branch = branchResult.stdout;

    const remoteResult = await this.git(["remote"]);
    const hasRemote = remoteResult.stdout.length > 0;

    const logResult = await this.git(["log", "-1", "--format=%H %s"]);
    const lastCommit = logResult.stdout;

    return { isRepo: true, dirty, branch, hasRemote, lastCommit };
  }

  async pull(): Promise<PullResult> {
    const status = await this.getStatus();
    if (!status.isRepo || !status.hasRemote) {
      return {
        pulled: false,
        error: status.isRepo ? "no remote configured" : "not a git repo",
      };
    }

    const result = await this.git(["pull", "--rebase"]);
    if (!result.success) {
      return { pulled: false, error: result.stderr };
    }
    return { pulled: true };
  }

  async commitAndPush(message: string): Promise<PushResult> {
    const status = await this.getStatus();
    if (!status.isRepo) {
      return { committed: false, pushed: false, error: "not a git repo" };
    }

    if (!status.dirty) {
      return { committed: false, pushed: false, error: "nothing to commit" };
    }

    const addResult = await this.git(["add", "-A"]);
    if (!addResult.success) {
      return { committed: false, pushed: false, error: addResult.stderr };
    }

    const commitResult = await this.git(["commit", "-m", message]);
    if (!commitResult.success) {
      return { committed: false, pushed: false, error: commitResult.stderr };
    }

    if (!status.hasRemote) {
      return { committed: true, pushed: false };
    }

    const pushResult = await this.git(["push"]);
    if (!pushResult.success) {
      return { committed: true, pushed: false, error: pushResult.stderr };
    }

    return { committed: true, pushed: true };
  }
}
